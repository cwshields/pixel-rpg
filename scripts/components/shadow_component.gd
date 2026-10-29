class_name ShadowComponent
extends Sprite2D

@export var shadow_width: float = 20.0
@export var shadow_height: float = 8.0
@export var shadow_offset: Vector2 = Vector2(0, 12)

var _shader_material: ShaderMaterial

func _ready() -> void:
	var shader := preload("res://shaders/entity_shadow.gdshader")
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	material = _shader_material
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(img)
	position = shadow_offset
	scale = Vector2(shadow_width, shadow_height)
	z_index = -1
	show_behind_parent = true
