class_name WeaponSwingFrame
extends Resource
## One frame of weapon-overlay placement during an attack animation.
## Edit these per-frame in the inspector on the WeaponOverlay node.

@export var offset: Vector2 = Vector2.ZERO
@export var rotation_deg: float = 0.0
## True = weapon draws in front of body; false = behind.
@export var flip_h: bool = false
@export var in_front: bool = true
@export var frame_visible: bool = true
