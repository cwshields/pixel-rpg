@tool
class_name WeaponOverlay
extends Sprite2D

enum PreviewAnim { SIDE, MOVE_SIDE, DOWN, UP }

const ANIM_NAMES: Array[StringName] = [
	&"attack_side", &"attack_move_side", &"attack_down", &"attack_up",
]

@export_group("Editor Preview")
@export var preview_animation: PreviewAnim = PreviewAnim.SIDE:
	set(v):
		preview_animation = v
		if Engine.is_editor_hint():
			_editor_sync()
@export_range(0, 7) var preview_frame: int = 0:
	set(v):
		preview_frame = v
		if Engine.is_editor_hint():
			_editor_sync()
@export var preview_texture: Texture2D:
	set(v):
		preview_texture = v
		if Engine.is_editor_hint():
			texture = v
			_editor_sync()
@export var preview_flipped: bool = false:
	set(v):
		preview_flipped = v
		if Engine.is_editor_hint():
			_editor_sync()
@export var preview_playing: bool = false:
	set(v):
		preview_playing = v
		if Engine.is_editor_hint():
			if v:
				_preview_play()
			else:
				_preview_stop()

@export_group("Side Attack")
@export var attack_side_frames: Array[WeaponSwingFrame] = []
@export_group("Side Attack (Moving)")
@export var attack_move_side_frames: Array[WeaponSwingFrame] = []
@export_group("Down Attack")
@export var attack_down_frames: Array[WeaponSwingFrame] = []
@export_group("Up Attack")
@export var attack_up_frames: Array[WeaponSwingFrame] = []

var _frame_map: Dictionary = {}
var _body_sprite: AnimatedSprite2D
var _active: bool = false
var _preview_playing_active: bool = false

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _preview_playing_active:
		var preview := get_node_or_null("BodyPreview") as AnimatedSprite2D
		if not preview or not preview.is_playing():
			_preview_playing_active = false
			preview_playing = false
		else:
			preview_frame = preview.frame
	_editor_sync()

func _ready() -> void:
	_build_frame_map()
	if Engine.is_editor_hint():
		set_process(true)
		_setup_editor_preview()
		return
	texture = null
	visible = false
	var preview := get_node_or_null("BodyPreview") as AnimatedSprite2D
	if preview:
		preview.visible = false
	_body_sprite = get_parent().get_node_or_null("AnimatedSprite2D")
	if _body_sprite:
		_body_sprite.frame_changed.connect(_on_frame_changed)
		_body_sprite.animation_changed.connect(_on_animation_changed)

func _build_frame_map() -> void:
	_frame_map = {
		&"attack_side": attack_side_frames,
		&"attack_move_side": attack_move_side_frames,
		&"attack_down": attack_down_frames,
		&"attack_up": attack_up_frames,
	}

func set_weapon_texture(tex: Texture2D) -> void:
	texture = tex
	if tex == null:
		_active = false
		visible = false

func show_overlay() -> void:
	if texture == null:
		return
	_active = true
	_sync()

func hide_overlay() -> void:
	_active = false
	visible = false

func _on_animation_changed() -> void:
	_sync()

func _on_frame_changed() -> void:
	_sync()

func _sync() -> void:
	if not _active or not _body_sprite or texture == null:
		visible = false
		return
	var anim: StringName = _body_sprite.animation
	var frames: Array = _frame_map.get(anim, [])
	if frames.is_empty():
		visible = false
		return
	var frame_idx: int = clampi(_body_sprite.frame, 0, frames.size() - 1)
	var entry: WeaponSwingFrame = frames[frame_idx]
	if entry == null or not entry.frame_visible:
		visible = false
		return
	var off: Vector2 = entry.offset
	var rot: float = entry.rotation_deg
	var z: int = 1 if entry.in_front else -1
	if _body_sprite.flip_h:
		off.x = -off.x
		rot = -rot
	var f: bool = entry.flip_h != _body_sprite.flip_h
	position = off
	rotation_degrees = rot
	flip_h = f
	z_index = z
	visible = true

# ── Editor preview ──────────────────────────────────────────────────

func _setup_editor_preview() -> void:
	var preview := get_node_or_null("BodyPreview") as AnimatedSprite2D
	if preview:
		preview.visible = true
		_body_sprite = preview
	if preview_texture:
		texture = preview_texture
	_editor_sync()

func _editor_sync() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_build_frame_map()
	var preview := get_node_or_null("BodyPreview") as AnimatedSprite2D
	if not preview:
		return
	var anim_name: StringName = ANIM_NAMES[preview_animation]
	if preview.sprite_frames and preview.sprite_frames.has_animation(anim_name):
		preview.animation = anim_name
		preview.frame = clampi(preview_frame, 0, preview.sprite_frames.get_frame_count(anim_name) - 1)
	preview.flip_h = preview_flipped
	var frames: Array = _frame_map.get(anim_name, [])
	if frames.is_empty() or texture == null:
		visible = false
		return
	var idx: int = clampi(preview_frame, 0, frames.size() - 1)
	var entry: WeaponSwingFrame = frames[idx]
	if entry == null or not entry.frame_visible:
		visible = false
		return
	var off: Vector2 = entry.offset
	var rot: float = entry.rotation_deg
	var z: int = 1 if entry.in_front else -1
	if preview_flipped:
		off.x = -off.x
		rot = -rot
	var f: bool = entry.flip_h != preview_flipped
	position = off
	rotation_degrees = rot
	flip_h = f
	z_index = z
	visible = true

func _preview_play() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var preview := get_node_or_null("BodyPreview") as AnimatedSprite2D
	if not preview:
		return
	var anim_name: StringName = ANIM_NAMES[preview_animation]
	if preview.sprite_frames and preview.sprite_frames.has_animation(anim_name):
		preview.animation = anim_name
		preview.frame = 0
		preview.play(anim_name)
		_preview_playing_active = true

func _preview_stop() -> void:
	_preview_playing_active = false
	var preview := get_node_or_null("BodyPreview") as AnimatedSprite2D
	if preview:
		preview.stop()
	_editor_sync()
