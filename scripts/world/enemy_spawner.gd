class_name EnemySpawner
extends Marker2D
## A world-placed spawn point for enemies. Drop one into a scene, point
## `enemy_scene` at an enemy .tscn (defaults to the shared enemy_base in
## enemy_spawner.tscn), and it spawns a batch when the level loads. Set
## `max_alive` above 0 to have it refill that batch over time as enemies
## die, turning a marker into a continuously-populated encounter.
##
## Spawned enemies are parented to `spawn_into` — or this spawner's own
## parent when that's left empty — so they live alongside the rest of the
## world's entities rather than nested under the marker. Like the Tree
## prop, it doesn't care what it's parented under.

## Enemy scene to instance. Anything whose root extends EnemyBase works.
@export var enemy_scene: PackedScene

@export_group("Spawning")
## How many enemies the initial batch contains (and the number `max_alive`
## refilling tops back up toward).
@export_range(1, 50) var spawn_count: int = 1
## Each enemy is placed at a random point within this many pixels of the
## marker. 0 stacks them all exactly on it.
@export var spawn_radius: float = 24.0
## Spawn the initial batch automatically when the spawner enters the tree.
## Turn off to fire it yourself by calling `spawn_batch()`.
@export var spawn_on_ready: bool = true

@export_group("Respawning")
## 0 disables respawning — the initial batch is all you get. Above 0, the
## spawner keeps topping the live count back up to this number.
@export_range(0, 50) var max_alive: int = 0
## Seconds between refill checks while the live count is below `max_alive`.
@export var respawn_delay: float = 5.0

## Node to parent spawned enemies under. Falls back to this spawner's own
## parent when left unset.
@export var spawn_into: Node2D

## Enemies this spawner has produced that are still in the tree.
var _alive: Array[Node] = []

func _ready() -> void:
	if max_alive > 0:
		var timer := Timer.new()
		timer.wait_time = maxf(respawn_delay, 0.05)
		timer.autostart = true
		timer.timeout.connect(_on_respawn_tick)
		add_child(timer)
	if spawn_on_ready:
		# Deferred so the rest of the scene tree (and GameManager.player)
		# is settled before enemies start looking for a target.
		spawn_batch.call_deferred()

## Spawns up to `spawn_count` enemies now, never pushing the live count
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
	if not enemy_scene:
		push_warning("EnemySpawner at %s has no enemy_scene set." % global_position)
		return false
	var enemy := enemy_scene.instantiate() as Node2D
	if not enemy:
		push_warning("EnemySpawner: enemy_scene's root isn't a Node2D.")
		return false
	var parent: Node = spawn_into if spawn_into else get_parent()
	parent.add_child(enemy)
	enemy.global_position = _random_point()
	_alive.append(enemy)
	enemy.tree_exited.connect(_on_enemy_gone.bind(enemy))
	return true

func _on_enemy_gone(enemy: Node) -> void:
	_alive.erase(enemy)

func _random_point() -> Vector2:
	if spawn_radius <= 0.0:
		return global_position
	# sqrt(randf()) keeps the distribution even across the disc instead of
	# clumping toward the centre.
	var angle: float = randf() * TAU
	var dist: float = sqrt(randf()) * spawn_radius
	return global_position + Vector2(cos(angle), sin(angle)) * dist
