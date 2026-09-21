class_name InventoryUI
extends MenuBase
## Tetris-grid display of GameManager.player's inventory. Toggled open and
## closed by the "toggle_inventory" action (Tab; see MenuBase.toggle_action,
## set on this scene's root node). Expects an InventoryGrid child named
## "Grid" (accessed via the %-unique-name shortcut, so mark that node
## "Access as Unique Name" in the editor).

@onready var grid: InventoryGrid = %Grid

func _on_open() -> void:
	# See item_spawner_ui.gd's _on_open() — the two screens are mutually
	# exclusive since both embed an InventoryGrid on the same Inventory.
	UIManager.close_screen(&"item_spawner")
	var player: Player = GameManager.player
	if player:
		grid.setup(player.inventory)

func _on_close() -> void:
	grid.cancel_held_item()
