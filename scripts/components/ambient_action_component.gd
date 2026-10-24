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
## Random range (seconds) between action urges at night.
@export var interval_min: float = 120.0
@export var interval_max: float = 300.0
## Multiplier applied to the interval during daytime (higher = less frequent).
@export var day_interval_multiplier: float = 3.0

@export_group("Response Howl")
## Group name used to find nearby entities that can respond. Leave empty to
## disable the call-and-response behavior.
@export var response_group: StringName = &"wolves"
## Node name of the AudioStreamPlayer2D whose max_distance defines how far
## the action carries for response purposes (e.g. "HowlSoundPlayer").
@export var sound_player_name: StringName = &"HowlSoundPlayer"
## Fallback radius (pixels) when no sound player is found.
@export var response_radius_fallback: float = 2800.0
## Probability (0–1) that a nearby idle entity joins in when it hears a howl.
@export var response_chance: float = 0.85
## Stagger range (seconds) so responses don't all fire on the same frame.
@export var response_delay_min: float = 0.8
@export var response_delay_max: float = 3.0

@onready var _owner: EnemyBase = get_parent() as EnemyBase

var _timer: Timer

func _ready() -> void:
	if not _owner:
		push_warning("AmbientActionComponent must be a child of an EnemyBase.")
		return
	if response_group != &"":
		_owner.add_to_group(response_group)
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_restart_and_try_act)
	_timer.start(_get_interval())

func _get_interval() -> float:
	var base := randf_range(interval_min, interval_max)
	var dnc = get_node_or_null("/root/DayNightCycle")
	if dnc and not dnc.is_night:
		base *= day_interval_multiplier
	return base

func _restart_and_try_act() -> void:
	_timer.start(_get_interval())
	if not _can_act():
		return
	_owner.state_machine.transition_to(action_state)
	_notify_nearby()

func _can_act() -> bool:
	if _owner.is_dead() or _owner.target or _owner.alert_target:
		return false
	var current: State = _owner.state_machine.current_state
	return current != null and current.name == &"Idle"

func _get_response_radius() -> float:
	var player := _owner.get_node_or_null(NodePath(sound_player_name)) as AudioStreamPlayer2D
	if player:
		return player.max_distance
	return response_radius_fallback

func _notify_nearby() -> void:
	if response_group == &"":
		return
	var radius := _get_response_radius()
	for node in _owner.get_tree().get_nodes_in_group(response_group):
		if node == _owner:
			continue
		if node.global_position.distance_to(_owner.global_position) > radius:
			continue
		var comp := node.get_node_or_null("AmbientActionComponent") as AmbientActionComponent
		if comp:
			comp._hear_nearby_action()

func _hear_nearby_action() -> void:
	if not _can_act():
		return
	if randf() > response_chance:
		return
	var delay := randf_range(response_delay_min, response_delay_max)
	_timer.stop()
	_timer.start(delay)
