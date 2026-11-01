class_name Ammo
extends ItemBase
## Stackable ammunition consumed by ranged weapons (bows, crossbows).
## Each ammo resource defines its own damage bonus and projectile speed;
## the bow's base damage is added on top.

enum AmmoType { ARROW, BOLT }

@export var ammo_type: AmmoType = AmmoType.ARROW
@export var damage_bonus: float = 1.0
@export var projectile_speed: float = 200.0

func _init() -> void:
	category = Category.AMMO
	max_stack = 100
