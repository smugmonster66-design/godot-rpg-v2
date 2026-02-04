# res://resources/data/preview_effect.gd
# Visual effect configuration for drag preview dice
extends Resource
class_name PreviewEffect

# Reuse enums from DiceAffix
enum VisualEffectType {
	NONE,
	COLOR_TINT,
	OVERLAY_TEXTURE,
	SHADER,
	BORDER_GLOW,
}

enum ValueEffectType {
	NONE,
	COLOR,
	OUTLINE_COLOR,
	SHADER,
	COLOR_AND_OUTLINE,
}

# ============================================================================
# FILL TEXTURE EFFECTS
# ============================================================================
@export_group("Fill Texture")
@export var fill_effect_type: VisualEffectType = VisualEffectType.NONE
@export var fill_effect_color: Color = Color.WHITE
@export var fill_shader_material: ShaderMaterial = null

# ============================================================================
# STROKE TEXTURE EFFECTS
# ============================================================================
@export_group("Stroke Texture")
@export var stroke_effect_type: VisualEffectType = VisualEffectType.NONE
@export var stroke_effect_color: Color = Color.WHITE
@export var stroke_shader_material: ShaderMaterial = null

# ============================================================================
# VALUE LABEL EFFECTS
# ============================================================================
@export_group("Value Label")
@export var value_effect_type: ValueEffectType = ValueEffectType.NONE
@export var value_text_color: Color = Color.WHITE
@export var value_outline_color: Color = Color.BLACK
@export var value_shader_material: ShaderMaterial = null

# ============================================================================
# PARTICLE EFFECTS
# ============================================================================
@export_group("Particles")
## Particle scene to add to the preview (e.g., mist, sparkles, frost)
@export var particle_scene: PackedScene = null
## Offset from die center for particle emitter
@export var particle_offset: Vector2 = Vector2(62, 62)
## Scale for particle emitter
@export var particle_scale: Vector2 = Vector2.ONE
