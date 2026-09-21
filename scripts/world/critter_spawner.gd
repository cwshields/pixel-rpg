class_name CritterSpawner
extends Marker2D
## A world-placed spawn point for ambient wildlife. Drop one into a scene,
## point `critter_scene` at a critter .tscn (boar/deer/fox/hare/black
## grouse under scenes/entities/critter), and it spawns a batch when the
## level loads. Set `max_alive` above 0 to have it refill that batch over
## time as critters die, turning a marker into a continuously-populated
## patch of wildlife.
##
## Spawned critters are parented to `spawn_into` — or this spawner's own
## parent when that's left empty — so they live alongside the rest of the
## world's entities rather than nested under the marker. Mirrors
## EnemySpawner; kept separate since critters are a distinct, non-hostile
## population.

## Critter scene to instance. Anything whose root extends CritterBase works.
@export var critter_scene: PackedScene

@export_group("Spawning")
## How many critters the initial batch contains (and the number
## `max_alive` refilling tops back up toward).
@export_range(1, 50) var spawn_count: int = 1
## Each critter is placed at a random point within this many pixels of
## the marker. 0 stacks them all exactly on it.
@export var spawn_radius: float = 48.0
## Spawn the initial batch automatically when the spawner enters the tree.
## Turn off to fire it yourself by calling `spawn_batch()`.
@export var spawn_on_ready: bool = true

@export_group("Respawning")
## 0 disables respawning — the initial batch is all you get. Above 0, the
## spawner keeps topping the live count back up to this number.
@export_range(0, 50) var max_alive: int = 0
## Seconds between refill checks while the live count is below `max_alive`.
@export var respawn_delay: float = 5.0

## Node to parent spawned critters under. Falls back to this spawner's
## own parent when left unset.
@export var spawn_into: Node2D

## Critters this spawner has produced that are still in the tree.
var _alive: Array[Node] = []

func _ready() -> void:
	if max_alive > 0:
		var timer := Timer.new()
		timer.wait_time = maxf(respawn_delay, 0.05)
		timer.autostart = true
		timer.timeout.connect(_on_respawn_tick)
		add_child(timer)
	if spawn_on_ready:
		# Deferred so the rest of the scene tree is settled before
		# critters start looking for their spawn anchor.
		spawn_batch.call_deferred()

## Spawns up to `spawn_count` critters now, never pushing the live count
## past `max_alive` while that cap is active. Returns how many spawned.
func spawn_batch() -> int:
	var budget: int = spawn_count
	if max_alive > 0:
		budget = mini(budget, max_alive - _alive.size())
	var spawned: int = 0
	for _i in maxi(budget, 0):
		if _spawn_one():
			spawned += 1
	return spawned

func _on_respawn_tick() -> void:
	if _alive.size() < max_alive:
		_spawn_one()

func _spawn_one() -> bool:
	if not critter_scene:
		push_warning("CritterSpawner at %s has no critter_scene set." % global_position)
		return false
	var critter := critter_scene.instantiate() as Node2D
	if not critter:
		push_warning("CritterSpawner: critter_scene's root isn't a Node2D.")
		return false
	var parent: Node = spawn_into if spawn_into else get_parent()
	parent.add_child(critter)
	critter.global_position = _random_point()
	if critter is CritterBase:
		# CritterBase._ready() already ran during add_child() above and
		# captured anchor_position from the position it had *before* the
		# line above — (0, 0), the scene's unset default — not the real
		# spawn point. Patch it now so wandering stays anchored to where
		# this critter actually landed instead of drifting toward the
		# world origin.
		(critter as CritterBase).anchor_position = critter.global_position
	_alive.append(critter)
	critter.tree_exited.connect(_on_critter_gone.bind(critter))
	return true

func _on_critter_gone(critter: Node) -> void:
	_alive.erase(critter)

func _random_point() -> Vector2:
	if spawn_radius <= 0.0:
		return global_position
	# sqrt(randf()) keeps the distribution even across the disc instead of
	# clumping toward the centre.
	var angle: float = randf() * TAU
	var dist: float = sqrt(randf()) * spawn_radius
	return global_position + Vector2(cos(angle), sin(angle)) * dist
