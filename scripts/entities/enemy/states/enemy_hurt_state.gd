class_name EnemyHurtState
extends State

@export var hurt_duration: float = 0.3

var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	entity.play_animation("hurt")

func process_physics(delta: float) -> void:
	_timer += delta
	entity.move(Vector2.ZERO, delta)
	if _timer >= hurt_duration:
		var enemy := entity as EnemyBase
		transition_requested.emit(&"Chase" if enemy.target else &"Idle", {})
