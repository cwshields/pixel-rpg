@tool
class_name TreeProp
extends OccluderProp
## A single tree prop with two effects tied to the player's position, both
## keyed off the same `FadeArea` (a hand-shaped trunk+canopy outline, see
## the Occlusion Fade group below) rather than two separate approximations
## that could disagree with each other:
## 1. Depth sort — the tree draws in front of the player (instead of
##    behind, as normal) once the player's feet are at or above the tree's
##    own Y, OR the player is still physically overlapping `FadeArea` —
##    the latter covers the moment the player is blocked against the
##    trunk's collision, where the feet-offset compare point (see
##    `player_feet_offset`) can already read as past the tree's Y even
##    though the player hasn't actually walked past it. Relying on real
##    overlap here (rather than a flat pixel margin) means the tree flips
##    back the instant the player actually leaves the area — not several
##    pixels later regardless of whether they're even still nearby.
## 2. Occlusion fade — while standing inside `FadeArea`, the tree eases
##    toward `faded_alpha` so it doesn't fully hide the player. Since
##    `FadeArea` is a real Area2D overlap check, not a distance estimate,
##    it only fades exactly where the art would actually hide the player,
##    tuned tree by tree — and, sharing the same signal as the depth sort
##    above, the two effects can never disagree about where "behind the
##    tree" ends.
##
## The depth-sort flip runs on a timer, not per-node-per-frame: the tree
## registers itself with the `Foliage` autoload on entering the scene, and
## Foliage calls `update_proximity()` each frame ONLY while the player is
## within its activation radius — a tree on the far side of the map costs
## nothing. `FadeArea` overlap itself is tracked via its body_entered/exited
## signals rather than recomputed per frame, so it costs nothing until the
## player actually crosses into it. Dropping a Tree anywhere in the world
## (regardless of what it's parented under) is still all that's required.
##
## Tree variations live as inherited scenes in `VARIANT_DIR`
## (`scenes/world/trees/`), each setting its own sprite and collision
## shapes directly on the child nodes. Place trees by instancing those —
## editing a variant scene's shapes once updates every tree that uses it.
## The Art / Trunk / Fade / Hover exports below are the older per-instance
## override path (only a few one-off trees still use it).
##
## The script is `@tool` so those overrides preview live in the editor and
## the "Randomize Variant" button works. The player-relative effects never
## run in the editor (guarded by `Engine.is_editor_hint()`).
##
## Extends `OccluderProp` purely for typing — `RockProp` (rock.gd) is the
## other implementation, sharing nothing but the interface and the Foliage
## registration.

## Folder of tree variant scenes (each inherits tree.tscn) that "Randomize
## Variant" picks from.
const VARIANT_DIR := "res://scenes/world/trees/"

const _DEFAULT_TRUNK_SIZE := Vector2(9, 8)
const _DEFAULT_TRUNK_OFFSET := Vector2(0.5, -4)

# Shared across every TreeProp in the session so 100+ converted trees that
# draw from the same sheet region (or share a trunk outline) reuse one
# resource instead of each allocating (and serialising) its own.
static var _atlas_cache: Dictionary = {}
static var _trunk_shape_cache: Dictionary = {}

@export_group("Depth Sorting")
## Vertical distance from the player's node origin down to their visual
## feet. The player's AnimatedSprite2D is centered on the node origin
## (not anchored at the feet), so this corrects for that when comparing
## "who's lower on the grid" — without it the compare point would be the
## player's torso, and the tree would seem to switch in front/behind too
## early or late.
@export var player_feet_offset: float = 18.0

@export_group("Occlusion Fade")
## Alpha the tree eases down to while the player is inside `FadeArea`.
## 1.0 = never fades, 0.0 = fully invisible. 0.5 = 50% transparent,
## matching "trees go about 50% transparent" — this is the
## maximum-transparency value.
@export_range(0.0, 1.0) var faded_alpha: float = 0.5
## How fast the alpha eases toward its target, in alpha-units/second
## (e.g. 6.0 = a full 0↔1 fade takes about 1/6th of a second).
@export var fade_speed: float = 4.0
## Explicit outline (points relative to the node origin) for `FadeArea`,
## the overlap check that drives the occlusion fade above — hugging the
## trunk plus whatever part of the canopy actually hides the player,
## instead of a simple box that fades even where the art wouldn't hide
## anyone. When non-empty this wins over the auto-sized rectangle.
##
## For a plain hand-placed tree, you don't need this at all — just select
## FadeArea/CollisionPolygon2D and edit its Polygon directly with Godot's
## built-in polygon tool in the 2D viewport; `_apply_fade_shape()` never
## touches that node unless `art_texture` is set or this array changes, so
## a hand-edited plain tree keeps its shape. Use this field for converted
## trees (`art_texture` set programmatically), where a custom outline
## would otherwise get overwritten the next time the art re-applies —
## same reasoning as `trunk_polygon`/`hover_polygon` above/below.
@export var fade_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		fade_polygon = value
		_apply_fade_shape()

@export_group("Art")
## Sprite sheet to draw this tree from. Leave null to keep whatever
## `tree.tscn` ships with — existing hand-placed trees set nothing here and
## are completely unaffected. The painted-tree converter sets this per
## instance to the matching tileset sheet (`res://Tilesets/Size_0X.png`).
@export var art_texture: Texture2D = null:
	set(value):
		art_texture = value
		_apply_art()
## Region (px) of `art_texture` to show. Zero size = use the whole texture.
@export var art_region: Rect2i = Rect2i():
	set(value):
		art_region = value
		_apply_art()
## Sprite2D local position. The node origin sits at the trunk foot, so this
## is normally negative Y (canopy rises above the base). Default matches
## `tree.tscn`'s built-in sprite.
@export var art_offset: Vector2 = Vector2(0, -56):
	set(value):
		art_offset = value
		_apply_art()
## When false the canopy wind ShaderMaterial is stripped — used for stumps
## and other static props that shouldn't sway.
@export var swaying: bool = true:
	set(value):
		swaying = value
		_apply_art()

## Inspector button: swaps this tree for an instance of a different,
## randomly picked variant scene from `VARIANT_DIR`, keeping its name,
## transform and place in the parent. Undoable with Ctrl+Z. The pick only
## ever happens when you press the button — never in `_ready()` — so the
## editor and the running game can never disagree about which one a tree
## ended up with. Adding a variation is just saving another inherited scene
## into that folder.
@export_tool_button("Randomize Variant") var _randomize_variant_button = _randomize_variant

@export_group("Trunk Collision")
## When false the trunk StaticBody2D's shape is disabled, so the tree is
## purely visual. Ignored when `trunk_polygon` is set.
@export var trunk_enabled: bool = true:
	set(value):
		trunk_enabled = value
		_apply_trunk()
## Explicit trunk collision outline (points relative to `trunk_offset`).
## When non-empty this wins: the CollisionShape2D becomes a
## ConvexPolygonShape2D with these points. The converter fills it from each
## tileset tree tile's own physics polygon so converted trees keep exactly
## the collision they had as tiles.
@export var trunk_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		trunk_polygon = value
		_apply_trunk()
## Trunk collision box size. Only applied when it differs from the default
## and `trunk_polygon` is empty.
@export var trunk_size: Vector2 = _DEFAULT_TRUNK_SIZE:
	set(value):
		trunk_size = value
		_apply_trunk()
## Trunk collision offset from the node origin (also the origin the
## `trunk_polygon` points are measured from).
@export var trunk_offset: Vector2 = _DEFAULT_TRUNK_OFFSET:
	set(value):
		trunk_offset = value
		_apply_trunk()

@export_group("Hover Area (Cursor)")
## Explicit outline (points relative to the node origin) for the
## cursor-only HoverArea, letting a tree's "cut" hover region hug an
## irregular canopy instead of the sprite's rectangular bounding box.
## When non-empty this wins over the auto-sized rectangle.
##
## For a plain hand-placed tree, you don't need this at all — just select
## HoverArea/CollisionPolygon2D and edit its Polygon directly with
## Godot's built-in polygon tool in the 2D viewport; `_apply_hover_shape()`
## never touches that node unless `art_texture` is set or this array
## changes, so a hand-edited plain tree keeps its shape. Use this field
## for converted trees (`art_texture` set programmatically), where a
## custom outline would otherwise get overwritten the next time the art
## re-applies — same reasoning as `trunk_polygon` above.
@export var hover_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		hover_polygon = value
		_apply_hover_shape()

@export_group("Combat")
@export var loot_table: Array[LootEntry] = []
## Explicit outline (points relative to the node origin) for the
## HurtboxComponent's hit region — same idea as `hover_polygon`.
@export var hurt_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		hurt_polygon = value
		_apply_hurt_shape()

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var health: HealthComponent = get_node_or_null("HealthComponent")
@onready var fade_area: Area2D = get_node_or_null("FadeArea")

var _target_alpha: float = 1.0
var _active: bool = false
## Whether the player's physical body currently overlaps `FadeArea`. Kept
## in sync by `_on_fade_area_body_entered/exited` (real overlap signals),
## not recomputed per frame — see `update_proximity()`.
var _player_in_fade_area: bool = false
var _shake_tween: Tween
var _sprite_rest_pos: Vector2
var _hit_particles: CPUParticles2D

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	Foliage.register_prop(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	Foliage.unregister_prop(self)

func _ready() -> void:
	z_index = PLAYER_Z_INDEX - 1
	_apply_art()
	_apply_trunk()
	if not Engine.is_editor_hint() and health:
		health.died.connect(_on_died)
		health.damaged.connect(_on_damaged)
	if not Engine.is_editor_hint():
		_setup_hit_particles()
	if not Engine.is_editor_hint() and fade_area:
		fade_area.body_entered.connect(_on_fade_area_body_entered)
		fade_area.body_exited.connect(_on_fade_area_body_exited)

## `FadeArea` (collision_mask 1, "Solid bodies") reports the player's
## physical CharacterBody2D directly — filtered against `GameManager.player`
## rather than a group, since nothing else on layer 1 should trigger the
## fade (an enemy walking behind a tree still reads fine without it).
func _on_fade_area_body_entered(body: Node) -> void:
	if body == GameManager.player:
		_player_in_fade_area = true

func _on_fade_area_body_exited(body: Node) -> void:
	if body == GameManager.player:
		_player_in_fade_area = false

## "Randomize Variant" button target — see OccluderProp.swap_for_random_variant.
func _randomize_variant() -> void:
	swap_for_random_variant(VARIANT_DIR)

## Rebuilds the Sprite2D from the Art overrides. No-op when `art_texture`
## is unset, so a plain `tree.tscn` instance keeps its shipped sprite.
func _apply_art() -> void:
	if art_texture == null:
		return
	var s: Sprite2D = get_node_or_null("Sprite2D")
	if s == null:
		return

	if art_region.size != Vector2i.ZERO:
		var key := "%s:%s" % [art_texture.get_rid(), art_region]
		var atlas: AtlasTexture = _atlas_cache.get(key)
		if atlas == null:
			atlas = AtlasTexture.new()
			atlas.atlas = art_texture
			atlas.region = Rect2(art_region)
			_atlas_cache[key] = atlas
		if s.texture != atlas:
			s.texture = atlas
	elif s.texture != art_texture:
		s.texture = art_texture

	if s.position != art_offset:
		s.position = art_offset
	if not swaying and s.material != null:
		s.material = null

	_apply_hover_shape()
	_apply_hurt_shape()
	_apply_fade_shape()

## Applies the Hover Area overrides. Only called from `_apply_art()`
## (i.e. only when `art_texture` is set) and from the `hover_polygon`
## setter — never unconditionally from `_ready()` — so a plain
## `tree.tscn` instance's CollisionPolygon2D is never touched and safely
## keeps whatever outline you hand-draw for it in the editor.
##
## With `hover_polygon` set, the cursor-only HoverArea's CollisionPolygon2D
## traces that outline directly. Otherwise it falls back to a rectangle
## auto-sized to the current sprite's bounding box, so the "cut" hover
## cursor tracks the visible canopy instead of the trunk's much smaller
## physical collision box. HoverArea has no collision_mask and isn't on
## the physical-solids layer, so neither shape ever blocks player/enemy
## movement — see the collision layer legend in README.md.
func _apply_hover_shape() -> void:
	var poly_node: CollisionPolygon2D = get_node_or_null("HoverArea/CollisionPolygon2D")
	if poly_node == null:
		return

	if not hover_polygon.is_empty():
		poly_node.polygon = hover_polygon
		return

	if sprite == null or sprite.texture == null:
		return
	var half: Vector2 = sprite.texture.get_size() * 0.5
	# Polygon points are local to poly_node, which may itself be offset.
	var center: Vector2 = sprite.position - poly_node.position
	poly_node.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])

## Applies the `FadeArea` overrides. Only called from `_apply_art()` (i.e.
## only when `art_texture` is set) and from the `fade_polygon` setter —
## never unconditionally from `_ready()` — so a plain `tree.tscn`
## instance's CollisionPolygon2D is never touched and safely keeps
## whatever outline you hand-draw for it in the editor. Same fallback
## rectangle as `_apply_hover_shape()` until you've tuned a real outline.
func _apply_fade_shape() -> void:
	var poly_node: CollisionPolygon2D = get_node_or_null("FadeArea/CollisionPolygon2D")
	if poly_node == null:
		return

	if not fade_polygon.is_empty():
		poly_node.polygon = fade_polygon
		return

	if sprite == null or sprite.texture == null:
		return
	var half: Vector2 = sprite.texture.get_size() * 0.5
	# Polygon points are local to poly_node, which may itself be offset.
	var center: Vector2 = sprite.position - poly_node.position
	poly_node.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])

## Applies the Trunk overrides. With no overrides set, the shipped
## rectangle in `tree.tscn` is left completely untouched (shared resource
## included), so a plain instance is unchanged.
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

## Called every frame by the Foliage autoload while the player is within
## Foliage.ACTIVE_RADIUS. Flips draw order against the player and eases
## the sprite's alpha toward its proximity target. Both read
## `_player_in_fade_area`, kept current by FadeArea's overlap signals —
## see `_on_fade_area_body_entered/exited` — so no distance math (and no
## separate pixel margin that could drift out of sync with it) runs here.
func update_proximity(player_pos: Vector2, delta: float) -> void:
	_active = true

	var player_feet: Vector2 = player_pos + Vector2(0, player_feet_offset)
	# The OR covers the approach from above (before the player has reached
	# FadeArea at all) as well as the moment they're blocked against the
	# trunk within it — see the class doc comment for why that second case
	# needs FadeArea rather than just the Y compare.
	var tree_in_front: bool = player_feet.y <= global_position.y or _player_in_fade_area
	z_index = (PLAYER_Z_INDEX + 1) if tree_in_front else (PLAYER_Z_INDEX - 1)

	_target_alpha = faded_alpha if _player_in_fade_area else 1.0

	if sprite:
		sprite.modulate.a = move_toward(sprite.modulate.a, _target_alpha, fade_speed * delta)

## Called by the Foliage autoload the frame a tree leaves the activation
## radius. Snaps back to the resting state — safe because ACTIVE_RADIUS is
## well outside FadeArea, so a leaving tree is already opaque.
func reset_proximity() -> void:
	z_index = PLAYER_Z_INDEX - 1
	_target_alpha = 1.0
	if sprite:
		sprite.modulate.a = 1.0
	_active = false

func is_proximity_active() -> bool:
	return _active

func filter_incoming_damage(amount: float, _source: Node, _hitbox: HitboxComponent) -> float:
	return amount

func _on_died() -> void:
	_drop_loot()
	_detach_from_tilemap()
	_play_death_effect()

func _detach_from_tilemap() -> void:
	var layer := get_parent()
	if not layer is TileMapLayer:
		return
	var cell: Vector2i = layer.local_to_map(position)
	var gpos := global_position
	Foliage.unregister_prop(self)
	layer.remove_child(self)
	layer.get_parent().add_child(self)
	global_position = gpos
	layer.erase_cell(cell)

func _drop_loot() -> void:
	ItemPickup.drop_loot(loot_table, global_position)

func _play_death_effect() -> void:
	Foliage.unregister_prop(self)
	var hurtbox := get_node_or_null("HurtboxComponent") as Area2D
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	var hover := get_node_or_null("HoverArea") as Area2D
	if hover:
		hover.set_deferred("monitoring", false)
		hover.set_deferred("monitorable", false)
	if fade_area:
		fade_area.set_deferred("monitoring", false)
		fade_area.set_deferred("monitorable", false)
	var shape := get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)
	_spawn_break_fragments()
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

func _spawn_break_fragments() -> void:
	if not get_parent():
		return
	var frags := CPUParticles2D.new()
	frags.emitting = true
	frags.one_shot = true
	frags.amount = 14
	frags.explosiveness = 0.9
	frags.lifetime = 0.5
	frags.direction = Vector2.UP
	frags.spread = 180.0
	frags.initial_velocity_min = 35.0
	frags.initial_velocity_max = 75.0
	frags.gravity = Vector2(0, 220.0)
	frags.scale_amount_min = 1.0
	frags.scale_amount_max = 2.5
	frags.color = Color(0.35, 0.52, 0.22)
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	frags.color_ramp = gradient
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	frags.texture = ImageTexture.create_from_image(img)
	frags.position = position + (sprite.position if sprite else Vector2.ZERO)
	frags.z_index = z_index
	get_parent().add_child(frags)
	get_tree().create_timer(frags.lifetime + 0.1).timeout.connect(frags.queue_free)

func _on_damaged(amount: float, source: Node) -> void:
	_shake(amount)
	_emit_hit_particles(source)

func _shake(damage: float) -> void:
	if not sprite:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		sprite.position = _sprite_rest_pos
	_sprite_rest_pos = sprite.position
	var intensity := clampf(damage / 4.0, 0.3, 1.5)
	var offset := intensity * 1.5
	var count := 3 if intensity < 0.6 else 5
	_shake_tween = create_tween()
	for i in count:
		var dir := 1.0 if i % 2 == 0 else -1.0
		_shake_tween.tween_property(sprite, "position:x",
				_sprite_rest_pos.x + offset * dir, 0.03)
	_shake_tween.tween_property(sprite, "position", _sprite_rest_pos, 0.03)

func _setup_hit_particles() -> void:
	_hit_particles = CPUParticles2D.new()
	_hit_particles.emitting = false
	_hit_particles.one_shot = true
	_hit_particles.amount = 8
	_hit_particles.explosiveness = 0.9
	_hit_particles.lifetime = 0.45
	_hit_particles.direction = Vector2.UP
	_hit_particles.spread = 55.0
	_hit_particles.initial_velocity_min = 28.0
	_hit_particles.initial_velocity_max = 58.0
	_hit_particles.gravity = Vector2(0, 180.0)
	_hit_particles.scale_amount_min = 0.5
	_hit_particles.scale_amount_max = 1.5
	_hit_particles.color = Color(0.42, 0.55, 0.28)
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	_hit_particles.color_ramp = gradient
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_hit_particles.texture = ImageTexture.create_from_image(img)
	_hit_particles.position = sprite.position if sprite else Vector2.ZERO
	add_child(_hit_particles)

func _emit_hit_particles(source: Node) -> void:
	if not _hit_particles or not source is Node2D:
		return
	var to_source := (source as Node2D).global_position - global_position
	if to_source != Vector2.ZERO:
		_hit_particles.position = (sprite.position if sprite else Vector2.ZERO) \
				+ to_source.normalized() * 6.0
	_hit_particles.restart()
	_hit_particles.emitting = true

func _apply_hurt_shape() -> void:
	var poly_node: CollisionPolygon2D = get_node_or_null("HurtboxComponent/CollisionPolygon2D")
	if poly_node == null:
		return

	if not hurt_polygon.is_empty():
		poly_node.polygon = hurt_polygon
		return

	if sprite == null or sprite.texture == null:
		return
	var half: Vector2 = sprite.texture.get_size() * 0.5
	var center: Vector2 = sprite.position - poly_node.position
	poly_node.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])
