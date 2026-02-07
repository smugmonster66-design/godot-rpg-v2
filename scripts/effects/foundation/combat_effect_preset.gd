# combat_effect_preset.gd
# Base preset resource for the combat effect system.
# Holds configuration for the three parallel tracks:
#   - Target shader track (temporary shaders on existing nodes)
#   - Particle shader track (shader overrides for spawned particles)
#   - Screen effect track (full-screen post-processing)
#
# Each effect type (Emanate, Impact, etc.) extends this with type-specific
# parameters in its own preset class.
extends Resource
class_name CombatEffectPreset

# ============================================================================
# TARGET SHADER TRACK
# ============================================================================
@export_group("Target Shader")
## Shader to temporarily apply to the target node(s) during the effect.
## Examples: flash white, distortion pulse, drain tint, dissolve.
@export var target_shader: Shader = null
## Initial uniform values for the target shader.
@export var target_shader_params: Dictionary = {}
## Animated transitions for target shader uniforms.
@export var target_shader_anims: Array[ShaderParamAnimation] = []
## Application mode: STACK chains via next_pass (preserves affix shaders),
## REPLACE swaps material entirely (needed for dissolve/morph effects).
@export_enum("STACK", "REPLACE") var target_shader_mode: int = 0  # 0=STACK, 1=REPLACE

@export_group("Source Shader")
## Optional: also apply a shader to the SOURCE node (e.g., glow on caster).
@export var source_shader: Shader = null
@export var source_shader_params: Dictionary = {}
@export var source_shader_anims: Array[ShaderParamAnimation] = []
@export_enum("STACK", "REPLACE") var source_shader_mode: int = 0

# ============================================================================
# PARTICLE SHADER TRACK
# ============================================================================
@export_group("Particle Shader")
## Override shader for spawned particle nodes. If null, particles inherit
## the source die's shader (existing scatter-converge behavior).
@export var particle_shader_override: Shader = null
## Uniform values for the particle shader override.
@export var particle_shader_params: Dictionary = {}

# ============================================================================
# SCREEN EFFECT TRACK
# ============================================================================
@export_group("Screen Effect")
## Full-screen shader (applied to ColorRect overlay above all gameplay).
## Examples: shockwave ripple, chromatic aberration, vignette pulse.
@export var screen_shader: Shader = null
@export var screen_shader_params: Dictionary = {}
@export var screen_shader_anims: Array[ShaderParamAnimation] = []
## Simple screen flash (no shader needed). Set alpha > 0 to enable.
@export var screen_flash_color: Color = Color(1, 1, 1, 0)
@export_range(0.0, 0.5) var screen_flash_duration: float = 0.0

# ============================================================================
# SOUND
# ============================================================================
@export_group("Sound")
@export var start_sound: AudioStream = null
@export var peak_sound: AudioStream = null
@export var end_sound: AudioStream = null

# ============================================================================
# HELPERS
# ============================================================================

func has_target_shader() -> bool:
	return target_shader != null

func has_source_shader() -> bool:
	return source_shader != null

func has_screen_effect() -> bool:
	return screen_shader != null or screen_flash_color.a > 0.0

func has_particle_shader_override() -> bool:
	return particle_shader_override != null

func get_target_apply_mode() -> int:
	return target_shader_mode

func get_source_apply_mode() -> int:
	return source_shader_mode
