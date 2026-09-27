class_name EnemyGrowlState
extends State
## Stationary warning growl: entered from Idle once a target is within the
## wider AlertArea but hasn't yet crossed into the tighter DetectionArea
## that actually triggers Chase/Attack (see EnemyBase.alert_target vs.
## `target`). Loops the "growl" animation in place — advances to Chase the
## moment `target` fires (the real aggro boundary), or falls back to Idle
## if the target backs out of the alert ring without ever closing the
## distance. Opt-in per enemy: EnemyIdleState only routes here when both
## an AlertArea and a "Growl" state node exist (currently just the wolf).
##
## Faces the target the whole time it's growling (flip_h only — this art
## has no up/down variants) even though it isn't moving, so it doesn't
## snarl in some stale direction left over from before it noticed anyone.

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.play_animation("growl")

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	entity.move(Vector2.ZERO, delta)
	if enemy.target:
		transition_requested.emit(&"Chase", {})
		return
	if not enemy.alert_target:
		transition_requested.emit(&"Idle", {})
		return
	var to_target: Vector2 = enemy.alert_target.global_position - entity.global_position
	if to_target != Vector2.ZERO:
		entity.facing_direction = to_target.normalized()
		entity.play_animation("growl") # re-applies flip_h for the new facing
