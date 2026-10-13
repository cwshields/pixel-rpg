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
var _was_mining: bool = false
var _finishing_crush: bool = false
var _crush_prev_frame: int = -1

var _chop_timer: float = 0.0
var _was_chopping: bool = false
var _finishing_chop: bool = false
var _chop_prev_frame: int = -1

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.sprinting = false
	entity.stop()
	_mine_timer = 0.0
	_was_mining = false
	_finishing_crush = false
	_chop_timer = 0.0
	_was_chopping = false
	_finishing_chop = false
	var player := entity as Player
	if player.is_mining_rock():
		entity.play_animation("crush")
	elif player.is_chopping_tree():
		entity.play_animation("attack")
	else:
		entity.play_animation("idle")

func process_physics(delta: float) -> void:
	var player := entity as Player
	if not GameManager.is_playing():
		_finishing_crush = false
		_finishing_chop = false
		entity.play_animation("idle")
		return
	if Input.is_action_pressed("attack") and (player.wants_to_mine_rock() or player.wants_to_chop_tree()):
		player.face_toward_mouse()
	var mining := player.is_mining_rock()
	var chopping := player.is_chopping_tree()
	if _was_mining and not mining and Input.is_action_pressed("attack"):
		_finishing_crush = true
		_crush_prev_frame = entity.animated_sprite.frame if entity.animated_sprite else 0
	_was_mining = mining
	if _was_chopping and not chopping and Input.is_action_pressed("attack"):
		_finishing_chop = true
		_chop_prev_frame = entity.animated_sprite.frame if entity.animated_sprite else 0
	_was_chopping = chopping
	if _finishing_crush and entity.animated_sprite:
		if not entity.animated_sprite.is_playing():
			_finishing_crush = false
		else:
			var cur := entity.animated_sprite.frame
			if cur < _crush_prev_frame:
				_finishing_crush = false
			_crush_prev_frame = cur
	if _finishing_chop and entity.animated_sprite:
		if not entity.animated_sprite.is_playing():
			_finishing_chop = false
		else:
			var cur := entity.animated_sprite.frame
			if cur < _chop_prev_frame:
				_finishing_chop = false
			_chop_prev_frame = cur
	var harvesting := mining or chopping or _finishing_crush or _finishing_chop
	if not harvesting and Input.is_action_pressed("attack") and not player.is_mouse_over_gui():
		if player.can_attack():
			transition_requested.emit(&"Attack", {})
			return
		player.flash_exhausted()
	_update_mine_hitbox(player, mining, delta)
	_update_chop_hitbox(player, chopping, delta)
	if mining:
		entity.play_animation("crush")
	elif chopping:
		entity.play_animation("attack")
	elif not _finishing_crush and not _finishing_chop:
		entity.play_animation("idle")
	if player.get_move_input() != Vector2.ZERO:
		transition_requested.emit(&"Move", {})

func exit() -> void:
	_finishing_crush = false
	_finishing_chop = false
	var player := entity as Player
	if player.mine_hitbox:
		player.mine_hitbox.deactivate()
	if player.chop_hitbox:
		player.chop_hitbox.deactivate()

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

func _update_chop_hitbox(player: Player, chopping: bool, delta: float) -> void:
	var hitbox := player.chop_hitbox
	if not chopping:
		_chop_timer = 0.0
		if hitbox:
			hitbox.deactivate()
		return
	var cycle := Player.CHOP_ATTACK.duration
	var previous_phase := fmod(_chop_timer, cycle)
	_chop_timer += delta
	if not hitbox:
		return
	var phase := fmod(_chop_timer, cycle)
	if phase < previous_phase or _chop_timer <= delta:
		hitbox.reset_hits()
	var frame: int = player.animated_sprite.frame if player.animated_sprite else 0
	hitbox.update_pose(player.facing_direction, frame, Player.CHOP_ATTACK.in_active_window(phase))
