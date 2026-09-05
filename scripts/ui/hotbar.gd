class_name Hotbar
extends Control
## Always-on-screen tool bar pinned to the bottom of the viewport. Shows
## the first `slot_count` slots of GameManager.player's inventory, with a
## highlighted "active" slot the player picks by:
##   * pressing a number key (1..9 -> slot 0..8), or
##   * scrolling the mouse wheel (wraps around).
## The active slot is broadcast on Events.hotbar_selection_changed so a
## future "use held tool" system can react without knowing about this UI.
##
## Hides itself whenever any UIManager screen (inventory, pause...) is
## open, and ignores input while not PLAYING.

const SLOT_TEX := "res://assets/UI/kit/slot_hotbar.png"
const SLOT_TEX_SELECTED := "res://assets/UI/kit/slot_hotbar_selected.png"
## Nine-patch border of slot_hotbar.png, in texture pixels (see README_UIKIT.md).
const SLOT_PATCH_MARGIN := 5

@export var slot_count: int = 8
@export var slot_size: int = 44
@export var separation: int = 4
## Gap between the bar and the bottom edge of the screen, in pixels.
@export var bottom_margin: int = 10
## Flip if wheel-up should advance instead of go back.
@export var invert_scroll: bool = false

var _box: HBoxContainer
var _slots: Array[HotbarSlot] = []
var _selected: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tex_normal := _try_load(SLOT_TEX)
	var tex_selected := _try_load(SLOT_TEX_SELECTED)

	_box = HBoxContainer.new()
	_box.add_theme_constant_override("separation", separation)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	for i in slot_count:
		var s := HotbarSlot.new(slot_size, i + 1, tex_normal, tex_selected, SLOT_PATCH_MARGIN)
		_box.add_child(s)
		_slots.append(s)

	# Pin the row centred along the bottom edge.
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	var row_w: float = slot_count * slot_size + (slot_count - 1) * separation
	_box.offset_left = -row_w / 2.0
	_box.offset_right = row_w / 2.0
	_box.offset_top = -slot_size - bottom_margin
	_box.offset_bottom = -bottom_margin

	Events.inventory_changed.connect(refresh)
	Events.player_spawned.connect(func(_p: Node) -> void: refresh())
	Events.ui_toggled.connect(_on_ui_toggled)

	refresh()
	_apply_selection()
	Events.hotbar_selection_changed.emit(_selected, _current_item())
	visible = not UIManager.is_any_open()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not GameManager.is_playing():
		return
	var step := -1 if invert_scroll else 1
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select(_selected - step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select(_selected + step)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx: int = event.keycode - KEY_1
			if idx < _slots.size():
				select(idx)
				get_viewport().set_input_as_handled()

## Selects a slot by index; wraps, so callers can pass _selected +/- 1
## freely. No-op (and no signal) if the index doesn't actually change.
func select(index: int) -> void:
	var next := wrapi(index, 0, _slots.size())
	if next == _selected:
		return
	_selected = next
	_apply_selection()
	Events.hotbar_selection_changed.emit(_selected, _current_item())

func get_selected_index() -> int:
	return _selected

## The item in the active slot, or null if it's empty / there's no player.
func get_selected_item() -> ItemBase:
	return _current_item()

func refresh() -> void:
	var player := GameManager.player as Player
	for i in _slots.size():
		var inv_slot: Inventory.Slot = null
		if player and i < player.inventory.slots.size():
			inv_slot = player.inventory.slots[i]
		if inv_slot:
			_slots[i].set_item(inv_slot.item, inv_slot.quantity)
		else:
			_slots[i].set_item(null, 0)

func _apply_selection() -> void:
	for i in _slots.size():
		_slots[i].set_selected(i == _selected)

func _current_item() -> ItemBase:
	var player := GameManager.player as Player
	if player and _selected < player.inventory.slots.size():
		return player.inventory.slots[_selected].item
	return null

func _on_ui_toggled(_screen_name: StringName, _is_open: bool) -> void:
	visible = not UIManager.is_any_open()

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Hotbar: %s isn't imported yet - open the project in Godot once." % path)
	return null
