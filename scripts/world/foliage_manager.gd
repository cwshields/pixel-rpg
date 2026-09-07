extends Node
## Drives the player-relative effects on trees (autoload name: "Foliage").
##
## Each TreeProp has two effects tied to the player's position — a
## front/behind z_index flip so the player can walk behind it, and a
## proximity alpha fade so a close tree doesn't fully hide the player.
## Running that logic in a per-node _process() means every tree in the
## world pays for it every frame, even the ones nowhere near the player.
##
## This manager centralises it: trees register themselves on entering the
## tree, and each frame we evaluate only the ones within `ACTIVE_RADIUS`
## of the player. A far tree costs a single squared-distance compare and
## nothing else. Trees still "just work" when dropped anywhere in the
## world — registration happens in TreeProp._enter_tree(), no shared
## container or setup required.

## Distance (px) from the player within which a tree gets the full
## front/behind + fade evaluation. Must stay comfortably larger than any
## tree's `fade_start_distance` (default 52) so a tree is never dropped
## from the active set while it's still mid-fade — see reset_proximity()
## in tree.gd, which snaps alpha back to opaque.
const ACTIVE_RADIUS: float = 260.0

var _trees: Array[TreeProp] = []

func register_tree(tree: TreeProp) -> void:
	if tree not in _trees:
		_trees.append(tree)

func unregister_tree(tree: TreeProp) -> void:
	_trees.erase(tree)

func _process(delta: float) -> void:
	var player: Node2D = GameManager.player
	if not player:
		return

	var player_pos: Vector2 = player.global_position
	var radius_sq: float = ACTIVE_RADIUS * ACTIVE_RADIUS
	var has_freed := false

	for tree in _trees:
		if not is_instance_valid(tree):
			has_freed = true
			continue
		if tree.global_position.distance_squared_to(player_pos) <= radius_sq:
			tree.update_proximity(player_pos, delta)
		elif tree.is_proximity_active():
			tree.reset_proximity()

	if has_freed:
		_trees = _trees.filter(func(t: TreeProp) -> bool: return is_instance_valid(t))
