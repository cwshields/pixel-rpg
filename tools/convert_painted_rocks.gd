@tool
extends EditorScript
## One-shot converter: replaces the rock tiles painted into `World/Rocks`
## with real `rock.tscn` (RockProp) instances so they pick up the player
## walk-behind depth sort, which a TileMapLayer (one CanvasItem, no
## per-tile z_index) can never do. Mirrors `convert_painted_trees.gd` —
## see that file for the fuller write-up of the technique.
##
## HOW TO RUN
##   1. Open `scenes/main.tscn` in the editor (it must be the active scene).
##   2. `World` now lives in `scenes/world/world.scn` and is instanced into
##      main.tscn — right-click the `World` node in the Scene dock and enable
##      "Editable Children" so this script can reach and edit `World/Rocks`
##      (erasing its converted tiles) through the instance. Without this the
##      tile erasure won't survive a save.
##   3. Open this file, then File ▸ Run (Ctrl+Shift+X).
##   4. Check the Output panel, eyeball the new `RockProps` nodes.
##   5. Ctrl+S to keep it, or Ctrl+Z / `git checkout scenes/main.tscn` to bail.
##
## Safe to run repeatedly. It does two idempotent passes:
##   * REPAIR — every existing `PaintedRock_*` that is missing its collision
##     gets it back (rebuilt from the matching tileset tile's own physics
##     polygon).
##   * CONVERT — any rock tiles still on the layer are turned into instances
##     and erased.
## A clean checkout hits only CONVERT; a scene from an earlier (collision-
## less) run hits only REPAIR.

const ROCK_SCENE := preload("res://scenes/world/rock.tscn")

## World/Rocks TileSet sources that are rock sheets. There's only the one
## today (Rock-ruins.png); add more here if a second rock sheet shows up.
const ROCK_SOURCE_IDS: Array[int] = [0]

## Carry each tile's collision polygon onto its instance. Off = the
## converted rocks are purely visual.
const ADD_COLLISION := true

const ROCKS_LAYER_PATH := "World/Rocks"
const CONTAINER_NAME := "RockProps"

func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("[convert_painted_rocks] No scene open. Open scenes/main.tscn first.")
		return

	var rocks := root.get_node_or_null(ROCKS_LAYER_PATH) as TileMapLayer
	if rocks == null:
		push_error("[convert_painted_rocks] %s not found under the open scene." % ROCKS_LAYER_PATH)
		return

	var tile_set := rocks.tile_set
	if tile_set == null:
		push_error("[convert_painted_rocks] Rocks layer has no TileSet.")
		return

	var container := _ensure_container(root)

	var repaired := _repair_existing(container, tile_set)
	var converted := _convert_cells(root, rocks, tile_set, container)

	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()

	print("[convert_painted_rocks] repaired %d existing instance(s), converted %d tile(s)." % [repaired, converted])
	if repaired == 0 and converted == 0:
		print("  nothing to do — everything already converted with collision intact.")
	else:
		print("  Review %s, then Ctrl+S. Undo with Ctrl+Z or `git checkout scenes/main.tscn`." % CONTAINER_NAME)


## REPAIR pass — give any collision-less `PaintedRock_*` its collision back,
## reconstructed from the tileset tile its Art overrides point at.
func _repair_existing(container: Node, tile_set: TileSet) -> int:
	var half := tile_set.tile_size.y / 2.0
	var fixed := 0
	for rock in container.get_children():
		if not (rock is RockProp) or not String(rock.name).begins_with("PaintedRock_"):
			continue
		if rock.art_texture == null:
			continue

		var shape_node := rock.get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
		var already_fixed := shape_node and shape_node.shape is ConvexPolygonShape2D and not shape_node.disabled
		if already_fixed:
			continue

		var atlas_coords := Vector2i(rock.art_region.position) / tile_set.tile_size
		var points := _collision_points(tile_set, 0, atlas_coords)
		if points.is_empty():
			if rock.collision_enabled:
				rock.collision_enabled = false
				fixed += 1
			continue

		rock.collision_offset = Vector2(0, -half)
		rock.collision_enabled = true
		rock.collision_polygon = points
		fixed += 1
	return fixed


## CONVERT pass — turn every remaining rock tile on the layer into an
## instance, then erase the tile.
func _convert_cells(root: Node, rocks: TileMapLayer, tile_set: TileSet, container: Node) -> int:
	var half := tile_set.tile_size.y / 2.0
	var to_erase: Array[Vector2i] = []
	var count := 0
	var oddities: Array[String] = []

	for coords in rocks.get_used_cells():
		var source_id := rocks.get_cell_source_id(coords)
		if source_id not in ROCK_SOURCE_IDS:
			continue

		var src := tile_set.get_source(source_id) as TileSetAtlasSource
		if src == null:
			oddities.append("cell %s: source %d is not an atlas source, skipped" % [coords, source_id])
			continue

		var atlas_coords := rocks.get_cell_atlas_coords(coords)
		var tile_data := rocks.get_cell_tile_data(coords)
		var region := src.get_tile_texture_region(atlas_coords, 0)
		var origin := tile_data.texture_origin

		var rock := ROCK_SCENE.instantiate() as RockProp
		rock.name = "PaintedRock_%d_%d" % [coords.x, coords.y]
		rock.art_region = region
		# Node origin sits at the rock's base (cell bottom edge). The tile is
		# drawn centered on the cell then shifted by -texture_origin, so the
		# sprite's local offset is -origin - half a tile.
		rock.art_offset = Vector2(-origin.x, -origin.y - half)

		var points := PackedVector2Array()
		if ADD_COLLISION:
			points = _polygon_from_tile_data(tile_data)
		if points.is_empty():
			rock.collision_enabled = false
		else:
			rock.collision_offset = Vector2(0, -half)  # tile polygons are measured from the cell center

		rock.art_texture = src.texture
		if not points.is_empty():
			rock.collision_polygon = points

		container.add_child(rock)
		rock.owner = root
		rock.global_position = rocks.to_global(rocks.map_to_local(coords) + Vector2(0, half))

		count += 1
		to_erase.append(coords)

	for dead_cell in to_erase:
		rocks.erase_cell(dead_cell)

	for line in oddities:
		print("  * " + line)
	return count


func _ensure_container(root: Node) -> Node2D:
	var container := root.get_node_or_null(CONTAINER_NAME) as Node2D
	if container == null:
		container = Node2D.new()
		container.name = CONTAINER_NAME
		container.y_sort_enabled = true
		root.add_child(container)
		container.owner = root
	return container


func _polygon_from_tile_data(tile_data: TileData) -> PackedVector2Array:
	if tile_data == null or tile_data.get_collision_polygons_count(0) <= 0:
		return PackedVector2Array()
	return tile_data.get_collision_polygon_points(0, 0)


func _collision_points(tile_set: TileSet, source_id: int, atlas_coords: Vector2i) -> PackedVector2Array:
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	if src == null or not src.has_tile(atlas_coords):
		return PackedVector2Array()
	return _polygon_from_tile_data(src.get_tile_data(atlas_coords, 0))
