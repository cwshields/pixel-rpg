@tool
class_name BreakableProp
extends OccluderProp
## Intermediate base for world props that can be hit, broken, and looted —
## today that's `TreeProp` and `RockProp`. Shared logic lives here:
## art/texture application, collision-polygon shape helpers, depth-sort +
## occlusion-fade proximity, combat feedback (shake, hit particles, break
## fragments), loot drops, and tilemap-detach on death.
##
## Subclasses add their own body-collision setup (trunk vs. boulder), damage
## filtering, and death animation via the virtual hooks below.

static var _atlas_cache: Dictionary = {}

@export_group("Occlusion Fade")
## Explicit outline for FadeArea. When non-empty, wins over the auto-sized
## rectangle. For converted props — hand-placed props keep whatever outline
## you draw directly on FadeArea/CollisionPolygon2D.
@export var fade_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		fade_polygon = value
		_apply_fade_shape()

@export_group("Art")
## Sprite sheet to draw from. Leave null to keep whatever the base scene
## ships with (hand-placed props set nothing here).
@export var art_texture: Texture2D = null:
	set(value):
		art_texture = value
		_apply_art()
## Region (px) of `art_texture` to show. Zero size = whole texture.
@export var art_region: Rect2i = Rect2i():
	set(value):
		art_region = value
		_apply_art()
## Sprite2D local position. The node origin sits at the prop's base.
@export var art_offset: Vector2 = Vector2.ZERO:
	set(value):
		art_offset = value
		_apply_art()

@export_group("Hover Area (Cursor)")
## Explicit outline for the cursor-only HoverArea. Same rules as
## fade_polygon — for converted props, not hand-placed ones.
@export var hover_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		hover_polygon = value
		_apply_hover_shape()

@export_group("Combat")
@export var loot_table: Array[LootEntry] = []
## Explicit outline for the HurtboxComponent's hit region.
@export var hurt_polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		hurt_polygon = value
		_apply_hurt_shape()

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var health: HealthComponent = get_node_or_null("HealthComponent")
@onready var fade_area: Area2D = get_node_or_null("FadeArea")

var _shake_tween: Tween
var _sprite_rest_pos: Vector2
var _hit_particles: CPUParticles2D
## Subclasses set these in _init() for their particle colours.
var _hit_particle_color := Color.WHITE
var _break_fragment_color := Color.WHITE

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	z_index = PLAYER_Z_INDEX - 1
	_apply_art()
	_apply_body_collision()
	if not Engine.is_editor_hint() and health:
		health.died.connect(_on_died)
		health.damaged.connect(_on_damaged)
	if not Engine.is_editor_hint():
		_setup_hit_particles()
	if not Engine.is_editor_hint() and fade_area:
		fade_area.body_entered.connect(_on_fade_area_body_entered)
		fade_area.body_exited.connect(_on_fade_area_body_exited)

# ---------------------------------------------------------------------------
# Proximity (concrete implementation for breakable props)
# ---------------------------------------------------------------------------

func update_proximity(player_pos: Vector2, delta: float) -> void:
	_active = true
	var player_feet: Vector2 = player_pos + Vector2(0, player_feet_offset)
	var in_front: bool = player_feet.y <= global_position.y or _player_in_fade_area
	z_index = (PLAYER_Z_INDEX + 1) if in_front else (PLAYER_Z_INDEX - 1)
	_target_alpha = faded_alpha if _player_in_fade_area else 1.0
	if sprite:
		sprite.modulate.a = move_toward(sprite.modulate.a, _target_alpha, fade_speed * delta)

func reset_proximity() -> void:
	z_index = PLAYER_Z_INDEX - 1
	_target_alpha = 1.0
	if sprite:
		sprite.modulate.a = 1.0
	_active = false

func is_proximity_active() -> bool:
	return _active

# ---------------------------------------------------------------------------
# Art application
# ---------------------------------------------------------------------------

## Rebuilds the Sprite2D from the Art exports. No-op when `art_texture`
## is unset, so a plain base-scene instance keeps its shipped sprite.
func _apply_art() -> void:
	if art_texture == null:
		return
	var s: Sprite2D = get_node_or_null("Sprite2D")
	if s == null:
		return

	if art_region.size != Vector2i.ZERO:
		var key := "%s:%s" % [art_texture.get_rid(), art_region]
		var atlas: AtlasTexture = _atlas_cache.get(key)
		if atlas == null:
			atlas = AtlasTexture.new()
			atlas.atlas = art_texture
			atlas.region = Rect2(art_region)
			_atlas_cache[key] = atlas
		if s.texture != atlas:
			s.texture = atlas
	elif s.texture != art_texture:
		s.texture = art_texture

	if s.position != art_offset:
		s.position = art_offset
	_post_apply_art(s)
	_apply_hover_shape()
	_apply_hurt_shape()
	_apply_fade_shape()

## Override for post-art-apply work (e.g. TreeProp strips sway material).
func _post_apply_art(_s: Sprite2D) -> void:
	pass

# ---------------------------------------------------------------------------
# Shape helpers
# ---------------------------------------------------------------------------

## Applies `explicit_polygon` to the CollisionPolygon2D at `path`, or falls
## back to an auto-sized rectangle matching the sprite's bounding box.
func _apply_polygon_or_auto_rect(path: String, explicit_polygon: PackedVector2Array) -> void:
	var poly_node: CollisionPolygon2D = get_node_or_null(path)
	if poly_node == null:
		return

	if not explicit_polygon.is_empty():
		poly_node.polygon = explicit_polygon
		return

	if sprite == null or sprite.texture == null:
		return
	var half: Vector2 = sprite.texture.get_size() * 0.5
	var center: Vector2 = sprite.position - poly_node.position \
			- (poly_node.get_parent() as Node2D).position
	poly_node.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])

func _apply_hover_shape() -> void:
	_apply_polygon_or_auto_rect("HoverArea/CollisionPolygon2D", hover_polygon)

func _apply_fade_shape() -> void:
	_apply_polygon_or_auto_rect("FadeArea/CollisionPolygon2D", fade_polygon)

func _apply_hurt_shape() -> void:
	_apply_polygon_or_auto_rect("HurtboxComponent/CollisionPolygon2D", hurt_polygon)

# ---------------------------------------------------------------------------
# Body collision — subclasses override (trunk vs. boulder)
# ---------------------------------------------------------------------------

func _apply_body_collision() -> void:
	pass

# ---------------------------------------------------------------------------
# Damage filtering — subclasses override (e.g. RockProp scales non-mining)
# ---------------------------------------------------------------------------

func filter_incoming_damage(amount: float, _source: Node, _hitbox: HitboxComponent) -> float:
	return amount

# ---------------------------------------------------------------------------
# Combat feedback
# ---------------------------------------------------------------------------

func _on_damaged(amount: float, source: Node) -> void:
	_shake(amount)
	_emit_hit_particles(source)

func _shake(damage: float) -> void:
	if not sprite:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		sprite.position = _sprite_rest_pos
	_sprite_rest_pos = sprite.position
	var intensity := clampf(damage / 4.0, 0.3, 1.5)
	var offset := intensity * 1.5
	var count := 3 if intensity < 0.6 else 5
	_shake_tween = create_tween()
	for i in count:
		var dir := 1.0 if i % 2 == 0 else -1.0
		_shake_tween.tween_property(sprite, "position:x",
				_sprite_rest_pos.x + offset * dir, 0.03)
	_shake_tween.tween_property(sprite, "position", _sprite_rest_pos, 0.03)

func _setup_hit_particles() -> void:
	_hit_particles = CPUParticles2D.new()
	_hit_particles.emitting = false
	_hit_particles.one_shot = true
	_hit_particles.amount = 8
	_hit_particles.explosiveness = 0.9
	_hit_particles.lifetime = 0.45
	_hit_particles.direction = Vector2.UP
	_hit_particles.spread = 55.0
	_hit_particles.initial_velocity_min = 28.0
	_hit_particles.initial_velocity_max = 58.0
	_hit_particles.gravity = Vector2(0, 180.0)
	_hit_particles.scale_amount_min = 0.5
	_hit_particles.scale_amount_max = 1.5
	_hit_particles.color = _hit_particle_color
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	_hit_particles.color_ramp = gradient
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_hit_particles.texture = ImageTexture.create_from_image(img)
	_hit_particles.position = sprite.position if sprite else Vector2.ZERO
	add_child(_hit_particles)

func _emit_hit_particles(source: Node) -> void:
	if not _hit_particles or not source is Node2D:
		return
	var to_source := (source as Node2D).global_position - global_position
	if to_source != Vector2.ZERO:
		_hit_particles.position = (sprite.position if sprite else Vector2.ZERO) \
				+ to_source.normalized() * 6.0
	_hit_particles.restart()
	_hit_particles.emitting = true

# ---------------------------------------------------------------------------
# Death
# ---------------------------------------------------------------------------

func _on_died() -> void:
	_drop_loot()
	_detach_from_tilemap()
	_play_death_effect()

func _detach_from_tilemap() -> void:
	var layer := get_parent()
	if not layer is TileMapLayer:
		return
	var cell: Vector2i = layer.local_to_map(position)
	var gpos := global_position
	Foliage.unregister_prop(self)
	layer.remove_child(self)
	layer.get_parent().add_child(self)
	global_position = gpos
	layer.erase_cell(cell)

func _drop_loot() -> void:
	ItemPickup.drop_loot(loot_table, global_position)

func _play_death_effect() -> void:
	Foliage.unregister_prop(self)
	var hurtbox := get_node_or_null("HurtboxComponent") as Area2D
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	var hover := get_node_or_null("HoverArea") as Area2D
	if hover:
		hover.set_deferred("monitoring", false)
		hover.set_deferred("monitorable", false)
	if fade_area:
		fade_area.set_deferred("monitoring", false)
		fade_area.set_deferred("monitorable", false)
	_disable_static_body()
	_spawn_break_fragments()
	_animate_death()

func _disable_static_body() -> void:
	var shape := get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)
	var poly := get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if poly:
		poly.set_deferred("disabled", true)

## Override for the subclass-specific death animation.
func _animate_death() -> void:
	queue_free()

func _spawn_break_fragments() -> void:
	if not get_parent():
		return
	var frags := CPUParticles2D.new()
	frags.emitting = true
	frags.one_shot = true
	frags.amount = 14
	frags.explosiveness = 0.9
	frags.lifetime = 0.5
	frags.direction = Vector2.UP
	frags.spread = 180.0
	frags.initial_velocity_min = 35.0
	frags.initial_velocity_max = 75.0
	frags.gravity = Vector2(0, 220.0)
	frags.scale_amount_min = 1.0
	frags.scale_amount_max = 2.5
	frags.color = _break_fragment_color
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	frags.color_ramp = gradient
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	frags.texture = ImageTexture.create_from_image(img)
	frags.position = position + (sprite.position if sprite else Vector2.ZERO)
	frags.z_index = z_index
	get_parent().add_child(frags)
	get_tree().create_timer(frags.lifetime + 0.1).timeout.connect(frags.queue_free)
