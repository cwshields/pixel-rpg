class_name EnemyBase
extends AIEntityBase
## Hostile creature driven by AI states. Extends AIEntityBase with
## player-targeting (target / alert_target), loot, XP, and the equipment
## overlay that breaks loose on death. Concrete enemies are usually just
## this scene + tuned exports + swapped art.

@export var loot_table: Array[LootEntry] = []
@export var xp_reward: int = 5

const EQUIPMENT_FLING_SPEED: Vector2 = Vector2(35.0, 75.0)
const EQUIPMENT_SPIN_RANGE: float = 10.0
const SWORD_BREAKS_FREE_CHANCE: float = 0.5

const _LOOSE_EQUIPMENT_PIECE_SCENE: PackedScene = preload("res://scenes/world/loose_equipment_piece.tscn")

@onready var alert_area: Area2D = get_node_or_null("AlertArea")
@onready var equipment: Node2D = get_node_or_null("Equipment")

var target: Node2D = null
var alert_target: Node2D = null

func _ready() -> void:
	super._ready()
	if alert_area:
		alert_area.body_entered.connect(_on_body_entered_alert)
		alert_area.body_exited.connect(_on_body_exited_alert)
	died.connect(func(_e: EntityBase) -> void:
		_drop_loot()
		_break_loose_equipment())

func _physics_process(_delta: float) -> void:
	if equipment:
		equipment.scale.x = -1.0 if facing_direction.x < 0.0 else 1.0

func _on_body_entered_detection(body: Node2D) -> void:
	if body is Player:
		target = body

func _on_body_exited_detection(body: Node2D) -> void:
	if body == target:
		target = null

func _on_body_entered_alert(body: Node2D) -> void:
	if body is Player:
		alert_target = body

func _on_body_exited_alert(body: Node2D) -> void:
	if body == alert_target:
		alert_target = null

func _primary_pursuit_target() -> Node2D:
	return target

func _should_react() -> StringName:
	if target:
		return &"Chase"
	if alert_target and state_machine.states.has(&"Growl"):
		return &"Growl"
	return &""

func _drop_loot() -> void:
	ItemPickup.drop_loot(loot_table, global_position)

func _break_loose_equipment() -> void:
	if not equipment:
		return
	var offhand := equipment.get_node_or_null("HandOffhand") as Node2D
	var main_hand := equipment.get_node_or_null("HandMain") as Node2D
	var sword: Node2D = main_hand.get_node_or_null("Sword") as Node2D if main_hand else null
	if sword and randf() < SWORD_BREAKS_FREE_CHANCE:
		_launch_piece(sword)
	if main_hand:
		_launch_piece(main_hand)
	if offhand:
		_launch_piece(offhand)

func _launch_piece(sprite: Node2D) -> void:
	var piece: LooseEquipmentPiece = _LOOSE_EQUIPMENT_PIECE_SCENE.instantiate()
	get_tree().current_scene.add_child(piece)
	piece.global_position = sprite.global_position
	piece.global_rotation = sprite.global_rotation
	sprite.reparent(piece, true)
	var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	piece.launch(
		direction * randf_range(EQUIPMENT_FLING_SPEED.x, EQUIPMENT_FLING_SPEED.y),
		randf_range(-EQUIPMENT_SPIN_RANGE, EQUIPMENT_SPIN_RANGE))
