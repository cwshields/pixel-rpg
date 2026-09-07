class_name EnemyDeadState
extends State

## Seconds to leave the corpse resting on the final death frame before it
## starts to fade.
const LINGER_TIME: float = 10.0
## Seconds the fade-out itself takes.
const FADE_TIME: float = 3.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.set_physics_process(false)
	var enemy := entity as EnemyBase
	# Let the player walk through the corpse right away.
	var body_collision := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision:
		body_collision.set_deferred("disabled", true)
	if enemy.play_animation("death"):
		await enemy.animated_sprite.animation_finished
	if not is_instance_valid(enemy):
		return
	await enemy.get_tree().create_timer(LINGER_TIME).timeout
	if not is_instance_valid(enemy):
		return
	var tween := enemy.create_tween()
	tween.tween_property(enemy, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	if is_instance_valid(enemy):
		enemy.queue_free()
