# screen_effector.gd
# Manages screen-space shader effects via a full-screen ColorRect overlay.
# Used for shockwaves, chromatic aberration, screen flash, vignette pulse, etc.
#
# Creates its own CanvasLayer (layer 110, above ProjectileOverlay at 100)
# so screen effects render on top of all gameplay elements.
#
# Usage:
#   screen_effector.apply(shockwave_shader, {"center": hit_pos, "intensity": 0.0})
#   screen_effector.animate("intensity", 0.0, 1.0, 0.15)
#   screen_effector.animate("intensity", 1.0, 0.0, 0.3)
#   await screen_effector.wait_for_animations()
#   screen_effector.clear()
extends Node
class_name ScreenEffector

# ============================================================================
# INTERNAL STATE
# ============================================================================
var _canvas_layer: CanvasLayer = null
var _overlay: ColorRect = null
var _material: ShaderMaterial = null
var _active_tweens: Array[Tween] = []

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "ScreenEffectLayer"
	_canvas_layer.layer = 110
	add_child(_canvas_layer)

	_overlay = ColorRect.new()
	_overlay.name = "ScreenOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_overlay.color = Color(1, 1, 1, 0)
	_canvas_layer.add_child(_overlay)

# ============================================================================
# APPLICATION
# ============================================================================

func apply(shader: Shader, initial_params: Dictionary = {}) -> ShaderMaterial:
	"""Apply a screen shader. Returns the material for direct manipulation."""
	_material = ShaderMaterial.new()
	_material.shader = shader
	for key in initial_params:
		_material.set_shader_parameter(key, initial_params[key])
	_overlay.material = _material
	_overlay.visible = true
	return _material

func set_param(param_name: String, value: Variant):
	"""Set a shader parameter immediately."""
	if _material:
		_material.set_shader_parameter(param_name, value)

# ============================================================================
# ANIMATION
# ============================================================================

func animate(param_name: String, from_val: Variant, to_val: Variant,
			duration: float, ease: Tween.EaseType = Tween.EASE_IN_OUT,
			trans: Tween.TransitionType = Tween.TRANS_LINEAR,
			delay_sec: float = 0.0) -> Tween:
	"""Animate a screen shader parameter."""
	if not _material:
		return null

	var mat = _material
	var tween = create_tween()

	if delay_sec > 0.0:
		tween.tween_interval(delay_sec)

	tween.tween_method(
		func(val): mat.set_shader_parameter(param_name, val),
		from_val, to_val, duration
	).set_ease(ease).set_trans(trans)

	_active_tweens.append(tween)
	return tween

func play_animations(animations: Array[ShaderParamAnimation]) -> void:
	"""Play multiple ShaderParamAnimations on the screen shader."""
	for anim in animations:
		animate(anim.param_name, anim.get_start(), anim.get_end(),
				anim.duration, anim.ease_type, anim.trans_type, anim.delay)

func wait_for_animations() -> void:
	"""Await all active animations completing."""
	for tween in _active_tweens:
		if tween and tween.is_valid():
			await tween.finished
	_active_tweens.clear()

# ============================================================================
# SCREEN FLASH (convenience)
# ============================================================================

func flash_color(color: Color, duration: float = 0.15, peak_alpha: float = 0.4):
	"""Quick screen flash — no shader needed, just ColorRect alpha."""
	_overlay.material = null
	_overlay.color = Color(color.r, color.g, color.b, 0.0)
	_overlay.visible = true

	var tween = create_tween()
	tween.tween_property(_overlay, "color:a", peak_alpha, duration * 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "color:a", 0.0, duration * 0.7).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _overlay.visible = false)
	_active_tweens.append(tween)

# ============================================================================
# CLEANUP
# ============================================================================

func clear():
	"""Remove the screen shader and hide the overlay."""
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()

	_overlay.visible = false
	_overlay.material = null
	_material = null

func is_active() -> bool:
	return _overlay.visible and _material != null
