class_name DialogueUI
extends MenuBase
## Bottom-of-screen NPC dialogue panel. Shows the NPC's greeting and a
## vertical list of options (Gossip, Shop, Leave). Opened by the
## Events.dialogue_started signal; closed by Escape or the Leave button.

var _active_npc: NPCBase = null
var _transitioning_to_shop := false

@onready var _npc_name_label: Label = %NPCNameLabel
@onready var _dialogue_label: Label = %DialogueLabel
@onready var _gossip_btn: Button = %GossipBtn
@onready var _shop_btn: Button = %ShopBtn
@onready var _leave_btn: Button = %LeaveBtn

func _ready() -> void:
	super._ready()
	_gossip_btn.pressed.connect(_on_gossip)
	_shop_btn.pressed.connect(_on_shop)
	_leave_btn.pressed.connect(_on_leave)
	Events.dialogue_started.connect(_on_dialogue_started)

func _on_dialogue_started(npc: Node) -> void:
	if npc is not NPCBase:
		return
	_active_npc = npc as NPCBase
	_npc_name_label.text = _active_npc.npc_name
	if _active_npc.dialogue_lines.is_empty():
		_dialogue_label.text = "..."
	else:
		_dialogue_label.text = _active_npc.get_current_line()
	_shop_btn.visible = _active_npc.has_shop and _active_npc.shop_inventory != null
	_gossip_btn.visible = not _active_npc.gossip_lines.is_empty()
	UIManager.open_screen(screen_name)

func _on_gossip() -> void:
	if not _active_npc:
		return
	var line := _active_npc.get_random_gossip()
	if not line.is_empty():
		_dialogue_label.text = line

func _on_shop() -> void:
	if not _active_npc:
		return
	var shop_ui := UIManager.get_screen(&"shop") as ShopUI
	if shop_ui:
		shop_ui.setup_shop(_active_npc)
	_transitioning_to_shop = true
	UIManager.close_screen(screen_name)
	_transitioning_to_shop = false
	UIManager.open_screen(&"shop")

func _on_leave() -> void:
	UIManager.close_screen(screen_name)

func _on_close() -> void:
	_active_npc = null
	if not _transitioning_to_shop:
		Events.dialogue_ended.emit()
