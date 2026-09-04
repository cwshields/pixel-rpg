class_name Tool
extends ItemBase
## Gathering/utility tools (pickaxe, axe, fishing rod...). These
## typically aren't "equipped" via Equipment — a gathering system would
## instead check the player's inventory for the right tool type/power
## when interacting with a resource node (a tree, an ore vein).

enum ToolType { PICKAXE, AXE, FISHING_ROD, HOE, SHOVEL }

@export var tool_type: ToolType = ToolType.PICKAXE
## How effective this tool is; a gathering system might require the
## node's resistance to be <= this to succeed, or use it to scale yield.
@export var power: int = 1
@export var max_durability: int = 50

var durability: int

func _init() -> void:
	category = Category.TOOL
	durability = max_durability

## Returns false once durability hits 0, so callers know to break/discard it.
func consume_durability(amount: int = 1) -> bool:
	durability = maxi(durability - amount, 0)
	return durability > 0
