class_name CritterChaseState
extends State
## Charges at whatever CritterBase.pursuit_target() returns — either a
## hostile threat this critter is fighting back against (see
## CritterFleeState.fight_back_after, e.g. boar.tscn), or, for a
## predator, prey it's hunting (see HunterComponent, e.g. fox.tscn). A
## critter that's only hunting (not yet hostile) still bails to Flee the
## instant the player becomes a real threat — only a hostile critter
## presses on regardless. Same shape as EnemyChaseState.

@export var attack_range: float = 20.0
## 0 disables this (chase forever — the hostile default, e.g. boar.tscn).
## Above 0, give up and return to Idle after this many seconds of
## continuous pursuit without catching the target, so a predator hunting
## something faster than itself (see Fox vs. Hare) doesn't chase forever.
## Time-based rather than a distance-from-anchor cutoff — the target may
## have been spotted anywhere up to the hunter's own search radius away,
## so a fixed travel distance would just as easily run out before the
## chase even reaches the target as after a fair pursuit.
@export var giveup_time: float = 0.0

var _time: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.sprinting = true
	_time = 0.0

func exit() -> void:
	entity.sprinting = false

func process_physics(delta: float) -> void:
	var critter := entity as CritterBase
	if not critter.is_hostile and critter.is_threat_active():
		critter.hunt_target = null
		transition_requested.emit(&"Flee", {})
		return
	var target := critter.pursuit_target()
	if not target:
		transition_requested.emit(&"Idle", {})
		return
	_time += delta
	if giveup_time > 0.0 and _time >= giveup_time:
		critter.hunt_target = null
		transition_requested.emit(&"Idle", {})
		return
	var to_target: Vector2 = target.global_position - entity.global_position
	if to_target.length() <= attack_range:
		transition_requested.emit(&"Attack", {})
		return
	entity.move(entity.steer_direction(to_target.normalized(), [target]), delta)
	entity.play_animation("flee") # the run sheet — no separate charge art
