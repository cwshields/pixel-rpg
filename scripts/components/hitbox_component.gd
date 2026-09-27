class_name HitboxComponent
extends Area2D
## An attack's damage source — a sword swing, an arrow, a fireball. Leave
## `monitoring` off by default and switch it on only for the active
## frames of an attack (an attack State is the usual place to do this).
##
## Directional, frame-synced layouts: name direct CollisionShape2D children
## after the facing they belong to, optionally tagged with the animation
## frames they're live on (case-insensitive):
##   Down      — live for the attack's whole active window (time-based)
##   Down_3    — live only on animation frame 3
##   Down_3-5  — live on frames 3 through 5
## so a swing's hitbox can follow the blade's arc frame by frame. Drive it
## with update_pose() each physics tick; it toggles the shapes and
## `monitoring` itself. With no such children it falls back to rotating
## the whole Area2D to face the target (enemy/critter hitboxes).

@export var damage: float = 5.0
@export var knockback_force: float = 150.0
## Whoever is dealing this damage. Set by the owning entity so hitboxes
## don't hurt their own source and so death credit/loot can be attributed.
var source: Node = null

## Stretches a directional layout outward along the facing axis — e.g. 1.2
## for a longer sword reusing the standard slash shapes. Set by the owner
## (see Player._equip_attack()).
var reach_scale: float = 1.0

const _POSE_NAME := "^(up|down|left|right)(?:_(\\d+)(?:-(\\d+))?)?$"

## Direction ("up"/"down"/"left"/"right") -> Array of
## {shape: CollisionShape2D, from: int, to: int, timed: bool}. `timed`
## entries are the untagged ones, gated on the active window instead of
## the frame.
var _poses: Dictionary = {}
## Hurtboxes already struck since the last reset_hits(). Frame-tagged
## shapes switching on and off mid-swing re-fire area_entered for a target
## that's still inside, so without this one swing could hit it several
## times. Only used for directional layouts.
var _already_hit: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	var pattern := RegEx.create_from_string(_POSE_NAME)
	for child in get_children():
		if not child is CollisionShape2D:
			continue
		var result := pattern.search(String(child.name).to_lower())
		if result == null:
			continue
		var timed := result.get_string(2).is_empty()
		var from := 0 if timed else result.get_string(2).to_int()
		var to := from if result.get_string(3).is_empty() else result.get_string(3).to_int()
		if timed:
			to = 1 << 30
		var direction := result.get_string(1)
		if not _poses.has(direction):
			_poses[direction] = []
		_poses[direction].append({shape = child, from = from, to = to, timed = timed})
		(child as CollisionShape2D).disabled = true

## Positions the hitbox for the current moment of an attack: facing
## `direction`, showing animation `frame`, with `in_window` saying whether
## the time-based active window is open (see AttackDefinition). Enables
## only the matching shapes and turns `monitoring` on exactly when one is
## live. Without a directional layout, just rotates to face `direction`
## and leaves `monitoring` to the caller.
func update_pose(direction: Vector2, frame: int, in_window: bool) -> void:
	if _poses.is_empty():
		if direction != Vector2.ZERO:
			global_rotation = direction.angle()
		return
	var active_direction := EntityBase.cardinal_name(direction) if direction != Vector2.ZERO else ""
	var any_live := false
	for key in _poses:
		for pose in _poses[key]:
			var live: bool = key == active_direction and frame >= pose.from and frame <= pose.to \
					and (in_window or not pose.timed)
			(pose.shape as CollisionShape2D).disabled = not live
			any_live = any_live or live
	var vertical := active_direction == "up" or active_direction == "down"
	scale = Vector2(1.0, reach_scale) if vertical else Vector2(reach_scale, 1.0)
	if monitoring != any_live:
		monitoring = any_live

## True when this hitbox has Up/Down/Left/Right shapes that update_pose()
## drives (and so manages `monitoring` itself).
func has_directional_layout() -> bool:
	return not _poses.is_empty()

## Switches every shape off and stops monitoring — call when an attack
## ends or is interrupted.
func deactivate() -> void:
	for key in _poses:
		for pose in _poses[key]:
			(pose.shape as CollisionShape2D).disabled = true
	monitoring = false

## Starts a fresh swing: targets hit by the previous one can be hit again.
func reset_hits() -> void:
	_already_hit.clear()

func _on_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hurtbox := area as HurtboxComponent
	if source and hurtbox.get_parent() == source:
		return
	if not _poses.is_empty():
		if _already_hit.has(hurtbox.get_instance_id()):
			return
		_already_hit[hurtbox.get_instance_id()] = true
	var knockback: Vector2 = Vector2.ZERO
	if source and source is Node2D and hurtbox.get_parent() is Node2D:
		var away: Vector2 = hurtbox.get_parent().global_position - (source as Node2D).global_position
		knockback = away.normalized() * knockback_force if away.length() > 0.0 else Vector2.ZERO
	hurtbox.receive_hit(damage, source, knockback)
