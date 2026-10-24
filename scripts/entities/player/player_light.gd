extends PointLight2D
## Torch-like glow attached to the player. Fades in at night, out during day.
## Flicker simulates real fire: slow energy swell, color drift toward
## orange/red, and radius breathing — all layered with randomised timing
## so it never looks mechanical.

@export var light_radius: float = 100.0:
	set(value):
		light_radius = value
		_rebuild_texture()

@export var light_energy_night: float = 1.0
@export var light_energy_day: float = 0.0
@export var fade_speed: float = 1.5

@export_group("Flicker")
@export var flicker_enabled: bool = true
@export_range(0.0, 0.5) var energy_variation: float = 0.12
@export_range(0.0, 0.15) var radius_variation: float = 0.03
@export_range(0.5, 4.0) var flicker_speed: float = 1.8
@export_range(0.0, 3.0) var position_wobble: float = 1.2
@export var color_warm: Color = Color(1.0, 0.85, 0.55)
@export var color_hot: Color = Color(1.0, 0.6, 0.35)

var _base_energy: float = 0.0
var _t: float = 0.0
var _next_gust: float = 0.0
var _gust_strength: float = 0.0
var _gust_decay: float = 0.0
var _wobble_target: Vector2 = Vector2.ZERO
var _wobble_current: Vector2 = Vector2.ZERO
var _wobble_timer: float = 0.0

func _ready() -> void:
	_rebuild_texture()
	blend_mode = PointLight2D.BLEND_MODE_ADD
	shadow_enabled = false
	color = color_warm
	_base_energy = light_energy_night if _is_night() else light_energy_day
	energy = _base_energy
	_next_gust = randf_range(1.5, 4.0)

func _process(delta: float) -> void:
	var target := light_energy_night if _is_night() else light_energy_day
	_base_energy = move_toward(_base_energy, target, fade_speed * delta)

	if not flicker_enabled or _base_energy <= 0.0:
		energy = _base_energy
		color = color_warm
		texture_scale = 1.0
		return

	_t += delta * flicker_speed

	# --- energy flicker: slow sway + medium wobble + fast jitter ---
	var sway := sin(_t * 0.7) * 0.5 + sin(_t * 1.3) * 0.3
	var wobble := sin(_t * 2.9 + 0.8) * 0.3 + sin(_t * 4.1) * 0.2
	var jitter := sin(_t * 9.7) * 0.15 + sin(_t * 14.3) * 0.1
	var flicker_val := sway + wobble + jitter

	# --- random gusts: occasional dips that decay ---
	_next_gust -= delta
	if _next_gust <= 0.0:
		_gust_strength = randf_range(0.15, 0.45)
		_gust_decay = randf_range(0.3, 0.8)
		_next_gust = randf_range(2.0, 6.0)
	_gust_strength = move_toward(_gust_strength, 0.0, delta / _gust_decay if _gust_decay > 0.0 else 1.0)

	var energy_offset := (flicker_val * energy_variation) - (_gust_strength * energy_variation * 2.0)
	energy = clampf(_base_energy + energy_offset, _base_energy * 0.55, _base_energy * 1.15)

	# --- radius: fast random pops, kept subtle ---
	var r_fast := sin(_t * 6.1) * 0.35 + sin(_t * 11.3) * 0.4 + sin(_t * 17.7) * 0.25
	var radius_factor := 1.0 + r_fast * radius_variation - _gust_strength * radius_variation
	texture_scale = clampf(radius_factor, 1.0 - radius_variation, 1.0 + radius_variation)

	# --- position wobble: drift toward random offsets ---
	_wobble_timer -= delta
	if _wobble_timer <= 0.0:
		_wobble_target = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * position_wobble
		_wobble_timer = randf_range(0.06, 0.2)
	_wobble_current = _wobble_current.lerp(_wobble_target, clampf(delta * 12.0, 0.0, 1.0))
	offset = _wobble_current

	# --- color drift: lerp toward hotter orange on bright peaks ---
	var heat := clampf(inverse_lerp(-1.0, 1.0, flicker_val), 0.0, 1.0)
	color = color_warm.lerp(color_hot, heat * 0.5 + _gust_strength * 0.3)

func _is_night() -> bool:
	var dn = get_node_or_null("/root/DayNightCycle")
	if dn:
		var phase: String = dn.get_phase()
		return phase == "night" or phase == "dusk"
	return false

func _rebuild_texture() -> void:
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.add_point(0.6, Color(1, 1, 1, 0.4))
	grad.set_offset(grad.get_point_count() - 1, 1.0)
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = int(light_radius * 2)
	tex.height = int(light_radius * 2)
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	texture = tex
	texture_scale = 1.0
