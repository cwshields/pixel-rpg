@tool
extends EditorScript
## Builds (or rebuilds) the Scene Collection TileSet used to paint rocks
## directly as nodes.  Run once after adding new variant scenes to
## `scenes/world/rocks/`, then open the RockTiles TileMapLayer in
## main.tscn to paint with the updated palette.
##
## HOW TO RUN
##   1. Open this file in the Script Editor.
##   2. File ▸ Run (Ctrl+Shift+X).
##   3. Check the Output panel — the new tileset is saved automatically.

const VARIANT_DIR := "res://scenes/world/rocks/"
const BASE_ROCK := "res://scenes/world/rock.tscn"
const OUTPUT_PATH := "res://resources/tilesets/rock_scenes.tres"
const TILE_SIZE := Vector2i(16, 16)

func _run() -> void:
	var scenes := _collect_scenes()
	if scenes.is_empty():
		push_error("[setup_rock_scene_tileset] No rock scenes found.")
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE

	var source := TileSetScenesCollectionSource.new()
	var id := 0
	for path in scenes:
		var scene := load(path) as PackedScene
		if scene:
			source.create_scene_tile(scene, id)
			id += 1

	tile_set.add_source(source, 0)

	var dir := OUTPUT_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var err := ResourceSaver.save(tile_set, OUTPUT_PATH)
	if err != OK:
		push_error("[setup_rock_scene_tileset] Failed to save: %s" % error_string(err))
		return

	print("[setup_rock_scene_tileset] Saved %s with %d scene tile(s)." % [OUTPUT_PATH, id])
	for i in scenes.size():
		print("  %d: %s" % [i, scenes[i]])


func _collect_scenes() -> Array[String]:
	var result: Array[String] = []
	result.append(BASE_ROCK)
	_scan_dir(VARIANT_DIR, result)
	return result


func _scan_dir(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			_scan_dir(dir_path.path_join(file_name), out)
		elif file_name.ends_with(".tscn"):
			out.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
