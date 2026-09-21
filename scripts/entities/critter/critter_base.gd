class_name CritterBase
extends EntityBase
## Shared behavior for ambient wildlife. A StateMachine drives passive AI
## (Idle/Wander/Flee/Hurt/Dead) — critters amble near their spawn point
## and bolt when the player gets close or lands a hit. Most never fight
## back, but a critter can be configured (see CritterFleeState's
## fight_back_after) to snap into a hostile Chase/Attack loop if chased
## too long — see boar.tscn. Concrete critters are usually just this
## scene + tuned export values + swapped art, same pattern as EnemyBase.

## How far from its spawn point this critter wanders while idle.
@export var wander_radius: float = 64.0
## How fast (px/sec) `threat` needs to be moving for this critter to
## actually react to it. Real prey keys off motion far more than
## presence — a motionless player standing right next to it just reads
## as part of the scenery. Ignored once `is_hostile` (see
## CritterFleeState.fight_back_after) — an enraged critter isn't fooled
## by playing statue anymore.
@export var alarm_speed_threshold: float = 5.0

@onready var state_machine: StateMachine = $StateMachine
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
## Only present on critters that can fight back (see CritterFleeState's
## fight_back_after) — null for ordinary prey.
@onready var hitbox: HitboxComponent = get_node_or_null("HitboxComponent")

## Whatever this critter is currently running from — the player, once
## sighted or once they land a hit. Null when nothing is chasing it.
var threat: Node2D = null
## Where this critter started; wandering stays anchored here instead of
## drifting indefinitely.
var anchor_position: Vector2
## Set permanently once this critter turns to fight back after being
## chased too long (CritterFleeState.fight_back_after). From then on it
## chases and attacks like a hostile enemy instead of fleeing.
var is_hostile: bool = false
## For a predator (see HunterComponent), the prey it's currently hunting
## — set by an urge timer, not by being provoked. Null when not hunting
## anything. Cleared automatically once the target dies (see
## pursuit_target()) or if this critter itself gets scared into fleeing
## (CritterFleeState).
var hunt_target: CritterBase = null

func _ready() -> void:
	super._ready()
	anchor_position = global_position
	if hitbox:
		hitbox.source = self
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered_detection)
		detection_area.body_exited.connect(_on_body_exited_detection)
	if health:
		health.damaged.connect(_on_damaged)
		health.died.connect(func() -> void: state_machine.transition_to(&"Dead"))

func _on_body_entered_detection(body: Node2D) -> void:
	if body is Player:
		threat = body
	elif body is CritterBase and (body as CritterBase).hunt_target == self:
		threat = body

func _on_body_exited_detection(body: Node2D) -> void:
	if body == threat:
		threat = null

## Whether `threat` is actually worth reacting to right now. `threat`
## itself just tracks presence (who's nearby / who last hit us); this
## adds the "is it moving" ignorance check states use to decide whether
## to flee/chase.
func is_threat_active() -> bool:
	if not threat:
		return false
	if is_hostile:
		return true
	var body := threat as CharacterBody2D
	return body == null or body.velocity.length() > alarm_speed_threshold

func _on_damaged(_amount: float, source: Node) -> void:
	if source is Node2D:
		threat = source as Node2D
	state_machine.transition_to(&"Hurt")

## Whoever this critter is currently pursuing to strike — a hostile
## threat it's fighting back against (is_hostile), or, for a predator,
## the prey it's hunting (hunt_target). Self-clears hunt_target once the
## target's no longer worth chasing (dead or freed), so a finished hunt
## doesn't leave stale state behind. Null when not pursuing anything.
func pursuit_target() -> Node2D:
	if is_hostile and threat:
		return threat
	if hunt_target:
		if is_instance_valid(hunt_target) and not hunt_target.is_dead():
			return hunt_target
		hunt_target = null
	return null
