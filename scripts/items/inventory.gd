class_name Inventory
extends RefCounted
## Simple stack-based inventory. A RefCounted (not a Resource) because
## each entity needs its own independent instance — Resources are shared
## by reference unless you remember to duplicate() them everywhere.

signal changed

class Slot:
	var item: ItemBase
	var quantity: int
	func _init(p_item: ItemBase, p_quantity: int) -> void:
		item = p_item
		quantity = p_quantity

var capacity: int
var slots: Array[Slot] = []

func _init(p_capacity: int = 24) -> void:
	capacity = p_capacity

## Adds `amount` of `item`, stacking onto existing slots first, then
## filling new slots up to capacity. Returns whatever didn't fit (0 if
## everything was added).
func add_item(item: ItemBase, amount: int = 1) -> int:
	var remaining: int = amount
	for slot in slots:
		if remaining <= 0:
			break
		if slot.item.id == item.id and slot.quantity < slot.item.max_stack:
			var space: int = slot.item.max_stack - slot.quantity
			var to_add: int = mini(space, remaining)
			slot.quantity += to_add
			remaining -= to_add
	while remaining > 0 and slots.size() < capacity:
		var to_add: int = mini(item.max_stack, remaining)
		slots.append(Slot.new(item, to_add))
		remaining -= to_add
	if remaining != amount:
		changed.emit()
		Events.inventory_changed.emit()
	return remaining

## Removes up to `amount` of the item matching `item_id`. Returns false
## (removing nothing) if the inventory doesn't hold that much.
func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if count_item(item_id) < amount:
		return false
	var remaining: int = amount
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var slot: Slot = slots[i]
		if slot.item.id != item_id:
			continue
		var take: int = mini(slot.quantity, remaining)
		slot.quantity -= take
		remaining -= take
		if slot.quantity <= 0:
			slots.remove_at(i)
	changed.emit()
	Events.inventory_changed.emit()
	return true

func count_item(item_id: StringName) -> int:
	var total: int = 0
	for slot in slots:
		if slot.item.id == item_id:
			total += slot.quantity
	return total

func has_item(item_id: StringName, amount: int = 1) -> bool:
	return count_item(item_id) >= amount
