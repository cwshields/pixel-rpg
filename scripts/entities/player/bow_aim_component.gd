class_name BowAimComponent
extends Sprite2D
## Renders the equipped bow hovering around the player, always pointing
## its handle toward the mouse cursor. Tracks draw state: idle → drawing
## → fully drawn. The bow sprite uses the weapon's icon/swing_sprite and
## shows the draw progression via a subtle scale pulse.

## Radius (pixels) the bow orbits around the player center.
@export var orbit_radius: float = 14.0
## How quickly the bow catches up to the target angle (higher = snappier).
@export var rotation_speed: float = 12.0
## Seconds of holding before the bow transitions to "fully drawn."
@export var draw_time: float = 1.0

enum DrawState { IDLE, DRAWING, FULLY_DRAWN }

var draw_state: DrawState = DrawState.IDLE
var _draw_timer: float = 0.0
var _target_angle: float = 0.0
var _current_angle: float = 0.0

func setup(bow_texture: Texture2D) -> void:
	texture = bow_texture
	draw_state = DrawState.IDLE
	_draw_timer = 0.0
	visible = false

func teardown() -> void:
	visible = false
	texture = null
	draw_state = DrawState.IDLE
	_draw_timer = 0.0

func start_draw() -> void:
	draw_state = DrawState.DRAWING
	_draw_timer = 0.0

func stop_draw() -> void:
	draw_state = DrawState.IDLE
	_draw_timer = 0.0
	scale = Vector2.ONE

func is_fully_drawn() -> bool:
	return draw_state == DrawState.FULLY_DRAWN

func get_aim_direction() -> Vector2:
	return Vector2.from_angle(_current_angle)

func _process(delta: float) -> void:
	if not visible or texture == null:
		return
	var parent := get_parent() as Node2D
	if not parent:
		return
	var mouse_pos := parent.get_global_mouse_position()
	_target_angle = (mouse_pos - parent.global_position).angle()
	_current_angle = lerp_angle(_current_angle, _target_angle, minf(rotation_speed * delta, 1.0))
	position = Vector2.from_angle(_current_angle) * orbit_radius
	rotation = _current_angle + PI
	var pointing_left := absf(_current_angle) > PI / 2.0
	flip_h = pointing_left
	if draw_state == DrawState.DRAWING:
		_draw_timer += delta
		var draw_progress := clampf(_draw_timer / draw_time, 0.0, 1.0)
		scale = Vector2.ONE * lerpf(1.0, 1.15, draw_progress)
		if _draw_timer >= draw_time:
			draw_state = DrawState.FULLY_DRAWN
			scale = Vector2.ONE * 1.15
