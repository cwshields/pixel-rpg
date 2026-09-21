@tool
class_name RockProp
extends OccluderProp
## A single rock/boulder prop with the same player-relative depth sort as
## `TreeProp` (tree.gd): if the rock's base is lower on the grid than the
## player (i.e. the rock is visually "in front"), it draws over the player
## instead of under them, so the player appears to walk behind it.
## Otherwise it draws behind the player as normal.
##
## Unlike TreeProp there's no proximity fade — a rock is solid all the way
## up, so there's nothing behind it worth seeing through; the flip alone is
## enough to sell "walking behind the boulder".
##
## Registers with the `Foliage` autoload on entering the scene, same as
## TreeProp — see foliage_manager.gd for the shared per-frame driver.
##
## The script is `@tool` only so the Art overrides below preview live in
## the editor — this is what lets a single `rock.tscn` stand in for every
## rock sprite in the tileset. The player-relative effect never runs in the
## editor (guarded by `Engine.is_editor_hint()`).
##
## Extends `OccluderProp` purely for typing — see tree.gd for the sibling
## implementation this shares an interface (and nothing else) with.

## Player.tscn's root z_index is set to this same value — see the matching
## constant + comment on TreeProp (tree.gd). Keep all three in sync.
const PLAYER_Z_INDEX := 4

const _DEFAULT_COLLISION_SIZE := Vector2(16, 10)
const _DEFAULT_COLLISION_OFFSET := Vector2(0, -5)

# Shared across every RockProp in the session so many rocks that draw from
# the same sheet region (or share a collision outline) reuse one resource
# instead of each allocating (and serialising) its own.
static var _atlas_cache: Dictionary = {}
static var _collision_shape_cache: Dictionary = {}

@export_group("Depth Sorting")
## Vertical distance from the player's node origin down to their visual
## feet — see TreeProp.player_feet_offset for the full rationale.
@export var player_feet_offset: float = 18.0
## Extra slack (px) below the rock's base within which the rock still
## draws in front of the player — see TreeProp.flip_margin.
@export var flip_margin: float = 14.0

@export_group("Art")
## Sprite sheet to draw this rock from. Leave null to keep whatever
## `rock.tscn` ships with. The painted-rock converter sets this per
## instance to the matching tileset sheet.
@export var art_texture: Texture2D = null:
	set(value):
		art_texture = value
		_apply_art()
## Region (px) of `art_texture` to show. Zero size = use the whole texture.
@export var art_region: Rect2i = Rect2i():
	set(value):
		art_region = value
		_apply_art()
## Sprite2D local position. The node origin sits at the rock's base, so
## this is normally negative Y (the rock rises above its base).
@export var art_offset: Vector2 = Vector2(0, -24):
	set(value):
		art_offset = value
		_apply_art()

@export_group("Collision")
## When false the StaticBody2D's shape is disabled, so the rock is purely
## visual. Ignored when `collision_polygon` is set.
@export var collision_enabled: bool = true:
	set(value):
		collision_enabled = value
		_apply_collision()
## Explicit collision outline (points relative to `collision_offset`). When
## non-empty this wins: the CollisionShape2D becomes a
## ConvexPolygonShape2D with these points. The converter fills it from each
## tileset rock tile's own physics polygon so converted rocks keep exactly
## the collision they had as tiles.
@export var collision_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		collision_polygon = value
		_apply_collision()
## Collision box size. Only applied when it differs from the default and
## `collision_polygon` is empty.
@export var collision_size: Vector2 = _DEFAULT_COLLISION_SIZE:
	set(value):
		collision_size = value
		_apply_collision()
## Collision offset from the node origin (also the origin the
## `collision_polygon` points are measured from).
@export var collision_offset: Vector2 = _DEFAULT_COLLISION_OFFSET:
	set(value):
		collision_offset = value
		_apply_collision()

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var _active: bool = false

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
	_apply_collision()

## Rebuilds the Sprite2D from the Art overrides. No-op when `art_texture`
## is unset, so a plain `rock.tscn` instance keeps its shipped sprite.
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

## Applies the Collision overrides. With no overrides set, the shipped
## rectangle in `rock.tscn` is left completely untouched (shared resource
## included), so a plain instance is unchanged.
func _apply_collision() -> void:
	var shape_node: CollisionShape2D = get_node_or_null("StaticBody2D/CollisionShape2D")
	if shape_node == null:
		return

	if not collision_polygon.is_empty():
		var key := var_to_str(collision_polygon)
		var poly: ConvexPolygonShape2D = _collision_shape_cache.get(key)
		if poly == null:
			poly = ConvexPolygonShape2D.new()
			poly.points = collision_polygon
			_collision_shape_cache[key] = poly
		if shape_node.shape != poly:
			shape_node.shape = poly
		shape_node.position = collision_offset
		shape_node.disabled = false
		return

	shape_node.disabled = not collision_enabled
	if collision_size != _DEFAULT_COLLISION_SIZE or collision_offset != _DEFAULT_COLLISION_OFFSET:
		shape_node.position = collision_offset
		var rect := RectangleShape2D.new()
		rect.size = collision_size
		shape_node.shape = rect

## Called every frame by the Foliage autoload while the player is within
## Foliage.ACTIVE_RADIUS. Flips draw order against the player — no fade,
## unlike TreeProp.
func update_proximity(player_pos: Vector2, _delta: float) -> void:
	_active = true
	var player_feet: Vector2 = player_pos + Vector2(0, player_feet_offset)
	var rock_in_front: bool = player_feet.y <= global_position.y + flip_margin
	z_index = (PLAYER_Z_INDEX + 1) if rock_in_front else (PLAYER_Z_INDEX - 1)

## Called by the Foliage autoload the frame a rock leaves the activation
## radius. Snaps back to the resting state.
func reset_proximity() -> void:
	z_index = PLAYER_Z_INDEX - 1
	_active = false

func is_proximity_active() -> bool:
	return _active
