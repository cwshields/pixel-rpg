@tool
extends EditorScript
## One-shot converter: replaces the tree tiles painted into
## `World/TileMap/Vegitation` with real `tree.tscn` (TreeProp) instances so
## they pick up the player walk-behind + proximity-fade effect, which a
## TileMapLayer (one CanvasItem, no per-tile z_index/modulate) can never do.
##
## HOW TO RUN
##   1. Open `scenes/main.tscn` in the editor (it must be the active scene).
##   2. `World` now lives in `scenes/world/world.scn` and is instanced into
##      main.tscn — right-click the `World` node in the Scene dock and enable
##      "Editable Children" so this script can reach and edit
##      `World/TileMap/Vegitation` (erasing its converted tiles) through the
##      instance. Without this the tile erasure won't survive a save.
##   3. Open this file, then File ▸ Run (Ctrl+Shift+X).
##   4. Check the Output panel, eyeball the new `Trees/PaintedTrees` nodes.
##   5. Ctrl+S to keep it, or Ctrl+Z / `git checkout scenes/main.tscn` to bail.
##
## Safe to run repeatedly. It does two idempotent passes:
##   * REPAIR — every existing `PaintedTree_*` that is missing its trunk
##     collision gets it back (rebuilt from the matching tileset tile's own
##     physics polygon); any missing its hover collision gets that backfilled
##     too, independently of the trunk check.
##   * CONVERT — any tree tiles still on the Vegitation layer are turned
##     into instances and erased.
## A clean checkout hits only CONVERT; a scene from an earlier (collision-
## less) run hits only REPAIR.
##
## HOVER SHAPE AUTHORING
##   TreeProp's cursor-only HoverArea defaults to a rectangle sized to the
##   sprite's bounding box. For a canopy-shaped hover outline instead, draw
##   a *second* polygon (index 1) on the same physics layer 0 you already
##   used for the trunk — in the TileSet editor's tile collision tool, pick
##   the tile, then "+" to add a second polygon and trace the canopy. Only
##   the handful of distinct tile types actually painted need this (not one
##   per instance) — re-run this script's REPAIR pass afterward to backfill
##   `hover_polygon` onto every existing instance of that tile. Skipped
##   tiles just keep the auto-rectangle.

const TREE_SCENE := preload("res://scenes/world/tree.tscn")

## Vegitation TileSet sources that are tree sheets (Size_02/03/04).
## Source 1 is the grass/bush/flower atlas and is deliberately left alone.
const TREE_SOURCE_IDS: Array[int] = [2, 3, 4]

## Carry each tile's trunk collision polygon onto its instance. Off = the
## converted trees are purely visual.
const ADD_TRUNK_COLLISION := true

## Carry each tile's hover-area collision polygon (physics layer 0,
## polygon index 1 — see HOVER SHAPE AUTHORING above) onto its instance.
## Off = converted trees keep TreeProp's auto-rectangle hover shape.
const ADD_HOVER_COLLISION := true

const VEGITATION_PATH := "World/TileMap/Vegitation"
const CONTAINER_NAME := "Trees"
const PAINTED_NAME := "PaintedTrees"

func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("[convert_painted_trees] No scene open. Open scenes/main.tscn first.")
		return

	var veg := root.get_node_or_null(VEGITATION_PATH) as TileMapLayer
	if veg == null:
		push_error("[convert_painted_trees] %s not found under the open scene." % VEGITATION_PATH)
		return

	var tile_set := veg.tile_set
	if tile_set == null:
		push_error("[convert_painted_trees] Vegitation layer has no TileSet.")
		return

	var painted := _ensure_container(root)

	var repaired := _repair_existing(painted, tile_set)
	var converted := _convert_cells(root, veg, tile_set, painted)

	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()

	print("[convert_painted_trees] repaired %d existing instance(s), converted %d tile(s)." % [repaired, converted])
	if repaired == 0 and converted == 0:
		print("  nothing to do — everything already converted with collision intact.")
	else:
		print("  Review %s/%s, then Ctrl+S. Undo with Ctrl+Z or `git checkout scenes/main.tscn`." % [CONTAINER_NAME, PAINTED_NAME])


## REPAIR pass — give any collision-less `PaintedTree_*` its trunk back,
## reconstructed from the tileset tile its Art overrides point at; and
## backfill `hover_polygon` for any instance still missing one, whenever
## the matching tile now has a second (canopy) polygon authored. The two
## checks are independent, so re-running this after adding hover polygons
## to the TileSet backfills every existing instance without touching an
## already-repaired trunk.
func _repair_existing(painted: Node, tile_set: TileSet) -> int:
	var half := tile_set.tile_size.y / 2.0
	var fixed := 0
	for tree in painted.get_children():
		if not (tree is TreeProp) or not String(tree.name).begins_with("PaintedTree_"):
			continue
		if tree.art_texture == null:
			continue
		var source_id := _source_for(tree.art_texture.resource_path.get_file())
		if source_id == 0:
			continue
		var atlas_coords := Vector2i(tree.art_region.position) / tile_set.tile_size
		var touched := false

		var shape_node := tree.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
		var trunk_already_fixed := shape_node and shape_node.shape is ConvexPolygonShape2D and not shape_node.disabled
		if not trunk_already_fixed:
			var points := _collision_points(tile_set, source_id, atlas_coords, 0)
			if points.is_empty():
				if tree.trunk_enabled:
					tree.trunk_enabled = false
					touched = true
			else:
				tree.trunk_offset = Vector2(0, -half)
				tree.trunk_enabled = true
				tree.trunk_polygon = points
				touched = true

		if ADD_HOVER_COLLISION and tree.hover_polygon.is_empty():
			var hover_points := _collision_points(tile_set, source_id, atlas_coords, 1)
			if not hover_points.is_empty():
				tree.hover_polygon = _shift_points(hover_points, Vector2(0, -half))
				touched = true

		if touched:
			fixed += 1
	return fixed


## CONVERT pass — turn every remaining tree tile on the layer into an
## instance, then erase the tile.
func _convert_cells(root: Node, veg: TileMapLayer, tile_set: TileSet, painted: Node) -> int:
	var half := tile_set.tile_size.y / 2.0
	var to_erase: Array[Vector2i] = []
	var per_source := {}
	var oddities: Array[String] = []

	for coords in veg.get_used_cells():
		var source_id := veg.get_cell_source_id(coords)
		if source_id not in TREE_SOURCE_IDS:
			continue

		var src := tile_set.get_source(source_id) as TileSetAtlasSource
		if src == null:
			oddities.append("cell %s: source %d is not an atlas source, skipped" % [coords, source_id])
			continue

		var atlas_coords := veg.get_cell_atlas_coords(coords)
		var tile_data := veg.get_cell_tile_data(coords)
		var region := src.get_tile_texture_region(atlas_coords, 0)
		var origin := tile_data.texture_origin

		if region.size.x <= tile_set.tile_size.x and region.size.y <= tile_set.tile_size.y:
			oddities.append("cell %s: single-tile sprite (source %d, atlas %s) — converted, but may be a stray tile" % [coords, source_id, atlas_coords])

		var tree := TREE_SCENE.instantiate() as TreeProp
		tree.name = "PaintedTree_%d_%d" % [coords.x, coords.y]
		tree.art_region = region
		# Node origin sits at the trunk foot (cell bottom edge). The tile is
		# drawn centered on the cell then shifted by -texture_origin, so the
		# sprite's local offset is -origin - half a tile.
		tree.art_offset = Vector2(-origin.x, -origin.y - half)
		tree.swaying = tile_data.material == null

		var points := PackedVector2Array()
		if ADD_TRUNK_COLLISION:
			points = _polygon_from_tile_data(tile_data, 0)
		if points.is_empty():
			tree.trunk_enabled = false
		else:
			tree.trunk_offset = Vector2(0, -half)  # tile polygons are measured from the cell center

		tree.art_texture = src.texture
		if not points.is_empty():
			tree.trunk_polygon = points

		if ADD_HOVER_COLLISION:
			var hover_points := _polygon_from_tile_data(tile_data, 1)
			if not hover_points.is_empty():
				tree.hover_polygon = _shift_points(hover_points, Vector2(0, -half))

		painted.add_child(tree)
		tree.owner = root
		tree.global_position = veg.to_global(veg.map_to_local(coords) + Vector2(0, half))

		per_source[source_id] = int(per_source.get(source_id, 0)) + 1
		to_erase.append(coords)

	for dead_cell in to_erase:
		veg.erase_cell(dead_cell)

	if not to_erase.is_empty():
		for source_id in TREE_SOURCE_IDS:
			if per_source.has(source_id):
				print("  - source %d (%s): %d" % [source_id, _sheet_name(tile_set, source_id), per_source[source_id]])
	for line in oddities:
		print("  * " + line)
	return to_erase.size()


func _ensure_container(root: Node) -> Node2D:
	var container := root.get_node_or_null(CONTAINER_NAME) as Node2D
	if container == null:
		container = Node2D.new()
		container.name = CONTAINER_NAME
		root.add_child(container)
		container.owner = root
	var painted := container.get_node_or_null(PAINTED_NAME) as Node2D
	if painted == null:
		painted = Node2D.new()
		painted.name = PAINTED_NAME
		container.add_child(painted)
		painted.owner = root
	return painted


## `polygon_index` selects which polygon within physics layer 0: 0 is the
## trunk shape, 1 is the optional canopy/hover shape (see HOVER SHAPE
## AUTHORING above).
func _polygon_from_tile_data(tile_data: TileData, polygon_index: int = 0) -> PackedVector2Array:
	if tile_data == null or tile_data.get_collision_polygons_count(0) <= polygon_index:
		return PackedVector2Array()
	return tile_data.get_collision_polygon_points(0, polygon_index)


func _collision_points(tile_set: TileSet, source_id: int, atlas_coords: Vector2i, polygon_index: int = 0) -> PackedVector2Array:
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	if src == null or not src.has_tile(atlas_coords):
		return PackedVector2Array()
	return _polygon_from_tile_data(src.get_tile_data(atlas_coords, 0), polygon_index)


## Tile collision points come back relative to the cell's center; both
## `trunk_polygon` (via `trunk_offset`) and `hover_polygon` (no offset
## export of its own — see tree.gd) need them relative to the node
## origin (the cell's bottom edge) instead.
func _shift_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	shifted.resize(points.size())
	for i in points.size():
		shifted[i] = points[i] + offset
	return shifted


func _source_for(texture_file: String) -> int:
	match texture_file:
		"Size_02.png": return 2
		"Size_03.png": return 3
		"Size_04.png": return 4
		_: return 0


func _sheet_name(tile_set: TileSet, source_id: int) -> String:
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	if src and src.texture:
		return src.texture.resource_path.get_file()
	return "?"
