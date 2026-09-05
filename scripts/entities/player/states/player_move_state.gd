class_name PlayerMoveState
extends State

func exit() -> void:
	entity.sprinting = false

func process_physics(delta: float) -> void:
	var player := entity as Player
	if Input.is_action_just_pressed("attack"):
		transition_requested.emit(&"Attack", {})
		return
	var input_dir: Vector2 = player.get_move_input()
	if input_dir == Vector2.ZERO:
		transition_requested.emit(&"Idle", {})
		return
	player.sprinting = player.wants_to_sprint()
	entity.move(input_dir.normalized(), delta)
	entity.play_animation("run" if player.sprinting else "walk")
