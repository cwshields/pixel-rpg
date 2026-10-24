@tool
class_name BushProp
extends BreakableProp
## A vegetation bush — walkable (no blocking collision), slows entities by
## 40% while inside, depth-sorts and fades like trees/rocks, rustles on
## walk-through, and can be destroyed by any attack.
##
## Bush variations live as inherited scenes in `VARIANT_DIR`
## (`scenes/world/bushes/`).

const VARIANT_DIR := "res://scenes/world/bushes/"
const SLOW_AMOUNT := -0.3

var _rustle_sound: AudioStream = preload("res://assets/SoundFX/Foliage/leaves-rustling.mp3")
@onready var _rustle_player: AudioStreamPlayer2D = get_node_or_null("RustleSoundPlayer")

var _slow_source_id: StringName
var _slowed_entities: Array[EntityBase] = []
var _rustle_cooldown: float = 0.0

@export_group("Art")
@export var swaying: bool = true:
	set(value):
		swaying = value
		_apply_art()

@export_tool_button("Randomize Variant") var _randomize_variant_button = _randomize_variant

func _init() -> void:
	_hit_particle_color = Color(0.42, 0.55, 0.28)
	_break_fragment_color = Color(0.35, 0.52, 0.22)

func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		_slow_source_id = StringName("bush_slow_%d" % get_instance_id())

func _randomize_variant() -> void:
	swap_for_random_variant(VARIANT_DIR)

func _post_apply_art(s: Sprite2D) -> void:
	if not swaying and s.material != null:
		s.material = null

func _apply_body_collision() -> void:
	pass

# ---------------------------------------------------------------------------
# FadeArea — walk-through rustle + slowdown on top of base fade tracking
# ---------------------------------------------------------------------------

func _on_fade_area_body_entered(body: Node) -> void:
	super._on_fade_area_body_entered(body)
	if Engine.is_editor_hint():
		return
	if body is EntityBase:
		_try_rustle()
		_apply_slow(body as EntityBase)

func _on_fade_area_body_exited(body: Node) -> void:
	super._on_fade_area_body_exited(body)
	if body is EntityBase:
		_remove_slow(body as EntityBase)

# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

func _on_damaged(amount: float, source: Node) -> void:
	super._on_damaged(amount, source)
	_play_rustle()

func _animate_death() -> void:
	_clear_all_slows()
	if sprite:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_property(sprite, "scale", sprite.scale * 0.5, 0.3) \
				.set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
	else:
		queue_free()

# ---------------------------------------------------------------------------
# Slowdown
# ---------------------------------------------------------------------------

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_clear_all_slows()

func _clear_all_slows() -> void:
	for entity in _slowed_entities:
		if is_instance_valid(entity) and entity.stats:
			entity.stats.remove_modifier(&"speed_multiplier", _slow_source_id)
	_slowed_entities.clear()

func _apply_slow(entity: EntityBase) -> void:
	if entity.stats and entity not in _slowed_entities:
		entity.stats.add_modifier(&"speed_multiplier", SLOW_AMOUNT, _slow_source_id)
		_slowed_entities.append(entity)

func _remove_slow(entity: EntityBase) -> void:
	_slowed_entities.erase(entity)
	if is_instance_valid(entity) and entity.stats:
		entity.stats.remove_modifier(&"speed_multiplier", _slow_source_id)

# ---------------------------------------------------------------------------
# Rustle
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_rustle_cooldown = maxf(_rustle_cooldown - delta, 0.0)

func _try_rustle() -> void:
	if _rustle_cooldown > 0.0:
		return
	_rustle_cooldown = 0.5
	_shake(2.0)
	_play_rustle()

func _play_rustle() -> void:
	if not _rustle_player:
		return
	_rustle_player.stream = _rustle_sound
	_rustle_player.pitch_scale = randf_range(0.85, 1.15)
	_rustle_player.volume_db = -10.0
	_rustle_player.play()
