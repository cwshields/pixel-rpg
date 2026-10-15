class_name HotbarStrip
extends Control

const SLOTS_BG := preload("res://assets/UI/inventory/hotbar_slots.png")
const SELECTED_MARKER := preload("res://assets/UI/inventory/wield-selected.png")
const SLOT_SIZE := 88
const SLOT_COUNT := 8
const ICON_PAD := 12
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.15)
const ASSIGN_COLOR := Color(0.45, 1.0, 0.45, 0.25)
const CLEAR_COLOR := Color(1.0, 0.35, 0.35, 0.25)

var _selected: int = 0
var _inventory: Inventory
var _grid: InventoryGrid
var _hovered_slot: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	Events.hotbar_selection_changed.connect(_on_hotbar_changed)
	Events.hotbar_slot_changed.connect(func(_idx: int, _item: ItemBase) -> void: queue_redraw())

func setup(p_inventory: Inventory, p_grid: InventoryGrid = null) -> void:
	_inventory = p_inventory
	_grid = p_grid
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
		var idx := _slot_at(get_local_mouse_position())
		if idx < 0:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _grid and _grid.has_held_item():
				_try_assign_held(idx)
				get_viewport().set_input_as_handled()
			else:
				Events.hotbar_selection_changed.emit(idx, _item_at(idx))
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var player := GameManager.player as Player
			if player and _item_at(idx):
				player.clear_hotbar_slot(idx)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var idx := _slot_at(get_local_mouse_position())
		if idx != _hovered_slot:
			_hovered_slot = idx
			queue_redraw()

func _try_assign_held(idx: int) -> void:
	if not _grid or not _grid.has_held_item():
		return
	var held_item := _grid.get_held_item()
	if not held_item is Consumable:
		return
	var player := GameManager.player as Player
	if not player:
		return
	var held_data := _grid.take_held_item()
	_inventory.add_item(held_data.item, held_data.quantity)
	player.assign_hotbar_slot(idx, held_data.item)

func _slot_at(pos: Vector2) -> int:
	if pos.y < 0 or pos.y > SLOT_SIZE:
		return -1
	var idx := int(pos.x / SLOT_SIZE)
	if idx < 0 or idx >= SLOT_COUNT:
		return -1
	return idx

func _item_at(idx: int) -> ItemBase:
	var player := GameManager.player as Player
	if player and idx < player.hotbar_slots.size():
		return player.hotbar_slots[idx]
	return null

func _draw() -> void:
	var bg_w := SLOTS_BG.get_width() * 2
	var bg_h := SLOTS_BG.get_height() * 2
	draw_texture_rect(SLOTS_BG, Rect2(0, 0, bg_w, bg_h), false)
	var player := GameManager.player as Player
	if not player:
		return
	for i in SLOT_COUNT:
		var x := i * SLOT_SIZE
		var item: ItemBase = null
		if i < player.hotbar_slots.size():
			item = player.hotbar_slots[i]
		if item and item.icon:
			var qty := _inventory.count_item(item.id) if _inventory else 0
			var icon_rect := Rect2(x + ICON_PAD, ICON_PAD, SLOT_SIZE - ICON_PAD * 2, SLOT_SIZE - ICON_PAD * 2)
			var mod := Color.WHITE if qty > 0 else Color(1, 1, 1, 0.35)
			draw_texture_rect(item.icon, icon_rect, false, mod)
		if i == _selected:
			draw_rect(Rect2(x, 0, SLOT_SIZE, SLOT_SIZE), HIGHLIGHT_COLOR, true)
			var mw := SELECTED_MARKER.get_width() * 2
			var mh := SELECTED_MARKER.get_height() * 2
			var mx := x + (SLOT_SIZE - mw) / 2.0
			draw_texture_rect(SELECTED_MARKER, Rect2(mx, SLOT_SIZE - mh - 2, mw, mh), false)
		if _hovered_slot == i and _grid and _grid.has_held_item():
			var color := ASSIGN_COLOR if _grid.get_held_item() is Consumable else CLEAR_COLOR
			draw_rect(Rect2(x, 0, SLOT_SIZE, SLOT_SIZE), color, true)
