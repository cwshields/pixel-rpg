class_name Cursor
extends Node
## In-game replacement for the OS mouse cursor.
##
## Installed as the OS *hardware* cursor via Input.set_custom_mouse_cursor()
## rather than drawn as a sprite: a sprite only moves when the game renders
## a frame (plus vsync/swapchain latency), so it visibly trails the real
## mouse, while the hardware cursor is composited by the OS at full mouse
## rate. The art is still swapped by game state via set_cursor() — used
## here to reflect whatever's under the mouse in the game world (see
## _update_hover()) — and pre-scaled to match the project's canvas_items
## stretch (see _refresh_scale()), since the OS doesn't know about it.
##
## Runs with process_mode ALWAYS so it keeps tracking the mouse (and
## un-hovering world targets) even while GameManager.PAUSED has frozen
## everything else, e.g. behind the pause menu.

## Shown on _ready() and whenever nothing hoverable is under the mouse.
## The pixel in the texture that should sit exactly on the mouse position
## (e.g. an arrow's tip), measured from its top-left.
@export var default_texture: Texture2D
@export var hotspot: Vector2 = Vector2.ZERO
## Shown while the mouse hovers a HurtboxComponent (something attackable).
@export var attack_texture: Texture2D
@export var attack_hotspot: Vector2 = Vector2.ZERO
## Shown while the mouse hovers an InteractionComponent (NPC, chest, sign).
@export var interact_texture: Texture2D
@export var interact_hotspot: Vector2 = Vector2.ZERO
## Shown while the mouse hovers a Tree the player can cut down.
@export var cut_texture: Texture2D
@export var cut_hotspot: Vector2 = Vector2.ZERO
## Shown while the mouse hovers a Rock the player can mine.
@export var mine_texture: Texture2D
@export var mine_hotspot: Vector2 = Vector2.ZERO

## Layer 3 (hurtboxes, value 4) | layer 4 (interactables, value 8) |
## layer 5 (choppable trees, value 16) | layer 6 (mineable rocks, value 32)
## — see the collision layer legend in README.md.
const HOVER_MASK := 0b111100
const CURSOR_SCALE := 2

## Captured in _ready() so _update_hover() can restore it — set_cursor()
## overwrites `hotspot` itself to track whichever art is currently shown.
var _default_hotspot: Vector2

## The harvestable prop (RockProp or TreeProp) currently under the mouse,
## or null — kept in sync by _update_hover() each frame. Player reads
## this (via GameManager.cursor) to tell "clicking near a prop" from
## "actually clicking on the prop", since the "attack" input is shared
## with the sword swing.
var hovered_harvestable: BreakableProp = null

## Art/hotspot currently installed, so set_cursor() can skip the (costly)
## OS cursor upload when _update_hover() re-requests the same one each frame.
var _current_texture: Texture2D = null
var _current_hotspot: Vector2 = Vector2.ZERO

## Screen pixels per game pixel under the canvas_items stretch, and the
## cursor images already scaled to it (Texture2D -> Image). Both rebuilt
## on window resize by _refresh_scale().
var _scale: float = 1.0
var _scaled_images: Dictionary = {}

func _ready() -> void:
	_default_hotspot = hotspot
	get_tree().root.size_changed.connect(_refresh_scale)
	_refresh_scale()
	set_cursor(default_texture, _default_hotspot)
	GameManager.register_cursor(self)

func _process(_delta: float) -> void:
	_update_hover()

## Point-queries the physics world at the mouse position and swaps the
## cursor art to match what's there: a RockProp (mineable) beats a
## HurtboxComponent (attackable), which beats an InteractionComponent
## (talk/open/read), which beats a TreeProp's cursor-only HoverArea
## (choppable), which beats the plain arrow. Rock is checked first across
## ALL intersect_point results because a rock's own HurtboxComponent sits
## on the attack layer and can win the single-result race otherwise.
## Skipped whenever a UI screen (inventory, pause menu...) has the mouse's
## attention instead of the game world, so hovering a menu never shows a
## sword cursor for whatever happens to sit behind it.
func _update_hover() -> void:
	if UIManager.is_any_open():
		set_cursor(default_texture, _default_hotspot)
		hovered_harvestable = null
		return
	var colliders := _hovered_colliders()
	hovered_harvestable = null
	var best := 0
	var harvest_hit: BreakableProp = null
	for c in colliders:
		if c is CollisionObject2D and c.get_parent() is RockProp:
			harvest_hit = c.get_parent() as RockProp
			best = 4
			break
		elif c is HurtboxComponent and best < 3:
			best = 3
		elif c is InteractionComponent and best < 2:
			best = 2
		elif c is CollisionObject2D and c.get_parent() is TreeProp and best < 1:
			harvest_hit = c.get_parent() as TreeProp
			best = 1
	match best:
		4:
			hovered_harvestable = harvest_hit
			set_cursor(mine_texture, mine_hotspot)
		3:
			set_cursor(attack_texture, attack_hotspot)
		2:
			set_cursor(interact_texture, interact_hotspot)
		1:
			hovered_harvestable = harvest_hit
			set_cursor(cut_texture, cut_hotspot)
		_:
			set_cursor(default_texture, _default_hotspot)

## All colliders under the mouse on HOVER_MASK. Uses the player's world
## position to resolve the mouse to world space — Cursor itself lives in a
## separate always-on-top CanvasLayer, so it has no camera-relative
## transform of its own to convert screen -> world with.
func _hovered_colliders() -> Array:
	var player := GameManager.player as Node2D
	if not player:
		return []
	var query := PhysicsPointQueryParameters2D.new()
	query.position = player.get_global_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = HOVER_MASK
	var results := get_viewport().world_2d.direct_space_state.intersect_point(query, 8)
	var out: Array = []
	for r in results:
		out.append(r["collider"])
	return out

## Swap the cursor's look. `new_hotspot` is the pixel in the texture that
## sits exactly on the mouse position (e.g. an arrow's tip), measured from
## its top-left in unscaled game pixels. Called by _update_hover() each
## frame, but also fine to call directly for cases hovering doesn't cover
## (e.g. mid-attack). No-op if that art is already installed.
func set_cursor(texture: Texture2D, new_hotspot: Vector2 = Vector2.ZERO) -> void:
	if texture == _current_texture and new_hotspot == _current_hotspot:
		return
	_current_texture = texture
	_current_hotspot = new_hotspot
	hotspot = new_hotspot
	_install_current()

func _install_current() -> void:
	if not _current_texture:
		Input.set_custom_mouse_cursor(null)
		return
	var hs := (_current_hotspot * CURSOR_SCALE * _scale).round()
	Input.set_custom_mouse_cursor(_scaled_image(_current_texture),
			Input.CURSOR_ARROW, hs)

func _scaled_image(texture: Texture2D) -> Image:
	if _scaled_images.has(texture):
		return _scaled_images[texture]
	var image: Image
	if texture is AtlasTexture:
		image = texture.atlas.get_image()
		if image.is_compressed():
			image.decompress()
		image = image.get_region(Rect2i(texture.region))
	else:
		image = texture.get_image()
		if image.is_compressed():
			image.decompress()
	var base := image.get_size()
	var scaled := base * CURSOR_SCALE
	var final_size := (Vector2(scaled) * _scale).round()
	final_size = final_size.clamp(Vector2.ONE, Vector2(256, 256))
	image.resize(int(final_size.x), int(final_size.y), Image.INTERPOLATE_NEAREST)
	_scaled_images[texture] = image
	return image

## Re-reads the root window's stretch scale and, if it changed, rebuilds
## the scaled images and reinstalls the current cursor at the new size.
## Never below 1x, so a window shrunk under the base resolution doesn't
## shrink the pointer into illegibility.
func _refresh_scale() -> void:
	var new_scale := maxf(get_tree().root.get_final_transform().get_scale().x, 1.0)
	if is_equal_approx(new_scale, _scale) and not _scaled_images.is_empty():
		return
	_scale = new_scale
	_scaled_images.clear()
	_install_current()
