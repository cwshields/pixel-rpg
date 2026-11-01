class_name ItemBase
extends Resource
## Base data for every item in the game. Concrete kinds (Weapon, Armor,
## Tool, Ring, Amulet, Consumable, CraftingMaterial) extend this.
##
## Create actual items as .tres resource files in the editor (see
## resources/items/ for examples) rather than hardcoding stats in
## scripts — that way designers can add/tune items without touching
## GDScript, and items serialize cleanly for save files.

enum Category { WEAPON, ARMOR, TOOL, RING, AMULET, CONSUMABLE, MATERIAL, QUEST, RUNE_STONE, AMMO }
enum Rarity { COMMON, MAGIC, RARE, SET, UNIQUE }
enum ClassAffinity { NONE, WARRIOR, RANGER, SORCERER }

const RARITY_COLORS := {
	Rarity.COMMON: Color("e4ba85"),
	Rarity.MAGIC: Color("3d8be3"),
	Rarity.RARE: Color("f1c71e"),
	Rarity.SET: Color("3cf11e"),
	Rarity.UNIQUE: Color("ec5715"),
}

@export var id: StringName
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(1, 999) var max_stack: int = 1
## Base buy/sell value; shops can apply their own markup/markdown on top.
@export var value: int = 0
@export var category: Category = Category.MATERIAL
@export var rarity: Rarity = Rarity.COMMON
@export var class_affinity: ClassAffinity = ClassAffinity.NONE
@export var weight: float = 0.0

@export_group("Requirements")
@export var required_level: int = 0
@export var required_strength: int = 0
@export var required_dexterity: int = 0

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

## Rolled magical affixes (populated by AffixDatabase.roll_affixes_for()).
## COMMON=0, MAGIC=1-6, RARE/SET/UNIQUE=4-8.
var affixes: Array[AffixInstance] = []
## For SET rarity items: the SetDefinition this item belongs to.
var set_def: SetDefinition

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

## Base value plus bonus from rolled affixes — each affix adds value based on
## its rolled modifier magnitudes and the affix's min_level tier.
func get_total_value() -> int:
	if affixes.is_empty():
		return value
	var bonus := 0.0
	for a: AffixInstance in affixes:
		var affix_template: ItemAffix = AffixDB.get_affix(a.affix_id)
		var tier_mult := 1.0
		if affix_template:
			tier_mult = maxf(1.0, affix_template.min_level * 0.5)
		for stat: StringName in a.rolled_modifiers:
			var val: float = absf(a.rolled_modifiers[stat])
			if AffixInstance._is_percent_stat(stat):
				bonus += val * 100.0 * tier_mult
			else:
				bonus += val * tier_mult
	return value + ceili(bonus)

func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[Rarity.COMMON])

func use(_user: Node) -> bool:
	return false

## Returns the display name with affix prefixes/suffixes baked in, or the
## plain display_name when the item has no affixes.
func get_display_name() -> String:
	if affixes.is_empty():
		return display_name
	var prefix := ""
	var suffix := ""
	for a: AffixInstance in affixes:
		if a.type == ItemAffix.AffixType.PREFIX and prefix.is_empty():
			prefix = a.display_name
		elif a.type == ItemAffix.AffixType.SUFFIX and suffix.is_empty():
			suffix = a.display_name
	var parts: PackedStringArray = []
	if not prefix.is_empty():
		parts.append(prefix)
	parts.append(display_name)
	if not suffix.is_empty():
		parts.append(suffix)
	return " ".join(parts)

## Pushes affix modifiers onto the StatsComponent. Subclasses that override
## apply_modifiers() must call super() to include affix effects.
func apply_modifiers(_stats: StatsComponent, _source_id: StringName) -> void:
	_apply_affix_modifiers(_stats, _source_id)

func _apply_affix_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	for a: AffixInstance in affixes:
		for stat: StringName in a.rolled_modifiers:
			stats.add_modifier(stat, a.rolled_modifiers[stat], source_id)

## Override to report lines for the inventory tooltip's stat block (below
## the description) — e.g. Weapon reports damage/durability/APS. Empty by
## default, which hides the block entirely.
func get_stat_lines() -> Array[String]:
	return []

func get_affix_lines() -> Array[String]:
	var lines: Array[String] = []
	for a: AffixInstance in affixes:
		lines.append_array(a.get_stat_lines())
	return lines


func to_save_dict() -> Dictionary:
	var data: Dictionary = {
		"id": String(id),
		"rarity": rarity,
	}
	if not affixes.is_empty():
		var affix_list: Array[Dictionary] = []
		for a: AffixInstance in affixes:
			affix_list.append(a.to_dict())
		data["affixes"] = affix_list
	if set_def:
		data["set_id"] = String(set_def.id)
	return data


static func from_save_dict(data: Dictionary) -> ItemBase:
	var base: ItemBase = ItemFactory.get_base(StringName(data["id"]))
	if not base:
		return null
	var item: ItemBase = base.duplicate(true)
	item.rarity = data.get("rarity", Rarity.COMMON) as Rarity
	var affix_list: Array = data.get("affixes", [])
	item.affixes = []
	for a_data: Dictionary in affix_list:
		var inst := AffixInstance.from_dict(a_data, AffixDB)
		if inst:
			item.affixes.append(inst)
	var set_id: String = data.get("set_id", "")
	if not set_id.is_empty():
		item.set_def = AffixDB.get_set(StringName(set_id))
	return item
