class_name Armor
extends ItemBase

enum ArmorSlot { HEAD, CHEST, LEGS, FEET, SHIELD }

@export var armor_slot: ArmorSlot = ArmorSlot.CHEST
@export var defense: float = 2.0

func _init() -> void:
	category = Category.ARMOR

func apply_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	stats.add_modifier(&"defense", defense, source_id)
