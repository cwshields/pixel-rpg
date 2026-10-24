class_name Fireflies
extends Node2D
## Spawns tiny glowing lights that drift and blink during nighttime.
## Place one in the world and set spawn_area to define the region.

@export_group("Spawn")
@export var count: int = 12
@export var spawn_area: Vector2 = Vector2(200, 120)

@export_group("Light")
@export var light_color: Color = Color(0.981, 0.896, 0.509, 1.0)
@export var light_radius: float = 20.0
@export var light_energy_max: float = 0.5
@export var pixel_color: Color = Color(1.0, 0.995, 0.426, 1.0)

@export_group("Pulse")
@export var pulse_period_min: float = 2.0
@export var pulse_period_max: float = 4.5
@export var off_time_min: float = 1.0
@export var off_time_max: float = 3.0

@export_group("Movement")
@export var drift_speed: float = 8.0
@export var direction_change_time: float = 1.5

@export_group("Day/Night")
@export var fade_speed: float = 1.0

var _bugs: Array[Dictionary] = []
var _group_alpha: float = 0.0
var _light_tex: GradientTexture2D
var _pixel_tex: ImageTexture

func _ready() -> void:
	_light_tex = _build_texture()
	_pixel_tex = _build_pixel_texture()
	for i in count:
		_spawn_bug()

func _process(delta: float) -> void:
	var target_alpha := 1.0 if _is_night() else 0.0
	_group_alpha = move_toward(_group_alpha, target_alpha, fade_speed * delta)

	for bug in _bugs:
		_tick_bug(bug, delta)

func _spawn_bug() -> void:
	var light := PointLight2D.new()
	light.texture = _light_tex
	light.texture_scale = 1.0
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	light.shadow_enabled = false
	light.color = light_color
	light.energy = 0.0
	light.position = _random_point()
	add_child(light)

	var pixel := Sprite2D.new()
	pixel.texture = _pixel_tex
	pixel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel.self_modulate = pixel_color
	pixel.modulate.a = 0.0
	light.add_child(pixel)

	var bug := {
		"node": light,
		"pixel": pixel,
		"phase": randf() * TAU,
		"period": randf_range(pulse_period_min, pulse_period_max),
		"off_timer": randf_range(0.0, off_time_max),
		"glowing": false,
		"drift_dir": Vector2.from_angle(randf() * TAU),
		"dir_timer": randf_range(0.0, direction_change_time),
	}
	_bugs.append(bug)

func _tick_bug(bug: Dictionary, delta: float) -> void:
	var light: PointLight2D = bug["node"]

	# --- drift ---
	bug["dir_timer"] -= delta
	if bug["dir_timer"] <= 0.0:
		bug["drift_dir"] = Vector2.from_angle(randf() * TAU)
		bug["dir_timer"] = randf_range(direction_change_time * 0.5, direction_change_time * 1.5)

	light.position += bug["drift_dir"] * drift_speed * delta

	var half := spawn_area * 0.5
	if light.position.x < -half.x or light.position.x > half.x \
		or light.position.y < -half.y or light.position.y > half.y:
		bug["drift_dir"] = (Vector2.ZERO - light.position).normalized()
		bug["dir_timer"] = randf_range(0.5, 1.5)

	# --- pulse ---
	var pixel: Sprite2D = bug["pixel"]

	if not bug["glowing"]:
		bug["off_timer"] -= delta
		if bug["off_timer"] <= 0.0:
			bug["glowing"] = true
			bug["phase"] = 0.0
			bug["period"] = randf_range(pulse_period_min, pulse_period_max)
		light.energy = 0.0
		pixel.modulate.a = 0.0
		return

	bug["phase"] += delta / bug["period"] * TAU
	if bug["phase"] >= TAU:
		bug["glowing"] = false
		bug["off_timer"] = randf_range(off_time_min, off_time_max)
		light.energy = 0.0
		pixel.modulate.a = 0.0
		return

	var glow := maxf(sin(bug["phase"]), 0.0)
	light.energy = glow * light_energy_max * _group_alpha
	pixel.modulate.a = glow * _group_alpha

func _random_point() -> Vector2:
	return Vector2(
		randf_range(-spawn_area.x * 0.5, spawn_area.x * 0.5),
		randf_range(-spawn_area.y * 0.5, spawn_area.y * 0.5),
	)

func _is_night() -> bool:
	var dn := get_node_or_null("/root/DayNightCycle")
	if dn:
		var phase: String = dn.get_phase()
		return phase == "night" or phase == "dusk"
	return false

func _build_pixel_texture() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _build_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.add_point(0.5, Color(1, 1, 1, 0.5))
	grad.set_offset(grad.get_point_count() - 1, 1.0)
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = int(light_radius * 2)
	tex.height = int(light_radius * 2)
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
