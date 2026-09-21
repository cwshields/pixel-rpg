extends Node
## Drives the player-relative depth-sort effects on world props (autoload
## name: "Foliage" — a holdover from when trees were the only prop it
## managed; it now also drives rocks, and any future `OccluderProp`).
##
## Each registered prop gets a front/behind `z_index` flip against the
## player every frame (plus, for `TreeProp`, a proximity alpha fade).
## Running that logic in a per-node `_process()` means every prop in the
## world pays for it every frame, even ones nowhere near the player.
##
## This manager centralises it: props register themselves on entering the
## tree (pun intended), and each frame we evaluate only the ones within
## `ACTIVE_RADIUS` of the player. A far prop costs a single squared-
## distance compare and nothing else. Props still "just work" when dropped
## anywhere in the world — registration happens in each prop's
## `_enter_tree()`, no shared container or setup required.

## Distance (px) from the player within which a prop gets the full
## front/behind (+ fade, for props that have one) evaluation. Must stay
## comfortably larger than any prop's fade-start distance (TreeProp's
## `fade_start_distance`, default 52) so a prop is never dropped from the
## active set while it's still mid-fade — see reset_proximity(), which
## snaps state back to resting.
const ACTIVE_RADIUS: float = 260.0

var _props: Array[OccluderProp] = []

func register_prop(prop: OccluderProp) -> void:
	if prop not in _props:
		_props.append(prop)

func unregister_prop(prop: OccluderProp) -> void:
	_props.erase(prop)

func _process(delta: float) -> void:
	var player: Node2D = GameManager.player
	if not player:
		return

	var player_pos: Vector2 = player.global_position
	var radius_sq: float = ACTIVE_RADIUS * ACTIVE_RADIUS
	var has_freed := false

	for prop in _props:
		if not is_instance_valid(prop):
			has_freed = true
			continue
		if prop.global_position.distance_squared_to(player_pos) <= radius_sq:
			prop.update_proximity(player_pos, delta)
		elif prop.is_proximity_active():
			prop.reset_proximity()

	if has_freed:
		_props = _props.filter(func(p: OccluderProp) -> bool: return is_instance_valid(p))
