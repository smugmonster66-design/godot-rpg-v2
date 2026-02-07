# shader_param_animation.gd
# Defines a single animated shader parameter transition.
# Attach multiple of these to a CombatEffectPreset to drive shader uniforms.
#
# Supports float and Color parameter types.
# For floats: uses start_value → end_value
# For colors: uses start_color → end_color (set is_color = true)
extends Resource
class_name ShaderParamAnimation

# ============================================================================
# PARAMETER IDENTITY
# ============================================================================
## Name of the shader uniform to animate (must match the uniform name in the shader)
@export var param_name: String = ""

# ============================================================================
# FLOAT VALUES (default mode)
# ============================================================================
@export_group("Float")
@export var start_value: float = 0.0
@export var end_value: float = 1.0

# ============================================================================
# COLOR VALUES (when is_color = true)
# ============================================================================
@export_group("Color")
## When true, animate start_color → end_color instead of float values
@export var is_color: bool = false
@export var start_color: Color = Color.WHITE
@export var end_color: Color = Color.WHITE

# ============================================================================
# TIMING
# ============================================================================
@export_group("Timing")
@export_range(0.01, 5.0) var duration: float = 0.3
@export_range(0.0, 5.0) var delay: float = 0.0

# ============================================================================
# EASING
# ============================================================================
@export_group("Easing")
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_LINEAR

# ============================================================================
# HELPERS
# ============================================================================

func get_start() -> Variant:
	return start_color if is_color else start_value

func get_end() -> Variant:
	return end_color if is_color else end_value
