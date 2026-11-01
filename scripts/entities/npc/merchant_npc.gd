class_name MerchantNPC
extends NPCBase
## A shopkeeper NPC. Generates random shop stock per category, seeded so
## the same items persist until the game is restarted.

const _WELCOME_SFX: AudioStream = preload("res://assets/SoundFX/Voice/sophia-welcome-traveler.mp3")

@export var shop_items: Array[ItemBase] = []
@export var buy_markup: float = 1.0
@export var shop_level: int = 1
@export_range(2, 20) var items_per_category: int = 20

var _category_inventories: Dictionary = {}
var _session_seed: int = 0

func _ready() -> void:
	has_shop = true
	_session_seed = hash(npc_name) ^ int(Time.get_unix_time_from_system())
	_generate_category_stock(ItemBase.Category.WEAPON)
	_generate_category_stock(ItemBase.Category.ARMOR)
	_generate_misc_stock()
	_add_exported_items()
	shop_inventory = _category_inventories.get(&"weapons", ShopInventory.new())
	super._ready()

func get_category_inventory(category: StringName) -> ShopInventory:
	return _category_inventories.get(category, shop_inventory)

func _generate_category_stock(category: ItemBase.Category) -> void:
	var bases := ItemFactory.get_bases_by_category(category)
	if bases.is_empty():
		return
	var cat_name := _category_key(category)
	var inv := ShopInventory.new()
	inv.buy_markup = buy_markup
	var rng := RandomNumberGenerator.new()
	rng.seed = _session_seed ^ hash(cat_name)
	_shuffle_with_rng(bases, rng)
	var count := mini(items_per_category, bases.size())
	for i in count:
		var item := ItemFactory.generate(bases[i], shop_level)
		inv.add_item(item)
	_category_inventories[cat_name] = inv

func _generate_misc_stock() -> void:
	var misc_categories: Array[ItemBase.Category] = [
		ItemBase.Category.RING, ItemBase.Category.AMULET, ItemBase.Category.CONSUMABLE,
	]
	var inv := ShopInventory.new()
	inv.buy_markup = buy_markup
	var rng := RandomNumberGenerator.new()
	rng.seed = _session_seed ^ hash("misc")
	for cat in misc_categories:
		var bases := ItemFactory.get_bases_by_category(cat)
		_shuffle_with_rng(bases, rng)
		var count := mini(items_per_category / 2 + 1, bases.size())
		for i in count:
			if cat == ItemBase.Category.CONSUMABLE:
				inv.add_item(bases[i], rng.randi_range(1, 5))
			else:
				var item := ItemFactory.generate(bases[i], shop_level)
				inv.add_item(item)
	_category_inventories[&"misc"] = inv

func _add_exported_items() -> void:
	for item in shop_items:
		if not item:
			continue
		var cat_key := _category_key(item.category)
		if not _category_inventories.has(cat_key):
			cat_key = &"misc"
		if _category_inventories.has(cat_key):
			var inv: ShopInventory = _category_inventories[cat_key]
			inv.add_item(item)

func _shuffle_with_rng(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _category_key(category: ItemBase.Category) -> StringName:
	match category:
		ItemBase.Category.WEAPON: return &"weapons"
		ItemBase.Category.ARMOR: return &"armor"
		ItemBase.Category.RING, ItemBase.Category.AMULET, ItemBase.Category.CONSUMABLE:
			return &"misc"
		_: return &"misc"

func start_dialogue() -> void:
	_play_welcome_sfx()
	super.start_dialogue()

func _play_welcome_sfx() -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = _WELCOME_SFX
	sfx.bus = &"Voice"
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
