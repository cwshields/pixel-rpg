class_name TreeProp
extends Node2D
## A single tree prop with two effects tied to the player's position:
## 1. Depth sort — if the tree's base is lower on the grid than the
##    player (i.e. the tree is visually "in front"), it draws over the
##    player instead of under them, so the player appears to walk behind
##    it. Otherwise it draws behind the player as normal.
## 2. Proximity fade — while the tree is drawn in front of the player,
##    it fades toward `faded_alpha` the closer the player gets, so it
##    doesn't fully hide them at close range.
##
## Both effects are driven purely by comparing positions each frame, so
## dropping a Tree anywhere in the world (regardless of what it's parented
## under) is enough — no shared container or Y-Sort setup required.

## Player.tscn's root z_index is set to this same value — a tree needs a
## shared baseline to sit exactly one step above or below the player.
## Change both together if you ever retune this.
const PLAYER_Z_INDEX := 10

@export_group("Depth Sorting")
## Vertical distance from the player's node origin down to their visual
## feet. The player's AnimatedSprite2D is centered on the node origin
## (not anchored at the feet), so this corrects for that when comparing
## "who's lower on the grid" — without it the compare point would be the
## player's torso, and the tree would seem to switch in front/behind too
## early or late.
@export var player_feet_offset: float = 38.0

@export_group("Transparency Fade")
## Distance (px) from the tree's base at which fading begins. Beyond
## this distance the tree stays fully opaque even while it's drawn in
## front of the player. This is "the player-distance tree-transparency
## start" value — raise it to make the tree start fading from further away.
@export var fade_start_distance: float = 52.0
## Alpha the tree eases down to when the player is right at its base.
## 1.0 = never fades, 0.0 = fully invisible up close. 0.5 = 50%
## transparent, matching "trees go about 50% transparent" — this is the
## maximum-transparency value.
@export_range(0.0, 1.0) var faded_alpha: float = 0.5
## How fast the alpha eases toward its target, in alpha-units/second
## (e.g. 6.0 = a full 0↔1 fade takes about 1/6th of a second).
@export var fade_speed: float = 6.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var _target_alpha: float = 1.0

func _ready() -> void:
	z_index = PLAYER_Z_INDEX - 1

func _process(delta: float) -> void:
	var player: Node2D = GameManager.player
	if player:
		_update_against_player(player)
	if sprite:
		sprite.modulate.a = move_toward(sprite.modulate.a, _target_alpha, fade_speed * delta)

func _update_against_player(player: Node2D) -> void:
	var player_feet: Vector2 = player.global_position + Vector2(0, player_feet_offset)
	var tree_in_front: bool = global_position.y >= player_feet.y
	z_index = (PLAYER_Z_INDEX + 1) if tree_in_front else (PLAYER_Z_INDEX - 1)

	if tree_in_front and fade_start_distance > 0.0:
		var distance: float = global_position.distance_to(player_feet)
		var t: float = clampf(distance / fade_start_distance, 0.0, 1.0)
		_target_alpha = lerpf(faded_alpha, 1.0, t)
	else:
		_target_alpha = 1.0
