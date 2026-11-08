class_name ItemPickup
extends Area2D
## World-space representation of an item lying on the ground. Either
## drop one into a level with `item`/`amount` set in the Inspector, or
## spawn one at runtime via setup() (e.g. from EnemyBase's loot table).
##
## Once the player wanders inside `attract_radius` the pickup is pulled
## toward them, accelerating as the gap closes, and is collected on
## contact.

const _SCENE: PackedScene = preload("res://scenes/world/item_pickup.tscn")
const DEFAULT_SCATTER: float = 8.0

## Global multiplier on every LootEntry's drop chance.
const DROP_RATE_MULT: float = 0.40
## Chance that an equipment drop is replaced by a common pool item instead.
const EQUIPMENT_DILUTION: float = 0.30
## How many bonus common-pool rolls per drop_loot call (materials, runes).
const BONUS_COMMON_ROLLS: int = 1
## Per-roll chance for each bonus common-pool drop.
const BONUS_COMMON_CHANCE: float = 0.18

@export var item: ItemBase
@export var amount: int = 1

@export_group("Magnetism")
## The player starts dragging this pickup in once they're within a random
## distance in this range (px). Randomised per drop so a scattered pile
## doesn't all leap at once.
@export var attract_radius_min: float = 20.0
@export var attract_radius_max: float = 24.0
## Collected once the pickup closes to within this distance of the player (px).
@export var collect_radius: float = 3.0
## Pull speed the instant attraction begins, at the edge of the radius (px/s).
@export var attract_speed_min: float = 24.0
## Pull speed once the pickup is right on top of the player (px/s).
@export var attract_speed_max: float = 220.0

static var _pickup_streams: Array[AudioStream] = [
	preload("res://assets/SoundFX/UI/pickup-pop-2.mp3"),
	preload("res://assets/SoundFX/UI/pickup-pop-3.mp3"),
	preload("res://assets/SoundFX/UI/pickup-pop-4.mp3"),
	preload("res://assets/SoundFX/UI/pop-pickup.mp3"),
]

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

static func drop_loot(
		loot_table: Array[LootEntry], origin: Vector2,
		scatter: float = DEFAULT_SCATTER, level: int = 1,
		dilute: bool = true) -> void:
	for entry in loot_table:
		if not entry.item:
			continue
		var effective_chance := entry.chance * (DROP_RATE_MULT if dilute else 1.0)
		if randf() > effective_chance:
			continue
		var qty: int = randi_range(entry.min_amount, entry.max_amount)
		if qty <= 0:
			continue
		if dilute and ItemFactory.is_equipment(entry.item) and randf() < EQUIPMENT_DILUTION:
			var common := ItemFactory.roll_common_pool_item(level)
			if common:
				_spawn(common, 1, origin, scatter)
			continue
		if entry.drop_individually:
			for _i in qty:
				var rolled := ItemFactory.generate(entry.item, level)
				_spawn(rolled, 1, origin, scatter)
		else:
			var rolled := ItemFactory.generate(entry.item, level)
			_spawn(rolled, qty, origin, scatter)
	if dilute:
		for _i in BONUS_COMMON_ROLLS:
			if randf() < BONUS_COMMON_CHANCE:
				var common := ItemFactory.roll_common_pool_item(level)
				if common:
					_spawn(common, 1, origin, scatter)

static func _spawn(
		item: ItemBase, qty: int, origin: Vector2, scatter: float) -> void:
	var pickup: ItemPickup = _SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	pickup.setup(item, qty)
	pickup.position = origin + Vector2(
		randf_range(-scatter, scatter), randf_range(-scatter, scatter))
	tree.current_scene.call_deferred(&"add_child", pickup)

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
		_play_pickup_sfx()
		queue_free()
	elif leftover < before:
		_play_pickup_sfx()
		amount = leftover
		_retry_delay = 0.5
	else:
		_retry_delay = 1.0

func _play_pickup_sfx() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = _pickup_streams.pick_random()
	sfx.volume_db = -14.0
	sfx.bus = &"Master"
	get_tree().current_scene.add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
