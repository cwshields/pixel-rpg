class_name EnemyAttackState
extends State
## Strikes at whatever EnemyBase.pursuit_target() returns — the player or
## hunted prey (see EnemyChaseState). Turns to face the target and mirrors
## the hitbox's horizontal offset to that side first, since enemy art only
## faces right and flips via flip_h — without this, a hitbox authored on
## the right would whiff at anything to the enemy's left.

@export var attack_cooldown: float = 1.0
@export var windup_time: float = 0.25
## When the target is hunted prey (not the player), keep sprinting at it
## through the bite instead of planting in place — a fleeing animal is
## long gone by the end of a standing windup.
@export var lunge_at_prey: bool = true

var _timer: float = 0.0
var _hitbox_offset_x: float = NAN
var _hitbox_offset_y: float = NAN

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	var enemy := entity as EnemyBase
	var attack_target := enemy.pursuit_target()
	var hunting_prey := lunge_at_prey and attack_target and attack_target == enemy.hunt_target
	if not hunting_prey:
		entity.stop()
	if attack_target:
		var to_target: Vector2 = attack_target.global_position - entity.global_position
		if to_target.length() > 0.001:
			entity.facing_direction = to_target.normalized()
	if enemy.hitbox:
		enemy.hitbox.damage = enemy.stats.compute_outgoing_damage() if enemy.stats else enemy.hitbox.damage
		if is_nan(_hitbox_offset_x):
			_hitbox_offset_x = absf(enemy.hitbox.position.x)
			_hitbox_offset_y = enemy.hitbox.position.y
		_position_hitbox(enemy)
	entity.play_animation("attack")
	var attack_sound := entity.get_node_or_null("AttackSoundPlayer") as AudioStreamPlayer2D
	if attack_sound:
		attack_sound.play()

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	_timer += delta
	var attack_target := enemy.pursuit_target()
	if lunge_at_prey and attack_target and attack_target == enemy.hunt_target:
		var to_target: Vector2 = attack_target.global_position - entity.global_position
		entity.sprinting = true
		entity.move(entity.steer_direction(to_target.normalized(), [attack_target]), delta)
		if enemy.hitbox:
			_position_hitbox(enemy)
	else:
		entity.move(Vector2.ZERO, delta)
	if enemy.hitbox:
		enemy.hitbox.monitoring = _timer >= windup_time
	if _timer >= attack_cooldown:
		if enemy.hitbox:
			enemy.hitbox.monitoring = false
		transition_requested.emit(&"Chase" if enemy.pursuit_target() else &"Idle", {})

func exit() -> void:
	entity.sprinting = false
	var enemy := entity as EnemyBase
	if enemy.hitbox:
		enemy.hitbox.monitoring = false
		enemy.hitbox.rotation = 0.0

func _position_hitbox(enemy: EnemyBase) -> void:
	var cardinal := EntityBase.cardinal_name(entity.facing_direction)
	match cardinal:
		"right":
			enemy.hitbox.position = Vector2(_hitbox_offset_x, _hitbox_offset_y)
			enemy.hitbox.rotation = 0.0
		"left":
			enemy.hitbox.position = Vector2(-_hitbox_offset_x, _hitbox_offset_y)
			enemy.hitbox.rotation = 0.0
		"down":
			enemy.hitbox.position = Vector2(0.0, _hitbox_offset_x)
			enemy.hitbox.rotation = PI * 0.5
		"up":
			enemy.hitbox.position = Vector2(0.0, -_hitbox_offset_x)
			enemy.hitbox.rotation = -PI * 0.5
