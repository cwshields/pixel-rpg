class_name CritterBase
extends AIEntityBase
## Ambient wildlife driven by AI states. Extends AIEntityBase with
## threat-tracking (flee from the player, fight back if provoked long
## enough) and the motion-based alarm that lets a motionless player stand
## right next to prey without spooking it.

@export var alarm_speed_threshold: float = 5.0

var threat: Node2D = null
var is_hostile: bool = false

func _init() -> void:
	wander_radius = 64.0

func _on_body_entered_detection(body: Node2D) -> void:
	if body is Player:
		threat = body
	elif body.get(&"hunt_target") == self:
		threat = body

func _on_body_exited_detection(body: Node2D) -> void:
	if body == threat:
		threat = null

func _on_ai_damaged(_amount: float, source: Node) -> void:
	if source is Node2D:
		threat = source as Node2D
	super._on_ai_damaged(_amount, source)

func is_threat_active() -> bool:
	if not threat:
		return false
	if not is_instance_valid(threat) or (not threat is Player and threat.get(&"hunt_target") != self):
		threat = null
		return false
	if is_hostile:
		return true
	var body := threat as CharacterBody2D
	return body == null or body.velocity.length() > alarm_speed_threshold

func _primary_pursuit_target() -> Node2D:
	if is_hostile and threat:
		return threat
	return null

func _should_react() -> StringName:
	if is_threat_active():
		return &"Chase" if is_hostile else &"Flee"
	return &""

func _hurt_recovery_state() -> StringName:
	if threat:
		return &"Chase" if is_hostile else &"Flee"
	if pursuit_target():
		return &"Chase"
	return &"Idle"
