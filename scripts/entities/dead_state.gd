class_name DeadState
extends State
## Shared corpse lifecycle: stop the entity, disable collision, play the
## death animation, linger on the final frame, fade out, then free.
## Works for any EntityBase — set `linger_time` per-scene in the inspector.

@export var linger_time: float = 10.0
@export var fade_time: float = 3.0

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
	await entity.get_tree().create_timer(linger_time).timeout
	if not is_instance_valid(entity):
		return
	var tween := entity.create_tween()
	tween.tween_property(entity, "modulate:a", 0.0, fade_time)
	await tween.finished
	if is_instance_valid(entity):
		entity.queue_free()
