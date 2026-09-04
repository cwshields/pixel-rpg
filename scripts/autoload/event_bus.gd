extends Node
## Global signal bus (autoload name: "Events").
##
## Decouples systems that shouldn't hold direct references to each other —
## e.g. the HUD reacts to health changes without needing a reference to
## whatever entity took damage. Prefer a direct signal connection when two
## nodes already know about each other (e.g. parent/child); reach for this
## bus when they don't.

signal player_spawned(player: Node)
signal health_changed(entity: Node, current: float, max: float)
signal entity_died(entity: Node)
signal item_picked_up(item: Resource, amount: int)
signal inventory_changed
signal dialogue_started(npc: Node)
signal dialogue_ended
## Fired whenever a UI screen registered with UIManager opens or closes.
signal ui_toggled(screen_name: StringName, is_open: bool)
