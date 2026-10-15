class_name ShopUI
extends MenuBase
## Buy/sell screen with two InventoryGrids side by side: the NPC's shop
## stock on the left and the player's inventory on the right.
##
## Drag trade: pick up from one grid, place in the other — gold transfers.
## Quick trade: Shift+Click instantly buys/sells without dragging.

var _active_npc: NPCBase = null
var _shop_inventory: ShopInventory = null
var _feedback_tween: Tween

@onready var _shop_grid: InventoryGrid = %ShopGrid
@onready var _player_grid: InventoryGrid = %PlayerGrid
@onready var _shop_title: Label = %ShopTitle
@onready var _player_gold_label: Label = %PlayerGoldLabel
@onready var _shop_gold_label: Label = %ShopGoldLabel
@onready var _charisma_label: Label = %CharismaLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _close_btn: Button = %CloseBtn

func _ready() -> void:
	super._ready()
	_close_btn.pressed.connect(func() -> void: UIManager.close_screen(screen_name))

func setup_shop(npc: NPCBase) -> void:
	_active_npc = npc
	_shop_inventory = npc.shop_inventory

func _on_open() -> void:
	UIManager.close_screen(&"inventory")
	UIManager.close_screen(&"level_up")
	UIManager.close_screen(&"item_spawner")
	var player: Player = GameManager.player
	if not player or not _shop_inventory:
		return
	_shop_title.text = "%s's Wares" % _active_npc.npc_name if _active_npc else "Shop"
	_shop_grid.setup(_shop_inventory.inventory)
	_player_grid.setup(player.inventory)
	_shop_grid.input_filter = _on_grid_click.bind(_shop_grid)
	_player_grid.input_filter = _on_grid_click.bind(_player_grid)
	_refresh_gold()
	_refresh_charisma()

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
		if clicked_grid == _shop_grid:
			return _quick_buy(local, player)
		return _quick_sell(local, player)
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

func _quick_buy(local_pos: Vector2, player: Player) -> bool:
	var cell := Vector2i(floori(local_pos.x / InventoryGrid.CELL_SIZE),
			floori(local_pos.y / InventoryGrid.CELL_SIZE))
	var inv := _shop_inventory.inventory
	var placed: Inventory.PlacedItem = null
	for p in inv.items:
		if cell in inv.get_world_cells(p.item, p.pos, p.rotation):
			placed = p
			break
	if not placed:
		return false
	var price := _shop_inventory.get_buy_price(placed.item)
	if player.gold < price:
		_show_feedback("Not enough gold!")
		return true
	var leftover := player.inventory.add_item(placed.item, 1)
	if leftover > 0:
		_show_feedback("Inventory full!")
		return true
	player.gold -= price
	Events.gold_changed.emit(player.gold)
	if placed.quantity > 1:
		placed.quantity -= 1
		inv.changed.emit()
	else:
		inv.remove_placed(placed)
	_refresh_gold()
	return true

func _quick_sell(local_pos: Vector2, player: Player) -> bool:
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
	var price := _shop_inventory.get_sell_price(placed.item, charisma)
	player.gold += price
	Events.gold_changed.emit(player.gold)
	if placed.quantity > 1:
		placed.quantity -= 1
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
