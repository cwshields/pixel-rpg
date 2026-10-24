extends CanvasModulate
## Autoload that drives a day/night cycle via CanvasModulate tinting.
##
## The full cycle (day_duration + night_duration) loops continuously.
## Transition periods (dawn/dusk) are a fraction of each phase spent
## smoothly lerping between the day and night tint colors.

@export_group("Timing")
@export var day_duration: float = 300.0
@export var night_duration: float = 300.0
@export_range(0.0, 0.5) var transition_ratio: float = 0.2

@export_group("Colors")
@export var day_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var night_color: Color = Color(0.15, 0.12, 0.25, 1.0)

@export_group("Night Audio")
@export var night_sound: AudioStream = preload("res://assets/SoundFX/Woodlands/forest-night-sounds.mp3")
@export var night_sound_volume: float = -10.0
@export var night_sound_fade_time: float = 4.0
@export var night_sound_crossfade_at: float = 222.0

@export_group("Start")
@export var start_at_night: bool = true

var _night_players: Array[AudioStreamPlayer] = []
var _night_active: int = 0
var _night_crossfade_triggered: bool = false
var _night_volume_target: float = 0.0

var cycle_time: float = 0.0
var total_cycle: float:
	get: return day_duration + night_duration

var is_night: bool = false

func _ready() -> void:
	if night_sound:
		var stream := night_sound.duplicate()
		if stream is AudioStreamMP3:
			stream.loop = false
		elif stream is AudioStreamOggVorbis:
			stream.loop = false
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.volume_db = -80.0
			p.bus = &"Master"
			add_child(p)
			_night_players.append(p)
		_night_players[0].play()
	if start_at_night:
		cycle_time = day_duration + night_duration * 0.5
	_apply_tint()
	_update_night_audio(true)

func _process(delta: float) -> void:
	cycle_time += delta
	if cycle_time >= total_cycle:
		cycle_time -= total_cycle
	_apply_tint()
	_update_night_audio(false, delta)

func _apply_tint() -> void:
	var t := cycle_time
	var day_end := day_duration
	var night_start := day_duration
	var night_end := total_cycle

	var dusk_duration := day_duration * transition_ratio
	var dawn_duration := night_duration * transition_ratio

	var dusk_start := day_end - dusk_duration
	var dawn_end := night_end - dawn_duration if dawn_duration > 0.0 else night_end

	if t < dusk_start:
		color = day_color
		is_night = false
	elif t < day_end:
		var progress := (t - dusk_start) / dusk_duration if dusk_duration > 0.0 else 1.0
		color = day_color.lerp(night_color, progress)
		is_night = false
	elif t < dawn_end:
		color = night_color
		is_night = true
	else:
		var progress := (t - dawn_end) / dawn_duration if dawn_duration > 0.0 else 1.0
		color = night_color.lerp(day_color, progress)
		is_night = true

func _update_night_audio(instant: bool, delta: float = 0.0) -> void:
	if _night_players.is_empty():
		return

	var phase := get_phase()
	if phase == "night":
		_night_volume_target = night_sound_volume
	elif phase == "dusk":
		var dusk_dur := day_duration * transition_ratio
		var dusk_start := day_duration - dusk_dur
		var progress := (cycle_time - dusk_start) / dusk_dur if dusk_dur > 0.0 else 1.0
		_night_volume_target = lerpf(-80.0, night_sound_volume, progress)
	elif phase == "dawn":
		var dawn_dur := night_duration * transition_ratio
		var dawn_end := total_cycle - dawn_dur
		var progress := (cycle_time - dawn_end) / dawn_dur if dawn_dur > 0.0 else 1.0
		_night_volume_target = lerpf(night_sound_volume, -80.0, progress)
	else:
		_night_volume_target = -80.0

	var speed := 80.0 / maxf(night_sound_fade_time, 0.1)
	for p in _night_players:
		if instant:
			p.volume_db = _night_volume_target if p.playing else -80.0
		elif p.playing:
			p.volume_db = move_toward(p.volume_db, _night_volume_target, speed * delta)

	var active := _night_players[_night_active]
	if not active.playing:
		var other := _night_players[1 - _night_active]
		if other.playing:
			_night_active = 1 - _night_active
		else:
			active.volume_db = _night_volume_target
			active.play()
		_night_crossfade_triggered = false
		return

	if active.get_playback_position() < night_sound_crossfade_at:
		_night_crossfade_triggered = false
	elif not _night_crossfade_triggered:
		_night_crossfade_triggered = true
		var next := 1 - _night_active
		_night_players[next].volume_db = _night_volume_target
		_night_players[next].play()
		_night_active = next

func get_time_of_day_normalized() -> float:
	return cycle_time / total_cycle

func get_phase() -> String:
	var t := cycle_time
	var dusk_start := day_duration - day_duration * transition_ratio
	var dawn_end := total_cycle - night_duration * transition_ratio
	if t < dusk_start:
		return "day"
	elif t < day_duration:
		return "dusk"
	elif t < dawn_end:
		return "night"
	else:
		return "dawn"
