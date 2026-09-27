class_name EnemyWanderState
extends State
## Ambles to a random point within EnemyBase.wander_radius of the enemy's
## spawn anchor, then hands back to Idle — the enemy-side twin of
## CritterWanderState. Breaks off to Chase/Growl the moment the player
## gets close (see EnemyBase.player_reaction_state). Opt-in: EnemyIdleState
## only routes here when this node exists and wander_radius is above 0.

@export var arrival_distance: float = 4.0
@export var max_travel_time: float = 6.0

var _destination: Vector2
var _timer: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	var enemy := entity as EnemyBase
	var angle: float = randf() * TAU
	var dist: float = sqrt(randf()) * enemy.wander_radius
	_destination = enemy.anchor_position + Vector2(cos(angle), sin(angle)) * dist
	_timer = 0.0
	entity.play_animation("walk")

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	var reaction := enemy.player_reaction_state()
	if reaction != &"":
		transition_requested.emit(reaction, {})
		return
	_timer += delta
	var to_destination: Vector2 = _destination - entity.global_position
	if to_destination.length() <= arrival_distance or _timer >= max_travel_time:
		transition_requested.emit(&"Idle", {})
		return
	entity.move(entity.steer_direction(to_destination.normalized()), delta)
	entity.play_animation("walk")
