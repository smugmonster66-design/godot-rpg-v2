# res://scripts/effects/projectile_effect.gd
# A projectile that travels from source to target position
extends CombatEffectBase
class_name ProjectileEffect

signal reached_target()

@export_group("Movement")
@export var rotate_to_target: bool = true
@export var trail_particles: bool = true

@export_group("Visual")
@export var spin_speed: float = 0.0

@export_group("Trail")
@export var ghost_trail_enabled: bool = true
@export var ghost_count: int = 8
@export var ghost_lifetime: float = 0.25
@export var ghost_start_alpha: float = 0.7
@export var ghost_color: Color = Color(1.0, 0.6, 0.2, 1.0)
@export var ghost_shrink: bool = true
@export var ghost_source_node: NodePath = NodePath("") 


# Discovered by type in _ready() — any node names are valid in child scenes.
# sprite: first Sprite2D or AnimatedSprite2D found (used for ghost trail)
# all_particles: every GPUParticles2D child (all toggled together)
# audio: first AudioStreamPlayer2D found
var sprite: Node2D = null
var all_particles: Array[GPUParticles2D] = []
var audio: AudioStreamPlayer2D = null

var target_position: Vector2
var travel_curve: Curve
var travel_duration: float = 0.4
var _start_position: Vector2
var _ghost_timer: float = 0.0
var _ghost_interval: float = 0.0


func _ready():
	# Ghost source: explicit NodePath takes priority over type-based discovery
	if ghost_source_node != NodePath(""):
		var explicit := get_node_or_null(ghost_source_node)
		if explicit is Sprite2D or explicit is AnimatedSprite2D:
			sprite = explicit
	
	# Fall back to first Sprite2D or AnimatedSprite2D found
	if sprite == null:
		for child in get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				sprite = child
				break
	
	for child in get_children():
		if child is GPUParticles2D:
			all_particles.append(child)
	
	if audio == null:
		for child in get_children():
			if child is AudioStreamPlayer2D:
				audio = child
				break


func setup(from: Vector2, to: Vector2, p_duration: float = 0.4, p_curve: Curve = null):
	_start_position = from
	global_position = from
	target_position = to
	travel_duration = p_duration
	travel_curve = p_curve
	print("🚀 Projectile setup: from=%s to=%s duration=%s" % [from, to, p_duration])
	print("🚀 Projectile: global_pos=%s scale=%s rotation=%s" % [global_position, scale, rotation])
	print("🚀 Projectile: parent=%s (type: %s)" % [get_parent().name if get_parent() else "null", get_parent().get_class() if get_parent() else "null"])
	if sprite:
		var tex_size = Vector2.ZERO
		if sprite is Sprite2D and sprite.texture:
			tex_size = sprite.texture.get_size()
		print("🚀 Sprite: pos=%s size=%s" % [sprite.position, tex_size])

	if rotate_to_target:
		rotation = from.angle_to_point(to)


func play():
	print("🚀 play() called — target=%s stack=%s" % [target_position, get_stack()])
	effect_started.emit()

	# Start all particle children
	if trail_particles:
		for p in all_particles:
			p.emitting = true

	# Play sound if exists
	if audio and audio.stream:
		audio.play()

	# Ghost trail — requires a visible sprite to sample texture from
	var has_sprite = _get_ghost_texture() != null
	if ghost_trail_enabled and has_sprite:
		_ghost_interval = travel_duration / float(ghost_count)
		_ghost_timer = 0.0
		set_process(true)

	var tween = create_tween()

	if travel_curve:
		tween.tween_method(_follow_curve, 0.0, 1.0, travel_duration)
	else:
		tween.tween_property(self, "global_position", target_position, travel_duration)
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Optional spin during flight — applied to the sprite child, not the root
	if spin_speed != 0.0 and sprite:
		var spin_tween = create_tween()
		spin_tween.tween_property(sprite, "rotation_degrees", spin_speed * travel_duration, travel_duration)

	await tween.finished
	set_process(false)
	reached_target.emit()

	# Stop all particles and wait for the longest lifetime to fade
	if trail_particles and all_particles.size() > 0:
		var longest_lifetime := 0.0
		for p in all_particles:
			p.emitting = false
			if p.lifetime > longest_lifetime:
				longest_lifetime = p.lifetime
		await get_tree().create_timer(longest_lifetime).timeout

	_on_finished()


func _process(delta: float):
	if not ghost_trail_enabled:
		return
	_ghost_timer += delta
	if _ghost_timer >= _ghost_interval:
		_ghost_timer -= _ghost_interval
		_spawn_ghost()


func _get_ghost_texture() -> Texture2D:
	if sprite == null:
		return null
	if sprite is Sprite2D and sprite.texture:
		return sprite.texture
	if sprite is AnimatedSprite2D and sprite.sprite_frames:
		return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return null


func _spawn_ghost():
	var tex := _get_ghost_texture()
	if not tex:
		return

	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.global_position = global_position
	ghost.rotation = sprite.global_rotation
	ghost.scale = sprite.global_scale
	ghost.modulate = ghost_color
	ghost.modulate.a = ghost_start_alpha
	ghost.z_index = z_index - 1

	# Additive blending for glowing trail
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ghost.material = mat

	get_parent().add_child(ghost)

	var tw := ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 0.0, ghost_lifetime).set_ease(Tween.EASE_IN)
	if ghost_shrink:
		tw.tween_property(ghost, "scale", ghost.scale * 0.3, ghost_lifetime).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ghost.queue_free)


func _follow_curve(t: float):
	var linear_pos = _start_position.lerp(target_position, t)

	var height_offset = travel_curve.sample(t) * 100
	global_position = linear_pos + Vector2(0, -height_offset)

	if rotate_to_target and t > 0:
		var prev_pos = _start_position.lerp(target_position, max(0, t - 0.05))
		var prev_height = travel_curve.sample(max(0, t - 0.05)) * 100
		var prev_full = prev_pos + Vector2(0, -prev_height)
		rotation = prev_full.angle_to_point(global_position)
