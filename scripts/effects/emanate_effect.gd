# emanate_effect.gd
# Radial outward expansion: rings pulse outward and fade, optional burst particles.
# Use for: buff activation, aura proc, status applied, shockwave, heal pulse.
#
# Usage:
#   var effect = EmanateEffect.new()
#   container.add_child(effect)
#   effect.configure(preset, source_pos)
#   effect.set_source_node(die_visual)  # optional: shader glow on source
#   await effect.play()
extends CombatEffect
class_name EmanateEffect

var _emanate_preset: EmanatePreset = null
var _ring_texture: ImageTexture = null

func configure(preset: EmanatePreset, source: Vector2, target: Vector2 = Vector2.ZERO):
	"""Configure the emanate effect. Target defaults to source for self-centered effects."""
	_emanate_preset = preset
	configure_base(preset, source, target if target != Vector2.ZERO else source)

func _execute_node_track() -> void:
	_ring_texture = _generate_ring_texture()
	var soft_circle = _generate_soft_circle()

	# Spawn rings with stagger
	for i in _emanate_preset.ring_count:
		_spawn_ring(i)
		if i < _emanate_preset.ring_count - 1:
			await get_tree().create_timer(_emanate_preset.ring_stagger).timeout

	# Spawn burst particles simultaneously
	if _emanate_preset.burst_particle_count > 0:
		_spawn_burst(soft_circle)

	# Peak at first ring's midpoint
	get_tree().create_timer(_emanate_preset.ring_duration * 0.4).timeout.connect(
		_emit_peak, CONNECT_ONE_SHOT
	)

	# Wait for full duration
	await get_tree().create_timer(_emanate_preset.total_duration).timeout

func _spawn_ring(ring_index: int):
	"""Spawn a single expanding ring."""
	var ring = TextureRect.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.texture = _ring_texture
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ring.modulate = _emanate_preset.emanate_color

	# Start small at source
	var start_size = Vector2.ONE * _emanate_preset.ring_start_radius * 2
	var end_size = Vector2.ONE * _emanate_preset.ring_end_radius * 2
	ring.custom_minimum_size = start_size
	ring.size = start_size
	ring.pivot_offset = start_size / 2.0
	ring.global_position = _source_pos - start_size / 2.0
	add_child(ring)

	var duration = _emanate_preset.ring_duration
	var tween = create_tween().set_parallel(true)

	# Scale up
	var scale_factor = _emanate_preset.ring_end_radius / maxf(_emanate_preset.ring_start_radius, 1.0)
	tween.tween_property(ring, "scale", Vector2.ONE * scale_factor, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Reposition to keep centered
	tween.tween_property(ring, "global_position",
		_source_pos - start_size * scale_factor / 2.0, duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Fade out
	tween.tween_property(ring, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN).set_delay(duration * 0.3)

	# Cleanup
	tween.chain().tween_callback(ring.queue_free)

func _spawn_burst(soft_circle: ImageTexture):
	"""Spawn radial burst particles."""
	var count = _emanate_preset.burst_particle_count
	for i in count:
		var angle = (TAU / count) * i + randf_range(-0.15, 0.15)
		var direction = Vector2(cos(angle), sin(angle))
		var end_pos = _source_pos + direction * _emanate_preset.burst_radius

		var particle = _create_particle_sprite(
			_emanate_preset.particle_size, soft_circle,
			_emanate_preset.emanate_color
		)
		particle.global_position = _source_pos - particle.pivot_offset
		particle.rotation = randf_range(0, TAU)
		particle.scale = Vector2.ONE * 0.3
		add_child(particle)

		var duration = _emanate_preset.burst_duration
		var tween = create_tween().set_parallel(true)

		# Move outward
		tween.tween_property(particle, "global_position",
			end_pos - particle.pivot_offset, duration
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		# Scale up then shrink
		tween.tween_property(particle, "scale", Vector2.ONE, duration * 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector2.ONE * 0.1, duration * 0.7).set_ease(Tween.EASE_IN).set_delay(duration * 0.3)

		# Fade
		tween.tween_property(particle, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)

		# Spin
		tween.tween_property(particle, "rotation", particle.rotation + randf_range(-PI, PI), duration)

		tween.chain().tween_callback(particle.queue_free)

func _generate_ring_texture() -> ImageTexture:
	"""Generate a ring texture (hollow circle)."""
	var tex_size: int = 64
	var center: float = tex_size / 2.0
	var outer_r: float = center - 1.0
	var thickness: float = clampf(_emanate_preset.ring_thickness / _emanate_preset.ring_end_radius * center, 1.0, center)
	var inner_r: float = outer_r - thickness

	var img = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	for x in tex_size:
		for y in tex_size:
			var dist = Vector2(x, y).distance_to(Vector2(center, center))
			var alpha = 0.0
			if dist >= inner_r and dist <= outer_r:
				# Smooth edges
				var edge_inner = smoothstep(inner_r - 0.5, inner_r + 0.5, dist)
				var edge_outer = smoothstep(outer_r + 0.5, outer_r - 0.5, dist)
				alpha = edge_inner * edge_outer
			img.set_pixel(x, y, Color(1, 1, 1, alpha))

	return ImageTexture.create_from_image(img)
