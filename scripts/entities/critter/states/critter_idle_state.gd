class_name CritterIdleState
extends State
## Stands still for a random pause, then hands off to Wander. Bolts to
## Flee immediately if something the critter is scared of is nearby.

@export var min_idle_time: float = 1.5
@export var max_idle_time: float = 4.0

var _timer: float = 0.0
var _idle_time: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.play_animation("idle")
	_timer = 0.0
	_idle_time = randf_range(min_idle_time, max_idle_time)

func process_physics(delta: float) -> void:
	var critter := entity as CritterBase
	if critter.is_threat_active():
		transition_requested.emit(&"Chase" if critter.is_hostile else &"Flee", {})
		return
	entity.move(Vector2.ZERO, delta)
	_timer += delta
	if _timer >= _idle_time:
		transition_requested.emit(&"Wander", {})
