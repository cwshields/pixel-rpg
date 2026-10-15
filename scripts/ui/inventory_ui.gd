class_name InventoryUI
extends MenuBase
## Full inventory + equipment screen — three-column layout with an equipment
## panel (left), tetris grid + tabs + hotbar (center), and item-detail /
## character-summary panel (right). Toggled by the "toggle_inventory" action.

var _category_filters: Dictionary

static func _build_category_filters() -> Dictionary:
	return {
		&"all":       Callable(),
		&"weapons":   func(item: ItemBase) -> bool: return item.category == ItemBase.Category.WEAPON,
		&"armor":     func(item: ItemBase) -> bool: return item.category == ItemBase.Category.ARMOR,
		&"potions":   func(item: ItemBase) -> bool: return item is Consumable and (item as Consumable).consumable_type == Consumable.ConsumableType.POTION,
		&"food":      func(item: ItemBase) -> bool: return item is Consumable and (item as Consumable).consumable_type == Consumable.ConsumableType.FOOD,
		&"keys":      func(item: ItemBase) -> bool: return item.category == ItemBase.Category.QUEST,
		&"spells":    func(item: ItemBase) -> bool: return item is Consumable and (item as Consumable).consumable_type == Consumable.ConsumableType.SCROLL,
		&"materials": func(item: ItemBase) -> bool: return item.category == ItemBase.Category.MATERIAL,
	}

@onready var grid: InventoryGrid = %Grid
@onready var equip_panel: EquipmentPanel = %EquipmentPanel
@onready var tab_bar: CategoryTabBar = %TabBar
@onready var hotbar_strip: HotbarStrip = %HotbarStrip
@onready var info_panel: ItemDetailPanel = %InfoPanel
@onready var search_input: LineEdit = %SearchInput
@onready var weight_label: Label = %WeightLabel
@onready var gold_label: Label = %GoldLabel
@onready var close_btn: TextureButton = %CloseBtn
@onready var character_label: Label = %CharacterLabel

var _active_tab: StringName = &"all"
var _search_text: String = ""

func _on_open() -> void:
	UIManager.close_screen(&"shop")
	UIManager.close_screen(&"level_up")
	UIManager.close_screen(&"item_spawner")
	var player: Player = GameManager.player
	if player:
		grid.setup(player.inventory)
		if equip_panel:
			equip_panel.setup(player.equipment, grid)
		if hotbar_strip:
			hotbar_strip.setup(player.inventory, grid)
		if info_panel:
			info_panel.refresh_summary()
		_refresh_header(player)

func _on_close() -> void:
	grid.cancel_held_item()
	Events.inventory_item_hovered.emit(null)
	if tab_bar:
		tab_bar.reset()
	if search_input:
		search_input.text = ""
	_search_text = ""
	set_category(&"all")

func _input(event: InputEvent) -> void:
	if search_input and search_input.has_focus():
		if event.is_action_pressed(&"ui_cancel"):
			search_input.release_focus()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey:
			return
	super._input(event)

func _ready() -> void:
	super._ready()
	_category_filters = _build_category_filters()
	if close_btn:
		close_btn.pressed.connect(func() -> void: UIManager.close_screen(screen_name))
	if tab_bar:
		tab_bar.tab_changed.connect(set_category)
	if search_input:
		search_input.text_changed.connect(_on_search_changed)
	Events.inventory_item_hovered.connect(_on_item_hovered)
	Events.gold_changed.connect(func(amount: int) -> void:
		if gold_label and visible:
			gold_label.text = str(amount))

func _refresh_header(player: Player) -> void:
	if weight_label:
		var current := player.inventory.get_total_weight()
		weight_label.text = "%s / %s" % [_fmt_weight(current), _fmt_weight(player.max_carry_weight)]
	if gold_label:
		gold_label.text = str(player.gold)

func _fmt_weight(w: float) -> String:
	return str(int(w)) if is_equal_approx(w, roundf(w)) else "%.1f" % w

func set_category(category: StringName) -> void:
	_active_tab = category
	_update_filter()

func _on_search_changed(text: String) -> void:
	_search_text = text.strip_edges().to_lower()
	_update_filter()

func _on_item_hovered(item: ItemBase) -> void:
	if character_label:
		character_label.text = "ITEM DETAILS" if item else "CHARACTER"

func _update_filter() -> void:
	var cat_filter: Callable = _category_filters.get(_active_tab, Callable())
	if _search_text.is_empty() and not cat_filter.is_valid():
		grid.item_filter = Callable()
	else:
		var cat := cat_filter
		var search := _search_text
		grid.item_filter = func(item: ItemBase) -> bool:
			if cat.is_valid() and not cat.call(item):
				return false
			if not search.is_empty() and search not in item.display_name.to_lower():
				return false
			return true
	grid.queue_redraw()
