class_name PlayerIdleState
extends State

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.sprinting = false
	entity.stop()
	entity.play_animation("idle")

func process_physics(_delta: float) -> void:
	var player := entity as Player
	if Input.is_action_just_pressed("attack"):
		if player.can_attack():
			transition_requested.emit(&"Attack", {})
			return
		player.flash_exhausted()
	if player.get_move_input() != Vector2.ZERO:
		transition_requested.emit(&"Move", {})
