class_name EnemyIdleState
extends State
## Stands still until a target wanders into detection range. If this
## enemy roams (a "Wander" state node + EnemyBase.wander_radius above 0,
## e.g. the wolf), hands off to Wander after a random pause, same shape
## as CritterIdleState; otherwise it just stands its ground indefinitely.

@export var min_idle_time: float = 2.0
@export var max_idle_time: float = 5.0

var _timer: float = 0.0
var _idle_time: float = 0.0

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	entity.stop()
	entity.play_animation("idle")
	_timer = 0.0
	_idle_time = randf_range(min_idle_time, max_idle_time)

func process_physics(delta: float) -> void:
	var enemy := entity as EnemyBase
	# Routes through a "Growl" warning state first if this enemy has one
	# (see EnemyBase.player_reaction_state) — enemies without it (the
	# skeleton) only react once `target` fires.
	var reaction := enemy.player_reaction_state()
	if reaction != &"":
		transition_requested.emit(reaction, {})
		return
	entity.move(Vector2.ZERO, delta)
	_timer += delta
	if _timer >= _idle_time and enemy.wander_radius > 0.0 and enemy.state_machine.states.has(&"Wander"):
		transition_requested.emit(&"Wander", {})
