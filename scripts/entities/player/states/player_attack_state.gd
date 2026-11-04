class_name PlayerAttackState
extends State
## Plays the equipped weapon's attack (Player.attack — slash, stab, ...).
## Timing, animation and move speed come from that AttackDefinition; the
## hitbox itself is driven frame by frame via HitboxComponent.update_pose(),
## so its shapes follow the swing's arc on screen (see slash_hitbox.tscn)
## and only connect on the frames that have shapes.

var _timer: float = 0.0
var _was_moving: bool = false
var _was_sprinting: bool = false

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	var player := entity as Player
	if player.stamina:
		player.stamina.spend_attack()
	player.face_toward_mouse()
	if player.hitbox:
		if player.stats:
			player.hitbox.damage_breakdown = player.stats.compute_outgoing_damage()
		player.hitbox.reset_hits()
	var moving := player.get_move_input() != Vector2.ZERO
	player.sprinting = moving and player.wants_to_sprint()
	_apply_attack_visuals(player, moving)
	_update_hitbox(player)
	if player.weapon_overlay:
		player.weapon_overlay.show_overlay()
	player.play_swing_sound()

func process_physics(delta: float) -> void:
	_timer += delta
	var player := entity as Player
	var moving := player.get_move_input() != Vector2.ZERO
	player.sprinting = moving and player.wants_to_sprint()
	player.move(player.get_move_input() * player.attack.move_speed_multiplier, delta, false)
	if moving != _was_moving or player.sprinting != _was_sprinting:
		_apply_attack_visuals(player, moving)
	_update_hitbox(player)
	var atk_spd: float = 1.0 + (player.stats.attack_speed if player.stats else 0.0)
	if _timer >= player.attack.duration / atk_spd:
		if Input.is_action_pressed("attack") and not player.is_mouse_over_gui() and player.can_attack():
			_timer = 0.0
			player.face_toward_mouse()
			if player.stamina:
				player.stamina.spend_attack()
			if player.hitbox:
				if player.stats:
					player.hitbox.damage_breakdown = player.stats.compute_outgoing_damage()
				player.hitbox.reset_hits()
			_apply_attack_visuals(player, moving)
			_update_hitbox(player)
			player.play_swing_sound()
		else:
			transition_requested.emit(&"Move" if moving else &"Idle", {})

func exit() -> void:
	var player := entity as Player
	player.sprinting = false
	if player.hitbox:
		player.hitbox.deactivate()
	if player.weapon_overlay:
		player.weapon_overlay.hide_overlay()
	if player.swing_sound_player and player.swing_sound_player.playing:
		player.swing_sound_player.stop()

func _update_hitbox(player: Player) -> void:
	if not player.hitbox:
		return
	var frame: int = player.animated_sprite.frame if player.animated_sprite else 0
	var atk_spd: float = 1.0 + (player.stats.attack_speed if player.stats else 0.0)
	var scaled_time: float = _timer * atk_spd
	player.hitbox.update_pose(player.facing_direction, frame, player.attack.in_active_window(scaled_time))
	if not player.hitbox.has_directional_layout():
		player.hitbox.monitoring = player.attack.in_active_window(scaled_time)

## Chooses the attack animation for the current movement state (called only
## when it changes). Sprinting tries "<animation>_run_<dir>", walking
## "<animation>_move_<dir>" (only the slash has these, side-only), each
## falling back to the plain "<animation>_<dir>" swing.
func _apply_attack_visuals(player: Player, moving: bool) -> void:
	_was_moving = moving
	_was_sprinting = player.sprinting
	var base := String(player.attack.animation)
	if moving and player.sprinting and player.play_animation(base + "_run"):
		return
	if moving and player.play_animation(base + "_move"):
		return
	player.play_animation(base)
