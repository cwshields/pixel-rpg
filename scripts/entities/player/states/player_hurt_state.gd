class_name PlayerHurtState
extends State

static var _hurt_streams: Array[AudioStream] = [
	preload("res://assets/SoundFX/Player/hurt-3457.mp3"),
	preload("res://assets/SoundFX/Player/hurt-ough-47202.mp3"),
	preload("res://assets/SoundFX/Player/umph-47201.mp3"),
	preload("res://assets/SoundFX/Player/grunt2.mp3"),
]

## Tuned to the Hit animation (4 frames @ 10fps = 0.4s).
@export var hurt_duration: float = 0.4
@export var knockback_decay: float = 600.0

var _timer: float = 0.0
var _active_sfx: AudioStreamPlayer2D = null

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	entity.play_animation("hurt")
	_play_hurt_sfx()

func exit() -> void:
	if is_instance_valid(_active_sfx) and _active_sfx.playing:
		_active_sfx.stop()
		_active_sfx.queue_free()
	_active_sfx = null

func process_physics(delta: float) -> void:
	_timer += delta
	entity.velocity = entity.velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	entity.move_and_slide()
	if _timer >= hurt_duration:
		transition_requested.emit(&"Idle", {})

func _play_hurt_sfx() -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = _hurt_streams.pick_random()
	sfx.bus = &"Voice"
	entity.add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
	_active_sfx = sfx
