class_name PlayerAttackState
extends State
## Swings whatever's in HitboxComponent. The hitbox only actually damages
## anything while `monitoring` is true, so we window that to the "active"
## portion of the swing instead of the whole animation.

## Tuned to the Slice animation (8 frames @ 14fps ≈ 0.57s); adjust if you
## swap in a different attack animation/weapon speed.
@export var attack_duration: float = 0.6
@export var hitbox_active_start: float = 0.2
@export var hitbox_active_end: float = 0.45

var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	entity.stop()
	var player := entity as Player
	if player.hitbox:
		player.hitbox.global_rotation = player.facing_direction.angle()
		player.hitbox.damage = player.stats.compute_outgoing_damage() if player.stats else player.hitbox.damage
	entity.play_animation("attack")

func process_physics(delta: float) -> void:
	_timer += delta
	var player := entity as Player
	if player.hitbox:
		player.hitbox.monitoring = _timer >= hitbox_active_start and _timer <= hitbox_active_end
	if _timer >= attack_duration:
		transition_requested.emit(&"Idle", {})

func exit() -> void:
	var player := entity as Player
	if player.hitbox:
		player.hitbox.monitoring = false
