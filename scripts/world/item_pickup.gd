class_name ItemPickup
extends Area2D
## World-space representation of an item lying on the ground. Either
## drop one into a level with `item`/`amount` set in the Inspector, or
## spawn one at runtime via setup() (e.g. from EnemyBase's loot table).

@export var item: ItemBase
@export var amount: int = 1

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_sprite()

func setup(p_item: ItemBase, p_amount: int = 1) -> void:
	item = p_item
	amount = p_amount
	_refresh_sprite()

func _refresh_sprite() -> void:
	if sprite and item and item.icon:
		sprite.texture = item.icon

func _on_body_entered(body: Node) -> void:
	if body is Player and item:
		var leftover: int = (body as Player).pickup_item(item, amount)
		if leftover <= 0:
			queue_free()
		else:
			amount = leftover
