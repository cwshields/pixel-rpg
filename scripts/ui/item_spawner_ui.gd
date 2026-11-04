class_name ItemSpawnerUI
extends MenuBase
## Debug-only window listing every ItemBase .tres under ITEMS_DIR as a grid
## of icon buttons, next to a live view of the player's inventory. Clicking
## an icon picks that item up onto the cursor via InventoryGrid.pick_up_new()
## — the same held-item mechanic the inventory screen itself uses to drag
## items between slots (see inventory_grid.gd) — so placing it into the
## panel on the right works exactly like moving any other item.
##
## Opened only from DebugPanel's "Item Spawner" button, which doesn't exist
## outside debug builds; this self-deletes there too so it never scans
## resources/items/ in a release build.

const ITEMS_DIR := "res://resources/items"
const CELL_SIZE := 40

@onready var _item_grid: GridContainer = %ItemGrid
@onready var _inventory_grid: InventoryGrid = %Grid
@onready var _trash: Button = %Trash
@onready var _search: LineEdit = %Search
@onready var _rarity: OptionButton = %Rarity
@onready var _level: SpinBox = %Level
@onready var _reroll: Button = %Reroll

var _slot_style: StyleBoxTexture

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	super._ready()
	_slot_style = InventoryGrid.make_slot_style()
	_populate_items()
	_setup_rarity_dropdown()
	_search.text_changed.connect(_on_search_changed)
	_reroll.pressed.connect(_on_reroll_pressed)
	_trash.add_theme_stylebox_override("normal", _slot_style)
	_trash.add_theme_stylebox_override("hover", _slot_style)
	_trash.add_theme_stylebox_override("pressed", _slot_style)
	_trash.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_trash.modulate = Color(1.0, 0.55, 0.55)
	_inventory_grid.trash_control = _trash

func _on_open() -> void:
	# Mutually exclusive with the real inventory screen: both embed an
	# InventoryGrid bound to the same Inventory, and InventoryGrid reads
	# input via _input() rather than _gui_input() (see inventory_grid.gd),
	# so two live instances at once would both react to the same click.
	UIManager.close_screen(&"inventory")
	var player: Player = GameManager.player
	if player:
		_inventory_grid.setup(player.inventory)

func _on_close() -> void:
	_inventory_grid.cancel_held_item()

func _populate_items() -> void:
	for child in _item_grid.get_children():
		child.queue_free()
	var items: Array[ItemBase] = []
	for id in ItemFactory.get_all_base_ids():
		var base := ItemFactory.get_base(id)
		if base:
			items.append(base)
	items.sort_custom(func(a: ItemBase, b: ItemBase) -> bool:
		if a.category != b.category:
			return a.category < b.category
		return a.display_name < b.display_name)
	for item in items:
		_item_grid.add_child(_make_item_button(item))

func repopulate() -> void:
	_populate_items()
	if _search:
		_on_search_changed(_search.text)

func _make_item_button(item: ItemBase) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	btn.icon = item.icon
	btn.expand_icon = true
	btn.tooltip_text = item.display_name
	btn.add_theme_stylebox_override("normal", _slot_style)
	btn.add_theme_stylebox_override("hover", _slot_style)
	btn.add_theme_stylebox_override("pressed", _slot_style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.gui_input.connect(_on_item_gui_input.bind(item))
	return btn

func _on_search_changed(query: String) -> void:
	var filter := query.strip_edges().to_lower()
	for btn: Button in _item_grid.get_children():
		btn.visible = filter.is_empty() or btn.tooltip_text.to_lower().contains(filter)

func _on_item_gui_input(event: InputEvent, item: ItemBase) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var generated := _generate_item(item)
	if event.button_index == MOUSE_BUTTON_LEFT:
		_inventory_grid.pick_up_new(generated, generated.max_stack)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_inventory_grid.pick_up_new(generated, 1)


func _setup_rarity_dropdown() -> void:
	_rarity.add_item("Common", ItemBase.Rarity.COMMON)
	_rarity.add_item("Magic", ItemBase.Rarity.MAGIC)
	_rarity.add_item("Rare", ItemBase.Rarity.RARE)
	_rarity.add_item("Set", ItemBase.Rarity.SET)
	_rarity.add_item("Unique", ItemBase.Rarity.UNIQUE)
	_rarity.selected = 1
	for i in _rarity.item_count:
		var r: ItemBase.Rarity = _rarity.get_item_id(i) as ItemBase.Rarity
		_rarity.set_item_metadata(i, ItemBase.RARITY_COLORS.get(r, Color.WHITE))
	_rarity.item_selected.connect(_on_rarity_selected)
	_update_rarity_color()


func _on_rarity_selected(_index: int) -> void:
	_update_rarity_color()


func _update_rarity_color() -> void:
	var color: Color = _rarity.get_item_metadata(_rarity.selected)
	_rarity.add_theme_color_override("font_color", color)


func _generate_item(base: ItemBase) -> ItemBase:
	var rarity_id: int = _rarity.get_item_id(_rarity.selected)
	var level := int(_level.value)
	return ItemFactory.generate(base, level, rarity_id as ItemBase.Rarity)


func _on_reroll_pressed() -> void:
	var held: ItemBase = _inventory_grid.get_held_item()
	if not held:
		return
	var level := int(_level.value)
	var rarity_id: int = _rarity.get_item_id(_rarity.selected)
	held.rarity = rarity_id as ItemBase.Rarity
	held.affixes = AffixDB.roll_affixes_for(held, level)
	_inventory_grid.refresh_held_tooltip()
