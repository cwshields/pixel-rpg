class_name HotbarStrip
extends Control

const SLOTS_BG := preload("res://assets/UI/inventory/hotbar_slots.png")
const SELECTED_MARKER := preload("res://assets/UI/inventory/wield-selected.png")
const SLOT_SIZE := 88
const SLOT_COUNT := 8
const ICON_PAD := 12
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.15)

var _selected: int = 0
var _inventory: Inventory

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	Events.hotbar_selection_changed.connect(_on_hotbar_changed)

func setup(p_inventory: Inventory) -> void:
	_inventory = p_inventory
	if not _inventory.changed.is_connected(_on_inv_changed):
		_inventory.changed.connect(_on_inv_changed)
	queue_redraw()

func _on_hotbar_changed(idx: int, _item: ItemBase) -> void:
	_selected = idx
	queue_redraw()

func _on_inv_changed() -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _inventory:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var idx := _slot_at(get_local_mouse_position())
			if idx >= 0:
				Events.hotbar_selection_changed.emit(idx, _item_at(idx))
				get_viewport().set_input_as_handled()

func _slot_at(pos: Vector2) -> int:
	if pos.y < 0 or pos.y > SLOT_SIZE:
		return -1
	var idx := int(pos.x / SLOT_SIZE)
	if idx < 0 or idx >= SLOT_COUNT:
		return -1
	return idx

func _item_at(idx: int) -> ItemBase:
	if _inventory and idx < _inventory.items.size():
		return _inventory.items[idx].item
	return null

func _draw() -> void:
	var bg_w := SLOTS_BG.get_width() * 2
	var bg_h := SLOTS_BG.get_height() * 2
	draw_texture_rect(SLOTS_BG, Rect2(0, 0, bg_w, bg_h), false)
	if not _inventory:
		return
	for i in SLOT_COUNT:
		var x := i * SLOT_SIZE
		if i < _inventory.items.size():
			var placed := _inventory.items[i]
			if placed.item.icon:
				var icon_rect := Rect2(x + ICON_PAD, ICON_PAD, SLOT_SIZE - ICON_PAD * 2, SLOT_SIZE - ICON_PAD * 2)
				draw_texture_rect(placed.item.icon, icon_rect, false)
		if i == _selected:
			draw_rect(Rect2(x, 0, SLOT_SIZE, SLOT_SIZE), HIGHLIGHT_COLOR, true)
			var mw := SELECTED_MARKER.get_width() * 2
			var mh := SELECTED_MARKER.get_height() * 2
			var mx := x + (SLOT_SIZE - mw) / 2.0
			draw_texture_rect(SELECTED_MARKER, Rect2(mx, SLOT_SIZE - mh - 2, mw, mh), false)
