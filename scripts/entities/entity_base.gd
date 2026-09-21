class_name EntityBase
extends CharacterBody2D
## Shared base for anything that moves around the world and can take
## damage: the player, enemies, and (optionally) NPCs. Concrete entities
## extend this, add a StateMachine child, and drive `move()`/`stop()`
## from within their states rather than duplicating movement code.

signal died(entity: EntityBase)
signal facing_changed(direction: Vector2)

@export var move_speed: float = 65.0
## Target speed (px/sec) used in place of `move_speed` while `sprinting` is
## true. The driving state sets `sprinting` each frame from its own input
## (see PlayerMoveState).
@export var sprint_speed: float = 110.0
@export var acceleration: float = 600.0
@export var friction: float = 500.0

## When true, `move()` targets `sprint_speed` instead of `move_speed`. Not
## persisted — whichever state is active owns setting and clearing it.
var sprinting: bool = false

## Last non-zero movement direction. Useful for aiming an attack or
## picking an idle-facing animation when the entity is standing still.
var facing_direction: Vector2 = Vector2.DOWN

@onready var health: HealthComponent = get_node_or_null("HealthComponent")
@onready var stats: StatsComponent = get_node_or_null("StatsComponent")
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

func _ready() -> void:
	if health:
		health.died.connect(_on_died)

## Plays an animation for `base_name` on the AnimatedSprite2D. Tries an
## exact match first (for single-direction art — most mobs/NPCs in this
## project only face right and mirror via flip_h), then falls back to
## "<base_name>_<direction>" (down/up/side, for multi-directional art
## like the player's). flip_h always mirrors for leftward movement.
## Returns false — and does nothing — if there's no AnimatedSprite2D, no
## SpriteFrames, or no matching animation (e.g. before art is added), so
## callers that need to know when an animation actually finishes can
## skip awaiting it.
func play_animation(base_name: String) -> bool:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return false
	var frames: SpriteFrames = animated_sprite.sprite_frames
	var anim_name := StringName(base_name)
	if not frames.has_animation(anim_name):
		anim_name = StringName("%s_%s" % [base_name, _facing_suffix()])
		if not frames.has_animation(anim_name):
			return false
	animated_sprite.flip_h = facing_direction.x < 0.0
	if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
		animated_sprite.play(anim_name)
	return true

func _facing_suffix() -> String:
	if absf(facing_direction.y) >= absf(facing_direction.x):
		return "up" if facing_direction.y < 0.0 else "down"
	return "side"

## Eases velocity toward `direction * move_speed` and slides. Pass
## Vector2.ZERO to decelerate to a stop. `direction` should already be
## normalized (or zero) — callers decide how input maps to a direction.
## Pass `update_facing = false` to move without re-aiming `facing_direction`
## (e.g. sidestepping mid-attack while the swing stays committed).
func move(direction: Vector2, delta: float, update_facing: bool = true) -> void:
	var base_speed: float = sprint_speed if sprinting else move_speed
	var target_speed: float = base_speed * (stats.speed_multiplier if stats else 1.0)
	if direction != Vector2.ZERO:
		if update_facing:
			facing_direction = direction
			facing_changed.emit(direction)
		velocity = velocity.move_toward(direction * target_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

func stop() -> void:
	velocity = Vector2.ZERO

func take_damage(amount: float, source: Node = null, knockback: Vector2 = Vector2.ZERO) -> void:
	if GameManager.god_mode and self == GameManager.player:
		return
	var final_amount: float = stats.compute_incoming_damage(amount) if stats else amount
	if health:
		health.take_damage(final_amount, source)
	if knockback != Vector2.ZERO:
		velocity = knockback

func is_dead() -> bool:
	return health != null and health.is_dead()

func _on_died() -> void:
	died.emit(self)
	Events.entity_died.emit(self)
