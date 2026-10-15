class_name InventoryGrid
extends Control
## Draws an Inventory as a grid of square cells and lets the player click to
## pick items up onto the cursor and click again to place them, rotating
## with the R key or right mouse button while holding. Owned by InventoryUI,
## which calls setup() with GameManager.player.inventory each time the
## screen opens.
##
## Input is read from _input() rather than _gui_input() so a held item keeps
## tracking the mouse even if it strays outside this control's own rect
## (fast moves, placing near an edge, etc), and so a click anywhere on
## screen while holding something is consumed rather than leaking through
## to gameplay underneath.

const CELL_SIZE := 56
const SLOT_TEX := "res://assets/UI/inventory/grid_cell.png"
const SLOT_PATCH_MARGIN := 8
const PICKUP_SCENE: PackedScene = preload("res://scenes/world/item_pickup.tscn")
const VALID_COLOR := Color(0.45, 1.0, 0.45, 0.35)
const INVALID_COLOR := Color(1.0, 0.35, 0.35, 0.35)
const ITEM_FILL_COLOR := Color(1, 1, 1, 0.07)
const ITEM_OUTLINE_COLOR := Color(1, 1, 1, 0.4)
const HOVER_COLOR := Color(1, 1, 1, 0.18)
const LOCKED_COLOR := Color(0.15, 0.13, 0.1, 0.65)
const TRASH_HOVER_TINT := Color(1.5, 1.5, 1.5)
const TOOLTIP_PANEL_TEX := "res://assets/UI/kit/panel.png"
const TOOLTIP_PANEL_MARGIN := 12
const TOOLTIP_MAX_WIDTH := 224
const TOOLTIP_OFFSET := Vector2(20, 20)

var inventory: Inventory
## When set, only items whose ItemBase passes this check are drawn and
## interactable. Cleared (set to Callable()) to show everything.
var item_filter: Callable

var _slot_style: StyleBoxTexture
var _slot_tex: Texture2D
## The item currently riding the cursor, or null when nothing's held. Not
## registered anywhere in `inventory` while held — picking it up removes it
## outright, so the grid is always fully consistent.
var _held_item: ItemBase = null
var _held_quantity: int = 0
var _held_rotation: int = 0
var _held_icon: TextureRect

## The stack under the cursor when nothing's held, or null. Drives the
## hover highlight and the tooltip; cleared as soon as it stops being
## valid (picked up, or removed/moved elsewhere by an inventory change).
var _hovered: Inventory.PlacedItem = null
var _trash_highlighted := false

## Optional external drop target: when set, clicking to place a held item
## while the cursor is over this control's global rect discards it instead
## (see discard_held_item()). Left null for ordinary inventory screens;
## ItemSpawnerUI wires up its trash slot here.
var trash_control: Control = null
## Called with (InputEventMouseButton) before processing a left-click.
## Return true to consume the event (grid skips its own handling).
var input_filter: Callable
var _tooltip: PanelContainer
var _tooltip_name: Label
var _tooltip_desc: Label
var _tooltip_stats: Label
var _tooltip_magic: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slot_style = InventoryGrid.make_slot_style()
	if ResourceLoader.exists(SLOT_TEX):
		_slot_tex = load(SLOT_TEX) as Texture2D

	_held_icon = TextureRect.new()
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_icon.modulate.a = 0.85
	_held_icon.top_level = true
	_held_icon.visible = false
	add_child(_held_icon)

	_build_tooltip()

## Builds the hover tooltip out of plain Controls (no separate .tscn,
## matching _held_icon above) — a dark pixel-art panel capped at
## TOOLTIP_MAX_WIDTH with name/description/stats/magic labels stacked in
## a VBox. top_level so it positions in screen space and can spill
## outside this grid's own rect near screen edges.
func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.top_level = true
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	var style := StyleBoxTexture.new()
	if ResourceLoader.exists(TOOLTIP_PANEL_TEX):
		style.texture = load(TOOLTIP_PANEL_TEX) as Texture2D
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, TOOLTIP_PANEL_MARGIN)
	_tooltip.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(TOOLTIP_MAX_WIDTH - TOOLTIP_PANEL_MARGIN * 2, 0)
	vbox.add_theme_constant_override("separation", 6)
	_tooltip.add_child(vbox)

	_tooltip_name = _make_tooltip_label(16)
	_tooltip_desc = _make_tooltip_label(14)
	_tooltip_desc.modulate.a = 0.8
	_tooltip_stats = _make_tooltip_label(14)
	_tooltip_magic = _make_tooltip_label(14)
	for label in [_tooltip_name, _tooltip_desc, _tooltip_stats, _tooltip_magic]:
		vbox.add_child(label)

	add_child(_tooltip)

func _make_tooltip_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Binds this grid to `p_inventory` and (re)connects its `changed` signal.
## Safe to call repeatedly with the same instance (e.g. every time the
## inventory screen re-opens). Resolves any still-held item back into the
## *current* inventory first — shouldn't normally trigger, since closing
## the screen already does this via cancel_held_item(), but it's a safe
## fallback if setup() is ever called while something's in hand.
func setup(p_inventory: Inventory) -> void:
	cancel_held_item()
	if inventory and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = p_inventory
	custom_minimum_size = Vector2(inventory.width, inventory.height) * CELL_SIZE
	size = custom_minimum_size
	inventory.changed.connect(_on_inventory_changed)
	queue_redraw()

## Returns any held item to the inventory — the first free slot it fits in,
## or dropped in the world at the player's feet if the grid has no room at
## all. Called when the inventory screen closes so a held item is never
## silently lost.
func cancel_held_item() -> void:
	_clear_hover()
	if not _held_item:
		return
	var placement := inventory.find_free_placement(_held_item)
	if not placement.is_empty():
		inventory.place_item(_held_item, placement.pos, placement.rotation, _held_quantity)
	else:
		_drop_in_world()
	_clear_held()

## True if trash_control is set, visible, and the cursor is over it — and
## if so, discards the held item there and then. Checked before every
## placement attempt so dropping onto the trash slot always wins over
## whatever grid cell happens to be underneath it.
func _try_discard_at_trash() -> bool:
	if not trash_control or not trash_control.is_visible_in_tree():
		return false
	if not trash_control.get_global_rect().has_point(get_global_mouse_position()):
		return false
	discard_held_item()
	return true

## Clears the held item without returning it anywhere — unlike
## cancel_held_item(), which puts it back in the grid or drops it in the
## world. Used by trash_control to let a held item be discarded outright.
func discard_held_item() -> void:
	_clear_held()

func _drop_in_world() -> void:
	var player := GameManager.player as Player
	if not player:
		return
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = player.global_position
	pickup.setup(_held_item, _held_quantity)

func _clear_held() -> void:
	_held_item = null
	_held_icon.visible = false
	_set_trash_highlight(false)
	queue_redraw()

func _clear_hover() -> void:
	_hovered = null
	if _tooltip:
		_tooltip.visible = false

func _update_trash_highlight() -> void:
	if not trash_control or not trash_control.is_visible_in_tree():
		_set_trash_highlight(false)
		return
	_set_trash_highlight(trash_control.get_global_rect().has_point(get_global_mouse_position()))

func _set_trash_highlight(on: bool) -> void:
	if on == _trash_highlighted:
		return
	_trash_highlighted = on
	if trash_control:
		trash_control.self_modulate = TRASH_HOVER_TINT if on else Color.WHITE

func _on_inventory_changed() -> void:
	if _hovered and not inventory.items.has(_hovered):
		_clear_hover()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not inventory:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if input_filter.is_valid() and input_filter.call(mb):
				get_viewport().set_input_as_handled()
				return
			if not _held_item:
				if _pick_up_at(get_local_mouse_position()):
					get_viewport().set_input_as_handled()
			else:
				if _try_discard_at_trash():
					get_viewport().set_input_as_handled()
				elif _is_in_grid(get_local_mouse_position()):
					_try_place_held()
					get_viewport().set_input_as_handled()
			if _held_item:
				_clear_hover()
			else:
				_update_hover(get_local_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _held_item:
				_rotate_held()
				get_viewport().set_input_as_handled()
			elif _pick_up_one_at(get_local_mouse_position()):
				_clear_hover()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var local_pos := get_local_mouse_position()
		if _held_item:
			_held_icon.global_position = get_global_mouse_position() - _held_icon.size / 2.0
			_update_trash_highlight()
			queue_redraw()
		else:
			_update_hover(local_pos)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and _held_item:
			_rotate_held()
			get_viewport().set_input_as_handled()
	if not _held_item and event.is_action_pressed("interact"):
		if _try_use_hovered():
			get_viewport().set_input_as_handled()

## Updates `_hovered` from a local-space cursor position and shows/hides/
## repositions the tooltip accordingly. Only called while nothing's held.
func _update_hover(local_pos: Vector2) -> void:
	var cell := Vector2i(floori(local_pos.x / CELL_SIZE), floori(local_pos.y / CELL_SIZE))
	var new_hovered: Inventory.PlacedItem = null
	if cell.x >= 0 and cell.y >= 0 and cell.x < inventory.width and cell.y < inventory.height:
		var candidate := _placed_at(cell)
		if candidate and _passes_filter(candidate.item):
			new_hovered = candidate
	if new_hovered == _hovered:
		if _hovered:
			_position_tooltip()
		return
	_hovered = new_hovered
	queue_redraw()
	if _hovered:
		_show_tooltip(_hovered)
		_position_tooltip()
		Events.inventory_item_hovered.emit(_hovered.item)
	else:
		_tooltip.visible = false
		Events.inventory_item_hovered.emit(null)

func _show_tooltip(placed: Inventory.PlacedItem) -> void:
	var item := placed.item
	_tooltip_name.text = item.display_name
	_tooltip_desc.text = item.description
	_tooltip_desc.visible = not item.description.is_empty()
	var stat_lines: Array[String] = item.get_stat_lines()
	_tooltip_stats.text = "\n".join(stat_lines)
	_tooltip_stats.visible = not stat_lines.is_empty()
	var magic_lines: Array[String] = _roll_magic_effects(item)
	_tooltip_magic.text = "\n".join(magic_lines)
	_tooltip_magic.visible = not magic_lines.is_empty()
	_tooltip.visible = true
	_tooltip.size = _tooltip.get_minimum_size()

## Picks a random subset of item.magic_effect_pool to show — re-rolled on
## every hover so peeking at the same item again can surface a different
## pair. Display-only; not wired to any gameplay effect.
func _roll_magic_effects(item: ItemBase) -> Array[String]:
	var result: Array[String] = []
	if item.magic_effect_pool.is_empty():
		return result
	var pool: Array = Array(item.magic_effect_pool)
	pool.shuffle()
	var count := clampi(item.magic_effect_count, 0, pool.size())
	for i in count:
		result.append(pool[i])
	return result

func _position_tooltip() -> void:
	var pos := get_global_mouse_position() + TOOLTIP_OFFSET
	var viewport_size := get_viewport_rect().size
	pos.x = minf(pos.x, viewport_size.x - _tooltip.size.x - 2)
	pos.y = minf(pos.y, viewport_size.y - _tooltip.size.y - 2)
	_tooltip.position = pos

func _pick_up_at(local_pos: Vector2) -> bool:
	var cell := Vector2i(floori(local_pos.x / CELL_SIZE), floori(local_pos.y / CELL_SIZE))
	if cell.x < 0 or cell.y < 0 or cell.x >= inventory.width or cell.y >= inventory.height:
		return false
	var placed := _placed_at(cell)
	if not placed:
		return false
	_held_item = placed.item
	_held_quantity = placed.quantity
	_held_rotation = placed.rotation
	inventory.remove_placed(placed)
	_update_held_icon()
	_held_icon.global_position = get_global_mouse_position() - _held_icon.size / 2.0
	_held_icon.visible = true
	queue_redraw()
	return true

func _pick_up_one_at(local_pos: Vector2) -> bool:
	var cell := Vector2i(floori(local_pos.x / CELL_SIZE), floori(local_pos.y / CELL_SIZE))
	if cell.x < 0 or cell.y < 0 or cell.x >= inventory.width or cell.y >= inventory.height:
		return false
	var placed := _placed_at(cell)
	if not placed or placed.quantity < 2:
		return false
	placed.quantity -= 1
	inventory.changed.emit()
	_held_item = placed.item
	_held_quantity = 1
	_held_rotation = placed.rotation
	_update_held_icon()
	_held_icon.global_position = get_global_mouse_position() - _held_icon.size / 2.0
	_held_icon.visible = true
	queue_redraw()
	return true

## Picks `item` up onto the cursor as a fresh stack of `quantity`, exactly as
## if it had just been clicked up out of a slot — used by the debug item
## spawner window. No-op if something's already held (place or drop it
## first) or the grid isn't bound to an inventory yet.
func pick_up_new(item: ItemBase, quantity: int = 1) -> void:
	if _held_item or not inventory:
		return
	_held_item = item
	_held_quantity = quantity
	_held_rotation = 0
	_update_held_icon()
	_held_icon.global_position = get_global_mouse_position() - _held_icon.size / 2.0
	_held_icon.visible = true
	_clear_hover()
	queue_redraw()

func _rotate_held() -> void:
	if not _held_item.can_rotate:
		return
	_held_rotation = (_held_rotation + 1) % 4
	_update_held_icon()
	_held_icon.global_position = get_global_mouse_position() - _held_icon.size / 2.0
	queue_redraw()

## Attempts to place the held item at the cursor's target cell: a direct
## placement if the spot is free, a swap if it's covered by exactly one
## other item and the held item fits once that item's gone, or a stack
## merge if that one occupant is the same item with spare room. Rejected
## (held item unchanged, nothing happens) if the footprint spills off-grid
## or covers two or more distinct items.
func _try_place_held() -> void:
	var target := _held_target_pos()
	var cells := inventory.get_world_cells(_held_item, target, _held_rotation)
	for cell in cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= inventory.width or cell.y >= inventory.height:
			return
	if inventory.can_place_at(_held_item, target, _held_rotation):
		inventory.place_item(_held_item, target, _held_rotation, _held_quantity)
		_clear_held()
		return
	var occupants := inventory.get_occupants(_held_item, target, _held_rotation)
	if occupants.size() != 1:
		return
	var occupant := occupants[0]
	if occupant.item.id == _held_item.id and occupant.quantity < occupant.item.max_stack:
		_held_quantity = inventory.merge_into(occupant, _held_quantity)
		if _held_quantity <= 0:
			_clear_held()
		else:
			_update_held_icon()
			queue_redraw()
		return
	if not inventory.can_place_at(_held_item, target, _held_rotation, occupant):
		return
	inventory.remove_placed(occupant)
	inventory.place_item(_held_item, target, _held_rotation, _held_quantity)
	_held_item = occupant.item
	_held_quantity = occupant.quantity
	_held_rotation = occupant.rotation
	_update_held_icon()
	_held_icon.global_position = get_global_mouse_position() - _held_icon.size / 2.0
	queue_redraw()

func _held_target_pos() -> Vector2i:
	var dims := _shape_dims(inventory.get_rotated_cells(_held_item, _held_rotation))
	var top_left := get_local_mouse_position() - Vector2(dims) * CELL_SIZE / 2.0
	return Vector2i(roundi(top_left.x / CELL_SIZE), roundi(top_left.y / CELL_SIZE))

func _update_held_icon() -> void:
	var dims := _shape_dims(inventory.get_rotated_cells(_held_item, _held_rotation))
	_held_icon.texture = _held_item.icon
	_held_icon.size = Vector2(dims) * CELL_SIZE

func _placed_at(cell: Vector2i) -> Inventory.PlacedItem:
	for placed in inventory.items:
		if cell in inventory.get_world_cells(placed.item, placed.pos, placed.rotation):
			return placed
	return null

func _shape_dims(cells: Array[Vector2i]) -> Vector2i:
	var w := 0
	var h := 0
	for c in cells:
		w = maxi(w, c.x + 1)
		h = maxi(h, c.y + 1)
	return Vector2i(w, h)

func _passes_filter(item: ItemBase) -> bool:
	return not item_filter.is_valid() or item_filter.call(item)

func _is_in_grid(local_pos: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(local_pos)

func _try_use_hovered() -> bool:
	if not _hovered or not _hovered.item is Consumable:
		return false
	var player := GameManager.player as Player
	if not player:
		return false
	var consumable := _hovered.item as Consumable
	if not consumable.use(player):
		return false
	if _hovered.quantity > 1:
		_hovered.quantity -= 1
		inventory.changed.emit()
	else:
		inventory.remove_placed(_hovered)
		_clear_hover()
	return true

func has_held_item() -> bool:
	return _held_item != null

func get_held_item() -> ItemBase:
	return _held_item

func get_held_quantity() -> int:
	return _held_quantity

func take_held_item() -> Dictionary:
	if not _held_item:
		return {}
	var result := {"item": _held_item, "quantity": _held_quantity}
	_clear_held()
	return result

func _draw() -> void:
	if not inventory:
		return
	for y in inventory.height:
		for x in inventory.width:
			if _slot_tex:
				draw_texture_rect(_slot_tex, Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE), false)
	for y in range(inventory.unlocked_rows, inventory.height):
		for x in inventory.width:
			draw_rect(Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE), LOCKED_COLOR, true)
	for placed in inventory.items:
		if _passes_filter(placed.item):
			_draw_item(placed.item, placed.pos, placed.rotation, placed.quantity)
	if _hovered and not _held_item:
		for cell in inventory.get_world_cells(_hovered.item, _hovered.pos, _hovered.rotation):
			draw_rect(Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE), HOVER_COLOR, true)
	if _held_item:
		var target := _held_target_pos()
		var cells := inventory.get_world_cells(_held_item, target, _held_rotation)
		var in_bounds := true
		for cell in cells:
			if cell.x < 0 or cell.y < 0 or cell.x >= inventory.width or cell.y >= inventory.height:
				in_bounds = false
				break
		var fits := in_bounds and inventory.can_place_at(_held_item, target, _held_rotation)
		var ok := fits or (in_bounds and inventory.get_occupants(_held_item, target, _held_rotation).size() == 1)
		var color := VALID_COLOR if ok else INVALID_COLOR
		for cell in cells:
			if cell.x >= 0 and cell.y >= 0 and cell.x < inventory.width and cell.y < inventory.height:
				draw_rect(Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE), color, true)

func _draw_item(item: ItemBase, pos: Vector2i, rot: int, quantity: int) -> void:
	var cells := inventory.get_rotated_cells(item, rot)
	var dims := _shape_dims(cells)
	var origin := Vector2(pos) * CELL_SIZE
	var footprint := Vector2(dims) * CELL_SIZE
	for c in cells:
		draw_rect(Rect2(origin + Vector2(c) * CELL_SIZE, Vector2.ONE * CELL_SIZE), ITEM_FILL_COLOR, true)
	draw_rect(Rect2(origin + Vector2.ONE, footprint - Vector2.ONE * 2), ITEM_OUTLINE_COLOR, false, 1.0)
	if item.icon:
		draw_texture_rect(item.icon, Rect2(origin + Vector2.ONE * 2, footprint - Vector2.ONE * 4), false)
	if quantity > 1:
		var font := get_theme_default_font()
		var font_size := 14
		var text := str(quantity)
		var box_width := footprint.x - 4
		var text_pos := Vector2(origin.x + 2, origin.y + footprint.y - 4)
		draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_RIGHT, box_width, font_size,
			2, Color(0.05, 0.05, 0.08))
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_RIGHT, box_width, font_size,
			Color(0.95, 0.92, 0.85))

static func make_slot_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if ResourceLoader.exists(SLOT_TEX):
		style.texture = load(SLOT_TEX) as Texture2D
	else:
		push_warning("InventoryGrid: %s isn't imported yet - open the project in Godot once." % SLOT_TEX)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, SLOT_PATCH_MARGIN)
	return style
