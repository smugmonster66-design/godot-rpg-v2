# res://resources/data/element_visual_config.gd
# Central element visual configuration - fill/stroke/value shader materials + icons
# Access via: GameManager.ELEMENT_VISUALS
extends Resource
class_name ElementVisualConfig

# ============================================================================
# ELEMENT ENTRIES — drag materials into each slot in the inspector
# ============================================================================
@export_group("Physical Elements")
@export var slashing: ElementVisuals
@export var blunt: ElementVisuals
@export var piercing: ElementVisuals

@export_group("Magical Elements")
@export var fire: ElementVisuals
@export var ice: ElementVisuals
@export var shock: ElementVisuals
@export var poison: ElementVisuals
@export var shadow: ElementVisuals

@export_group("Default")
## Fallback visuals when element has no config
@export var default_visuals: ElementVisuals

# ============================================================================
# LOOKUP API
# ============================================================================

func get_visuals(element: ActionEffect.DamageType) -> ElementVisuals:
	var result = _lookup(element)
	return result if result else default_visuals

func get_fill_material(element: ActionEffect.DamageType) -> ShaderMaterial:
	var visuals = get_visuals(element)
	if visuals and visuals.fill_material:
		return visuals.fill_material.duplicate()
	return null

func get_stroke_material(element: ActionEffect.DamageType) -> ShaderMaterial:
	var visuals = get_visuals(element)
	if visuals and visuals.stroke_material:
		return visuals.stroke_material.duplicate()
	return null

func get_value_material(element: ActionEffect.DamageType) -> ShaderMaterial:
	var visuals = get_visuals(element)
	if visuals and visuals.value_material:
		return visuals.value_material.duplicate()
	return null

func get_tint_color(element: ActionEffect.DamageType) -> Color:
	var visuals = get_visuals(element)
	return visuals.tint_color if visuals else Color.WHITE

func get_icon(element: ActionEffect.DamageType) -> Texture2D:
	var visuals = get_visuals(element)
	if visuals and visuals.icon:
		return visuals.icon
	return null

func _lookup(element: ActionEffect.DamageType) -> ElementVisuals:
	match element:
		ActionEffect.DamageType.SLASHING: return slashing
		ActionEffect.DamageType.BLUNT: return blunt
		ActionEffect.DamageType.PIERCING: return piercing
		ActionEffect.DamageType.FIRE: return fire
		ActionEffect.DamageType.ICE: return ice
		ActionEffect.DamageType.SHOCK: return shock
		ActionEffect.DamageType.POISON: return poison
		ActionEffect.DamageType.SHADOW: return shadow
		_: return null
