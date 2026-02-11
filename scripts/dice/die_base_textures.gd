# res://scripts/dice/die_base_textures.gd
# Maps die sizes to their base fill/stroke textures.
# Drag PNGs into the inspector slots on GameManager.
# Element shader effects are handled separately by ElementVisualConfig.
extends Resource
class_name DieBaseTextures

@export_group("D4")
@export var d4_fill: Texture2D
@export var d4_stroke: Texture2D

@export_group("D6")
@export var d6_fill: Texture2D
@export var d6_stroke: Texture2D

@export_group("D8")
@export var d8_fill: Texture2D
@export var d8_stroke: Texture2D

@export_group("D10")
@export var d10_fill: Texture2D
@export var d10_stroke: Texture2D

@export_group("D12")
@export var d12_fill: Texture2D
@export var d12_stroke: Texture2D

@export_group("D20")
@export var d20_fill: Texture2D
@export var d20_stroke: Texture2D

# ============================================================================
# SINGLETON
# ============================================================================

static var instance: DieBaseTextures

func register():
	instance = self

# ============================================================================
# LOOKUP
# ============================================================================

func get_fill(die_type: DieResource.DieType) -> Texture2D:
	match die_type:
		DieResource.DieType.D4: return d4_fill
		DieResource.DieType.D6: return d6_fill
		DieResource.DieType.D8: return d8_fill
		DieResource.DieType.D10: return d10_fill
		DieResource.DieType.D12: return d12_fill
		DieResource.DieType.D20: return d20_fill
	return null

func get_stroke(die_type: DieResource.DieType) -> Texture2D:
	match die_type:
		DieResource.DieType.D4: return d4_stroke
		DieResource.DieType.D6: return d6_stroke
		DieResource.DieType.D8: return d8_stroke
		DieResource.DieType.D10: return d10_stroke
		DieResource.DieType.D12: return d12_stroke
		DieResource.DieType.D20: return d20_stroke
	return null

func apply_to(die: DieResource):
	"""Apply base textures to a die if it doesn't already have them."""
	if not die.fill_texture:
		die.fill_texture = get_fill(die.die_type)
	if not die.stroke_texture:
		die.stroke_texture = get_stroke(die.die_type)
