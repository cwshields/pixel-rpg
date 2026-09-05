class_name PlayerAttackState
extends State
## Swings whatever's in HitboxComponent. The hitbox only actually damages
## anything while `monitoring` is true, so we window that to the "active"
## portion of the swing instead of the whole animation.

## Tuned to the Slice animation (8 frames @ 14fps ≈ 0.57s); adjust if you
## swap in a different attack animation/weapon speed.
@export var attack_duration: float = 0.6
@export var hitbox_active_start: float = 0.2
@export var hitbox_active_end: float = 0.45

## How much of normal move speed the player keeps while mid-swing. 1.0 is
## full free movement; lower it for a more committed, weighty attack.
@export_range(0.0, 1.0) var move_speed_multiplier: float = 0.5

var _timer: float = 0.0
var _was_moving: bool = false
var _was_sprinting: bool = false

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	var player := entity as Player
	var aim := player.get_global_mouse_position() - player.global_position
	if aim != Vector2.ZERO:
		player.facing_direction = aim.normalized()
		player.facing_changed.emit(player.facing_direction)
	if player.hitbox:
		player.hitbox.global_rotation = player.facing_direction.angle()
		player.hitbox.damage = player.stats.compute_outgoing_damage() if player.stats else player.hitbox.damage
	var moving := player.get_move_input() != Vector2.ZERO
	player.sprinting = moving and player.wants_to_sprint()
	_apply_attack_visuals(player, moving)

func process_physics(delta: float) -> void:
	_timer += delta
	var player := entity as Player
	var moving := player.get_move_input() != Vector2.ZERO
	player.sprinting = moving and player.wants_to_sprint()
	player.move(player.get_move_input() * move_speed_multiplier, delta, false)
	if moving != _was_moving or player.sprinting != _was_sprinting:
		_apply_attack_visuals(player, moving)
	if player.hitbox:
		player.hitbox.monitoring = _timer >= hitbox_active_start and _timer <= hitbox_active_end
	if _timer >= attack_duration:
		transition_requested.emit(&"Move" if moving else &"Idle", {})

func exit() -> void:
	var player := entity as Player
	player.sprinting = false
	if player.hitbox:
		player.hitbox.monitoring = false

## Chooses the attack animation for the current movement state (called only
## when it changes). Sprinting uses the combined run+slice sheet
## ("attack_run_<dir>"), walking the run/walk+slice sheet
## ("attack_move_<dir>") — both currently side-only — each falling back to
## the plain "attack" swing when there's no directional art.
func _apply_attack_visuals(player: Player, moving: bool) -> void:
	_was_moving = moving
	_was_sprinting = player.sprinting
	if moving and player.sprinting and player.play_animation("attack_run"):
		return
	if moving and player.play_animation("attack_move"):
		return
	player.play_animation("attack")
