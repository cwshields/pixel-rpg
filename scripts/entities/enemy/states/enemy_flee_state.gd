class_name EnemyFleeState
extends State
## Runs away from the player after a growl timeout expires. Sprints in the
## opposite direction for `flee_duration` seconds, then returns to Idle.
## If the player closes in during the flee (enters DetectionArea), the
## enemy turns and fights instead.

@export var flee_duration: float = 3.0

var _timer: float = 0.0
var _direction: Vector2 = Vector2.ZERO

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	var enemy := entity as EnemyBase
	entity.sprinting = true
	_timer = 0.0
	var away_from: Node2D = enemy.alert_target if enemy.alert_target else enemy.target
	if away_from:
		_direction = (entity.global_position - away_from.global_position).normalized()
	else:
		_direction = Vector2.RIGHT.rotated(randf() * TAU)

func exit() -> void:
	entity.sprinting = false

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	if enemy.target:
		transition_requested.emit(&"Chase", {})
		return
	_timer += delta
	if _timer >= flee_duration:
		transition_requested.emit(&"Idle", {})
		return
	if entity.is_stuck():
		_direction = _direction.rotated(PI * 0.5)
	entity.move(entity.steer_direction(_direction, []), delta)
	entity.play_animation("walk")
