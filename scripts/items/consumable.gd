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
	var entity := user as EntityBase
	if entity and entity.health and heal_amount > 0.0:
		entity.health.heal(heal_amount)
	if entity and stamina_amount > 0.0:
		var stamina := entity.get_node_or_null("StaminaComponent") as StaminaComponent
		if stamina:
			stamina.restore(stamina_amount)
	if buff_stat != &"" and entity and entity.stats:
		_apply_timed_buff(entity)
	return true

func get_stat_lines() -> Array[String]:
	var lines: Array[String] = []
	if heal_amount > 0.0:
		lines.append("Restores %d Health" % roundi(heal_amount))
	if stamina_amount > 0.0:
		lines.append("Restores %d Stamina" % roundi(stamina_amount))
	if buff_stat != &"" and buff_amount != 0.0:
		var sign_str := "+" if buff_amount > 0.0 else ""
		var dur_str := " (%ds)" % roundi(buff_duration) if buff_duration > 0.0 else ""
		lines.append("%s%d %s%s" % [sign_str, roundi(buff_amount), buff_stat, dur_str])
	return lines

func _apply_timed_buff(entity: EntityBase) -> void:
	var stats: StatsComponent = entity.stats
	var source_id := StringName("consumable_%s_%d" % [id, Time.get_ticks_msec()])
	stats.add_modifier(buff_stat, buff_amount, source_id)
	if buff_duration > 0.0:
		var timer: SceneTreeTimer = entity.get_tree().create_timer(buff_duration)
		timer.timeout.connect(func() -> void: stats.remove_modifier(buff_stat, source_id))
