class_name NPCBase
extends CharacterBody2D
## Base for non-hostile characters: shopkeepers, quest givers, villagers.
## Doesn't extend EntityBase since most NPCs don't need combat/health —
## nothing stops you from also adding a HealthComponent/HurtboxComponent
## to a specific NPC if it should be killable or shovable.

@export var npc_name: String = "Villager"
@export var dialogue_lines: Array[String] = []

@onready var interaction: InteractionComponent = get_node_or_null("InteractionComponent")
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var _dialogue_index: int = 0

func _ready() -> void:
	if interaction:
		interaction.interacted.connect(_on_interacted)
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(&"idle"):
		animated_sprite.play(&"idle")

func _on_interacted(_interactor: Node) -> void:
	start_dialogue()

func start_dialogue() -> void:
	if dialogue_lines.is_empty():
		return
	_dialogue_index = 0
	Events.dialogue_started.emit(self)
	# Hook a DialogueUI (a MenuBase subclass) here to actually display
	# get_current_line(); have it call advance_dialogue() on confirm.

## Returns false (and fires dialogue_ended) once the conversation is over.
func advance_dialogue() -> bool:
	_dialogue_index += 1
	if _dialogue_index >= dialogue_lines.size():
		Events.dialogue_ended.emit()
		return false
	return true

func get_current_line() -> String:
	return dialogue_lines[_dialogue_index] if not dialogue_lines.is_empty() else ""
