class_name EnemyGrowlState
extends State
## A one-shot aggro bark played the moment an enemy first spots its
## target, before actually giving chase — pure flavor between Idle and
## Chase. EnemyIdleState only routes here when this state node is present
## in the enemy's StateMachine, so this is opt-in per enemy (currently
## just the wolf); add a "Growl" node + this script to any other enemy's
## StateMachine to give it the same beat.

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	if entity.play_animation("growl"):
		await entity.animated_sprite.animation_finished
	if not is_instance_valid(entity):
		return
	var enemy := entity as EnemyBase
	transition_requested.emit(&"Chase" if enemy.target else &"Idle", {})

func process_physics(delta: float) -> void:
	entity.move(Vector2.ZERO, delta)
