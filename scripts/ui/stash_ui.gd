class_name StashUI
extends MenuBase
## Storage screen with two InventoryGrids side by side: the stash pages on
## the left and the player's inventory on the right. Shift+Click quick-
## transfers items between the two; page arrows flip through the 10 stash
## pages.

var _stash: Stash = null

@onready var _stash_grid: InventoryGrid = %StashGrid
@onready var _player_grid: InventoryGrid = %PlayerGrid
@onready var _stash_title: Label = %StashTitle
@onready var _page_controls: PageControls = %PageControls
@onready var _close_btn: Button = %CloseBtn

func _ready() -> void:
	super._ready()
	_close_btn.pressed.connect(func() -> void: UIManager.close_screen(screen_name))
	_page_controls.page_changed.connect(_on_page_changed)

func setup_stash(stash: Stash) -> void:
	_stash = stash

func _on_open() -> void:
	UIManager.close_screen(&"inventory")
	UIManager.close_screen(&"shop")
	UIManager.close_screen(&"level_up")
	UIManager.close_screen(&"item_spawner")
	var player: Player = GameManager.player
	if not player or not _stash:
		return
	_stash_title.text = "Stash"
	_player_grid.setup(player.inventory)
	_stash_grid.input_filter = _on_grid_click.bind(_stash_grid)
	_player_grid.input_filter = _on_grid_click.bind(_player_grid)
	_page_controls.set_page_count(_stash.page_count)
	_page_controls.set_page(_stash.get_current_page_index() + 1)
	_stash_grid.setup(_stash.get_current_page())

func _on_close() -> void:
	_stash_grid.cancel_held_item()
	_player_grid.cancel_held_item()
	_stash_grid.input_filter = Callable()
	_player_grid.input_filter = Callable()
	Events.dialogue_ended.emit()

func _on_page_changed(page_1based: int) -> void:
	_stash_grid.cancel_held_item()
	_stash.set_current_page(page_1based - 1)
	_stash_grid.setup(_stash.get_current_page())

func _on_grid_click(event: InputEventMouseButton, clicked_grid: InventoryGrid) -> bool:
	var player: Player = GameManager.player
	if not player or not _stash:
		return false
	var local := clicked_grid.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, clicked_grid.size).has_point(local):
		return false
	if event.shift_pressed:
		var full_stack := event.button_index == MOUSE_BUTTON_LEFT
		if clicked_grid == _stash_grid:
			return _quick_withdraw(local, full_stack)
		return _quick_deposit(local, full_stack)
	var other: InventoryGrid = _player_grid if clicked_grid == _stash_grid else _stash_grid
	if other.has_held_item():
		if clicked_grid == _player_grid:
			return _withdraw_held()
		return _deposit_held()
	return false

func _deposit_held() -> bool:
	var data := _player_grid.take_held_item()
	if data.is_empty():
		return false
	var item: ItemBase = data.item
	var quantity: int = data.quantity
	var leftover := _stash.get_current_page().add_item(item, quantity)
	if leftover > 0:
		player_inv().add_item(item, leftover)
	return true

func _withdraw_held() -> bool:
	var data := _stash_grid.take_held_item()
	if data.is_empty():
		return false
	var item: ItemBase = data.item
	var quantity: int = data.quantity
	var leftover := player_inv().add_item(item, quantity)
	if leftover > 0:
		_stash.get_current_page().add_item(item, leftover)
	return true

func _quick_deposit(local_pos: Vector2, full_stack: bool) -> bool:
	var placed := _find_placed(local_pos, player_inv(), _player_grid)
	if not placed:
		return false
	var count := placed.quantity if full_stack else 1
	var leftover := _stash.get_current_page().add_item(placed.item, count)
	var moved := count - leftover
	if moved <= 0:
		return true
	_player_grid._play_place_sfx(placed.item)
	if placed.quantity > moved:
		placed.quantity -= moved
		player_inv().changed.emit()
	else:
		player_inv().remove_placed(placed)
	return true

func _quick_withdraw(local_pos: Vector2, full_stack: bool) -> bool:
	var stash_inv := _stash.get_current_page()
	var placed := _find_placed(local_pos, stash_inv, _stash_grid)
	if not placed:
		return false
	var count := placed.quantity if full_stack else 1
	var leftover := player_inv().add_item(placed.item, count)
	var moved := count - leftover
	if moved <= 0:
		return true
	_stash_grid._play_place_sfx(placed.item)
	if placed.quantity > moved:
		placed.quantity -= moved
		stash_inv.changed.emit()
	else:
		stash_inv.remove_placed(placed)
	return true

func _find_placed(local_pos: Vector2, inv: Inventory, grid: InventoryGrid) -> Inventory.PlacedItem:
	var cell := Vector2i(
		floori(local_pos.x / InventoryGrid.CELL_SIZE),
		floori(local_pos.y / InventoryGrid.CELL_SIZE))
	for p in inv.items:
		if cell in inv.get_world_cells(p.item, p.pos, p.rotation):
			return p
	return null

func player_inv() -> Inventory:
	return GameManager.player.inventory
