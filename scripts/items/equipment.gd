class_name Equipment
extends RefCounted
## Tracks what's equipped in each slot and applies/removes the item's
## stat modifiers on the linked StatsComponent. One instance per entity
## (set `owner_stats` right after creating it — see Player._ready()).

enum Slot { WEAPON, HEAD, CHEST, LEGS, FEET, SHIELD, RING_1, RING_2, AMULET }

var owner_stats: StatsComponent
var slots: Dictionary = {}   # Slot -> ItemBase

## Equips `item` into `slot`, returning whatever was previously there
## (or null). Swap the previous item back into the inventory yourself —
## Equipment doesn't know about Inventory to keep the two decoupled.
func equip(slot: Slot, item: ItemBase) -> ItemBase:
	var previous: ItemBase = unequip(slot)
	slots[slot] = item
	if owner_stats and item:
		item.apply_modifiers(owner_stats, _source_id(slot))
	return previous

func unequip(slot: Slot) -> ItemBase:
	if not slots.has(slot):
		return null
	var item: ItemBase = slots[slot]
	slots.erase(slot)
	if owner_stats:
		owner_stats.remove_all_from_source(_source_id(slot))
	return item

func get_equipped(slot: Slot) -> ItemBase:
	return slots.get(slot)

func _source_id(slot: Slot) -> StringName:
	return StringName("equip_slot_%d" % slot)
