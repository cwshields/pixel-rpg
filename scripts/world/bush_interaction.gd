extends Node2D
## Runtime converter: replaces Source-1 (Vegetation.png) bush tiles from the
## Vegitation TileMapLayer with BushProp scene instances so they get the
## depth-sort/fade effect, walk-through shake, and rustle sound.

const BUSH_SCENE := preload("res://scenes/world/bush.tscn")
const BUSH_SOURCE_ID := 1

func _ready() -> void:
	var veg := get_node_or_null("../Vegitation") as TileMapLayer
	if veg == null:
		print("[BushInteraction] Vegitation layer not found")
		return
	var tile_set := veg.tile_set
	if tile_set == null:
		print("[BushInteraction] No TileSet on Vegitation layer")
		return
	var src := tile_set.get_source(BUSH_SOURCE_ID) as TileSetAtlasSource
	if src == null:
		print("[BushInteraction] Source %d not found in TileSet" % BUSH_SOURCE_ID)
		# List available sources
		for i in tile_set.get_source_count():
			var sid := tile_set.get_source_id(i)
			print("  source id %d: %s" % [sid, tile_set.get_source(sid)])
		return

	var half := tile_set.tile_size.y / 2.0
	var to_erase: Array[Vector2i] = []
	var used := veg.get_used_cells()
	print("[BushInteraction] Vegitation layer has %d used cells, tile_size=%s" % [used.size(), tile_set.tile_size])

	var source_counts := {}
	for coords in used:
		var sid := veg.get_cell_source_id(coords)
		source_counts[sid] = int(source_counts.get(sid, 0)) + 1

	print("[BushInteraction] Cells by source_id: %s" % [source_counts])

	for coords in used:
		if veg.get_cell_source_id(coords) != BUSH_SOURCE_ID:
			continue

		var atlas_coords := veg.get_cell_atlas_coords(coords)
		var tile_data := veg.get_cell_tile_data(coords)
		var region := src.get_tile_texture_region(atlas_coords, 0)
		var origin := tile_data.texture_origin if tile_data else Vector2i.ZERO

		var bush := BUSH_SCENE.instantiate() as BushProp
		bush.art_texture = src.texture
		bush.art_region = region
		bush.art_offset = Vector2(-origin.x, -origin.y - half)

		add_child(bush)
		bush.global_position = veg.to_global(veg.map_to_local(coords) + Vector2(0, half))
		to_erase.append(coords)

	for cell in to_erase:
		veg.erase_cell(cell)

	print("[BushInteraction] Converted %d bush tiles to BushProp nodes" % to_erase.size())
