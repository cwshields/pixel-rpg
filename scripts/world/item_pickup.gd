class_name ItemPickup
extends Area2D
## World-space representation of an item lying on the ground. Either
## drop one into a level with `item`/`amount` set in the Inspector, or
## spawn one at runtime via setup() (e.g. from EnemyBase's loot table).
##
## Once the player wanders inside `attract_radius` the pickup is pulled
## toward them, accelerating as the gap closes, and is collected on
## contact.

@export var item: ItemBase
@export var amount: int = 1

@export_group("Magnetism")
## The player starts dragging this pickup in once they're within a random
## distance in this range (px). Randomised per drop so a scattered pile
## doesn't all leap at once.
@export var attract_radius_min: float = 16.0
@export var attract_radius_max: float = 24.0
## Collected once the pickup closes to within this distance of the player (px).
@export var collect_radius: float = 3.0
## Pull speed the instant attraction begins, at the edge of the radius (px/s).
@export var attract_speed_min: float = 24.0
## Pull speed once the pickup is right on top of the player (px/s).
@export var attract_speed_max: float = 220.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

## Actual trigger distance for this instance, rolled in _ready().
var _attract_radius: float = 0.0
## Counts down after a failed grab (inventory full) so we don't spam
## pickup_item()/events every frame.
var _retry_delay: float = 0.0
var _player: Player = null

func _ready() -> void:
	_attract_radius = randf_range(attract_radius_min, attract_radius_max)
	_refresh_sprite()

func setup(p_item: ItemBase, p_amount: int = 1) -> void:
	item = p_item
	amount = p_amount
	_refresh_sprite()

func _refresh_sprite() -> void:
	if sprite and item and item.icon:
		sprite.texture = item.icon

func _physics_process(delta: float) -> void:
	if item == null:
		return
	if _retry_delay > 0.0:
		_retry_delay -= delta
		return
	if _player == null or not is_instance_valid(_player):
		_player = GameManager.player as Player
		if _player == null:
			return

	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()
	if dist > _attract_radius:
		return
	if dist <= collect_radius:
		_collect()
		return

	# Closer = faster: ramp speed from min at the radius edge to max at
	# the player. Squared falloff makes the final snap feel snappy.
	var closeness: float = 1.0 - clampf(dist / _attract_radius, 0.0, 1.0)
	var speed: float = lerpf(attract_speed_min, attract_speed_max, closeness * closeness)
	global_position += (to_player / dist) * minf(speed * delta, dist)

func _collect() -> void:
	var before: int = amount
	var leftover: int = _player.pickup_item(item, amount)
	if leftover <= 0:
		queue_free()
	elif leftover < before:
		# Part of the stack fit; leave the rest on the ground.
		amount = leftover
		_retry_delay = 0.5
	else:
		# Inventory full — stop pestering it for a bit.
		_retry_delay = 1.0
