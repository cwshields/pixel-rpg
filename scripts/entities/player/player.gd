class_name Player
extends EntityBase
## The player-controlled hero. Reads input, drives its StateMachine, and
## owns the Inventory/Equipment the rest of the game (UI, item pickups,
## save system) reads from via GameManager.player.

var inventory: Inventory = Inventory.new()
var equipment: Equipment = Equipment.new()

@onready var state_machine: StateMachine = $StateMachine
@onready var hitbox: HitboxComponent = get_node_or_null("HitboxComponent")
@onready var interaction_detector: Area2D = get_node_or_null("InteractionDetector")

var _nearby_interactables: Array[InteractionComponent] = []

func _ready() -> void:
	super._ready()
	if hitbox:
		hitbox.source = self
		hitbox.monitoring = false
	equipment.owner_stats = stats
	if interaction_detector:
		interaction_detector.area_entered.connect(_on_interactable_entered)
		interaction_detector.area_exited.connect(_on_interactable_exited)
	if health:
		health.damaged.connect(func(_amount: float, _source: Node) -> void: state_machine.transition_to(&"Hurt"))
		health.died.connect(func() -> void: state_machine.transition_to(&"Dead"))
	GameManager.register_player(self)

## 8-directional analog input. Returns a normalized-or-zero Vector2.
func get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

## True while the sprint key (Shift) is held. Movement states use this to
## pick run speed + run animations; only meaningful when actually moving.
func wants_to_sprint() -> bool:
	return Input.is_action_pressed("sprint")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact_with_nearest()
	elif event.is_action_pressed("toggle_inventory"):
		UIManager.toggle_screen(&"inventory")

func _interact_with_nearest() -> void:
	for area in _nearby_interactables:
		if is_instance_valid(area) and area.can_interact(self):
			area.interact(self)
			return

func _on_interactable_entered(area: Area2D) -> void:
	if area is InteractionComponent:
		_nearby_interactables.append(area)

func _on_interactable_exited(area: Area2D) -> void:
	if area is InteractionComponent:
		_nearby_interactables.erase(area)

## Adds an item to the inventory and broadcasts the pickup. Returns
## whatever didn't fit (0 if it all fit), same contract as Inventory.add_item.
func pickup_item(item: ItemBase, amount: int = 1) -> int:
	var leftover := inventory.add_item(item, amount)
	if amount - leftover > 0:
		Events.item_picked_up.emit(item, amount - leftover)
	return leftover
