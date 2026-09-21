class_name EnemyBase
extends EntityBase
## Shared behavior for hostile creatures. A StateMachine drives the AI
## (Idle/Chase/Attack/Hurt/Dead), a DetectionArea finds the player to
## chase, and a loot table decides what drops on death. Concrete enemies
## are usually just this scene + tuned export values + swapped art —
## script-level subclassing is only needed for special-case behavior.

@export var loot_table: Array[LootEntry] = []
@export var xp_reward: int = 5

## How far from the death spot dropped pickups land, in pixels. Keeps a
## multi-item drop from stacking into a single invisible pile.
const LOOT_SCATTER: float = 8.0

## Fling speed (px/sec) range for a hand/weapon piece breaking loose on
## death — a short pop-and-tumble, not a dramatic launch.
const EQUIPMENT_FLING_SPEED: Vector2 = Vector2(20.0, 55.0)
const EQUIPMENT_SPIN_RANGE: float = 8.0
## Chance the sword flies off on its own instead of staying gripped in
## the hand it's parented to (see enemy_base.tscn's Equipment/HandMain/Sword).
const SWORD_BREAKS_FREE_CHANCE: float = 0.5

@onready var state_machine: StateMachine = $StateMachine
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
@onready var hitbox: HitboxComponent = get_node_or_null("HitboxComponent")
## Holds the floating hand/weapon overlay sprites, if this mob has any
## (see enemy_base.tscn). Mirrored as a whole via scale.x so the hands
## stay on the correct side when facing_direction flips.
@onready var equipment: Node2D = get_node_or_null("Equipment")

## The current chase/attack target, usually the player. Null when no one
## is in detection range.
var target: Node2D = null

func _ready() -> void:
	super._ready()
	if hitbox:
		hitbox.source = self
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered_detection)
		detection_area.body_exited.connect(_on_body_exited_detection)
	if health:
		health.damaged.connect(func(_amount: float, _source: Node) -> void: state_machine.transition_to(&"Hurt"))
		health.died.connect(func() -> void: state_machine.transition_to(&"Dead"))
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

func _drop_loot() -> void:
	if loot_table.is_empty():
		return
	var pickup_scene: PackedScene = load("res://scenes/world/item_pickup.tscn")
	for entry in loot_table:
		if not entry.item or randf() > entry.chance:
			continue
		var amount: int = randi_range(entry.min_amount, entry.max_amount)
		if amount <= 0:
			continue
		if entry.drop_individually:
			for _i in amount:
				_spawn_pickup(pickup_scene, entry.item, 1)
		else:
			_spawn_pickup(pickup_scene, entry.item, amount)

func _spawn_pickup(pickup_scene: PackedScene, item: ItemBase, amount: int) -> void:
	var pickup: ItemPickup = pickup_scene.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector2(
		randf_range(-LOOT_SCATTER, LOOT_SCATTER),
		randf_range(-LOOT_SCATTER, LOOT_SCATTER))
	pickup.setup(item, amount)

## Knocks the Equipment overlay sprites loose so they tumble away as
## physics debris instead of just freezing in place with the corpse. The
## sword either stays gripped in HandMain (rides along as its child, same
## as while alive) or peels off to land on its own.
func _break_loose_equipment() -> void:
	if not equipment:
		return
	var offhand := equipment.get_node_or_null("HandOffhand") as Node2D
	var main_hand := equipment.get_node_or_null("HandMain") as Node2D
	var sword: Node2D = main_hand.get_node_or_null("Sword") as Node2D if main_hand else null
	if sword and randf() < SWORD_BREAKS_FREE_CHANCE:
		_launch_piece(sword)
	if main_hand:
		_launch_piece(main_hand) # brings the sword with it if still attached
	if offhand:
		_launch_piece(offhand)

## Detaches `sprite` onto its own LooseEquipmentPiece so it survives and
## tumbles independently of this enemy's own eventual queue_free().
func _launch_piece(sprite: Node2D) -> void:
	var piece: LooseEquipmentPiece = load("res://scenes/world/loose_equipment_piece.tscn").instantiate()
	get_tree().current_scene.add_child(piece)
	piece.global_position = sprite.global_position
	piece.global_rotation = sprite.global_rotation
	sprite.reparent(piece, true)
	var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	piece.launch(
		direction * randf_range(EQUIPMENT_FLING_SPEED.x, EQUIPMENT_FLING_SPEED.y),
		randf_range(-EQUIPMENT_SPIN_RANGE, EQUIPMENT_SPIN_RANGE))
