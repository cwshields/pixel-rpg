class_name ShopInventory
extends RefCounted
## Merchant stock with pricing logic backed by a real Inventory so items
## can be displayed and dragged via InventoryGrid.

signal changed

var inventory: Inventory
var buy_markup: float = 1.0

func _init(p_width: int = 8, p_height: int = 9) -> void:
	inventory = Inventory.new(p_width, p_height)
	inventory.changed.connect(func() -> void: changed.emit())

func add_item(item: ItemBase, quantity: int = 1) -> void:
	inventory.add_item(item, quantity)

func get_buy_price(item: ItemBase) -> int:
	return ceili(item.value * buy_markup)

## Sell price scales from 40% (0 charisma) to 120% (100 charisma) on a
## quadratic curve — low charisma gains little, high charisma gains a lot.
func get_sell_price(item: ItemBase, charisma: float = 0.0) -> int:
	var t := clampf(charisma / 100.0, 0.0, 1.0)
	var sell_pct := 0.4 + 0.8 * t * t
	return maxi(1, floori(item.value * sell_pct))
