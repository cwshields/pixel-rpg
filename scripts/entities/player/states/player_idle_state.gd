class_name PlayerIdleState
extends State
## Plain standing-still state — except while the player is next to a
## mineable rock AND actively clicking it (see Player.is_mining_rock()),
## where it loops the "crush" animation (swinging a pickaxe) and pulses
## Player.mine_hitbox on a repeating window, damaging whatever's in front of
## the player (normally the targeted RockProp's HurtboxComponent) once
## per swing cycle. Re-checked every frame rather than once on enter()
## because, unlike proximity alone, the mouse button can be
## pressed/released (and the mouse re-aimed off the rock) while the
## player stays perfectly still. While mining, the shared "attack" button
## drives the pickaxe swing instead of the sword's Attack state.

## The crush cycle length and per-cycle active window come from
## Player.MINE_ATTACK (resources/combat/attacks/crush.tres) — same
## AttackDefinition windowing as a sword swing, but repeating instead of
## one-shot since mining loops for as long as the button's held.

var _mine_timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.sprinting = false
	entity.stop()
	_mine_timer = 0.0
	var player := entity as Player
	entity.play_animation("crush" if player.is_mining_rock() else "idle")

func process_physics(delta: float) -> void:
	var player := entity as Player
	var mining := player.is_mining_rock()
	if mining:
		player.face_toward_mouse()
	elif Input.is_action_just_pressed("attack"):
		if player.can_attack():
			transition_requested.emit(&"Attack", {})
			return
		player.flash_exhausted()
	_update_mine_hitbox(player, mining, delta)
	entity.play_animation("crush" if mining else "idle")
	if player.get_move_input() != Vector2.ZERO:
		transition_requested.emit(&"Move", {})

func exit() -> void:
	var player := entity as Player
	if player.mine_hitbox:
		player.mine_hitbox.deactivate()

func _update_mine_hitbox(player: Player, mining: bool, delta: float) -> void:
	var hitbox := player.mine_hitbox
	if not mining:
		_mine_timer = 0.0
		if hitbox:
			hitbox.deactivate()
		return
	var cycle := Player.MINE_ATTACK.duration
	var previous_phase := fmod(_mine_timer, cycle)
	_mine_timer += delta
	if not hitbox:
		return
	var phase := fmod(_mine_timer, cycle)
	# Each swing of the pickaxe can strike the rock once — a fresh cycle
	# (or the very first) clears the hit-once set.
	if phase < previous_phase or _mine_timer <= delta:
		hitbox.reset_hits()
	var frame: int = player.animated_sprite.frame if player.animated_sprite else 0
	hitbox.update_pose(player.facing_direction, frame, Player.MINE_ATTACK.in_active_window(phase))
