class_name StaminaComponent
extends Node
## Stamina pool for effortful actions. Drains continuously while
## `sprinting` is true (the driving movement state sets that every physics
## frame), takes a flat hit per attack via spend_attack(), and refills the
## rest of the time. Drop it on any entity whose movement code sets
## `sprinting` and gates its run speed on `can_sprint()` — nothing here
## assumes the player specifically.
##
## Mirrors HealthComponent: it owns its number, clamps it, and broadcasts
## every change on Events.stamina_changed so the HUD bar can follow along
## without holding a reference to us.

signal stamina_changed(current: float, max: float)
## Emitted the instant the pool hits 0 (sprint is now locked out).
signal exhausted
## Emitted when the pool has refilled far enough to sprint again after an
## exhaustion (see `sprint_resume_threshold`).
signal recovered

## Total stamina, and the amount the pool starts full at. Raise this to
## make sprints last longer.
@export var max_stamina: float = 100.0
## Stamina refilled per second while not sprinting.
@export var regen_rate: float = 5.0
## Stamina drained per second while sprinting.
@export var sprint_cost: float = 10.0
## Stamina spent per attack swing (a flat, one-off cost, not per second).
@export var attack_cost: float = 15.0
## After the pool bottoms out at 0, sprinting stays locked until it
## regenerates back up to this value — this stops a 1-frame flicker
## between run and walk when holding sprint on an empty bar. Set to 0 for
## "any stamina at all lets you sprint".
@export var sprint_resume_threshold: float = 20.0

## Set by the driving state each physics frame (see PlayerMoveState).
## True only while the entity is actually sprint-moving; cleared when that
## state exits.
var sprinting: bool = false

var current_stamina: float
var _exhausted: bool = false

func _ready() -> void:
	current_stamina = max_stamina
	_emit_changed()

func _physics_process(delta: float) -> void:
	if sprinting and can_sprint() and not _is_player_god_mode():
		current_stamina = maxf(current_stamina - sprint_cost * delta, 0.0)
		_emit_changed()
		if current_stamina == 0.0 and not _exhausted:
			_exhausted = true
			exhausted.emit()
	elif current_stamina < max_stamina:
		current_stamina = minf(current_stamina + regen_rate * delta, max_stamina)
		_emit_changed()
		if _exhausted and current_stamina >= minf(sprint_resume_threshold, max_stamina):
			_exhausted = false
			recovered.emit()

## True when there's stamina to start or keep sprinting. After a full
## drain this stays false until the pool climbs back to
## `sprint_resume_threshold`.
func can_sprint() -> bool:
	return not _exhausted and current_stamina > 0.0

## True when the pool can cover a whole swing. Requiring the full
## `attack_cost` up front (rather than "any stamina at all") is what
## actually gates attacks once the bar is low — otherwise regen keeps
## nudging it a sliver above 0 and every press slips through.
func can_attack() -> bool:
	return current_stamina >= attack_cost

## Immediately deducts a flat amount for a one-off action (an attack swing,
## a dodge...). Clamps at 0 and latches exhaustion if it bottoms out, just
## like a fully drained sprint. Returns true if the pool covered the whole
## cost (it still spends whatever's left when it doesn't).
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if _is_player_god_mode():
		return true
	var had_enough := current_stamina >= amount
	current_stamina = maxf(current_stamina - amount, 0.0)
	_emit_changed()
	if current_stamina == 0.0 and not _exhausted:
		_exhausted = true
		exhausted.emit()
	return had_enough

## Convenience wrapper for the attack state: spends one swing's worth
## (`attack_cost`).
func spend_attack() -> bool:
	return spend(attack_cost)

## Runtime setter that keeps `current_stamina` in range. `refill` tops the
## pool back off; otherwise it's only clamped down to the new maximum.
func set_max_stamina(new_max: float, refill: bool = false) -> void:
	max_stamina = maxf(new_max, 0.0)
	current_stamina = max_stamina if refill else minf(current_stamina, max_stamina)
	if current_stamina > 0.0:
		_exhausted = false
	_emit_changed()

func _emit_changed() -> void:
	stamina_changed.emit(current_stamina, max_stamina)
	Events.stamina_changed.emit(get_parent(), current_stamina, max_stamina)

## True while this component belongs to the player and GameManager.god_mode
## is on — stamina costs are skipped entirely.
func _is_player_god_mode() -> bool:
	return GameManager.god_mode and get_parent() == GameManager.player
