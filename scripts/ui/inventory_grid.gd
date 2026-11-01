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
const _GRAB_SFX: AudioStream = preload("res://assets/SoundFX/UI/item-pickup-553942.mp3")
const _WOOD_PLACE_SFX: AudioStream = preload("res://assets/SoundFX/UI/put_place_item-83043.mp3")
const _GENERAL_PLACE_SFX: AudioStream = preload("res://assets/SoundFX/UI/small-thud-48175.mp3")
const _IRON_WEAPON_PLACE_SFX: AudioStream = preload("res://assets/SoundFX/UI/menu-click-sound.mp3")
const _HEAVY_ARMOR_PLACE_SFX: AudioStream = preload("res://assets/SoundFX/UI/armor-pickup-equip-6904.mp3")
const _LIGHT_ARMOR_PLACE_SFX: AudioStream = preload("res://assets/SoundFX/UI/punching-light-armour-87442.mp3")
const _AMULET_PLACE_SFX: AudioStream = preload("res://assets/SoundFX/UI/drop-pickup-equip-item.mp3")
const ITEM_FILL_COLOR := Color(1, 1, 1, 0.07)
const ITEM_OUTLINE_COLOR := Color(1, 1, 1, 0.4)
const HOVER_COLOR := Color(1, 1, 1, 0.18)
const LOCKED_COLOR := Color(0.15, 0.13, 0.1, 0.65)
const TRASH_HOVER_TINT := Color(1.5, 1.5, 1.5)

const DIVIDER_TEX := preload("res://assets/UI/inventory/info_divider.png")
const COIN_ICON := preload("res://assets/UI/inventory/icon_coin_detail.png")
const WEIGHT_ICON := preload("res://assets/UI/inventory/icon_weight_detail.png")
const DMG_ICON := preload("res://assets/UI/inventory/icon_dmg.png")
const DURABILITY_ICON := preload("res://assets/UI/inventory/icon_durability.png")
const ATK_SPEED_ICON := preload("res://assets/UI/inventory/icon_atk_speed.png")
const ARMOR_ICON := preload("res://assets/UI/inventory/icon_armor_detail.png")
const INFO_BG_TEX := preload("res://assets/UI/inventory/info_bg.png")
const INFO_BORDER_TEX := preload("res://assets/UI/inventory/info_border.png")
const INFO_DECAL_TEX := preload("res://assets/UI/inventory/info_decal.png")
const TOOLTIP_PADDING := 16
const TOOLTIP_MAX_WIDTH := 280
const TOOLTIP_OFFSET := Vector2(20, 20)
const BORDER_PATCH_MARGIN := 10
const TT_FONT_SIZE := 18
const TT_HEADER_SIZE := 20
const MAGIC_COLOR := Color("3d8be3")
const LABEL_COLOR := Color(0.894, 0.729, 0.522, 1.0)
const MUTED_COLOR := Color(0.7, 0.6, 0.5, 0.85)
const TT_VALUE_COLOR := Color(0.96, 0.94, 0.88, 1.0)
const TT_OUTLINE_COLOR := Color(0.05, 0.04, 0.06)
const REQ_LABEL_COLOR := Color(0.85, 0.35, 0.25, 1.0)
const REQ_VALUE_COLOR := Color(0.96, 0.94, 0.88, 1.0)
const HINT_COLOR := Color(0.6, 0.55, 0.5, 0.9)
const MAX_COLLAPSED_AFFIXES := 5

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

var _tooltip_item: ItemBase
var _tooltip_expanded: bool = false
var _tooltip_external: bool = false
var _cursor_tooltip: Control
var _tooltip_vbox: VBoxContainer

## Optional external drop target: when set, clicking to place a held item
## while the cursor is over this control's global rect discards it instead
## (see discard_held_item()). Left null for ordinary inventory screens;
## ItemSpawnerUI wires up its trash slot here.
var trash_control: Control = null
## Called with (InputEventMouseButton) before processing a left-click.
## Return true to consume the event (grid skips its own handling).
var input_filter: Callable

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
	_build_cursor_tooltip()

func _process(_delta: float) -> void:
	if _cursor_tooltip.visible:
		_resize_tooltip()
		_position_tooltip()

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

func show_external_tooltip(item: ItemBase) -> void:
	if item:
		_tooltip_external = true
		_tooltip_item = item
		_tooltip_expanded = false
		_show_detail(item)
	else:
		_tooltip_external = false
		_tooltip_item = null
		_cursor_tooltip.visible = false

func _clear_hover() -> void:
	_hovered = null
	_tooltip_item = null
	_tooltip_expanded = false
	_tooltip_external = false
	_cursor_tooltip.visible = false
	Events.inventory_item_hovered.emit(null)

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
	if event is InputEventKey and event.keycode == KEY_ALT and _tooltip_item and _cursor_tooltip.visible:
		var want_expanded: bool = (event as InputEventKey).pressed
		if want_expanded != _tooltip_expanded:
			_tooltip_expanded = want_expanded
			_show_detail(_tooltip_item)
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
			if mb.shift_pressed and input_filter.is_valid() and input_filter.call(mb):
				get_viewport().set_input_as_handled()
				return
			if _held_item:
				_rotate_held()
				get_viewport().set_input_as_handled()
			elif mb.shift_pressed:
				if _pick_up_half_at(get_local_mouse_position()):
					_clear_hover()
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
		return
	_hovered = new_hovered
	queue_redraw()
	if _hovered:
		_tooltip_external = false
		_tooltip_item = _hovered.item
		_tooltip_expanded = false
		_show_detail(_hovered.item)
		Events.inventory_item_hovered.emit(_hovered.item)
	elif not _tooltip_external:
		_tooltip_item = null
		_cursor_tooltip.visible = false
		Events.inventory_item_hovered.emit(null)

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
	_play_grab_sfx()
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
	_play_grab_sfx()
	queue_redraw()
	return true

func _pick_up_half_at(local_pos: Vector2) -> bool:
	var cell := Vector2i(floori(local_pos.x / CELL_SIZE), floori(local_pos.y / CELL_SIZE))
	if cell.x < 0 or cell.y < 0 or cell.x >= inventory.width or cell.y >= inventory.height:
		return false
	var placed := _placed_at(cell)
	if not placed or placed.quantity < 2:
		return false
	var half := placed.quantity / 2
	placed.quantity -= half
	inventory.changed.emit()
	_held_item = placed.item
	_held_quantity = half
	_held_rotation = placed.rotation
	_update_held_icon()
	_held_icon.global_position = get_global_mouse_position() - _held_icon.size / 2.0
	_held_icon.visible = true
	_play_grab_sfx()
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

func _play_grab_sfx() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = _GRAB_SFX
	sfx.bus = &"Master"
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()

func _play_place_sfx(item: ItemBase) -> void:
	var stream: AudioStream
	if _is_wood_item(item):
		stream = _WOOD_PLACE_SFX
	elif item is Weapon and _is_iron_item(item):
		stream = _IRON_WEAPON_PLACE_SFX
	elif item is Armor and _is_heavy_armor(item):
		stream = _HEAVY_ARMOR_PLACE_SFX
	elif item is Armor:
		stream = _LIGHT_ARMOR_PLACE_SFX
	elif item is Amulet:
		stream = _AMULET_PLACE_SFX
	elif item.category not in [ItemBase.Category.WEAPON, ItemBase.Category.CONSUMABLE,
			ItemBase.Category.RUNE_STONE]:
		stream = _GENERAL_PLACE_SFX
	else:
		return
	var volume_db := 0.0
	if stream == _HEAVY_ARMOR_PLACE_SFX:
		volume_db = 4.0
	elif stream == _IRON_WEAPON_PLACE_SFX:
		volume_db = -10.0
	elif stream == _LIGHT_ARMOR_PLACE_SFX:
		volume_db = -6.0
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.bus = &"Master"
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()

static func _is_wood_item(item: ItemBase) -> bool:
	if item is CraftingMaterial and item.material_type == CraftingMaterial.MaterialType.WOOD:
		return true
	return "wood" in item.id

static func _is_iron_item(item: ItemBase) -> bool:
	return "iron" in item.id

static func _is_heavy_armor(item: ItemBase) -> bool:
	return "leather" not in item.id and "cloth" not in item.id

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
		_play_place_sfx(_held_item)
		inventory.place_item(_held_item, target, _held_rotation, _held_quantity)
		_clear_held()
		return
	var occupants := inventory.get_occupants(_held_item, target, _held_rotation)
	if occupants.size() != 1:
		return
	var occupant := occupants[0]
	if occupant.item.id == _held_item.id and occupant.quantity < occupant.item.max_stack:
		_play_place_sfx(_held_item)
		_held_quantity = inventory.merge_into(occupant, _held_quantity)
		if _held_quantity <= 0:
			_clear_held()
		else:
			_update_held_icon()
			queue_redraw()
		return
	if not inventory.can_place_at(_held_item, target, _held_rotation, occupant):
		return
	_play_place_sfx(_held_item)
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

# ---------------------------------------------------------------------------
# Cursor tooltip
# ---------------------------------------------------------------------------

func _build_cursor_tooltip() -> void:
	_cursor_tooltip = Control.new()
	_cursor_tooltip.top_level = true
	_cursor_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_tooltip.visible = false

	var bg := NinePatchRect.new()
	bg.texture = INFO_BG_TEX
	bg.patch_margin_left = BORDER_PATCH_MARGIN
	bg.patch_margin_top = BORDER_PATCH_MARGIN
	bg.patch_margin_right = BORDER_PATCH_MARGIN
	bg.patch_margin_bottom = BORDER_PATCH_MARGIN
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_tooltip.add_child(bg)

	var border := NinePatchRect.new()
	border.texture = INFO_BORDER_TEX
	border.patch_margin_left = BORDER_PATCH_MARGIN
	border.patch_margin_top = BORDER_PATCH_MARGIN
	border.patch_margin_right = BORDER_PATCH_MARGIN
	border.patch_margin_bottom = BORDER_PATCH_MARGIN
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_tooltip.add_child(border)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", TOOLTIP_PADDING)
	margin.add_theme_constant_override("margin_top", TOOLTIP_PADDING)
	margin.add_theme_constant_override("margin_right", TOOLTIP_PADDING)
	margin.add_theme_constant_override("margin_bottom", TOOLTIP_PADDING)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_tooltip.add_child(margin)

	_tooltip_vbox = VBoxContainer.new()
	_tooltip_vbox.custom_minimum_size = Vector2(TOOLTIP_MAX_WIDTH - TOOLTIP_PADDING * 2, 0)
	_tooltip_vbox.add_theme_constant_override("separation", 4)
	_tooltip_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_tooltip_vbox)

	add_child(_cursor_tooltip)

func _show_detail(item: ItemBase) -> void:
	_tt_clear_children(_tooltip_vbox)
	_cursor_tooltip.visible = true

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var decal_left := TextureRect.new()
	decal_left.texture = INFO_DECAL_TEX
	decal_left.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decal_left.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	decal_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(decal_left)
	header.add_child(_tt_make_label("Item Details", TT_FONT_SIZE, LABEL_COLOR))
	var decal_right := TextureRect.new()
	decal_right.texture = INFO_DECAL_TEX
	decal_right.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decal_right.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	decal_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(decal_right)
	_tooltip_vbox.add_child(header)
	_tooltip_vbox.add_child(_tt_make_spacer(4))

	var name_label := _tt_make_label(item.get_display_name(), TT_HEADER_SIZE)
	name_label.add_theme_color_override("font_color", item.get_rarity_color())
	_tooltip_vbox.add_child(name_label)

	var type_text := _tt_get_type_text(item)
	if not type_text.is_empty():
		_tooltip_vbox.add_child(_tt_make_label(type_text, TT_FONT_SIZE, MUTED_COLOR))

	_tooltip_vbox.add_child(_tt_make_divider())

	if item is Weapon:
		var w := item as Weapon
		if w.min_damage > 0.0 or w.max_damage > 0.0:
			_tooltip_vbox.add_child(_tt_make_icon_label(DMG_ICON,
				"%d-%d" % [roundi(w.min_damage), roundi(w.max_damage)], TT_VALUE_COLOR))
		if w.max_durability > 0:
			_tooltip_vbox.add_child(_tt_make_icon_label(DURABILITY_ICON,
				"%d/%d" % [w.durability, w.max_durability], TT_VALUE_COLOR))
		_tooltip_vbox.add_child(_tt_make_icon_label(ATK_SPEED_ICON,
			"%.2f" % w.get_effective_attack_speed(), TT_VALUE_COLOR))
	elif item is Armor:
		var a := item as Armor
		_tooltip_vbox.add_child(_tt_make_icon_label(ARMOR_ICON,
			"%d" % roundi(a.defense), TT_VALUE_COLOR))

	var affix_lines := item.get_affix_lines()
	var magic_lines: Array[String] = []
	magic_lines.append_array(affix_lines)
	if not item.magic_effect_pool.is_empty():
		var pool: Array = Array(item.magic_effect_pool)
		pool.shuffle()
		var count := clampi(item.magic_effect_count, 0, pool.size())
		for i in count:
			magic_lines.append(pool[i])

	if not magic_lines.is_empty():
		_tooltip_vbox.add_child(_tt_make_spacer(6))
		var visible_count := magic_lines.size() if _tooltip_expanded else mini(magic_lines.size(), MAX_COLLAPSED_AFFIXES)
		for i in visible_count:
			_tooltip_vbox.add_child(_tt_make_label(magic_lines[i], TT_FONT_SIZE, MAGIC_COLOR))
		if not _tooltip_expanded and magic_lines.size() > MAX_COLLAPSED_AFFIXES:
			_tooltip_vbox.add_child(_tt_make_spacer(4))
			_tooltip_vbox.add_child(_tt_make_hold_alt_hint())

	var has_reqs := item.required_level > 0 or item.required_strength > 0 or item.required_dexterity > 0
	if has_reqs:
		_tooltip_vbox.add_child(_tt_make_spacer(6))
		_tooltip_vbox.add_child(_tt_make_label("Required:", TT_FONT_SIZE, REQ_LABEL_COLOR))
		var req_parts: PackedStringArray = []
		if item.required_strength > 0:
			req_parts.append("Str: %d" % item.required_strength)
		if item.required_dexterity > 0:
			req_parts.append("Dex: %d" % item.required_dexterity)
		if item.required_level > 0:
			req_parts.append("Lvl: %d" % item.required_level)
		_tooltip_vbox.add_child(_tt_make_label("    ".join(req_parts), TT_FONT_SIZE, REQ_VALUE_COLOR))

	_tooltip_vbox.add_child(_tt_make_divider())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	_tooltip_vbox.add_child(footer)

	var total_value := item.get_total_value()
	if total_value > 0:
		footer.add_child(_tt_make_icon_label(COIN_ICON, str(total_value), LABEL_COLOR))
	if item.weight > 0.0:
		var wt := str(int(item.weight)) if is_equal_approx(item.weight, roundf(item.weight)) else "%.1f" % item.weight
		footer.add_child(_tt_make_icon_label(WEIGHT_ICON, wt, LABEL_COLOR))

	_resize_tooltip()
	_position_tooltip()

func _resize_tooltip() -> void:
	var margin_node: MarginContainer = _tooltip_vbox.get_parent() as MarginContainer
	if margin_node:
		var content_size := _tooltip_vbox.get_combined_minimum_size()
		var total := content_size + Vector2(TOOLTIP_PADDING * 2, TOOLTIP_PADDING * 2)
		_cursor_tooltip.size = total
		margin_node.size = total

func _position_tooltip() -> void:
	var pos := get_global_mouse_position() + TOOLTIP_OFFSET
	var viewport_size := get_viewport_rect().size
	pos.x = minf(pos.x, viewport_size.x - _cursor_tooltip.size.x - 2)
	pos.y = minf(pos.y, viewport_size.y - _cursor_tooltip.size.y - 2)
	_cursor_tooltip.position = pos

func _tt_get_type_text(item: ItemBase) -> String:
	if item is Weapon:
		return Weapon.WeaponType.keys()[(item as Weapon).weapon_type].capitalize()
	if item is Armor:
		return Armor.ArmorSlot.keys()[(item as Armor).armor_slot].capitalize() + " Armor"
	if item is Consumable:
		return Consumable.ConsumableType.keys()[(item as Consumable).consumable_type].capitalize()
	var cat_names := ["Weapon", "Armor", "Tool", "Ring", "Amulet", "Consumable", "Material", "Quest Item", "Rune Stone"]
	if item.category >= 0 and item.category < cat_names.size():
		return cat_names[item.category]
	return ""

func _tt_make_label(text: String, font_size: int, color: Color = TT_VALUE_COLOR) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", TT_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _tt_make_divider() -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = DIVIDER_TEX
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tex.custom_minimum_size.y = DIVIDER_TEX.get_height() * 2 + 12
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex

func _tt_make_spacer(h: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = h
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _tt_make_hold_alt_hint() -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.add_theme_font_size_override("normal_font_size", TT_FONT_SIZE - 2)
	rtl.add_theme_color_override("default_color", HINT_COLOR)
	rtl.text = "... Hold [color=#e4e0d8][Alt][/color] to view more"
	return rtl

func _tt_make_icon_label(icon: Texture2D, text: String, color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tex := TextureRect.new()
	tex.texture = icon
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.custom_minimum_size = Vector2(32, 32)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(tex)

	hbox.add_child(_tt_make_label(text, TT_FONT_SIZE, color))
	return hbox

func _tt_clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
