@tool
class_name TreeProp
extends BreakableProp
## A single tree prop — canopy sway, trunk collision, and a fall-over death
## animation on top of BreakableProp's shared depth-sort, occlusion-fade,
## art application, and combat feedback.
##
## Tree variations live as inherited scenes in `VARIANT_DIR`
## (`scenes/world/trees/`), each setting its own sprite and collision
## shapes directly on the child nodes. The Art / Trunk / Fade / Hover
## exports are the older per-instance override path.

const VARIANT_DIR := "res://scenes/world/trees/"

const _DEFAULT_TRUNK_SIZE := Vector2(9, 8)
const _DEFAULT_TRUNK_OFFSET := Vector2(0.5, -4)

static var _trunk_shape_cache: Dictionary = {}

@export_group("Art")
## When false the canopy wind ShaderMaterial is stripped — for stumps and
## other static props that shouldn't sway.
@export var swaying: bool = true:
	set(value):
		swaying = value
		_apply_art()

@export_tool_button("Randomize Variant") var _randomize_variant_button = _randomize_variant

@export_group("Trunk Collision")
## When false the trunk StaticBody2D's shape is disabled.
@export var trunk_enabled: bool = true:
	set(value):
		trunk_enabled = value
		_apply_trunk()
## Explicit trunk collision outline. When non-empty, the CollisionShape2D
## becomes a ConvexPolygonShape2D with these points.
@export var trunk_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		trunk_polygon = value
		_apply_trunk()
@export var trunk_size: Vector2 = _DEFAULT_TRUNK_SIZE:
	set(value):
		trunk_size = value
		_apply_trunk()
@export var trunk_offset: Vector2 = _DEFAULT_TRUNK_OFFSET:
	set(value):
		trunk_offset = value
		_apply_trunk()

@export_group("Combat")
## Damage multiplier for non-chopping hits (sword swings etc.). Chop hits
## deal full damage; everything else is scaled so weapon stats don't
## shortcut the per-size hit counts set by HealthComponent.max_health.
@export var swing_damage_scale: float = 0.5

func _init() -> void:
	art_offset = Vector2(0, -56)
	_hit_particle_color = Color(0.42, 0.55, 0.28)
	_break_fragment_color = Color(0.35, 0.52, 0.22)

func _randomize_variant() -> void:
	swap_for_random_variant(VARIANT_DIR)

func _post_apply_art(s: Sprite2D) -> void:
	if not swaying and s.material != null:
		s.material = null

func _apply_body_collision() -> void:
	_apply_trunk()

## Applies the Trunk overrides. With no overrides set, the shipped
## rectangle in `tree.tscn` is left completely untouched.
func _apply_trunk() -> void:
	var shape_node: CollisionShape2D = get_node_or_null("StaticBody2D/CollisionShape2D")
	if shape_node == null:
		return

	if not trunk_polygon.is_empty():
		var key := var_to_str(trunk_polygon)
		var poly: ConvexPolygonShape2D = _trunk_shape_cache.get(key)
		if poly == null:
			poly = ConvexPolygonShape2D.new()
			poly.points = trunk_polygon
			_trunk_shape_cache[key] = poly
		if shape_node.shape != poly:
			shape_node.shape = poly
		shape_node.position = trunk_offset
		shape_node.disabled = false
		return

	shape_node.disabled = not trunk_enabled
	if trunk_size != _DEFAULT_TRUNK_SIZE or trunk_offset != _DEFAULT_TRUNK_OFFSET:
		shape_node.position = trunk_offset
		var rect := RectangleShape2D.new()
		rect.size = trunk_size
		shape_node.shape = rect

func filter_incoming_damage(amount: float, _source: Node, hitbox: HitboxComponent) -> float:
	if hitbox == null or hitbox.is_chopping:
		return amount
	return amount * swing_damage_scale

func _animate_death() -> void:
	if sprite:
		if _shake_tween and _shake_tween.is_valid():
			_shake_tween.kill()
			sprite.position = _sprite_rest_pos
		var fall_dir := 1.0 if randf() < 0.5 else -1.0
		if sprite.texture:
			var half_h := sprite.texture.get_size().y * 0.5
			sprite.offset.y = -half_h
			sprite.position.y += half_h
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "rotation", fall_dir * deg_to_rad(80.0), 1.2) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(sprite, "position:x",
				sprite.position.x + fall_dir * 12.0, 1.2) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.4).set_delay(0.85)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
	else:
		queue_free()
