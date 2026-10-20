class_name FootstepPlayer
extends AudioStreamPlayer2D

@export var footstep_sounds: Array[AudioStream] = []
@export var walk_step_frames: PackedInt32Array = [0, 3]
@export var run_step_frames: PackedInt32Array = [1, 4]
@export var attack_move_step_frames: PackedInt32Array = [2, 5]
@export var step_volume_db: float = -18.9
@export var walk_volume_db: float = -24.2
@export var pitch_variance: float = 0.1

var _sprite: AnimatedSprite2D

func bind(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite
	_sprite.frame_changed.connect(_on_frame_changed)

func _on_frame_changed() -> void:
	if not _sprite or footstep_sounds.is_empty():
		return
	var anim := String(_sprite.animation)
	var frames: PackedInt32Array
	var vol := step_volume_db
	if anim.begins_with("walk"):
		frames = walk_step_frames
		vol = walk_volume_db
	elif anim.begins_with("attack_move"):
		frames = attack_move_step_frames
	elif anim.begins_with("run"):
		frames = run_step_frames
	else:
		return
	if _sprite.frame in frames:
		_play_random(vol)

func _play_random(vol: float) -> void:
	stream = footstep_sounds.pick_random()
	volume_db = vol
	pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	play()
