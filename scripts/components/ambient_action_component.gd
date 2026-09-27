class_name AmbientActionComponent
extends Node
## Gives its owner a flavor behavior it breaks into every so often while
## otherwise unengaged — e.g. the wolf's howl. Every `interval_min` to
## `interval_max` seconds (rerolled each time via a one-shot Timer, same
## shape as HunterComponent's urge timer), if the owner is idling and not
## aggroed/alerted, transitions its StateMachine to `action_state`. That
## state is responsible for returning to Idle (or wherever's appropriate)
## on its own once it's done.
##
## Drop as a child of any EnemyBase with a state node matching
## `action_state` — see wolf.tscn (action_state = "Howl").

@export var action_state: StringName = &"Howl"
## Random range (seconds) between action urges.
@export var interval_min: float = 30.0
@export var interval_max: float = 90.0

@onready var _owner: EnemyBase = get_parent() as EnemyBase

var _timer: Timer

func _ready() -> void:
	if not _owner:
		push_warning("AmbientActionComponent must be a child of an EnemyBase.")
		return
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_restart_and_try_act)
	_timer.start(randf_range(interval_min, interval_max))

func _restart_and_try_act() -> void:
	_timer.start(randf_range(interval_min, interval_max))
	if _owner.is_dead() or _owner.target or _owner.alert_target:
		return
	var current: State = _owner.state_machine.current_state
	if not current or current.name != &"Idle":
		return
	_owner.state_machine.transition_to(action_state)
