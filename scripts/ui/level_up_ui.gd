class_name LevelUpUI
extends MenuBase

const LABEL_COLOR := Color(0.894, 0.729, 0.522, 1.0)
const VALUE_COLOR := Color(0.96, 0.94, 0.88, 1.0)
const OUTLINE_COLOR := Color(0.05, 0.04, 0.06)
const GOLD_COLOR := Color(0.82, 0.65, 0.24)
const TRADEOFF_COLOR := Color(0.85, 0.35, 0.35, 0.85)
const BENEFIT_COLOR := Color(0.5, 0.82, 0.45, 0.85)
const BG_COLOR := Color(0.06, 0.05, 0.08, 0.88)
const PANEL_BG := Color(0.10, 0.09, 0.12, 0.95)
const ROW_BG := Color(0.13, 0.12, 0.16, 0.8)
const PENDING_COLOR := Color(0.45, 0.82, 0.45)

const STAT_ICONS := {
	&"strength": preload("res://assets/UI/inventory/stat_strength.png"),
	&"constitution": preload("res://assets/UI/inventory/stat_constitution.png"),
	&"dexterity": preload("res://assets/UI/inventory/stat_dexterity.png"),
	&"charisma": preload("res://assets/UI/inventory/stat_charisma.png"),
	&"intelligence": preload("res://assets/UI/inventory/stat_intelligence.png"),
}

const STAT_LABELS := {
	&"strength": "Strength",
	&"constitution": "Constitution",
	&"dexterity": "Dexterity",
	&"charisma": "Charisma",
	&"intelligence": "Intelligence",
}

const STAT_BENEFITS := {
	&"strength": "+0.5 Attack, +0.3 Defense, +0.3 Phys Resist, +2 Carry Weight",
	&"constitution": "+2 Max Health, +1.5 Max Stamina, +0.2 Regen",
	&"dexterity": "+0.01 Block, +0.005 Crit, +0.005 Speed, +0.2 Move Spd, +0.4 Evasion",
	&"charisma": "Improves haggling and NPC favor",
	&"intelligence": "+0.3 All Magic Dmg, +0.3 Luck, +2 Max Mana",
}

const STAT_TRADEOFFS := {
	&"strength": "-0.003 Speed, -0.15 Evasion",
	&"constitution": "",
	&"dexterity": "-0.05 Defense",
	&"charisma": "",
	&"intelligence": "-0.1 Defense",
}

var _level_label: Label
var _xp_label: Label
var _xp_bar: ColorRect
var _points_label: Label
var _confirm_btn: Button
var _stat_rows: Dictionary = {}
var _stat_value_labels: Dictionary = {}
var _plus_buttons: Dictionary = {}
var _minus_buttons: Dictionary = {}

var _pending: Dictionary = {}
var _pending_points: int = 0

func _on_open() -> void:
	UIManager.close_screen(&"inventory")
	UIManager.close_screen(&"shop")
	UIManager.close_screen(&"item_spawner")
	_reset_pending()
	_refresh()

func _on_close() -> void:
	_reset_pending()

func _ready() -> void:
	super._ready()
	Events.level_up.connect(func(_e: Node, _l: int, _p: int) -> void:
		if visible:
			_reset_pending()
			_refresh())
	_build_ui()

func _reset_pending() -> void:
	_pending.clear()
	_pending_points = 0
	for attr: StringName in StatsComponent.VALID_ATTRIBUTES:
		_pending[attr] = 0

func _total_available() -> int:
	var player: Player = GameManager.player if GameManager.player else null
	if not player or not player.stats:
		return 0
	return player.stats.stat_points - _pending_points

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = BG_COLOR
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = -290.0
	panel.offset_bottom = 290.0
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := _styled_label("Character", 24, GOLD_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header_row)

	_level_label = _styled_label("Level 1", 18, VALUE_COLOR)
	header_row.add_child(_level_label)

	_xp_label = _styled_label("XP: 0/100", 14, LABEL_COLOR)
	header_row.add_child(_xp_label)

	var xp_bg := ColorRect.new()
	xp_bg.color = Color(0.06, 0.05, 0.08, 0.92)
	xp_bg.custom_minimum_size = Vector2(0, 6)
	xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(xp_bg)

	_xp_bar = ColorRect.new()
	_xp_bar.color = GOLD_COLOR
	_xp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_bar.anchor_right = 0.0
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bg.add_child(_xp_bar)

	_points_label = _styled_label("Available Points: 0", 18, GOLD_COLOR)
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_points_label)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	for attr: StringName in StatsComponent.VALID_ATTRIBUTES:
		vbox.add_child(_build_stat_row(attr))

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm"
	_confirm_btn.custom_minimum_size = Vector2(0, 36)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_btn)

func _build_stat_row(attr: StringName) -> Control:
	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = ROW_BG
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_style.content_margin_left = 10.0
	row_style.content_margin_right = 10.0
	row_style.content_margin_top = 6.0
	row_style.content_margin_bottom = 6.0
	row_panel.add_theme_stylebox_override("panel", row_style)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	row_panel.add_child(outer)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	outer.add_child(top_row)

	var icon := TextureRect.new()
	icon.texture = STAT_ICONS.get(attr)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(icon)

	var name_label := _styled_label(STAT_LABELS.get(attr, ""), 16, LABEL_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	var val_label := _styled_label("5", 16, VALUE_COLOR)
	val_label.custom_minimum_size.x = 50.0
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(val_label)
	_stat_value_labels[attr] = val_label

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(32, 28)
	minus_btn.disabled = true
	minus_btn.pressed.connect(func() -> void: _on_minus_pressed(attr))
	top_row.add_child(minus_btn)
	_minus_buttons[attr] = minus_btn

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(32, 28)
	plus_btn.pressed.connect(func() -> void: _on_plus_pressed(attr))
	top_row.add_child(plus_btn)
	_plus_buttons[attr] = plus_btn

	var benefit_label := _styled_label(STAT_BENEFITS.get(attr, ""), 11, BENEFIT_COLOR)
	benefit_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	outer.add_child(benefit_label)

	var tradeoff_text: String = STAT_TRADEOFFS.get(attr, "")
	if not tradeoff_text.is_empty():
		var tradeoff_label := _styled_label(tradeoff_text, 11, TRADEOFF_COLOR)
		tradeoff_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		outer.add_child(tradeoff_label)

	_stat_rows[attr] = row_panel
	return row_panel

func _on_plus_pressed(attr: StringName) -> void:
	if _total_available() <= 0:
		return
	_pending[attr] += 1
	_pending_points += 1
	_refresh()

func _on_minus_pressed(attr: StringName) -> void:
	if _pending.get(attr, 0) <= 0:
		return
	_pending[attr] -= 1
	_pending_points -= 1
	_refresh()

func _on_confirm() -> void:
	var player: Player = GameManager.player if GameManager.player else null
	if not player or not player.stats:
		return
	for attr: StringName in StatsComponent.VALID_ATTRIBUTES:
		var count: int = _pending.get(attr, 0)
		for i in count:
			player.stats.allocate_point(attr)
	_reset_pending()
	_refresh()

func _refresh() -> void:
	var player: Player = GameManager.player if GameManager.player else null
	if not player or not player.stats:
		return
	var s := player.stats
	_level_label.text = "Level %d" % s.level
	_xp_label.text = "XP: %d / %d" % [s.current_xp, s.xp_for_next_level()]
	var needed := s.xp_for_next_level()
	_xp_bar.anchor_right = clampf(float(s.current_xp) / float(needed), 0.0, 1.0) if needed > 0 else 0.0

	var avail := _total_available()
	_points_label.text = "Available Points: %d" % avail

	var has_pending := _pending_points > 0
	_confirm_btn.disabled = not has_pending

	for attr: StringName in StatsComponent.VALID_ATTRIBUTES:
		var val_label: Label = _stat_value_labels.get(attr)
		if val_label:
			var base_val: float = 0.0
			match attr:
				&"strength": base_val = s.strength
				&"constitution": base_val = s.constitution
				&"dexterity": base_val = s.dexterity
				&"charisma": base_val = s.charisma
				&"intelligence": base_val = s.intelligence
			var pend: int = _pending.get(attr, 0)
			if pend > 0:
				val_label.text = "%d (+%d)" % [roundi(base_val), pend]
				val_label.add_theme_color_override("font_color", PENDING_COLOR)
			else:
				val_label.text = "%d" % roundi(base_val)
				val_label.add_theme_color_override("font_color", VALUE_COLOR)

		var plus_btn: Button = _plus_buttons.get(attr)
		if plus_btn:
			plus_btn.disabled = avail <= 0

		var minus_btn: Button = _minus_buttons.get(attr)
		if minus_btn:
			minus_btn.disabled = _pending.get(attr, 0) <= 0

func _styled_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
