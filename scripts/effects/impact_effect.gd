# impact_effect.gd
# Quick, punchy directional hit at the target position.
# Draws a slash line across the impact point and bursts sparks outward.
# Use for: weapon strikes, damage application, ability hits.
extends CombatEffect
class_name ImpactEffect

var _impact_preset: ImpactPreset = null

func configure(preset: ImpactPreset, source: Vector2, target: Vector2):
	_impact_preset = preset
	configure_base(preset, source, target)

func _execute_node_track() -> void:
	var soft_circle = _generate_soft_circle()

	if _impact_preset.anticipation_delay > 0:
		await get_tree().create_timer(_impact_preset.anticipation_delay).timeout

	# Everything fires simultaneously at impact
	if _impact_preset.slash_enabled:
		_spawn_slash()
	if _impact_preset.spark_count > 0:
		_spawn_sparks(soft_circle)

	_emit_peak()

	await get_tree().create_timer(_impact_preset.total_duration).timeout

func _spawn_slash():
	"""Draw a directional slash line across the target."""
	var direction = _get_direction()
	var angle = direction.angle() + randf_range(
		-deg_to_rad(_impact_preset.slash_angle_spread),
		deg_to_rad(_impact_preset.slash_angle_spread)
	)

	var slash_dir = Vector2(cos(angle), sin(angle))
	var half_len = _impact_preset.slash_length / 2.0
	var start_pos = _target_pos - slash_dir * half_len
	var end_pos = _target_pos + slash_dir * half_len

	# Slash is a thin stretched rect
	var slash = _create_particle_sprite(
		Vector2(_impact_preset.slash_length, _impact_preset.slash_thickness),
		null, _impact_preset.slash_color
	)

	# Use a white rect as texture
	var img = Image.create(4, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	slash.texture = ImageTexture.create_from_image(img)

	slash.global_position = _target_pos - slash.pivot_offset
	slash.rotation = angle
	slash.scale = Vector2(0.0, 1.0)
	add_child(slash)

	var duration = _impact_preset.slash_duration
	var tween = create_tween()

	# Extend outward
	tween.tween_property(slash, "scale", Vector2(1.0, 1.0), duration * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

	# Fade and thin
	tween.tween_property(slash, "scale:y", 0.0, duration * 0.6).set_ease(Tween.EASE_IN)
	# Can't parallel chain after chain, so use separate tween for fade
	var fade_tween = create_tween()
	fade_tween.tween_interval(duration * 0.3)
	fade_tween.tween_property(slash, "modulate:a", 0.0, duration * 0.7)
	fade_tween.tween_callback(slash.queue_free)

func _spawn_sparks(soft_circle: ImageTexture):
	"""Burst sparks outward from impact point."""
	var incoming = _get_direction()
	var deflect = -incoming  # Bounce direction

	for i in _impact_preset.spark_count:
		var base_angle = randf_range(0, TAU)
		# Bias toward deflection direction
		if _impact_preset.spark_deflection_bias > 0:
			var deflect_angle = deflect.angle() + randf_range(-PI * 0.6, PI * 0.6)
			base_angle = lerp_angle(base_angle, deflect_angle, _impact_preset.spark_deflection_bias)

		var spark_dir = Vector2(cos(base_angle), sin(base_angle))
		var travel_dist = randf_range(_impact_preset.spark_radius * 0.4, _impact_preset.spark_radius)
		var end_pos = _target_pos + spark_dir * travel_dist

		var spark = _create_particle_sprite(
			_impact_preset.spark_size, soft_circle,
			_impact_preset.spark_color
		)
		spark.global_position = _target_pos - spark.pivot_offset
		spark.scale = Vector2.ONE * 0.5
		spark.rotation = randf_range(0, TAU)
		add_child(spark)

		var duration = _impact_preset.spark_duration + randf_range(-0.05, 0.05)
		var tween = create_tween().set_parallel(true)

		# Fly outward (decelerating)
		tween.tween_property(spark, "global_position",
			end_pos - spark.pivot_offset, duration
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		# Pop scale then shrink
		tween.tween_property(spark, "scale", Vector2.ONE * 1.2, duration * 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector2.ZERO, duration * 0.6).set_ease(Tween.EASE_IN).set_delay(duration * 0.4)

		# Fade
		tween.tween_property(spark, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)

		tween.chain().tween_callback(spark.queue_free)
