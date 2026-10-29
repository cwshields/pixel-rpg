class_name Weapon
extends ItemBase

enum WeaponType { SWORD, DAGGER, AXE, SPEAR, BOW, STAFF, MACE }

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
	WeaponType.MACE: 0.65,
}

## Per-type hitbox profiles: {reach_scale, width_scale, knockback_override}.
## Applied when a weapon leaves its own field at the default. A dagger is
## tight and fast; an axe is wide and heavy; a spear has extreme reach but
## narrow width.
const TYPE_DEFAULT_HITBOX := {
	WeaponType.SWORD:  {reach = 1.0, width = 1.0, knockback = -1.0},
	WeaponType.DAGGER: {reach = 0.7, width = 0.6, knockback = 60.0},
	WeaponType.AXE:    {reach = 1.0, width = 1.3, knockback = 200.0},
	WeaponType.SPEAR:  {reach = 1.5, width = 0.5, knockback = 100.0},
	WeaponType.BOW:    {reach = 1.0, width = 1.0, knockback = -1.0},
	WeaponType.STAFF:  {reach = 1.2, width = 1.0, knockback = 120.0},
	WeaponType.MACE:   {reach = 0.9, width = 1.1, knockback = 220.0},
}

## Fallback attack motion per WeaponType, used whenever a weapon leaves
## `attack` unset. Hitbox shapes belong to the motion (see AttackDefinition),
## so every weapon of a type shares one tuned layout. AXE/STAFF/BOW reuse
## the slash until they get their own animations.
const TYPE_DEFAULT_ATTACK := {
	WeaponType.SWORD: preload("res://resources/combat/attacks/slash.tres"),
	WeaponType.DAGGER: preload("res://resources/combat/attacks/stab.tres"),
	WeaponType.AXE: preload("res://resources/combat/attacks/slash.tres"),
	WeaponType.SPEAR: preload("res://resources/combat/attacks/stab.tres"),
	WeaponType.BOW: preload("res://resources/combat/attacks/slash.tres"),
	WeaponType.STAFF: preload("res://resources/combat/attacks/slash.tres"),
	WeaponType.MACE: preload("res://resources/combat/attacks/slash.tres"),
}

@export var weapon_type: WeaponType = WeaponType.SWORD
## Overrides this weapon_type's TYPE_DEFAULT_ATTACK entry — e.g. a sword
## that stabs. Leave empty to use the type default. See get_attack().
@export var attack: AttackDefinition
## Stretches the attack's hitbox outward along the facing axis (1.2 = 20%
## more reach), so a longer blade can reuse the shared layout.
@export var reach_scale: float = 1.0
## Stretches the hitbox perpendicular to the facing axis — wider arc for
## axes and greatswords, narrower for daggers and spears.
@export var width_scale: float = 1.0
## Overrides the hitbox scene's knockback_force for this weapon. Leave at
## -1 to use the scene default (e.g. slash = 150, stab = 90).
@export var knockback_override: float = -1.0
@export var damage: float = 5.0
## 0 (default) means "use this weapon_type's TYPE_DEFAULT_APS entry" —
## see get_effective_attack_speed(). Set explicitly only to override that
## per-type default for a specific weapon.
@export var attack_speed: float = 0.0
@export var crit_bonus: float = 0.0
@export var two_handed: bool = false
## Optional texture shown on the weapon overlay during attack animations.
## Falls back to `icon` when unset.
@export var swing_sprite: Texture2D

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
	super.apply_modifiers(stats, source_id)

## attack_speed left at 0 falls back to this weapon's TYPE_DEFAULT_APS
## entry; anything explicitly set on the resource wins.
func get_effective_attack_speed() -> float:
	return attack_speed if attack_speed > 0.0 else TYPE_DEFAULT_APS.get(weapon_type, 1.0)

## `attack` if set, else this weapon_type's TYPE_DEFAULT_ATTACK entry.
func get_attack() -> AttackDefinition:
	return attack if attack else TYPE_DEFAULT_ATTACK.get(weapon_type)

func get_effective_reach_scale() -> float:
	if reach_scale != 1.0:
		return reach_scale
	var profile: Dictionary = TYPE_DEFAULT_HITBOX.get(weapon_type, {})
	return profile.get("reach", 1.0)

func get_effective_width_scale() -> float:
	if width_scale != 1.0:
		return width_scale
	var profile: Dictionary = TYPE_DEFAULT_HITBOX.get(weapon_type, {})
	return profile.get("width", 1.0)

func get_effective_knockback() -> float:
	if knockback_override >= 0.0:
		return knockback_override
	var profile: Dictionary = TYPE_DEFAULT_HITBOX.get(weapon_type, {})
	return profile.get("knockback", -1.0)

func get_stat_lines() -> Array[String]:
	var lines: Array[String] = []
	if min_damage > 0.0 or max_damage > 0.0:
		lines.append("%d-%d Physical Damage" % [roundi(min_damage), roundi(max_damage)])
	if max_durability > 0:
		lines.append("%d/%d Durability" % [durability, max_durability])
	lines.append("%.1f Attacks Per Second" % get_effective_attack_speed())
	return lines
