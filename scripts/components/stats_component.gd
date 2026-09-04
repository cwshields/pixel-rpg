class_name StatsComponent
extends Node
## Base combat/movement stats plus a modifier stack, so equipment (rings,
## amulets, armor, weapons) and temporary buffs (potions) can push stat
## changes without the entity needing to know anything about items.

@export var base_attack: float = 5.0
@export var base_defense: float = 0.0
@export var base_speed_multiplier: float = 1.0
@export_range(0.0, 1.0) var base_crit_chance: float = 0.05

## {stat_name: {source_id: amount}}. Use add_modifier()/remove_modifier()
## rather than touching this directly so unrelated sources never clobber
## each other.
var _modifiers: Dictionary = {}

var attack: float:
	get: return base_attack + _sum_modifiers(&"attack")
var defense: float:
	get: return base_defense + _sum_modifiers(&"defense")
var speed_multiplier: float:
	get: return base_speed_multiplier + _sum_modifiers(&"speed_multiplier")
var crit_chance: float:
	get: return base_crit_chance + _sum_modifiers(&"crit_chance")

## `source_id` should identify what added the modifier (e.g. an equip
## slot or "consumable_<timestamp>") so it — and only it — can be
## removed later via remove_modifier()/remove_all_from_source().
func add_modifier(stat: StringName, amount: float, source_id: StringName) -> void:
	if not _modifiers.has(stat):
		_modifiers[stat] = {}
	_modifiers[stat][source_id] = amount

func remove_modifier(stat: StringName, source_id: StringName) -> void:
	if _modifiers.has(stat):
		_modifiers[stat].erase(source_id)

func remove_all_from_source(source_id: StringName) -> void:
	for stat: StringName in _modifiers.keys():
		_modifiers[stat].erase(source_id)

func _sum_modifiers(stat: StringName) -> float:
	if not _modifiers.has(stat):
		return 0.0
	var total: float = 0.0
	for value: float in _modifiers[stat].values():
		total += value
	return total

func compute_incoming_damage(raw_damage: float) -> float:
	return maxf(raw_damage - defense, 1.0)

func compute_outgoing_damage() -> float:
	var dmg: float = attack
	if randf() < crit_chance:
		dmg *= 2.0
	return dmg
