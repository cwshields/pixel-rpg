class_name AIHurtState
extends State
## Shared hurt flinch for all AI entities. Plays the hurt animation, then
## transitions to whatever AIEntityBase._hurt_recovery_state() returns.

@export var hurt_duration: float = 0.3

var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	entity.play_animation("hurt")
	var hit_sound := entity.get_node_or_null("HitSoundPlayer") as AudioStreamPlayer2D
	if hit_sound:
		hit_sound.play()

func process_physics(delta: float) -> void:
	_timer += delta
	entity.move(Vector2.ZERO, delta)
	if _timer >= hurt_duration:
		transition_requested.emit((entity as AIEntityBase)._hurt_recovery_state(), {})
