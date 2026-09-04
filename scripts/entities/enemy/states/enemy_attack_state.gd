class_name EnemyAttackState
extends State

@export var attack_cooldown: float = 1.0
@export var windup_time: float = 0.25

var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	entity.stop()
	var enemy := entity as EnemyBase
	if enemy.hitbox:
		enemy.hitbox.damage = enemy.stats.compute_outgoing_damage() if enemy.stats else enemy.hitbox.damage
	entity.play_animation("attack")

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	_timer += delta
	if enemy.hitbox:
		enemy.hitbox.monitoring = _timer >= windup_time
	if _timer >= attack_cooldown:
		if enemy.hitbox:
			enemy.hitbox.monitoring = false
		transition_requested.emit(&"Chase" if enemy.target else &"Idle", {})

func exit() -> void:
	var enemy := entity as EnemyBase
	if enemy.hitbox:
		enemy.hitbox.monitoring = false
