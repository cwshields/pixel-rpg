class_name Weapon
extends ItemBase

enum WeaponType { SWORD, DAGGER, AXE, SPEAR, BOW, STAFF }

@export var weapon_type: WeaponType = WeaponType.SWORD
@export var damage: float = 5.0
@export var attack_speed: float = 1.0
@export var crit_bonus: float = 0.0
@export var two_handed: bool = false

func _init() -> void:
	category = Category.WEAPON

func apply_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	stats.add_modifier(&"attack", damage, source_id)
	stats.add_modifier(&"crit_chance", crit_bonus, source_id)
