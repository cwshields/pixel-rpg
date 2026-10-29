extends Node
## Autoload that generates rolled item instances from base templates.
## Base templates are .tres files under res://resources/items/; this factory
## duplicates them, rolls rarity + affixes, and assigns set membership.

const ITEMS_DIR := "res://resources/items"

var _registry: Dictionary = {}  # StringName -> String (resource path)

const _RARITY_WEIGHTS := {
	ItemBase.Rarity.COMMON: 60.0,
	ItemBase.Rarity.MAGIC: 25.0,
	ItemBase.Rarity.RARE: 10.0,
	ItemBase.Rarity.SET: 3.0,
	ItemBase.Rarity.UNIQUE: 2.0,
}
const _LEVEL_MAGIC_FIND_SCALE := 0.02


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
	var magic_find_bonus := level * _LEVEL_MAGIC_FIND_SCALE
	var weights: Dictionary = {}
	for r: ItemBase.Rarity in _RARITY_WEIGHTS:
		if r == ItemBase.Rarity.COMMON:
			weights[r] = _RARITY_WEIGHTS[r]
		else:
			weights[r] = _RARITY_WEIGHTS[r] * (1.0 + magic_find_bonus)
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


func _scan_and_register(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_scan_and_register(full_path)
		elif file_name.ends_with(".tres"):
			var res := load(full_path)
			if res is ItemBase:
				_registry[(res as ItemBase).id] = full_path
		file_name = dir.get_next()
	dir.list_dir_end()
