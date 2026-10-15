class_name StatsComponent
extends Node
## Base combat/movement stats plus a modifier stack, so equipment (rings,
## amulets, armor, weapons) and temporary buffs (potions) can push stat
## changes without the entity needing to know anything about items.
## Also owns the leveling system: XP accumulation, level-up checks, and
## stat point allocation.

const BASE_XP: float = 100.0
const XP_EXPONENT: float = 1.5
const POINTS_PER_LEVEL: int = 5
const VALID_ATTRIBUTES: Array[StringName] = [
	&"strength", &"constitution", &"dexterity", &"charisma", &"intelligence"]

## --- Primary attributes ---
@export var base_constitution: float = 5.0
@export var base_strength: float = 5.0
@export var base_dexterity: float = 5.0
@export var base_charisma: float = 5.0
@export var base_intelligence: float = 5.0

## --- Combat base stats (still directly settable for enemies/NPCs) ---
@export var base_attack: float = 5.0
@export var base_defense: float = 0.0
@export var base_speed_multiplier: float = 1.0
@export_range(0.0, 1.0) var base_crit_chance: float = 0.05

## {stat_name: {source_id: amount}}. Use add_modifier()/remove_modifier()
## rather than touching this directly so unrelated sources never clobber
## each other.
var _modifiers: Dictionary = {}

## --- Leveling ---
var level: int = 1
var current_xp: int = 0
var stat_points: int = 0
var _allocated: Dictionary = {}

## --- Primary attributes (base + allocated + modifiers) ---
var constitution: float:
	get: return base_constitution + _allocated.get(&"constitution", 0) + _sum_modifiers(&"constitution")
var strength: float:
	get: return base_strength + _allocated.get(&"strength", 0) + _sum_modifiers(&"strength")
var dexterity: float:
	get: return base_dexterity + _allocated.get(&"dexterity", 0) + _sum_modifiers(&"dexterity")
var charisma: float:
	get: return base_charisma + _allocated.get(&"charisma", 0) + _sum_modifiers(&"charisma")
var intelligence: float:
	get: return base_intelligence + _allocated.get(&"intelligence", 0) + _sum_modifiers(&"intelligence")

## --- Secondary / combat stats ---
## Strength drives attack.
var attack: float:
	get: return base_attack + _sum_modifiers(&"attack") + strength * 0.5
## Strength drives defense; dexterity and intelligence slightly reduce it.
var defense: float:
	get: return base_defense + _sum_modifiers(&"defense") + strength * 0.3 - dexterity * 0.05 - intelligence * 0.1
## Dexterity slightly increases speed; strength slightly decreases it.
var speed_multiplier: float:
	get: return base_speed_multiplier + _sum_modifiers(&"speed_multiplier") + dexterity * 0.005 - strength * 0.003
var crit_chance: float:
	get: return base_crit_chance + _sum_modifiers(&"crit_chance") + dexterity * 0.005
var block_chance: float:
	get: return _sum_modifiers(&"block_chance") + dexterity * 0.01
var move_speed: float:
	get: return 15.0 + _sum_modifiers(&"move_speed") + dexterity * 0.2
## Dexterity increases evasion; strength decreases it.
var evasion: float:
	get: return _sum_modifiers(&"evasion") + dexterity * 0.4 - strength * 0.15

## --- Recovery & utility ---
var regeneration: float:
	get: return _sum_modifiers(&"regeneration") + constitution * 0.2
var lifesteal: float:
	get: return _sum_modifiers(&"lifesteal")
## Intelligence drives luck (moved from charisma).
var luck: float:
	get: return _sum_modifiers(&"luck") + intelligence * 0.3

## --- Pool bonuses (consumed by player to scale component max values) ---
var max_health_bonus: float:
	get: return constitution * 2.0
var max_stamina_bonus: float:
	get: return constitution * 1.5
var max_mana_bonus: float:
	get: return intelligence * 2.0
var max_hunger_bonus: float:
	get: return constitution * 1.0

## --- Elemental resists ---
## Strength increases physical resist.
var fire_resist: float:
	get: return _sum_modifiers(&"fire_resist")
var ice_resist: float:
	get: return _sum_modifiers(&"ice_resist")
var physical_resist: float:
	get: return _sum_modifiers(&"physical_resist") + strength * 0.3
var venom_resist: float:
	get: return _sum_modifiers(&"venom_resist")
var lightning_resist: float:
	get: return _sum_modifiers(&"lightning_resist")
var holy_arcana_resist: float:
	get: return _sum_modifiers(&"holy_arcana_resist")

## --- Elemental damage ---
## Intelligence drives all magic damage.
var fire_damage: float:
	get: return _sum_modifiers(&"fire_damage") + intelligence * 0.3
var ice_damage: float:
	get: return _sum_modifiers(&"ice_damage") + intelligence * 0.3
var venom_damage: float:
	get: return _sum_modifiers(&"venom_damage") + intelligence * 0.3
var lightning_damage: float:
	get: return _sum_modifiers(&"lightning_damage") + intelligence * 0.3
var holy_arcana_damage: float:
	get: return _sum_modifiers(&"holy_arcana_damage") + intelligence * 0.3

## --- Modifier helpers ---

func add_modifier(stat: StringName, amount: float, source_id: StringName) -> void:
	if not _modifiers.has(stat):
		_modifiers[stat] = {}
	_modifiers[stat][source_id] = amount
	Events.stats_changed.emit(get_parent())

func remove_modifier(stat: StringName, source_id: StringName) -> void:
	if _modifiers.has(stat):
		_modifiers[stat].erase(source_id)
		Events.stats_changed.emit(get_parent())

func remove_all_from_source(source_id: StringName) -> void:
	for stat: StringName in _modifiers.keys():
		_modifiers[stat].erase(source_id)
	Events.stats_changed.emit(get_parent())

func _sum_modifiers(stat: StringName) -> float:
	if not _modifiers.has(stat):
		return 0.0
	var total: float = 0.0
	for value: float in _modifiers[stat].values():
		total += value
	return total

## --- Combat ---

func compute_incoming_damage(raw_damage: float) -> float:
	return maxf(raw_damage - defense, 1.0)

func compute_outgoing_damage() -> float:
	var dmg: float = attack
	if randf() < crit_chance:
		dmg *= 2.0
	return dmg

## --- Leveling ---

func xp_for_next_level() -> int:
	return floori(BASE_XP * pow(level, XP_EXPONENT))

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	var leveled := false
	while current_xp >= xp_for_next_level():
		current_xp -= xp_for_next_level()
		level += 1
		stat_points += POINTS_PER_LEVEL
		leveled = true
		Events.level_up.emit(get_parent(), level, stat_points)
	Events.xp_changed.emit(get_parent(), current_xp, xp_for_next_level())
	if leveled:
		Events.stats_changed.emit(get_parent())

func allocate_point(attribute: StringName) -> bool:
	if stat_points <= 0 or attribute not in VALID_ATTRIBUTES:
		return false
	stat_points -= 1
	_allocated[attribute] = _allocated.get(attribute, 0) + 1
	Events.stats_changed.emit(get_parent())
	return true

func get_allocated(attribute: StringName) -> int:
	return _allocated.get(attribute, 0)
