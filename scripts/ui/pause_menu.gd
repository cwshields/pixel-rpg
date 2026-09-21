class_name PauseMenu
extends MenuBase
## Escape-triggered pause screen (see MenuBase / UIManager). Unlike other
## MenuBase screens it drives its own open/close entirely — it's the only
## thing on "pause" — and runs with process_mode ALWAYS so it keeps
## receiving input while GameManager.PAUSED has frozen everything else.
##
## Options is a second view swapped into the same panel rather than a
## separate registered screen; there's no persisted settings system yet,
## so Master volume and fullscreen just apply live via AudioServer /
## DisplayServer and reset to whatever those already are on next open.

@onready var _main_panel: Control = %MainPanel
@onready var _options_panel: Control = %OptionsPanel
@onready var _resume_button: Button = %ResumeButton
@onready var _options_button: Button = %OptionsButton
@onready var _exit_button: Button = %ExitButton
@onready var _back_button: Button = %BackButton
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _fullscreen_check: CheckButton = %FullscreenCheck

var _master_bus: int = AudioServer.get_bus_index("Master")

func _ready() -> void:
	super._ready()
	_resume_button.pressed.connect(func() -> void: UIManager.close_screen(screen_name))
	_options_button.pressed.connect(_show_options)
	_back_button.pressed.connect(_show_main)
	_exit_button.pressed.connect(func() -> void: get_tree().quit())
	_volume_slider.value_changed.connect(_on_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

## Overrides MenuBase's close_action handling entirely: this is the single
## place "pause" gets toggled, so it must work whether or not the tree is
## currently paused.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		UIManager.toggle_screen(screen_name)
		get_viewport().set_input_as_handled()

func _on_open() -> void:
	_show_main()
	_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(_master_bus))
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_resume_button.grab_focus()

func _show_main() -> void:
	_main_panel.show()
	_options_panel.hide()

func _show_options() -> void:
	_main_panel.hide()
	_options_panel.show()
	_back_button.grab_focus()

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(value))

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
