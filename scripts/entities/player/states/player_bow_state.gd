class_name PlayerBowState
extends State
## Active while the player holds a bow and presses attack. Holds the
## first frame of the pierce animation (facing toward cursor), drives
## the BowAimComponent's draw progression, and fires an arrow on release.

const ARROW_SCENE: PackedScene = preload("res://scenes/combat/arrow_projectile.tscn")

var _held: bool = false

func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	var player := entity as Player
	_held = true
	player.face_toward_mouse()
	_apply_aim_visuals(player)
	_hold_first_frame(player)
	if player.bow_aim:
		player.bow_aim.visible = true
		player.bow_aim.start_draw()

func process_physics(delta: float) -> void:
	var player := entity as Player
	player.face_toward_mouse()
	_apply_aim_visuals(player)
	_hold_first_frame(player)
	var moving := player.get_move_input() != Vector2.ZERO
	player.move(player.get_move_input() * 0.4, delta, false)
	if _held and not Input.is_action_pressed("attack"):
		_fire(player)
		_held = false
		transition_requested.emit(&"Move" if moving else &"Idle", {})

func exit() -> void:
	var player := entity as Player
	if player.bow_aim:
		player.bow_aim.stop_draw()
		player.bow_aim.visible = false
	if player.swing_sound_player and player.swing_sound_player.playing:
		player.swing_sound_player.stop()

func _apply_aim_visuals(player: Player) -> void:
	var aim := player.get_global_mouse_position() - player.global_position
	if aim == Vector2.ZERO:
		return
	player.facing_direction = aim.normalized()
	player.facing_changed.emit(player.facing_direction)

func _hold_first_frame(player: Player) -> void:
	if not player.animated_sprite or not player.animated_sprite.sprite_frames:
		return
	var suffix := _facing_suffix(player)
	var anim := StringName("pierce_" + suffix)
	if not player.animated_sprite.sprite_frames.has_animation(anim):
		return
	if player.animated_sprite.animation != anim:
		player.animated_sprite.play(anim)
	player.animated_sprite.stop()
	player.animated_sprite.frame = 0
	player.animated_sprite.flip_h = player.facing_direction.x < 0.0

func _facing_suffix(player: Player) -> String:
	var dir := player.facing_direction
	if absf(dir.y) >= absf(dir.x):
		return "up" if dir.y < 0.0 else "down"
	return "side"

func _fire(player: Player) -> void:
	var weapon := player.equipment.get_equipped(Equipment.Slot.PRIMARY_HAND) as Weapon
	if not weapon or weapon.weapon_type != Weapon.WeaponType.BOW:
		return
	var ammo := player.find_ammo(Ammo.AmmoType.ARROW)
	if not ammo:
		Events.notification.emit("No arrows in inventory.")
		return
	player.inventory.remove_item(ammo.id, 1)
	var aim_dir: Vector2
	if player.bow_aim:
		aim_dir = player.bow_aim.get_aim_direction()
	else:
		aim_dir = (player.get_global_mouse_position() - player.global_position).normalized()
	var arrow := ARROW_SCENE.instantiate() as ArrowProjectile
	arrow.direction = aim_dir
	arrow.set_arrow_texture(ammo.icon)
	arrow.speed = ammo.projectile_speed
	if player.stats:
		var bd: Dictionary = player.stats.compute_outgoing_damage()
		bd[&"physical"] = bd.get(&"physical", 0.0) + ammo.damage_bonus
		arrow.damage_breakdown = bd
	else:
		arrow.damage = weapon.damage + ammo.damage_bonus
	arrow.knockback_force = 100.0
	arrow.source = player
	arrow.global_position = player.global_position + aim_dir * 12.0
	player.get_parent().add_child(arrow)
	player.play_swing_sound()
