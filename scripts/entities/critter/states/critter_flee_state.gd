class_name CritterFleeState
extends State
## Sprints directly away from `threat`. Keeps running for a bit after the
## threat stops being "active" (out of range, or simply stopped moving —
## see CritterBase.is_threat_active) instead of calming down instantly,
## via `flee_linger_time` — a startled animal doesn't stop on a dime. If
## `fight_back_after` is set above 0 and the threat stays actively on its
## tail that long, the critter snaps and turns hostile instead of
## continuing to run (see CritterBase.is_hostile).

## Seconds to keep running (in the last fled direction) after `threat`
## goes away, before settling back to Idle.
@export var flee_linger_time: float = 2.5
## Seconds of being actively chased before this critter turns to fight
## back instead of fleeing. 0 disables this — it just runs forever, like
## ordinary prey.
@export var fight_back_after: float = 0.0

var _time_without_threat: float = 0.0
var _time_with_threat: float = 0.0
var _last_direction: Vector2 = Vector2.RIGHT

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.sprinting = true
	_time_without_threat = 0.0
	_time_with_threat = 0.0
	var critter := entity as CritterBase
	critter.hunt_target = null # getting spooked drops any hunt this critter was on
	_last_direction = _away_from(critter.threat) if critter.threat else Vector2.RIGHT.rotated(randf() * TAU)

func exit() -> void:
	entity.sprinting = false

func process_physics(delta: float) -> void:
	var critter := entity as CritterBase
	if critter.is_threat_active():
		_time_without_threat = 0.0
		_time_with_threat += delta
		if fight_back_after > 0.0 and _time_with_threat >= fight_back_after:
			critter.is_hostile = true
			transition_requested.emit(&"Chase", {})
			return
		_last_direction = _away_from(critter.threat)
	else:
		_time_without_threat += delta
		if _time_without_threat >= flee_linger_time:
			transition_requested.emit(&"Idle", {})
			return
	var ignore: Array[Node2D] = []
	if critter.threat:
		ignore.append(critter.threat)
	entity.move(entity.steer_direction(_last_direction, ignore), delta)
	entity.play_animation("flee")

func _away_from(threat: Node2D) -> Vector2:
	var away: Vector2 = entity.global_position - threat.global_position
	return away.normalized() if away.length() > 0.001 else _last_direction
