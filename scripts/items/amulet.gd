class_name Amulet
extends ItemBase
## Passive stat-boosting accessory, one slot. `passive_effect` is a hook
## for triggered effects (life-on-hit, thorns, regen...) that go beyond
## a flat stat modifier — wire it up in whatever combat/effects system
## you build once you know what effects you need.

@export var stat_modifiers: Dictionary = {}
@export var passive_effect: StringName = &""

func _init() -> void:
	category = Category.AMULET

func apply_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	for stat: String in stat_modifiers:
		stats.add_modifier(StringName(stat), stat_modifiers[stat], source_id)
