extends Node
## Autoload that generates rolled item instances from base templates.
## Base templates are .tres files under res://resources/items/; this factory
## duplicates them, rolls rarity + affixes, and assigns set membership.

const ITEMS_DIR := "res://resources/items"

var _registry: Dictionary = {}  # StringName -> String (resource path)

## Each non-common rarity has a level threshold (appears at 0% chance),
## a level where it reaches full weight, and that full weight. Between
## threshold and full the weight ramps linearly from 0.
const _RARITY_CURVES := {
	#                         unlock  full_at  peak_weight
	ItemBase.Rarity.MAGIC:   [1,      30,      30.0],
	ItemBase.Rarity.RARE:    [8,      40,      12.0],
	ItemBase.Rarity.SET:     [15,     50,       4.0],
	ItemBase.Rarity.UNIQUE:  [20,     50,       3.0],
}
const _COMMON_BASE_WEIGHT := 100.0
const _COMMON_MIN_WEIGHT := 20.0
const _COMMON_DECAY_RATE := 0.03

const _EQUIPMENT_CATEGORIES := [
	ItemBase.Category.WEAPON, ItemBase.Category.ARMOR,
	ItemBase.Category.TOOL, ItemBase.Category.RING, ItemBase.Category.AMULET,
]
const _COMMON_POOL_CATEGORIES := [
	ItemBase.Category.MATERIAL, ItemBase.Category.RUNE_STONE,
]


func _ready() -> void:
	_scan_and_register(ITEMS_DIR)


func generate(base: ItemBase, level: int = 1, rarity_override = null) -> ItemBase:
	var item: ItemBase = base.duplicate(true)
	if base.rarity == ItemBase.Rarity.SET or base.rarity == ItemBase.Rarity.UNIQUE:
		pass
	elif rarity_override != null:
		item.rarity = rarity_override as ItemBase.Rarity
	else:
		item.rarity = _roll_rarity(level)
	item.affixes = AffixDB.roll_affixes_for(item, level)
	if item.rarity == ItemBase.Rarity.SET:
		item.set_def = AffixDB.get_set_for_item(item.id)
	return item


func reload() -> void:
	_registry.clear()
	_scan_and_register(ITEMS_DIR, true)
	print("[ItemFactory] Reloaded %d items from disk." % _registry.size())


func get_base(id: StringName) -> ItemBase:
	var path: String = _registry.get(id, "")
	if path.is_empty():
		return null
	return load(path) as ItemBase


func get_bases_by_category(cat: ItemBase.Category) -> Array[ItemBase]:
	var result: Array[ItemBase] = []
	for path: String in _registry.values():
		var item := load(path) as ItemBase
		if item and item.category == cat:
			result.append(item)
	return result


func get_all_base_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_registry.keys())
	return ids


func _roll_rarity(level: int) -> ItemBase.Rarity:
	var player_luck: float = 0.0
	if GameManager.player and GameManager.player.stats:
		player_luck = GameManager.player.stats.luck
	var luck_mult: float = 1.0 + player_luck * 0.02
	var weights: Dictionary = {}
	weights[ItemBase.Rarity.COMMON] = maxf(_COMMON_MIN_WEIGHT,
		_COMMON_BASE_WEIGHT * exp(-_COMMON_DECAY_RATE * level))
	for r: ItemBase.Rarity in _RARITY_CURVES:
		var curve: Array = _RARITY_CURVES[r]
		var unlock: int = curve[0]
		var full_at: int = curve[1]
		var peak: float = curve[2]
		if level < unlock:
			weights[r] = 0.0
		elif level >= full_at:
			weights[r] = peak * luck_mult
		else:
			weights[r] = peak * float(level - unlock) / float(full_at - unlock) * luck_mult
	var total := 0.0
	for w: float in weights.values():
		total += w
	var roll := randf() * total
	var running := 0.0
	for r: ItemBase.Rarity in weights:
		running += weights[r]
		if roll <= running:
			return r
	return ItemBase.Rarity.COMMON


func is_equipment(item: ItemBase) -> bool:
	return item.category in _EQUIPMENT_CATEGORIES


func get_common_pool_bases() -> Array[ItemBase]:
	var result: Array[ItemBase] = []
	for cat: ItemBase.Category in _COMMON_POOL_CATEGORIES:
		result.append_array(get_bases_by_category(cat))
	return result


func roll_common_pool_item(level: int) -> ItemBase:
	var bases := get_common_pool_bases()
	if bases.is_empty():
		return null
	return generate(bases.pick_random(), level)


func _scan_and_register(dir_path: String, cache_bust: bool = false) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	var cache_mode := ResourceLoader.CACHE_MODE_REPLACE if cache_bust \
		else ResourceLoader.CACHE_MODE_REUSE
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_scan_and_register(full_path, cache_bust)
		elif file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			var load_path := full_path.replace(".remap", "")
			var res := ResourceLoader.load(load_path, "", cache_mode)
			if res is ItemBase:
				_registry[(res as ItemBase).id] = load_path
		file_name = dir.get_next()
	dir.list_dir_end()
