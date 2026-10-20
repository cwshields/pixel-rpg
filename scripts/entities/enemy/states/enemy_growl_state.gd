class_name EnemyGrowlState
extends State
## Stationary warning growl: entered from Idle once a target is within the
## wider AlertArea but hasn't yet crossed into the tighter DetectionArea
## that actually triggers Chase/Attack (see EnemyBase.alert_target vs.
## `target`). Loops the "growl" animation in place — advances to Chase the
## moment `target` fires (the real aggro boundary), or falls back to Idle
## if the target backs out of the alert ring without ever closing the
## distance. Opt-in per enemy: AIIdleState only routes here when both
## an AlertArea and a "Growl" state node exist (currently just the wolf).
##
## If the player lingers in the alert ring without approaching for
## `growl_timeout` seconds, the wolf gives up and flees.

@export var growl_timeout: float = 3.5

var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.play_animation("growl")
	_timer = 0.0

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	entity.move(Vector2.ZERO, delta)
	if enemy.target:
		transition_requested.emit(&"Chase", {})
		return
	if not enemy.alert_target:
		transition_requested.emit(&"Idle", {})
		return
	_timer += delta
	if _timer >= growl_timeout:
		transition_requested.emit(&"Flee", {})
		return
	var to_target: Vector2 = enemy.alert_target.global_position - entity.global_position
	if to_target != Vector2.ZERO:
		entity.facing_direction = to_target.normalized()
		entity.play_animation("growl")
