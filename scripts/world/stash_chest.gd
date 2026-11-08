class_name StashChest
extends StaticBody2D
## An interactable chest in the world that opens the stash UI.

@onready var _interaction: InteractionComponent = $InteractionComponent
@onready var _sprite: Sprite2D = $Sprite2D
var _player_in_range: bool = false
var _prompt: Label

func _ready() -> void:
	_prompt = _build_prompt()
	if _interaction:
		_interaction.one_shot = false
		_interaction.interacted.connect(_on_interacted)
		_interaction.area_entered.connect(func(_a: Area2D) -> void:
			_player_in_range = true
			if not UIManager.is_any_open():
				_show_prompt())
		_interaction.area_exited.connect(func(_a: Area2D) -> void:
			_player_in_range = false
			_hide_prompt())
	Events.dialogue_ended.connect(func() -> void:
		if _player_in_range:
			_show_prompt())

func _on_interacted(_interactor: Node) -> void:
	_hide_prompt()
	var stash_ui := UIManager.get_screen(&"stash") as StashUI
	if stash_ui:
		stash_ui.setup_stash(GameManager.stash)
	UIManager.open_screen(&"stash")

func _build_prompt() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -44)
	label.size = Vector2(100, 20)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	add_child(label)
	return label

func _show_prompt() -> void:
	var events := InputMap.action_get_events("interact")
	var key_name := "?"
	for event in events:
		if event is InputEventKey:
			key_name = event.as_text_keycode()
			break
	_prompt.text = "[%s] Stash" % key_name
	_prompt.visible = true

func _hide_prompt() -> void:
	_prompt.visible = false
