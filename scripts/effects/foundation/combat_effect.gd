# combat_effect.gd
# Base class for all combat visual effects.
# Orchestrates three parallel animation tracks:
#   1. Node track — spawned particles/visuals (subclass implements _execute_node_track)
#   2. Shader track — temporary shaders on existing nodes (auto-managed from preset)
#   3. Screen track — full-screen overlays (auto-managed from preset)
#
# Subclasses override _execute_node_track() for their specific behavior.
# Shader and screen tracks run automatically from CombatEffectPreset config.
#
# Usage:
#   var effect = SomeEffect.new()
#   container.add_child(effect)
#   effect.configure(preset, source_pos, target_pos, ...)
#   effect.set_target_node(enemy_visual)     # optional: for shader track
#   effect.set_source_node(caster_visual)    # optional: for shader track
#   await effect.play()
#   # effect self-destructs
extends Control
class_name CombatEffect

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when the effect begins playing
signal effect_started()
## Emitted at the "peak" moment (hit, impact, max intensity)
signal effect_peak()
## Emitted when the effect is fully complete
signal effect_finished()

# ============================================================================
# STATE
# ============================================================================
var _preset: CombatEffectPreset = null
var _is_playing: bool = false
var _source_pos: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO

## Optional node references for shader track application
var _target_node: CanvasItem = null
var _source_node: CanvasItem = null

## Sub-controllers
var _shader_animator: ShaderAnimator = null
var _screen_effector: ScreenEffector = null

## Shader handles for cleanup
var _shader_handles: Array[int] = []

## Audio players
var _audio_player: AudioStreamPlayer2D = null

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_shader_animator = ShaderAnimator.new()
	_shader_animator.name = "ShaderAnimator"
	add_child(_shader_animator)

	_screen_effector = ScreenEffector.new()
	_screen_effector.name = "ScreenEffector"
	add_child(_screen_effector)

	_audio_player = AudioStreamPlayer2D.new()
	_audio_player.name = "AudioPlayer"
	add_child(_audio_player)

func configure_base(preset: CombatEffectPreset, source: Vector2, target: Vector2):
	"""Set core positioning. Called by subclass configure() methods."""
	_preset = preset
	_source_pos = source
	_target_pos = target

func set_target_node(node: CanvasItem):
	"""Set the node that receives the target shader track."""
	_target_node = node

func set_source_node(node: CanvasItem):
	"""Set the node that receives the source shader track."""
	_source_node = node

# ============================================================================
# PLAYBACK
# ============================================================================

func play() -> void:
	"""Run the full effect. Awaitable — returns when complete."""
	if not _preset:
		push_error("CombatEffect: No preset configured!")
		effect_finished.emit()
		return

	_is_playing = true
	effect_started.emit()
	_play_sound(_preset.start_sound)

	# Start all three tracks in parallel
	_start_shader_track()
	_start_screen_track()

	# Node track is the primary timeline — subclasses implement this
	await _execute_node_track()

	# Cleanup
	_is_playing = false
	_cleanup_shader_track()
	_screen_effector.clear()
	effect_finished.emit()

	# Brief delay for trailing visuals (afterimages, shader fades)
	await get_tree().create_timer(0.2).timeout
	queue_free()

# ============================================================================
# NODE TRACK (override in subclasses)
# ============================================================================

func _execute_node_track() -> void:
	"""Override in subclasses for spawned particle/visual behavior.
	This is the primary timeline — shader and screen tracks run alongside it.
	Must emit effect_peak at the appropriate moment."""
	await get_tree().create_timer(0.5).timeout

# ============================================================================
# SHADER TRACK (automatic from preset)
# ============================================================================

func _start_shader_track():
	"""Apply temporary shaders to target and source nodes."""
	if not _preset:
		return

	# Target shader
	if _preset.has_target_shader() and _target_node and is_instance_valid(_target_node):
		var mode = ShaderAnimator.ApplyMode.STACK if _preset.target_shader_mode == 0 else ShaderAnimator.ApplyMode.REPLACE
		var handle = _shader_animator.apply(
			_target_node, _preset.target_shader,
			_preset.target_shader_params, mode
		)
		_shader_handles.append(handle)
		if _preset.target_shader_anims.size() > 0:
			_shader_animator.play_animations(handle, _preset.target_shader_anims)

	# Source shader
	if _preset.has_source_shader() and _source_node and is_instance_valid(_source_node):
		var mode = ShaderAnimator.ApplyMode.STACK if _preset.source_shader_mode == 0 else ShaderAnimator.ApplyMode.REPLACE
		var handle = _shader_animator.apply(
			_source_node, _preset.source_shader,
			_preset.source_shader_params, mode
		)
		_shader_handles.append(handle)
		if _preset.source_shader_anims.size() > 0:
			_shader_animator.play_animations(handle, _preset.source_shader_anims)

func _cleanup_shader_track():
	"""Restore all temporary shaders."""
	_shader_animator.cleanup()
	_shader_handles.clear()

# ============================================================================
# SCREEN TRACK (automatic from preset)
# ============================================================================

func _start_screen_track():
	"""Start screen-space effects from preset configuration."""
	if not _preset or not _preset.has_screen_effect():
		return

	if _preset.screen_shader:
		_screen_effector.apply(_preset.screen_shader, _preset.screen_shader_params)
		if _preset.screen_shader_anims.size() > 0:
			_screen_effector.play_animations(_preset.screen_shader_anims)

	if _preset.screen_flash_color.a > 0.0 and _preset.screen_flash_duration > 0.0:
		_screen_effector.flash_color(_preset.screen_flash_color, _preset.screen_flash_duration)

# ============================================================================
# PEAK MOMENT
# ============================================================================

func _emit_peak():
	"""Call this from subclass _execute_node_track() at the impact/hit moment."""
	effect_peak.emit()
	_play_sound(_preset.peak_sound)

# ============================================================================
# AUDIO
# ============================================================================

func _play_sound(stream: AudioStream):
	if stream and _audio_player:
		_audio_player.stream = stream
		_audio_player.global_position = _target_pos
		_audio_player.play()

# ============================================================================
# UTILITY FOR SUBCLASSES
# ============================================================================

func _get_direction() -> Vector2:
	"""Unit vector from source to target."""
	return (_target_pos - _source_pos).normalized()

func _get_distance() -> float:
	"""Distance from source to target."""
	return _source_pos.distance_to(_target_pos)

func _create_particle_sprite(size: Vector2, texture: Texture2D = null,
							tint: Color = Color.WHITE) -> TextureRect:
	"""Helper: create a simple particle TextureRect."""
	var sprite = TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.custom_minimum_size = size
	sprite.size = size
	sprite.pivot_offset = size / 2.0
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if texture:
		sprite.texture = texture
	sprite.modulate = tint
	return sprite

func _generate_soft_circle(tex_size: int = 32) -> ImageTexture:
	"""Helper: procedural soft radial gradient."""
	var center: float = tex_size / 2.0
	var img = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	for x in tex_size:
		for y in tex_size:
			var dist = Vector2(x, y).distance_to(Vector2(center, center))
			var normalized = clampf(dist / center, 0.0, 1.0)
			var alpha = exp(-normalized * normalized * 3.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)

func cancel():
	"""Immediately cancel the effect."""
	_is_playing = false
	_cleanup_shader_track()
	_screen_effector.clear()
	queue_free()
