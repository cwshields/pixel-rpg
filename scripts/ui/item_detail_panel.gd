class_name ItemDetailPanel
extends Control

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

	_set_val("ConstitutionCell", "%d" % roundi(s.constitution))
	_set_val("DamageCell", "%d" % roundi(s.attack))
	_set_val("StrengthCell", "%d" % roundi(s.strength))
	_set_val("DefenceCell", "%d" % roundi(s.defense))
	_set_val("DexterityCell", "%d" % roundi(s.dexterity))
	_set_val("BlockChanceCell", "%d%%" % roundi(s.block_chance * 100))
	_set_val("CharismaCell", "%d" % roundi(s.charisma))
	_set_val("AtkSpeedCell", "%.2f" % s.speed_multiplier)
	_set_val("IntelligenceCell", "%d" % roundi(s.intelligence))
	_set_val("MoveSpeedCell", "%d" % roundi(s.move_speed))

	_set_val("RegenerationCell", "%d" % roundi(s.regeneration))
	_set_val("LifestealCell", "%d" % roundi(s.lifesteal))
	_set_val("LuckCell", "%d%%" % roundi(s.luck))

	_set_val("FireResistCell", "%d" % roundi(s.fire_resist))
	_set_val("IceResistCell", "%d" % roundi(s.ice_resist))
	_set_val("PhysResistCell", "%d" % roundi(s.physical_resist))
	_set_val("VenomResistCell", "%d" % roundi(s.venom_resist))
	_set_val("LightningResistCell", "%d" % roundi(s.lightning_resist))
	_set_val("HolyArcanaResistCell", "%d" % roundi(s.holy_arcana_resist))

	_set_val("FireDamageCell", "%d" % roundi(s.fire_damage))
	_set_val("IceDamageCell", "%d" % roundi(s.ice_damage))
	_set_val("EvasionCell", "%d" % roundi(s.evasion))
	_set_val("VenomDamageCell", "%d" % roundi(s.venom_damage))
	_set_val("LightningDamageCell", "%d" % roundi(s.lightning_damage))
	_set_val("HolyArcanaDamageCell", "%d" % roundi(s.holy_arcana_damage))

func _set_val(cell_name: String, text: String) -> void:
	var lbl: Label = _stat_values.get(cell_name)
	if lbl:
		lbl.text = text

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
