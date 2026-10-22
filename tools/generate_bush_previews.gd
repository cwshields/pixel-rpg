@tool
extends EditorScript
## One-shot: forces the editor to generate thumbnail previews for every
## bush variant scene so they show up in the BushTiles tile palette.
##
## Run via File ▸ Run (Ctrl+Shift+X) with any scene open.

const BUSHES_DIR := "res://scenes/world/bushes/"

func _run() -> void:
	var previewer := EditorInterface.get_resource_previewer()
	var dir := DirAccess.open(BUSHES_DIR)
	if dir == null:
		push_error("[generate_bush_previews] Cannot open %s" % BUSHES_DIR)
		return

	var count := 0
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var path := BUSHES_DIR + file
		previewer.queue_resource_preview(path, self, "_preview_done", path)
		count += 1

	print("[generate_bush_previews] Queued %d scene previews. They'll appear in the tile palette shortly." % count)

func _preview_done(path: String, preview: Texture2D, thumbnail: Texture2D, userdata: Variant) -> void:
	if preview:
		print("  ✓ %s" % userdata)
	else:
		print("  ✗ %s (no preview generated)" % userdata)
