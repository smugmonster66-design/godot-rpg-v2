# orbit_effect.gd
# Persistent orbiting motes around a source point or node.
# Unlike other effects, Orbit uses start()/stop() rather than play().
# Motes circle continuously until stopped.
# Use for: active buff indicator, charged state, enchant, readied ability.
#
# Usage:
#   var orbit = OrbitEffect.new()
#   container.add_child(orbit)
#   orbit.configure(preset, die_center)
#   orbit.set_follow_node(die_visual)  # motes follow the node's position
#   orbit.start()
#   # ... later ...
#   await orbit.stop()  # fades out and self-destructs
extends Control
class_name OrbitEffect

# ============================================================================
# SIGNALS
# ============================================================================
signal orbit_started()
signal orbit_stopped()

# ============================================================================
# STATE
# ============================================================================
var _preset: OrbitPreset = null
var _center: Vector2 = Vector2.ZERO
var _follow_node: CanvasItem = null
var _is_orbiting: bool = false
var _elapsed: float = 0.0

## Per-mote data
var _motes: Array[Control] = []
var _mote_angles: Array[float] = []
var _mote_radii: Array[float] = []
var _mote_speeds: Array[float] = []

## Trail timer
var _trail_timer: Timer = null
var _soft_circle: ImageTexture = null

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func configure(preset: OrbitPreset, center: Vector2):
	_preset = preset
	_center = center

func set_follow_node(node: CanvasItem):
	"""Set a node to follow — orbit center tracks its position each frame."""
	_follow_node = node

# ============================================================================
# START / STOP
# ============================================================================

func start():
	"""Begin orbiting. Motes fade in."""
	if _is_orbiting:
		return
	_is_orbiting = true
	_elapsed = 0.0
	_soft_circle = _generate_soft_circle()
	_spawn_motes()

	if _preset.trail_enabled:
		_start_trail_timer()

	set_process(true)
	orbit_started.emit()

func stop() -> void:
	"""Fade out motes and self-destruct. Awaitable."""
	if not _is_orbiting:
		return
	_is_orbiting = false
	set_process(false)
	_stop_trail_timer()

	# Fade out all motes
	for mote in _motes:
		if is_instance_valid(mote):
			var tween = mote.create_tween()
			tween.tween_property(mote, "modulate:a", 0.0, _preset.fade_out_duration)
			tween.tween_callback(mote.queue_free)

	await get_tree().create_timer(_preset.fade_out_duration + 0.1).timeout
	_motes.clear()
	orbit_stopped.emit()
	queue_free()

# ============================================================================
# MOTE SPAWNING
# ============================================================================

func _spawn_motes():
	"""Create mote sprites with randomized orbit parameters."""
	var count = _preset.mote_count
	for i in count:
		var mote = _create_mote()
		add_child(mote)
		_motes.append(mote)

		# Evenly distributed starting angles with slight randomization
		var base_angle = (TAU / count) * i
		_mote_angles.append(base_angle + randf_range(-0.3, 0.3))
		_mote_radii.append(_preset.orbit_radius + randf_range(-_preset.radius_variation, _preset.radius_variation))
		_mote_speeds.append(_preset.orbit_speed * (1.0 + randf_range(-_preset.speed_variation, _preset.speed_variation)))

		# Position immediately
		_update_mote_position(i, 0.0)

		# Fade in
		mote.modulate.a = 0.0
		var tween = mote.create_tween()
		tween.tween_property(mote, "modulate:a", _preset.mote_color.a,
			_preset.fade_in_duration + randf_range(0, 0.1)
		)

func _create_mote() -> Control:
	var mote = TextureRect.new()
	mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mote.custom_minimum_size = _preset.mote_size
	mote.size = _preset.mote_size
	mote.pivot_offset = _preset.mote_size / 2.0
	mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mote.texture = _soft_circle
	mote.modulate = _preset.mote_color
	return mote

# ============================================================================
# PER-FRAME UPDATE
# ============================================================================

func _process(delta: float):
	if not _is_orbiting:
		return

	_elapsed += delta

	# Update center if following a node
	if _follow_node and is_instance_valid(_follow_node):
		_center = _follow_node.global_position + _follow_node.size / 2.0

	# Update each mote
	for i in _motes.size():
		if is_instance_valid(_motes[i]):
			_mote_angles[i] += _mote_speeds[i] * delta
			_update_mote_position(i, _elapsed)

func _update_mote_position(index: int, time: float):
	"""Position and scale a single mote based on its orbit parameters."""
	var mote = _motes[index]
	var angle = _mote_angles[index]
	var radius = _mote_radii[index]

	var pos = _center + Vector2(cos(angle), sin(angle)) * radius
	mote.global_position = pos - mote.pivot_offset

	# Breathing scale
	if _preset.breathe_amount > 0:
		var breathe = 1.0 + sin(time * _preset.breathe_speed * TAU + angle) * _preset.breathe_amount
		mote.scale = Vector2.ONE * breathe

# ============================================================================
# TRAILS
# ============================================================================

func _start_trail_timer():
	_trail_timer = Timer.new()
	_trail_timer.wait_time = _preset.trail_interval
	_trail_timer.one_shot = false
	_trail_timer.timeout.connect(_spawn_trails)
	add_child(_trail_timer)
	_trail_timer.start()

func _stop_trail_timer():
	if _trail_timer and is_instance_valid(_trail_timer):
		_trail_timer.stop()
		_trail_timer.queue_free()
		_trail_timer = null

func _spawn_trails():
	for mote in _motes:
		if not is_instance_valid(mote):
			continue
		var ghost = TextureRect.new()
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.custom_minimum_size = _preset.mote_size * 0.7
		ghost.size = ghost.custom_minimum_size
		ghost.pivot_offset = ghost.size / 2.0
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost.texture = _soft_circle
		ghost.modulate = Color(mote.modulate.r, mote.modulate.g, mote.modulate.b, 0.3)
		ghost.global_position = mote.global_position
		ghost.scale = mote.scale * 0.8
		add_child(ghost)

		var tween = ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, _preset.trail_fade)
		tween.tween_callback(ghost.queue_free)

# ============================================================================
# UTILITY
# ============================================================================

func _generate_soft_circle() -> ImageTexture:
	var tex_size: int = 32
	var center_f: float = tex_size / 2.0
	var img = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	for x in tex_size:
		for y in tex_size:
			var dist = Vector2(x, y).distance_to(Vector2(center_f, center_f))
			var normalized = clampf(dist / center_f, 0.0, 1.0)
			var alpha = exp(-normalized * normalized * 3.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)

func update_color(new_color: Color):
	"""Update mote color at runtime (e.g., buff intensity changed)."""
	_preset.mote_color = new_color
	for mote in _motes:
		if is_instance_valid(mote):
			mote.modulate = new_color

func update_speed(new_speed: float):
	"""Update orbit speed at runtime."""
	var ratio = new_speed / _preset.orbit_speed if _preset.orbit_speed > 0 else 1.0
	for i in _mote_speeds.size():
		_mote_speeds[i] *= ratio
	_preset.orbit_speed = new_speed
