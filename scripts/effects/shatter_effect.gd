# shatter_effect.gd
# Break-apart destruction: optional pre-shake on target, then fragments
# burst outward with gravity arcs and fade.
# Use for: die consumed, die destroyed, item break, death animation.
extends CombatEffect
class_name ShatterEffect

var _shatter_preset: ShatterPreset = null
var _source_texture: Texture2D = null
var _source_tint: Color = Color.WHITE

func configure(preset: ShatterPreset, source: Vector2, _target: Vector2 = Vector2.ZERO):
	_shatter_preset = preset
	configure_base(preset, source, source)

func set_source_appearance(texture: Texture2D = null, tint: Color = Color.WHITE):
	"""Provide source die texture/tint for fragment visuals."""
	_source_texture = texture
	_source_tint = tint

func _execute_node_track() -> void:
	# Pre-shake on target node
	if _shatter_preset.pre_shake_enabled and _target_node and is_instance_valid(_target_node):
		await _play_pre_shake()

	# Explode fragments
	_spawn_fragments()
	_emit_peak()

	await get_tree().create_timer(_shatter_preset.total_duration).timeout

func _play_pre_shake() -> void:
	"""Rapid shake oscillation on the target node before breaking apart."""
	var node = _target_node
	var original_pos = node.position
	var intensity = _shatter_preset.shake_intensity
	var count = _shatter_preset.shake_count
	var per_shake = _shatter_preset.pre_shake_duration / count

	var tween = create_tween()
	for i in count:
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		# Reduce intensity each shake for a tightening effect
		offset *= (1.0 - float(i) / count * 0.5)
		tween.tween_property(node, "position", original_pos + offset, per_shake * 0.5)
		tween.tween_property(node, "position", original_pos, per_shake * 0.5)
	await tween.finished

func _spawn_fragments():
	"""Spawn fragment particles that burst outward with gravity."""
	var soft_circle = _generate_soft_circle()

	for i in _shatter_preset.fragment_count:
		# Random size within range
		var frag_size = Vector2(
			randf_range(_shatter_preset.fragment_size_min.x, _shatter_preset.fragment_size_max.x),
			randf_range(_shatter_preset.fragment_size_min.y, _shatter_preset.fragment_size_max.y)
		)

		# Texture: inherit from source or use soft circle
		var tex = _source_texture if _shatter_preset.inherit_source_texture and _source_texture else soft_circle
		var tint = _source_tint * _shatter_preset.fragment_color

		var fragment = _create_particle_sprite(frag_size, tex, tint)
		fragment.global_position = _source_pos - fragment.pivot_offset
		fragment.rotation = randf_range(0, TAU)
		add_child(fragment)

		# Calculate trajectory
		var angle = randf_range(0, TAU)
		var speed = randf_range(_shatter_preset.explosion_radius * 0.4, _shatter_preset.explosion_radius)
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		velocity.y -= _shatter_preset.upward_bias  # Initial upward kick

		var spin = randf_range(-_shatter_preset.spin_range, _shatter_preset.spin_range)
		var duration = _shatter_preset.explosion_duration + randf_range(-0.1, 0.1)

		# Animate via tween_method for gravity simulation
		var start_pos = _source_pos
		var start_rot = fragment.rotation
		var gravity = _shatter_preset.gravity

		var tween = create_tween().set_parallel(true)
		tween.tween_method(
			func(t: float):
				# Position: velocity * t + 0.5 * gravity * t²
				var pos = start_pos + velocity * t + Vector2(0, 0.5 * gravity * t * t)
				fragment.global_position = pos - fragment.pivot_offset,
			0.0, duration, duration
		)

		# Spin
		tween.tween_property(fragment, "rotation",
			start_rot + spin * duration, duration
		)

		# Scale: slight pop then shrink
		tween.tween_property(fragment, "scale", Vector2.ONE * 1.1, duration * 0.1).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "scale", Vector2.ZERO, duration * 0.5).set_ease(Tween.EASE_IN).set_delay(duration * 0.5)

		# Fade out in second half
		tween.tween_property(fragment, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)

		tween.chain().tween_callback(fragment.queue_free)
