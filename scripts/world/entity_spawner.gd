@tool
class_name EntitySpawner
extends Marker2D
## A world-placed spawn point for entities (enemies, critters, or
## anything else with a CharacterBody2D root). Drop one into a scene,
## point `entity_scene` at any .tscn whose root extends EntityBase, and
## it spawns a batch when the level loads. Set `max_alive` above 0 to
## have it refill that batch over time as entities die, turning a marker
## into a continuously-populated encounter or wildlife patch.
##
## Spawned entities are parented to `spawn_into` — or this spawner's own
## parent when that's left empty — so they live alongside the rest of the
## world's entities rather than nested under the marker.

@export var entity_scene: PackedScene:
	set(value):
		entity_scene = value
		if Engine.is_editor_hint():
			_update_preview()

@export_group("Editor Preview")
@export var preview_animation: StringName = &"":
	set(value):
		preview_animation = value
		if Engine.is_editor_hint():
			_update_preview()
@export var preview_frame: int = 0:
	set(value):
		preview_frame = value
		if Engine.is_editor_hint():
			_update_preview()

@export_group("Spawning")
## How many entities the initial batch contains (and the number
## `max_alive` refilling tops back up toward).
@export_range(1, 50) var spawn_count: int = 1
## Each entity is placed at a random point within this many pixels of
## the marker. 0 stacks them all exactly on it.
@export var spawn_radius: float = 48.0
## Spawn the initial batch automatically when the spawner enters the tree.
## Turn off to fire it yourself by calling `spawn_batch()`.
@export var spawn_on_ready: bool = true

@export_group("Respawning")
## 0 disables respawning — the initial batch is all you get. Above 0, the
## spawner keeps topping the live count back up to this number.
@export_range(0, 50) var max_alive: int = 0
## Seconds between refill checks while the live count is below `max_alive`.
@export var respawn_delay: float = 5.0

## Node to parent spawned entities under. Falls back to this spawner's
## own parent when left unset.
@export var spawn_into: Node2D

## Entities this spawner has produced that are still in the tree.
var _alive: Array[Node] = []
var _preview_sprite: Sprite2D

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_preview()
		return
	if max_alive > 0:
		var timer := Timer.new()
		timer.wait_time = maxf(respawn_delay, 0.05)
		timer.autostart = true
		timer.timeout.connect(_on_respawn_tick)
		add_child(timer)
	if spawn_on_ready:
		spawn_batch.call_deferred()

## Spawns up to `spawn_count` entities now, never pushing the live count
## past `max_alive` while that cap is active. Returns how many spawned.
@warning_ignore("unreachable_code")
func spawn_batch() -> int:
	if Engine.is_editor_hint():
		return 0
	var budget: int = spawn_count
	if max_alive > 0:
		budget = mini(budget, max_alive - _alive.size())
	var spawned: int = 0
	for _i in maxi(budget, 0):
		if _spawn_one():
			spawned += 1
	return spawned

func _on_respawn_tick() -> void:
	if _alive.size() < max_alive:
		_spawn_one()

func _spawn_one() -> bool:
	if not entity_scene:
		push_warning("EntitySpawner at %s has no entity_scene set." % global_position)
		return false
	var entity := entity_scene.instantiate() as Node2D
	if not entity:
		push_warning("EntitySpawner: entity_scene's root isn't a Node2D.")
		return false
	var parent: Node = spawn_into if spawn_into else get_parent()
	parent.add_child(entity)
	entity.global_position = _random_point()
	var ai := entity as AIEntityBase
	if ai:
		ai.anchor_position = entity.global_position
	_alive.append(entity)
	entity.tree_exited.connect(_on_entity_gone.bind(entity))
	return true

func _on_entity_gone(entity: Node) -> void:
	_alive.erase(entity)

func _random_point() -> Vector2:
	if spawn_radius <= 0.0:
		return global_position
	var angle: float = randf() * TAU
	var dist: float = sqrt(randf()) * spawn_radius
	return global_position + Vector2(cos(angle), sin(angle)) * dist

# --- Editor preview ---

func _update_preview() -> void:
	if not is_inside_tree():
		return
	if _preview_sprite:
		_preview_sprite.texture = null
	if not entity_scene:
		return
	var tex := _extract_frame(entity_scene, preview_animation, preview_frame)
	if not tex:
		return
	if not _preview_sprite:
		_preview_sprite = Sprite2D.new()
		_preview_sprite.modulate = Color(1, 1, 1, 0.6)
		add_child(_preview_sprite)
		_preview_sprite.owner = null
	_preview_sprite.texture = tex

static func _extract_frame(scene: PackedScene, anim_override: StringName, frame_idx: int) -> Texture2D:
	var state := scene.get_state()
	var sf: SpriteFrames
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"sprite_frames":
			sf = state.get_node_property_value(0, i)
			break
	if not sf:
		for node_idx in state.get_node_count():
			for prop_idx in state.get_node_property_count(node_idx):
				if state.get_node_property_name(node_idx, prop_idx) == &"sprite_frames":
					sf = state.get_node_property_value(node_idx, prop_idx)
					break
			if sf:
				break
	if not sf:
		return null
	var anim: StringName
	if anim_override != &"" and sf.has_animation(anim_override):
		anim = anim_override
	elif sf.has_animation(&"idle"):
		anim = &"idle"
	else:
		anim = StringName(sf.get_animation_names()[0])
	var clamped := clampi(frame_idx, 0, sf.get_frame_count(anim) - 1)
	return sf.get_frame_texture(anim, clamped)
