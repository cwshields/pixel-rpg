class_name ImbuingUI
extends MenuBase
## The imbuing station interface: destruct items to learn affixes,
## imbue learned affixes onto eligible items, and manage existing affixes.

@onready var _player_grid: InventoryGrid = %PlayerGrid
@onready var _close_btn: Button = %CloseBtn
@onready var _destruct_slot: ItemSlot = %DestructSlot
@onready var _target_slot: ItemSlot = %TargetSlot
@onready var _essence_slot: ItemSlot = %EssenceSlot
@onready var _catalyst_slot: ItemSlot = %CatalystSlot
@onready var _destruct_btn: Button = %DestructBtn
@onready var _destruct_preview: Label = %DestructPreview
@onready var _affix_list: VBoxContainer = %AffixList
@onready var _learned_list: VBoxContainer = %LearnedList
@onready var _feedback_label: Label = %FeedbackLabel


func _ready() -> void:
	super._ready()
	_close_btn.pressed.connect(func() -> void: UIManager.close_screen(screen_name))
	_destruct_btn.pressed.connect(_on_destruct_pressed)
	_destruct_slot.item_placed.connect(func(_i: ItemBase, _q: int) -> void: _refresh_destruct_preview())
	_destruct_slot.item_removed.connect(func(_i: ItemBase, _q: int) -> void: _refresh_destruct_preview())
	_target_slot.item_placed.connect(func(_i: ItemBase, _q: int) -> void: _refresh_affix_panel())
	_target_slot.item_removed.connect(func(_i: ItemBase, _q: int) -> void: _refresh_affix_panel())
	_essence_slot.item_placed.connect(func(_i: ItemBase, _q: int) -> void: _refresh_affix_panel())
	_essence_slot.item_removed.connect(func(_i: ItemBase, _q: int) -> void: _refresh_affix_panel())
	_catalyst_slot.item_placed.connect(func(_i: ItemBase, _q: int) -> void: _refresh_affix_panel())
	_catalyst_slot.item_removed.connect(func(_i: ItemBase, _q: int) -> void: _refresh_affix_panel())

	_destruct_slot.accept_filter = func(item: ItemBase) -> bool:
		return ImbuingLogic._is_imbue_category(item.category) or item.affixes.size() > 0
	_target_slot.accept_filter = func(item: ItemBase) -> bool:
		return ImbuingLogic.can_imbue_item(item)
	_essence_slot.accept_filter = func(item: ItemBase) -> bool:
		return item is CraftingMaterial and (item as CraftingMaterial).material_type == CraftingMaterial.MaterialType.ESSENCE
	_catalyst_slot.accept_filter = func(item: ItemBase) -> bool:
		if not item is CraftingMaterial:
			return false
		var mat := item as CraftingMaterial
		return mat.material_type in [CraftingMaterial.MaterialType.GEM, CraftingMaterial.MaterialType.HERB]


func _on_open() -> void:
	UIManager.close_screen(&"inventory")
	UIManager.close_screen(&"shop")
	UIManager.close_screen(&"stash")
	UIManager.close_screen(&"level_up")
	UIManager.close_screen(&"item_spawner")

	var player: Player = GameManager.player
	if not player:
		return

	_player_grid.setup(player.inventory)
	_player_grid.input_filter = _on_grid_click

	_destruct_slot.linked_grid = _player_grid
	_target_slot.linked_grid = _player_grid
	_essence_slot.linked_grid = _player_grid
	_catalyst_slot.linked_grid = _player_grid

	_clear_all_slots()
	_refresh_destruct_preview()
	_refresh_affix_panel()
	_hide_feedback()


func _on_close() -> void:
	_return_all_to_inventory()
	_player_grid.cancel_held_item()
	_player_grid.input_filter = Callable()
	Events.dialogue_ended.emit()


func _on_grid_click(event: InputEventMouseButton) -> bool:
	if not event.shift_pressed:
		return false
	var local := _player_grid.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, _player_grid.size).has_point(local):
		return false

	var placed: Inventory.PlacedItem = _find_placed(local)
	if not placed:
		return false

	var item: ItemBase = placed.item
	if item is CraftingMaterial:
		var mat := item as CraftingMaterial
		if mat.material_type == CraftingMaterial.MaterialType.ESSENCE and _essence_slot.is_empty():
			return _quick_move_to_slot(placed, _essence_slot)
		if mat.material_type in [CraftingMaterial.MaterialType.GEM,
				CraftingMaterial.MaterialType.HERB] and _catalyst_slot.is_empty():
			return _quick_move_to_slot(placed, _catalyst_slot)
	elif ImbuingLogic.can_imbue_item(item) and _target_slot.is_empty():
		return _quick_move_to_slot(placed, _target_slot)
	elif _destruct_slot.is_empty():
		if ImbuingLogic._is_imbue_category(item.category) or item.affixes.size() > 0:
			return _quick_move_to_slot(placed, _destruct_slot)
	return false


func _quick_move_to_slot(placed: Inventory.PlacedItem, slot: ItemSlot) -> bool:
	var item: ItemBase = placed.item
	var qty: int = placed.quantity
	var inv: Inventory = _player_grid.inventory
	inv.remove_placed(placed)
	slot.try_place(item, qty)
	return true


func _find_placed(local_pos: Vector2) -> Inventory.PlacedItem:
	var inv: Inventory = _player_grid.inventory
	var cell := Vector2i(
		floori(local_pos.x / InventoryGrid.CELL_SIZE),
		floori(local_pos.y / InventoryGrid.CELL_SIZE))
	for p in inv.items:
		if cell in inv.get_world_cells(p.item, p.pos, p.rotation):
			return p
	return null


# -- Destruct ------------------------------------------------------------

func _on_destruct_pressed() -> void:
	if _destruct_slot.is_empty():
		_show_feedback("Place an item to destruct.", Color(0.9, 0.6, 0.3))
		return

	var item: ItemBase = _destruct_slot.item
	var item_name: String = item.get_display_name() if item.has_method("get_display_name") else item.display_name

	var player: Player = GameManager.player
	if not player:
		return

	var result := ImbuingLogic.destruct(item, player.affix_knowledge,
		player.inventory)

	if not result.success:
		_show_feedback(result.error, Color(0.9, 0.3, 0.3))
		return

	_destruct_slot.item = null
	_destruct_slot.quantity = 0
	_destruct_slot.queue_redraw()

	var feedback_parts: Array[String] = []
	for affix_id: StringName in result.learned_affixes:
		var affix: ItemAffix = AffixDB.get_affix(affix_id)
		if affix:
			var prof: int = result.proficiency_gains.get(affix_id, 1)
			feedback_parts.append("%s (Prof. %d)" % [affix.display_name, prof])
	for essence_id: StringName in result.essence_yields:
		var qty: int = result.essence_yields[essence_id]
		var base: ItemBase = ItemFactory.get_base(essence_id)
		if base:
			feedback_parts.append("+%d %s" % [qty, base.display_name])

	_show_feedback("Destructed %s! %s" % [item_name, ", ".join(feedback_parts)],
		Color(0.5, 0.9, 0.5))
	_refresh_destruct_preview()
	_refresh_affix_panel()

	Events.item_destructed.emit(item)


# -- Affix management ----------------------------------------------------

func _refresh_destruct_preview() -> void:
	if _destruct_slot.is_empty():
		_destruct_preview.text = "Place an item to see\nwhat you'll gain."
		_destruct_btn.disabled = true
		return
	_destruct_btn.disabled = false
	var item: ItemBase = _destruct_slot.item
	var yields := ImbuingLogic.calculate_destruct_yields(item)
	var lines: Array[String] = []
	for essence_id: StringName in yields:
		var qty: int = yields[essence_id]
		var base: ItemBase = ItemFactory.get_base(essence_id)
		if base:
			lines.append("%d %s" % [qty, base.display_name])
	if item.affixes.size() > 0:
		lines.append("")
		lines.append("Learns:")
		for inst: AffixInstance in item.affixes:
			lines.append("  %s" % inst.display_name)
	else:
		lines.append("")
		lines.append("No affixes to learn.")
	_destruct_preview.text = "\n".join(lines)


func _refresh_affix_panel() -> void:
	_clear_children(_affix_list)
	_clear_children(_learned_list)

	if _target_slot.is_empty():
		var hint := Label.new()
		hint.text = "Place an item to manage\nits affixes."
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
		_affix_list.add_child(hint)
		return

	var target: ItemBase = _target_slot.item
	var player: Player = GameManager.player
	if not player:
		return
	var knowledge: AffixKnowledge = player.affix_knowledge
	var catalyst: ItemBase = _catalyst_slot.item
	var essence_total := _get_slot_essence_total()

	for i in target.affixes.size():
		var inst: AffixInstance = target.affixes[i]
		var row := _build_affix_row(inst, i, knowledge, catalyst, essence_total)
		_affix_list.add_child(row)

	if target.affixes.is_empty():
		var no_affix := Label.new()
		no_affix.text = "No affixes."
		no_affix.add_theme_font_size_override("font_size", 11)
		no_affix.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
		_affix_list.add_child(no_affix)

	var applicable := knowledge.get_applicable_for(target)
	for affix_id: StringName in applicable:
		if ImbuingLogic.has_affix(target, affix_id):
			continue
		var row := _build_learned_row(affix_id, knowledge, catalyst, essence_total, target)
		_learned_list.add_child(row)

	if _learned_list.get_child_count() == 0:
		var no_learned := Label.new()
		no_learned.text = "No learned affixes\navailable for this item."
		no_learned.add_theme_font_size_override("font_size", 11)
		no_learned.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
		_learned_list.add_child(no_learned)


func _build_affix_row(inst: AffixInstance, index: int,
		knowledge: AffixKnowledge, catalyst: ItemBase,
		essence_total: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var stat_lines := inst.get_stat_lines()
	var name_label := Label.new()
	name_label.text = "%s: %s" % [inst.display_name, ", ".join(stat_lines)]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.4, 0.65, 0.9))
	row.add_child(name_label)

	var bonus := ImbuingLogic.get_catalyst_bonus(catalyst)
	var upgrade_cost := ceili(ImbuingLogic.get_upgrade_cost(inst.affix_id) * bonus["cost_mult"])
	var upgrade_btn := Button.new()
	upgrade_btn.text = "Upgrade (%d)" % upgrade_cost
	upgrade_btn.add_theme_font_size_override("font_size", 10)
	upgrade_btn.custom_minimum_size = Vector2(100, 24)
	upgrade_btn.disabled = essence_total < upgrade_cost
	upgrade_btn.pressed.connect(_on_upgrade_pressed.bind(index))
	row.add_child(upgrade_btn)

	var remove_return := ImbuingLogic.get_remove_return(inst.affix_id)
	var remove_btn := Button.new()
	remove_btn.text = "Remove (+%d)" % remove_return
	remove_btn.add_theme_font_size_override("font_size", 10)
	remove_btn.custom_minimum_size = Vector2(100, 24)
	remove_btn.pressed.connect(_on_remove_pressed.bind(index))
	row.add_child(remove_btn)

	return row


func _build_learned_row(affix_id: StringName, knowledge: AffixKnowledge,
		catalyst: ItemBase, essence_total: int, target: ItemBase) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var affix: ItemAffix = AffixDB.get_affix(affix_id)
	if not affix:
		return row

	var prof: int = knowledge.get_proficiency(affix_id)
	var stars := ""
	for s in AffixKnowledge.MAX_PROFICIENCY:
		stars += "*" if s < prof else "-"

	var name_label := Label.new()
	name_label.text = "%s [%s]" % [affix.display_name, stars]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.9))
	row.add_child(name_label)

	var bonus := ImbuingLogic.get_catalyst_bonus(catalyst)
	var cost := ceili(ImbuingLogic.get_imbue_cost(affix_id) * bonus["cost_mult"])

	var can_imbue := essence_total >= cost and ImbuingLogic.has_room_for_affix(target)
	var imbue_btn := Button.new()
	imbue_btn.text = "Imbue (%d)" % cost
	imbue_btn.add_theme_font_size_override("font_size", 10)
	imbue_btn.custom_minimum_size = Vector2(100, 24)
	imbue_btn.disabled = not can_imbue
	imbue_btn.pressed.connect(_on_imbue_pressed.bind(affix_id))
	row.add_child(imbue_btn)

	return row


func _on_imbue_pressed(affix_id: StringName) -> void:
	if _target_slot.is_empty():
		return
	var player: Player = GameManager.player
	if not player:
		return

	var catalyst: ItemBase = _catalyst_slot.item
	var bonus := ImbuingLogic.get_catalyst_bonus(catalyst)
	var cost := ceili(ImbuingLogic.get_imbue_cost(affix_id) * bonus["cost_mult"])

	if not _deduct_essence(cost):
		_show_feedback("Not enough essence.", Color(0.9, 0.3, 0.3))
		return

	if catalyst:
		_catalyst_slot.quantity -= 1
		if _catalyst_slot.quantity <= 0:
			_catalyst_slot.clear()
		else:
			_catalyst_slot.queue_redraw()

	var result := ImbuingLogic.imbue_affix(_target_slot.item, affix_id,
		player.affix_knowledge, catalyst)

	if not result.success:
		_show_feedback(result.error, Color(0.9, 0.3, 0.3))
		return

	var stat_lines := result.new_affix.get_stat_lines()
	_show_feedback("Imbued %s! %s" % [result.new_affix.display_name,
		", ".join(stat_lines)], Color(0.5, 0.7, 0.9))
	_refresh_affix_panel()
	_target_slot.queue_redraw()

	Events.item_imbued.emit(_target_slot.item, affix_id)


func _on_upgrade_pressed(affix_index: int) -> void:
	if _target_slot.is_empty():
		return
	var player: Player = GameManager.player
	if not player:
		return

	var inst: AffixInstance = _target_slot.item.affixes[affix_index]
	var catalyst: ItemBase = _catalyst_slot.item
	var bonus := ImbuingLogic.get_catalyst_bonus(catalyst)
	var cost := ceili(ImbuingLogic.get_upgrade_cost(inst.affix_id) * bonus["cost_mult"])

	if not _deduct_essence(cost):
		_show_feedback("Not enough essence.", Color(0.9, 0.3, 0.3))
		return

	if catalyst:
		_catalyst_slot.quantity -= 1
		if _catalyst_slot.quantity <= 0:
			_catalyst_slot.clear()
		else:
			_catalyst_slot.queue_redraw()

	var result := ImbuingLogic.upgrade_affix(_target_slot.item, affix_index,
		player.affix_knowledge, catalyst)

	if not result.success:
		_show_feedback(result.error, Color(0.9, 0.3, 0.3))
		return

	_show_feedback("Upgraded %s!" % inst.display_name, Color(0.9, 0.85, 0.4))
	_refresh_affix_panel()
	_target_slot.queue_redraw()


func _on_remove_pressed(affix_index: int) -> void:
	if _target_slot.is_empty():
		return

	var result := ImbuingLogic.remove_affix(_target_slot.item, affix_index)
	if not result.success:
		_show_feedback(result.error, Color(0.9, 0.3, 0.3))
		return

	if result.essence_returned > 0:
		var player: Player = GameManager.player
		if player:
			var dust: ItemBase = ItemFactory.get_base(ImbuingLogic.ESSENCE_DUST_ID)
			if dust:
				player.inventory.add_item(dust.duplicate(), result.essence_returned)

	_show_feedback("Removed %s. +%d essence returned." % [
		result.removed_affix.display_name, result.essence_returned],
		Color(0.9, 0.6, 0.3))
	_refresh_affix_panel()
	_target_slot.queue_redraw()


# -- Essence management --------------------------------------------------

func _get_slot_essence_total() -> int:
	if _essence_slot.is_empty():
		return 0
	return ImbuingLogic.calculate_essence_total(null, _essence_slot.item,
		_essence_slot.quantity)


func _deduct_essence(cost: int) -> bool:
	var available := _get_slot_essence_total()
	if available < cost:
		return false

	var per_unit := ImbuingLogic._essence_value(_essence_slot.item.id)
	if per_unit <= 0:
		return false
	var units_needed := ceili(float(cost) / float(per_unit))
	units_needed = mini(units_needed, _essence_slot.quantity)

	_essence_slot.quantity -= units_needed
	if _essence_slot.quantity <= 0:
		_essence_slot.clear()
	else:
		_essence_slot.queue_redraw()
	return true


# -- Helpers -------------------------------------------------------------

func _clear_all_slots() -> void:
	_destruct_slot.clear()
	_target_slot.clear()
	_essence_slot.clear()
	_catalyst_slot.clear()


func _return_all_to_inventory() -> void:
	var player: Player = GameManager.player
	if not player:
		return
	for slot: ItemSlot in [_destruct_slot, _target_slot, _essence_slot, _catalyst_slot]:
		if not slot.is_empty():
			player.inventory.add_item(slot.item, slot.quantity)
			slot.item = null
			slot.quantity = 0
			slot.queue_redraw()


func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()


func _show_feedback(text: String, color: Color = Color.WHITE) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", color)
	_feedback_label.visible = true
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_feedback_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func() -> void:
		_feedback_label.visible = false
		_feedback_label.modulate.a = 1.0)


func _hide_feedback() -> void:
	_feedback_label.visible = false
