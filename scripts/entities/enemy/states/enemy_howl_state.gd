class_name EnemyHowlState
extends State
## A one-shot flavor action, triggered by AmbientActionComponent on a
## random timer rather than by detection (see wolf.tscn) — plays the
## "howl" animation through once, then returns to whatever fits: Chase or
## Growl if a target/alert_target showed up while howling, else back to
## Idle. Duration is read off the SpriteFrames animation itself (frame
## count / speed) rather than hardcoded, since that animation gets
## hand-tuned in the editor independently of this script.

## Extra seconds to hold the howl pose after the animation finishes.
@export var linger_time: float = 2.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	if entity.play_animation("howl"):
		var howl_sound := entity.get_node_or_null("HowlSoundPlayer") as AudioStreamPlayer2D
		if howl_sound:
			howl_sound.play()
		var frames := entity.animated_sprite.sprite_frames
		var anim_name := entity.animated_sprite.animation
		var total_durations := 0.0
		for i in frames.get_frame_count(anim_name):
			total_durations += frames.get_frame_duration(anim_name, i)
		var duration: float = total_durations / frames.get_animation_speed(anim_name)
		await entity.get_tree().create_timer(duration + linger_time).timeout
	# Something else (Hurt/Dead) may have already taken over while we were
	# mid-howl — don't yank control back if this state isn't current anymore.
	if not is_instance_valid(entity):
		return
	var state_machine := get_parent() as StateMachine
	if state_machine.current_state != self:
		return
	var enemy := entity as EnemyBase
	if enemy.target:
		transition_requested.emit(&"Chase", {})
	elif enemy.alert_target:
		transition_requested.emit(&"Growl", {})
	else:
		transition_requested.emit(&"Idle", {})

func process_physics(delta: float) -> void:
	entity.move(Vector2.ZERO, delta)
