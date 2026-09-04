class_name PlayerMoveState
extends State

func process_physics(delta: float) -> void:
	var player := entity as Player
	if Input.is_action_just_pressed("attack"):
		transition_requested.emit(&"Attack", {})
		return
	var input_dir: Vector2 = player.get_move_input()
	if input_dir == Vector2.ZERO:
		transition_requested.emit(&"Idle", {})
		return
	entity.move(input_dir.normalized(), delta)
	entity.play_animation("walk")
