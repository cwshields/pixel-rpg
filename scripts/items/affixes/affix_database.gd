extends Node
## Autoload holding every magical affix definition and the logic to roll
## affixes onto items based on rarity and level.  Add / tweak entries in
## _ready() — no .tres files needed.

const _W := ItemBase.Category.WEAPON
const _A := ItemBase.Category.ARMOR
const _R := ItemBase.Category.RING
const _AM := ItemBase.Category.AMULET
const _T := ItemBase.Category.TOOL
const _RS := ItemBase.Category.RUNE_STONE

const _EQUIPPABLE: Array[ItemBase.Category] = [_W, _A, _R, _AM, _RS]
const _DEFENSIVE: Array[ItemBase.Category] = [_A, _R, _AM, _RS]
const _GEAR: Array[ItemBase.Category] = [_W, _A]
const _ACCESSORIES: Array[ItemBase.Category] = [_R, _AM]
const _WEAPONS: Array[ItemBase.Category] = [_W]
const _ARMOR: Array[ItemBase.Category] = [_A]
const _ALL_SLOTS: Array[ItemBase.Category] = [_W, _A, _R, _AM, _T, _RS]

var _affixes: Dictionary = {}  # StringName -> ItemAffix
var _sets: Dictionary = {}     # StringName -> SetDefinition

const PRE := ItemAffix.AffixType.PREFIX
const SUF := ItemAffix.AffixType.SUFFIX

const _AFF_NONE := ItemBase.ClassAffinity.NONE
const _AFF_WAR := ItemBase.ClassAffinity.WARRIOR
const _AFF_RNG := ItemBase.ClassAffinity.RANGER
const _AFF_SOR := ItemBase.ClassAffinity.SORCERER

const AFFINITY_MATCH_MULT := 2.5
const AFFINITY_MISMATCH_MULT := 0.4


func _ready() -> void:
	_register_weapon_prefixes()
	_register_armor_prefixes()
	_register_universal_prefixes()
	_register_life_mana_suffixes()
	_register_combat_suffixes()
	_register_utility_suffixes()
	_register_elemental_suffixes()
	_register_knockback_affixes()
	_register_weapon_effect_affixes()
	_register_armor_defensive_affixes()
	_register_magic_effect_affixes()
	_register_sets()


# ---------------------------------------------------------------------------
#  Public API
# ---------------------------------------------------------------------------

func get_affix(id: StringName) -> ItemAffix:
	return _affixes.get(id)


func get_all_affixes() -> Array:
	return _affixes.values()


func get_affixes_for_category(category: ItemBase.Category) -> Array[ItemAffix]:
	var result: Array[ItemAffix] = []
	for affix: ItemAffix in _affixes.values():
		if category in affix.categories:
			result.append(affix)
	return result


func get_set(id: StringName) -> SetDefinition:
	return _sets.get(id)


func get_set_for_item(item_id: StringName) -> SetDefinition:
	for s: SetDefinition in _sets.values():
		if item_id in s.member_ids:
			return s
	return null


func count_set_pieces(set_id: StringName, equipped_items: Array) -> int:
	var s: SetDefinition = _sets.get(set_id)
	if not s:
		return 0
	var count := 0
	for item: ItemBase in equipped_items:
		if item and item.id in s.member_ids:
			count += 1
	return count


func roll_affixes_for(item: ItemBase, level: int = 1) -> Array[AffixInstance]:
	var count := _affix_count_for_rarity(item.rarity)
	if count == 0:
		return []

	var pool_pre := _build_pool(item, PRE, level)
	var pool_suf := _build_pool(item, SUF, level)

	var result: Array[AffixInstance] = []
	var used_ids: Dictionary = {}
	var aff := item.class_affinity

	var max_pre := count / 2 + 1
	var max_suf := count / 2 + 1
	var pre_count := 0
	var suf_count := 0

	for i in count:
		var want_pre := pre_count < max_pre and pool_pre.size() > 0
		var want_suf := suf_count < max_suf and pool_suf.size() > 0
		if want_pre and want_suf:
			if randf() < 0.5:
				_pick_one(pool_pre, used_ids, result, aff)
				pre_count += 1
			else:
				_pick_one(pool_suf, used_ids, result, aff)
				suf_count += 1
		elif want_pre:
			_pick_one(pool_pre, used_ids, result, aff)
			pre_count += 1
		elif want_suf:
			_pick_one(pool_suf, used_ids, result, aff)
			suf_count += 1

	if result.is_empty():
		var fallback := pool_pre if pool_pre.size() > 0 else pool_suf
		_pick_one(fallback, used_ids, result, aff)

	return result


func generate_affix_name(base_name: String, affixes: Array[AffixInstance]) -> String:
	var prefix := ""
	var suffix := ""
	for a: AffixInstance in affixes:
		if a.type == ItemAffix.AffixType.PREFIX and prefix.is_empty():
			prefix = a.display_name
		elif a.type == ItemAffix.AffixType.SUFFIX and suffix.is_empty():
			suffix = a.display_name
	var parts: PackedStringArray = []
	if not prefix.is_empty():
		parts.append(prefix)
	parts.append(base_name)
	if not suffix.is_empty():
		parts.append(suffix)
	return " ".join(parts)


# ---------------------------------------------------------------------------
#  Internal helpers
# ---------------------------------------------------------------------------

func _affix_count_for_rarity(rarity: ItemBase.Rarity) -> int:
	match rarity:
		ItemBase.Rarity.COMMON: return 0
		ItemBase.Rarity.MAGIC: return randi_range(1, 6)
		ItemBase.Rarity.RARE: return randi_range(4, 8)
		ItemBase.Rarity.SET: return randi_range(4, 8)
		ItemBase.Rarity.UNIQUE: return randi_range(4, 8)
	return 0


func _build_pool(item: ItemBase, type: ItemAffix.AffixType, level: int) -> Array[ItemAffix]:
	var pool: Array[ItemAffix] = []
	for affix: ItemAffix in _affixes.values():
		if affix.type != type:
			continue
		if level < affix.min_level:
			continue
		if item.category not in affix.categories:
			continue
		pool.append(affix)
	return pool


func _pick_one(pool: Array[ItemAffix], used: Dictionary, out: Array[AffixInstance],
		item_affinity: ItemBase.ClassAffinity = ItemBase.ClassAffinity.NONE) -> void:
	if pool.is_empty():
		return
	var total_weight := 0.0
	for a: ItemAffix in pool:
		if not used.has(a.id):
			total_weight += _effective_weight(a, item_affinity)
	if total_weight <= 0.0:
		return
	var roll := randf() * total_weight
	var running := 0.0
	for a: ItemAffix in pool:
		if used.has(a.id):
			continue
		running += _effective_weight(a, item_affinity)
		if roll <= running:
			var inst := AffixInstance.roll_from(a)
			out.append(inst)
			used[a.id] = true
			return


func _effective_weight(affix: ItemAffix, item_affinity: ItemBase.ClassAffinity) -> float:
	if item_affinity == _AFF_NONE or affix.class_affinity == _AFF_NONE:
		return float(affix.weight)
	if affix.class_affinity == item_affinity:
		return float(affix.weight) * AFFINITY_MATCH_MULT
	return float(affix.weight) * AFFINITY_MISMATCH_MULT


func _reg(
	id: StringName,
	name: String,
	type: ItemAffix.AffixType,
	mods: Dictionary,
	cats: Array[ItemBase.Category],
	lvl: int = 1,
	w: int = 100,
	affinity: ItemBase.ClassAffinity = ItemBase.ClassAffinity.NONE,
) -> void:
	_affixes[id] = ItemAffix.create(id, name, type, mods, cats, lvl, w, affinity)


# ===================================================================
#  AFFIX DEFINITIONS
#  Naming draws from Diablo 2 structure with project-specific flavor.
#  Stats map to StatsComponent modifier names.
# ===================================================================

# ---------------------------------------------------------------------------
#  WEAPON PREFIXES — damage, elemental, crit, speed
# ---------------------------------------------------------------------------

func _register_weapon_prefixes() -> void:
	# --- Physical damage % ---
	_reg(&"pre_honed", "Honed", PRE,
		{&"damage_percent": Vector2(0.05, 0.10)}, _WEAPONS, 1, 120)
	_reg(&"pre_tempered", "Tempered", PRE,
		{&"damage_percent": Vector2(0.11, 0.20)}, _WEAPONS, 5, 100)
	_reg(&"pre_wicked", "Wicked", PRE,
		{&"damage_percent": Vector2(0.21, 0.30)}, _WEAPONS, 10, 80)
	_reg(&"pre_brutal", "Brutal", PRE,
		{&"damage_percent": Vector2(0.31, 0.45)}, _WEAPONS, 18, 60)
	_reg(&"pre_ruthless", "Ruthless", PRE,
		{&"damage_percent": Vector2(0.46, 0.65)}, _WEAPONS, 28, 40)
	_reg(&"pre_merciless", "Merciless", PRE,
		{&"damage_percent": Vector2(0.66, 0.90)}, _WEAPONS, 40, 20)

	# --- Fire damage ---
	_reg(&"pre_smoldering", "Smoldering", PRE,
		{&"fire_damage": Vector2(1, 3)}, _WEAPONS, 1, 100, _AFF_SOR)
	_reg(&"pre_scorching", "Scorching", PRE,
		{&"fire_damage": Vector2(4, 8)}, _WEAPONS, 8, 80, _AFF_SOR)
	_reg(&"pre_blazing", "Blazing", PRE,
		{&"fire_damage": Vector2(9, 15)}, _WEAPONS, 18, 60, _AFF_SOR)
	_reg(&"pre_infernal", "Infernal", PRE,
		{&"fire_damage": Vector2(16, 25)}, _WEAPONS, 30, 35, _AFF_SOR)

	# --- Ice damage ---
	_reg(&"pre_chilled", "Chilled", PRE,
		{&"ice_damage": Vector2(1, 3)}, _WEAPONS, 1, 100, _AFF_SOR)
	_reg(&"pre_frosted", "Frosted", PRE,
		{&"ice_damage": Vector2(4, 8)}, _WEAPONS, 8, 80, _AFF_SOR)
	_reg(&"pre_glacial", "Glacial", PRE,
		{&"ice_damage": Vector2(9, 15)}, _WEAPONS, 18, 60, _AFF_SOR)
	_reg(&"pre_boreal", "Boreal", PRE,
		{&"ice_damage": Vector2(16, 25)}, _WEAPONS, 30, 35, _AFF_SOR)

	# --- Lightning damage ---
	_reg(&"pre_sparking", "Sparking", PRE,
		{&"lightning_damage": Vector2(1, 3)}, _WEAPONS, 1, 100, _AFF_SOR)
	_reg(&"pre_voltaic", "Voltaic", PRE,
		{&"lightning_damage": Vector2(4, 8)}, _WEAPONS, 8, 80, _AFF_SOR)
	_reg(&"pre_thundering", "Thundering", PRE,
		{&"lightning_damage": Vector2(9, 15)}, _WEAPONS, 18, 60, _AFF_SOR)
	_reg(&"pre_tempest", "Tempest", PRE,
		{&"lightning_damage": Vector2(16, 25)}, _WEAPONS, 30, 35, _AFF_SOR)

	# --- Venom damage ---
	_reg(&"pre_septic", "Septic", PRE,
		{&"venom_damage": Vector2(1, 3)}, _WEAPONS, 1, 100, _AFF_SOR)
	_reg(&"pre_toxic", "Toxic", PRE,
		{&"venom_damage": Vector2(4, 8)}, _WEAPONS, 8, 80, _AFF_SOR)
	_reg(&"pre_noxious", "Noxious", PRE,
		{&"venom_damage": Vector2(9, 15)}, _WEAPONS, 18, 60, _AFF_SOR)
	_reg(&"pre_virulent", "Virulent", PRE,
		{&"venom_damage": Vector2(16, 25)}, _WEAPONS, 30, 35, _AFF_SOR)

	# --- Holy / Arcana damage ---
	_reg(&"pre_blessed", "Blessed", PRE,
		{&"holy_arcana_damage": Vector2(1, 3)}, _WEAPONS, 1, 100, _AFF_SOR)
	_reg(&"pre_hallowed", "Hallowed", PRE,
		{&"holy_arcana_damage": Vector2(4, 8)}, _WEAPONS, 8, 80, _AFF_SOR)
	_reg(&"pre_divine", "Divine", PRE,
		{&"holy_arcana_damage": Vector2(9, 15)}, _WEAPONS, 18, 60, _AFF_SOR)
	_reg(&"pre_celestial", "Celestial", PRE,
		{&"holy_arcana_damage": Vector2(16, 25)}, _WEAPONS, 30, 35, _AFF_SOR)

	# --- Critical strike ---
	_reg(&"pre_keen", "Keen", PRE,
		{&"crit_chance": Vector2(0.01, 0.03)}, _WEAPONS, 1, 100, _AFF_RNG)
	_reg(&"pre_precise", "Precise", PRE,
		{&"crit_chance": Vector2(0.04, 0.07)}, _WEAPONS, 12, 70, _AFF_RNG)
	_reg(&"pre_deadly", "Deadly", PRE,
		{&"crit_chance": Vector2(0.08, 0.12)}, _WEAPONS, 25, 40, _AFF_RNG)

	# --- Attack speed ---
	_reg(&"pre_swift", "Swift", PRE,
		{&"attack_speed": Vector2(0.05, 0.10)}, _WEAPONS, 1, 100, _AFF_RNG)
	_reg(&"pre_nimble", "Nimble", PRE,
		{&"attack_speed": Vector2(0.11, 0.18)}, _WEAPONS, 12, 70, _AFF_RNG)
	_reg(&"pre_blinding", "Blinding", PRE,
		{&"attack_speed": Vector2(0.19, 0.28)}, _WEAPONS, 25, 35, _AFF_RNG)


# ---------------------------------------------------------------------------
#  ARMOR PREFIXES — defense, resists
# ---------------------------------------------------------------------------

func _register_armor_prefixes() -> void:
	# --- Flat defense ---
	_reg(&"pre_sturdy", "Sturdy", PRE,
		{&"defense": Vector2(2, 4)}, _ARMOR, 1, 120, _AFF_WAR)
	_reg(&"pre_fortified", "Fortified", PRE,
		{&"defense": Vector2(5, 9)}, _ARMOR, 8, 100, _AFF_WAR)
	_reg(&"pre_stalwart", "Stalwart", PRE,
		{&"defense": Vector2(10, 16)}, _ARMOR, 18, 70, _AFF_WAR)
	_reg(&"pre_impervious", "Impervious", PRE,
		{&"defense": Vector2(17, 26)}, _ARMOR, 32, 35, _AFF_WAR)

	# --- Fire resist ---
	_reg(&"pre_crimson", "Crimson", PRE,
		{&"fire_resist": Vector2(0.01, 0.03)}, _ARMOR, 1, 100, _AFF_SOR)
	_reg(&"pre_garnet", "Garnet", PRE,
		{&"fire_resist": Vector2(0.03, 0.06)}, _ARMOR, 12, 70, _AFF_SOR)
	_reg(&"pre_ruby", "Ruby", PRE,
		{&"fire_resist": Vector2(0.06, 0.12)}, _ARMOR, 25, 40, _AFF_SOR)

	# --- Ice resist ---
	_reg(&"pre_azure", "Azure", PRE,
		{&"ice_resist": Vector2(0.01, 0.03)}, _ARMOR, 1, 100, _AFF_SOR)
	_reg(&"pre_cobalt", "Cobalt", PRE,
		{&"ice_resist": Vector2(0.03, 0.06)}, _ARMOR, 12, 70, _AFF_SOR)
	_reg(&"pre_sapphire", "Sapphire", PRE,
		{&"ice_resist": Vector2(0.06, 0.12)}, _ARMOR, 25, 40, _AFF_SOR)

	# --- Lightning resist ---
	_reg(&"pre_ocher", "Ocher", PRE,
		{&"lightning_resist": Vector2(0.01, 0.03)}, _ARMOR, 1, 100, _AFF_SOR)
	_reg(&"pre_coral", "Coral", PRE,
		{&"lightning_resist": Vector2(0.03, 0.06)}, _ARMOR, 12, 70, _AFF_SOR)
	_reg(&"pre_amber", "Amber", PRE,
		{&"lightning_resist": Vector2(0.06, 0.12)}, _ARMOR, 25, 40, _AFF_SOR)

	# --- Venom resist ---
	_reg(&"pre_beryl", "Beryl", PRE,
		{&"venom_resist": Vector2(0.01, 0.03)}, _ARMOR, 1, 100, _AFF_SOR)
	_reg(&"pre_jade", "Jade", PRE,
		{&"venom_resist": Vector2(0.03, 0.06)}, _ARMOR, 12, 70, _AFF_SOR)
	_reg(&"pre_emerald", "Emerald", PRE,
		{&"venom_resist": Vector2(0.06, 0.12)}, _ARMOR, 25, 40, _AFF_SOR)

	# --- Holy / Arcana resist ---
	_reg(&"pre_opal", "Opal", PRE,
		{&"holy_arcana_resist": Vector2(0.01, 0.03)}, _ARMOR, 1, 100, _AFF_SOR)
	_reg(&"pre_pearl", "Pearl", PRE,
		{&"holy_arcana_resist": Vector2(0.03, 0.06)}, _ARMOR, 12, 70, _AFF_SOR)
	_reg(&"pre_diamond", "Diamond", PRE,
		{&"holy_arcana_resist": Vector2(0.06, 0.12)}, _ARMOR, 25, 40, _AFF_SOR)

	# --- All resists (armor + accessories) ---
	var _armor_acc: Array[ItemBase.Category] = [_A, _R, _AM]
	_reg(&"pre_warding", "Warding", PRE, {
		&"fire_resist": Vector2(0.01, 0.02), &"ice_resist": Vector2(0.01, 0.02),
		&"lightning_resist": Vector2(0.01, 0.02), &"venom_resist": Vector2(0.01, 0.02),
		&"holy_arcana_resist": Vector2(0.01, 0.02),
	}, _armor_acc, 8, 80, _AFF_SOR)
	_reg(&"pre_prismatic", "Prismatic", PRE, {
		&"fire_resist": Vector2(0.02, 0.04), &"ice_resist": Vector2(0.02, 0.04),
		&"lightning_resist": Vector2(0.02, 0.04), &"venom_resist": Vector2(0.02, 0.04),
		&"holy_arcana_resist": Vector2(0.02, 0.04),
	}, _armor_acc, 22, 40, _AFF_SOR)
	_reg(&"pre_chromatic", "Chromatic", PRE, {
		&"fire_resist": Vector2(0.04, 0.06), &"ice_resist": Vector2(0.04, 0.06),
		&"lightning_resist": Vector2(0.04, 0.06), &"venom_resist": Vector2(0.04, 0.06),
		&"holy_arcana_resist": Vector2(0.04, 0.06),
	}, _armor_acc, 38, 15, _AFF_SOR)


# ---------------------------------------------------------------------------
#  UNIVERSAL PREFIXES — primary attributes (any equippable)
# ---------------------------------------------------------------------------

func _register_universal_prefixes() -> void:
	# --- Strength ---
	_reg(&"pre_ironclad", "Ironclad", PRE,
		{&"strength": Vector2(1, 3)}, _EQUIPPABLE, 1, 100, _AFF_WAR)
	_reg(&"pre_titans", "Titan's", PRE,
		{&"strength": Vector2(4, 7)}, _EQUIPPABLE, 12, 60, _AFF_WAR)
	_reg(&"pre_colossus", "Colossus", PRE,
		{&"strength": Vector2(8, 13)}, _EQUIPPABLE, 28, 30, _AFF_WAR)

	# --- Dexterity ---
	_reg(&"pre_agile", "Agile", PRE,
		{&"dexterity": Vector2(1, 3)}, _EQUIPPABLE, 1, 100, _AFF_RNG)
	_reg(&"pre_fleet", "Fleet", PRE,
		{&"dexterity": Vector2(4, 7)}, _EQUIPPABLE, 12, 60, _AFF_RNG)
	_reg(&"pre_phantom", "Phantom", PRE,
		{&"dexterity": Vector2(8, 13)}, _EQUIPPABLE, 28, 30, _AFF_RNG)

	# --- Constitution ---
	_reg(&"pre_hardy", "Hardy", PRE,
		{&"constitution": Vector2(1, 3)}, _EQUIPPABLE, 1, 100)
	_reg(&"pre_vigorous", "Vigorous", PRE,
		{&"constitution": Vector2(4, 7)}, _EQUIPPABLE, 12, 60)
	_reg(&"pre_enduring", "Enduring", PRE,
		{&"constitution": Vector2(8, 13)}, _EQUIPPABLE, 28, 30)

	# --- Intelligence ---
	_reg(&"pre_sages", "Sage's", PRE,
		{&"intelligence": Vector2(1, 3)}, _EQUIPPABLE, 1, 100, _AFF_SOR)
	_reg(&"pre_arcane", "Arcane", PRE,
		{&"intelligence": Vector2(4, 7)}, _EQUIPPABLE, 12, 60, _AFF_SOR)
	_reg(&"pre_mystic", "Mystic", PRE,
		{&"intelligence": Vector2(8, 13)}, _EQUIPPABLE, 28, 30, _AFF_SOR)

	# --- Charisma (armor + accessories only) ---
	_reg(&"pre_charming", "Charming", PRE,
		{&"charisma": Vector2(1, 3)}, _DEFENSIVE, 1, 100)
	_reg(&"pre_eloquent", "Eloquent", PRE,
		{&"charisma": Vector2(4, 7)}, _DEFENSIVE, 12, 60)
	_reg(&"pre_sovereign", "Sovereign", PRE,
		{&"charisma": Vector2(8, 13)}, _DEFENSIVE, 28, 30)


# ---------------------------------------------------------------------------
#  SUFFIXES — life, mana
# ---------------------------------------------------------------------------

func _register_life_mana_suffixes() -> void:
	# --- Life ---
	_reg(&"suf_jackal", "of the Jackal", SUF,
		{&"max_health": Vector2(3, 8)}, _DEFENSIVE, 1, 120)
	_reg(&"suf_fox", "of the Fox", SUF,
		{&"max_health": Vector2(9, 18)}, _DEFENSIVE, 6, 100)
	_reg(&"suf_wolf", "of the Wolf", SUF,
		{&"max_health": Vector2(19, 30)}, _DEFENSIVE, 14, 80)
	_reg(&"suf_tiger", "of the Tiger", SUF,
		{&"max_health": Vector2(31, 48)}, _DEFENSIVE, 24, 55)
	_reg(&"suf_mammoth", "of the Mammoth", SUF,
		{&"max_health": Vector2(49, 72)}, _DEFENSIVE, 36, 30)
	_reg(&"suf_whale", "of the Whale", SUF,
		{&"max_health": Vector2(73, 100)}, _DEFENSIVE, 48, 15)

	# --- Mana ---
	_reg(&"suf_newt", "of the Newt", SUF,
		{&"max_mana": Vector2(3, 8)}, _DEFENSIVE, 1, 110, _AFF_SOR)
	_reg(&"suf_serpent", "of the Serpent", SUF,
		{&"max_mana": Vector2(9, 18)}, _DEFENSIVE, 8, 85, _AFF_SOR)
	_reg(&"suf_drake", "of the Drake", SUF,
		{&"max_mana": Vector2(19, 32)}, _DEFENSIVE, 18, 60, _AFF_SOR)
	_reg(&"suf_dragon", "of the Dragon", SUF,
		{&"max_mana": Vector2(33, 55)}, _DEFENSIVE, 32, 30, _AFF_SOR)

	# --- Stamina ---
	_reg(&"suf_ant", "of the Ant", SUF,
		{&"max_stamina": Vector2(3, 8)}, _DEFENSIVE, 1, 120, _AFF_WAR)
	_reg(&"suf_hare", "of the Hare", SUF,
		{&"max_stamina": Vector2(9, 18)}, _DEFENSIVE, 6, 100, _AFF_WAR)
	_reg(&"suf_stag", "of the Stag", SUF,
		{&"max_stamina": Vector2(19, 30)}, _DEFENSIVE, 14, 80, _AFF_WAR)
	_reg(&"suf_bear", "of the Bear", SUF,
		{&"max_stamina": Vector2(31, 48)}, _DEFENSIVE, 24, 55, _AFF_WAR)
	_reg(&"suf_ox", "of the Ox", SUF,
		{&"max_stamina": Vector2(49, 72)}, _DEFENSIVE, 36, 30, _AFF_WAR)
	_reg(&"suf_titan", "of the Titan", SUF,
		{&"max_stamina": Vector2(73, 100)}, _DEFENSIVE, 48, 15, _AFF_WAR)


# ---------------------------------------------------------------------------
#  SUFFIXES — combat (lifesteal, regen, crit, dodge, block, speed, evasion)
# ---------------------------------------------------------------------------

func _register_combat_suffixes() -> void:
	# --- Lifesteal (weapons, accessories) ---
	var _wpn_acc: Array[ItemBase.Category] = [_W, _R, _AM]
	_reg(&"suf_leeching", "of Leeching", SUF,
		{&"lifesteal": Vector2(0.01, 0.03)}, _wpn_acc, 5, 90)
	_reg(&"suf_lamprey", "of the Lamprey", SUF,
		{&"lifesteal": Vector2(0.04, 0.06)}, _wpn_acc, 16, 55)
	_reg(&"suf_vampire", "of the Vampire", SUF,
		{&"lifesteal": Vector2(0.07, 0.10)}, _wpn_acc, 30, 25)

	# --- Regeneration (armor + accessories only) ---
	_reg(&"suf_mending", "of Mending", SUF,
		{&"regeneration": Vector2(0.5, 1.5)}, _DEFENSIVE, 1, 100)
	_reg(&"suf_restoration", "of Restoration", SUF,
		{&"regeneration": Vector2(1.6, 3.0)}, _DEFENSIVE, 14, 65)
	_reg(&"suf_renewal", "of Renewal", SUF,
		{&"regeneration": Vector2(3.1, 5.0)}, _DEFENSIVE, 28, 30)

	# --- Dodge (armor, accessories) ---
	var _armor_acc: Array[ItemBase.Category] = [_A, _R, _AM]
	_reg(&"suf_evasion", "of Evasion", SUF,
		{&"dodge_chance": Vector2(0.02, 0.04)}, _armor_acc, 5, 90, _AFF_RNG)
	_reg(&"suf_avoidance", "of Avoidance", SUF,
		{&"dodge_chance": Vector2(0.05, 0.08)}, _armor_acc, 18, 55, _AFF_RNG)
	_reg(&"suf_wind", "of the Wind", SUF,
		{&"dodge_chance": Vector2(0.09, 0.14)}, _armor_acc, 32, 25, _AFF_RNG)

	# --- Block (armor only) ---
	_reg(&"suf_blocking", "of Blocking", SUF,
		{&"block_chance": Vector2(0.02, 0.06)}, _ARMOR, 5, 85, _AFF_WAR)
	_reg(&"suf_deflection", "of Deflection", SUF,
		{&"block_chance": Vector2(0.07, 0.12)}, _ARMOR, 20, 45, _AFF_WAR)

	# --- Move speed (armor + accessories only) ---
	_reg(&"suf_pacing", "of Pacing", SUF,
		{&"move_speed": Vector2(0.5, 1.5)}, _DEFENSIVE, 1, 100)
	_reg(&"suf_haste", "of Haste", SUF,
		{&"move_speed": Vector2(1.6, 3.0)}, _DEFENSIVE, 14, 60)
	_reg(&"suf_speed", "of Speed", SUF,
		{&"move_speed": Vector2(3.1, 5.0)}, _DEFENSIVE, 28, 30)

	# --- Evasion (armor, accessories) ---
	_reg(&"suf_shadows", "of Shadows", SUF,
		{&"evasion": Vector2(2, 5)}, _armor_acc, 5, 90, _AFF_RNG)
	_reg(&"suf_mist", "of the Mist", SUF,
		{&"evasion": Vector2(6, 12)}, _armor_acc, 18, 55, _AFF_RNG)
	_reg(&"suf_wraith", "of the Wraith", SUF,
		{&"evasion": Vector2(13, 22)}, _armor_acc, 32, 25, _AFF_RNG)

	# --- Attack (flat bonus, weapons + accessories) ---
	_reg(&"suf_worth", "of Worth", SUF,
		{&"attack": Vector2(1, 3)}, _wpn_acc, 1, 100)
	_reg(&"suf_measure", "of Measure", SUF,
		{&"attack": Vector2(4, 8)}, _wpn_acc, 10, 70)
	_reg(&"suf_slaughter", "of Slaughter", SUF,
		{&"attack": Vector2(9, 16)}, _wpn_acc, 22, 40)


# ---------------------------------------------------------------------------
#  SUFFIXES — utility (luck, charisma, physical resist)
# ---------------------------------------------------------------------------

func _register_utility_suffixes() -> void:
	# --- Luck ---
	_reg(&"suf_fortune", "of Fortune", SUF,
		{&"luck": Vector2(1, 3)}, _EQUIPPABLE, 1, 100)
	_reg(&"suf_prosperity", "of Prosperity", SUF,
		{&"luck": Vector2(4, 8)}, _EQUIPPABLE, 14, 60)
	_reg(&"suf_providence", "of Providence", SUF,
		{&"luck": Vector2(9, 14)}, _EQUIPPABLE, 30, 25)

	# --- Physical resist (armor) ---
	_reg(&"suf_toughness", "of Toughness", SUF,
		{&"physical_resist": Vector2(0.01, 0.03)}, _ARMOR, 5, 90, _AFF_WAR)
	_reg(&"suf_stone", "of Stone", SUF,
		{&"physical_resist": Vector2(0.03, 0.06)}, _ARMOR, 18, 55, _AFF_WAR)
	_reg(&"suf_iron_skin", "of Iron Skin", SUF,
		{&"physical_resist": Vector2(0.06, 0.12)}, _ARMOR, 32, 25, _AFF_WAR)

	# --- Thorns (armor) — attacker-takes-damage as physical_resist stand-in ---
	# Stored as a modifier; combat system can check &"thorns" on the defender.
	_reg(&"suf_thorns", "of Thorns", SUF,
		{&"thorns": Vector2(1, 3)}, _ARMOR, 8, 80, _AFF_WAR)
	_reg(&"suf_barbs", "of Barbs", SUF,
		{&"thorns": Vector2(4, 8)}, _ARMOR, 20, 50, _AFF_WAR)
	_reg(&"suf_razors", "of Razors", SUF,
		{&"thorns": Vector2(9, 15)}, _ARMOR, 34, 25, _AFF_WAR)


# ---------------------------------------------------------------------------
#  SUFFIXES — elemental (resist on accessories, elemental dmg on accessories)
# ---------------------------------------------------------------------------

func _register_elemental_suffixes() -> void:
	# --- Single-element resist on accessories ---
	_reg(&"suf_flame_ward", "of Flame Ward", SUF,
		{&"fire_resist": Vector2(0.02, 0.05)}, _ACCESSORIES, 5, 90, _AFF_SOR)
	_reg(&"suf_frost_ward", "of Frost Ward", SUF,
		{&"ice_resist": Vector2(0.02, 0.05)}, _ACCESSORIES, 5, 90, _AFF_SOR)
	_reg(&"suf_storm_ward", "of Storm Ward", SUF,
		{&"lightning_resist": Vector2(0.02, 0.05)}, _ACCESSORIES, 5, 90, _AFF_SOR)
	_reg(&"suf_venom_ward", "of Venom Ward", SUF,
		{&"venom_resist": Vector2(0.02, 0.05)}, _ACCESSORIES, 5, 90, _AFF_SOR)
	_reg(&"suf_holy_ward", "of Holy Ward", SUF,
		{&"holy_arcana_resist": Vector2(0.02, 0.05)}, _ACCESSORIES, 5, 90, _AFF_SOR)

	# --- Elemental damage on accessories ---
	_reg(&"suf_embers", "of Embers", SUF,
		{&"fire_damage": Vector2(1, 4)}, _ACCESSORIES, 5, 80, _AFF_SOR)
	_reg(&"suf_rime", "of Rime", SUF,
		{&"ice_damage": Vector2(1, 4)}, _ACCESSORIES, 5, 80, _AFF_SOR)
	_reg(&"suf_sparks", "of Sparks", SUF,
		{&"lightning_damage": Vector2(1, 4)}, _ACCESSORIES, 5, 80, _AFF_SOR)
	_reg(&"suf_blight", "of Blight", SUF,
		{&"venom_damage": Vector2(1, 4)}, _ACCESSORIES, 5, 80, _AFF_SOR)
	_reg(&"suf_radiance", "of Radiance", SUF,
		{&"holy_arcana_damage": Vector2(1, 4)}, _ACCESSORIES, 5, 80, _AFF_SOR)


# ---------------------------------------------------------------------------
#  SET DEFINITIONS
#  Each set lists its member item IDs and tiered bonuses that activate when
#  enough pieces are equipped. Add new sets here as items are authored.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
#  KNOCKBACK — weapon prefixes (outgoing) + armor suffixes (resistance)
# ---------------------------------------------------------------------------

func _register_knockback_affixes() -> void:
	# --- Outgoing knockback (weapons only) ---
	_reg(&"pre_pushing", "Pushing", PRE,
		{&"knockback_bonus": Vector2(0.05, 0.12)}, _WEAPONS, 1, 100, _AFF_WAR)
	_reg(&"pre_shoving", "Shoving", PRE,
		{&"knockback_bonus": Vector2(0.13, 0.22)}, _WEAPONS, 14, 65, _AFF_WAR)
	_reg(&"pre_staggering", "Staggering", PRE,
		{&"knockback_bonus": Vector2(0.23, 0.35)}, _WEAPONS, 28, 35, _AFF_WAR)

	# --- Knockback resistance (armor, rings, amulets, runes) ---
	_reg(&"suf_stability", "of Stability", SUF,
		{&"knockback_resist": Vector2(0.05, 0.12)}, _DEFENSIVE, 1, 100, _AFF_WAR)
	_reg(&"suf_anchoring", "of Anchoring", SUF,
		{&"knockback_resist": Vector2(0.13, 0.22)}, _DEFENSIVE, 14, 65, _AFF_WAR)
	_reg(&"suf_fortress", "of the Fortress", SUF,
		{&"knockback_resist": Vector2(0.23, 0.35)}, _DEFENSIVE, 28, 35, _AFF_WAR)


# ---------------------------------------------------------------------------
#  WEAPON EFFECTS — bleed, slow, petrify, charm, drain, reach, charge,
#                   slashing/bludgeoning/piercing type bonuses
# ---------------------------------------------------------------------------

func _register_weapon_effect_affixes() -> void:
	# --- Bleed (DoT on hit) ---
	_reg(&"pre_jagged", "Jagged", PRE,
		{&"bleed_damage": Vector2(1, 3)}, _WEAPONS, 1, 100, _AFF_WAR)
	_reg(&"pre_serrated", "Serrated", PRE,
		{&"bleed_damage": Vector2(4, 8)}, _WEAPONS, 12, 70, _AFF_WAR)
	_reg(&"pre_rending", "Rending", PRE,
		{&"bleed_damage": Vector2(9, 15)}, _WEAPONS, 25, 35, _AFF_WAR)

	# --- Slow (chance to slow on hit) ---
	_reg(&"suf_hindering", "of Hindering", SUF,
		{&"slow_chance": Vector2(0.03, 0.07)}, _WEAPONS, 5, 90)
	_reg(&"suf_crippling", "of Crippling", SUF,
		{&"slow_chance": Vector2(0.08, 0.14)}, _WEAPONS, 18, 55)
	_reg(&"suf_fettering", "of Fettering", SUF,
		{&"slow_chance": Vector2(0.15, 0.22)}, _WEAPONS, 32, 25)

	# --- Petrification (chance to petrify on hit) ---
	_reg(&"pre_calcifying", "Calcifying", PRE,
		{&"petrify_chance": Vector2(0.01, 0.03)}, _WEAPONS, 14, 60, _AFF_SOR)
	_reg(&"pre_gorgons", "Gorgon's", PRE,
		{&"petrify_chance": Vector2(0.04, 0.07)}, _WEAPONS, 28, 30, _AFF_SOR)
	_reg(&"pre_medusas", "Medusa's", PRE,
		{&"petrify_chance": Vector2(0.08, 0.12)}, _WEAPONS, 42, 12, _AFF_SOR)

	# --- Charm (chance to charm on hit) ---
	_reg(&"pre_beguiling", "Beguiling", PRE,
		{&"charm_chance": Vector2(0.01, 0.03)}, _WEAPONS, 10, 65, _AFF_SOR)
	_reg(&"pre_enthralling", "Enthralling", PRE,
		{&"charm_chance": Vector2(0.04, 0.07)}, _WEAPONS, 24, 35, _AFF_SOR)
	_reg(&"pre_mesmerizing", "Mesmerizing", PRE,
		{&"charm_chance": Vector2(0.08, 0.12)}, _WEAPONS, 38, 15, _AFF_SOR)

	# --- Drain (mana/stamina siphon on hit) ---
	_reg(&"suf_siphoning", "of Siphoning", SUF,
		{&"drain_amount": Vector2(1, 3)}, _WEAPONS, 8, 80, _AFF_SOR)
	_reg(&"suf_devouring", "of Devouring", SUF,
		{&"drain_amount": Vector2(4, 8)}, _WEAPONS, 20, 50, _AFF_SOR)
	_reg(&"suf_consuming", "of Consuming", SUF,
		{&"drain_amount": Vector2(9, 14)}, _WEAPONS, 34, 25, _AFF_SOR)

	# --- Reach (weapon range bonus) ---
	_reg(&"pre_lengthy", "Lengthy", PRE,
		{&"reach_bonus": Vector2(0.05, 0.12)}, _WEAPONS, 1, 90, _AFF_RNG)
	_reg(&"pre_elongated", "Elongated", PRE,
		{&"reach_bonus": Vector2(0.13, 0.22)}, _WEAPONS, 14, 55, _AFF_RNG)
	_reg(&"pre_farreaching", "Far-Reaching", PRE,
		{&"reach_bonus": Vector2(0.23, 0.35)}, _WEAPONS, 28, 25, _AFF_RNG)

	# --- Charge (bonus to charge attacks) ---
	_reg(&"suf_momentum", "of Momentum", SUF,
		{&"charge_bonus": Vector2(0.05, 0.12)}, _WEAPONS, 5, 90, _AFF_WAR)
	_reg(&"suf_onslaught", "of Onslaught", SUF,
		{&"charge_bonus": Vector2(0.13, 0.22)}, _WEAPONS, 18, 55, _AFF_WAR)
	_reg(&"suf_rampage", "of Rampage", SUF,
		{&"charge_bonus": Vector2(0.23, 0.35)}, _WEAPONS, 32, 25, _AFF_WAR)

	# --- Slashing damage ---
	_reg(&"pre_cleaving", "Cleaving", PRE,
		{&"slash_damage": Vector2(1, 4)}, _WEAPONS, 1, 90, _AFF_WAR)
	_reg(&"pre_slicing", "Slicing", PRE,
		{&"slash_damage": Vector2(5, 10)}, _WEAPONS, 14, 60, _AFF_WAR)
	_reg(&"pre_severing", "Severing", PRE,
		{&"slash_damage": Vector2(11, 18)}, _WEAPONS, 28, 30, _AFF_WAR)

	# --- Bludgeoning damage ---
	_reg(&"pre_heavy", "Heavy", PRE,
		{&"bludgeon_damage": Vector2(1, 4)}, _WEAPONS, 1, 90, _AFF_WAR)
	_reg(&"pre_crushing", "Crushing", PRE,
		{&"bludgeon_damage": Vector2(5, 10)}, _WEAPONS, 14, 60, _AFF_WAR)
	_reg(&"pre_pulverizing", "Pulverizing", PRE,
		{&"bludgeon_damage": Vector2(11, 18)}, _WEAPONS, 28, 30, _AFF_WAR)

	# --- Piercing damage ---
	_reg(&"pre_pointed", "Pointed", PRE,
		{&"pierce_damage": Vector2(1, 4)}, _WEAPONS, 1, 90, _AFF_RNG)
	_reg(&"pre_barbed", "Barbed", PRE,
		{&"pierce_damage": Vector2(5, 10)}, _WEAPONS, 14, 60, _AFF_RNG)
	_reg(&"pre_impaling", "Impaling", PRE,
		{&"pierce_damage": Vector2(11, 18)}, _WEAPONS, 28, 30, _AFF_RNG)


# ---------------------------------------------------------------------------
#  ARMOR DEFENSIVE — parry, deflect, dampen, cooldown reduction, stealth,
#                    weight reduction, elemental attunement, death defiance
# ---------------------------------------------------------------------------

func _register_armor_defensive_affixes() -> void:
	# --- Parry (chance to parry, negating damage) ---
	_reg(&"suf_parrying", "of Parrying", SUF,
		{&"parry_chance": Vector2(0.02, 0.05)}, _DEFENSIVE, 5, 90, _AFF_WAR)
	_reg(&"suf_riposte", "of Riposte", SUF,
		{&"parry_chance": Vector2(0.06, 0.10)}, _DEFENSIVE, 18, 55, _AFF_WAR)
	_reg(&"suf_duelist", "of the Duelist", SUF,
		{&"parry_chance": Vector2(0.11, 0.16)}, _DEFENSIVE, 32, 25, _AFF_WAR)

	# --- Deflect (chance to deflect projectiles) ---
	_reg(&"suf_warding_shell", "of Deflecting", SUF,
		{&"deflect_chance": Vector2(0.02, 0.05)}, _DEFENSIVE, 5, 90, _AFF_WAR)
	_reg(&"suf_rebounding", "of Rebounding", SUF,
		{&"deflect_chance": Vector2(0.06, 0.10)}, _DEFENSIVE, 18, 55, _AFF_WAR)
	_reg(&"suf_aegis", "of the Aegis", SUF,
		{&"deflect_chance": Vector2(0.11, 0.16)}, _DEFENSIVE, 32, 25, _AFF_WAR)

	# --- Dampen (flat damage reduction %) ---
	_reg(&"pre_cushioned", "Cushioned", PRE,
		{&"dampen": Vector2(0.02, 0.05)}, _ARMOR, 5, 90, _AFF_WAR)
	_reg(&"pre_padded", "Padded", PRE,
		{&"dampen": Vector2(0.06, 0.10)}, _ARMOR, 18, 55, _AFF_WAR)
	_reg(&"pre_dampened", "Dampened", PRE,
		{&"dampen": Vector2(0.11, 0.18)}, _ARMOR, 32, 25, _AFF_WAR)

	# --- Cooldown Reduction ---
	_reg(&"suf_readiness", "of Readiness", SUF,
		{&"cooldown_reduction": Vector2(0.03, 0.07)}, _DEFENSIVE, 8, 85, _AFF_RNG)
	_reg(&"suf_alacrity", "of Alacrity", SUF,
		{&"cooldown_reduction": Vector2(0.08, 0.14)}, _DEFENSIVE, 22, 50, _AFF_RNG)
	_reg(&"suf_swiftness", "of Swiftness", SUF,
		{&"cooldown_reduction": Vector2(0.15, 0.22)}, _DEFENSIVE, 36, 25, _AFF_RNG)

	# --- Stealth ---
	_reg(&"pre_quiet", "Quiet", PRE,
		{&"stealth": Vector2(2, 5)}, _ARMOR, 5, 90, _AFF_RNG)
	_reg(&"pre_hushed", "Hushed", PRE,
		{&"stealth": Vector2(6, 12)}, _ARMOR, 18, 55, _AFF_RNG)
	_reg(&"pre_invisible", "Invisible", PRE,
		{&"stealth": Vector2(13, 22)}, _ARMOR, 32, 25, _AFF_RNG)

	# --- Weight Reduction (reduces armor weight penalties) ---
	_reg(&"pre_lightweight", "Lightweight", PRE,
		{&"weight_reduction": Vector2(0.05, 0.12)}, _ARMOR, 1, 90, _AFF_RNG)
	_reg(&"pre_featherweight", "Featherweight", PRE,
		{&"weight_reduction": Vector2(0.13, 0.22)}, _ARMOR, 14, 55, _AFF_RNG)
	_reg(&"pre_weightless", "Weightless", PRE,
		{&"weight_reduction": Vector2(0.23, 0.35)}, _ARMOR, 28, 25, _AFF_RNG)

	# --- Elemental Attunement (boosts all elemental effect strength) ---
	_reg(&"suf_attunement", "of Attunement", SUF,
		{&"elemental_attunement": Vector2(0.03, 0.07)}, _DEFENSIVE, 10, 80, _AFF_SOR)
	_reg(&"suf_resonance", "of Resonance", SUF,
		{&"elemental_attunement": Vector2(0.08, 0.14)}, _DEFENSIVE, 24, 50, _AFF_SOR)
	_reg(&"suf_convergence", "of Convergence", SUF,
		{&"elemental_attunement": Vector2(0.15, 0.22)}, _DEFENSIVE, 38, 25, _AFF_SOR)

	# --- Death Defiance (chance to survive a lethal hit at 1 HP) ---
	_reg(&"suf_last_stand", "of Last Stand", SUF,
		{&"death_defiance": Vector2(0.03, 0.06)}, _DEFENSIVE, 20, 50, _AFF_WAR)
	_reg(&"suf_undying", "of the Undying", SUF,
		{&"death_defiance": Vector2(0.07, 0.12)}, _DEFENSIVE, 35, 25, _AFF_WAR)
	_reg(&"suf_immortal", "of the Immortal", SUF,
		{&"death_defiance": Vector2(0.13, 0.18)}, _DEFENSIVE, 46, 10, _AFF_WAR)


# ---------------------------------------------------------------------------
#  MAGIC EFFECTS — fear, taunt, berserk, blind (weapon + armor)
# ---------------------------------------------------------------------------

func _register_magic_effect_affixes() -> void:
	var _wpn_armor: Array[ItemBase.Category] = [_W, _A]

	# --- Fear (chance to fear enemies on hit / when hit) ---
	_reg(&"pre_dreadful", "Dreadful", PRE,
		{&"fear_chance": Vector2(0.02, 0.05)}, _WEAPONS, 8, 80, _AFF_SOR)
	_reg(&"pre_terrifying", "Terrifying", PRE,
		{&"fear_chance": Vector2(0.06, 0.10)}, _WEAPONS, 22, 45, _AFF_SOR)
	_reg(&"pre_nightmarish", "Nightmarish", PRE,
		{&"fear_chance": Vector2(0.11, 0.16)}, _WEAPONS, 36, 20, _AFF_SOR)

	# --- Taunt (increased aggro generation) ---
	_reg(&"suf_provoking", "of Provoking", SUF,
		{&"taunt_bonus": Vector2(0.10, 0.25)}, _wpn_armor, 5, 90, _AFF_WAR)
	_reg(&"suf_goading", "of Goading", SUF,
		{&"taunt_bonus": Vector2(0.26, 0.50)}, _wpn_armor, 18, 55, _AFF_WAR)
	_reg(&"suf_enraging", "of Enraging", SUF,
		{&"taunt_bonus": Vector2(0.51, 0.80)}, _wpn_armor, 32, 25, _AFF_WAR)

	# --- Berserk (bonus damage at low health) ---
	_reg(&"pre_frenzied", "Frenzied", PRE,
		{&"berserk_bonus": Vector2(0.05, 0.12)}, _wpn_armor, 10, 80, _AFF_WAR)
	_reg(&"pre_bloodrage", "Bloodrage", PRE,
		{&"berserk_bonus": Vector2(0.13, 0.22)}, _wpn_armor, 24, 45, _AFF_WAR)
	_reg(&"pre_berserkers", "Berserker's", PRE,
		{&"berserk_bonus": Vector2(0.23, 0.35)}, _wpn_armor, 38, 20, _AFF_WAR)

	# --- Blind (chance to blind enemies on hit) ---
	_reg(&"suf_dimming", "of Dimming", SUF,
		{&"blind_chance": Vector2(0.02, 0.05)}, _WEAPONS, 8, 80, _AFF_SOR)
	_reg(&"suf_blinding", "of Blinding", SUF,
		{&"blind_chance": Vector2(0.06, 0.10)}, _WEAPONS, 22, 45, _AFF_SOR)
	_reg(&"suf_oblivion", "of Oblivion", SUF,
		{&"blind_chance": Vector2(0.11, 0.16)}, _WEAPONS, 36, 20, _AFF_SOR)


func _register_sets() -> void:
	# Warrior: heavy plate + iron weapons
	_reg_set(&"set_iron_bulwark", "Iron Bulwark", [
		&"iron_cuirass", &"iron_greaves", &"iron_helm", &"iron_gauntlets",
		&"iron_round_shield",
	], [
		{ "pieces": 2, "modifiers": { &"defense": 6.0, &"physical_resist": 0.05 } },
		{ "pieces": 3, "modifiers": { &"constitution": 4.0, &"block_chance": 0.05 } },
		{ "pieces": 4, "modifiers": { &"thorns": 8.0, &"max_health": 30.0 } },
		{ "pieces": 5, "modifiers": { &"strength": 6.0, &"regeneration": 2.0 } },
	])

	# Sorcerer: arcane robes + mage gear
	_reg_set(&"set_arcane_regalia", "Arcane Regalia", [
		&"arcane_regalia", &"archmage_hat", &"arcane_boots", &"sorcerer_bracers",
		&"void_ring",
	], [
		{ "pieces": 2, "modifiers": { &"intelligence": 5.0, &"max_mana": 20.0 } },
		{ "pieces": 3, "modifiers": { &"lightning_damage": 6.0, &"fire_damage": 6.0 } },
		{ "pieces": 4, "modifiers": { &"crit_chance": 0.08, &"all_resist": 0.10 } },
		{ "pieces": 5, "modifiers": { &"ice_damage": 8.0, &"max_mana": 40.0 } },
	])

	# Ranger: leather armor + ranger gear
	_reg_set(&"set_shadow_stalker", "Shadow Stalker's Garb", [
		&"stalker_harness", &"stalker_boots", &"stalker_bracers", &"ranger_hood",
		&"raven_band",
	], [
		{ "pieces": 2, "modifiers": { &"dexterity": 4.0, &"evasion": 6.0 } },
		{ "pieces": 3, "modifiers": { &"crit_chance": 0.06, &"move_speed": 2.0 } },
		{ "pieces": 4, "modifiers": { &"dodge_chance": 0.10, &"attack": 8.0 } },
		{ "pieces": 5, "modifiers": { &"lifesteal": 0.08, &"venom_damage": 12.0 } },
	])

	# Bone themed: bone weapons + accessories
	_reg_set(&"set_bone_collector", "Bone Collector", [
		&"bone_longsword", &"bone_buckler", &"bone_shield",
		&"bone_ring", &"bone_amulet",
	], [
		{ "pieces": 2, "modifiers": { &"attack": 4.0, &"physical_resist": 0.05 } },
		{ "pieces": 3, "modifiers": { &"lifesteal": 0.05, &"constitution": 3.0 } },
		{ "pieces": 4, "modifiers": { &"venom_damage": 10.0, &"max_health": 25.0 } },
		{ "pieces": 5, "modifiers": { &"thorns": 12.0, &"regeneration": 3.0 } },
	])

	# Cursed weapon set
	_reg_set(&"set_cursed_arms", "Cursed Armaments", [
		&"cursed_longsword", &"cursed_buckler", &"cursed_battle_axe",
	], [
		{ "pieces": 2, "modifiers": { &"attack": 8.0, &"venom_damage": 6.0 } },
		{ "pieces": 3, "modifiers": { &"lifesteal": 0.10, &"crit_chance": 0.10, &"max_health": -20.0 } },
	])

	# Desert gold elite set
	_reg_set(&"set_desert_kings", "Desert King's Regalia", [
		&"desert_gold_spear", &"desert_gold_battle_axe",
		&"desert_gold_bow", &"gold_ring",
	], [
		{ "pieces": 2, "modifiers": { &"holy_arcana_damage": 6.0, &"fire_resist": 0.10 } },
		{ "pieces": 3, "modifiers": { &"strength": 5.0, &"defense": 8.0 } },
		{ "pieces": 4, "modifiers": { &"block_chance": 0.08, &"max_health": 40.0, &"charisma": 5.0 } },
	])

	# Elven grace set
	_reg_set(&"set_elven_grace", "Elven Grace", [
		&"elven_longsword", &"elven_buckler", &"elven_tower_shield",
		&"emerald_loop",
	], [
		{ "pieces": 2, "modifiers": { &"dexterity": 5.0, &"attack_speed": 0.15 } },
		{ "pieces": 3, "modifiers": { &"evasion": 8.0, &"ice_resist": 0.10 } },
		{ "pieces": 4, "modifiers": { &"crit_chance": 0.12, &"move_speed": 3.0, &"max_mana": 20.0 } },
	])

	# Infernal weapons set
	_reg_set(&"set_infernal_forge", "Infernal Forge", [
		&"infernal_longsword", &"infernal_spear", &"infernal_morningstar",
	], [
		{ "pieces": 2, "modifiers": { &"fire_damage": 10.0, &"attack": 5.0 } },
		{ "pieces": 3, "modifiers": { &"fire_resist": 0.12, &"strength": 6.0, &"crit_chance": 0.08 } },
	])


func _reg_set(id: StringName, set_name: String, members: Array[StringName], bonuses: Array[Dictionary]) -> void:
	var s := SetDefinition.new()
	s.id = id
	s.set_name = set_name
	s.member_ids = members
	s.bonuses = bonuses
	_sets[id] = s
