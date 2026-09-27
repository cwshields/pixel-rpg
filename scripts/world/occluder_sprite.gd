@tool
class_name OccluderSprite
extends OccluderProp
## Drop-in version of the tree/rock depth-sort + occlusion fade for any
## existing sprite — buildings, walls, big one-off props. Unlike `TreeProp`
## and `RockProp` there's no scene to instance: attach this script straight
## onto a `Sprite2D` already placed in a level (or onto a `Node2D` whose
## first child `Sprite2D` is the art), and it builds what it needs:
##   * `StaticBody2D/CollisionPolygon2D` — the solid footprint. Auto-sized to
##     the bottom `footprint_ratio` of the sprite, so the player can walk up
##     into the roof/upper art and be hidden by it.
##   * `FadeArea/CollisionPolygon2D` — the occlusion-fade region. Auto-sized
##     to the whole sprite.
## Both are ordinary nodes saved into the scene, so once built you tune them
## by selecting the CollisionPolygon2D and dragging its points in the 2D
## viewport. The script never overwrites an existing polygon on its own —
## only the "Rebuild Occluder Shapes" button does.
##
## Depth sort works like TreeProp: the art draws in front of the player
## while the player's feet are above the art's base line (the sprite's
## bottom edge + `base_line_adjust`) or the player is inside `FadeArea`,
## and behind otherwise. While inside `FadeArea` the art eases toward
## `faded_alpha`.
##
## Avoid negative scale / 180° rotation tricks for mirroring (physics
## polygons don't like reflected transforms) — use the Sprite2D's Flip H.

const _BODY_NAME := "StaticBody2D"
const _FADE_NAME := "FadeArea"

@export_group("Depth Sorting")
## See TreeProp.player_feet_offset — distance from the player's origin down
## to their visual feet.
@export var player_feet_offset: float = 18.0
## Nudges the sort line (px, local, + = down) from the sprite's bottom edge,
## for art whose bottom row isn't where the building meets the ground
## (porch steps, a shadow, transparent padding).
@export var base_line_adjust: float = 0.0

@export_group("Occlusion Fade")
## Alpha the art eases down to while the player is inside `FadeArea`.
@export_range(0.0, 1.0) var faded_alpha: float = 0.5
## Alpha-units/second, same meaning as TreeProp.fade_speed.
@export var fade_speed: float = 4.0

@export_group("Auto Shapes")
## Fraction of the sprite's height, measured up from its bottom edge, that
## the auto-built solid footprint covers.
@export_range(0.05, 1.0) var footprint_ratio: float = 0.45
## Pixels trimmed off each side of the auto-built footprint (roof eaves
## usually overhang the walls).
@export var footprint_inset: float = 4.0
## Inspector button: (re)builds both polygons from the current sprite,
## discarding any hand edits. Creates the child nodes first if missing.
@export_tool_button("Rebuild Occluder Shapes") var _rebuild_button = _rebuild_shapes

var _target_alpha: float = 1.0
var _active: bool = false
var _player_in_fade_area: bool = false
## The art's base line in local space — the point compared against the
## player's feet (TreeProp uses its own origin, which sits at the trunk
## foot; a centered Sprite2D's origin is mid-art, so this corrects for it).
var _base_local: Vector2 = Vector2.ZERO

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	Foliage.register_prop(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	Foliage.unregister_prop(self)

func _ready() -> void:
	_ensure_children()
	var rect := _art_rect()
	_base_local = Vector2(rect.get_center().x, rect.end.y + base_line_adjust)
	if Engine.is_editor_hint():
		return
	z_index = PLAYER_Z_INDEX - 1
	var fade_area: Area2D = get_node_or_null(_FADE_NAME)
	if fade_area:
		fade_area.body_entered.connect(_on_fade_area_body_entered)
		fade_area.body_exited.connect(_on_fade_area_body_exited)

func _get_configuration_warnings() -> PackedStringArray:
	if _art_sprite() == null:
		return ["OccluderSprite needs to be on a Sprite2D, or have a Sprite2D child."]
	return []

func _on_fade_area_body_entered(body: Node) -> void:
	if body == GameManager.player:
		_player_in_fade_area = true

func _on_fade_area_body_exited(body: Node) -> void:
	if body == GameManager.player:
		_player_in_fade_area = false

## This node itself if it's a Sprite2D, else its first Sprite2D child.
func _art_sprite() -> Sprite2D:
	var node: Node = self
	if node is Sprite2D:
		return node
	for child in get_children():
		if child is Sprite2D:
			return child
	return null

## The art's bounding box in this node's local space.
func _art_rect() -> Rect2:
	var s := _art_sprite()
	if s == null or s.texture == null:
		return Rect2()
	if s == self:
		return s.get_rect()
	return s.transform * s.get_rect()

## Creates the StaticBody2D / FadeArea children (with auto shapes) if
## they're missing. In the editor they're owned by the edited scene so they
## get saved; at runtime (script attached but never opened in the editor)
## they're just built on the fly so the effect still works.
func _ensure_children() -> void:
	var created := false
	if get_node_or_null(_BODY_NAME) == null:
		var body := StaticBody2D.new()
		body.name = _BODY_NAME
		body.collision_mask = 0
		_add_owned(body)
		_add_owned(CollisionPolygon2D.new(), body)
		created = true
	if get_node_or_null(_FADE_NAME) == null:
		var area := Area2D.new()
		area.name = _FADE_NAME
		area.collision_layer = 0
		area.monitorable = false
		_add_owned(area)
		_add_owned(CollisionPolygon2D.new(), area)
		created = true
	if created:
		_fit_empty_polygons()

func _add_owned(node: Node, parent: Node = self) -> void:
	parent.add_child(node)
	if not Engine.is_editor_hint():
		return
	var scene_root := get_tree().edited_scene_root
	# Only claim nodes inside the scene being edited — never inside an
	# instanced sub-scene, where they couldn't be saved anyway.
	if scene_root and (scene_root == self or owner == scene_root):
		node.owner = scene_root

func _rebuild_shapes() -> void:
	_ensure_children()
	_fit_polygon(_BODY_NAME, true)
	_fit_polygon(_FADE_NAME, false)
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()

func _fit_empty_polygons() -> void:
	for pair in [[_BODY_NAME, true], [_FADE_NAME, false]]:
		var poly: CollisionPolygon2D = get_node_or_null("%s/CollisionPolygon2D" % pair[0])
		if poly and poly.polygon.is_empty():
			_fit_polygon(pair[0], pair[1])

func _fit_polygon(parent_name: String, is_footprint: bool) -> void:
	var poly: CollisionPolygon2D = get_node_or_null("%s/CollisionPolygon2D" % parent_name)
	var rect := _art_rect()
	if poly == null or rect.size == Vector2.ZERO:
		return
	if is_footprint:
		var h := rect.size.y * footprint_ratio
		rect = Rect2(
			rect.position.x + footprint_inset, rect.end.y - h,
			maxf(rect.size.x - footprint_inset * 2.0, 1.0), h)
	poly.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])

## Called every frame by the Foliage autoload while the player is within
## Foliage.ACTIVE_RADIUS — same flip + fade rules as TreeProp.
func update_proximity(player_pos: Vector2, delta: float) -> void:
	_active = true
	var player_feet_y: float = player_pos.y + player_feet_offset
	var art_in_front: bool = player_feet_y <= to_global(_base_local).y or _player_in_fade_area
	z_index = (PLAYER_Z_INDEX + 1) if art_in_front else (PLAYER_Z_INDEX - 1)
	_target_alpha = faded_alpha if _player_in_fade_area else 1.0
	modulate.a = move_toward(modulate.a, _target_alpha, fade_speed * delta)

func reset_proximity() -> void:
	z_index = PLAYER_Z_INDEX - 1
	_target_alpha = 1.0
	modulate.a = 1.0
	_active = false

func is_proximity_active() -> bool:
	return _active
