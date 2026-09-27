class_name AttackDefinition
extends Resource
## One kind of attack *motion* — a slash, a stab, a pickaxe crush — and
## the hitbox layout that goes with it. Weapons pick one of these (see
## Weapon.get_attack()) rather than owning shapes themselves, since a
## hitbox's geometry follows the swing's animation frames, not the item:
## every sword shares the slash layout, a spear reuses the stab.
##
## Knockback lives on the hitbox scene's own HitboxComponent.knockback_force,
## so it's tuned right alongside the shapes it belongs to.

## Base animation name passed to EntityBase.play_animation() — "attack"
## plays attack_<dir>, "pierce" plays pierce_<dir>. PlayerAttackState also
## tries "<animation>_run" / "<animation>_move" first while moving, and
## falls back to this when there's no moving variant.
@export var animation: StringName = &"attack"
## An Area2D scene with hitbox_component.gd whose CollisionShape2D children
## are named per direction and frame (Down, Down_3, Down_3-5 ... see
## HitboxComponent).
@export var hitbox_scene: PackedScene
## Total length of one attack (or one cycle, for a looping one like
## mining), in seconds. Tuned to the animation — 8 frames @ 14fps ≈ 0.57s.
@export var duration: float = 0.6
## Active window (seconds into the attack) for shapes with no frame tag.
## Frame-tagged shapes (Down_3 etc.) ignore this — their frames ARE the window.
@export var active_start: float = 0.2
@export var active_end: float = 0.45
## How much of normal move speed the attacker keeps mid-swing. 1.0 is full
## free movement; lower it for a more committed, weighty attack.
@export_range(0.0, 1.0) var move_speed_multiplier: float = 0.5

func in_active_window(time: float) -> bool:
	return time >= active_start and time <= active_end
