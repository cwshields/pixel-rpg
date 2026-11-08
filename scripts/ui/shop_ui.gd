class_name ShopUI
extends MenuBase
## Buy/sell screen with two InventoryGrids side by side: the NPC's shop
## stock on the left and the player's inventory on the right.
##
## Drag trade: pick up from one grid, place in the other — gold transfers.
## Quick trade: Shift+Click instantly buys/sells without dragging.

const _ACTIVE_COLOR := Color(0.92, 0.9, 0.84, 1)
const _INACTIVE_COLOR := Color(0.75, 0.72, 0.65, 1)

const DURABILITY_ICON := preload("res://assets/UI/inventory/icon_durability.png")
const INVENTORY_ICON := preload("res://assets/UI/inventory/icon_inventory.png")
const _ANVIL_SFX: AudioStream = preload("res://assets/SoundFX/UI/repair-gear.mp3")

const _ROW_BASE_COST := 200
const _ROW_COST_MULT := 1.8

var _active_npc: NPCBase = null
var _shop_inventory: ShopInventory = null
var _feedback_tween: Tween
var _tab_buttons: Array[Button] = []
var _repair_btn: Button
var _repair_tooltip: Control
var _expand_btn: Button
var _expand_tooltip: Control

@onready var _shop_grid: InventoryGrid = %ShopGrid
@onready var _player_grid: InventoryGrid = %PlayerGrid
@onready var _shop_title: Label = %ShopTitle
@onready var _player_gold_label: Label = %PlayerGoldLabel
@onready var _shop_gold_label: Label = %ShopGoldLabel
@onready var _charisma_label: Label = %CharismaLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _close_btn: Button = %CloseBtn
@onready var _weapons_tab: Button = %WeaponsTab
@onready var _armor_tab: Button = %ArmorTab
@onready var _misc_tab: Button = %MiscTab

func _ready() -> void:
	super._ready()
	_close_btn.pressed.connect(func() -> void: UIManager.close_screen(screen_name))
	_tab_buttons = [_weapons_tab, _armor_tab, _misc_tab]
	_weapons_tab.pressed.connect(_switch_shop_category.bind(&"weapons"))
	_armor_tab.pressed.connect(_switch_shop_category.bind(&"armor"))
	_misc_tab.pressed.connect(_switch_shop_category.bind(&"misc"))
	_build_repair_button()
	_build_expand_button()

func setup_shop(npc: NPCBase) -> void:
	_active_npc = npc
	_shop_inventory = npc.shop_inventory

func _on_open() -> void:
	UIManager.close_screen(&"inventory")
	UIManager.close_screen(&"stash")
	UIManager.close_screen(&"level_up")
	UIManager.close_screen(&"item_spawner")
	var player: Player = GameManager.player
	if not player or not _shop_inventory:
		return
	_shop_title.text = "%s's Wares" % _active_npc.npc_name if _active_npc else "Shop"
	_player_grid.setup(player.inventory)
	_shop_grid.input_filter = _on_grid_click.bind(_shop_grid)
	_player_grid.input_filter = _on_grid_click.bind(_player_grid)
	_switch_shop_category(&"weapons")
	_refresh_gold()
	_refresh_charisma()
	_refresh_expand_button()

func _on_close() -> void:
	_shop_grid.cancel_held_item()
	_player_grid.cancel_held_item()
	_shop_grid.input_filter = Callable()
	_player_grid.input_filter = Callable()
	Events.dialogue_ended.emit()

func _on_grid_click(event: InputEventMouseButton, clicked_grid: InventoryGrid) -> bool:
	var player: Player = GameManager.player
	if not player or not _shop_inventory:
		return false
	var local := clicked_grid.get_local_mouse_position()
	var in_rect := Rect2(Vector2.ZERO, clicked_grid.size).has_point(local)
	if not in_rect:
		return false
	if event.shift_pressed:
		var full_stack := event.button_index == MOUSE_BUTTON_LEFT
		if clicked_grid == _shop_grid:
			return _quick_buy(local, player, full_stack)
		return _quick_sell(local, player, full_stack)
	var other: InventoryGrid = _player_grid if clicked_grid == _shop_grid else _shop_grid
	if other.has_held_item():
		if clicked_grid == _player_grid:
			return _buy_held_item(player)
		return _sell_held_item(player)
	return false

func _buy_held_item(player: Player) -> bool:
	var data := _shop_grid.take_held_item()
	if data.is_empty():
		return false
	var item: ItemBase = data.item
	var quantity: int = data.quantity
	var total_price := _shop_inventory.get_buy_price(item) * quantity
	if player.gold < total_price:
		_shop_inventory.inventory.add_item(item, quantity)
		_show_feedback("Not enough gold!")
		_refresh_gold()
		return true
	var leftover := player.inventory.add_item(item, quantity)
	if leftover > 0:
		var bought := quantity - leftover
		player.gold -= _shop_inventory.get_buy_price(item) * bought
		Events.gold_changed.emit(player.gold)
		_shop_inventory.inventory.add_item(item, leftover)
		_show_feedback("Inventory full!" if bought == 0 else "Bought %d (inventory full)" % bought)
	else:
		player.gold -= total_price
		Events.gold_changed.emit(player.gold)
	_refresh_gold()
	return true

func _sell_held_item(player: Player) -> bool:
	var data := _player_grid.take_held_item()
	if data.is_empty():
		return false
	var item: ItemBase = data.item
	var quantity: int = data.quantity
	var charisma := player.stats.charisma if player.stats else 0.0
	var total_price := _shop_inventory.get_sell_price(item, charisma) * quantity
	player.gold += total_price
	Events.gold_changed.emit(player.gold)
	_shop_inventory.inventory.add_item(item, quantity)
	_refresh_gold()
	return true

func _quick_buy(local_pos: Vector2, player: Player, full_stack: bool = false) -> bool:
	var cell := Vector2i(floori(local_pos.x / InventoryGrid.CELL_SIZE),
			floori(local_pos.y / InventoryGrid.CELL_SIZE))
	var inv := _shop_inventory.inventory
	var placed: Inventory.PlacedItem = null
	for p in inv.items:
		if cell in inv.get_world_cells(p.item, p.pos, p.rotation):
			placed = p
			break
	if not placed or not _shop_grid._passes_filter(placed.item):
		return false
	var unit_price := _shop_inventory.get_buy_price(placed.item)
	var desired := placed.quantity if full_stack else 1
	var affordable := mini(desired, floori(player.gold / unit_price)) if unit_price > 0 else desired
	if affordable <= 0:
		_show_feedback("Not enough gold!")
		return true
	var leftover := player.inventory.add_item(placed.item, affordable)
	var bought := affordable - leftover
	if bought <= 0:
		_show_feedback("Inventory full!")
		return true
	_player_grid._play_place_sfx(placed.item)
	player.gold -= unit_price * bought
	Events.gold_changed.emit(player.gold)
	if placed.quantity > bought:
		placed.quantity -= bought
		inv.changed.emit()
	else:
		inv.remove_placed(placed)
	if leftover > 0:
		_show_feedback("Bought %d (inventory full)" % bought)
	_refresh_gold()
	return true

func _quick_sell(local_pos: Vector2, player: Player, full_stack: bool = false) -> bool:
	var cell := Vector2i(floori(local_pos.x / InventoryGrid.CELL_SIZE),
			floori(local_pos.y / InventoryGrid.CELL_SIZE))
	var inv := player.inventory
	var placed: Inventory.PlacedItem = null
	for p in inv.items:
		if cell in inv.get_world_cells(p.item, p.pos, p.rotation):
			placed = p
			break
	if not placed:
		return false
	var charisma := player.stats.charisma if player.stats else 0.0
	var unit_price := _shop_inventory.get_sell_price(placed.item, charisma)
	var count := placed.quantity if full_stack else 1
	_shop_grid._play_place_sfx(placed.item)
	player.gold += unit_price * count
	Events.gold_changed.emit(player.gold)
	if placed.quantity > count:
		placed.quantity -= count
		inv.changed.emit()
	else:
		inv.remove_placed(placed)
	_refresh_gold()
	return true

func _refresh_gold() -> void:
	var player: Player = GameManager.player
	if player:
		_player_gold_label.text = "Gold: %d" % player.gold

func _refresh_charisma() -> void:
	var player: Player = GameManager.player
	if not player or not player.stats or not _shop_inventory:
		_charisma_label.text = ""
		return
	var cha := player.stats.charisma
	var t := clampf(cha / 100.0, 0.0, 1.0)
	var sell_pct := roundi((0.4 + 0.8 * t * t) * 100)
	_charisma_label.text = "Sell: %d%%\nCharisma: %d" % [sell_pct, roundi(cha)]

func _switch_shop_category(category: StringName) -> void:
	_shop_grid.cancel_held_item()
	if _active_npc and _active_npc is MerchantNPC:
		_shop_inventory = (_active_npc as MerchantNPC).get_category_inventory(category)
	_shop_grid.item_filter = Callable()
	_shop_grid.setup(_shop_inventory.inventory)
	var tab_map := {&"weapons": _weapons_tab, &"armor": _armor_tab, &"misc": _misc_tab}
	var active_tab: Button = tab_map.get(category, _weapons_tab)
	for btn in _tab_buttons:
		var active := btn == active_tab
		var s := _make_tab_style(active)
		btn.add_theme_color_override("font_color", _ACTIVE_COLOR if active else _INACTIVE_COLOR)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", s)
		btn.add_theme_stylebox_override("pressed", s)

func _make_tab_style(active: bool) -> StyleBox:
	if active:
		var s := StyleBoxTexture.new()
		s.texture = load("res://assets/UI/rpg_hud/frame_button.png")
		s.texture_margin_left = 7.0
		s.texture_margin_top = 7.0
		s.texture_margin_right = 7.0
		s.texture_margin_bottom = 7.0
		return s
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.16, 0.14, 0.6)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_right = 4
	s.corner_radius_bottom_left = 4
	return s

func _show_feedback(text: String) -> void:
	_feedback_label.text = text
	_feedback_label.visible = true
	_feedback_label.modulate = Color.WHITE
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(1.0)
	_feedback_tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.4)
	_feedback_tween.tween_callback(func() -> void: _feedback_label.visible = false)

# ---------------------------------------------------------------------------
# Repair
# ---------------------------------------------------------------------------

func _build_repair_button() -> void:
	var center_info := %CharismaLabel.get_parent()
	if not center_info:
		return

	_repair_btn = Button.new()
	_repair_btn.custom_minimum_size = Vector2(48, 48)
	_repair_btn.icon = DURABILITY_ICON
	_repair_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_repair_btn.expand_icon = true
	var btn_style := StyleBoxTexture.new()
	btn_style.texture = load("res://assets/UI/rpg_hud/frame_button.png")
	btn_style.texture_margin_left = 7.0
	btn_style.texture_margin_top = 7.0
	btn_style.texture_margin_right = 7.0
	btn_style.texture_margin_bottom = 7.0
	_repair_btn.add_theme_stylebox_override("normal", btn_style)
	_repair_btn.add_theme_stylebox_override("hover", btn_style)
	_repair_btn.add_theme_stylebox_override("pressed", btn_style)
	var focus_style := StyleBoxEmpty.new()
	_repair_btn.add_theme_stylebox_override("focus", focus_style)
	_repair_btn.pressed.connect(_on_repair_pressed)
	_repair_btn.mouse_entered.connect(_on_repair_hover.bind(true))
	_repair_btn.mouse_exited.connect(_on_repair_hover.bind(false))
	center_info.add_child(_repair_btn)

	_repair_tooltip = Control.new()
	_repair_tooltip.top_level = true
	_repair_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_repair_tooltip.visible = false

	var bg := NinePatchRect.new()
	bg.texture = preload("res://assets/UI/inventory/info_bg.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		bg.set_patch_margin(side, 10)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_repair_tooltip.add_child(bg)

	var border := NinePatchRect.new()
	border.texture = preload("res://assets/UI/inventory/info_border.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		border.set_patch_margin(side, 10)
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_repair_tooltip.add_child(border)

	var label := Label.new()
	label.name = "CostLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.894, 0.729, 0.522, 1))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(10, 8)
	_repair_tooltip.add_child(label)

	add_child(_repair_tooltip)

func _get_repair_cost() -> int:
	var player: Player = GameManager.player
	if not player:
		return 0
	var total := 0
	for item: ItemBase in player.equipment.get_all_equipped():
		total += _item_repair_cost(item)
	for placed: Inventory.PlacedItem in player.inventory.items:
		total += _item_repair_cost(placed.item)
	return total

func _item_repair_cost(item: ItemBase) -> int:
	var dur := item._get_durability()
	var max_dur := item._get_max_durability()
	if max_dur <= 0 or dur >= max_dur:
		return 0
	var missing := max_dur - dur
	var base_cost := maxf(1.0, item.value * 0.1)
	return ceili(missing * base_cost / float(max_dur))

func _repair_all_items() -> void:
	var player: Player = GameManager.player
	if not player:
		return
	for item: ItemBase in player.equipment.get_all_equipped():
		_repair_item(item)
	for placed: Inventory.PlacedItem in player.inventory.items:
		_repair_item(placed.item)

func _repair_item(item: ItemBase) -> void:
	var max_dur := item._get_max_durability()
	if max_dur > 0:
		item._set_durability(max_dur)

func _on_repair_pressed() -> void:
	var player: Player = GameManager.player
	if not player:
		return
	var cost := _get_repair_cost()
	if cost <= 0:
		_show_feedback("Nothing to repair!")
		return
	if player.gold < cost:
		_show_feedback("Not enough gold!")
		return
	player.gold -= cost
	Events.gold_changed.emit(player.gold)
	_repair_all_items()
	_refresh_gold()
	_show_feedback("All gear repaired!")
	_repair_tooltip.visible = false
	var sfx := AudioStreamPlayer.new()
	sfx.stream = _ANVIL_SFX
	sfx.bus = &"Master"
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()

func _on_repair_hover(hovering: bool) -> void:
	if not _repair_tooltip:
		return
	if hovering:
		var label: Label = _repair_tooltip.get_node("CostLabel")
		var cost := _get_repair_cost()
		if cost > 0:
			label.text = "Repair All\n%d gold" % cost
		else:
			label.text = "Repair All\nAll intact"
		_position_tooltip_above(_repair_tooltip, _repair_btn)
	else:
		_repair_tooltip.visible = false

# ---------------------------------------------------------------------------
# Expand Inventory
# ---------------------------------------------------------------------------

func _build_expand_button() -> void:
	var center_info := %CharismaLabel.get_parent()
	if not center_info:
		return

	_expand_btn = Button.new()
	_expand_btn.custom_minimum_size = Vector2(48, 48)
	_expand_btn.icon = INVENTORY_ICON
	_expand_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_expand_btn.expand_icon = true
	var btn_style := StyleBoxTexture.new()
	btn_style.texture = load("res://assets/UI/rpg_hud/frame_button.png")
	btn_style.texture_margin_left = 7.0
	btn_style.texture_margin_top = 7.0
	btn_style.texture_margin_right = 7.0
	btn_style.texture_margin_bottom = 7.0
	_expand_btn.add_theme_stylebox_override("normal", btn_style)
	_expand_btn.add_theme_stylebox_override("hover", btn_style)
	_expand_btn.add_theme_stylebox_override("pressed", btn_style)
	var focus_style := StyleBoxEmpty.new()
	_expand_btn.add_theme_stylebox_override("focus", focus_style)
	_expand_btn.pressed.connect(_on_expand_pressed)
	_expand_btn.mouse_entered.connect(_on_expand_hover.bind(true))
	_expand_btn.mouse_exited.connect(_on_expand_hover.bind(false))
	center_info.add_child(_expand_btn)

	_expand_tooltip = Control.new()
	_expand_tooltip.top_level = true
	_expand_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expand_tooltip.visible = false

	var bg := NinePatchRect.new()
	bg.texture = preload("res://assets/UI/inventory/info_bg.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		bg.set_patch_margin(side, 10)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expand_tooltip.add_child(bg)

	var border := NinePatchRect.new()
	border.texture = preload("res://assets/UI/inventory/info_border.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		border.set_patch_margin(side, 10)
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expand_tooltip.add_child(border)

	var label := Label.new()
	label.name = "CostLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.894, 0.729, 0.522, 1))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(10, 8)
	_expand_tooltip.add_child(label)

	add_child(_expand_tooltip)

func _get_expand_cost() -> int:
	var player: Player = GameManager.player
	if not player:
		return 0
	var purchased := player.inventory.unlocked_rows - 5
	return ceili(_ROW_BASE_COST * pow(_ROW_COST_MULT, purchased))

func _refresh_expand_button() -> void:
	if not _expand_btn:
		return
	var player: Player = GameManager.player
	if not player:
		_expand_btn.visible = false
		return
	_expand_btn.visible = player.inventory.unlocked_rows < player.inventory.height

func _on_expand_pressed() -> void:
	var player: Player = GameManager.player
	if not player:
		return
	var inv := player.inventory
	if inv.unlocked_rows >= inv.height:
		_show_feedback("Inventory fully expanded!")
		return
	var cost := _get_expand_cost()
	if player.gold < cost:
		_show_feedback("Not enough gold!")
		return
	player.gold -= cost
	Events.gold_changed.emit(player.gold)
	inv.unlock_rows(inv.unlocked_rows + 1)
	inv.changed.emit()
	_player_grid.queue_redraw()
	_refresh_gold()
	_refresh_expand_button()
	_expand_tooltip.visible = false
	_show_feedback("+1 inventory row!")

func _on_expand_hover(hovering: bool) -> void:
	if not _expand_tooltip:
		return
	if hovering:
		var label: Label = _expand_tooltip.get_node("CostLabel")
		var player: Player = GameManager.player
		if player and player.inventory.unlocked_rows < player.inventory.height:
			label.text = "Expand Row\n%d gold" % _get_expand_cost()
		else:
			label.text = "Expand Row\nFully expanded"
		_position_tooltip_above(_expand_tooltip, _expand_btn)
	else:
		_expand_tooltip.visible = false

# ---------------------------------------------------------------------------
# Shared tooltip positioning
# ---------------------------------------------------------------------------

func _position_tooltip_above(tooltip: Control, btn: Button) -> void:
	var label: Label = tooltip.get_node("CostLabel")
	var text_size := label.get_combined_minimum_size()
	var padding := Vector2(20, 16)
	tooltip.size = text_size + padding
	var btn_rect := btn.get_global_rect()
	var tip_x := btn_rect.position.x + btn_rect.size.x / 2.0 - tooltip.size.x / 2.0
	var tip_y := btn_rect.position.y - tooltip.size.y - 6
	var vp := get_viewport_rect().size
	tip_x = clampf(tip_x, 2, vp.x - tooltip.size.x - 2)
	if tip_y < 2:
		tip_y = btn_rect.position.y + btn_rect.size.y + 6
	tooltip.position = Vector2(tip_x, tip_y)
	tooltip.visible = true
