class_name EquipmentPanel
extends Control

const HOVER_COLOR := Color(1, 1, 1, 0.18)
const VALID_COLOR := Color(0.45, 1.0, 0.45, 0.25)
const INVALID_COLOR := Color(1.0, 0.35, 0.35, 0.25)

class SlotDef:
	var slot: Equipment.Slot
	var node: Control
	var icon: TextureRect
	var hover: ColorRect
	func _init(p_slot: Equipment.Slot, p_node: Control) -> void:
		slot = p_slot
		node = p_node
		icon = p_node.get_node("Icon")
		hover = p_node.get_node("Hover")

var _slots: Array[SlotDef] = []
var _hovered_idx: int = -1
var equipment: Equipment
var grid: InventoryGrid

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_slots.append(SlotDef.new(Equipment.Slot.RUNE_STONE, $RuneStone))
	_slots.append(SlotDef.new(Equipment.Slot.HEAD, $Head))
	_slots.append(SlotDef.new(Equipment.Slot.AMULET, $Amulet))
	_slots.append(SlotDef.new(Equipment.Slot.PRIMARY_HAND, $PrimaryHand))
	_slots.append(SlotDef.new(Equipment.Slot.CHEST, $Chest))
	_slots.append(SlotDef.new(Equipment.Slot.OFF_HAND, $OffHand))
	_slots.append(SlotDef.new(Equipment.Slot.GAUNTLETS, $Gauntlets))
	_slots.append(SlotDef.new(Equipment.Slot.RING_1, $Ring1))
	_slots.append(SlotDef.new(Equipment.Slot.RING_2, $Ring2))
	_slots.append(SlotDef.new(Equipment.Slot.FEET, $Feet))

func setup(p_equipment: Equipment, p_grid: InventoryGrid) -> void:
	equipment = p_equipment
	grid = p_grid
	if not equipment.changed.is_connected(_on_equipment_changed):
		equipment.changed.connect(_on_equipment_changed)
	_refresh_icons()

func _on_equipment_changed(_slot: Equipment.Slot) -> void:
	_refresh_icons()

func _refresh_icons() -> void:
	if not equipment:
		return
	for def in _slots:
		var item := equipment.get_equipped(def.slot)
		if item and item.icon:
			def.icon.texture = item.icon
			def.icon.visible = true
		else:
			def.icon.visible = false

func _slot_at(pos: Vector2) -> int:
	for i in _slots.size():
		var r := Rect2(_slots[i].node.position, _slots[i].node.size)
		if r.has_point(pos):
			return i
	return -1

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not equipment:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var local := get_local_mouse_position()
			var idx := _slot_at(local)
			if idx >= 0:
				_handle_click(idx)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var local := get_local_mouse_position()
		var new_idx := _slot_at(local)
		if new_idx != _hovered_idx:
			_update_hover(new_idx)

func _update_hover(new_idx: int) -> void:
	if _hovered_idx >= 0:
		_slots[_hovered_idx].hover.visible = false
	_hovered_idx = new_idx
	if new_idx >= 0:
		var def := _slots[new_idx]
		def.hover.visible = true
		if grid and grid.has_held_item():
			var held := grid.get_held_item()
			def.hover.color = VALID_COLOR if Equipment.slot_accepts(def.slot, held) else INVALID_COLOR
		else:
			def.hover.color = HOVER_COLOR
		var item := equipment.get_equipped(def.slot)
		Events.inventory_item_hovered.emit(item)
	else:
		Events.inventory_item_hovered.emit(null)

func _handle_click(idx: int) -> void:
	var def := _slots[idx]
	if grid.has_held_item():
		_try_equip(def)
	else:
		_try_unequip(def)

func _try_equip(def: SlotDef) -> void:
	var held := grid.get_held_item()
	if not Equipment.slot_accepts(def.slot, held):
		return
	var held_data := grid.take_held_item()
	var previous: ItemBase = equipment.equip(def.slot, held_data.item)
	if previous:
		grid.pick_up_new(previous, 1)

func _try_unequip(def: SlotDef) -> void:
	var item := equipment.get_equipped(def.slot)
	if not item:
		return
	equipment.unequip(def.slot)
	grid.pick_up_new(item, 1)
