class_name StatsComponent
extends Node
## Base combat/movement stats plus a modifier stack, so equipment (rings,
## amulets, armor, weapons) and temporary buffs (potions) can push stat
## changes without the entity needing to know anything about items.

## --- Primary attributes ---
@export var base_constitution: float = 10.0
@export var base_strength: float = 10.0
@export var base_dexterity: float = 10.0
@export var base_charisma: float = 10.0
@export var base_intelligence: float = 10.0

## --- Combat base stats (still directly settable for enemies/NPCs) ---
@export var base_attack: float = 5.0
@export var base_defense: float = 0.0
@export var base_speed_multiplier: float = 1.0
@export_range(0.0, 1.0) var base_crit_chance: float = 0.05

## {stat_name: {source_id: amount}}. Use add_modifier()/remove_modifier()
## rather than touching this directly so unrelated sources never clobber
## each other.
var _modifiers: Dictionary = {}

## --- Primary attributes (base + modifiers) ---
var constitution: float:
	get: return base_constitution + _sum_modifiers(&"constitution")
var strength: float:
	get: return base_strength + _sum_modifiers(&"strength")
var dexterity: float:
	get: return base_dexterity + _sum_modifiers(&"dexterity")
var charisma: float:
	get: return base_charisma + _sum_modifiers(&"charisma")
var intelligence: float:
	get: return base_intelligence + _sum_modifiers(&"intelligence")

## --- Secondary / combat stats ---
var attack: float:
	get: return base_attack + _sum_modifiers(&"attack") + strength * 0.5
var defense: float:
	get: return base_defense + _sum_modifiers(&"defense") + constitution * 0.3
var speed_multiplier: float:
	get: return base_speed_multiplier + _sum_modifiers(&"speed_multiplier")
var crit_chance: float:
	get: return base_crit_chance + _sum_modifiers(&"crit_chance") + dexterity * 0.005
var block_chance: float:
	get: return _sum_modifiers(&"block_chance") + dexterity * 0.01
var move_speed: float:
	get: return 15.0 + _sum_modifiers(&"move_speed") + dexterity * 0.2
var evasion: float:
	get: return _sum_modifiers(&"evasion") + dexterity * 0.4

## --- Recovery & utility ---
var regeneration: float:
	get: return _sum_modifiers(&"regeneration") + constitution * 0.2
var lifesteal: float:
	get: return _sum_modifiers(&"lifesteal")
var luck: float:
	get: return _sum_modifiers(&"luck") + charisma * 0.3

## --- Elemental resists ---
var fire_resist: float:
	get: return _sum_modifiers(&"fire_resist")
var ice_resist: float:
	get: return _sum_modifiers(&"ice_resist")
var physical_resist: float:
	get: return _sum_modifiers(&"physical_resist")
var venom_resist: float:
	get: return _sum_modifiers(&"venom_resist")
var lightning_resist: float:
	get: return _sum_modifiers(&"lightning_resist")
var holy_arcana_resist: float:
	get: return _sum_modifiers(&"holy_arcana_resist")

## --- Elemental damage ---
var fire_damage: float:
	get: return _sum_modifiers(&"fire_damage") + intelligence * 0.3
var ice_damage: float:
	get: return _sum_modifiers(&"ice_damage")
var venom_damage: float:
	get: return _sum_modifiers(&"venom_damage")
var lightning_damage: float:
	get: return _sum_modifiers(&"lightning_damage")
var holy_arcana_damage: float:
	get: return _sum_modifiers(&"holy_arcana_damage")

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
