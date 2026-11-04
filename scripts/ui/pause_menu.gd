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
@onready var _save_load_panel: SaveLoadDialog = %SaveLoadPanel
@onready var _resume_button: Button = %ResumeButton
@onready var _options_button: Button = %OptionsButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _save_exit_button: Button = %SaveExitButton
@onready var _back_button: Button = %BackButton
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _ambience_slider: HSlider = %AmbienceSlider
@onready var _voice_slider: HSlider = %VoiceSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _ambience_value: Label = %AmbienceValue
@onready var _voice_value: Label = %VoiceValue
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _damage_numbers_check: CheckButton = %DamageNumbersCheck
@onready var _health_bars_check: CheckButton = %HealthBarsCheck

const _DebugHealthBarScript: GDScript = preload("res://scripts/ui/debug_health_bar.gd")

var _master_bus: int
var _ambience_bus: int
var _voice_bus: int

func _ready() -> void:
	_master_bus = AudioServer.get_bus_index("Master")
	_ambience_bus = AudioServer.get_bus_index("Ambience")
	_voice_bus = AudioServer.get_bus_index("Voice")
	super._ready()
	_resume_button.pressed.connect(func() -> void: UIManager.close_screen(screen_name))
	_options_button.pressed.connect(_show_options)
	_back_button.pressed.connect(_show_main)
	_new_game_button.pressed.connect(_on_new_game)
	_load_game_button.pressed.connect(_show_save_load)
	_save_exit_button.pressed.connect(_on_save_and_exit)
	_save_load_panel.save_requested.connect(_on_dialog_save)
	_save_load_panel.load_requested.connect(_on_dialog_load)
	_save_load_panel.cancelled.connect(_show_main)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_ambience_slider.value_changed.connect(_on_ambience_changed)
	_voice_slider.value_changed.connect(_on_voice_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	_health_bars_check.toggled.connect(_on_health_bars_toggled)
	if GameManager.show_health_bars:
		_add_health_bars_to_all()
		get_tree().node_added.connect(_on_node_added_health_bar)

## Overrides MenuBase's close_action handling entirely: this is the single
## place "pause" gets toggled, so it must work whether or not the tree is
## currently paused.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		UIManager.toggle_screen(screen_name)
		get_viewport().set_input_as_handled()

func _on_open() -> void:
	_show_main()
	_volume_slider.value = snappedf(db_to_linear(AudioServer.get_bus_volume_db(_master_bus)), 0.01)
	_ambience_slider.value = snappedf(db_to_linear(AudioServer.get_bus_volume_db(_ambience_bus)), 0.01)
	_voice_slider.value = snappedf(db_to_linear(AudioServer.get_bus_volume_db(_voice_bus)), 0.01)
	_update_value_labels()
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_damage_numbers_check.button_pressed = GameManager.show_damage_numbers
	_health_bars_check.button_pressed = GameManager.show_health_bars
	_resume_button.grab_focus()

func _show_main() -> void:
	_main_panel.show()
	_options_panel.hide()
	_save_load_panel.hide()

func _show_options() -> void:
	_main_panel.hide()
	_options_panel.show()
	_save_load_panel.hide()
	_back_button.grab_focus()

func _show_save_load() -> void:
	_main_panel.hide()
	_options_panel.hide()
	_save_load_panel.show()
	_save_load_panel.refresh()

func _on_volume_changed(value: float) -> void:
	var rounded := snappedf(value, 0.01)
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(rounded))
	_update_value_labels()
	_persist_settings()

func _on_ambience_changed(value: float) -> void:
	var rounded := snappedf(value, 0.01)
	AudioServer.set_bus_volume_db(_ambience_bus, linear_to_db(rounded))
	_update_value_labels()
	_persist_settings()

func _on_voice_changed(value: float) -> void:
	var rounded := snappedf(value, 0.01)
	AudioServer.set_bus_volume_db(_voice_bus, linear_to_db(rounded))
	_update_value_labels()
	_persist_settings()

func _update_value_labels() -> void:
	_volume_value.text = "%d%%" % roundi(_volume_slider.value * 100.0)
	_ambience_value.text = "%d%%" % roundi(_ambience_slider.value * 100.0)
	_voice_value.text = "%d%%" % roundi(_voice_slider.value * 100.0)

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	_persist_settings()

func _on_damage_numbers_toggled(pressed: bool) -> void:
	GameManager.show_damage_numbers = pressed
	_persist_settings()

func _on_health_bars_toggled(pressed: bool) -> void:
	GameManager.show_health_bars = pressed
	if pressed:
		_add_health_bars_to_all()
		get_tree().node_added.connect(_on_node_added_health_bar)
	else:
		if get_tree().node_added.is_connected(_on_node_added_health_bar):
			get_tree().node_added.disconnect(_on_node_added_health_bar)
		_remove_all_health_bars()
	_persist_settings()

func _add_health_bars_to_all() -> void:
	for entity in get_tree().get_nodes_in_group("entities"):
		_ensure_health_bar(entity)

func _ensure_health_bar(node: Node) -> void:
	if not node is AIEntityBase:
		return
	var entity := node as AIEntityBase
	if not entity.health or entity.is_dead():
		return
	if entity.get_node_or_null("DebugHealthBar"):
		return
	var bar: Node2D = _DebugHealthBarScript.new()
	bar.name = "DebugHealthBar"
	entity.add_child(bar)

func _on_node_added_health_bar(node: Node) -> void:
	if node is AIEntityBase:
		if node.is_node_ready():
			_ensure_health_bar(node)
		else:
			node.ready.connect(_ensure_health_bar.bind(node), CONNECT_ONE_SHOT)

func _remove_all_health_bars() -> void:
	for entity in get_tree().get_nodes_in_group("entities"):
		var bar := entity.get_node_or_null("DebugHealthBar")
		if bar:
			bar.queue_free()

func _persist_settings() -> void:
	SaveManager.save_settings({
		"master_volume": snappedf(db_to_linear(AudioServer.get_bus_volume_db(_master_bus)), 0.01),
		"ambience_volume": snappedf(db_to_linear(AudioServer.get_bus_volume_db(_ambience_bus)), 0.01),
		"voice_volume": snappedf(db_to_linear(AudioServer.get_bus_volume_db(_voice_bus)), 0.01),
		"fullscreen": DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"damage_numbers": GameManager.show_damage_numbers,
		"health_bars": GameManager.show_health_bars,
	})

func _on_new_game() -> void:
	SaveManager.delete_all_saves()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_dialog_save(slot_name: String) -> void:
	SaveManager.save_game(slot_name)
	_save_load_panel.refresh()

func _on_dialog_load(slot_name: String) -> void:
	if SaveManager.load_game(slot_name):
		get_tree().paused = false
		get_tree().reload_current_scene()

func _on_save_and_exit() -> void:
	SaveManager.save_game()
	get_tree().quit()
