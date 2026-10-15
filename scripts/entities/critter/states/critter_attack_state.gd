class_name CritterAttackState
extends State
## Strikes at whatever CritterBase.pursuit_target() returns — a hostile
## threat, or, for a predator, hunted prey (see CritterChaseState). Same
## shape as EnemyAttackState, but aims the hitbox at whatever direction
## the target was in when the attack started, since a critter's art
## (unlike the single-direction enemy sprites) actually faces all 4 ways.

@export var attack_cooldown: float = 1.0
@export var windup_time: float = 0.3
## Local-space distance to push the hitbox out toward the target.
@export var hitbox_reach: float = 10.0
## When the target is hunted prey, keep sprinting at it through the bite.
@export var lunge_at_prey: bool = false

var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	var critter := entity as CritterBase
	var target := critter.pursuit_target()
	var hunting_prey := lunge_at_prey and target and target == critter.hunt_target
	if hunting_prey:
		entity.sprinting = true
	else:
		entity.stop()
	if critter.hitbox:
		critter.hitbox.damage = critter.stats.compute_outgoing_damage() if critter.stats else critter.hitbox.damage
		if target:
			var to_target: Vector2 = target.global_position - entity.global_position
			if to_target.length() > 0.001:
				critter.hitbox.position = to_target.normalized() * hitbox_reach
	entity.play_animation("attack")

func process_physics(delta: float) -> void:
	var critter := entity as CritterBase
	_timer += delta
	var target := critter.pursuit_target()
	if lunge_at_prey and target and target == critter.hunt_target:
		var to_target: Vector2 = target.global_position - entity.global_position
		entity.sprinting = true
		entity.move(entity.steer_direction(to_target.normalized(), [target]), delta)
		if critter.hitbox:
			critter.hitbox.position = entity.facing_direction.normalized() * hitbox_reach
	else:
		entity.move(Vector2.ZERO, delta)
	if critter.hitbox:
		critter.hitbox.monitoring = _timer >= windup_time
	if _timer >= attack_cooldown:
		if critter.hitbox:
			critter.hitbox.monitoring = false
		transition_requested.emit(&"Chase" if critter.pursuit_target() else &"Idle", {})

func exit() -> void:
	entity.sprinting = false
	var critter := entity as CritterBase
	if critter.hitbox:
		critter.hitbox.monitoring = false
