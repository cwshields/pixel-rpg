class_name SetDefinition
extends Resource
## Defines a named equipment set: which items belong to it and what bonuses
## activate at each equipped-piece threshold.

@export var id: StringName
@export var set_name: String
## Item IDs that belong to this set.
@export var member_ids: Array[StringName] = []
## Bonuses that unlock when N pieces are equipped. Each entry is a threshold
## dictionary: { "pieces": int, "modifiers": { &"stat": value } }.
## Example: [{ pieces = 2, modifiers = { &"fire_resist": 0.10 } },
##           { pieces = 4, modifiers = { &"attack": 5, &"crit_chance": 0.05 } }]
@export var bonuses: Array[Dictionary] = []


func get_active_modifiers(equipped_count: int) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in bonuses:
		if equipped_count >= int(entry.get("pieces", 99)):
			var mods: Dictionary = entry.get("modifiers", {})
			for stat: StringName in mods:
				result[stat] = result.get(stat, 0.0) + float(mods[stat])
	return result


func get_bonus_lines(equipped_count: int) -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in bonuses:
		var needed: int = int(entry.get("pieces", 0))
		var active := equipped_count >= needed
		var mods: Dictionary = entry.get("modifiers", {})
		var header := "(%d/%d) Set Bonus:" % [mini(equipped_count, needed), needed]
		if not active:
			header = "[inactive] " + header
		lines.append(header)
		for stat: StringName in mods:
			var val: float = float(mods[stat])
			var sign := "+" if val >= 0.0 else ""
			var label := AffixInstance._format_stat_name(stat)
			if AffixInstance._is_percent_stat(stat):
				lines.append("  %s%.0f%% %s" % [sign, val * 100.0, label])
			else:
				lines.append("  %s%.0f %s" % [sign, val, label])
	return lines
