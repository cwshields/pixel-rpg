extends Node
## Owns the set of toggleable UI screens (autoload name: "UIManager").
##
## Screens (inventory, pause menu, dialogue box...) register themselves
## in their own _ready() via register_screen(). Anything else — the
## player reading a keypress, an NPC starting a conversation — just calls
## toggle_screen()/open_screen()/close_screen() by name and doesn't need
## a reference to the screen node itself.

var _screens: Dictionary = {}       # StringName -> MenuBase
var _open_stack: Array[StringName] = []

func register_screen(screen_name: StringName, screen: Control) -> void:
	_screens[screen_name] = screen

func toggle_screen(screen_name: StringName) -> void:
	if _open_stack.has(screen_name):
		close_screen(screen_name)
	else:
		open_screen(screen_name)

func open_screen(screen_name: StringName) -> void:
	if not _screens.has(screen_name):
		push_warning("UIManager: no screen registered as '%s'" % screen_name)
		return
	if _open_stack.has(screen_name):
		return
	var screen: MenuBase = _screens[screen_name]
	screen.open()
	_open_stack.append(screen_name)
	_update_state()
	Events.ui_toggled.emit(screen_name, true)

func close_screen(screen_name: StringName) -> void:
	if not _screens.has(screen_name) or not _open_stack.has(screen_name):
		return
	_screens[screen_name].close()
	_open_stack.erase(screen_name)
	_update_state()
	Events.ui_toggled.emit(screen_name, false)

func is_any_open() -> bool:
	return not _open_stack.is_empty()

## Re-derives GameManager's state from whatever's left in `_open_stack`,
## rather than just reacting to the stack going empty. Without this, closing
## a pause_game screen (pause menu) while a lighter MENU screen (inventory)
## is still open underneath left the tree stuck paused forever — nothing
## short of PauseMenu's own ALWAYS process_mode could still get input to
## unpause it.
func _update_state() -> void:
	if _open_stack.is_empty():
		GameManager.set_state(GameManager.GameState.PLAYING)
		return
	for screen_name in _open_stack:
		if (_screens[screen_name] as MenuBase).pause_game:
			GameManager.set_state(GameManager.GameState.PAUSED)
			return
	GameManager.set_state(GameManager.GameState.MENU)
