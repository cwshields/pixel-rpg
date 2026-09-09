class_name HotbarSlot
extends Control
## One cell of the on-screen Hotbar. Built entirely in code by hotbar.gd
## (no scene file) so the whole widget is one script to reason about.
## Shows the item icon + stack count and the hotkey digit in the corner.
## The slot cell itself is part of the bar art, so the background is a
## no-op tint and the frame texture only appears while the slot is
## selected.

const _BG_COLOR := Color(0.12, 0.11, 0.16, 0.0)

var _bg: ColorRect
var _frame: NinePatchRect
var _icon: TextureRect
var _key_label: Label
var _qty_label: Label

var _tex_normal: Texture2D
var _tex_selected: Texture2D
var _patch_margin: int = 5

func _init(size_px: int, hotkey: int, tex_normal: Texture2D, tex_selected: Texture2D, patch_margin: int) -> void:
	_tex_normal = tex_normal
	_tex_selected = tex_selected
	_patch_margin = patch_margin
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bg = ColorRect.new()
	_bg.color = _BG_COLOR
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_frame = NinePatchRect.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.texture = _tex_selected
	_frame.visible = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_frame.set_patch_margin(side, _patch_margin)
	add_child(_frame)

	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 9
	_icon.offset_top = 9
	_icon.offset_right = -9
	_icon.offset_bottom = -9
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_key_label = _make_label(str(hotkey), HORIZONTAL_ALIGNMENT_LEFT)
	_key_label.offset_left = 5
	_key_label.offset_top = 2
	add_child(_key_label)

	_qty_label = _make_label("", HORIZONTAL_ALIGNMENT_RIGHT)
	_qty_label.offset_right = -4
	_qty_label.offset_bottom = -2
	_qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_qty_label)

func _make_label(text: String, halign: int) -> Label:
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = halign
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(0.91, 0.88, 0.82))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	l.add_theme_constant_override("outline_size", 6)
	return l

func set_item(item: ItemBase, quantity: int) -> void:
	_icon.texture = item.icon if item else null
	_qty_label.text = str(quantity) if quantity > 1 else ""

func set_selected(selected: bool) -> void:
	_frame.visible = selected and _tex_selected != null
	_key_label.add_theme_color_override(
		"font_color", Color(1.0, 0.78, 0.47) if selected else Color(0.91, 0.88, 0.82))
