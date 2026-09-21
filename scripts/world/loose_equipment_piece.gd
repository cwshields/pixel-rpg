class_name LooseEquipmentPiece
extends RigidBody2D
## A hand/weapon sprite knocked loose from a dying enemy's equipment rig
## (see EnemyBase._break_loose_equipment()). Purely cosmetic debris, not
## a pickup or an obstacle: collision_layer is 0 so nothing ever targets
## it, while collision_mask still includes layer 1 (solid bodies) so it
## bumps off walls instead of sliding through them. gravity_scale is 0 —
## this is a top-down game, "falling" just means flung out and damped to
## a stop — so it tumbles briefly, lingers, then fades away like the
## corpse it fell off of (mirrors EnemyDeadState's linger-then-fade).

@export var linger_time: float = 8.0
@export var fade_time: float = 2.0

func _ready() -> void:
	_settle_and_fade()

## Sets the piece flying. `impulse` is the initial velocity (px/sec),
## `spin` the initial angular velocity (rad/sec).
func launch(impulse: Vector2, spin: float) -> void:
	linear_velocity = impulse
	angular_velocity = spin

func _settle_and_fade() -> void:
	await get_tree().create_timer(linger_time).timeout
	if not is_instance_valid(self):
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	await tween.finished
	if is_instance_valid(self):
		queue_free()
