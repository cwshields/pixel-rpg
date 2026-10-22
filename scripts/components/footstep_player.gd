class_name FootstepPlayer
extends AudioStreamPlayer2D

@export var footstep_sounds: Array[AudioStream] = []
@export var walk_step_frames: PackedInt32Array = [0, 3]
@export var run_step_frames: PackedInt32Array = [1, 4]
@export var flee_step_frames: PackedInt32Array = [1, 4]
@export var attack_move_step_frames: PackedInt32Array = [2, 5]
@export var step_volume_db: float = -10.0
@export var walk_volume_db: float = -13.0
@export var pitch_variance: float = 0.1

@export_group("Overlay Sound")
@export var overlay_player_path: NodePath
@export var overlay_every_min: int = 2
@export var overlay_every_max: int = 4

var _sprite: AnimatedSprite2D
var _overlay_player: AudioStreamPlayer2D
var _step_count: int = 0
var _next_overlay: int = 0

func bind(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite
	_sprite.frame_changed.connect(_on_frame_changed)
	if overlay_player_path:
		_overlay_player = get_node_or_null(overlay_player_path) as AudioStreamPlayer2D
		_next_overlay = randi_range(overlay_every_min, overlay_every_max)

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
	elif anim.begins_with("flee"):
		frames = flee_step_frames
	else:
		return
	if _sprite.frame in frames:
		_play_random(vol)
		_step_count += 1
		if _overlay_player and _step_count >= _next_overlay:
			_overlay_player.play()
			_step_count = 0
			_next_overlay = randi_range(overlay_every_min, overlay_every_max)

func _play_random(vol: float) -> void:
	stream = footstep_sounds.pick_random()
	volume_db = vol
	pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	play()
