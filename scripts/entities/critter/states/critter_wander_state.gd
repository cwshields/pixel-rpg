class_name CritterWanderState
extends State
## Ambles to a random point near the critter's spawn anchor, then hands
## back to Idle. A single point-to-point walk with a giveup timer, unlike
## EnemyChaseState's continuous pursuit loop, so a critter never gets
## stuck pushing at a wall.

@export var arrival_distance: float = 4.0
@export var max_travel_time: float = 6.0

var _destination: Vector2
var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	var critter := entity as CritterBase
	var angle: float = randf() * TAU
	var dist: float = sqrt(randf()) * critter.wander_radius
	_destination = critter.anchor_position + Vector2(cos(angle), sin(angle)) * dist
	_timer = 0.0
	entity.play_animation("walk")

func process_physics(delta: float) -> void:
	var critter := entity as CritterBase
	if critter.is_threat_active():
		transition_requested.emit(&"Chase" if critter.is_hostile else &"Flee", {})
		return
	_timer += delta
	var to_destination: Vector2 = _destination - entity.global_position
	if to_destination.length() <= arrival_distance or _timer >= max_travel_time:
		transition_requested.emit(&"Idle", {})
		return
	entity.move(entity.steer_direction(to_destination.normalized()), delta)
	entity.play_animation("walk")
