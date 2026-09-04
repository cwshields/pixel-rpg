class_name HitboxComponent
extends Area2D
## An attack's damage source — a sword swing, an arrow, a fireball. Leave
## `monitoring` off by default and switch it on only for the active
## frames of an attack (an attack State is the usual place to do this).

@export var damage: float = 5.0
@export var knockback_force: float = 150.0
## Whoever is dealing this damage. Set by the owning entity so hitboxes
## don't hurt their own source and so death credit/loot can be attributed.
var source: Node = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hurtbox := area as HurtboxComponent
	if source and hurtbox.get_parent() == source:
		return
	var knockback: Vector2 = Vector2.ZERO
	if source and source is Node2D and hurtbox.get_parent() is Node2D:
		var away: Vector2 = hurtbox.get_parent().global_position - (source as Node2D).global_position
		knockback = away.normalized() * knockback_force if away.length() > 0.0 else Vector2.ZERO
	hurtbox.receive_hit(damage, source, knockback)
