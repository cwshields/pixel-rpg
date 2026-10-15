class_name NPCBase
extends CharacterBody2D
## Base for non-hostile characters: shopkeepers, quest givers, villagers.
## Doesn't extend EntityBase since most NPCs don't need combat/health —
## nothing stops you from also adding a HealthComponent/HurtboxComponent
## to a specific NPC if it should be killable or shovable.

@export var npc_name: String = "Villager"
@export var dialogue_lines: Array[String] = []
@export var gossip_lines: Array[String] = []
@export var has_shop: bool = false

var shop_inventory: ShopInventory = null

@onready var interaction: InteractionComponent = get_node_or_null("InteractionComponent")
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var _dialogue_index: int = 0
var _player_in_range: bool = false
var _interaction_prompt: Label

func _ready() -> void:
	_interaction_prompt = _build_prompt()
	if interaction:
		interaction.interacted.connect(_on_interacted)
		interaction.area_entered.connect(_on_detector_entered)
		interaction.area_exited.connect(_on_detector_exited)
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(&"idle"):
		animated_sprite.play(&"idle")
	Events.dialogue_ended.connect(_on_dialogue_ended)

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

func _get_interact_key_name() -> String:
	var events := InputMap.action_get_events("interact")
	for event in events:
		if event is InputEventKey:
			return event.as_text_keycode()
	return "?"

func _refresh_prompt_text() -> void:
	_interaction_prompt.text = "[%s] Interact" % _get_interact_key_name()

func _show_prompt() -> void:
	_refresh_prompt_text()
	_interaction_prompt.visible = true

func _hide_prompt() -> void:
	_interaction_prompt.visible = false

func _on_detector_entered(_area: Area2D) -> void:
	_player_in_range = true
	if not UIManager.is_any_open():
		_show_prompt()

func _on_detector_exited(_area: Area2D) -> void:
	_player_in_range = false
	_hide_prompt()

func _on_interacted(_interactor: Node) -> void:
	start_dialogue()

func start_dialogue() -> void:
	_hide_prompt()
	_dialogue_index = 0
	Events.dialogue_started.emit(self)

func _on_dialogue_ended() -> void:
	if _player_in_range:
		_show_prompt()

## Returns false (and fires dialogue_ended) once the conversation is over.
func advance_dialogue() -> bool:
	_dialogue_index += 1
	if _dialogue_index >= dialogue_lines.size():
		Events.dialogue_ended.emit()
		return false
	return true

func get_current_line() -> String:
	return dialogue_lines[_dialogue_index] if not dialogue_lines.is_empty() else ""

func get_random_gossip() -> String:
	if gossip_lines.is_empty():
		return ""
	return gossip_lines[randi() % gossip_lines.size()]
