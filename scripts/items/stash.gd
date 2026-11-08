class_name Stash
extends RefCounted
## Persistent multi-page storage. Each page is an independent Inventory grid
## of the same dimensions as the player's inventory. Pages are created lazily
## but the page count is fixed at construction.

signal page_changed(page_index: int)

var page_count: int
var width: int
var height: int
var _pages: Array[Inventory] = []
var _current_page: int = 0

func _init(p_page_count: int = 10, p_width: int = 12, p_height: int = 9) -> void:
	page_count = p_page_count
	width = p_width
	height = p_height
	for i in page_count:
		_pages.append(Inventory.new(width, height))

func get_page(index: int) -> Inventory:
	return _pages[clampi(index, 0, page_count - 1)]

func get_current_page() -> Inventory:
	return _pages[_current_page]

func get_current_page_index() -> int:
	return _current_page

func set_current_page(index: int) -> void:
	_current_page = clampi(index, 0, page_count - 1)
	page_changed.emit(_current_page)
