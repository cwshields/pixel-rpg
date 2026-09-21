class_name Hotbar
extends Control
## Always-on-screen tool bar, laid over the bottom-centre bar art. Shows
## the first `slot_count` slots of GameManager.player's inventory, with a
## highlighted "active" slot the player picks by:
##   * pressing a number key (1..9 -> slot 0..8), or
##   * scrolling the mouse wheel (wraps around).
## The active slot is broadcast on Events.hotbar_selection_changed so a
## future "use held tool" system can react without knowing about this UI.
##
## Hides itself whenever any UIManager screen (inventory, pause...) is
## open, and ignores input while not PLAYING.
##
## The slot cells, frame and gauges are all painted into the parent
## TextureRect's art (Hotbar-UI-final.png, authored at 256x41, drawn 3x).
## This node just drops interactive HotbarSlots on top of the eight baked
## cells — four either side of the mana orb — and lets the art show
## through except for the selected slot's highlight.

const SLOT_TEX := "res://assets/UI/kit/slot_hotbar.png"
const SLOT_TEX_SELECTED := "res://assets/UI/kit/slot_hotbar_selected.png"
## Nine-patch border of the slot textures, in texture pixels (see README_UIKIT.md).
const SLOT_PATCH_MARGIN := 0

## Scale the parent art is drawn at, and the native slot-frame texture size.
const ART_SCALE := 2.0
const SLOT_PX := 17.5
## Centre X of each baked cell in source-art pixels (cols 0..3 left of the
## orb, 4..7 right of it); centre Y is shared. Measured from the art.
const CELL_CENTERS_X := [7.5, 24.5, 41.45, 58, 99, 116, 133, 150]
const CELL_CENTER_Y := 9

@export_range(1, 8) var slot_count: int = 8
## Flip if wheel-up should advance instead of go back.
@export var invert_scroll: bool = false

var _slots: Array[HotbarSlot] = []
var _selected: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tex_normal := _try_load(SLOT_TEX)
	var tex_selected := _try_load(SLOT_TEX_SELECTED)

	var count: int = mini(slot_count, CELL_CENTERS_X.size())
	var slot_screen_px := int(SLOT_PX * ART_SCALE)
	for i in count:
		var s := HotbarSlot.new(slot_screen_px, i + 1, tex_normal, tex_selected, SLOT_PATCH_MARGIN)
		s.position = Vector2(
			(float(CELL_CENTERS_X[i]) - SLOT_PX / 2.0) * ART_SCALE,
			(CELL_CENTER_Y - SLOT_PX / 2.0) * ART_SCALE)
		add_child(s)
		_slots.append(s)

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
		var placed: Inventory.PlacedItem = null
		if player and i < player.inventory.items.size():
			placed = player.inventory.items[i]
		if placed:
			_slots[i].set_item(placed.item, placed.quantity)
		else:
			_slots[i].set_item(null, 0)

func _apply_selection() -> void:
	for i in _slots.size():
		_slots[i].set_selected(i == _selected)

func _current_item() -> ItemBase:
	var player := GameManager.player as Player
	if player and _selected < player.inventory.items.size():
		return player.inventory.items[_selected].item
	return null

func _on_ui_toggled(_screen_name: StringName, _is_open: bool) -> void:
	visible = not UIManager.is_any_open()

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Hotbar: %s isn't imported yet - open the project in Godot once." % path)
	return null
