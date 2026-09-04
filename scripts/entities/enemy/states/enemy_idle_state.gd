class_name EnemyIdleState
extends State
## Stands still until a target wanders into detection range. Extend this
## (or replace it) if you want patrol/wander behavior — the state
## boundary is deliberately kept simple here.

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.play_animation("idle")

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	if enemy.target:
		transition_requested.emit(&"Chase", {})
		return
	entity.move(Vector2.ZERO, delta)
