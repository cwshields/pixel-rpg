class_name Inventory
extends RefCounted
## Tetris-style grid inventory. Each placed stack occupies a set of cells
## defined by its ItemBase.shape (rotated in 90-degree steps), instead of
## every item taking exactly one uniform slot — a 2x1 sword and a 1x1
## gem both fit without stretching or squashing their icons.
##
## A RefCounted (not a Resource) because each entity needs its own
## independent instance — Resources are shared by reference unless you
## remember to duplicate() them everywhere.

signal changed

class PlacedItem:
	var item: ItemBase
	var quantity: int
	var pos: Vector2i       ## Top-left cell of the shape's own (unrotated) bounding box.
	var rotation: int       ## Quarter-turns clockwise (0-3) applied to item.shape.
	func _init(p_item: ItemBase, p_quantity: int, p_pos: Vector2i, p_rotation: int = 0) -> void:
		item = p_item
		quantity = p_quantity
		pos = p_pos
		rotation = p_rotation

var width: int
var height: int
## Insertion-ordered list of everything placed in the grid. Hotbar (and
## anything else that wants "the first N items") reads this directly.
var items: Array[PlacedItem] = []
## Flat width*height occupancy grid; each cell holds the PlacedItem
## covering it, or null. Kept in lockstep with `items` by _paint().
var _grid: Array[PlacedItem] = []

func _init(p_width: int = 7, p_height: int = 12) -> void:
	width = p_width
	height = p_height
	_grid.resize(width * height)

## `item`'s footprint cells (relative to its own top-left corner) after
## rotating `rotation` quarter-turns clockwise.
func get_rotated_cells(item: ItemBase, rotation: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = item.get_shape_cells()
	var dims := _cell_bounds(cells)
	for i in ((rotation % 4) + 4) % 4:
		var rotated: Array[Vector2i] = []
		for c in cells:
			rotated.append(Vector2i(dims.y - 1 - c.y, c.x))
		cells = rotated
		dims = Vector2i(dims.y, dims.x)
	return cells

## Same cells, translated to absolute grid coordinates.
func get_world_cells(item: ItemBase, pos: Vector2i, rotation: int) -> Array[Vector2i]:
	var world: Array[Vector2i] = []
	for c in get_rotated_cells(item, rotation):
		world.append(pos + c)
	return world

## True if `item` fits entirely in-bounds at `pos`/`rotation` without
## overlapping any other placed stack. Pass `ignore` (e.g. the stack
## being dragged) to let it overlap its own current cells.
func can_place_at(item: ItemBase, pos: Vector2i, rotation: int = 0, ignore: PlacedItem = null) -> bool:
	for cell in get_world_cells(item, pos, rotation):
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			return false
		var occupant := _grid[cell.y * width + cell.x]
		if occupant != null and occupant != ignore:
			return false
	return true

## Every distinct placed stack whose cells overlap `item`'s footprint at
## `pos`/`rotation` (out-of-bounds cells are skipped, not counted). A
## multi-cell item can cover several cells of the same occupant — each
## occupant is only reported once.
func get_occupants(item: ItemBase, pos: Vector2i, rotation: int = 0) -> Array[PlacedItem]:
	var occupants: Array[PlacedItem] = []
	for cell in get_world_cells(item, pos, rotation):
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			continue
		var occupant := _grid[cell.y * width + cell.x]
		if occupant != null and not occupants.has(occupant):
			occupants.append(occupant)
	return occupants

## First free (row-major) position `item` fits in, trying rotation 0 first
## and then 90/180/270 if the item allows rotating. Empty dict if nothing fits.
func find_free_placement(item: ItemBase) -> Dictionary:
	var rotations := [0, 1, 2, 3] if item.can_rotate else [0]
	for y in height:
		for x in width:
			var pos := Vector2i(x, y)
			for rot in rotations:
				if can_place_at(item, pos, rot):
					return {"pos": pos, "rotation": rot}
	return {}

## Places a new stack and marks its cells occupied. Caller is expected to
## have already checked can_place_at() — this doesn't re-validate.
func place_item(item: ItemBase, pos: Vector2i, rotation: int, quantity: int) -> PlacedItem:
	var placed := PlacedItem.new(item, quantity, pos, rotation)
	items.append(placed)
	_paint(placed, placed)
	changed.emit()
	Events.inventory_changed.emit()
	return placed

func remove_placed(placed: PlacedItem) -> void:
	if not items.has(placed):
		return
	_paint(placed, null)
	items.erase(placed)
	changed.emit()
	Events.inventory_changed.emit()

## Moves an already-placed stack to a new position/rotation. Returns false
## (leaving it untouched) if it doesn't fit there.
func move_item(placed: PlacedItem, pos: Vector2i, rotation: int) -> bool:
	if not can_place_at(placed.item, pos, rotation, placed):
		return false
	_paint(placed, null)
	placed.pos = pos
	placed.rotation = rotation
	_paint(placed, placed)
	changed.emit()
	Events.inventory_changed.emit()
	return true

## Rotates a placed stack 90 degrees clockwise in place; false (no-op) if
## the item can't be rotated or the rotated footprint no longer fits.
func rotate_item(placed: PlacedItem) -> bool:
	if not placed.item.can_rotate:
		return false
	return move_item(placed, placed.pos, placed.rotation + 1)

## Adds `amount` of `item`: stacks onto existing matching stacks with
## spare room first, then drops new stacks into free grid space up to
## capacity. Returns whatever didn't fit (0 if everything was added).
func add_item(item: ItemBase, amount: int = 1) -> int:
	var remaining: int = amount
	var stacked := false
	if item.max_stack > 1:
		for placed in items:
			if remaining <= 0:
				break
			if placed.item.id == item.id and placed.quantity < placed.item.max_stack:
				var added := _stack_onto(placed, remaining)
				remaining -= added
				if added > 0:
					stacked = true
	while remaining > 0:
		var placement := find_free_placement(item)
		if placement.is_empty():
			break
		var to_add: int = mini(item.max_stack, remaining)
		place_item(item, placement.pos, placement.rotation, to_add)
		remaining -= to_add
	if stacked:
		changed.emit()
		Events.inventory_changed.emit()
	return remaining

## Tops off an already-placed stack with up to `amount` more, capped at its
## max_stack. Returns the leftover that didn't fit (0 if it all merged in).
func merge_into(placed: PlacedItem, amount: int) -> int:
	var added := _stack_onto(placed, amount)
	if added > 0:
		changed.emit()
		Events.inventory_changed.emit()
	return amount - added

## Raw stacking arithmetic shared by add_item and merge_into — no signal
## emission, since callers batch or gate that themselves.
func _stack_onto(placed: PlacedItem, amount: int) -> int:
	var space: int = placed.item.max_stack - placed.quantity
	var to_add: int = mini(space, amount)
	placed.quantity += to_add
	return to_add

## Removes up to `amount` of the item matching `item_id`, freeing cells as
## stacks empty out. Returns false (removing nothing) if the inventory
## doesn't hold that much.
func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if count_item(item_id) < amount:
		return false
	var remaining: int = amount
	for i in range(items.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var placed: PlacedItem = items[i]
		if placed.item.id != item_id:
			continue
		var take: int = mini(placed.quantity, remaining)
		placed.quantity -= take
		remaining -= take
		if placed.quantity <= 0:
			_paint(placed, null)
			items.remove_at(i)
	changed.emit()
	Events.inventory_changed.emit()
	return true

func count_item(item_id: StringName) -> int:
	var total: int = 0
	for placed in items:
		if placed.item.id == item_id:
			total += placed.quantity
	return total

func has_item(item_id: StringName, amount: int = 1) -> bool:
	return count_item(item_id) >= amount

func _paint(placed: PlacedItem, value: PlacedItem) -> void:
	for cell in get_world_cells(placed.item, placed.pos, placed.rotation):
		_grid[cell.y * width + cell.x] = value

func _cell_bounds(cells: Array[Vector2i]) -> Vector2i:
	var w := 0
	var h := 0
	for c in cells:
		w = maxi(w, c.x + 1)
		h = maxi(h, c.y + 1)
	return Vector2i(w, h)
