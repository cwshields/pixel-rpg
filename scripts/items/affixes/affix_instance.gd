class_name AffixInstance
extends RefCounted
## A concrete affix rolled onto an item — the template id plus the actual
## values that fell within the template's [min, max] range.

var affix_id: StringName
var display_name: String
var type: ItemAffix.AffixType
## { &"stat_name": rolled_float_value }
var rolled_modifiers: Dictionary


static func roll_from(affix: ItemAffix) -> AffixInstance:
	var inst := AffixInstance.new()
	inst.affix_id = affix.id
	inst.display_name = affix.display_name
	inst.type = affix.type
	inst.rolled_modifiers = {}
	for stat: StringName in affix.modifiers:
		var range: Vector2 = affix.modifiers[stat]
		var step := 0.01 if _is_percent_stat(stat) else 0.1
		inst.rolled_modifiers[stat] = snappedf(randf_range(range.x, range.y), step)
	return inst


func get_stat_lines() -> Array[String]:
	var lines: Array[String] = []
	for stat: StringName in rolled_modifiers:
		var val: float = rolled_modifiers[stat]
		var sign := "+" if val >= 0.0 else ""
		var label := _format_stat_name(stat)
		if _is_percent_stat(stat):
			lines.append("%s%.0f%% %s" % [sign, val * 100.0, label])
		else:
			lines.append("%s%.0f %s" % [sign, val, label])
	return lines


static func _format_stat_name(stat: StringName) -> String:
	match stat:
		&"attack": return "Attack"
		&"defense": return "Defense"
		&"max_health": return "Life"
		&"max_mana": return "Mana"
		&"strength": return "Strength"
		&"dexterity": return "Dexterity"
		&"constitution": return "Constitution"
		&"intelligence": return "Intelligence"
		&"charisma": return "Charisma"
		&"crit_chance": return "Critical Strike Chance"
		&"dodge_chance": return "Dodge Chance"
		&"block_chance": return "Block Chance"
		&"move_speed": return "Movement Speed"
		&"regeneration": return "Life Regeneration"
		&"lifesteal": return "Life Stolen per Hit"
		&"luck": return "Luck"
		&"fire_damage": return "Fire Damage"
		&"ice_damage": return "Ice Damage"
		&"venom_damage": return "Venom Damage"
		&"lightning_damage": return "Lightning Damage"
		&"holy_arcana_damage": return "Holy Damage"
		&"fire_resist": return "Fire Resistance"
		&"ice_resist": return "Ice Resistance"
		&"venom_resist": return "Venom Resistance"
		&"lightning_resist": return "Lightning Resistance"
		&"holy_arcana_resist": return "Holy Resistance"
		&"physical_resist": return "Physical Resistance"
		&"damage_percent": return "Damage"
		&"speed_multiplier": return "Move Speed Multiplier"
		&"attack_speed": return "Attack Speed"
		&"evasion": return "Evasion"
	return String(stat).capitalize()


static func _is_percent_stat(stat: StringName) -> bool:
	return stat in [
		&"crit_chance", &"dodge_chance", &"block_chance",
		&"lifesteal", &"damage_percent", &"attack_speed",
		&"fire_resist", &"ice_resist", &"venom_resist",
		&"lightning_resist", &"holy_arcana_resist", &"physical_resist",
	]


func to_dict() -> Dictionary:
	return {
		"affix_id": String(affix_id),
		"rolled_modifiers": rolled_modifiers.duplicate(),
	}


static func from_dict(data: Dictionary, database: Node) -> AffixInstance:
	var affix: ItemAffix = database.get_affix(StringName(data["affix_id"]))
	if not affix:
		return null
	var inst := AffixInstance.new()
	inst.affix_id = affix.id
	inst.display_name = affix.display_name
	inst.type = affix.type
	inst.rolled_modifiers = {}
	for key: String in data.get("rolled_modifiers", {}):
		var val := float(data["rolled_modifiers"][key])
		var stat := StringName(key)
		if stat == &"speed_multiplier" and affix.id in [&"pre_swift", &"pre_nimble", &"pre_blinding"]:
			stat = &"attack_speed"
		if _is_percent_stat(stat) and val > 1.0:
			val = val / 100.0
		inst.rolled_modifiers[stat] = val
	return inst
