class_name EquipmentPanel
extends Control

const HOVER_COLOR := Color(1, 1, 1, 0.18)
const VALID_COLOR := Color(0.45, 1.0, 0.45, 0.25)
const INVALID_COLOR := Color(1.0, 0.35, 0.35, 0.25)
const ACTIVE_SET_COLOR := Color(0.894, 0.729, 0.522, 1.0)
const INACTIVE_SET_COLOR := Color(0.55, 0.48, 0.4, 0.45)
const WIELD_SELECTED := preload("res://assets/UI/inventory/wield-selected.png")

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
var _set_labels_primary: Array[Label] = []
var _set_labels_offhand: Array[Label] = []
var _set_markers_primary: Array[TextureRect] = []
var _set_markers_offhand: Array[TextureRect] = []

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
	_build_weapon_set_tabs($PrimaryHand, _set_labels_primary, _set_markers_primary)
	_build_weapon_set_tabs($OffHand, _set_labels_offhand, _set_markers_offhand)
	Events.weapon_set_swapped.connect(_on_weapon_set_swapped)

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
		if grid:
			grid.show_external_tooltip(item)
		Events.inventory_item_hovered.emit(item)
	else:
		if grid:
			grid.show_external_tooltip(null)
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
	grid._play_place_sfx(held_data.item)
	var previous: ItemBase = equipment.equip(def.slot, held_data.item)
	if previous:
		grid.pick_up_new(previous, 1)

func _try_unequip(def: SlotDef) -> void:
	var item := equipment.get_equipped(def.slot)
	if not item:
		return
	equipment.unequip(def.slot)
	grid.pick_up_new(item, 1)

func _build_weapon_set_tabs(slot_node: Control, labels: Array[Label], markers: Array[TextureRect]) -> void:
	var tab_w := slot_node.size.x / 2.0
	var tab_h := 28.0
	for i in 2:
		var marker := TextureRect.new()
		marker.texture = WIELD_SELECTED
		marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		marker.position = Vector2(slot_node.position.x + i * tab_w, slot_node.position.y - tab_h)
		marker.size = Vector2(tab_w, tab_h)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.visible = (i == 0)
		add_child(marker)
		markers.append(marker)

		var lbl := Label.new()
		lbl.text = "I" if i == 0 else "II"
		lbl.position = Vector2(slot_node.position.x + i * tab_w, slot_node.position.y - tab_h)
		lbl.size = Vector2(tab_w, tab_h)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", ACTIVE_SET_COLOR if i == 0 else INACTIVE_SET_COLOR)
		lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.gui_input.connect(_on_set_label_clicked.bind(i))
		add_child(lbl)
		labels.append(lbl)

func _on_set_label_clicked(event: InputEvent, set_index: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if equipment and equipment.active_weapon_set != set_index:
			equipment.swap_weapon_set()
			get_viewport().set_input_as_handled()

func _on_weapon_set_swapped(active_set: int) -> void:
	_update_set_labels(_set_labels_primary, _set_markers_primary, active_set)
	_update_set_labels(_set_labels_offhand, _set_markers_offhand, active_set)
	_refresh_icons()

func _update_set_labels(labels: Array[Label], markers: Array[TextureRect], active_set: int) -> void:
	for i in labels.size():
		var active := (i == active_set)
		labels[i].add_theme_color_override("font_color", ACTIVE_SET_COLOR if active else INACTIVE_SET_COLOR)
		markers[i].visible = active
