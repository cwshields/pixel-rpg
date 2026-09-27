class_name EnemyChaseState
extends State
## Charges at whatever EnemyBase.pursuit_target() returns — the player,
## or, for a predator, prey it's hunting (see HunterComponent, e.g. the
## wolf hunting deer). The player always wins: if they come into range
## mid-hunt, the hunt is dropped and the enemy turns on them instead.

@export var attack_range: float = 20.0
## Sprint (EntityBase.sprint_speed) while running down prey. Never
## applies to the player — fighting them keeps using plain move_speed.
@export var sprint_when_hunting: bool = true
## While hunting, creep toward the prey at walking pace until it's within
## this distance (or has noticed us and bolted), then break into the
## sprint. 0 sprints from the start. See HunterComponent.alert_prey.
@export var stalk_distance: float = 0.0
## 0 disables this (chase prey until it's caught). Above 0, give up a
## hunt and return to Idle after this many seconds of sprinting without
## catching the prey — see CritterChaseState.giveup_time. The stalk
## doesn't count toward it. Never applies to the player.
@export var giveup_time: float = 0.0

var _hunt_time: float = 0.0

func enter(previous_state: StringName, _data: Dictionary = {}) -> void:
	# Coming back from a bite continues the same pursuit — the giveup
	# clock only restarts for a fresh chase.
	if previous_state != &"Attack":
		_hunt_time = 0.0

func exit() -> void:
	entity.sprinting = false

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	if enemy.target:
		enemy.hunt_target = null # the player takes priority over any prey
	var chase_target := enemy.pursuit_target()
	if not chase_target:
		transition_requested.emit(&"Idle", {})
		return
	var to_target: Vector2 = chase_target.global_position - entity.global_position
	var hunting: bool = chase_target == enemy.hunt_target
	var pouncing: bool = hunting and (_hunt_time > 0.0 or to_target.length() <= stalk_distance
			or enemy.hunt_target.threat == enemy)
	entity.sprinting = pouncing and sprint_when_hunting
	if pouncing:
		_hunt_time += delta
		if giveup_time > 0.0 and _hunt_time >= giveup_time:
			enemy.hunt_target = null
			transition_requested.emit(&"Idle", {})
			return
	if to_target.length() <= attack_range:
		transition_requested.emit(&"Attack", {})
		return
	entity.move(entity.steer_direction(to_target.normalized(), [chase_target]), delta)
	entity.play_animation("walk")
