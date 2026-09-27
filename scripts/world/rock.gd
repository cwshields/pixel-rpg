@tool
class_name RockProp
extends OccluderProp
## A single rock/boulder prop with the same two player-relative effects as
## `TreeProp` (tree.gd), both keyed off the same `FadeArea` (a hand-shaped
## outline hugging the boulder, see the Occlusion Fade group below):
## 1. Depth sort — the rock draws in front of the player (instead of
##    behind, as normal) once the player's feet are at or above the rock's
##    own Y, OR the player is still physically overlapping `FadeArea` — the
##    latter covers the moment the player is blocked against the rock's own
##    collision, where the feet-offset compare point can already read as
##    past the rock's Y even though the player hasn't actually walked past
##    it. See TreeProp's doc comment for the fuller rationale.
## 2. Occlusion fade — while standing inside `FadeArea`, the rock eases
##    toward `faded_alpha` so it doesn't fully hide the player.
##
## Registers with the `Foliage` autoload on entering the scene, same as
## TreeProp — see foliage_manager.gd for the shared per-frame driver.
##
## Rock variations live as inherited scenes in `VARIANT_DIR`
## (`scenes/world/rocks/`), each setting its own sprite and collision shape
## directly on the child nodes. Place rocks by instancing those — editing a
## variant scene's shapes once updates every rock that uses it. The Art /
## Collision / Hover / Hurt exports below are the older per-instance
## override path (what `convert_painted_rocks.gd` still emits).
##
## The script is `@tool` so those overrides preview live in the editor and
## the "Randomize Variant" button works. The player-relative effect never
## runs in the editor (guarded by `Engine.is_editor_hint()`).
##
## Extends `OccluderProp` purely for typing — see tree.gd for the sibling
## implementation this shares an interface (and nothing else) with.

## Folder of rock variant scenes (each inherits rock.tscn) that "Randomize
## Variant" picks from.
const VARIANT_DIR := "res://scenes/world/rocks/"

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

@export_group("Occlusion Fade")
## Alpha the rock eases down to while the player is inside `FadeArea` —
## see TreeProp.faded_alpha.
@export_range(0.0, 1.0) var faded_alpha: float = 0.5
## How fast the alpha eases toward its target, in alpha-units/second —
## see TreeProp.fade_speed.
@export var fade_speed: float = 4.0
## Explicit outline (points relative to the node origin) for `FadeArea` —
## see TreeProp.fade_polygon for the full rationale and the same
## hand-edit-vs-converted-instance guidance.
@export var fade_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		fade_polygon = value
		_apply_fade_shape()

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

## Inspector button: swaps this rock for an instance of a different,
## randomly picked variant scene from `VARIANT_DIR` (undoable) — see
## OccluderProp.swap_for_random_variant. Adding a variation is just saving
## another inherited scene into that folder.
@export_tool_button("Randomize Variant") var _randomize_variant_button = _randomize_variant

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

@export_group("Hover Area (Cursor)")
## Explicit outline (points relative to the node origin) for the
## cursor-only HoverArea, letting a rock's "mine" hover region hug an
## irregular boulder instead of the sprite's rectangular bounding box.
## When non-empty this wins over the auto-sized rectangle.
##
## For a plain hand-placed rock, you don't need this at all — just select
## HoverArea/CollisionPolygon2D and edit its Polygon directly with
## Godot's built-in polygon tool in the 2D viewport; `_apply_hover_shape()`
## never touches that node unless `art_texture` is set or this array
## changes, so a hand-edited plain rock keeps its shape. Use this field
## for converted rocks (`art_texture` set programmatically), where a
## custom outline would otherwise get overwritten the next time the art
## re-applies — same reasoning as `collision_polygon` above.
@export var hover_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		hover_polygon = value
		_apply_hover_shape()

@export_group("Combat")
## Rolled against on death — see EnemyBase.loot_table (enemy_base.gd) for
## the same pattern; RockProp doesn't extend EntityBase so it can't just
## inherit that logic, but _drop_loot()/_spawn_pickup() below mirror it.
@export var loot_table: Array[LootEntry] = []
## Explicit outline (points relative to the node origin) for the
## HurtboxComponent's hit region — same idea as `hover_polygon` above,
## kept as a separate export (rather than reusing `hover_polygon` for
## both) since a mining tool's reach and the mouse's hover point don't
## have to line up exactly. When non-empty this wins over the auto-sized
## rectangle.
##
## For a plain hand-placed rock, edit HurtboxComponent/CollisionPolygon2D
## directly in the editor instead — see `hover_polygon` for why
## `_apply_hurt_shape()` leaves a hand-edited plain rock alone.
@export var hurt_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		hurt_polygon = value
		_apply_hurt_shape()

## How far (px) a dropped pickup can land from the rock's base — see
## EnemyBase.LOOT_SCATTER.

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var health: HealthComponent = get_node_or_null("HealthComponent")
@onready var fade_area: Area2D = get_node_or_null("FadeArea")

var _active: bool = false
var _target_alpha: float = 1.0
## Whether the player's physical body currently overlaps `FadeArea` — see
## TreeProp._player_in_fade_area.
var _player_in_fade_area: bool = false

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
	if not Engine.is_editor_hint() and health:
		health.died.connect(_on_died)
	if not Engine.is_editor_hint() and fade_area:
		fade_area.body_entered.connect(_on_fade_area_body_entered)
		fade_area.body_exited.connect(_on_fade_area_body_exited)

## `FadeArea` (collision_mask 1, "Solid bodies") reports the player's
## physical CharacterBody2D directly — see TreeProp._on_fade_area_body_entered.
func _on_fade_area_body_entered(body: Node) -> void:
	if body == GameManager.player:
		_player_in_fade_area = true

func _on_fade_area_body_exited(body: Node) -> void:
	if body == GameManager.player:
		_player_in_fade_area = false

## "Randomize Variant" button target.
func _randomize_variant() -> void:
	swap_for_random_variant(VARIANT_DIR)

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

	_apply_hover_shape()
	_apply_hurt_shape()
	_apply_fade_shape()

## Applies the Hover Area overrides. Only called from `_apply_art()`
## (i.e. only when `art_texture` is set) and from the `hover_polygon`
## setter — never unconditionally from `_ready()` — so a plain
## `rock.tscn` instance's CollisionPolygon2D is never touched and safely
## keeps whatever outline you hand-draw for it in the editor.
##
## With `hover_polygon` set, the cursor-only HoverArea's CollisionPolygon2D
## traces that outline directly. Otherwise it falls back to a rectangle
## auto-sized to the current sprite's bounding box, so the "mine" hover
## cursor tracks the visible boulder instead of the much smaller physical
## collision box. HoverArea has no collision_mask and isn't on the
## physical-solids layer, so neither shape ever blocks player/enemy
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
	# Polygon points are local to poly_node, and both it and its Area2D
	# parent are offset in rock.tscn.
	var center: Vector2 = sprite.position - poly_node.position - (poly_node.get_parent() as Node2D).position
	poly_node.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])

## Applies the Hurtbox overrides. Only called from `_apply_art()` (i.e.
## only when `art_texture` is set) and from the `hurt_polygon` setter —
## same rules as `_apply_hover_shape()` above, including the auto-sized
## rectangle fallback.
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
	# Polygon points are local to poly_node, and both it and its Area2D
	# parent are offset in rock.tscn.
	var center: Vector2 = sprite.position - poly_node.position - (poly_node.get_parent() as Node2D).position
	poly_node.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])

## Applies the `FadeArea` overrides. Only called from `_apply_art()` (i.e.
## only when `art_texture` is set) and from the `fade_polygon` setter —
## never unconditionally from `_ready()` — so a plain `rock.tscn` instance's
## CollisionPolygon2D is never touched and safely keeps whatever outline you
## hand-draw for it in the editor. Same fallback rectangle as
## `_apply_hover_shape()` until you've tuned a real outline.
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
	# Polygon points are local to poly_node, and both it and its Area2D
	# parent are offset in rock.tscn.
	var center: Vector2 = sprite.position - poly_node.position - (poly_node.get_parent() as Node2D).position
	poly_node.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])

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
## Foliage.ACTIVE_RADIUS. Flips draw order against the player and eases the
## sprite's alpha toward its proximity target — see TreeProp.update_proximity.
func update_proximity(player_pos: Vector2, delta: float) -> void:
	_active = true

	var player_feet: Vector2 = player_pos + Vector2(0, player_feet_offset)
	var rock_in_front: bool = player_feet.y <= global_position.y or _player_in_fade_area
	z_index = (PLAYER_Z_INDEX + 1) if rock_in_front else (PLAYER_Z_INDEX - 1)

	_target_alpha = faded_alpha if _player_in_fade_area else 1.0

	if sprite:
		sprite.modulate.a = move_toward(sprite.modulate.a, _target_alpha, fade_speed * delta)

## Called by the Foliage autoload the frame a rock leaves the activation
## radius. Snaps back to the resting state.
func reset_proximity() -> void:
	z_index = PLAYER_Z_INDEX - 1
	_target_alpha = 1.0
	if sprite:
		sprite.modulate.a = 1.0
	_active = false

func is_proximity_active() -> bool:
	return _active

## HealthComponent.died — drop loot, then remove the rock. _exit_tree()
## (above) already unregisters from Foliage as part of the free, same as
## walking a rock out of the loaded world.
func _on_died() -> void:
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	ItemPickup.drop_loot(loot_table, global_position)
