@tool
class_name TreeProp
extends Node2D
## A single tree prop with two effects tied to the player's position:
## 1. Depth sort — if the tree's base is lower on the grid than the
##    player (i.e. the tree is visually "in front"), it draws over the
##    player instead of under them, so the player appears to walk behind
##    it. Otherwise it draws behind the player as normal.
## 2. Proximity fade — while the tree is drawn in front of the player,
##    it fades toward `faded_alpha` the closer the player gets, so it
##    doesn't fully hide them at close range.
##
## Neither effect runs here per frame. The tree registers itself with the
## `Foliage` autoload on entering the scene, and Foliage calls
## `update_proximity()` each frame ONLY while the player is within its
## activation radius — a tree on the far side of the map costs nothing.
## Dropping a Tree anywhere in the world (regardless of what it's parented
## under) is still all that's required.
##
## The script is `@tool` only so the Art / Trunk overrides below preview
## live in the editor — this is what lets a single `tree.tscn` stand in for
## every tree sprite in the tileset. The player-relative effects never run
## in the editor (guarded by `Engine.is_editor_hint()`).

## Player.tscn's root z_index is set to this same value — a tree needs a
## shared baseline to sit exactly one step above or below the player.
## Change both together if you ever retune this.
const PLAYER_Z_INDEX := 4

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
## Extra slack (px) below the tree's base within which the tree still
## draws in front of the player. The trunk's collision box stops the
## player before their feet-point can reach the base, so without this the
## tree snaps behind the player the instant they bump the trunk — while
## the player sprite is still visually inside the canopy. Keep it a little
## larger than the gap the trunk collision leaves (~15–25 px).
@export var flip_margin: float = 14.0

@export_group("Transparency Fade")
## Distance (px) beyond the canopy sprite's edge at which fading begins;
## closer than that (and once the player's feet are inside the canopy) the
## tree eases toward `faded_alpha`. On the downhill side the canopy edge
## sits at the tree's base, so this still behaves like the old "distance
## from the base" there — it only widens the zone up the sides and over
## the top, where the canopy can hide the player but the base point is far
## away. Raise it to start the fade from further out. Keep it below
## Foliage.ACTIVE_RADIUS or the fade will pop instead of ease.
@export var fade_start_distance: float = 22.0
## Alpha the tree eases down to when the player is right at its base.
## 1.0 = never fades, 0.0 = fully invisible up close. 0.5 = 50%
## transparent, matching "trees go about 50% transparent" — this is the
## maximum-transparency value.
@export_range(0.0, 1.0) var faded_alpha: float = 0.5
## How fast the alpha eases toward its target, in alpha-units/second
## (e.g. 6.0 = a full 0↔1 fade takes about 1/6th of a second).
@export var fade_speed: float = 4.0

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

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var _target_alpha: float = 1.0
var _active: bool = false

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	Foliage.register_tree(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	Foliage.unregister_tree(self)

func _ready() -> void:
	z_index = PLAYER_Z_INDEX - 1
	_apply_art()
	_apply_trunk()

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
## the sprite's alpha toward its proximity target.
func update_proximity(player_pos: Vector2, delta: float) -> void:
	_active = true

	var player_feet: Vector2 = player_pos + Vector2(0, player_feet_offset)
	var tree_in_front: bool = player_feet.y <= global_position.y + flip_margin
	z_index = (PLAYER_Z_INDEX + 1) if tree_in_front else (PLAYER_Z_INDEX - 1)

	if tree_in_front and fade_start_distance > 0.0:
		var t: float = clampf(_canopy_edge_distance(player_feet) / fade_start_distance, 0.0, 1.0)
		_target_alpha = lerpf(faded_alpha, 1.0, t)
	else:
		_target_alpha = 1.0

	if sprite:
		sprite.modulate.a = move_toward(sprite.modulate.a, _target_alpha, fade_speed * delta)

## Distance (px) from `point` to the nearest edge of the canopy sprite's
## bounding box, or 0 while `point` is inside it. The fade keys off this
## instead of the distance to the trunk foot, so the tree thins out across
## the whole area the canopy can hide the player behind — not just a small
## circle at the stump. Falls back to distance-from-base if the sprite
## has no texture yet.
func _canopy_edge_distance(point: Vector2) -> float:
	if sprite == null or sprite.texture == null:
		return global_position.distance_to(point)
	var local: Vector2 = point - global_position
	var half: Vector2 = sprite.texture.get_size() * 0.5
	var dx: float = maxf(absf(local.x - sprite.position.x) - half.x, 0.0)
	var dy: float = maxf(absf(local.y - sprite.position.y) - half.y, 0.0)
	return sqrt(dx * dx + dy * dy)

## Called by the Foliage autoload the frame a tree leaves the activation
## radius. Snaps back to the resting state — safe because ACTIVE_RADIUS is
## well outside fade_start_distance, so a leaving tree is already opaque.
func reset_proximity() -> void:
	z_index = PLAYER_Z_INDEX - 1
	_target_alpha = 1.0
	if sprite:
		sprite.modulate.a = 1.0
	_active = false

func is_proximity_active() -> bool:
	return _active
