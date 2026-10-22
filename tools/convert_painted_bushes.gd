@tool
extends EditorScript
## One-shot converter: replaces the multi-cell bush tiles painted into
## `World/TileMap/Vegitation` with real `bush.tscn` (BushProp) instances so
## they pick up depth-sort, occlusion-fade, walk-through rustle, slowdown,
## and can be attacked/destroyed. Mirrors `convert_painted_trees.gd`.
##
## HOW TO RUN
##   1. Open `scenes/main.tscn` in the editor (it must be the active scene).
##   2. Right-click `World` in the Scene dock → "Editable Children" so this
##      script can reach `World/TileMap/Vegitation`.
##   3. Open this file, then File ▸ Run (Ctrl+Shift+X).
##   4. Check the Output panel, eyeball the new `BushProps` nodes.
##   5. Ctrl+S to keep it, or Ctrl+Z to bail.
##   6. Remove the `BushInteraction` node from `World/TileMap` — it's
##      superseded by these scene instances.
##
## Safe to run repeatedly — idempotent CONVERT pass.
## Only converts tiles where both atlas dimensions >= 2 (the actual bushes).
## 1×1 grass/flowers and 1×2 tall grass stay in the TileMapLayer.

const BUSH_SCENE := preload("res://scenes/world/bush.tscn")

## Source ID for Vegetation.png in TileSet_st1fa (the Vegitation layer's
## TileSet). Trees are sources 2/3/4 and were already converted separately.
const BUSH_SOURCE_ID := 1

## Minimum tile dimensions (in atlas cells) to convert. Tiles smaller than
## this in either dimension are grass/flowers and stay in the TileMapLayer.
const MIN_TILE_SIZE := Vector2i(2, 2)

const VEGITATION_PATH := "World/TileMap/Vegitation"
const CONTAINER_NAME := "BushProps"

func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("[convert_painted_bushes] No scene open. Open scenes/main.tscn first.")
		return

	var veg := root.get_node_or_null(VEGITATION_PATH) as TileMapLayer
	if veg == null:
		push_error("[convert_painted_bushes] %s not found. Enable Editable Children on World." % VEGITATION_PATH)
		return

	var tile_set := veg.tile_set
	if tile_set == null:
		push_error("[convert_painted_bushes] Vegitation layer has no TileSet.")
		return

	var src := tile_set.get_source(BUSH_SOURCE_ID) as TileSetAtlasSource
	if src == null:
		push_error("[convert_painted_bushes] Source %d not found in TileSet." % BUSH_SOURCE_ID)
		return

	var tile_size := tile_set.tile_size
	var container := _ensure_container(root)

	var to_erase: Array[Vector2i] = []
	var converted := 0
	var skipped_small := 0

	for coords in veg.get_used_cells():
		if veg.get_cell_source_id(coords) != BUSH_SOURCE_ID:
			continue

		var atlas_coords := veg.get_cell_atlas_coords(coords)
		if not src.has_tile(atlas_coords):
			continue

		var size := src.get_tile_size_in_atlas(atlas_coords)
		if size.x < MIN_TILE_SIZE.x or size.y < MIN_TILE_SIZE.y:
			skipped_small += 1
			continue

		var tile_data := veg.get_cell_tile_data(coords)
		var region := src.get_tile_texture_region(atlas_coords, 0)
		var origin: Vector2i = tile_data.texture_origin if tile_data else Vector2i.ZERO

		var bush := BUSH_SCENE.instantiate() as BushProp
		bush.name = "PaintedBush_%d_%d" % [coords.x, coords.y]
		bush.art_texture = src.texture
		bush.art_region = region
		bush.art_offset = Vector2(-origin.x, -origin.y - region.size.y / 2.0)

		# Dead/static bushes that had their per-tile material overridden
		if tile_data and tile_data.material != null:
			bush.swaying = false

		container.add_child(bush)
		bush.owner = root

		# Position at bottom-center of the multi-cell tile footprint.
		# map_to_local gives center of the top-left cell.
		var offset := Vector2(
			(size.x - 1) * tile_size.x / 2.0,
			(size.y - 0.5) * tile_size.y
		)
		bush.global_position = veg.to_global(veg.map_to_local(coords) + offset)

		converted += 1
		to_erase.append(coords)

	for cell in to_erase:
		veg.erase_cell(cell)

	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()

	print("[convert_painted_bushes] Converted %d bush tile(s), skipped %d small tile(s)." % [converted, skipped_small])
	if converted == 0:
		print("  Nothing to convert — bushes may already be converted, or no multi-cell tiles found.")
	else:
		print("  Review %s, then Ctrl+S. Undo with Ctrl+Z." % CONTAINER_NAME)
		print("  Don't forget to remove TileMap/BushInteraction — it's superseded.")


func _ensure_container(root: Node) -> Node2D:
	var container := root.get_node_or_null(CONTAINER_NAME) as Node2D
	if container == null:
		container = Node2D.new()
		container.name = CONTAINER_NAME
		container.y_sort_enabled = true
		root.add_child(container)
		container.owner = root
	return container
