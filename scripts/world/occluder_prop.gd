class_name OccluderProp
extends Node2D
## Marker/interface base for world props that get player-relative depth
## sorting through the `Foliage` autoload (see foliage_manager.gd) — today
## that's `TreeProp` and `RockProp`. Beyond the shared depth constant below,
## this class carries no shared state or logic of its own; it exists only
## so the manager can hold one typed array across every kind of prop and
## call the same three methods on whichever one it's holding. Each
## subclass implements its own version.

## Player.tscn's root z_index is set to this same value at runtime (see
## Player._ready()) so every OccluderProp has one shared baseline to sit
## exactly one step above or below the player. Single source of truth —
## previously this was three independently hand-synced constants (one per
## subclass plus a hardcoded value in player.tscn), which is exactly how
## the player/tree z-index drift bug happened.
const PLAYER_Z_INDEX := 4

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
