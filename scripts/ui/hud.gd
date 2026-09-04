class_name HUD
extends CanvasLayer
## Always-on-screen UI: health bar and anything else that should be
## visible outside of a toggled menu. Listens to Events instead of
## holding a direct player reference so it survives the player
## respawning/being reassigned.

@onready var health_bar: ProgressBar = %HealthBar

func _ready() -> void:
	Events.health_changed.connect(_on_health_changed)

func _on_health_changed(entity: Node, current: float, max_health: float) -> void:
	if entity == GameManager.player:
		health_bar.max_value = max_health
		health_bar.value = current
