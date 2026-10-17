class_name AIWanderState
extends State
## Shared wander for all AI entities. Ambles to a random point within
## wander_radius of the spawn anchor, then hands back to Idle. Breaks
## into a reaction state via AIEntityBase._should_react().

@export var arrival_distance: float = 4.0
@export var max_travel_time: float = 6.0

var _destination: Vector2
var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	var ai := entity as AIEntityBase
	var angle: float = randf() * TAU
	var dist: float = sqrt(randf()) * ai.wander_radius
	_destination = ai.anchor_position + Vector2(cos(angle), sin(angle)) * dist
	_timer = 0.0
	entity.play_animation("walk")

func process_physics(delta: float) -> void:
	var ai := entity as AIEntityBase
	var reaction := ai._should_react()
	if reaction != &"":
		transition_requested.emit(reaction, {})
		return
	_timer += delta
	if entity.is_stuck():
		transition_requested.emit(&"Idle", {})
		return
	var to_destination: Vector2 = _destination - entity.global_position
	if to_destination.length() <= arrival_distance or _timer >= max_travel_time:
		transition_requested.emit(&"Idle", {})
		return
	entity.move(entity.steer_direction(to_destination.normalized()), delta)
	entity.play_animation("walk")
