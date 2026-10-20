class_name PlayerIdleState
extends State
## Plain standing-still state — except while the player is next to a
## harvestable prop (rock or tree) AND actively clicking it, where it
## loops the harvest animation and pulses the matching hitbox on a
## repeating window, damaging the targeted BreakableProp once per swing
## cycle. Re-checked every frame because the mouse button can be
## pressed/released and the cursor re-aimed while the player stays still.

var _harvest_timer: float = 0.0
var _was_harvesting: bool = false
var _finishing_harvest: bool = false
var _harvest_prev_frame: int = -1
var _harvest_hitbox: HitboxComponent = null
var _harvest_attack: AttackDefinition = null
var _harvest_animation: StringName = &""
var _did_harvest: bool = false

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.sprinting = false
	entity.stop()
	_harvest_timer = 0.0
	_was_harvesting = false
	_finishing_harvest = false
	_did_harvest = false
	_harvest_hitbox = null
	var player := entity as Player
	var target := player.active_harvest_target()
	if target:
		_bind_harvest(player, target)
		entity.play_animation(_harvest_animation)
	else:
		entity.play_animation("idle")

func process_physics(delta: float) -> void:
	var player := entity as Player
	if not GameManager.is_playing():
		_finishing_harvest = false
		entity.play_animation("idle")
		return
	if Input.is_action_pressed("attack") and player.hovered_harvest_target():
		player.face_toward_mouse()
	var target := player.active_harvest_target()
	var harvesting := target != null
	if harvesting:
		_bind_harvest(player, target)
	elif _harvest_hitbox:
		_harvest_hitbox.deactivate()
	if _was_harvesting and not harvesting and Input.is_action_pressed("attack"):
		_finishing_harvest = true
		_harvest_prev_frame = entity.animated_sprite.frame if entity.animated_sprite else 0
	_was_harvesting = harvesting
	if _finishing_harvest and entity.animated_sprite:
		if not entity.animated_sprite.is_playing():
			_finishing_harvest = false
		else:
			var cur := entity.animated_sprite.frame
			if cur < _harvest_prev_frame:
				_finishing_harvest = false
			_harvest_prev_frame = cur
	if harvesting:
		_did_harvest = true
	if _did_harvest and not Input.is_action_pressed("attack"):
		_did_harvest = false
	var active_harvest := harvesting or _finishing_harvest
	if not active_harvest and not _did_harvest and Input.is_action_pressed("attack") and not player.is_mouse_over_gui():
		if player.can_attack():
			transition_requested.emit(&"Attack", {})
			return
		player.flash_exhausted()
	_update_harvest_hitbox(harvesting, delta)
	if harvesting:
		entity.play_animation(_harvest_animation)
	elif not _finishing_harvest:
		entity.play_animation("idle")
	if player.get_move_input() != Vector2.ZERO:
		transition_requested.emit(&"Move", {})

func exit() -> void:
	_finishing_harvest = false
	var player := entity as Player
	if player.mine_hitbox:
		player.mine_hitbox.deactivate()
	if player.chop_hitbox:
		player.chop_hitbox.deactivate()

func _bind_harvest(player: Player, target: BreakableProp) -> void:
	var hb := player.harvest_hitbox(target)
	if hb != _harvest_hitbox:
		if _harvest_hitbox:
			_harvest_hitbox.deactivate()
		_harvest_hitbox = hb
		_harvest_timer = 0.0
	_harvest_attack = player.harvest_attack(target)
	_harvest_animation = player.harvest_animation(target)

func _update_harvest_hitbox(harvesting: bool, delta: float) -> void:
	if not harvesting:
		_harvest_timer = 0.0
		if _harvest_hitbox:
			_harvest_hitbox.deactivate()
		return
	if not _harvest_hitbox or not _harvest_attack:
		return
	var cycle := _harvest_attack.duration
	var previous_phase := fmod(_harvest_timer, cycle)
	_harvest_timer += delta
	var phase := fmod(_harvest_timer, cycle)
	if phase < previous_phase or _harvest_timer <= delta:
		_harvest_hitbox.reset_hits()
	var player := entity as Player
	var frame: int = player.animated_sprite.frame if player.animated_sprite else 0
	_harvest_hitbox.update_pose(player.facing_direction, frame, _harvest_attack.in_active_window(phase))
