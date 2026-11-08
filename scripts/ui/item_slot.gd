class_name ItemSlot
extends Control
## A single-item drop target for crafting UIs. Accepts items from an
## InventoryGrid held-item system, filtered by an optional Callable.

signal item_placed(item: ItemBase, quantity: int)
signal item_removed(item: ItemBase, quantity: int)

const SLOT_SIZE := 64
const ICON_SIZE := 48
const BORDER_COLOR := Color(0.35, 0.32, 0.28, 1.0)
const EMPTY_COLOR := Color(0.12, 0.11, 0.10, 0.6)
const HOVER_COLOR := Color(0.45, 0.42, 0.38, 0.4)
const INVALID_COLOR := Color(0.6, 0.2, 0.2, 0.3)

var item: ItemBase = null
var quantity: int = 0
var accept_filter: Callable
var linked_grid: Control = null  ## InventoryGrid to pull held items from
var label_text: String = ""

var _hovered: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(SLOT_SIZE, SLOT_SIZE))

	draw_rect(rect, EMPTY_COLOR)
	draw_rect(rect, BORDER_COLOR, false, 2.0)

	if _hovered:
		var can_accept := true
		if linked_grid and linked_grid.has_held_item():
			var held: ItemBase = linked_grid.get_held_item()
			if accept_filter.is_valid() and not accept_filter.call(held):
				can_accept = false
		draw_rect(rect, HOVER_COLOR if can_accept else INVALID_COLOR)

	if item and item.icon:
		var icon_offset := Vector2((SLOT_SIZE - ICON_SIZE) * 0.5,
			(SLOT_SIZE - ICON_SIZE) * 0.5)
		draw_texture_rect(item.icon, Rect2(icon_offset,
			Vector2(ICON_SIZE, ICON_SIZE)), false)

		if quantity > 1:
			var font := ThemeDB.fallback_font
			var fsize := 11
			var qty_text := str(quantity)
			var text_size := font.get_string_size(qty_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, fsize)
			var text_pos := Vector2(SLOT_SIZE - text_size.x - 4, SLOT_SIZE - 4)
			draw_string_outline(font, text_pos, qty_text, HORIZONTAL_ALIGNMENT_RIGHT,
				-1, fsize, 3, Color(0.05, 0.04, 0.06))
			draw_string(font, text_pos, qty_text, HORIZONTAL_ALIGNMENT_RIGHT,
				-1, fsize, Color(0.96, 0.94, 0.88))

	elif label_text != "":
		var font := ThemeDB.fallback_font
		var fsize := 9
		var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE - 8, fsize)
		var text_pos := Vector2(4, (SLOT_SIZE + text_size.y) * 0.5)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER,
			SLOT_SIZE - 8, fsize, Color(0.5, 0.48, 0.42))


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if item:
		_return_item()
	elif linked_grid and linked_grid.has_held_item():
		_accept_from_grid()
	get_viewport().set_input_as_handled()


func try_place(p_item: ItemBase, p_quantity: int = 1) -> bool:
	if accept_filter.is_valid() and not accept_filter.call(p_item):
		return false
	if item:
		return false
	item = p_item
	quantity = p_quantity
	queue_redraw()
	item_placed.emit(item, quantity)
	return true


func take_item() -> Dictionary:
	if not item:
		return {}
	var result := {"item": item, "quantity": quantity}
	item = null
	quantity = 0
	queue_redraw()
	return result


func clear() -> void:
	if item:
		var old_item := item
		var old_qty := quantity
		item = null
		quantity = 0
		queue_redraw()
		item_removed.emit(old_item, old_qty)


func is_empty() -> bool:
	return item == null


func _accept_from_grid() -> void:
	if not linked_grid or not linked_grid.has_held_item():
		return
	var held: ItemBase = linked_grid.get_held_item()
	if accept_filter.is_valid() and not accept_filter.call(held):
		return
	var data: Dictionary = linked_grid.take_held_item()
	if data.is_empty():
		return
	item = data["item"]
	quantity = data["quantity"]
	queue_redraw()
	item_placed.emit(item, quantity)


func _return_item() -> void:
	if not item:
		return
	var old_item := item
	var old_qty := quantity
	if linked_grid and linked_grid.inventory:
		linked_grid.inventory.add_item(old_item, old_qty)
	item = null
	quantity = 0
	queue_redraw()
	item_removed.emit(old_item, old_qty)
