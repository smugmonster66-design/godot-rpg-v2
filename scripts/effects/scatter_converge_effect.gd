# scatter_converge_effect.gd - Orchestrates a scatter-converge particle burst
# Spawns ScatterParticle nodes, manages scatter positions, trails, impact flash.
# Add to a CanvasLayer overlay (e.g., CombatRollAnimator's ProjectileOverlay).
#
# Usage:
#   var effect = ScatterConvergeEffect.new()
#   container.add_child(effect)
#   effect.configure(preset, source_pos, target_pos, die_info)
#   await effect.play()
#   # effect cleans itself up
extends Control
class_name ScatterConvergeEffect

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when converge phase begins (first particle starts moving to target)
signal converge_started()
## Emitted when a configurable percentage of particles have arrived
signal impact()
## Emitted when all particles have arrived and cleanup is done
signal finished()

# ============================================================================
# CONFIGURATION
# ============================================================================
var _preset: ScatterConvergePreset = null
var _source_pos: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO

# Die visual data (same format as CombatRollAnimator._get_source_info())
var _fill_texture: Texture2D = null
var _fill_material: Material = null
var _tint: Color = Color.WHITE
var _element_color: Color = Color.WHITE

# Base particle texture (soft circle)
var _base_texture: Texture2D = null

# ============================================================================
# STATE
# ============================================================================
var _particles: Array[ScatterParticle] = []
var _arrived_count: int = 0
var _is_playing: bool = false
var _trail_timer: Timer = null

# ============================================================================
# ELEMENT COLOR MAP (fallback when no RarityColors/element data provided)
# ============================================================================
const ELEMENT_COLORS: Dictionary = {
	0: Color(0.9, 0.9, 0.9),       # NONE — light gray
	1: Color(0.9, 0.85, 0.7),      # SLASHING — pale steel
	2: Color(0.8, 0.75, 0.6),      # BLUNT — warm stone
	3: Color(0.7, 0.8, 0.9),       # PIERCING — silver blue
	4: Color(1.0, 0.45, 0.15),     # FIRE — orange
	5: Color(0.5, 0.8, 1.0),       # ICE — light blue
	6: Color(0.7, 0.9, 1.0),       # SHOCK — electric cyan
	7: Color(0.4, 0.85, 0.25),     # POISON — acid green
	8: Color(0.45, 0.15, 0.55),    # SHADOW — dark purple
}

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func configure(preset: ScatterConvergePreset, source: Vector2, target: Vector2,
				die_info: Dictionary, base_texture: Texture2D = null):
	"""Configure the effect before calling play().

	Args:
		preset: ScatterConvergePreset resource with all timing/behavior config.
		source: Global position of the source die center.
		target: Global position of the target die center.
		die_info: Dictionary with keys: fill_texture, fill_material, tint, element.
				  Same format as CombatRollAnimator._get_source_info().
		base_texture: Soft circle texture for base particle layer. If null, generates one.
	"""
	_preset = preset
	_source_pos = source
	_target_pos = target

	_fill_texture = die_info.get("fill_texture", null) as Texture2D
	_fill_material = die_info.get("fill_material", null) as Material
	_tint = die_info.get("tint", Color.WHITE) as Color

	# Element color from die_info or fallback map
	var element_val = die_info.get("element", 0)
	if element_val is int:
		_element_color = ELEMENT_COLORS.get(element_val, Color.WHITE)
	elif element_val is Color:
		_element_color = element_val
	else:
		_element_color = Color.WHITE

	# Base shape texture
	if base_texture:
		_base_texture = base_texture
	else:
		_base_texture = _generate_soft_circle()

func configure_from_die(preset: ScatterConvergePreset, source: Vector2, target: Vector2,
						die_resource: DieResource, die_visual: Control = null,
						base_texture: Texture2D = null):
	"""Convenience: configure directly from a DieResource and optional visual.

	Pulls fill_texture, material, tint, and element from the die data.
	"""
	var info: Dictionary = {}
	info["fill_texture"] = die_resource.fill_texture
	info["element"] = die_resource.element

	# Try to get active material from the visual (includes affix shaders)
	if die_visual and is_instance_valid(die_visual):
		if "fill_texture" in die_visual and die_visual.fill_texture is TextureRect:
			info["fill_material"] = die_visual.fill_texture.material
		info["tint"] = die_visual.modulate
	else:
		info["tint"] = die_resource.color

	configure(preset, source, target, info, base_texture)

# ============================================================================
# PLAY
# ============================================================================

func play() -> void:
	"""Run the full effect. Awaitable — returns when everything is done."""
	if not _preset:
		push_error("ScatterConvergeEffect: No preset configured!")
		finished.emit()
		return

	_is_playing = true
	_arrived_count = 0

	# ── Calculate scatter positions ──
	var scatter_positions: Array[Vector2] = _calculate_scatter_positions()

	# ── Calculate per-particle converge delays (for cascading arrival) ──
	var converge_delays: Array[float] = []
	for i in _preset.particle_count:
		converge_delays.append(randf() * _preset.converge_stagger * _preset.particle_count)

	# ── Spawn particles ──
	for i in _preset.particle_count:
		var particle = ScatterParticle.new()
		add_child(particle)
		particle.configure(
			_preset,
			_fill_texture,
			_fill_material,
			_tint,
			_element_color,
			_base_texture
		)
		particle.arrived.connect(_on_particle_arrived.bind(particle))
		_particles.append(particle)

	# ── Start trail system if enabled ──
	if _preset.trails_enabled:
		_start_trail_spawner()

	# ── Launch all particles ──
	for i in _particles.size():
		_particles[i].start(
			_source_pos,
			scatter_positions[i],
			_target_pos,
			converge_delays[i]
		)

	# ── Emit converge_started after scatter + hang ──
	var converge_signal_delay = _preset.scatter_duration + _preset.hang_duration
	get_tree().create_timer(converge_signal_delay).timeout.connect(
		func():
			if _is_playing:
				converge_started.emit(),
		CONNECT_ONE_SHOT
	)

	# ── Wait for all particles to arrive (with safety timeout) ──
	var safety_timeout = _preset.get_total_duration() + 0.5
	var timeout_timer = get_tree().create_timer(safety_timeout)

	while _arrived_count < _preset.particle_count and _is_playing:
		# Check each frame if we're done
		await get_tree().process_frame
		if not is_inside_tree():
			break
		# Safety: bail if timeout exceeded
		if timeout_timer.time_left <= 0:
			push_warning("ScatterConvergeEffect: Safety timeout reached, %d/%d arrived" % [_arrived_count, _preset.particle_count])
			break

	# ── Stop trails ──
	_stop_trail_spawner()

	# ── Impact flash ──
	if _preset.impact_flash_enabled:
		_play_impact_flash()
		await get_tree().create_timer(_preset.impact_flash_duration).timeout

	# ── Cleanup ──
	_is_playing = false
	_cleanup()
	finished.emit()

# ============================================================================
# SCATTER POSITION CALCULATION
# ============================================================================

func _calculate_scatter_positions() -> Array[Vector2]:
	"""Calculate scatter target positions for all particles."""
	var positions: Array[Vector2] = []
	var direction_to_target = (_target_pos - _source_pos).normalized()
	var base_angle = direction_to_target.angle()

	for i in _preset.particle_count:
		var angle: float
		var radius: float = randf_range(_preset.scatter_radius_min, _preset.scatter_radius_max)

		if _preset.directional_bias > 0.0:
			# Biased toward target direction with spread
			var half_spread = _preset.get_scatter_spread_rad() / 2.0
			var random_angle = randf_range(-half_spread, half_spread)

			# Blend between fully random and directionally biased
			var radial_angle = randf_range(0, TAU)
			angle = lerp_angle(radial_angle, base_angle + random_angle, _preset.directional_bias)
		else:
			# Pure radial burst
			angle = randf_range(0, TAU)

		var offset = Vector2(cos(angle), sin(angle)) * radius
		positions.append(_source_pos + offset)

	return positions

# ============================================================================
# PARTICLE ARRIVAL
# ============================================================================

func _on_particle_arrived(particle: ScatterParticle):
	"""Called when a single particle reaches the converge target."""
	_arrived_count += 1

	# Emit impact signal at ~70% arrival (feels like the main hit)
	var impact_threshold = ceili(_preset.particle_count * 0.7)
	if _arrived_count == impact_threshold:
		impact.emit()

# ============================================================================
# TRAIL SPAWNER
# ============================================================================

func _start_trail_spawner():
	"""Start a timer that spawns afterimages during the converge phase."""
	if not _preset.trails_enabled:
		return

	# Wait until converge phase begins
	var converge_start = _preset.scatter_duration + _preset.hang_duration
	await get_tree().create_timer(converge_start).timeout

	if not _is_playing:
		return

	_trail_timer = Timer.new()
	_trail_timer.wait_time = _preset.trail_interval
	_trail_timer.one_shot = false
	_trail_timer.timeout.connect(_spawn_trails)
	add_child(_trail_timer)
	_trail_timer.start()

	# Auto-stop after converge duration
	var max_stagger = _preset.converge_stagger * _preset.particle_count
	get_tree().create_timer(_preset.converge_duration + max_stagger).timeout.connect(
		_stop_trail_spawner,
		CONNECT_ONE_SHOT
	)

func _stop_trail_spawner():
	"""Stop the trail spawn timer."""
	if _trail_timer and is_instance_valid(_trail_timer):
		_trail_timer.stop()
		_trail_timer.queue_free()
		_trail_timer = null

func _spawn_trails():
	"""Spawn afterimages for all living particles."""
	for particle in _particles:
		if is_instance_valid(particle) and particle._is_alive:
			particle.spawn_afterimage(self)

# ============================================================================
# IMPACT FLASH
# ============================================================================

func _play_impact_flash():
	"""Spawn a brief flash at the target position using the die's visuals."""
	var flash = TextureRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.custom_minimum_size = _preset.particle_size * _preset.impact_flash_scale
	flash.size = flash.custom_minimum_size
	flash.pivot_offset = flash.size / 2.0
	flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Use fill texture + shader
	if _fill_texture:
		flash.texture = _fill_texture
	elif _base_texture:
		flash.texture = _base_texture

	if _fill_material:
		flash.material = _fill_material.duplicate()

	# Bright, element-colored
	flash.modulate = Color(
		_element_color.r * 1.5,
		_element_color.g * 1.5,
		_element_color.b * 1.5,
		1.0
	)

	flash.global_position = _target_pos - flash.pivot_offset
	flash.scale = Vector2.ONE * _preset.impact_flash_scale
	add_child(flash)

	# Quick scale pop then fade
	var tween = create_tween().set_parallel(true)
	tween.tween_property(
		flash, "scale",
		Vector2.ONE * _preset.impact_flash_scale * 1.3,
		_preset.impact_flash_duration * 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(
		flash, "scale",
		Vector2.ONE * 0.5,
		_preset.impact_flash_duration * 0.7
	).set_ease(Tween.EASE_IN)
	tween.tween_property(
		flash, "modulate:a", 0.0,
		_preset.impact_flash_duration
	).set_delay(_preset.impact_flash_duration * 0.3)
	tween.chain().tween_callback(flash.queue_free)

# ============================================================================
# SOFT CIRCLE GENERATION (fallback base shape)
# ============================================================================

func _generate_soft_circle() -> Texture2D:
	"""Procedurally generate a soft radial gradient circle texture."""
	var tex_size: int = 32
	var center: float = tex_size / 2.0
	var img = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)

	for x in tex_size:
		for y in tex_size:
			var dist = Vector2(x, y).distance_to(Vector2(center, center))
			var normalized = clampf(dist / center, 0.0, 1.0)
			# Gaussian-like falloff
			var alpha = exp(-normalized * normalized * 3.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)

# ============================================================================
# CLEANUP
# ============================================================================

func _cleanup():
	"""Remove all particles and self."""
	_stop_trail_spawner()
	for particle in _particles:
		if is_instance_valid(particle):
			particle.kill()
	_particles.clear()
	# Self-destruct after a brief delay for any remaining trail fades
	await get_tree().create_timer(0.3).timeout
	queue_free()

func cancel():
	"""Immediately cancel the effect."""
	_is_playing = false
	_cleanup()
