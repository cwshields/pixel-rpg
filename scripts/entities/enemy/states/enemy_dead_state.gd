class_name EnemyDeadState
extends State

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.set_physics_process(false)
	var enemy := entity as EnemyBase
	if enemy.play_animation("death"):
		await enemy.animated_sprite.animation_finished
	enemy.queue_free()
