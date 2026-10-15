class_name ItemDetailPanel
extends Control

const DIVIDER_TEX := preload("res://assets/UI/inventory/info_divider.png")
const COIN_ICON := preload("res://assets/UI/inventory/icon_coin_detail.png")
const WEIGHT_ICON := preload("res://assets/UI/inventory/icon_weight_detail.png")
const FONT_SIZE := 18
const HEADER_SIZE := 20
const MAGIC_COLOR := Color("3d8be3")
const LABEL_COLOR := Color(0.894, 0.729, 0.522, 1.0)
const MUTED_COLOR := Color(0.7, 0.6, 0.5, 0.85)
const VALUE_COLOR := Color(0.96, 0.94, 0.88, 1.0)
const OUTLINE_COLOR := Color(0.05, 0.04, 0.06)

var _item: ItemBase
var _stat_values: Dictionary = {}

@onready var _detail_vbox: VBoxContainer = %DetailVBox
@onready var _summary_vbox: VBoxContainer = %SummaryVBox
@onready var _exp_value: Label = %ExpValue
@onready var _level_value: Label = %LevelValue

var _stat_points_label: Button

func _ready() -> void:
	_collect_values($SummaryVBox/MainGrid)
	_collect_values($SummaryVBox/RecoveryGrid)
	_collect_values($SummaryVBox/ResistGrid)
	_collect_values($SummaryVBox/DamageGrid)
	Events.inventory_item_hovered.connect(_on_item_hovered)
	Events.stats_changed.connect(_on_stats_changed)
	Events.level_up.connect(_on_level_up)
	_build_stat_points_badge()
	_update_summary()

func _collect_values(grid: Control) -> void:
	for cell in grid.get_children():
		var val := cell.get_node_or_null("Text/Value") as Label
		if val:
			_stat_values[cell.name] = val

func _on_item_hovered(item: ItemBase) -> void:
	_item = item
	if item:
		_show_detail(item)
	else:
		_detail_vbox.visible = false
		_summary_vbox.visible = true

func _show_detail(item: ItemBase) -> void:
	_clear_children(_detail_vbox)
	_summary_vbox.visible = false
	_detail_vbox.visible = true

	var name_label := _make_label(item.display_name, HEADER_SIZE)
	name_label.add_theme_color_override("font_color", item.get_rarity_color())
	_detail_vbox.add_child(name_label)

	var type_text := _get_type_text(item)
	if not type_text.is_empty():
		_detail_vbox.add_child(_make_label(type_text, FONT_SIZE, MUTED_COLOR))

	_detail_vbox.add_child(_make_divider())

	if not item.description.is_empty():
		var desc := _make_label(item.description, FONT_SIZE, LABEL_COLOR)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		_detail_vbox.add_child(desc)

	var stat_lines := item.get_stat_lines()
	if not stat_lines.is_empty():
		_detail_vbox.add_child(_make_spacer(8))
		for line in stat_lines:
			_detail_vbox.add_child(_make_label(line, FONT_SIZE, VALUE_COLOR))

	if not item.magic_effect_pool.is_empty():
		_detail_vbox.add_child(_make_spacer(8))
		var pool: Array = Array(item.magic_effect_pool)
		pool.shuffle()
		var count := clampi(item.magic_effect_count, 0, pool.size())
		for i in count:
			_detail_vbox.add_child(_make_label(pool[i], FONT_SIZE, MAGIC_COLOR))

	_detail_vbox.add_child(_make_divider())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	_detail_vbox.add_child(footer)

	if item.value > 0:
		footer.add_child(_make_icon_label(COIN_ICON, str(item.value), LABEL_COLOR))
	if item.weight > 0.0:
		var wt := str(int(item.weight)) if is_equal_approx(item.weight, roundf(item.weight)) else "%.1f" % item.weight
		footer.add_child(_make_icon_label(WEIGHT_ICON, wt, LABEL_COLOR))

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
	if _summary_vbox and _summary_vbox.visible:
		_update_summary()

func _get_type_text(item: ItemBase) -> String:
	if item is Weapon:
		return Weapon.WeaponType.keys()[(item as Weapon).weapon_type].capitalize()
	if item is Armor:
		return Armor.ArmorSlot.keys()[(item as Armor).armor_slot].capitalize() + " Armor"
	if item is Consumable:
		return Consumable.ConsumableType.keys()[(item as Consumable).consumable_type].capitalize()
	var cat_names := ["Weapon", "Armor", "Tool", "Ring", "Amulet", "Consumable", "Material", "Quest Item", "Rune Stone"]
	if item.category >= 0 and item.category < cat_names.size():
		return cat_names[item.category]
	return ""

func _make_label(text: String, font_size: int, color: Color = VALUE_COLOR) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_divider() -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = DIVIDER_TEX
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tex.custom_minimum_size.y = DIVIDER_TEX.get_height() * 2 + 12
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex

func _make_spacer(h: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = h
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _make_icon_label(icon: Texture2D, text: String, color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tex := TextureRect.new()
	tex.texture = icon
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.custom_minimum_size = Vector2(32, 32)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(tex)

	hbox.add_child(_make_label(text, FONT_SIZE, color))
	return hbox

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _build_stat_points_badge() -> void:
	_stat_points_label = Button.new()
	_stat_points_label.flat = true
	_stat_points_label.add_theme_font_size_override("font_size", 14)
	_stat_points_label.add_theme_color_override("font_color", Color(0.82, 0.65, 0.24))
	_stat_points_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
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
	if entity == GameManager.player and _summary_vbox and _summary_vbox.visible:
		_update_summary()

func _on_level_up(_entity: Node, _new_level: int, _pts: int) -> void:
	if _entity == GameManager.player and _summary_vbox and _summary_vbox.visible:
		_update_summary()
