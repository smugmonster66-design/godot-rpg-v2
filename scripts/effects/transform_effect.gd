# transform_effect.gd
# In-place transformation: the shader track does the heavy lifting.
# The node track provides optional sparkle accents and scale punch.
# Use for: element shift, reroll visual, value change, rarity upgrade.
#
# NOTE: This effect relies heavily on the target_shader in the preset.
# Without a target shader, only the sparkles and scale punch play.
# Common shaders: dissolve, color_shift, shimmer, flash_swap.
#
# Usage:
#   var effect = TransformEffect.new()
#   container.add_child(effect)
#   effect.configure(preset, die_center)
#   effect.set_target_node(die_visual)  # REQUIRED for shader track
#   effect.set_swap_callback(func(): die.element = new_element; die_visual.refresh())
#   await effect.play()
extends CombatEffect
class_name TransformEffect

var _transform_preset: TransformPreset = null
## Callback invoked at the swap point (e.g., change die element, update display)
var _swap_callback: Callable = Callable()

func configure(preset: TransformPreset, source: Vector2, _target: Vector2 = Vector2.ZERO):
	_transform_preset = preset
	configure_base(preset, source, source)

func set_swap_callback(callback: Callable):
	"""Set the function called at the swap point to apply the actual data change."""
	_swap_callback = callback

func _execute_node_track() -> void:
	var soft_circle = _generate_soft_circle()
	var duration = _transform_preset.transform_duration
	var swap_time = duration * _transform_preset.swap_point

	# Schedule sparkles to fire at swap point
	if _transform_preset.sparkle_count > 0:
		get_tree().create_timer(swap_time - 0.05).timeout.connect(
			func(): _spawn_sparkles(soft_circle),
			CONNECT_ONE_SHOT
		)

	# Schedule scale punch at swap point
	if _transform_preset.scale_punch_enabled and _target_node and is_instance_valid(_target_node):
		get_tree().create_timer(swap_time - _transform_preset.squash_duration).timeout.connect(
			func(): _play_scale_punch(),
			CONNECT_ONE_SHOT
		)

	# Schedule swap callback
	get_tree().create_timer(swap_time).timeout.connect(
		func():
			if _swap_callback.is_valid():
				_swap_callback.call()
			_emit_peak(),
		CONNECT_ONE_SHOT
	)

	await get_tree().create_timer(duration).timeout

func _spawn_sparkles(soft_circle: ImageTexture):
	"""Spawn sparkle particles radiating from the transform center."""
	for i in _transform_preset.sparkle_count:
		var angle = randf_range(0, TAU)
		var radius = randf_range(_transform_preset.sparkle_radius * 0.3, _transform_preset.sparkle_radius)
		var end_pos = _source_pos + Vector2(cos(angle), sin(angle)) * radius

		var sparkle = _create_particle_sprite(
			_transform_preset.sparkle_size, soft_circle,
			_transform_preset.sparkle_color
		)
		sparkle.global_position = _source_pos - sparkle.pivot_offset
		sparkle.scale = Vector2.ZERO
		sparkle.rotation = randf_range(0, TAU)
		add_child(sparkle)

		var dur = _transform_preset.sparkle_duration + randf_range(-0.05, 0.05)
		var tween = create_tween().set_parallel(true)

		# Pop out
		tween.tween_property(sparkle, "global_position",
			end_pos - sparkle.pivot_offset, dur
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		# Scale pop then fade
		tween.tween_property(sparkle, "scale", Vector2.ONE, dur * 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(sparkle, "scale", Vector2.ZERO, dur * 0.5).set_ease(Tween.EASE_IN).set_delay(dur * 0.5)

		tween.tween_property(sparkle, "modulate:a", 0.0, dur * 0.3).set_delay(dur * 0.7)

		tween.chain().tween_callback(sparkle.queue_free)

func _play_scale_punch():
	"""Squash-and-stretch on the target node at swap point."""
	if not _target_node or not is_instance_valid(_target_node):
		return

	var original_scale = _target_node.scale
	var squash = _transform_preset.squash_scale
	var dur = _transform_preset.squash_duration

	var tween = create_tween()
	# Squash
	tween.tween_property(_target_node, "scale",
		Vector2(original_scale.x * squash.x, original_scale.y * squash.y), dur
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Stretch (overshoot)
	tween.tween_property(_target_node, "scale",
		Vector2(original_scale.x * squash.y, original_scale.y * squash.x), dur
	).set_ease(Tween.EASE_IN_OUT)
	# Return
	tween.tween_property(_target_node, "scale",
		original_scale, dur * 1.5
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
