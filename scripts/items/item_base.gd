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

## Grid footprint for the Tetris-style inventory: rows top-to-bottom,
## '#' marks an occupied cell and anything else is empty. Rows don't need
## padding to a common width. Example L shape: ["#.", "#.", "##"].
##
## Leave this at its default single "#" to have the footprint size itself
## automatically from `icon`'s pixel aspect ratio instead (see
## get_shape_cells()) — only set it explicitly for a non-rectangular shape
## (the L above) or one that needs to defy its icon's proportions on
## purpose.
@export var shape: PackedStringArray = ["#"]
## Whether Inventory.rotate_item()/the inventory UI are allowed to rotate
## this item's footprint. Leave off for items that must stay axis-locked
## (rare — mostly for square 1x1s where rotation would be a no-op anyway).
@export var can_rotate: bool = true

## Flavor-only magical affix pool shown in the inventory tooltip; a random
## subset re-rolls every time the tooltip is (re)shown. Not wired to any
## gameplay effect yet — display text only.
@export var magic_effect_pool: PackedStringArray = []
## How many entries from magic_effect_pool the tooltip picks per roll.
@export_range(0, 8) var magic_effect_count: int = 2

## Parses the effective shape (see _effective_shape()) into cell offsets
## relative to its own top-left corner.
func get_shape_cells() -> Array[Vector2i]:
	var effective := _effective_shape()
	var cells: Array[Vector2i] = []
	for y in effective.size():
		var row: String = effective[y]
		for x in row.length():
			if row[x] == "#":
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		cells.append(Vector2i.ZERO)
	return cells

## Below this aspect ratio (long side / short side) `icon` counts as square
## enough that an auto-derived footprint just stays a single cell.
const _AUTO_SHAPE_SQUARE_ASPECT := 1.6
## Longest side an auto-derived footprint can reach, in cells — keeps a
## very elongated icon (a spear, say) from eating the whole grid.
const _AUTO_SHAPE_MAX_CELLS := 4

## `shape` itself, unless it's still untouched at the default single "#",
## in which case a rectangle sized from `icon`'s pixel aspect ratio. This
## is what makes a plain sword/wand/whatever-shaped item look right without
## anyone hand-authoring `shape` to match its icon — a step that kept
## getting missed in practice (the wooden and iron swords both shipped
## squeezed into a single slot before this existed). Non-rectangular
## shapes (an L-piece) or ones that deliberately defy their icon's
## proportions still just set `shape` explicitly, which always wins.
func _effective_shape() -> PackedStringArray:
	if shape.size() != 1 or shape[0] != "#" or not icon:
		return shape
	var icon_size := icon.get_size()
	if icon_size.x <= 0.0 or icon_size.y <= 0.0:
		return shape
	var long_side := maxf(icon_size.x, icon_size.y)
	var short_side := minf(icon_size.x, icon_size.y)
	if long_side / short_side < _AUTO_SHAPE_SQUARE_ASPECT:
		return shape
	var long_cells := clampi(roundi(long_side / short_side), 2, _AUTO_SHAPE_MAX_CELLS)
	if icon_size.x >= icon_size.y:
		return PackedStringArray(["#".repeat(long_cells)])
	var rows := PackedStringArray()
	for i in long_cells:
		rows.append("#")
	return rows

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

## Override to report lines for the inventory tooltip's stat block (below
## the description) — e.g. Weapon reports damage/durability/APS. Empty by
## default, which hides the block entirely.
func get_stat_lines() -> Array[String]:
	return []
