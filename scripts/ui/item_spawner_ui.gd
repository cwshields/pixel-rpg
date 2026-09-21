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
const SLOT_TEX := "res://assets/UI/kit/slot_inventory.png"
const SLOT_PATCH_MARGIN := 5
const CELL_SIZE := 20

@onready var _item_grid: GridContainer = %ItemGrid
@onready var _inventory_grid: InventoryGrid = %Grid
@onready var _trash: Button = %Trash

var _slot_style: StyleBoxTexture

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	super._ready()
	_slot_style = _make_slot_style()
	_populate_items()
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
	var items: Array[ItemBase] = []
	_scan_items(ITEMS_DIR, items)
	items.sort_custom(func(a: ItemBase, b: ItemBase) -> bool:
		if a.category != b.category:
			return a.category < b.category
		return a.display_name < b.display_name)
	for item in items:
		_item_grid.add_child(_make_item_button(item))

func _scan_items(path: String, out: Array[ItemBase]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_warning("ItemSpawnerUI: couldn't open %s" % path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full_path := path.path_join(entry)
		if dir.current_is_dir():
			_scan_items(full_path, out)
		elif entry.ends_with(".tres"):
			var res := load(full_path)
			if res is ItemBase:
				out.append(res)
		entry = dir.get_next()
	dir.list_dir_end()

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
	btn.pressed.connect(_on_item_pressed.bind(item))
	return btn

func _on_item_pressed(item: ItemBase) -> void:
	_inventory_grid.pick_up_new(item, 1)

func _make_slot_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if ResourceLoader.exists(SLOT_TEX):
		style.texture = load(SLOT_TEX) as Texture2D
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, SLOT_PATCH_MARGIN)
	return style
