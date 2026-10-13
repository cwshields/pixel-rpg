class_name Equipment
extends RefCounted
## Tracks what's equipped in each slot and applies/removes the item's
## stat modifiers on the linked StatsComponent. One instance per entity
## (set `owner_stats` right after creating it — see Player._ready()).

## Emitted after `slot`'s contents change (equip or unequip).
signal changed(slot: Slot)

enum Slot { PRIMARY_HAND, HEAD, CHEST, FEET, OFF_HAND, RING_1, RING_2, AMULET, RUNE_STONE, GAUNTLETS }

var owner_stats: StatsComponent
var slots: Dictionary = {}   # Slot -> ItemBase

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
	changed.emit(slot)
	return previous

func unequip(slot: Slot) -> ItemBase:
	if not slots.has(slot):
		return null
	var item: ItemBase = slots[slot]
	slots.erase(slot)
	if owner_stats:
		owner_stats.remove_all_from_source(_source_id(slot))
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
		Slot.PRIMARY_HAND, Slot.OFF_HAND:
			return item is Weapon
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

func _source_id(slot: Slot) -> StringName:
	return StringName("equip_slot_%d" % slot)
