extends Node
## Persistent save/load system (autoload name: "SaveManager").
##
## Stores save files as JSON under the OS "Saved Games" folder:
##   Windows:  C:\Users\<user>\Saved Games\PixelGame\
##   Other:    user://saves/
##
## Supports multiple named save slots. Auto-save writes to the active
## slot every AUTO_SAVE_INTERVAL seconds while playing, and on window close.

const SAVE_DIR_NAME := "PixelGame"
const AUTO_SAVE_INTERVAL := 60.0
const AUTO_SAVE_SLOT := "autosave"

var _auto_save_timer: float = 0.0
var _save_dir: String = ""
var active_slot: String = AUTO_SAVE_SLOT

var _pending_save: Dictionary = {}

func _ready() -> void:
	_save_dir = _resolve_save_dir()
	_ensure_dir(_save_dir)
	_cleanup_tmp_files()
	apply_settings()
	set_process(true)
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_game()

# -- Directory helpers --

func _resolve_save_dir() -> String:
	if OS.get_name() == "Windows":
		var user_profile: String = OS.get_environment("USERPROFILE")
		if not user_profile.is_empty():
			return user_profile.replace("\\", "/") + "/Saved Games/" + SAVE_DIR_NAME
	return OS.get_user_data_dir() + "/saves"

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

func _cleanup_tmp_files() -> void:
	var dir := DirAccess.open(_save_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tmp"):
			DirAccess.remove_absolute(_save_dir + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func get_save_dir() -> String:
	return _save_dir

func _slot_path(slot_name: String) -> String:
	return _save_dir + "/" + slot_name + ".json"

func _settings_path() -> String:
	return _save_dir + "/settings.json"

# -- Settings persistence --

func save_settings(settings: Dictionary) -> void:
	_ensure_dir(_save_dir)
	var path := _settings_path()
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_warning("SaveManager: could not write settings")
		return
	file.store_string(JSON.stringify(settings, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp_path, path)

func load_settings() -> Dictionary:
	var path := _settings_path()
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

func apply_settings() -> void:
	var s := load_settings()
	if s.is_empty():
		return
	if s.has("master_volume"):
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Master"),
			linear_to_db(float(s["master_volume"])))
	if s.has("ambience_volume"):
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Ambience"),
			linear_to_db(float(s["ambience_volume"])))
	if s.has("voice_volume"):
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Voice"),
			linear_to_db(float(s["voice_volume"])))
	if s.has("fullscreen"):
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(s["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)

# -- Public API --

func has_save(slot_name: String = "") -> bool:
	if slot_name.is_empty():
		return not list_saves().is_empty()
	return FileAccess.file_exists(_slot_path(slot_name))

func save_game(slot_name: String = "") -> bool:
	if slot_name.is_empty():
		slot_name = active_slot
	var player: Player = GameManager.player as Player
	if not player:
		return false

	var data: Dictionary = {
		"version": 1,
		"slot_name": slot_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"player": _serialize_player(player),
		"world": _serialize_world(),
	}

	_ensure_dir(_save_dir)
	var path := _slot_path(slot_name)
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_warning("SaveManager: could not write to %s" % tmp_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp_path, path)
	active_slot = slot_name
	return true

func load_game(slot_name: String = "") -> bool:
	if slot_name.is_empty():
		slot_name = active_slot
	var path := _slot_path(slot_name)
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("SaveManager: corrupt save file: %s" % path)
		return false

	var data: Dictionary = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false

	_pending_save = data
	active_slot = slot_name
	return true

func apply_save() -> void:
	if _pending_save.is_empty():
		return
	var player: Player = GameManager.player as Player
	if not player:
		return

	var data: Dictionary = _pending_save
	_pending_save = {}

	_deserialize_player(player, data.get("player", {}))
	_deserialize_world(data.get("world", {}))

func delete_save(slot_name: String = "") -> void:
	if slot_name.is_empty():
		slot_name = active_slot
	var path := _slot_path(slot_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func delete_all_saves() -> void:
	for info: Dictionary in list_saves():
		delete_save(info["slot_name"])

## Returns an array of dictionaries with save metadata, sorted newest first.
## Each entry: { "slot_name": String, "timestamp": String, "path": String,
##               "level": int, "gold": int }
func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir := DirAccess.open(_save_dir)
	if not dir:
		return saves
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json") \
				and not file_name.ends_with(".tmp") \
				and file_name != "settings.json":
			var slot_name: String = file_name.get_basename()
			var path := _save_dir + "/" + file_name
			var meta := _read_save_meta(path, slot_name)
			if not meta.is_empty():
				saves.append(meta)
		file_name = dir.get_next()
	dir.list_dir_end()
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["timestamp"] > b["timestamp"])
	return saves

func _read_save_meta(path: String, slot_name: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {}

	var data: Dictionary = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}

	var player_data: Dictionary = data.get("player", {})
	var stats_data: Dictionary = player_data.get("stats", {})
	return {
		"slot_name": slot_name,
		"timestamp": data.get("timestamp", ""),
		"path": path,
		"level": int(stats_data.get("level", 1)),
		"gold": int(player_data.get("gold", 0)),
	}

# -- Serialization helpers --

func _serialize_player(player: Player) -> Dictionary:
	var data: Dictionary = {
		"position": {"x": player.global_position.x, "y": player.global_position.y},
		"gold": player.gold,
	}

	if player.health:
		data["health"] = {
			"current": player.health.current_health,
			"max": player.health.max_health,
		}

	if player.stats:
		data["stats"] = {
			"level": player.stats.level,
			"current_xp": player.stats.current_xp,
			"stat_points": player.stats.stat_points,
			"allocated": _dict_to_string_keys(player.stats._allocated),
		}

	data["inventory"] = _serialize_inventory(player.inventory)
	data["equipment"] = _serialize_equipment(player.equipment)
	data["hotbar"] = _serialize_hotbar(player)

	return data


func _deserialize_player(player: Player, data: Dictionary) -> void:
	if data.is_empty():
		return

	var pos: Dictionary = data.get("position", {})
	if pos.has("x") and pos.has("y"):
		player.global_position = Vector2(pos["x"], pos["y"])

	player.gold = int(data.get("gold", 100))

	if player.stats and data.has("stats"):
		var s: Dictionary = data["stats"]
		player.stats.level = int(s.get("level", 1))
		player.stats.current_xp = int(s.get("current_xp", 0))
		player.stats.stat_points = int(s.get("stat_points", 0))
		player.stats._allocated = _string_keys_to_dict(s.get("allocated", {}))
		Events.stats_changed.emit(player)
		Events.xp_changed.emit(player, player.stats.current_xp, player.stats.xp_for_next_level())

	if player.health and data.has("health"):
		var h: Dictionary = data["health"]
		player.health.current_health = float(h.get("current", player.health.max_health))
		Events.health_changed.emit(player, player.health.current_health, player.health.max_health)

	_deserialize_inventory(player.inventory, data.get("inventory", {}))
	_deserialize_equipment(player, data.get("equipment", {}))
	_deserialize_hotbar(player, data.get("hotbar", []))

	Events.gold_changed.emit(player.gold)


func _serialize_inventory(inv: Inventory) -> Dictionary:
	var placed_list: Array[Dictionary] = []
	for placed: Inventory.PlacedItem in inv.items:
		placed_list.append({
			"item": placed.item.to_save_dict(),
			"quantity": placed.quantity,
			"pos": {"x": placed.pos.x, "y": placed.pos.y},
			"rotation": placed.rotation,
		})
	return {
		"width": inv.width,
		"height": inv.height,
		"unlocked_rows": inv.unlocked_rows,
		"items": placed_list,
	}


func _deserialize_inventory(inv: Inventory, data: Dictionary) -> void:
	for i in range(inv.items.size() - 1, -1, -1):
		inv.remove_placed(inv.items[i])

	inv.unlocked_rows = int(data.get("unlocked_rows", inv.height))

	var items_data: Array = data.get("items", [])
	for entry: Dictionary in items_data:
		var item := ItemBase.from_save_dict(entry.get("item", {}))
		if not item:
			continue
		var pos_data: Dictionary = entry.get("pos", {})
		var pos := Vector2i(int(pos_data.get("x", 0)), int(pos_data.get("y", 0)))
		var rotation: int = int(entry.get("rotation", 0))
		var quantity: int = int(entry.get("quantity", 1))
		if inv.can_place_at(item, pos, rotation):
			inv.place_item(item, pos, rotation, quantity)
		else:
			inv.add_item(item, quantity)


func _serialize_equipment(equip: Equipment) -> Dictionary:
	var slots_data: Dictionary = {}
	for slot_key: Equipment.Slot in equip.slots:
		var item: ItemBase = equip.slots[slot_key]
		if item:
			slots_data[str(int(slot_key))] = item.to_save_dict()

	var weapon_sets: Array[Dictionary] = []
	for ws: Dictionary in equip._weapon_sets:
		var ws_data: Dictionary = {}
		for slot_key: Equipment.Slot in ws:
			var item: ItemBase = ws[slot_key]
			if item:
				ws_data[str(int(slot_key))] = item.to_save_dict()
		weapon_sets.append(ws_data)

	return {
		"slots": slots_data,
		"active_weapon_set": equip.active_weapon_set,
		"weapon_sets": weapon_sets,
	}


func _deserialize_equipment(player: Player, data: Dictionary) -> void:
	var equip := player.equipment
	for slot: Equipment.Slot in equip.slots.keys():
		equip.unequip(slot)

	equip.active_weapon_set = int(data.get("active_weapon_set", 0))
	equip._weapon_sets = [{}, {}]

	var ws_list: Array = data.get("weapon_sets", [])
	for i in mini(ws_list.size(), 2):
		var ws_data: Dictionary = ws_list[i]
		for slot_str: String in ws_data:
			var item := ItemBase.from_save_dict(ws_data[slot_str])
			if item:
				equip._weapon_sets[i][int(slot_str) as Equipment.Slot] = item

	var slots_data: Dictionary = data.get("slots", {})
	for slot_str: String in slots_data:
		var item := ItemBase.from_save_dict(slots_data[slot_str])
		if item:
			equip.equip(int(slot_str) as Equipment.Slot, item)


func _serialize_hotbar(player: Player) -> Array:
	var result: Array = []
	for i in player.HOTBAR_SIZE:
		var item: ItemBase = player.hotbar_slots[i]
		if item:
			result.append({"index": i, "item_id": String(item.id)})
	return result


func _deserialize_hotbar(player: Player, data: Array) -> void:
	player.hotbar_slots.fill(null)
	for entry: Dictionary in data:
		var idx: int = int(entry.get("index", -1))
		var item_id: StringName = StringName(entry.get("item_id", ""))
		if idx < 0 or idx >= player.HOTBAR_SIZE or item_id.is_empty():
			continue
		for placed: Inventory.PlacedItem in player.inventory.items:
			if placed.item.id == item_id:
				player.assign_hotbar_slot(idx, placed.item)
				break


func _serialize_world() -> Dictionary:
	return {
		"day_night_cycle_time": DayNightCycle.cycle_time,
	}


func _deserialize_world(data: Dictionary) -> void:
	if data.has("day_night_cycle_time"):
		DayNightCycle.cycle_time = float(data["day_night_cycle_time"])


func _dict_to_string_keys(d: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in d:
		result[String(key)] = d[key]
	return result


func _string_keys_to_dict(d: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in d:
		result[StringName(key)] = int(d[key])
	return result
