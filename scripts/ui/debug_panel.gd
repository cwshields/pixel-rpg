class_name DebugPanel
extends CanvasLayer
## Developer-only overlay pinned to the top-right of the screen for poking
## at the running game. Instanced once in main.tscn; it deletes itself in
## non-debug builds so it can stay wired up permanently.
##
## "Spawn Enemy" enters placement mode: a translucent copy of the enemy's
## sprite tracks the cursor, left-click drops a live enemy there (repeat as
## many times as you like), right-click or Esc leaves the mode. While
## placing, the player's state machine is frozen so the placement click
## doesn't also swing their weapon or move them.
##
## "Respawn Player" is enabled only while the player is dead; it refills
## their health, sends them back to World/PlayerSpawn, and drops them into
## the Idle state.
##
## "Heal Player" is enabled while the player is alive and below full HP;
## it tops their health back up to max.

## Enemy scene to drop. Any scene whose root extends EnemyBase works.
@export var enemy_scene: PackedScene = preload("res://scenes/entities/enemy/enemy_base.tscn")

## Node (relative to the current scene) that dropped enemies are parented
## under. Falls back to the scene root when it can't be found.
@export var spawn_into_path: NodePath = ^"Entities"

@onready var _spawn_button: Button = %SpawnEnemyButton
@onready var _respawn_button: Button = %RespawnPlayerButton
@onready var _heal_button: Button = %HealPlayerButton
@onready var _hint: Label = %Hint

var _placing: bool = false
var _ghost: Node2D = null

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_spawn_button.pressed.connect(_toggle_placing)
	_respawn_button.pressed.connect(_respawn_player)
	_heal_button.pressed.connect(_heal_player)
	Events.entity_died.connect(_on_player_state_maybe_changed)
	Events.health_changed.connect(func(entity: Node, _c: float, _m: float) -> void:
		_on_player_state_maybe_changed(entity))
	Events.player_spawned.connect(func(_p: Node) -> void: _refresh_buttons())
	_hint.hide()
	_refresh_buttons()

func _process(_delta: float) -> void:
	if _placing and is_instance_valid(_ghost):
		_ghost.global_position = _ghost.get_global_mouse_position().round()

func _unhandled_input(event: InputEvent) -> void:
	if not _placing:
		return
	if event.is_action_pressed(&"pause"):
		_stop_placing()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_spawn_enemy_at(_ghost.get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_stop_placing()
			get_viewport().set_input_as_handled()

# --- Enemy placement -------------------------------------------------------

func _toggle_placing() -> void:
	if _placing:
		_stop_placing()
	else:
		_start_placing()

func _start_placing() -> void:
	if not enemy_scene:
		push_warning("DebugPanel: no enemy_scene set.")
		return
	_placing = true
	_ghost = _build_ghost()
	if _ghost:
		_target_parent().add_child(_ghost)
		_ghost.global_position = _ghost.get_global_mouse_position().round()
	_spawn_button.text = "Stop Placing"
	_hint.show()
	_set_player_frozen(true)

func _stop_placing() -> void:
	if not _placing:
		return
	_placing = false
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_spawn_button.text = "Spawn Enemy"
	_hint.hide()
	_set_player_frozen(false)

func _spawn_enemy_at(world_pos: Vector2) -> void:
	var enemy := enemy_scene.instantiate() as Node2D
	if not enemy:
		push_warning("DebugPanel: enemy_scene's root isn't a Node2D.")
		return
	_target_parent().add_child(enemy)
	enemy.global_position = world_pos.round()

## A dim, non-interactive AnimatedSprite2D mirroring the enemy's own
## sprite, used as the cursor preview while placing.
func _build_ghost() -> Node2D:
	var ghost := AnimatedSprite2D.new()
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.45)
	ghost.z_index = 4096
	ghost.top_level = true  # position is world-space, ignore parent transform
	var probe := enemy_scene.instantiate()
	for child in probe.find_children("*", "AnimatedSprite2D", true, false):
		var src := child as AnimatedSprite2D
		if src.sprite_frames:
			ghost.sprite_frames = src.sprite_frames
			var anim: StringName = src.animation
			if not src.sprite_frames.has_animation(anim):
				var names := src.sprite_frames.get_animation_names()
				anim = StringName(names[0]) if not names.is_empty() else anim
			ghost.animation = anim
			ghost.play()
		break
	probe.free()
	return ghost

func _target_parent() -> Node:
	var scene := get_tree().current_scene
	var node := scene.get_node_or_null(spawn_into_path)
	return node if node else scene

## Freezes/unfreezes the player's StateMachine so a placement click can't
## leak through as an attack, and the player doesn't drift while we work.
func _set_player_frozen(frozen: bool) -> void:
	var player := GameManager.player as Player
	if not player:
		return
	var sm := player.state_machine
	if not sm:
		return
	sm.set_process(not frozen)
	sm.set_physics_process(not frozen)
	sm.set_process_unhandled_input(not frozen)
	if frozen:
		player.velocity = Vector2.ZERO

# --- Player respawn ------------------------------------------------------

func _respawn_player() -> void:
	var player := GameManager.player as Player
	if not player:
		return
	if player.health:
		player.health.revive()
	player.set_process(true)
	player.set_physics_process(true)
	player.velocity = Vector2.ZERO
	var spawn := get_tree().current_scene.get_node_or_null(^"World/PlayerSpawn") as Node2D
	if spawn:
		player.global_position = spawn.global_position
	if player.state_machine:
		player.state_machine.set_process(true)
		player.state_machine.set_physics_process(true)
		player.state_machine.set_process_unhandled_input(true)
		player.state_machine.transition_to(&"Idle")
	GameManager.set_state(GameManager.GameState.PLAYING)
	_refresh_buttons()

# --- Player heal -------------------------------------------------------

func _heal_player() -> void:
	var player := GameManager.player as Player
	if not player or not player.health:
		return
	player.health.revive()  # revive() tops up to max and works even at 0 HP
	_refresh_buttons()

func _on_player_state_maybe_changed(entity: Node) -> void:
	if entity == GameManager.player:
		_refresh_buttons()

func _refresh_buttons() -> void:
	var player := GameManager.player as EntityBase
	_respawn_button.disabled = player == null or not player.is_dead()
	var health := player.health if player else null
	_heal_button.disabled = health == null or health.is_dead() \
		or health.current_health >= health.max_health
