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

@export_group("Obstacle Avoidance")
## How far ahead `steer_direction()` looks for an obstacle, in pixels. 0
## disables steering entirely (movement still slides along walls via
## move_and_slide, it just won't pick a smarter heading beforehand).
@export var obstacle_look_ahead: float = 20.0
## Physics layers `steer_direction()` treats as obstacles to route
## around — defaults to layer 1, the world's static geometry (walls,
## trees, buildings).
@export_flags_2d_physics var obstacle_avoidance_mask: int = 1

## When true, `move()` targets `sprint_speed` instead of `move_speed`. Not
## persisted — whichever state is active owns setting and clearing it.
var sprinting: bool = false

## Last non-zero movement direction. Useful for aiming an attack or
## picking an idle-facing animation when the entity is standing still.
var facing_direction: Vector2 = Vector2.DOWN

@onready var health: HealthComponent = get_node_or_null("HealthComponent")
@onready var stats: StatsComponent = get_node_or_null("StatsComponent")
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
## The entity's own physical collision shape — used by `steer_direction()`
## to cast the entity's actual footprint (not a zero-width line) when
## feeling for obstacles. See `_direction_blocked()`.
@onready var _body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

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

## A cheap local steering check for AI movement (wandering, fleeing,
## chasing) — NOT used by the player, who's driven by direct input.
## Feels `obstacle_look_ahead` pixels along `desired_direction`; if it's
## clear, returns it unchanged. If it's blocked, fans outward in both
## directions (30°, 60°, 90°, 120°, 150°) and returns the first clear
## heading it finds, so a wandering/fleeing mob steers around a wall or
## tree instead of grinding face-first into it over and over. Returns
## Vector2.ZERO if every direction it tried is blocked (better to stop
## than shove into a corner). Reusable as-is by any EntityBase subclass —
## no extra nodes required beyond the body's own "CollisionShape2D", since
## it queries physics space directly.
##
## Pass `ignore_bodies` when steering toward/away from a specific body
## (a chase target, a flee threat) — otherwise, since mobs share the same
## physics layer as the world's static geometry, that body itself would
## start reading as a "wall" the moment it's within `obstacle_look_ahead`,
## and the mob would swerve off just as it closes the distance.
func steer_direction(desired_direction: Vector2, ignore_bodies: Array[Node2D] = []) -> Vector2:
	if obstacle_look_ahead <= 0.0 or desired_direction == Vector2.ZERO:
		return desired_direction
	var exclude: Array[RID] = [get_rid()]
	for body in ignore_bodies:
		if body is PhysicsBody2D:
			exclude.append((body as PhysicsBody2D).get_rid())
	if not _direction_blocked(desired_direction, exclude):
		return desired_direction
	for degrees in [30.0, 60.0, 90.0, 120.0, 150.0]:
		for side in [1.0, -1.0]:
			var candidate: Vector2 = desired_direction.rotated(deg_to_rad(degrees * side))
			if not _direction_blocked(candidate, exclude):
				return candidate
	return Vector2.ZERO

## Checks whether the entity's own body would fit `obstacle_look_ahead`
## pixels along `direction` — a shape cast using the entity's actual
## CollisionShape2D, not a zero-width ray. A ray from the node origin can
## slip past obstacles narrower than the body itself (the fox threading a
## tree's slim trunk box) or, near a jagged wall, read as newly "blocked"
## just because it starts flush against geometry the body is already
## touching (a fleeing hare pinned against a cliff edge) — both explained
## by the ray not matching the body's real footprint or offset. Casting
## the actual shape at the candidate point sidesteps both: it tests "would
## I fit there", not "is there anything along this thin line from here".
## Falls back to the old point-ray behavior if there's no CollisionShape2D
## to cast (rare — every current EntityBase subclass has one).
func _direction_blocked(direction: Vector2, exclude: Array[RID]) -> bool:
	var space_state := get_world_2d().direct_space_state
	if _body_shape == null or _body_shape.shape == null:
		var ray_query := PhysicsRayQueryParameters2D.create(
			global_position, global_position + direction.normalized() * obstacle_look_ahead)
		ray_query.collision_mask = obstacle_avoidance_mask
		ray_query.exclude = exclude
		return not space_state.intersect_ray(ray_query).is_empty()
	var destination: Vector2 = global_position + _body_shape.position + direction.normalized() * obstacle_look_ahead
	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = _body_shape.shape
	shape_query.transform = Transform2D(_body_shape.global_rotation, destination)
	shape_query.collision_mask = obstacle_avoidance_mask
	shape_query.exclude = exclude
	return not space_state.intersect_shape(shape_query, 1).is_empty()

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
