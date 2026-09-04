extends Node
## Global game state (autoload name: "GameManager").
##
## Holds things exactly one of which exists at a time: whose turn it is
## to receive input, whether the game is paused, and a reachable
## reference to the current player. Anything that needs "the player" or
## "are we paused" reads it from here instead of doing a scene-tree
## search.

enum GameState { PLAYING, PAUSED, MENU, DIALOGUE, CUTSCENE }

var state: GameState = GameState.PLAYING
var player: Node = null

func register_player(p: Node) -> void:
	player = p
	Events.player_spawned.emit(p)

func set_state(new_state: GameState) -> void:
	if state == new_state:
		return
	state = new_state
	get_tree().paused = state == GameState.PAUSED

func is_playing() -> bool:
	return state == GameState.PLAYING
