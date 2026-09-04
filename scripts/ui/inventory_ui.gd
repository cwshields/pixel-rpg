class_name InventoryUI
extends MenuBase
## Grid display of GameManager.player's inventory. Toggled by the
## "toggle_inventory" action (see Player._unhandled_input). Expects a
## GridContainer named "SlotGrid" (accessed via the %-unique-name
## shortcut, so mark that node "Access as Unique Name" in the editor).

## Optional custom slot scene; must implement set_slot_data(item, qty).
## Falls back to a plain TextureRect (icon only) if left unset.
@export var slot_scene: PackedScene

@onready var grid: GridContainer = %SlotGrid

func _on_open() -> void:
	refresh()

func refresh() -> void:
	for child in grid.get_children():
		child.queue_free()
	var player: Player = GameManager.player
	if not player:
		return
	for slot in player.inventory.slots:
		var slot_node: Control = slot_scene.instantiate() if slot_scene else TextureRect.new()
		grid.add_child(slot_node)
		if slot_node.has_method("set_slot_data"):
			slot_node.call("set_slot_data", slot.item, slot.quantity)
		elif slot_node is TextureRect and slot.item.icon:
			(slot_node as TextureRect).texture = slot.item.icon
