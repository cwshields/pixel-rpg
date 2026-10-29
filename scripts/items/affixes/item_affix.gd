class_name ItemAffix
extends RefCounted
## Template for a single magical prefix or suffix that can roll onto items.
## Holds the stat ranges — the concrete rolled values live in AffixInstance.

enum AffixType { PREFIX, SUFFIX }

var id: StringName
var display_name: String
var type: AffixType
## { &"stat_name": Vector2(min_value, max_value) }
var modifiers: Dictionary
## Which item categories this affix can appear on.
var categories: Array[ItemBase.Category]
## Minimum character/item level before this affix enters the pool.
var min_level: int
## Relative drop weight — higher means more common in the roll pool.
var weight: int
var class_affinity: ItemBase.ClassAffinity = ItemBase.ClassAffinity.NONE


static func create(
	p_id: StringName,
	p_name: String,
	p_type: AffixType,
	p_modifiers: Dictionary,
	p_categories: Array[ItemBase.Category],
	p_min_level: int = 1,
	p_weight: int = 100,
	p_affinity: ItemBase.ClassAffinity = ItemBase.ClassAffinity.NONE,
) -> ItemAffix:
	var a := ItemAffix.new()
	a.id = p_id
	a.display_name = p_name
	a.type = p_type
	a.modifiers = p_modifiers
	a.categories = p_categories
	a.min_level = p_min_level
	a.weight = p_weight
	a.class_affinity = p_affinity
	return a
