class_name SaveLoadDialog
extends Panel
## Save/load dialog shown from the pause menu. Displays a scrollable list
## of existing saves with metadata, a name input for new saves, and
## Save / Load / Delete / Cancel buttons.

signal save_requested(slot_name: String)
signal load_requested(slot_name: String)
signal cancelled

@onready var _save_list: ItemList = %SaveList
@onready var _slot_name_input: LineEdit = %SlotNameInput
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _delete_button: Button = %DeleteButton
@onready var _cancel_button: Button = %CancelButton
@onready var _open_folder_button: Button = %OpenFolderButton

var _saves: Array[Dictionary] = []

func _ready() -> void:
	_save_button.pressed.connect(_on_save)
	_load_button.pressed.connect(_on_load)
	_delete_button.pressed.connect(_on_delete)
	_cancel_button.pressed.connect(func() -> void: cancelled.emit())
	_open_folder_button.pressed.connect(_on_open_folder)
	_save_list.item_selected.connect(_on_item_selected)
	_slot_name_input.text_changed.connect(_on_name_changed)

func refresh() -> void:
	_saves = SaveManager.list_saves()
	_save_list.clear()
	for info: Dictionary in _saves:
		var label := _format_entry(info)
		_save_list.add_item(label)
	_update_buttons()

func _format_entry(info: Dictionary) -> String:
	var name_part: String = info["slot_name"]
	var ts: String = info.get("timestamp", "")
	var level: int = info.get("level", 1)
	var gold: int = info.get("gold", 0)
	if ts.length() > 16:
		ts = ts.substr(0, 16).replace("T", " ")
	return "%s  |  Lv %d  |  %d gold  |  %s" % [name_part, level, gold, ts]

func _on_item_selected(index: int) -> void:
	if index >= 0 and index < _saves.size():
		_slot_name_input.text = _saves[index]["slot_name"]
	_update_buttons()

func _on_name_changed(_new_text: String) -> void:
	_update_buttons()

func _update_buttons() -> void:
	var name_valid := not _slot_name_input.text.strip_edges().is_empty()
	var has_selection := _save_list.is_anything_selected()
	_save_button.disabled = not name_valid
	_load_button.disabled = not has_selection
	_delete_button.disabled = not has_selection

func _on_save() -> void:
	var slot_name := _slot_name_input.text.strip_edges()
	if slot_name.is_empty():
		return
	save_requested.emit(slot_name)

func _on_load() -> void:
	var selected := _save_list.get_selected_items()
	if selected.is_empty():
		return
	var info: Dictionary = _saves[selected[0]]
	load_requested.emit(info["slot_name"])

func _on_delete() -> void:
	var selected := _save_list.get_selected_items()
	if selected.is_empty():
		return
	var info: Dictionary = _saves[selected[0]]
	SaveManager.delete_save(info["slot_name"])
	refresh()

func _on_open_folder() -> void:
	OS.shell_open(SaveManager.get_save_dir())
