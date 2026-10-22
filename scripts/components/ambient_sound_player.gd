class_name AmbientSoundPlayer
extends AudioStreamPlayer2D
## Plays a random sound from its stream (typically an AudioStreamRandomizer)
## on a recurring timer, regardless of entity state. Stops when the entity
## dies. Attach as a child of any EntityBase.

@export var interval_min: float = 5.0
@export var interval_max: float = 15.0

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)
	_timer.start(randf_range(interval_min, interval_max))
	var entity := get_parent() as EntityBase
	if entity and entity.health:
		entity.health.died.connect(func() -> void: _timer.stop())

func _on_timeout() -> void:
	play()
	_timer.start(randf_range(interval_min, interval_max))
