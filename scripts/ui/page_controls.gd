class_name PageControls
extends Control

signal page_changed(page: int)

var _current_page: int = 1
var _page_count: int = 1

@onready var _btn_left: TextureButton = %LeftBtn
@onready var _btn_right: TextureButton = %RightBtn
@onready var _label: Label = %PageLabel

func _ready() -> void:
	_btn_left.pressed.connect(_on_prev)
	_btn_right.pressed.connect(_on_next)
	_refresh()

func set_page_count(count: int) -> void:
	_page_count = maxi(count, 1)
	_current_page = clampi(_current_page, 1, _page_count)
	_refresh()

func set_page(page: int) -> void:
	_current_page = clampi(page, 1, _page_count)
	_refresh()
	page_changed.emit(_current_page)

func _on_prev() -> void:
	if _current_page > 1:
		set_page(_current_page - 1)

func _on_next() -> void:
	if _current_page < _page_count:
		set_page(_current_page + 1)

func _refresh() -> void:
	if _label:
		_label.text = "%d / %d" % [_current_page, _page_count]
	if _btn_left:
		_btn_left.disabled = _current_page <= 1
	if _btn_right:
		_btn_right.disabled = _current_page >= _page_count
