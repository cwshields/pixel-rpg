class_name PlayerDeadState
extends State

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.set_physics_process(false)
	entity.play_animation("death")
	GameManager.set_state(GameManager.GameState.MENU)
	# Hook your game-over screen here, e.g.:
	# UIManager.open_screen(&"game_over")
