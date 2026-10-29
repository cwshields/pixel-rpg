class_name Equipment
extends RefCounted
## Tracks what's equipped in each slot and applies/removes the item's
## stat modifiers on the linked StatsComponent. One instance per entity
## (set `owner_stats` right after creating it — see Player._ready()).
##
## Supports two weapon sets (I / II) for PRIMARY_HAND and OFF_HAND,
## swapped with swap_weapon_set(). Non-weapon slots are shared.

signal changed(slot: Slot)

enum Slot { PRIMARY_HAND, HEAD, CHEST, FEET, OFF_HAND, RING_1, RING_2, AMULET, RUNE_STONE, GAUNTLETS }

var owner_stats: StatsComponent
var slots: Dictionary = {}   # Slot -> ItemBase

var active_weapon_set: int = 0
var _weapon_sets: Array = [{}, {}]  # Array of {Slot -> ItemBase} for PRIMARY_HAND / OFF_HAND

const _SET_BONUS_SOURCE := &"set_bonus"

## Equips `item` into `slot`, returning whatever was previously there
## (or null). Swap the previous item back into the inventory yourself —
## Equipment doesn't know about Inventory to keep the two decoupled.
func equip(slot: Slot, item: ItemBase) -> ItemBase:
	if slot == Slot.OFF_HAND and is_two_handed():
		return item
	var previous: ItemBase = unequip(slot)
	slots[slot] = item
	if owner_stats and item:
		item.apply_modifiers(owner_stats, _source_id(slot))
	if slot == Slot.PRIMARY_HAND and item is Weapon and (item as Weapon).two_handed:
		unequip(Slot.OFF_HAND)
	if _is_weapon_slot(slot):
		_weapon_sets[active_weapon_set][slot] = item
	_recalc_set_bonuses()
	changed.emit(slot)
	return previous

func unequip(slot: Slot) -> ItemBase:
	if not slots.has(slot):
		return null
	var item: ItemBase = slots[slot]
	slots.erase(slot)
	if owner_stats:
		owner_stats.remove_all_from_source(_source_id(slot))
	if _is_weapon_slot(slot):
		_weapon_sets[active_weapon_set].erase(slot)
	_recalc_set_bonuses()
	changed.emit(slot)
	return item

func get_equipped(slot: Slot) -> ItemBase:
	return slots.get(slot)

## True when the primary hand holds a two-handed weapon, blocking the
## off-hand slot.
func is_two_handed() -> bool:
	var weapon := get_equipped(Slot.PRIMARY_HAND) as Weapon
	return weapon != null and weapon.two_handed

static func slot_accepts(slot: Slot, item: ItemBase) -> bool:
	match slot:
		Slot.PRIMARY_HAND:
			return item is Weapon
		Slot.OFF_HAND:
			return item is Weapon or item is Shield
		Slot.HEAD:
			return item is Armor and (item as Armor).armor_slot == Armor.ArmorSlot.HEAD
		Slot.CHEST:
			return item is Armor and (item as Armor).armor_slot == Armor.ArmorSlot.CHEST
		Slot.FEET:
			return item is Armor and (item as Armor).armor_slot == Armor.ArmorSlot.FEET
		Slot.GAUNTLETS:
			return item is Armor and (item as Armor).armor_slot == Armor.ArmorSlot.GAUNTLETS
		Slot.RING_1, Slot.RING_2:
			return item is Ring
		Slot.AMULET:
			return item is Amulet
		Slot.RUNE_STONE:
			return item is RuneStone
	return false

func swap_weapon_set() -> void:
	for s in [Slot.PRIMARY_HAND, Slot.OFF_HAND]:
		var item: ItemBase = slots.get(s)
		if item and owner_stats:
			owner_stats.remove_all_from_source(_source_id(s))
		if item:
			slots.erase(s)
	active_weapon_set = 1 - active_weapon_set
	for s in [Slot.PRIMARY_HAND, Slot.OFF_HAND]:
		var item: ItemBase = _weapon_sets[active_weapon_set].get(s)
		if item:
			slots[s] = item
			if owner_stats:
				item.apply_modifiers(owner_stats, _source_id(s))
	_recalc_set_bonuses()
	changed.emit(Slot.PRIMARY_HAND)
	changed.emit(Slot.OFF_HAND)
	Events.weapon_set_swapped.emit(active_weapon_set)

func get_weapon_set_item(set_index: int, slot: Slot) -> ItemBase:
	return _weapon_sets[set_index].get(slot)

func get_all_equipped() -> Array:
	var items: Array = []
	for item: ItemBase in slots.values():
		if item:
			items.append(item)
	return items


func get_active_set_bonuses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var equipped := get_all_equipped()
	var seen_sets: Dictionary = {}
	for item: ItemBase in equipped:
		if not item.set_def:
			continue
		if seen_sets.has(item.set_def.id):
			continue
		seen_sets[item.set_def.id] = true
		var count := AffixDB.count_set_pieces(item.set_def.id, equipped)
		result.append({
			"set_def": item.set_def,
			"equipped_count": count,
		})
	return result


static func _is_weapon_slot(slot: Slot) -> bool:
	return slot == Slot.PRIMARY_HAND or slot == Slot.OFF_HAND

func _source_id(slot: Slot) -> StringName:
	return StringName("equip_slot_%d" % slot)


func _recalc_set_bonuses() -> void:
	if not owner_stats:
		return
	owner_stats.remove_all_from_source(_SET_BONUS_SOURCE)
	var equipped := get_all_equipped()
	var seen_sets: Dictionary = {}
	for item: ItemBase in equipped:
		if not item.set_def:
			continue
		if seen_sets.has(item.set_def.id):
			continue
		seen_sets[item.set_def.id] = true
		var count := AffixDB.count_set_pieces(item.set_def.id, equipped)
		var mods: Dictionary = item.set_def.get_active_modifiers(count)
		for stat: StringName in mods:
			owner_stats.add_modifier(stat, mods[stat], _SET_BONUS_SOURCE)
