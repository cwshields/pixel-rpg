@tool
class_name OccluderProp
extends Node2D
## Marker/interface base for world props that get player-relative depth
## sorting through the `Foliage` autoload (see foliage_manager.gd) — today
## that's `TreeProp` and `RockProp`. Beyond the shared depth constant below,
## this class carries no shared state or logic of its own; it exists only
## so the manager can hold one typed array across every kind of prop and
## call the same three methods on whichever one it's holding. Each
## subclass implements its own version.

## Player.tscn's root z_index is set to this same value at runtime (see
## Player._ready()) so every OccluderProp has one shared baseline to sit
## exactly one step above or below the player. Single source of truth —
## previously this was three independently hand-synced constants (one per
## subclass plus a hardcoded value in player.tscn), which is exactly how
## the player/tree z-index drift bug happened.
const PLAYER_Z_INDEX := 4

## Editor-only: replaces this prop, in the scene being edited, with an
## instance of a random *other* variant scene from `variant_dir` (a folder
## of scenes inheriting this prop's base scene), keeping its name, transform
## and place in the parent. Backs the "Randomize Variant" inspector button
## on TreeProp/RockProp. Done through the editor's undo/redo so Ctrl+Z
## restores the original node. Removing a node strips its `owner` (it no
## longer sits under the scene root), so owner is re-set on both sides —
## without it the node wouldn't be saved.
##
## `@tool` on this base script exists only so this runs from the
## subclasses' tool buttons; nothing else here does anything in the editor.
func swap_for_random_variant(variant_dir: String) -> void:
	if not Engine.is_editor_hint():
		return
	var root := EditorInterface.get_edited_scene_root()
	var parent := get_parent()
	if root == null or self == root or parent == null:
		push_warning("%s: open a scene that contains this prop to randomize it." % name)
		return

	# A prop that's already a variant stays within its own folder's category
	# (e.g. rocks/ruins/ only swaps among ruins); anything else — a plain
	# base-scene instance — picks from the top-level `variant_dir`.
	var dir := variant_dir
	if scene_file_path.begins_with(variant_dir):
		dir = scene_file_path.get_base_dir() + "/"

	var paths: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "tscn" and dir + file != scene_file_path:
			paths.append(dir + file)
	if paths.is_empty():
		push_warning("%s: no other variant scenes in %s." % [name, dir])
		return

	var scene: PackedScene = load(paths.pick_random())
	var replacement := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	replacement.name = name
	replacement.transform = transform
	var index := get_index()

	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Randomize Variant")
	undo.add_do_method(parent, "remove_child", self)
	undo.add_do_method(parent, "add_child", replacement)
	undo.add_do_method(parent, "move_child", replacement, index)
	undo.add_do_property(replacement, "owner", root)
	undo.add_do_reference(replacement)
	undo.add_undo_method(parent, "remove_child", replacement)
	undo.add_undo_method(parent, "add_child", self)
	undo.add_undo_method(parent, "move_child", self, index)
	undo.add_undo_property(self, "owner", root)
	undo.add_undo_reference(self)
	undo.commit_action()

	# The inspector is still showing this (now removed) node.
	EditorInterface.edit_node(replacement)

## Called every frame by Foliage while the player is within its active
## radius. Subclasses use this to flip z_index (and anything else, e.g.
## TreeProp's proximity fade) based on `player_pos`.
func update_proximity(_player_pos: Vector2, _delta: float) -> void:
	pass

## Called once, the frame Foliage drops this prop from the active set
## (player moved out of range). Subclasses should snap back to their
## resting z_index/alpha/etc.
func reset_proximity() -> void:
	pass

## Whether this prop is still mid-effect (flip/fade) and therefore needs
## its `reset_proximity()` call rather than being silently dropped.
func is_proximity_active() -> bool:
	return false
