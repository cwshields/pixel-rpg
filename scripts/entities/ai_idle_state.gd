class_name AIIdleState
extends State
## Shared idle for all AI entities. Stands still, then hands off to Wander
## when a wander_radius and Wander state exist. Breaks into a reaction
## state the moment AIEntityBase._should_react() fires.

@export var min_idle_time: float = 2.0
@export var max_idle_time: float = 5.0

var _timer: float = 0.0
var _idle_time: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.play_animation("idle")
	_timer = 0.0
	_idle_time = randf_range(min_idle_time, max_idle_time)

func process_physics(delta: float) -> void:
	var ai := entity as AIEntityBase
	var reaction := ai._should_react()
	if reaction != &"":
		transition_requested.emit(reaction, {})
		return
	entity.move(Vector2.ZERO, delta)
	_timer += delta
	if _timer >= _idle_time and ai.wander_radius > 0.0 and ai.state_machine.states.has(&"Wander"):
		transition_requested.emit(&"Wander", {})
