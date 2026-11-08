class_name ImbuingLogic
extends RefCounted
## Pure-logic class for all imbuing station operations.
## No UI dependency — the UI calls these and reacts to results.

const MAX_IMBUED_AFFIXES := 4

const ESSENCE_DUST_ID := &"arcane_dust"
const ESSENCE_SHARD_ID := &"arcane_shard"
const ESSENCE_CRYSTAL_ID := &"arcane_crystal"

const DUST_VALUE := 1
const SHARD_VALUE := 10
const CRYSTAL_VALUE := 50

static func _is_imbue_category(cat: int) -> bool:
	return cat in [
		ItemBase.Category.WEAPON,
		ItemBase.Category.ARMOR,
		ItemBase.Category.RING,
		ItemBase.Category.AMULET,
		ItemBase.Category.TOOL,
	]


# -- Result types --------------------------------------------------------

class DestructResult:
	var success: bool = false
	var learned_affixes: Array[StringName] = []
	var proficiency_gains: Dictionary = {}
	var essence_yields: Dictionary = {}
	var error: String = ""

class ImbueResult:
	var success: bool = false
	var new_affix: AffixInstance = null
	var essence_cost: int = 0
	var error: String = ""

class UpgradeResult:
	var success: bool = false
	var old_values: Dictionary = {}
	var new_values: Dictionary = {}
	var essence_cost: int = 0
	var error: String = ""

class RemoveResult:
	var success: bool = false
	var removed_affix: AffixInstance = null
	var essence_returned: int = 0
	var error: String = ""


# -- Eligibility ---------------------------------------------------------

static func can_imbue_item(item: ItemBase) -> bool:
	if not item:
		return false
	if not _is_imbue_category(item.category):
		return false
	if item.rarity == ItemBase.Rarity.SET or item.rarity == ItemBase.Rarity.UNIQUE:
		return false
	return true


static func get_affix_count(item: ItemBase) -> int:
	return item.affixes.size() if item else 0


static func has_room_for_affix(item: ItemBase) -> bool:
	return get_affix_count(item) < MAX_IMBUED_AFFIXES


static func has_affix(item: ItemBase, affix_id: StringName) -> bool:
	for inst: AffixInstance in item.affixes:
		if inst.affix_id == affix_id:
			return true
	return false


# -- Cost calculation ----------------------------------------------------

static func get_imbue_cost(affix_id: StringName) -> int:
	var affix: ItemAffix = AffixDB.get_affix(affix_id)
	if not affix:
		return 0
	var tier_mult := maxf(1.0, float(affix.min_level) / 5.0)
	var rarity_mult := 100.0 / maxf(10.0, float(affix.weight))
	return ceili(5.0 * tier_mult * rarity_mult)


static func get_upgrade_cost(affix_id: StringName) -> int:
	return ceili(get_imbue_cost(affix_id) * 1.5)


static func get_remove_return(affix_id: StringName) -> int:
	return ceili(get_imbue_cost(affix_id) * 0.25)


static func get_catalyst_bonus(catalyst: ItemBase) -> Dictionary:
	var bonus := {"range_mult": 1.0, "cost_mult": 1.0}
	if catalyst is CraftingMaterial:
		match (catalyst as CraftingMaterial).material_type:
			CraftingMaterial.MaterialType.GEM:
				bonus["range_mult"] = 1.1
			CraftingMaterial.MaterialType.HERB:
				bonus["cost_mult"] = 0.8
	return bonus


static func calculate_essence_total(inventory, essence_slot_item: ItemBase,
		essence_slot_qty: int) -> int:
	var total: int = 0
	if essence_slot_item and essence_slot_item is CraftingMaterial:
		var mat := essence_slot_item as CraftingMaterial
		if mat.material_type == CraftingMaterial.MaterialType.ESSENCE:
			total += _essence_value(mat.id) * essence_slot_qty
	return total


static func _essence_value(item_id: StringName) -> int:
	match item_id:
		ESSENCE_DUST_ID: return DUST_VALUE
		ESSENCE_SHARD_ID: return SHARD_VALUE
		ESSENCE_CRYSTAL_ID: return CRYSTAL_VALUE
	return 0


# -- Destruct flow -------------------------------------------------------

static func calculate_destruct_yields(item: ItemBase) -> Dictionary:
	var yields: Dictionary = {}
	if not item:
		return yields
	var affix_count: int = item.affixes.size()
	match item.rarity:
		ItemBase.Rarity.COMMON:
			yields[ESSENCE_DUST_ID] = randi_range(1, 3)
		ItemBase.Rarity.MAGIC:
			yields[ESSENCE_DUST_ID] = randi_range(3, 8)
			if affix_count >= 2:
				yields[ESSENCE_SHARD_ID] = randi_range(1, 2)
		ItemBase.Rarity.RARE:
			yields[ESSENCE_DUST_ID] = randi_range(5, 12)
			yields[ESSENCE_SHARD_ID] = randi_range(3, 6)
			yields[ESSENCE_CRYSTAL_ID] = randi_range(1, 2)
		ItemBase.Rarity.SET:
			yields[ESSENCE_DUST_ID] = randi_range(5, 12)
			yields[ESSENCE_SHARD_ID] = randi_range(3, 6)
			yields[ESSENCE_CRYSTAL_ID] = randi_range(1, 2)
		ItemBase.Rarity.UNIQUE:
			yields[ESSENCE_DUST_ID] = randi_range(8, 16)
			yields[ESSENCE_SHARD_ID] = randi_range(5, 10)
			yields[ESSENCE_CRYSTAL_ID] = randi_range(2, 4)
	return yields


static func destruct(item: ItemBase, knowledge: AffixKnowledge,
		inventory) -> DestructResult:
	var result := DestructResult.new()
	if not item:
		result.error = "No item to destruct."
		return result

	for inst: AffixInstance in item.affixes:
		var new_prof: int = knowledge.learn_affix(inst.affix_id)
		result.learned_affixes.append(inst.affix_id)
		result.proficiency_gains[inst.affix_id] = new_prof

	result.essence_yields = calculate_destruct_yields(item)

	for essence_id: StringName in result.essence_yields:
		var qty: int = result.essence_yields[essence_id]
		var essence_item: ItemBase = ItemFactory.get_base(essence_id)
		if essence_item:
			inventory.add_item(essence_item.duplicate(), qty)

	result.success = true
	return result


# -- Imbue flow ----------------------------------------------------------

static func imbue_affix(target: ItemBase, affix_id: StringName,
		knowledge: AffixKnowledge,
		catalyst: ItemBase = null) -> ImbueResult:
	var result := ImbueResult.new()

	if not can_imbue_item(target):
		result.error = "This item cannot be imbued."
		return result
	if not has_room_for_affix(target):
		result.error = "Item has the maximum number of affixes (%d)." % MAX_IMBUED_AFFIXES
		return result
	if not knowledge.has_learned(affix_id):
		result.error = "You haven't learned this affix yet."
		return result
	if has_affix(target, affix_id):
		result.error = "Item already has this affix."
		return result

	var affix_template: ItemAffix = AffixDB.get_affix(affix_id)
	if not affix_template:
		result.error = "Unknown affix."
		return result
	if target.category not in affix_template.categories:
		result.error = "This affix cannot be applied to this item type."
		return result

	var bonus := get_catalyst_bonus(catalyst)
	result.essence_cost = ceili(get_imbue_cost(affix_id) * bonus["cost_mult"])

	var prof_factor: float = knowledge.get_proficiency_range_factor(affix_id)
	prof_factor = minf(prof_factor * bonus["range_mult"], 1.0)
	result.new_affix = _roll_with_proficiency(affix_template, prof_factor)

	target.affixes.append(result.new_affix)
	if target.rarity == ItemBase.Rarity.COMMON:
		target.rarity = ItemBase.Rarity.MAGIC

	result.success = true
	return result


static func _roll_with_proficiency(affix: ItemAffix, prof_factor: float) -> AffixInstance:
	var inst := AffixInstance.new()
	inst.affix_id = affix.id
	inst.display_name = affix.display_name
	inst.type = affix.type
	inst.rolled_modifiers = {}
	for stat: StringName in affix.modifiers:
		var range: Vector2 = affix.modifiers[stat]
		var constrained_max: float = range.x + (range.y - range.x) * prof_factor
		var step := 0.01 if AffixInstance._is_percent_stat(stat) else 0.1
		inst.rolled_modifiers[stat] = snappedf(
			randf_range(range.x, constrained_max), step)
	return inst


# -- Upgrade flow --------------------------------------------------------

static func upgrade_affix(target: ItemBase, affix_index: int,
		knowledge: AffixKnowledge,
		catalyst: ItemBase = null) -> UpgradeResult:
	var result := UpgradeResult.new()

	if affix_index < 0 or affix_index >= target.affixes.size():
		result.error = "Invalid affix index."
		return result

	var inst: AffixInstance = target.affixes[affix_index]
	var affix_template: ItemAffix = AffixDB.get_affix(inst.affix_id)
	if not affix_template:
		result.error = "Unknown affix template."
		return result

	var bonus := get_catalyst_bonus(catalyst)
	result.essence_cost = ceili(get_upgrade_cost(inst.affix_id) * bonus["cost_mult"])

	var prof_factor: float = knowledge.get_proficiency_range_factor(inst.affix_id)
	prof_factor = minf(prof_factor * bonus["range_mult"], 1.0)

	result.old_values = inst.rolled_modifiers.duplicate()

	for stat: StringName in inst.rolled_modifiers:
		var range: Vector2 = affix_template.modifiers.get(stat, Vector2.ZERO)
		var current: float = inst.rolled_modifiers[stat]
		var constrained_max: float = range.x + (range.y - range.x) * prof_factor
		constrained_max = maxf(constrained_max, current)
		var step := 0.01 if AffixInstance._is_percent_stat(stat) else 0.1
		inst.rolled_modifiers[stat] = snappedf(
			maxf(current, randf_range(current, constrained_max)), step)

	result.new_values = inst.rolled_modifiers.duplicate()
	result.success = true
	return result


# -- Remove flow ---------------------------------------------------------

static func remove_affix(target: ItemBase, affix_index: int) -> RemoveResult:
	var result := RemoveResult.new()

	if affix_index < 0 or affix_index >= target.affixes.size():
		result.error = "Invalid affix index."
		return result

	result.removed_affix = target.affixes[affix_index]
	result.essence_returned = get_remove_return(result.removed_affix.affix_id)
	target.affixes.remove_at(affix_index)

	if target.affixes.is_empty() and target.rarity == ItemBase.Rarity.MAGIC:
		target.rarity = ItemBase.Rarity.COMMON

	result.success = true
	return result
