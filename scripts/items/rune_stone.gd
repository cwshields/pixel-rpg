class_name RuneStone
extends ItemBase
## A slotted rune stone that grants passive stat buffs while equipped in
## the RUNE_STONE slot. Rune stones can be found as loot or crafted.

@export var stat_modifiers: Dictionary = {}

func _init() -> void:
	category = Category.RUNE_STONE
	max_stack = 1

func apply_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	for stat: String in stat_modifiers:
		stats.add_modifier(StringName(stat), stat_modifiers[stat], source_id)

func get_stat_lines() -> Array[String]:
	var lines: Array[String] = []
	for stat: String in stat_modifiers:
		var val: float = stat_modifiers[stat]
		var sign := "+" if val >= 0.0 else ""
		lines.append("%s%.1f %s" % [sign, val, stat.capitalize()])
	return lines
