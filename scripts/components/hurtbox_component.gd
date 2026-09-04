class_name HurtboxComponent
extends Area2D
## Where an entity can be hit. Kept separate from HealthComponent so
## non-living things (a destructible pot, a shield) can still receive
## hits and react without HP logic living inside the Area2D.

signal hit_received(amount: float, source: Node)

## Leave empty to auto-look-up a sibling "HealthComponent" on the parent.
@export var health_component_path: NodePath

func receive_hit(amount: float, source: Node, knockback: Vector2 = Vector2.ZERO) -> void:
	hit_received.emit(amount, source)
	var entity := get_parent()
	if entity is EntityBase:
		(entity as EntityBase).take_damage(amount, source, knockback)
		return
	var health: HealthComponent = _resolve_health()
	if health:
		health.take_damage(amount, source)

func _resolve_health() -> HealthComponent:
	if not health_component_path.is_empty():
		return get_node_or_null(health_component_path) as HealthComponent
	var parent := get_parent()
	return parent.get_node_or_null("HealthComponent") as HealthComponent if parent else null
