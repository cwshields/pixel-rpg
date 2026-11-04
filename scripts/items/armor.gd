class_name Armor
extends ItemBase

enum ArmorSlot { HEAD, CHEST, FEET, GAUNTLETS }

@export var armor_slot: ArmorSlot = ArmorSlot.CHEST
@export var defense: float = 2.0
@export var max_durability: int = 80

var durability: int

func _init() -> void:
	category = Category.ARMOR
	durability = max_durability

func consume_durability(amount: int = 1) -> bool:
	if max_durability <= 0:
		return true
	durability = maxi(durability - amount, 0)
	return durability > 0

func _get_durability() -> int:
	return durability

func _get_max_durability() -> int:
	return max_durability

func _set_durability(value: int) -> void:
	durability = clampi(value, 0, max_durability)

func apply_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	stats.add_modifier(&"defense", defense, source_id)
	super.apply_modifiers(stats, source_id)

func get_stat_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("%d Defense" % roundi(defense))
	if max_durability > 0:
		lines.append("%d/%d Durability" % [durability, max_durability])
	return lines
