class_name HealthComponent
extends Node
## Tracks HP for whatever it's attached to. Drop it as a child of any
## entity (player, enemy, NPC, or even an inanimate breakable crate) —
## nothing about this component assumes what it's attached to.

signal health_changed(current: float, max: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died

@export var max_health: float = 20.0
## Brief damage immunity after a hit, so one swing can't multi-tick
## through overlapping hurtbox frames.
@export var invulnerability_time: float = 0.4

var current_health: float
var _invulnerable_timer: float = 0.0

func _ready() -> void:
	current_health = max_health

func _process(delta: float) -> void:
	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta

func is_invulnerable() -> bool:
	return _invulnerable_timer > 0.0

func is_dead() -> bool:
	return current_health <= 0.0

func take_damage(amount: float, source: Node = null) -> void:
	if is_dead() or is_invulnerable() or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	_invulnerable_timer = invulnerability_time
	damaged.emit(amount, source)
	health_changed.emit(current_health, max_health)
	Events.health_changed.emit(get_parent(), current_health, max_health)
	if current_health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)
	Events.health_changed.emit(get_parent(), current_health, max_health)

## Brings an entity back to `amount` HP — full health by default. Unlike
## heal(), this works when current_health is already 0, which is what a
## respawn needs, and it clears any lingering invulnerability.
func revive(amount: float = -1.0) -> void:
	current_health = max_health if amount < 0.0 else clampf(amount, 0.0, max_health)
	_invulnerable_timer = 0.0
	healed.emit(current_health)
	health_changed.emit(current_health, max_health)
	Events.health_changed.emit(get_parent(), current_health, max_health)

func set_max_health(new_max: float, refill: bool = false) -> void:
	max_health = new_max
	current_health = max_health if refill else minf(current_health, max_health)
	health_changed.emit(current_health, max_health)
