extends Node
## Plays looping ambient audio with crossfade (autoload name: "AmbientAudio").
##
## The recording has a natural fade-in and fade-out. To loop seamlessly, a
## second player starts from the beginning when the active one is OVERLAP
## seconds from the end — the new fade-in layers over the old fade-out.
##
## Runs with PROCESS_MODE_ALWAYS so it can fade audio out over 1 second
## when the tree pauses, then stream-pause the players. On unpause it
## reverses the fade.

const OVERLAP := 192.0  # 3m 12s — duration of the fade-in/out overlap
const VOLUME_DB := 2.0
const FADE_TIME := 1.0

var _stream: AudioStreamMP3
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _crossfade_point: float
var _fade_tween: Tween
var _was_paused: bool = false
var _crossfade_triggered: bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	_stream = load("res://assets/SoundFX/Woodlands/forest-wind-and-birds.mp3")
	_stream.loop = false
	var length := _stream.get_length()
	_crossfade_point = maxf(length - OVERLAP, length * 0.5)
	print("AmbientAudio: stream=%.1fs  overlap=%.1fs  crossfade_at=%.1fs" % [length, OVERLAP, _crossfade_point])

	for i in 2:
		var p := AudioStreamPlayer.new()
		p.stream = _stream
		p.volume_db = VOLUME_DB
		p.bus = &"Ambience"
		add_child(p)
		_players.append(p)

	_players[0].play()

func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		if paused:
			_fade_to_pause()
		else:
			_fade_to_resume()
		return

	if paused:
		return

	var current := _players[_active]
	if not current.playing:
		var other := 1 - _active
		if _players[other].playing:
			_active = other
		else:
			current.play()
		_crossfade_triggered = false
		return

	if current.get_playback_position() < _crossfade_point:
		_crossfade_triggered = false
	elif not _crossfade_triggered:
		_crossfade_triggered = true
		var next := 1 - _active
		_players[next].play()
		_active = next

func _fade_to_pause() -> void:
	_kill_fade()
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for p in _players:
		_fade_tween.parallel().tween_property(p, "volume_db", -80.0, FADE_TIME)
	_fade_tween.tween_callback(_stream_pause.bind(true))

func _fade_to_resume() -> void:
	for p in _players:
		p.volume_db = VOLUME_DB - 20.0
	_stream_pause(false)
	_kill_fade()
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for p in _players:
		_fade_tween.parallel().tween_property(p, "volume_db", VOLUME_DB, 0.25)

func _stream_pause(paused: bool) -> void:
	for p in _players:
		p.stream_paused = paused

func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
