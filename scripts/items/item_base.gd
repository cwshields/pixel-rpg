class_name ItemBase
extends Resource
## Base data for every item in the game. Concrete kinds (Weapon, Armor,
## Tool, Ring, Amulet, Consumable, CraftingMaterial) extend this.
##
## Create actual items as .tres resource files in the editor (see
## resources/items/ for examples) rather than hardcoding stats in
## scripts — that way designers can add/tune items without touching
## GDScript, and items serialize cleanly for save files.

enum Category { WEAPON, ARMOR, TOOL, RING, AMULET, CONSUMABLE, MATERIAL, QUEST }

@export var id: StringName
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(1, 999) var max_stack: int = 1
## Base buy/sell value; shops can apply their own markup/markdown on top.
@export var value: int = 0
@export var category: Category = Category.MATERIAL

## Override in subclasses that do something when used from the
## inventory (potions, food, scrolls...). Return true if the item was
## consumed and should be removed from the stack.
func use(_user: Node) -> bool:
	return false

## Override in equippable subclasses (Weapon/Armor/Ring/Amulet) to push
## their stat bonuses onto a StatsComponent when equipped. `source_id`
## identifies the equip slot so Equipment can cleanly remove exactly
## these modifiers again on unequip.
func apply_modifiers(_stats: StatsComponent, _source_id: StringName) -> void:
	pass
