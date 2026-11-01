class_name ArrowProjectile
extends Area2D
## A fired arrow that travels in a straight line, damages the first
## hurtbox it hits, then frees itself. Spawned by PlayerBowState on release.

@export var speed: float = 200.0
@export var damage: float = 5.0
@export var knockback_force: float = 100.0
@export var max_range: float = 300.0

var direction: Vector2 = Vector2.RIGHT
var source: Node = null
var arrow_texture: Texture2D
var _distance_traveled: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func set_arrow_texture(tex: Texture2D) -> void:
	arrow_texture = tex

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	rotation = direction.angle()
	if arrow_texture and sprite:
		sprite.texture = arrow_texture

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	_distance_traveled += step
	if _distance_traveled >= max_range:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hurtbox := area as HurtboxComponent
	if source and hurtbox.get_parent() == source:
		return
	var owner_entity := hurtbox.get_parent()
	if owner_entity is EntityBase and (owner_entity as EntityBase).is_dead():
		return
	var knockback := Vector2.ZERO
	if source and source is Node2D and hurtbox.get_parent() is Node2D:
		var away: Vector2 = hurtbox.get_parent().global_position - (source as Node2D).global_position
		knockback = away.normalized() * knockback_force if away.length() > 0.0 else Vector2.ZERO
	hurtbox.receive_hit(damage, source, knockback)
	queue_free()
