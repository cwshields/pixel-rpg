class_name HUD
extends CanvasLayer
## Always-on-screen UI. The bottom bar art (Hotbar-UI-final.png) has the
## health / stamina / mana fills painted straight into it; the shader on
## %BarArt erases them as those pools drain. This script only ever feeds
## that shader a 0..1 ratio per pool — it never touches the texture.
##
## Hovering the health / stamina bar or the mana orb pops a "cur/max"
## readout centred in it. The hover targets are sized from the same
## art-pixel regions the shader fills, so they track the art even if
## BarArt is rescaled.
##
## Listens on Events rather than holding a player reference so it survives
## the player respawning / being reassigned. On player_spawned it seeds the
## pools straight off the new player's components, since those emit their
## initial value before GameManager.player is set (so the bus broadcast is
## dropped) and a full pool never emits again on its own. Mana has no
## backing system yet: until something emits mana_changed the shader keeps
## its default (full) and the readout shows the placeholder 1/1.

# Bar-fill regions in source-art pixels (Hotbar-UI-final.png is 256x41),
# mirrored from shaders/hotbar_gauges.gdshader (HEALTH_X/Y, STAMINA_X/Y,
# MANA_X / MANA_TOP_BOTTOM).
const ART_SIZE := Vector2(256.0, 41.0)
const HEALTH_REGION := Rect2(76.0, 10.0, 56.0, 8.0)
const STAMINA_REGION := Rect2(122.0, 9.0, 56.0, 10.0)
const MANA_REGION := Rect2(110.0, 11.0, 33.0, 27.0)

@onready var _bar_mat: ShaderMaterial = (%BarArt as TextureRect).material as ShaderMaterial

# (current, max) per pool; max 0 is treated as empty to avoid div-by-zero.
var _health := Vector2(1.0, 1.0)
var _stamina := Vector2(1.0, 1.0)
var _mana := Vector2(1.0, 1.0)

var _health_readout: Label
var _stamina_readout: Label
var _mana_readout: Label

func _ready() -> void:
	_health_readout = _build_readout(HEALTH_REGION, func() -> Vector2: return _health)
	_stamina_readout = _build_readout(STAMINA_REGION, func() -> Vector2: return _stamina)
	_mana_readout = _build_readout(MANA_REGION, func() -> Vector2: return _mana)
	Events.health_changed.connect(_on_health_changed)
	Events.stamina_changed.connect(_on_stamina_changed)
	Events.mana_changed.connect(_on_mana_changed)
	Events.player_spawned.connect(_on_player_spawned)
	_push(&"health_fill", _health)
	_push(&"stamina_fill", _stamina)
	_push(&"mana_fill", _mana)
	if GameManager.player:
		_on_player_spawned(GameManager.player)

## Seed the pools from the freshly registered player. Its HealthComponent /
## StaminaComponent broadcast their starting value from _ready(), before
## register_player() runs, so the HUD never hears that first emit and a
## brimming pool stays silent afterwards — leaving the readout stuck on 1/1.
func _on_player_spawned(player: Node) -> void:
	var entity := player as EntityBase
	if entity and entity.health:
		_on_health_changed(player, entity.health.current_health, entity.health.max_health)
	var pl := player as Player
	if pl and pl.stamina:
		_on_stamina_changed(player, pl.stamina.current_stamina, pl.stamina.max_stamina)

func _on_health_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_health = Vector2(current, max_value)
		_push(&"health_fill", _health)
		_refresh_readout(_health_readout, _health)

func _on_stamina_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_stamina = Vector2(current, max_value)
		_push(&"stamina_fill", _stamina)
		_refresh_readout(_stamina_readout, _stamina)

func _on_mana_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_mana = Vector2(current, max_value)
		_push(&"mana_fill", _mana)
		_refresh_readout(_mana_readout, _mana)

func _push(param: StringName, cur_max: Vector2) -> void:
	var ratio := 0.0 if cur_max.y <= 0.0 else clampf(cur_max.x / cur_max.y, 0.0, 1.0)
	_bar_mat.set_shader_parameter(param, ratio)

## Invisible hover target over `region` (art px) with a hidden centred
## Label child; `getter` returns the (current, max) to display. Returns
## the Label so the *_changed handlers can keep it live while shown.
func _build_readout(region: Rect2, getter: Callable) -> Label:
	var hot := Control.new()
	hot.anchor_left = region.position.x / ART_SIZE.x
	hot.anchor_right = region.end.x / ART_SIZE.x
	hot.anchor_top = region.position.y / ART_SIZE.y
	hot.anchor_bottom = region.end.y / ART_SIZE.y
	hot.offset_left = 0.0
	hot.offset_top = 0.0
	hot.offset_right = 0.0
	hot.offset_bottom = 0.0
	hot.mouse_filter = Control.MOUSE_FILTER_STOP

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_contents = false
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.hide()
	hot.add_child(lbl)

	(%BarArt as TextureRect).add_child(hot)
	hot.mouse_entered.connect(func() -> void:
		lbl.text = _fmt(getter.call())
		lbl.show())
	hot.mouse_exited.connect(func() -> void: lbl.hide())
	return lbl

func _refresh_readout(lbl: Label, cur_max: Vector2) -> void:
	if lbl and lbl.visible:
		lbl.text = _fmt(cur_max)

func _fmt(cur_max: Vector2) -> String:
	return "%d/%d" % [roundi(cur_max.x), roundi(cur_max.y)]
