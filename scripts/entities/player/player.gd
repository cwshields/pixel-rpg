class_name Player
extends EntityBase
## The player-controlled hero. Reads input, drives its StateMachine, and
## owns the Inventory/Equipment the rest of the game (UI, item pickups,
## save system) reads from via GameManager.player.

var inventory: Inventory = Inventory.new(12, 9)
var equipment: Equipment = Equipment.new()
var gold: int = 0
@export var max_carry_weight: float = 120.0

@onready var state_machine: StateMachine = $StateMachine
@onready var stamina: StaminaComponent = get_node_or_null("StaminaComponent")
@onready var interaction_detector: Area2D = get_node_or_null("InteractionDetector")
## Detects a RockProp's physical StaticBody2D (collision layer 1, same as
## every other solid) coming within mining range — unlike InteractionDetector
## this masks onto bodies, not areas, since RockProp exposes no
## InteractionComponent of its own. See is_near_rock().
@onready var mine_detector: Area2D = get_node_or_null("MineDetector")

## Damage dealt per mining hitbox pulse (see PlayerIdleState), applied to
## `mine_hitbox` — its own hitbox, separate from the combat one, whose
## damage PlayerAttackState rescales from weapon/stats on every swing.
@export var mine_damage: float = 4.0

## Attack used with no weapon equipped (or a weapon with no attack).
const DEFAULT_ATTACK: AttackDefinition = preload("res://resources/combat/attacks/slash.tres")
## The pickaxe "crush" loop PlayerIdleState runs while mining.
const MINE_ATTACK: AttackDefinition = preload("res://resources/combat/attacks/crush.tres")
## The axe swing loop PlayerIdleState runs while chopping trees.
const CHOP_ATTACK: AttackDefinition = preload("res://resources/combat/attacks/slash.tres")

## The current combat attack (from the equipped weapon) and the hitbox
## instanced from its hitbox_scene. Rebuilt by _equip_attack() whenever
## the weapon slot changes, so read these fresh rather than caching them.
var attack: AttackDefinition
var hitbox: HitboxComponent
var mine_hitbox: HitboxComponent
var chop_hitbox: HitboxComponent

@export var chop_damage: float = 4.0

var _nearby_interactables: Array[InteractionComponent] = []
var _nearby_rocks: Array[RockProp] = []
var _nearby_trees: Array[TreeProp] = []
var _exhausted_flash: Tween

func _ready() -> void:
	super._ready()
	z_index = OccluderProp.PLAYER_Z_INDEX
	inventory.unlocked_rows = 5
	equipment.owner_stats = stats
	equipment.changed.connect(func(slot: Equipment.Slot) -> void:
		if slot == Equipment.Slot.PRIMARY_HAND:
			_equip_attack())
	_equip_attack()
	mine_hitbox = _spawn_hitbox(MINE_ATTACK)
	if mine_hitbox:
		mine_hitbox.damage = mine_damage
		mine_hitbox.is_mining = true
	chop_hitbox = _spawn_hitbox(CHOP_ATTACK)
	if chop_hitbox:
		chop_hitbox.damage = chop_damage
		chop_hitbox.is_chopping = true
	if interaction_detector:
		interaction_detector.area_entered.connect(_on_interactable_entered)
		interaction_detector.area_exited.connect(_on_interactable_exited)
	if mine_detector:
		mine_detector.body_entered.connect(_on_mine_body_entered)
		mine_detector.body_exited.connect(_on_mine_body_exited)
	if health:
		health.damaged.connect(func(_amount: float, _source: Node) -> void: state_machine.transition_to(&"Hurt"))
		health.died.connect(func() -> void: state_machine.transition_to(&"Dead"))
	GameManager.register_player(self)

## Swaps in the equipped weapon's attack (DEFAULT_ATTACK if unarmed) and
## rebuilds `hitbox` from its hitbox_scene.
func _equip_attack() -> void:
	var weapon := equipment.get_equipped(Equipment.Slot.PRIMARY_HAND) as Weapon
	var next: AttackDefinition = weapon.get_attack() if weapon else null
	if next == null:
		next = DEFAULT_ATTACK
	if hitbox:
		hitbox.queue_free()
	attack = next
	hitbox = _spawn_hitbox(attack)
	if hitbox and weapon:
		hitbox.reach_scale = weapon.reach_scale

func _spawn_hitbox(def: AttackDefinition) -> HitboxComponent:
	if def == null or def.hitbox_scene == null:
		return null
	var instance := def.hitbox_scene.instantiate() as HitboxComponent
	if instance == null:
		return null
	instance.source = self
	instance.monitoring = false
	add_child(instance)
	return instance

## 8-directional analog input. Returns a normalized-or-zero Vector2.
func get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

## True while the sprint key (Shift) is held. Raw input only — use
## can_sprint() for the "should we actually run" decision.
func wants_to_sprint() -> bool:
	return Input.is_action_pressed("sprint")

## True when the sprint key is held AND the stamina pool has something
## left to spend. Movement states gate run speed + run animations on this;
## only meaningful while actually moving. With no StaminaComponent the
## player can always sprint.
func can_sprint() -> bool:
	return wants_to_sprint() and (stamina == null or stamina.can_sprint())

## True when the stamina pool isn't empty, so a swing can be started. The
## movement states check this before entering the Attack state. With no
## StaminaComponent the player can always attack.
func can_attack() -> bool:
	return stamina == null or stamina.can_attack()

func is_mouse_over_gui() -> bool:
	return get_viewport().gui_get_hovered_control() != null

## Brief red pulse on the sprite when a stamina-gated action (an attack
## swing) is denied for an empty pool. Purely cosmetic and safe to spam —
## a fresh call restarts the pulse.
func flash_exhausted() -> void:
	if not animated_sprite:
		return
	if _exhausted_flash and _exhausted_flash.is_valid():
		_exhausted_flash.kill()
	animated_sprite.modulate = Color(1.0, 0.45, 0.45)
	_exhausted_flash = create_tween()
	_exhausted_flash.tween_property(animated_sprite, "modulate", Color.WHITE, 0.18)

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_playing():
		return
	if event.is_action_pressed("interact"):
		_interact_with_nearest()

func _interact_with_nearest() -> void:
	for area in _nearby_interactables:
		if is_instance_valid(area) and area.can_interact(self):
			area.interact(self)
			return

func _on_interactable_entered(area: Area2D) -> void:
	if area is InteractionComponent:
		_nearby_interactables.append(area)

func _on_interactable_exited(area: Area2D) -> void:
	if area is InteractionComponent:
		_nearby_interactables.erase(area)

## True while any RockProp's collision body overlaps MineDetector.
func is_near_rock() -> bool:
	return not _nearby_rocks.is_empty()

func is_near_tree() -> bool:
	return not _nearby_trees.is_empty()

## True when the cursor is hovering a rock within mining range — used by
## movement/idle states to decide whether an attack press should start
## mining (transition to Idle) rather than a combat swing. Doesn't check
## facing or the attack button, so the state can face_toward_mouse()
## first and then let is_mining_rock() do the full gate.
func wants_to_mine_rock() -> bool:
	if is_mouse_over_gui():
		return false
	var cursor := GameManager.cursor
	if not cursor or not cursor.hovered_rock:
		return false
	return cursor.hovered_rock in _nearby_rocks

## True while the player is both standing next to a rock AND actively
## clicking it — the "attack" button held while GameManager.cursor's
## hover happens to be that same nearby rock, not just held down anywhere
## while a rock happens to be close by — AND currently facing roughly
## toward it (not turned away or backed into it), so standing with your
## back to a rock and clicking doesn't start mining through your own
## body. Used by PlayerIdleState to swap the plain idle animation for
## "crush" (swinging a pickaxe).
func is_mining_rock() -> bool:
	if not Input.is_action_pressed("attack") or is_mouse_over_gui():
		return false
	var cursor := GameManager.cursor
	if not cursor or not cursor.hovered_rock:
		return false
	var rock: RockProp = cursor.hovered_rock
	if rock not in _nearby_rocks:
		return false
	var to_rock: Vector2 = rock.global_position - global_position
	return to_rock == Vector2.ZERO or facing_direction.dot(to_rock.normalized()) > 0.0

## Snaps `facing_direction` to aim straight at the mouse cursor — same aim
## logic PlayerAttackState uses for a sword swing, reused here so mining
## keeps the player visually oriented at the rock while the button's held.
func face_toward_mouse() -> void:
	var aim := get_global_mouse_position() - global_position
	if aim != Vector2.ZERO:
		facing_direction = aim.normalized()
		facing_changed.emit(facing_direction)

func wants_to_chop_tree() -> bool:
	if is_mouse_over_gui():
		return false
	var cursor := GameManager.cursor
	if not cursor or not cursor.hovered_tree:
		return false
	return cursor.hovered_tree in _nearby_trees

func is_chopping_tree() -> bool:
	if not Input.is_action_pressed("attack") or is_mouse_over_gui():
		return false
	var cursor := GameManager.cursor
	if not cursor or not cursor.hovered_tree:
		return false
	var tree: TreeProp = cursor.hovered_tree
	if tree not in _nearby_trees:
		return false
	var to_tree: Vector2 = tree.global_position - global_position
	return to_tree == Vector2.ZERO or facing_direction.dot(to_tree.normalized()) > 0.0

func _on_mine_body_entered(body: Node2D) -> void:
	var parent := body.get_parent()
	if parent is RockProp and parent not in _nearby_rocks:
		_nearby_rocks.append(parent)
	elif parent is TreeProp and parent not in _nearby_trees:
		_nearby_trees.append(parent)

func _on_mine_body_exited(body: Node2D) -> void:
	var parent := body.get_parent()
	if parent is RockProp:
		_nearby_rocks.erase(parent)
	elif parent is TreeProp:
		_nearby_trees.erase(parent)

## Adds an item to the inventory and broadcasts the pickup. Returns
## whatever didn't fit (0 if it all fit), same contract as Inventory.add_item.
func pickup_item(item: ItemBase, amount: int = 1) -> int:
	var leftover := inventory.add_item(item, amount)
	if amount - leftover > 0:
		Events.item_picked_up.emit(item, amount - leftover)
	return leftover
