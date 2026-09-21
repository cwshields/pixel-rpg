class_name MenuBase
extends Control
## Base for any UI panel toggled by a key press (inventory, pause menu,
## dialogue box...). Registers itself with UIManager under `screen_name`
## and closes itself on `close_action` (defaults to the built-in
## ui_cancel action, i.e. Escape). Override _on_open()/_on_close() to
## refresh contents or play show/hide animations.

@export var screen_name: StringName
@export var close_action: StringName = &"ui_cancel"
## Optional: an action that opens AND closes this screen (e.g.
## "toggle_inventory"), handled here rather than by whatever key-pressing
## code wants the screen open. Read in _input() — a phase that always
## runs, unlike _unhandled_input() — so a stray focused Control elsewhere
## in the UI can never eat the second press and leave the screen stuck open.
@export var toggle_action: StringName = &""
## When true, opening this screen pauses the SceneTree (GameManager.PAUSED)
## instead of the lighter GameManager.MENU state. Screens that set this
## must also set their own process_mode to ALWAYS/WHEN_PAUSED so they can
## still handle input (and close themselves) while the tree is paused.
@export var pause_game: bool = false

func _ready() -> void:
	visible = false
	if screen_name != &"":
		UIManager.register_screen(screen_name, self)

func _input(event: InputEvent) -> void:
	if toggle_action != &"" and event.is_action_pressed(toggle_action):
		UIManager.toggle_screen(screen_name)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if visible and close_action != &"" and event.is_action_pressed(close_action):
		UIManager.close_screen(screen_name)
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	_on_open()

func close() -> void:
	visible = false
	_on_close()

## Override to refresh contents each time the screen opens.
func _on_open() -> void:
	pass

func _on_close() -> void:
	pass
