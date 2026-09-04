class_name Main
extends Node2D
## Boots the game. This is the one script that's allowed to know how the
## world scene, the player, and the UI layer all fit together — attach
## it to the root node of your main scene (scenes/main.tscn).
##
## The player is a permanent child of Entities — visible and editable in
## the editor's Local scene tab at all times, running or not — rather
## than spawned here at runtime. Move it around directly to change its
## starting position. World/PlayerSpawn is kept as a reference marker
## (handy for wiring up a respawn point later) but isn't used by code.

func _ready() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
