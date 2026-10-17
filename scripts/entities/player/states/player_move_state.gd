class_name PlayerMoveState
extends State

func exit() -> void:
	entity.sprinting = false
	var player := entity as Player
	if player.stamina:
		player.stamina.sprinting = false

func process_physics(delta: float) -> void:
	var player := entity as Player
	if not GameManager.is_playing():
		transition_requested.emit(&"Idle", {})
		return
	if Input.is_action_pressed("attack") and not player.is_mouse_over_gui():
		if player.hovered_harvest_target():
			transition_requested.emit(&"Idle", {})
			return
		if player.can_attack():
			transition_requested.emit(&"Attack", {})
			return
		player.flash_exhausted()
	var input_dir: Vector2 = player.get_move_input()
	if input_dir == Vector2.ZERO:
		transition_requested.emit(&"Idle", {})
		return
	player.sprinting = player.can_sprint()
	if player.stamina:
		player.stamina.sprinting = player.sprinting
	entity.move(input_dir.normalized(), delta)
	entity.play_animation("run" if player.sprinting else "walk")
