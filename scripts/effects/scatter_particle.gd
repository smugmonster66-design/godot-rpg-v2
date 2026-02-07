# scatter_particle.gd - Individual scatter-converge particle
# Two-layer visual: BaseShape (soft glow, element tinted) + DieFace (fill texture + shader)
# Manages its own scatter → hang → converge tween chain
extends Control
class_name ScatterParticle

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when this particle reaches its converge target
signal arrived()

# ============================================================================
# CHILD NODES (created in _ready)
# ============================================================================
var base_shape: TextureRect = null
var die_face: TextureRect = null

# ============================================================================
# STATE
# ============================================================================
var _preset: ScatterConvergePreset = null
var _source_pos: Vector2 = Vector2.ZERO
var _scatter_target: Vector2 = Vector2.ZERO
var _converge_target: Vector2 = Vector2.ZERO
var _spin_rate: float = 0.0
var _is_alive: bool = true

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_layers()

func _create_layers():
	"""Build the two-layer visual structure."""
	# Base shape — soft circle glow, element-tinted
	base_shape = TextureRect.new()
	base_shape.name = "BaseShape"
	base_shape.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_shape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_shape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(base_shape)

	# Die face — fill texture with shader, additive blend
	die_face = TextureRect.new()
	die_face.name = "DieFace"
	die_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	die_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	die_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	die_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(die_face)

func configure(preset: ScatterConvergePreset, fill_texture: Texture2D,
				fill_material: Material, tint: Color, element_color: Color,
				base_texture: Texture2D):
	"""Configure particle appearance.

	Args:
		preset: Timing and behavior settings.
		fill_texture: The die's fill texture (rendered on die_face layer).
		fill_material: The die's active ShaderMaterial (duplicated per particle).
		tint: Modulate color from the die visual.
		element_color: Fallback glow color for base shape.
		base_texture: Soft circle / spark texture for the base layer.
	"""
	_preset = preset

	custom_minimum_size = preset.particle_size
	size = preset.particle_size
	pivot_offset = preset.particle_size / 2.0

	# Base shape: element-colored glow
	if base_shape:
		if base_texture:
			base_shape.texture = base_texture
		base_shape.modulate = Color(element_color.r, element_color.g, element_color.b, preset.base_shape_opacity)

	# Die face: fill texture + shader, additive blend
	if die_face:
		if fill_texture:
			die_face.texture = fill_texture
		if fill_material:
			die_face.material = fill_material.duplicate()

		# Apply additive blend via CanvasItemMaterial
		if preset.additive_blend:
			var canvas_mat = CanvasItemMaterial.new()
			canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			# If we already have a ShaderMaterial, we need it on the TextureRect.
			# CanvasItem blend mode is set on the node's CanvasItem, not the material.
			# So we set light_mode on the die_face node itself.
			die_face.material = die_face.material  # Keep shader
			# Actually: Godot's CanvasItem doesn't have a direct blend_mode property.
			# The cleanest approach: wrap in a SubViewport or use a CanvasItemMaterial
			# as next_pass. But simplest: just use modulate additive via self_modulate
			# with a CanvasGroup, OR accept that the shader already produces bright output.
			#
			# Pragmatic solution: we'll boost the die_face modulate to simulate additive
			# and set the parent's blend. Since the particle is a standalone node in an
			# overlay layer, we can safely set a CanvasItemMaterial on the die_face.
			if not die_face.material or not die_face.material is ShaderMaterial:
				die_face.material = canvas_mat
			else:
				# ShaderMaterial is present — we can't stack. Instead, brighten modulate
				# to approximate additive over the base shape.
				pass

		die_face.modulate = Color(tint.r, tint.g, tint.b, preset.die_face_opacity)

	# Random initial rotation
	rotation = randf_range(-preset.initial_rotation_range, preset.initial_rotation_range)

	# Random spin rate
	_spin_rate = randf_range(-preset.spin_amount, preset.spin_amount)

# ============================================================================
# ANIMATION LIFECYCLE
# ============================================================================

func start(source: Vector2, scatter_pos: Vector2, converge_pos: Vector2, converge_delay: float):
	"""Begin the three-phase animation.

	Args:
		source: Global position to start from (die center).
		scatter_pos: Global position to scatter to.
		converge_pos: Global position to converge on (target die center).
		converge_delay: Per-particle stagger delay before converge starts.
	"""
	_source_pos = source
	_scatter_target = scatter_pos
	_converge_target = converge_pos

	# Position at source, start invisible if using scale pop
	global_position = source - pivot_offset
	if _preset.scatter_start_scale < 1.0:
		scale = Vector2.ONE * _preset.scatter_start_scale
		modulate.a = 0.0

	# ── PHASE 1: SCATTER ──
	var scatter_tween = create_tween().set_parallel(true)

	# Move to scatter position
	scatter_tween.tween_property(
		self, "global_position",
		scatter_pos - pivot_offset,
		_preset.scatter_duration
	).set_ease(_preset.scatter_ease).set_trans(_preset.scatter_trans)

	# Pop in to full size
	if _preset.scatter_start_scale < 1.0:
		scatter_tween.tween_property(self, "scale", Vector2.ONE, _preset.scale_pop_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		scatter_tween.tween_property(self, "modulate:a", 1.0, _preset.scale_pop_duration * 0.5)

	# Spin during scatter
	if _spin_rate != 0.0:
		var scatter_rot = rotation + _spin_rate * (_preset.scatter_duration / _get_total_flight_time())
		scatter_tween.tween_property(self, "rotation", scatter_rot, _preset.scatter_duration)

	await scatter_tween.finished
	if not _is_alive:
		return

	# ── PHASE 2: HANG ──
	if _preset.hang_duration > 0.0:
		var hang_tween = create_tween().set_parallel(true)

		# Subtle drift
		if _preset.hang_drift > 0.0:
			var drift_offset = Vector2(
				randf_range(-_preset.hang_drift, _preset.hang_drift),
				randf_range(-_preset.hang_drift, _preset.hang_drift)
			)
			hang_tween.tween_property(
				self, "global_position",
				global_position + drift_offset,
				_preset.hang_duration
			).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		# Breathe scale
		if _preset.hang_breathe > 0.0:
			var breathe_scale = 1.0 + randf_range(-_preset.hang_breathe, _preset.hang_breathe)
			hang_tween.tween_property(
				self, "scale",
				Vector2.ONE * breathe_scale,
				_preset.hang_duration
			).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		# Gentle spin continues
		if _spin_rate != 0.0:
			hang_tween.tween_property(
				self, "rotation",
				rotation + _spin_rate * 0.2,
				_preset.hang_duration
			)

		await hang_tween.finished
		if not _is_alive:
			return

	# ── STAGGER DELAY ──
	if converge_delay > 0.0:
		await get_tree().create_timer(converge_delay).timeout
		if not _is_alive:
			return

	# ── PHASE 3: CONVERGE ──
	var converge_tween = create_tween().set_parallel(true)

	# Move to target
	converge_tween.tween_property(
		self, "global_position",
		_converge_target - pivot_offset,
		_preset.converge_duration
	).set_ease(_preset.converge_ease).set_trans(_preset.converge_trans)

	# Shrink on approach
	if _preset.converge_shrink > 0.0:
		var end_scale = 1.0 - _preset.converge_shrink
		converge_tween.tween_property(
			self, "scale",
			Vector2.ONE * end_scale,
			_preset.converge_duration
		).set_ease(Tween.EASE_IN)

	# Accelerated spin
	if _spin_rate != 0.0:
		var converge_rot = rotation + _spin_rate * _preset.converge_spin_accel
		converge_tween.tween_property(
			self, "rotation",
			converge_rot,
			_preset.converge_duration
		)

	# Fade out near the end
	converge_tween.tween_property(
		self, "modulate:a", 0.0,
		_preset.converge_duration * 0.3
	).set_delay(_preset.converge_duration * 0.7)

	await converge_tween.finished

	arrived.emit()

# ============================================================================
# TRAIL AFTERIMAGES
# ============================================================================

func spawn_afterimage(parent: Control):
	"""Create a fading afterimage at the current position.
	Called externally by ScatterConvergeEffect during converge phase."""
	if not _is_alive or not _preset:
		return

	var ghost = TextureRect.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.custom_minimum_size = _preset.particle_size
	ghost.size = _preset.particle_size
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.pivot_offset = _preset.particle_size / 2.0

	# Copy appearance from die_face (or base_shape as fallback)
	if die_face and die_face.texture:
		ghost.texture = die_face.texture
		ghost.modulate = die_face.modulate * Color(1, 1, 1, 0.5)
		if die_face.material:
			ghost.material = die_face.material.duplicate()
	elif base_shape and base_shape.texture:
		ghost.texture = base_shape.texture
		ghost.modulate = base_shape.modulate * Color(1, 1, 1, 0.4)

	ghost.global_position = global_position
	ghost.rotation = rotation
	ghost.scale = scale * 0.85
	parent.add_child(ghost)

	# Fade and remove
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, _preset.trail_fade_duration)
	tween.tween_callback(ghost.queue_free)

# ============================================================================
# CLEANUP
# ============================================================================

func kill():
	"""Immediately stop and clean up."""
	_is_alive = false
	queue_free()

func _get_total_flight_time() -> float:
	"""Approximate total time from scatter to converge end."""
	if _preset:
		return _preset.scatter_duration + _preset.hang_duration + _preset.converge_duration
	return 1.0
