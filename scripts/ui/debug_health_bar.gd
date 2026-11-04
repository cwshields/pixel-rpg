extends Node2D
## Tiny health bar drawn above an entity via _draw(). Created and managed
## by DebugPanel's "Show Health Bars" toggle — not meant for production UI.

const BAR_WIDTH: float = 32.0
const BAR_HEIGHT: float = 6.0
const OFFSET_Y: float = -24.0
const BG_COLOR: Color = Color(0.15, 0.15, 0.15, 0.85)
const FILL_COLOR: Color = Color(0.2, 0.75, 0.2, 0.9)
const LOW_COLOR: Color = Color(0.85, 0.2, 0.2, 0.9)
const BORDER_COLOR: Color = Color(0.0, 0.0, 0.0, 0.9)
const FONT_SIZE: int = 7

var _health: HealthComponent
var _font: Font

func _ready() -> void:
	position = Vector2(0.0, OFFSET_Y)
	z_index = 100
	var entity := get_parent()
	if entity is EntityBase:
		_health = entity.health
	if _health:
		_health.health_changed.connect(func(_c: float, _m: float) -> void: queue_redraw())
	_font = ThemeDB.fallback_font
	queue_redraw()

func _draw() -> void:
	if not _health:
		return
	var ratio: float = _health.current_health / maxf(_health.max_health, 1.0)
	var x0: float = -BAR_WIDTH * 0.5
	var bg_rect := Rect2(x0, 0.0, BAR_WIDTH, BAR_HEIGHT)
	var fill_rect := Rect2(x0, 0.0, BAR_WIDTH * ratio, BAR_HEIGHT)
	var color: Color = FILL_COLOR if ratio > 0.3 else LOW_COLOR
	draw_rect(bg_rect, BG_COLOR)
	draw_rect(fill_rect, color)
	draw_rect(bg_rect, BORDER_COLOR, false, 1.0)
	var text := "%d/%d" % [ceili(_health.current_health), ceili(_health.max_health)]
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE)
	var text_pos := Vector2(-text_size.x * 0.5, BAR_HEIGHT * 0.5 + text_size.y * 0.25)
	draw_string(_font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE, Color.WHITE)
