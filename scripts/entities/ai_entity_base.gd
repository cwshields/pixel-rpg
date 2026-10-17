class_name AIEntityBase
extends EntityBase
## Intermediate base for AI-driven entities — enemies and critters. Pulls
## up the fields and wiring every StateMachine-driven mob shares: a state
## machine, detection area, hitbox, spawn anchor, wander radius, and the
## hunt-target slot used by HunterComponent. Subclasses add their own
## detection reactions, pursuit priorities, and hurt-recovery logic via
## the virtual hooks below.

@export var wander_radius: float = 0.0

@onready var state_machine: StateMachine = $StateMachine
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
@onready var hitbox: HitboxComponent = get_node_or_null("HitboxComponent")

var anchor_position: Vector2
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
		health.damaged.connect(_on_ai_damaged)
		health.died.connect(func() -> void: state_machine.transition_to(&"Dead"))

func _on_body_entered_detection(_body: Node2D) -> void:
	pass

func _on_body_exited_detection(_body: Node2D) -> void:
	pass

func _on_ai_damaged(_amount: float, _source: Node) -> void:
	state_machine.transition_to(&"Hurt")

func pursuit_target() -> Node2D:
	var primary := _primary_pursuit_target()
	if primary:
		return primary
	if hunt_target:
		if is_instance_valid(hunt_target) and not hunt_target.is_dead():
			return hunt_target
		hunt_target = null
	return null

## Override: the entity's highest-priority chase target before hunt_target.
func _primary_pursuit_target() -> Node2D:
	return null

## Override: the state an idle/wandering entity should break into because
## of a nearby player or threat, or &"" when nothing demands a reaction.
func _should_react() -> StringName:
	return &""

## Override: the state to transition to after being hurt.
func _hurt_recovery_state() -> StringName:
	if pursuit_target():
		return &"Chase"
	return &"Idle"
