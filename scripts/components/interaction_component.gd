class_name InteractionComponent
extends Area2D
## Marks something the player can interact with: an NPC, a chest, a
## sign, a crafting station. Put it on layer 8 (see the collision-layer
## legend in README.md) and give the player an "InteractionDetector"
## Area2D masked to that layer.

signal interacted(interactor: Node)

@export var prompt_text: String = "Talk"
## For things you can only trigger once (a one-time loot chest, a sign
## you've already read out loud).
@export var one_shot: bool = false

var _used: bool = false

func can_interact(_interactor: Node) -> bool:
	return not (one_shot and _used)

func interact(interactor: Node) -> void:
	if not can_interact(interactor):
		return
	_used = true
	interacted.emit(interactor)
