class_name AffixKnowledge
extends RefCounted
## Tracks which affixes the player has learned by destructing items.
## Each entry records the affix_id and a proficiency level (1–5) that
## improves with repeated learning, constraining imbue roll quality.

const MAX_PROFICIENCY := 5

var learned: Dictionary = {}


func has_learned(affix_id: StringName) -> bool:
	return learned.has(affix_id)


func get_proficiency(affix_id: StringName) -> int:
	return learned.get(affix_id, 0) as int


func learn_affix(affix_id: StringName) -> int:
	var current: int = learned.get(affix_id, 0) as int
	var new_level: int = mini(current + 1, MAX_PROFICIENCY)
	learned[affix_id] = new_level
	return new_level


func get_all_learned() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in learned:
		result.append(key)
	return result


func get_applicable_for(item: ItemBase) -> Array[StringName]:
	var result: Array[StringName] = []
	for affix_id: StringName in learned:
		var affix: ItemAffix = AffixDB.get_affix(affix_id)
		if affix and item.category in affix.categories:
			result.append(affix_id)
	return result


func get_proficiency_range_factor(affix_id: StringName) -> float:
	var prof: int = get_proficiency(affix_id)
	if prof <= 0:
		return 0.0
	return float(prof) / float(MAX_PROFICIENCY)


func to_save_dict() -> Dictionary:
	var data: Dictionary = {}
	for key: StringName in learned:
		data[String(key)] = learned[key]
	return {"learned": data}


static func from_save_dict(data: Dictionary) -> AffixKnowledge:
	var knowledge := AffixKnowledge.new()
	var learned_data: Dictionary = data.get("learned", {})
	for key: String in learned_data:
		knowledge.learned[StringName(key)] = int(learned_data[key])
	return knowledge
