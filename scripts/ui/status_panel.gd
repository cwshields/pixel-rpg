class_name StatusPanel
extends Control

@onready var _health_bar: TextureProgressBar = $HealthRow/Bar
@onready var _health_value: Label = $HealthRow/ValueLabel
@onready var _stamina_bar: TextureProgressBar = $StaminaRow/Bar
@onready var _stamina_value: Label = $StaminaRow/ValueLabel
@onready var _hunger_bar: TextureProgressBar = $HungerRow/Bar
@onready var _hunger_value: Label = $HungerRow/ValueLabel
@onready var _mana_bar: TextureProgressBar = $ManaRow/Bar
@onready var _mana_value: Label = $ManaRow/ValueLabel

var _bars: Dictionary = {}
var _value_labels: Dictionary = {}

func _ready() -> void:
	_bars = {
		&"health": _health_bar,
		&"stamina": _stamina_bar,
		&"hunger": _hunger_bar,
		&"mana": _mana_bar,
	}
	_value_labels = {
		&"health": _health_value,
		&"stamina": _stamina_value,
		&"hunger": _hunger_value,
		&"mana": _mana_value,
	}

	Events.health_changed.connect(_on_health_changed)
	Events.stamina_changed.connect(_on_stamina_changed)
	Events.mana_changed.connect(_on_mana_changed)
	Events.hunger_changed.connect(_on_hunger_changed)
	Events.player_spawned.connect(_on_player_spawned)
	if GameManager.player:
		_on_player_spawned(GameManager.player)

func _on_player_spawned(player: Node) -> void:
	var entity := player as EntityBase
	if entity and entity.health:
		_on_health_changed(player, entity.health.current_health, entity.health.max_health)
	var pl := player as Player
	if pl and pl.stamina:
		_on_stamina_changed(player, pl.stamina.current_stamina, pl.stamina.max_stamina)

func _on_health_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_update_bar(&"health", current, max_value)

func _on_stamina_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_update_bar(&"stamina", current, max_value)

func _on_mana_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_update_bar(&"mana", current, max_value)

func _on_hunger_changed(entity: Node, current: float, max_value: float) -> void:
	if entity == GameManager.player:
		_update_bar(&"hunger", current, max_value)

func _update_bar(key: StringName, current: float, max_value: float) -> void:
	var bar: TextureProgressBar = _bars.get(key)
	if bar:
		bar.max_value = maxf(max_value, 1.0)
		bar.value = current
	var lbl: Label = _value_labels.get(key)
	if lbl:
		lbl.text = "%d/%d" % [roundi(current), roundi(max_value)]
