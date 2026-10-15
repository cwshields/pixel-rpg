class_name MerchantNPC
extends NPCBase
## A shopkeeper NPC. Populates a ShopInventory from the exported
## shop_items array so the ShopUI can display and trade from it.

@export var shop_items: Array[ItemBase] = []
@export var buy_markup: float = 1.0

func _ready() -> void:
	has_shop = true
	shop_inventory = ShopInventory.new()
	shop_inventory.buy_markup = buy_markup
	for item in shop_items:
		if item:
			shop_inventory.add_item(item)
	super._ready()
