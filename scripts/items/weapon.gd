class_name Weapon
extends ItemBase

enum WeaponType { SWORD, DAGGER, AXE, SPEAR, BOW, STAFF }

## Fallback APS per WeaponType, used whenever a weapon leaves attack_speed
## at its default (0 — "unset"). Tune per-type feel here; individual
## weapons only need attack_speed set when they deviate from their type.
const TYPE_DEFAULT_APS := {
	WeaponType.SWORD: 1.0,
	WeaponType.DAGGER: 1.6,
	WeaponType.AXE: 0.7,
	WeaponType.SPEAR: 0.9,
	WeaponType.BOW: 1.2,
	WeaponType.STAFF: 0.8,
}

@export var weapon_type: WeaponType = WeaponType.SWORD
@export var damage: float = 5.0
## 0 (default) means "use this weapon_type's TYPE_DEFAULT_APS entry" —
## see get_effective_attack_speed(). Set explicitly only to override that
## per-type default for a specific weapon.
@export var attack_speed: float = 0.0
@export var crit_bonus: float = 0.0
@export var two_handed: bool = false

## Display-only damage range for the tooltip ("min-max Physical Damage");
## `damage` above is what actually feeds apply_modifiers(). Leave both at
## 0 to hide the line.
@export var min_damage: float = 0.0
@export var max_damage: float = 0.0
## 0 hides the durability line. Tool has its own separate durability
## pattern (max_durability + a runtime counter) — mirrored here rather
## than lifted to ItemBase since not every item type wears down.
@export var max_durability: int = 0

var durability: int

func _init() -> void:
	category = Category.WEAPON
	durability = max_durability

func apply_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	stats.add_modifier(&"attack", damage, source_id)
	stats.add_modifier(&"crit_chance", crit_bonus, source_id)

## attack_speed left at 0 falls back to this weapon's TYPE_DEFAULT_APS
## entry; anything explicitly set on the resource wins.
func get_effective_attack_speed() -> float:
	return attack_speed if attack_speed > 0.0 else TYPE_DEFAULT_APS.get(weapon_type, 1.0)

func get_stat_lines() -> Array[String]:
	var lines: Array[String] = []
	if min_damage > 0.0 or max_damage > 0.0:
		lines.append("%d-%d Physical Damage" % [roundi(min_damage), roundi(max_damage)])
	if max_durability > 0:
		lines.append("%d/%d Durability" % [durability, max_durability])
	lines.append("%.1f Attacks Per Second" % get_effective_attack_speed())
	return lines
