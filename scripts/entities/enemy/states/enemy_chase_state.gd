class_name EnemyChaseState
extends State

@export var attack_range: float = 20.0

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	if not enemy.target:
		transition_requested.emit(&"Idle", {})
		return
	var to_target: Vector2 = enemy.target.global_position - entity.global_position
	if to_target.length() <= attack_range:
		transition_requested.emit(&"Attack", {})
		return
	entity.move(entity.steer_direction(to_target.normalized(), [enemy.target]), delta)
	entity.play_animation("walk")
