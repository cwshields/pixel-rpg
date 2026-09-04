class_name Ring
extends ItemBase
## Passive stat-boosting accessory. Equipment reserves two ring slots
## (RING_1/RING_2) so two can be worn at once.

## Flat modifiers to apply on equip, e.g. {"attack": 2.0, "speed_multiplier": 0.1}.
## Keys must match a StatsComponent stat name.
@export var stat_modifiers: Dictionary = {}

func _init() -> void:
	category = Category.RING

func apply_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	for stat: String in stat_modifiers:
		stats.add_modifier(StringName(stat), stat_modifiers[stat], source_id)
