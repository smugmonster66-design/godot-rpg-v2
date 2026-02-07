# stream_effect.gd
# Sustained directional particle flow between source and target.
# Spawns particles continuously that travel along a path.
# Use for: ongoing drain, heal channel, tether, energy flow.
#
# Usage:
#   var effect = StreamEffect.new()
#   container.add_child(effect)
#   effect.configure(preset, source_pos, target_pos)
#   await effect.play()
extends CombatEffect
class_name StreamEffect

var _stream_preset: StreamPreset = null
var _spawn_timer: float = 0.0
var _elapsed: float = 0.0
var _soft_circle: ImageTexture = null
var _is_streaming: bool = false

func configure(preset: StreamPreset, source: Vector2, target: Vector2):
	_stream_preset = preset
	configure_base(preset, source, target)

func _execute_node_track() -> void:
	_soft_circle = _generate_soft_circle()
	_is_streaming = true
	_elapsed = 0.0
	_spawn_timer = 0.0

	# Peak at midpoint
	get_tree().create_timer(_stream_preset.stream_duration * 0.5).timeout.connect(
		_emit_peak, CONNECT_ONE_SHOT
	)

	# Run the stream loop via process
	set_process(true)
	await get_tree().create_timer(_stream_preset.stream_duration).timeout
	_is_streaming = false
	set_process(false)

	# Wait for trailing particles to arrive
	await get_tree().create_timer(_stream_preset.particle_travel_time + 0.1).timeout

func _process(delta: float):
	if not _is_streaming:
		return

	_elapsed += delta

	# Calculate current spawn rate with ramp
	var rate = _stream_preset.spawn_rate * _get_ramp_multiplier()
	if rate <= 0:
		return

	var interval = 1.0 / rate
	_spawn_timer += delta

	while _spawn_timer >= interval:
		_spawn_timer -= interval
		_spawn_stream_particle()

func _get_ramp_multiplier() -> float:
	"""Ramp up at start, full in middle, ramp down at end."""
	var total = _stream_preset.stream_duration
	var ramp_up = _stream_preset.ramp_up_time
	var ramp_down = _stream_preset.ramp_down_time

	if _elapsed < ramp_up and ramp_up > 0:
		return _elapsed / ramp_up
	elif _elapsed > total - ramp_down and ramp_down > 0:
		return maxf(0.0, (total - _elapsed) / ramp_down)
	return 1.0

func _spawn_stream_particle():
	"""Spawn a single particle that flows from source to target."""
	var particle = _create_particle_sprite(
		_stream_preset.particle_size, _soft_circle,
		_stream_preset.particle_color
	)
	particle.scale = Vector2.ONE * 0.5
	particle.modulate.a = 0.0

	# Random perpendicular offset for spread
	var direction = _get_direction()
	var perp = Vector2(-direction.y, direction.x)
	var spread_offset = perp * randf_range(-_stream_preset.flow_spread, _stream_preset.flow_spread)

	var start = _source_pos + spread_offset
	var end = _target_pos + spread_offset * 0.3  # Converge slightly at target
	particle.global_position = start - particle.pivot_offset
	add_child(particle)

	var travel = _stream_preset.particle_travel_time
	var tween = create_tween().set_parallel(true)

	# Movement (with optional arc)
	if absf(_stream_preset.arc_height) > 1.0:
		tween.tween_method(
			func(t: float):
				var pos = start.lerp(end, t)
				pos.y -= sin(t * PI) * _stream_preset.arc_height
				particle.global_position = pos - particle.pivot_offset,
			0.0, 1.0, travel
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	else:
		tween.tween_property(particle, "global_position",
			end - particle.pivot_offset, travel
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Fade in quickly
	tween.tween_property(particle, "modulate:a", _stream_preset.particle_color.a, travel * 0.15)

	# Scale: pop in, then shrink on arrival
	tween.tween_property(particle, "scale", Vector2.ONE, travel * 0.2).set_ease(Tween.EASE_OUT)
	var end_scale = 1.0 - _stream_preset.arrival_shrink
	tween.tween_property(particle, "scale", Vector2.ONE * end_scale, travel * 0.5).set_delay(travel * 0.5)

	# Fade out near end
	tween.tween_property(particle, "modulate:a", 0.0, travel * 0.25).set_delay(travel * 0.75)

	# Cleanup
	tween.chain().tween_callback(particle.queue_free)
