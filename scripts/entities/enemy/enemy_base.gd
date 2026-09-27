class_name EnemyBase
extends EntityBase
## Shared behavior for hostile creatures. A StateMachine drives the AI
## (Idle/Chase/Attack/Hurt/Dead), a DetectionArea finds the player to
## chase, and a loot table decides what drops on death. Concrete enemies
## are usually just this scene + tuned export values + swapped art —
## script-level subclassing is only needed for special-case behavior.
##
## An optional wider AlertArea (see `alert_target`) lets an enemy react
## before the player is actually close enough to chase — currently used
## by the wolf's Growl warning state.
##
## Enemies can also roam and hunt like critters: give one a "Wander"
## state node and a `wander_radius` above 0 to have Idle hand off to
## ambling around its spawn point, and a HunterComponent child to have it
## break off now and then to hunt prey critters (see wolf.tscn hunting
## deer). The player always takes priority over prey — see
## pursuit_target().

@export var loot_table: Array[LootEntry] = []
@export var xp_reward: int = 5
## How far from its spawn point this enemy wanders while unengaged. 0
## (the default) keeps it standing in place — Idle only hands off to a
## "Wander" state when this is above 0 and that state node exists.
@export var wander_radius: float = 0.0

## Fling speed (px/sec) range for a hand/weapon piece breaking loose on
## death — a short pop-and-tumble, not a dramatic launch.
const EQUIPMENT_FLING_SPEED: Vector2 = Vector2(35.0, 75.0)
const EQUIPMENT_SPIN_RANGE: float = 10.0
## Chance the sword flies off on its own instead of staying gripped in
## the hand it's parented to (see enemy_base.tscn's Equipment/HandMain/Sword).
const SWORD_BREAKS_FREE_CHANCE: float = 0.5

const _LOOSE_EQUIPMENT_PIECE_SCENE: PackedScene = preload("res://scenes/world/loose_equipment_piece.tscn")

@onready var state_machine: StateMachine = $StateMachine
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
## Wider warning ring, if this enemy has one (see class doc above).
@onready var alert_area: Area2D = get_node_or_null("AlertArea")
@onready var hitbox: HitboxComponent = get_node_or_null("HitboxComponent")
## Holds the floating hand/weapon overlay sprites, if this mob has any
## (see enemy_base.tscn). Mirrored as a whole via scale.x so the hands
## stay on the correct side when facing_direction flips.
@onready var equipment: Node2D = get_node_or_null("Equipment")

## The current chase/attack target, usually the player. Null when no one
## is in detection range.
var target: Node2D = null

## The player once they're within AlertArea range but not yet close enough
## to set `target`. Null when no one is in that wider ring. See the Growl
## state — this never gets set for enemies with no AlertArea child.
var alert_target: Node2D = null

## Where this enemy started; wandering stays anchored here. Spawners patch
## it to the real spawn point after add_child() (see EntitySpawner).
var anchor_position: Vector2
## For a predator (see HunterComponent), the prey critter it's currently
## hunting. Null when not hunting. Self-clears via pursuit_target() once
## the prey dies, and is dropped the moment the player becomes `target`.
var hunt_target: CritterBase = null

func _ready() -> void:
	super._ready()
	anchor_position = global_position
	if hitbox:
		hitbox.source = self
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered_detection)
		detection_area.body_exited.connect(_on_body_exited_detection)
	if alert_area:
		alert_area.body_entered.connect(_on_body_entered_alert)
		alert_area.body_exited.connect(_on_body_exited_alert)
	if health:
		health.damaged.connect(func(_amount: float, _source: Node) -> void: state_machine.transition_to(&"Hurt"))
		health.died.connect(func() -> void: state_machine.transition_to(&"Dead"))
	died.connect(func(_e: EntityBase) -> void:
		_drop_loot()
		_break_loose_equipment())

func _physics_process(_delta: float) -> void:
	if equipment:
		equipment.scale.x = -1.0 if facing_direction.x < 0.0 else 1.0

func _on_body_entered_detection(body: Node2D) -> void:
	if body is Player:
		target = body

func _on_body_exited_detection(body: Node2D) -> void:
	if body == target:
		target = null

func _on_body_entered_alert(body: Node2D) -> void:
	if body is Player:
		alert_target = body

func _on_body_exited_alert(body: Node2D) -> void:
	if body == alert_target:
		alert_target = null

## Whoever this enemy is currently pursuing to strike — the player
## (`target`) first, else the prey it's hunting. Self-clears hunt_target
## once the prey is dead or freed. Null when not pursuing anything.
func pursuit_target() -> Node2D:
	if target:
		return target
	if hunt_target:
		if is_instance_valid(hunt_target) and not hunt_target.is_dead():
			return hunt_target
		hunt_target = null
	return null

## The state an unengaged enemy (Idle/Wander) should break into because of
## the player: "Chase" once they're in detection range, "Growl" once
## they're only in the wider alert ring and this enemy has a Growl state
## (e.g. the wolf), or &"" if the player isn't close enough to matter.
func player_reaction_state() -> StringName:
	if target:
		return &"Chase"
	if alert_target and state_machine.states.has(&"Growl"):
		return &"Growl"
	return &""

func _drop_loot() -> void:
	ItemPickup.drop_loot(loot_table, global_position)

## Knocks the Equipment overlay sprites loose so they tumble away as
## physics debris instead of just freezing in place with the corpse. The
## sword either stays gripped in HandMain (rides along as its child, same
## as while alive) or peels off to land on its own.
func _break_loose_equipment() -> void:
	if not equipment:
		return
	var offhand := equipment.get_node_or_null("HandOffhand") as Node2D
	var main_hand := equipment.get_node_or_null("HandMain") as Node2D
	var sword: Node2D = main_hand.get_node_or_null("Sword") as Node2D if main_hand else null
	if sword and randf() < SWORD_BREAKS_FREE_CHANCE:
		_launch_piece(sword)
	if main_hand:
		_launch_piece(main_hand) # brings the sword with it if still attached
	if offhand:
		_launch_piece(offhand)

## Detaches `sprite` onto its own LooseEquipmentPiece so it survives and
## tumbles independently of this enemy's own eventual queue_free().
func _launch_piece(sprite: Node2D) -> void:
	var piece: LooseEquipmentPiece = _LOOSE_EQUIPMENT_PIECE_SCENE.instantiate()
	get_tree().current_scene.add_child(piece)
	piece.global_position = sprite.global_position
	piece.global_rotation = sprite.global_rotation
	sprite.reparent(piece, true)
	var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	piece.launch(
		direction * randf_range(EQUIPMENT_FLING_SPEED.x, EQUIPMENT_FLING_SPEED.y),
		randf_range(-EQUIPMENT_SPIN_RANGE, EQUIPMENT_SPIN_RANGE))
