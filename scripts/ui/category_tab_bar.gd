class_name CategoryTabBar
extends Control

signal tab_changed(category: StringName)

const TAB_BG := preload("res://assets/UI/inventory/tab_category.png")
const TAB_SEL_BG := preload("res://assets/UI/inventory/tab_selected_bg.png")
const TAB_SEL_BORDER := preload("res://assets/UI/inventory/tab_selected_border.png")
const STRIP_BG := preload("res://assets/UI/inventory/grid_tab_bg.png")

const TAB_ICONS := [
	preload("res://assets/UI/inventory/icon_all_tab.png"),
	preload("res://assets/UI/inventory/weapons_tab_icon.png"),
	preload("res://assets/UI/inventory/icon_armor_tab.png"),
	preload("res://assets/UI/inventory/potions_tab_icon.png"),
	preload("res://assets/UI/inventory/icon_food_tab.png"),
	preload("res://assets/UI/inventory/icon_keys_tab.png"),
	preload("res://assets/UI/inventory/spells_tab_icon.png"),
	preload("res://assets/UI/inventory/icon_materials_tab.png"),
]

const CATEGORIES: Array[StringName] = [
	&"all", &"weapons", &"armor", &"potions",
	&"food", &"keys", &"spells", &"materials",
]

const TAB_COUNT := 8
const TAB_W := 80
const TAB_H := 78
const HOVER_COLOR := Color(1, 1, 1, 0.12)

var _selected: int = 0
var _hovered: int = -1
var _tab_rects: Array[Rect2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_tab_rects()

func _build_tab_rects() -> void:
	var centers := [34, 124, 212, 300, 388, 476, 566, 656]
	for cx in centers:
		var x: int = cx - TAB_W / 2
		_tab_rects.append(Rect2(x, 0, TAB_W, TAB_H))

func select_tab(idx: int) -> void:
	if idx < 0 or idx >= TAB_COUNT or idx == _selected:
		return
	_selected = idx
	queue_redraw()
	tab_changed.emit(CATEGORIES[idx])

func reset() -> void:
	_selected = 0
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var idx := _tab_at(get_local_mouse_position())
			if idx >= 0:
				select_tab(idx)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var idx := _tab_at(get_local_mouse_position())
		if idx != _hovered:
			_hovered = idx
			queue_redraw()

func _tab_at(pos: Vector2) -> int:
	for i in _tab_rects.size():
		if _tab_rects[i].has_point(pos):
			return i
	return -1

func _draw() -> void:
	var strip_rect := Rect2(0, floori((TAB_H - STRIP_BG.get_height() * 2) / 2.0),
		STRIP_BG.get_width() * 2, STRIP_BG.get_height() * 2)
	draw_texture_rect(STRIP_BG, strip_rect, false)

	for i in TAB_COUNT:
		var rect := _tab_rects[i]
		var x := int(rect.position.x)

		if i == _selected:
			draw_texture_rect(TAB_SEL_BG, Rect2(x, 0, TAB_W, TAB_H), false)
			var bx := x - 4
			var border_w := TAB_SEL_BORDER.get_width() * 2
			var border_h := TAB_SEL_BORDER.get_height() * 2
			draw_texture_rect(TAB_SEL_BORDER, Rect2(bx, -6, border_w, border_h), false)
		else:
			draw_texture_rect(TAB_BG, Rect2(x, 0, TAB_W, TAB_H), false)

		var icon: Texture2D = TAB_ICONS[i]
		var icon_w := icon.get_width() * 2
		var icon_h := icon.get_height() * 2
		var icon_x := x + floori((TAB_W - icon_w) / 2.0)
		var icon_y := floori((TAB_H - icon_h) / 2.0)
		draw_texture_rect(icon, Rect2(icon_x, icon_y, icon_w, icon_h), false)

		if i == _hovered and i != _selected:
			draw_rect(rect, HOVER_COLOR, true)
