@tool
class_name OccluderProp
extends Node2D
## Base for world props that get player-relative depth sorting through the
## `Foliage` autoload (see foliage_manager.gd). Today that's `TreeProp`,
## `RockProp` (via `BreakableProp`), and standalone `OccluderSprite`
## instances.
##
## Shared across all prop types: Foliage registration, the depth-sort
## baseline z_index, proximity-fade parameters, and FadeArea overlap
## tracking. Each concrete subclass or intermediate (`BreakableProp`,
## `OccluderSprite`) implements its own `update_proximity()` /
## `reset_proximity()`.

## Player.tscn's root z_index matches this at runtime so every OccluderProp
## sits exactly one step above or below the player.
const PLAYER_Z_INDEX := 4

@export_group("Depth Sorting")
## Vertical distance from the player's node origin down to their visual
## feet. Corrects the "who's lower" compare for centered sprites.
@export var player_feet_offset: float = 18.0

@export_group("Occlusion Fade")
## Alpha the prop eases down to while the player is inside its FadeArea.
@export_range(0.0, 1.0) var faded_alpha: float = 0.5
## Alpha-units / second toward the target.
@export var fade_speed: float = 4.0

var _target_alpha: float = 1.0
var _active: bool = false
## Whether the player's body currently overlaps this prop's FadeArea —
## kept in sync by body_entered / body_exited signals, not per-frame math.
var _player_in_fade_area: bool = false

# ---------------------------------------------------------------------------
# Lifecycle — Foliage registration
# ---------------------------------------------------------------------------

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	Foliage.register_prop(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	Foliage.unregister_prop(self)

# ---------------------------------------------------------------------------
# FadeArea overlap tracking (shared signal handlers)
# ---------------------------------------------------------------------------

func _on_fade_area_body_entered(body: Node) -> void:
	if body == GameManager.player:
		_player_in_fade_area = true

func _on_fade_area_body_exited(body: Node) -> void:
	if body == GameManager.player:
		_player_in_fade_area = false

# ---------------------------------------------------------------------------
# Editor variant swap
# ---------------------------------------------------------------------------

## Replaces this prop with a random variant scene from `variant_dir`.
## Editor-only, undoable. Done through undo/redo so Ctrl+Z restores the
## original node.
func swap_for_random_variant(variant_dir: String) -> void:
	if not Engine.is_editor_hint():
		return
	var root := EditorInterface.get_edited_scene_root()
	var parent := get_parent()
	if root == null or self == root or parent == null:
		push_warning("%s: open a scene that contains this prop to randomize it." % name)
		return

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

	EditorInterface.edit_node(replacement)

# ---------------------------------------------------------------------------
# Proximity — called by Foliage each frame while the player is nearby.
# Subclasses override with their own depth-sort and fade logic.
# ---------------------------------------------------------------------------

func update_proximity(_player_pos: Vector2, _delta: float) -> void:
	pass

func reset_proximity() -> void:
	pass

func is_proximity_active() -> bool:
	return false
