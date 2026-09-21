class_name CritterDeadState
extends State

## Seconds to leave the corpse resting on the final death frame before it
## starts to fade.
const LINGER_TIME: float = 10.0
## Seconds the fade-out itself takes.
const FADE_TIME: float = 3.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.set_physics_process(false)
	var body_collision := entity.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision:
		body_collision.set_deferred("disabled", true)
	if entity.play_animation("death"):
		await entity.animated_sprite.animation_finished
	if not is_instance_valid(entity):
		return
	await entity.get_tree().create_timer(LINGER_TIME).timeout
	if not is_instance_valid(entity):
		return
	var tween := entity.create_tween()
	tween.tween_property(entity, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	if is_instance_valid(entity):
		entity.queue_free()
