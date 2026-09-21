class_name HunterComponent
extends Node
## Gives its owning critter an unprovoked predator urge: every so often,
## scan `prey_group` for the nearest live CritterBase within
## search_radius and, if the owner is free to act (idling/wandering, not
## already hunting or scared), break off to hunt it — sets
## CritterBase.hunt_target and transitions the owner's StateMachine to
## "Chase". CritterChaseState/CritterAttackState (which drive off
## CritterBase.pursuit_target()) do the actual chase-and-strike; this
## only decides when to start one and against whom. Getting spooked
## (CritterFleeState) or landing the kill both end the hunt on their own.
##
## Drop as a child of any critter that should occasionally go hunt
## something — see fox.tscn hunting hares. The owner needs a
## HitboxComponent and Chase/Attack state nodes to actually catch and
## strike prey (critter_base.tscn doesn't include these by default — add
## them as inherited-scene overrides the same way boar.tscn/fox.tscn do).

## Group name of potential prey to scan for. Empty disables hunting —
## set this per critter (e.g. "hares" on a fox).
@export var prey_group: StringName = &""
## How far to scan for prey when the urge fires. Needs to reach past the
## owner's own wander_radius if predator and prey roam around separate
## spawner anchors rather than sharing a patch.
@export var search_radius: float = 550.0
## Random range (seconds) between hunting urges.
@export var urge_min: float = 20.0
@export var urge_max: float = 50.0

@onready var _owner: CritterBase = get_parent() as CritterBase

var _urge_timer: Timer

func _ready() -> void:
	if not _owner:
		push_warning("HunterComponent must be a child of a CritterBase.")
		return
	_urge_timer = Timer.new()
	_urge_timer.one_shot = true
	add_child(_urge_timer)
	_urge_timer.timeout.connect(_restart_and_try_hunt)
	_urge_timer.start(randf_range(urge_min, urge_max))

func _restart_and_try_hunt() -> void:
	_urge_timer.start(randf_range(urge_min, urge_max))
	if prey_group == &"" or _owner.is_dead() or _owner.hunt_target or _owner.is_threat_active():
		return
	var current: State = _owner.state_machine.current_state
	if not current or (current.name != &"Idle" and current.name != &"Wander"):
		return
	var prey := _find_nearby_prey()
	if not prey:
		return
	_owner.hunt_target = prey
	prey.threat = _owner # wake the prey immediately even if it's already in range
	_owner.state_machine.transition_to(&"Chase")

func _find_nearby_prey() -> CritterBase:
	var best: CritterBase = null
	var best_dist_sq: float = search_radius * search_radius
	for node in _owner.get_tree().get_nodes_in_group(prey_group):
		var prey := node as CritterBase
		if not prey or prey == _owner or prey.is_dead():
			continue
		var dist_sq: float = _owner.global_position.distance_squared_to(prey.global_position)
		if dist_sq <= best_dist_sq:
			best = prey
			best_dist_sq = dist_sq
	return best
