# summon_effect.gd
# Materialization: particles spawn at random positions around the target
# and converge inward, forming at the center with a flash.
# Use for: new die appearing, conjured shield, item spawn, ability summoned.
extends CombatEffect
class_name SummonEffect

var _summon_preset: SummonPreset = null

func configure(preset: SummonPreset, target: Vector2, _source: Vector2 = Vector2.ZERO):
	_summon_preset = preset
	configure_base(preset, target, target)

func _execute_node_track() -> void:
	var soft_circle = _generate_soft_circle()

	# Pre-glow at target
	if _summon_preset.pre_glow_enabled:
		_play_pre_glow(soft_circle)
		await get_tree().create_timer(_summon_preset.pre_glow_duration * 0.5).timeout

	# Spawn and converge particles
	var arrived_count: int = 0
	var total = _summon_preset.particle_count

	for i in total:
		var delay = randf() * _summon_preset.start_stagger
		_spawn_converge_particle(soft_circle, delay, func():
			arrived_count += 1
		)

	# Wait for convergence + stagger + small buffer
	await get_tree().create_timer(
		_summon_preset.converge_duration + _summon_preset.start_stagger + 0.05
	).timeout

	# Arrival flash and peak
	_emit_peak()
	if _summon_preset.arrival_flash_enabled:
		_play_arrival_flash(soft_circle)
		await get_tree().create_timer(_summon_preset.arrival_flash_duration).timeout

func _spawn_converge_particle(soft_circle: ImageTexture, delay: float, on_arrive: Callable):
	"""Spawn a particle at a random position that converges to target."""
	var angle = randf_range(0, TAU)
	var radius = randf_range(_summon_preset.spawn_radius * 0.5, _summon_preset.spawn_radius)
	var start_pos = _target_pos + Vector2(cos(angle), sin(angle)) * radius

	var particle = _create_particle_sprite(
		_summon_preset.particle_size, soft_circle,
		_summon_preset.particle_color
	)
	particle.global_position = start_pos - particle.pivot_offset
	particle.scale = Vector2.ONE * 0.3
	particle.modulate.a = 0.0
	particle.rotation = randf_range(0, TAU)
	add_child(particle)

	if delay > 0:
		await get_tree().create_timer(delay).timeout

	var duration = _summon_preset.converge_duration
	var tween = create_tween().set_parallel(true)

	# Move to center
	tween.tween_property(particle, "global_position",
		_target_pos - particle.pivot_offset, duration
	).set_ease(_summon_preset.converge_ease).set_trans(_summon_preset.converge_trans)

	# Fade in
	tween.tween_property(particle, "modulate:a",
		_summon_preset.particle_color.a, duration * 0.2
	)

	# Scale up then shrink as approaching
	tween.tween_property(particle, "scale", Vector2.ONE, duration * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(particle, "scale", Vector2.ONE * 0.2, duration * 0.4).set_ease(Tween.EASE_IN).set_delay(duration * 0.6)

	# Spin accelerating
	tween.tween_property(particle, "rotation",
		particle.rotation + angle * 2, duration
	)

	# Fade at very end
	tween.tween_property(particle, "modulate:a", 0.0, duration * 0.15).set_delay(duration * 0.85)

	tween.chain().tween_callback(func():
		on_arrive.call()
		particle.queue_free()
	)

func _play_pre_glow(soft_circle: ImageTexture):
	"""Subtle glow at target before particles arrive."""
	var glow = _create_particle_sprite(
		_summon_preset.particle_size * 3, soft_circle,
		Color(_summon_preset.particle_color, _summon_preset.pre_glow_intensity)
	)
	glow.global_position = _target_pos - glow.pivot_offset
	glow.scale = Vector2.ONE * 0.3
	add_child(glow)

	var tween = create_tween()
	tween.tween_property(glow, "scale", Vector2.ONE, _summon_preset.pre_glow_duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", 0.0, _summon_preset.pre_glow_duration * 0.5)
	tween.tween_callback(glow.queue_free)

func _play_arrival_flash(soft_circle: ImageTexture):
	"""Bright flash at center when formation completes."""
	var flash = _create_particle_sprite(
		_summon_preset.particle_size * _summon_preset.arrival_flash_scale,
		soft_circle, _summon_preset.arrival_flash_color
	)
	flash.global_position = _target_pos - flash.pivot_offset
	flash.scale = Vector2.ONE * 0.5
	add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "scale",
		Vector2.ONE * _summon_preset.arrival_flash_scale, _summon_preset.arrival_flash_duration * 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(flash, "scale", Vector2.ZERO, _summon_preset.arrival_flash_duration * 0.7).set_ease(Tween.EASE_IN)
	var fade = create_tween()
	fade.tween_property(flash, "modulate:a", 0.0, _summon_preset.arrival_flash_duration).set_delay(_summon_preset.arrival_flash_duration * 0.3)
	fade.tween_callback(flash.queue_free)
