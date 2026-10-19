@tool
class_name RockProp
extends BreakableProp
## A single rock/boulder prop — body collision, mining damage scaling, and a
## shrink-fade death animation on top of BreakableProp's shared depth-sort,
## occlusion-fade, art application, and combat feedback.
##
## Rock variations live as inherited scenes in `VARIANT_DIR`
## (`scenes/world/rocks/`), each setting its own sprite and collision shape
## directly on the child nodes.

const VARIANT_DIR := "res://scenes/world/rocks/"

const _DEFAULT_COLLISION_SIZE := Vector2(16, 10)
const _DEFAULT_COLLISION_OFFSET := Vector2(0, -5)

@export_tool_button("Randomize Variant") var _randomize_variant_button = _randomize_variant

@export_group("Collision")
## When false the StaticBody2D's shape is disabled.
@export var collision_enabled: bool = true:
	set(value):
		collision_enabled = value
		_apply_collision()
## Explicit collision outline. When non-empty, the CollisionPolygon2D
## uses these points directly.
@export var collision_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		collision_polygon = value
		_apply_collision()
@export var collision_size: Vector2 = _DEFAULT_COLLISION_SIZE:
	set(value):
		collision_size = value
		_apply_collision()
@export var collision_offset: Vector2 = _DEFAULT_COLLISION_OFFSET:
	set(value):
		collision_offset = value
		_apply_collision()

@export_group("Combat")
## Flat damage non-mining hits deal. Mining (crush) hits deal full weapon
## damage; everything else is clamped to this fixed value.
@export var swing_damage: float = 0.5
## Mining hits are scaled by this factor so rocks take several pickaxe
## swings to break rather than melting instantly.
@export var mining_damage_scale: float = 0.4

func _init() -> void:
	art_offset = Vector2(0, -24)
	_hit_particle_color = Color(0.72, 0.66, 0.56)
	_break_fragment_color = Color(0.65, 0.6, 0.5)

func _randomize_variant() -> void:
	swap_for_random_variant(VARIANT_DIR)

func _apply_body_collision() -> void:
	_apply_collision()

## Applies the Collision overrides. With no overrides set, the shipped
## polygon in `rock.tscn` is left untouched.
func _apply_collision() -> void:
	var poly_node: CollisionPolygon2D = get_node_or_null("StaticBody2D/CollisionPolygon2D")
	if poly_node == null:
		return

	if not collision_polygon.is_empty():
		poly_node.polygon = collision_polygon
		poly_node.position = collision_offset
		poly_node.disabled = false
		return

	poly_node.disabled = not collision_enabled
	if collision_size != _DEFAULT_COLLISION_SIZE or collision_offset != _DEFAULT_COLLISION_OFFSET:
		poly_node.position = collision_offset
		var half := collision_size * 0.5
		poly_node.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		])

var _last_hit_was_mining: bool = false

func filter_incoming_damage(amount: float, _source: Node, hitbox: HitboxComponent) -> float:
	_last_hit_was_mining = hitbox == null or hitbox.is_mining
	if _last_hit_was_mining:
		return amount * mining_damage_scale
	return swing_damage

func _on_damaged(amount: float, source: Node) -> void:
	if _last_hit_was_mining:
		_shake(amount)
	_emit_hit_particles(source)

func _animate_death() -> void:
	if sprite:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tween.tween_property(sprite, "scale", sprite.scale * 0.6, 0.25).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
	else:
		queue_free()
