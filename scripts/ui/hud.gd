class_name HUD
extends CanvasLayer
## Always-on-screen UI. The bottom bar art (Hotbar-UI-final.png) has the
## health / stamina / mana fills painted straight into it; the shader on
## %BarArt erases them as those pools drain. This script only ever feeds
## that shader a 0..1 ratio per pool — it never touches the texture.
##
## Listens on Events rather than holding a player reference so it survives
## the player respawning / being reassigned. Stamina and mana have no
## backing system yet: until something emits those signals the shader
## keeps its default (full).

@onready var _bar_mat: ShaderMaterial = (%BarArt as TextureRect).material as ShaderMaterial

# (current, max) per pool; max 0 is treated as empty to avoid div-by-zero.
var _health := Vector2(1.0, 1.0)
var _stamina := Vector2(1.0, 1.0)
var _mana := Vector2(1.0, 1.0)

func _ready() -> void:
	Events.health_changed.connect(_on_health_changed)
	Events.stamina_changed.connect(_on_stamina_changed)
	Events.mana_changed.connect(_on_mana_changed)
	_push(&"health_fill", _health)
	_push(&"stamina_fill", _stamina)
	_push(&"mana_fill", _mana)

func _on_health_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_health = Vector2(current, max_value)
		_push(&"health_fill", _health)

func _on_stamina_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_stamina = Vector2(current, max_value)
		_push(&"stamina_fill", _stamina)

func _on_mana_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_mana = Vector2(current, max_value)
		_push(&"mana_fill", _mana)

func _push(param: StringName, cur_max: Vector2) -> void:
	var ratio := 0.0 if cur_max.y <= 0.0 else clampf(cur_max.x / cur_max.y, 0.0, 1.0)
	_bar_mat.set_shader_parameter(param, ratio)
