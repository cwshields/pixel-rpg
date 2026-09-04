class_name PlayerHurtState
extends State

## Tuned to the Hit animation (4 frames @ 10fps = 0.4s).
@export var hurt_duration: float = 0.4
@export var knockback_decay: float = 600.0

var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	entity.play_animation("hurt")

func process_physics(delta: float) -> void:
	_timer += delta
	entity.velocity = entity.velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	entity.move_and_slide()
	if _timer >= hurt_duration:
		transition_requested.emit(&"Idle", {})
