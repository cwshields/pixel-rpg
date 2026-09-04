class_name Consumable
extends ItemBase
## Potions, food, scrolls, elixirs — anything used up from the inventory
## for an immediate or timed effect.

enum ConsumableType { POTION, FOOD, SCROLL, ELIXIR }

@export var consumable_type: ConsumableType = ConsumableType.POTION
@export var heal_amount: float = 0.0
@export var stamina_amount: float = 0.0
## Optional timed buff, e.g. buff_stat=&"attack", buff_amount=3.0,
## buff_duration=30.0. Leave buff_stat empty to skip.
@export var buff_stat: StringName = &""
@export var buff_amount: float = 0.0
@export var buff_duration: float = 0.0

func _init() -> void:
	category = Category.CONSUMABLE

func use(user: Node) -> bool:
	var health: HealthComponent = user.get_node_or_null("HealthComponent")
	if health and heal_amount > 0.0:
		health.heal(heal_amount)
	if buff_stat != &"" and user is EntityBase and (user as EntityBase).stats:
		_apply_timed_buff(user as EntityBase)
	return true

func _apply_timed_buff(entity: EntityBase) -> void:
	var stats: StatsComponent = entity.stats
	var source_id := StringName("consumable_%s_%d" % [id, Time.get_ticks_msec()])
	stats.add_modifier(buff_stat, buff_amount, source_id)
	if buff_duration > 0.0:
		var timer: SceneTreeTimer = entity.get_tree().create_timer(buff_duration)
		timer.timeout.connect(func() -> void: stats.remove_modifier(buff_stat, source_id))
