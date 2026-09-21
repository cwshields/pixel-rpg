class_name Cursor
extends CanvasLayer
## In-game replacement for the OS mouse cursor.
##
## Drawn as a Sprite2D inside its own CanvasLayer (layer 128, above every
## other UI layer) instead of an OS hardware cursor, so it scales with the
## project's canvas_items stretch mode and can be swapped by game state
## via set_cursor() — used here to reflect whatever's under the mouse in
## the game world (see _update_hover()). The real OS cursor is hidden
## while the window has focus and restored when focus is lost, so
## alt-tabbing doesn't strand the player without a pointer.
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

## Layer 3 (hurtboxes, value 4) | layer 4 (interactables, value 8) |
## layer 5 (choppable trees, value 16) — see the collision layer legend
## in README.md.
const HOVER_MASK := 0b11100

@onready var _sprite: Sprite2D = $Sprite

## Captured in _ready() so _update_hover() can restore it — set_cursor()
## overwrites `hotspot` itself to track whichever art is currently shown.
var _default_hotspot: Vector2

func _ready() -> void:
	_default_hotspot = hotspot
	_sprite.centered = false
	_sprite.texture = default_texture
	_sprite.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_window().focus_exited.connect(_on_focus_exited)
	get_window().focus_entered.connect(_on_focus_entered)

func _process(_delta: float) -> void:
	_sprite.position = get_viewport().get_mouse_position() - hotspot
	_update_hover()

## Point-queries the physics world at the mouse position and swaps the
## cursor art to match what's there: a HurtboxComponent (attackable) beats
## an InteractionComponent (talk/open/read), which beats a TreeProp's
## cursor-only HoverArea (choppable), which beats the plain arrow.
## Skipped whenever a UI screen (inventory, pause menu...) has the mouse's
## attention instead of the game world, so hovering a menu never shows a
## sword cursor for whatever happens to sit behind it.
func _update_hover() -> void:
	if UIManager.is_any_open():
		set_cursor(default_texture, _default_hotspot)
		return
	var hovered: Object = _hovered_collider()
	if hovered is HurtboxComponent:
		set_cursor(attack_texture, attack_hotspot)
	elif hovered is InteractionComponent:
		set_cursor(interact_texture, interact_hotspot)
	elif hovered is CollisionObject2D and hovered.get_parent() is TreeProp:
		set_cursor(cut_texture, cut_hotspot)
	else:
		set_cursor(default_texture, _default_hotspot)

## First collider under the mouse on HOVER_MASK, or null if none. Uses the
## player's world position to resolve the mouse to world space — Cursor
## itself lives in a separate always-on-top CanvasLayer, so it has no
## camera-relative transform of its own to convert screen -> world with.
func _hovered_collider() -> Object:
	var player := GameManager.player as Node2D
	if not player:
		return null
	var query := PhysicsPointQueryParameters2D.new()
	query.position = player.get_global_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = HOVER_MASK
	var results := get_viewport().world_2d.direct_space_state.intersect_point(query, 8)
	return results[0]["collider"] if not results.is_empty() else null

## Swap the cursor's look. `new_hotspot` follows the same convention as
## `hotspot`. Called by _update_hover() each frame, but also fine to call
## directly for cases hovering doesn't cover (e.g. mid-attack).
func set_cursor(texture: Texture2D, new_hotspot: Vector2 = Vector2.ZERO) -> void:
	_sprite.texture = texture
	hotspot = new_hotspot

func _on_focus_exited() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sprite.visible = false

func _on_focus_entered() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_sprite.visible = true
