class_name CraftingMaterial
extends ItemBase
## Raw materials for crafting/selling: ores, gems, wood, leather,
## feathers, cloth, herbs, bones. Pure data — a crafting system would
## check `material_type`/`rarity` against a recipe's requirements.

enum MaterialType { ORE, GEM, WOOD, LEATHER, FEATHER, CLOTH, HERB, BONE }

@export var material_type: MaterialType = MaterialType.ORE

func _init() -> void:
	category = Category.MATERIAL
	max_stack = 99
