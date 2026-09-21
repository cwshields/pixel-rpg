class_name OccluderProp
extends Node2D
## Marker/interface base for world props that get player-relative depth
## sorting through the `Foliage` autoload (see foliage_manager.gd) — today
## that's `TreeProp` and `RockProp`. This class carries no shared state or
## logic of its own; it exists only so the manager can hold one typed
## array across every kind of prop and call the same three methods on
## whichever one it's holding. Each subclass implements its own version.

## Called every frame by Foliage while the player is within its active
## radius. Subclasses use this to flip z_index (and anything else, e.g.
## TreeProp's proximity fade) based on `player_pos`.
func update_proximity(_player_pos: Vector2, _delta: float) -> void:
	pass

## Called once, the frame Foliage drops this prop from the active set
## (player moved out of range). Subclasses should snap back to their
## resting z_index/alpha/etc.
func reset_proximity() -> void:
	pass

## Whether this prop is still mid-effect (flip/fade) and therefore needs
## its `reset_proximity()` call rather than being silently dropped.
func is_proximity_active() -> bool:
	return false
