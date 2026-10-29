class_name Shield
extends ItemBase

@export var defense: float = 2.0
@export var block_chance: float = 0.05

func _init() -> void:
	category = Category.ARMOR

func apply_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	stats.add_modifier(&"defense", defense, source_id)
	stats.add_modifier(&"block_chance", block_chance, source_id)
	super.apply_modifiers(stats, source_id)
