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
## Hard cap on flee duration — if the critter has been fleeing this long
## (stuck in a corner, looping, etc.), give up and return to Idle.
@export var max_flee_time: float = 10.0

@export_group("Stumble")
## Probability (0–1) of tripping each stumble check while sprinting. 0
## disables stumbling (default for most critters).
@export var stumble_chance: float = 0.0
## Seconds between stumble checks.
@export var stumble_interval: float = 1.5
## How long the critter stalls when it trips.
@export var stumble_duration: float = 0.4

var _time_without_threat: float = 0.0
var _time_with_threat: float = 0.0
var _total_flee_time: float = 0.0
var _stumble_check_timer: float = 0.0
var _stumble_timer: float = 0.0
var _last_direction: Vector2 = Vector2.RIGHT

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.sprinting = true
	_time_without_threat = 0.0
	_time_with_threat = 0.0
	_total_flee_time = 0.0
	_stumble_check_timer = 0.0
	_stumble_timer = 0.0
	var critter := entity as CritterBase
	critter.hunt_target = null # getting spooked drops any hunt this critter was on
	_last_direction = _away_from(critter.threat) if critter.threat else Vector2.RIGHT.rotated(randf() * TAU)

func exit() -> void:
	entity.sprinting = false

func process_physics(delta: float) -> void:
	var critter := entity as CritterBase
	_total_flee_time += delta
	if _total_flee_time >= max_flee_time:
		transition_requested.emit(&"Idle", {})
		return
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
	if entity.is_stuck():
		_last_direction = _last_direction.rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
	if stumble_chance > 0.0:
		if _stumble_timer > 0.0:
			_stumble_timer -= delta
			entity.move(Vector2.ZERO, delta)
			entity.play_animation("flee")
			return
		_stumble_check_timer += delta
		if _stumble_check_timer >= stumble_interval:
			_stumble_check_timer = 0.0
			if randf() < stumble_chance:
				_stumble_timer = stumble_duration
				entity.move(Vector2.ZERO, delta)
				entity.play_animation("flee")
				return
	var ignore: Array[Node2D] = []
	if critter.threat:
		ignore.append(critter.threat)
	entity.move(entity.steer_direction(_last_direction, ignore), delta)
	entity.play_animation("flee")

func _away_from(threat: Node2D) -> Vector2:
	var away: Vector2 = entity.global_position - threat.global_position
	return away.normalized() if away.length() > 0.001 else _last_direction
