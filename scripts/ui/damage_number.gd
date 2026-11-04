class_name DamageNumber
extends Label

const FLOAT_SPEED := 30.0
const DURATION := 0.7
const SPREAD := 8.0
const CRIT_FLOAT_SPEED := 22.0
const CRIT_DURATION := 0.9

var _timer: float = 0.0
var _float_speed: float = FLOAT_SPEED
var _duration: float = DURATION

func _ready() -> void:
	z_index = 100
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 8)
	add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	add_theme_constant_override("outline_size", 2)
	pivot_offset = size * 0.5
	position.x += randf_range(-SPREAD, SPREAD)

func _process(delta: float) -> void:
	_timer += delta
	var t := _timer / _duration
	position.y -= _float_speed * delta
	modulate.a = 1.0 - ease(t, 2.0)
	var pop := 1.0 + 0.3 * (1.0 - ease(minf(t * 3.0, 1.0), 2.0))
	scale = Vector2(pop, pop)
	if t >= 1.0:
		queue_free()

static func spawn(entity: Node2D, amount: float, is_crit: bool = false) -> void:
	if not GameManager.show_damage_numbers:
		return
	var scene_root := entity.get_tree().current_scene
	var pos := entity.global_position + Vector2(0, -12)

	var label := DamageNumber.new()
	label.text = str(roundi(amount))
	if is_crit:
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		label.add_theme_font_size_override("font_size", 10)
	scene_root.add_child(label)
	label.global_position = pos

	if is_crit:
		var crit_label := DamageNumber.new()
		crit_label.text = "Critical!"
		crit_label._float_speed = CRIT_FLOAT_SPEED
		crit_label._duration = CRIT_DURATION
		crit_label.add_theme_font_size_override("font_size", 6)
		crit_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
		scene_root.add_child(crit_label)
		crit_label.global_position = pos + Vector2(0, -8)
