class_name MerchantNPC
extends NPCBase
## A shopkeeper NPC. Populates a ShopInventory from the exported
## shop_items array so the ShopUI can display and trade from it.

const _WELCOME_SFX: AudioStream = preload("res://assets/SoundFX/Voice/sophia-welcome-traveler.mp3")

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

func start_dialogue() -> void:
	_play_welcome_sfx()
	super.start_dialogue()

func _play_welcome_sfx() -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = _WELCOME_SFX
	sfx.bus = &"Voice"
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
