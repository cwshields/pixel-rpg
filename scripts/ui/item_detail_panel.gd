class_name ItemDetailPanel
extends Control

const BOOST_COLOR := Color(0.4, 0.7, 1.0)

var _stat_values: Dictionary = {}

@onready var _summary_vbox: VBoxContainer = %SummaryVBox
@onready var _exp_value: Label = %ExpValue
@onready var _level_value: Label = %LevelValue

var _stat_points_label: Button

func _ready() -> void:
	_collect_values($SummaryVBox/MainGrid)
	_collect_values($SummaryVBox/RecoveryGrid)
	_collect_values($SummaryVBox/ResistGrid)
	_collect_values($SummaryVBox/DamageGrid)
	Events.stats_changed.connect(_on_stats_changed)
	Events.level_up.connect(_on_level_up)
	_build_stat_points_badge()
	_summary_vbox.visible = true
	_update_summary()

func _collect_values(grid: Control) -> void:
	for cell in grid.get_children():
		var val := cell.get_node_or_null("Text/Value") as Label
		if val:
			_stat_values[cell.name] = val

func _update_summary() -> void:
	var player: Player = GameManager.player if GameManager.player else null
	if not player or not player.stats:
		return

	var s := player.stats

	_level_value.text = str(s.level) if s else "1"
	_exp_value.text = "%d/%d" % [s.current_xp, s.xp_for_next_level()] if s else "0/0"
	_update_stat_points_badge(s)

	var m: float

	m = s.get_modifier_total(&"constitution")
	_set_val("ConstitutionCell", "%d" % roundi(s.constitution), m, _boost_tip(s.constitution - m, m))
	m = s.get_modifier_total(&"attack")
	_set_val("DamageCell", "%d" % roundi(s.attack), m, _boost_tip(s.attack - m, m))
	m = s.get_modifier_total(&"strength")
	_set_val("StrengthCell", "%d" % roundi(s.strength), m, _boost_tip(s.strength - m, m))
	m = s.get_modifier_total(&"defense")
	_set_val("DefenceCell", "%d" % roundi(s.defense), m, _boost_tip(s.defense - m, m))
	m = s.get_modifier_total(&"dexterity")
	_set_val("DexterityCell", "%d" % roundi(s.dexterity), m, _boost_tip(s.dexterity - m, m))
	m = s.get_modifier_total(&"block_chance")
	_set_val("BlockChanceCell", "%d%%" % roundi(s.block_chance * 100), m, _boost_tip(s.block_chance - m, m, 100.0, "%"))
	m = s.get_modifier_total(&"charisma")
	_set_val("CharismaCell", "%d" % roundi(s.charisma), m, _boost_tip(s.charisma - m, m))
	m = s.get_modifier_total(&"attack_speed")
	_set_val("AtkSpeedCell", "+%d%%" % roundi(s.attack_speed * 100), m, _boost_tip(s.attack_speed - m, m, 100.0, "%"))
	m = s.get_modifier_total(&"intelligence")
	_set_val("IntelligenceCell", "%d" % roundi(s.intelligence), m, _boost_tip(s.intelligence - m, m))
	m = s.get_modifier_total(&"move_speed")
	_set_val("MoveSpeedCell", "%d" % roundi(s.move_speed), m, _boost_tip(s.move_speed - m, m))

	m = s.get_modifier_total(&"regeneration")
	_set_val("RegenerationCell", "%d" % roundi(s.regeneration), m, _boost_tip(s.regeneration - m, m))
	m = s.get_modifier_total(&"lifesteal")
	_set_val("LifestealCell", "%d%%" % roundi(s.lifesteal * 100), m, _boost_tip(s.lifesteal - m, m, 100.0, "%"))
	m = s.get_modifier_total(&"luck")
	_set_val("LuckCell", "%d%%" % roundi(s.luck), m, _boost_tip(s.luck - m, m, 1.0, "%"))
	m = s.get_modifier_total(&"magic_find")
	_set_val("MagicFindCell", "%d%%" % roundi(s.magic_find * 100), m, _boost_tip(s.magic_find - m, m, 100.0, "%"))
	m = s.get_modifier_total(&"gold_find")
	_set_val("GoldFindCell", "%d%%" % roundi(s.gold_find * 100), m, _boost_tip(s.gold_find - m, m, 100.0, "%"))

	m = s.get_modifier_total(&"fire_resist")
	_set_val("FireResistCell", "%d%%" % roundi(s.fire_resist * 100), m, _boost_tip(s.fire_resist - m, m, 100.0, "%"))
	m = s.get_modifier_total(&"ice_resist")
	_set_val("IceResistCell", "%d%%" % roundi(s.ice_resist * 100), m, _boost_tip(s.ice_resist - m, m, 100.0, "%"))
	m = s.get_modifier_total(&"physical_resist")
	_set_val("PhysResistCell", "%d%%" % roundi(s.physical_resist * 100), m, _boost_tip(s.physical_resist - m, m, 100.0, "%"))
	m = s.get_modifier_total(&"venom_resist")
	_set_val("VenomResistCell", "%d%%" % roundi(s.venom_resist * 100), m, _boost_tip(s.venom_resist - m, m, 100.0, "%"))
	m = s.get_modifier_total(&"lightning_resist")
	_set_val("LightningResistCell", "%d%%" % roundi(s.lightning_resist * 100), m, _boost_tip(s.lightning_resist - m, m, 100.0, "%"))
	m = s.get_modifier_total(&"holy_arcana_resist")
	_set_val("HolyArcanaResistCell", "%d%%" % roundi(s.holy_arcana_resist * 100), m, _boost_tip(s.holy_arcana_resist - m, m, 100.0, "%"))

	m = s.get_modifier_total(&"fire_damage")
	_set_val("FireDamageCell", "%d" % roundi(s.fire_damage), m, _boost_tip(s.fire_damage - m, m))
	m = s.get_modifier_total(&"ice_damage")
	_set_val("IceDamageCell", "%d" % roundi(s.ice_damage), m, _boost_tip(s.ice_damage - m, m))
	m = s.get_modifier_total(&"evasion")
	_set_val("EvasionCell", "%d" % roundi(s.evasion), m, _boost_tip(s.evasion - m, m))
	m = s.get_modifier_total(&"venom_damage")
	_set_val("VenomDamageCell", "%d" % roundi(s.venom_damage), m, _boost_tip(s.venom_damage - m, m))
	m = s.get_modifier_total(&"lightning_damage")
	_set_val("LightningDamageCell", "%d" % roundi(s.lightning_damage), m, _boost_tip(s.lightning_damage - m, m))
	m = s.get_modifier_total(&"holy_arcana_damage")
	_set_val("HolyArcanaDamageCell", "%d" % roundi(s.holy_arcana_damage), m, _boost_tip(s.holy_arcana_damage - m, m))

func _boost_tip(base_raw: float, mod_raw: float, scale: float = 1.0, suffix: String = "") -> String:
	return "Base: %d%s\nItems: +%d%s" % [roundi(base_raw * scale), suffix, roundi(mod_raw * scale), suffix]

func _set_val(cell_name: String, text: String, modifier: float = 0.0, tooltip: String = "") -> void:
	var lbl: Label = _stat_values.get(cell_name)
	if lbl:
		lbl.text = text
		if modifier > 0.0:
			lbl.add_theme_color_override("font_color", BOOST_COLOR)
			lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			lbl.tooltip_text = tooltip
		else:
			lbl.remove_theme_color_override("font_color")
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.tooltip_text = ""

func refresh_summary() -> void:
	if _summary_vbox:
		_update_summary()

func _build_stat_points_badge() -> void:
	_stat_points_label = Button.new()
	_stat_points_label.flat = true
	_stat_points_label.add_theme_font_size_override("font_size", 14)
	_stat_points_label.add_theme_color_override("font_color", Color(0.82, 0.65, 0.24))
	_stat_points_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	_stat_points_label.add_theme_constant_override("outline_size", 4)
	_stat_points_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_stat_points_label.pressed.connect(func() -> void:
		UIManager.close_screen(&"inventory")
		UIManager.open_screen(&"level_up"))
	_stat_points_label.hide()
	var level_box := _level_value.get_parent() if _level_value else null
	if level_box:
		level_box.add_child(_stat_points_label)

func _update_stat_points_badge(s: StatsComponent) -> void:
	if not _stat_points_label:
		return
	if s and s.stat_points > 0:
		_stat_points_label.text = "+%d pts [L]" % s.stat_points
		_stat_points_label.show()
	else:
		_stat_points_label.hide()

func _on_stats_changed(entity: Node) -> void:
	if entity == GameManager.player and _summary_vbox:
		_update_summary()

func _on_level_up(_entity: Node, _new_level: int, _pts: int) -> void:
	if _entity == GameManager.player and _summary_vbox:
		_update_summary()
