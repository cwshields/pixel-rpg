@tool
extends EditorScript
## One-shot converter: replaces the tree tiles painted into
## `World/TileMap/Vegitation` with real `tree.tscn` (TreeProp) instances so
## they pick up the player walk-behind + proximity-fade effect, which a
## TileMapLayer (one CanvasItem, no per-tile z_index/modulate) can never do.
##
## HOW TO RUN
##   1. Open `scenes/main.tscn` in the editor (it must be the active scene).
##   2. Open this file, then File ▸ Run (Ctrl+Shift+X).
##   3. Check the Output panel, eyeball the new `Trees/PaintedTrees` nodes.
##   4. Ctrl+S to keep it, or Ctrl+Z / `git checkout scenes/main.tscn` to bail.
##
## Re-running is safe: the tree cells are erased on the first pass, so a
## second run finds nothing to do. It also aborts if PaintedTrees already
## has children.

const TREE_SCENE := preload("res://scenes/world/tree.tscn")

## Vegitation TileSet sources that are tree sheets (Size_02/03/04).
## Source 1 is the grass/bush/flower atlas and is deliberately left alone.
const TREE_SOURCE_IDS: Array[int] = [2, 3, 4]

## Give each converted tree a trunk collider. Left OFF so movement through
## the map is unchanged from when these were plain tiles (which had no
## collision). Flip to true to match the hand-placed trees, then re-run on
## a fresh checkout.
const ADD_TRUNK_COLLISION := false

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
	if painted.get_child_count() > 0:
		push_error("[convert_painted_trees] %s/%s already has %d children — aborting so we don't double-convert. Delete it and re-run to redo." % [CONTAINER_NAME, PAINTED_NAME, painted.get_child_count()])
		return

	var half_tile := tile_set.tile_size.y / 2.0
	var per_source := {}
	var oddities: Array[String] = []
	var static_props := 0
	var to_erase: Array[Vector2i] = []

	for coords in veg.get_used_cells():
		var sid := veg.get_cell_source_id(coords)
		if sid not in TREE_SOURCE_IDS:
			continue

		var src := tile_set.get_source(sid) as TileSetAtlasSource
		if src == null:
			oddities.append("cell %s: source %d is not an atlas source, skipped" % [coords, sid])
			continue

		var atlas_coords := veg.get_cell_atlas_coords(coords)
		var tile_data := veg.get_cell_tile_data(coords)
		var region := src.get_tile_texture_region(atlas_coords, 0)
		var origin := tile_data.texture_origin

		if region.size.x <= tile_set.tile_size.x and region.size.y <= tile_set.tile_size.y:
			oddities.append("cell %s: single-tile sprite (source %d, atlas %s) — converted, but may be a stray tile" % [coords, sid, atlas_coords])

		var tree := TREE_SCENE.instantiate() as TreeProp
		tree.name = "PaintedTree_%d_%d" % [coords.x, coords.y]
		tree.art_region = region
		# Node origin sits at the trunk foot (cell bottom edge). The tile is
		# drawn centered on the cell then shifted by -texture_origin, so the
		# sprite's local offset is -origin - half a tile.
		tree.art_offset = Vector2(-origin.x, -origin.y - half_tile)
		tree.swaying = tile_data.material == null
		tree.trunk_enabled = ADD_TRUNK_COLLISION
		if ADD_TRUNK_COLLISION:
			tree.trunk_size = _trunk_size_for(sid)
		tree.art_texture = src.texture

		painted.add_child(tree)
		tree.owner = root
		tree.global_position = veg.to_global(veg.map_to_local(coords) + Vector2(0, half_tile))

		if not tree.swaying:
			static_props += 1
		per_source[sid] = int(per_source.get(sid, 0)) + 1
		to_erase.append(coords)

	for dead_cell in to_erase:
		veg.erase_cell(dead_cell)

	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()

	var total := to_erase.size()
	print("[convert_painted_trees] converted %d painted trees into %s/%s:" % [total, CONTAINER_NAME, PAINTED_NAME])
	for sid in TREE_SOURCE_IDS:
		if per_source.has(sid):
			print("  - source %d (%s): %d" % [sid, _sheet_name(tile_set, sid), per_source[sid]])
	if static_props > 0:
		print("  - %d had a static material (stumps) — kept non-swaying" % static_props)
	if not oddities.is_empty():
		print("  notes:")
		for line in oddities:
			print("    * " + line)
	if total == 0:
		print("  (nothing to do — already converted, or no tree tiles on the layer)")
	else:
		print("  Review the new nodes, then Ctrl+S to save. Undo with Ctrl+Z or `git checkout scenes/main.tscn`.")


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


func _trunk_size_for(source_id: int) -> Vector2:
	match source_id:
		4: return Vector2(20, 10)
		3: return Vector2(13, 9)
		_: return Vector2(9, 8)


func _sheet_name(tile_set: TileSet, source_id: int) -> String:
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	if src and src.texture:
		return src.texture.resource_path.get_file()
	return "?"
