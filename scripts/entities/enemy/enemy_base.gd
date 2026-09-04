class_name EnemyBase
extends EntityBase
## Shared behavior for hostile creatures. A StateMachine drives the AI
## (Idle/Chase/Attack/Hurt/Dead), a DetectionArea finds the player to
## chase, and a loot table decides what drops on death. Concrete enemies
## are usually just this scene + tuned export values + swapped art —
## script-level subclassing is only needed for special-case behavior.

@export var loot_table: Array[LootEntry] = []
@export var xp_reward: int = 5

@onready var state_machine: StateMachine = $StateMachine
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
@onready var hitbox: HitboxComponent = get_node_or_null("HitboxComponent")

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
	died.connect(func(_e: EntityBase) -> void: _drop_loot())

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
		if entry.item and randf() <= entry.chance:
			var amount: int = randi_range(entry.min_amount, entry.max_amount)
			var pickup: ItemPickup = pickup_scene.instantiate()
			get_tree().current_scene.add_child(pickup)
			pickup.global_position = global_position
			pickup.setup(entry.item, amount)
