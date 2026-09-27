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
		player.hitbox.damage = player.stats.compute_outgoing_damage() if player.stats else player.hitbox.damage
		player.hitbox.reset_hits()
	var moving := player.get_move_input() != Vector2.ZERO
	player.sprinting = moving and player.wants_to_sprint()
	_apply_attack_visuals(player, moving)
	_update_hitbox(player)

func process_physics(delta: float) -> void:
	_timer += delta
	var player := entity as Player
	var moving := player.get_move_input() != Vector2.ZERO
	player.sprinting = moving and player.wants_to_sprint()
	player.move(player.get_move_input() * player.attack.move_speed_multiplier, delta, false)
	if moving != _was_moving or player.sprinting != _was_sprinting:
		_apply_attack_visuals(player, moving)
	_update_hitbox(player)
	if _timer >= player.attack.duration:
		transition_requested.emit(&"Move" if moving else &"Idle", {})

func exit() -> void:
	var player := entity as Player
	player.sprinting = false
	if player.hitbox:
		player.hitbox.deactivate()

func _update_hitbox(player: Player) -> void:
	if not player.hitbox:
		return
	var frame: int = player.animated_sprite.frame if player.animated_sprite else 0
	player.hitbox.update_pose(player.facing_direction, frame, player.attack.in_active_window(_timer))
	# Directional layouts manage monitoring themselves; a plain single-shape
	# hitbox still needs the time window applied here.
	if not player.hitbox.has_directional_layout():
		player.hitbox.monitoring = player.attack.in_active_window(_timer)

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
