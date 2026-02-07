# shader_animator.gd
# Manages temporary shader effects applied to existing CanvasItem nodes.
#
# Supports two application modes:
#   STACK — chains effect shader via next_pass (preserves existing affix shaders)
#   REPLACE — swaps the material entirely (simpler, needed for dissolve/morph effects)
#
# Usage:
#   var handle = shader_animator.apply(die_visual, flash_shader, {"intensity": 0.0})
#   shader_animator.animate_param(handle, "intensity", 0.0, 1.0, 0.2)
#   await get_tree().create_timer(0.5).timeout
#   shader_animator.restore(handle)
extends Node
class_name ShaderAnimator

# ============================================================================
# APPLICATION MODE
# ============================================================================
enum ApplyMode {
	STACK,    ## Chain via next_pass — preserves existing materials
	REPLACE,  ## Swap material entirely — needed for full-surface effects
}

# ============================================================================
# INTERNAL STATE
# ============================================================================

class _EffectState:
	var handle: int
	var target: CanvasItem
	var original_material: Material
	var effect_material: ShaderMaterial
	var mode: ApplyMode
	var is_active: bool = true
	## For STACK mode: the material whose next_pass we appended to
	var stack_parent_material: ShaderMaterial = null

var _active_effects: Dictionary = {}  # handle_id → _EffectState
var _next_handle: int = 0
var _active_tweens: Array[Tween] = []

# ============================================================================
# APPLICATION
# ============================================================================

func apply(target: CanvasItem, shader: Shader, initial_params: Dictionary = {},
			mode: ApplyMode = ApplyMode.STACK) -> int:
	"""Apply a temporary shader to a CanvasItem.

	Args:
		target: The node to apply the shader to.
		shader: The shader to apply.
		initial_params: Dictionary of uniform_name → value to set immediately.
		mode: STACK to chain via next_pass, REPLACE to swap material.

	Returns:
		Handle ID for later animation/restoration.
	"""
	var handle = _next_handle
	_next_handle += 1

	var state = _EffectState.new()
	state.handle = handle
	state.target = target
	state.original_material = target.material
	state.mode = mode

	# Create the effect material
	state.effect_material = ShaderMaterial.new()
	state.effect_material.shader = shader
	for key in initial_params:
		state.effect_material.set_shader_parameter(key, initial_params[key])

	# Apply based on mode
	match mode:
		ApplyMode.STACK:
			_apply_stacked(state)
		ApplyMode.REPLACE:
			target.material = state.effect_material

	_active_effects[handle] = state
	return handle

func _apply_stacked(state: _EffectState):
	"""Chain the effect shader via next_pass on the existing material."""
	var target = state.target

	if target.material and target.material is ShaderMaterial:
		# Walk to the end of the next_pass chain
		var current = target.material as ShaderMaterial
		while current.next_pass and current.next_pass is ShaderMaterial:
			current = current.next_pass as ShaderMaterial
		current.next_pass = state.effect_material
		state.stack_parent_material = current
	else:
		# No existing ShaderMaterial — apply directly (effectively REPLACE)
		state.mode = ApplyMode.REPLACE
		target.material = state.effect_material

# ============================================================================
# PARAMETER ANIMATION
# ============================================================================

func animate_param(handle: int, param_name: String, from_val: Variant,
					to_val: Variant, duration: float,
					ease: Tween.EaseType = Tween.EASE_IN_OUT,
					trans: Tween.TransitionType = Tween.TRANS_LINEAR,
					delay_sec: float = 0.0) -> Tween:
	"""Animate a single shader parameter on an active effect.

	Returns the Tween for chaining/awaiting, or null if handle is invalid.
	"""
	var state = _active_effects.get(handle)
	if not state or not state.is_active:
		return null

	var mat = state.effect_material
	var tween = create_tween()

	if delay_sec > 0.0:
		tween.tween_interval(delay_sec)

	tween.tween_method(
		func(val): mat.set_shader_parameter(param_name, val),
		from_val, to_val, duration
	).set_ease(ease).set_trans(trans)

	_active_tweens.append(tween)
	return tween

func play_animations(handle: int, animations: Array[ShaderParamAnimation]) -> void:
	"""Play multiple ShaderParamAnimation resources simultaneously."""
	for anim in animations:
		animate_param(handle, anim.param_name, anim.get_start(), anim.get_end(),
					anim.duration, anim.ease_type, anim.trans_type, anim.delay)

func set_param(handle: int, param_name: String, value: Variant):
	"""Immediately set a shader parameter (no animation)."""
	var state = _active_effects.get(handle)
	if state and state.is_active:
		state.effect_material.set_shader_parameter(param_name, value)

# ============================================================================
# RESTORATION
# ============================================================================

func restore(handle: int) -> void:
	"""Remove the effect shader and restore the original material."""
	var state = _active_effects.get(handle)
	if not state:
		return

	state.is_active = false

	if is_instance_valid(state.target):
		match state.mode:
			ApplyMode.STACK:
				_restore_stacked(state)
			ApplyMode.REPLACE:
				state.target.material = state.original_material

	_active_effects.erase(handle)

func _restore_stacked(state: _EffectState):
	"""Remove effect material from the next_pass chain."""
	if state.stack_parent_material and is_instance_valid(state.target):
		# Remove our material from the chain, preserving anything after it
		if state.stack_parent_material.next_pass == state.effect_material:
			state.stack_parent_material.next_pass = state.effect_material.next_pass
		else:
			# Walk the chain to find and remove it
			var current = state.stack_parent_material
			while current.next_pass:
				if current.next_pass == state.effect_material:
					current.next_pass = state.effect_material.next_pass
					break
				if current.next_pass is ShaderMaterial:
					current = current.next_pass as ShaderMaterial
				else:
					break
	else:
		# Fell back to REPLACE mode during apply
		state.target.material = state.original_material

func restore_all() -> void:
	"""Restore all active effects."""
	for handle in _active_effects.keys():
		restore(handle)

# ============================================================================
# CLEANUP
# ============================================================================

func kill_tweens():
	"""Kill all active parameter tweens."""
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()

func cleanup():
	"""Kill tweens and restore all effects."""
	kill_tweens()
	restore_all()

# ============================================================================
# QUERY
# ============================================================================

func get_material(handle: int) -> ShaderMaterial:
	"""Get the ShaderMaterial for an active handle (for direct manipulation)."""
	var state = _active_effects.get(handle)
	if state and state.is_active:
		return state.effect_material
	return null

func is_active(handle: int) -> bool:
	var state = _active_effects.get(handle)
	return state != null and state.is_active

func get_active_count() -> int:
	return _active_effects.size()
