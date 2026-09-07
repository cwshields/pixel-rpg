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
const PLAYER_Z_INDEX := 10

const _DEFAULT_TRUNK_SIZE := Vector2(9, 8)
const _DEFAULT_TRUNK_OFFSET := Vector2(0.5, -4)

# Shared across every TreeProp in the session so 100+ converted trees that
# draw from the same sheet region reuse one AtlasTexture instead of each
# allocating (and serialising) its own.
static var _atlas_cache: Dictionary = {}

@export_group("Depth Sorting")
## Vertical distance from the player's node origin down to their visual
## feet. The player's AnimatedSprite2D is centered on the node origin
## (not anchored at the feet), so this corrects for that when comparing
## "who's lower on the grid" — without it the compare point would be the
## player's torso, and the tree would seem to switch in front/behind too
## early or late.
@export var player_feet_offset: float = 38.0

@export_group("Transparency Fade")
## Distance (px) from the tree's base at which fading begins. Beyond
## this distance the tree stays fully opaque even while it's drawn in
## front of the player. This is "the player-distance tree-transparency
## start" value — raise it to make the tree start fading from further away.
## Keep it below Foliage.ACTIVE_RADIUS or the fade will pop instead of ease.
@export var fade_start_distance: float = 52.0
## Alpha the tree eases down to when the player is right at its base.
## 1.0 = never fades, 0.0 = fully invisible up close. 0.5 = 50%
## transparent, matching "trees go about 50% transparent" — this is the
## maximum-transparency value.
@export_range(0.0, 1.0) var faded_alpha: float = 0.5
## How fast the alpha eases toward its target, in alpha-units/second
## (e.g. 6.0 = a full 0↔1 fade takes about 1/6th of a second).
@export var fade_speed: float = 6.0

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
## purely visual (matches trees that were painted as plain tileset tiles).
@export var trunk_enabled: bool = true:
	set(value):
		trunk_enabled = value
		_apply_trunk()
## Trunk collision box size. Only applied when it differs from the default.
@export var trunk_size: Vector2 = _DEFAULT_TRUNK_SIZE:
	set(value):
		trunk_size = value
		_apply_trunk()
## Trunk collision box offset from the node origin.
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

## Applies the Trunk overrides. Size/offset are only touched when they
## differ from the shipped defaults, so a plain instance keeps `tree.tscn`'s
## shared shape resource untouched.
func _apply_trunk() -> void:
	var shape_node: CollisionShape2D = get_node_or_null("StaticBody2D/CollisionShape2D")
	if shape_node == null:
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
	var tree_in_front: bool = global_position.y >= player_feet.y
	z_index = (PLAYER_Z_INDEX + 1) if tree_in_front else (PLAYER_Z_INDEX - 1)

	if tree_in_front and fade_start_distance > 0.0:
		var distance: float = global_position.distance_to(player_feet)
		var t: float = clampf(distance / fade_start_distance, 0.0, 1.0)
		_target_alpha = lerpf(faded_alpha, 1.0, t)
	else:
		_target_alpha = 1.0

	if sprite:
		sprite.modulate.a = move_toward(sprite.modulate.a, _target_alpha, fade_speed * delta)

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
