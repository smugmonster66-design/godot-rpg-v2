# res://scripts/dice/die_visual_entry.gd
# Single entry in the DieVisualRegistry.
# Defines textures, tint, and optional shader for a die size + element combo.
extends Resource
class_name DieVisualEntry

## Which die size this entry applies to (D4, D6, etc.)
@export var die_type: DieResource.DieType = DieResource.DieType.D6

## Element ID this entry applies to. -1 = base/default (no element).
## Matches DieResource.element values (e.g. 3 = Fire from your element enum).
@export var element: int = -1

@export_group("Textures")
@export var fill_texture: Texture2D
@export var stroke_texture: Texture2D

@export_group("Visual Modifiers")
@export var color_tint: Color = Color.WHITE
@export var shader_material: ShaderMaterial

func apply_to(die: DieResource):
	"""Apply this entry's visuals to a DieResource."""
	if fill_texture:
		die.fill_texture = fill_texture
	if stroke_texture:
		die.stroke_texture = stroke_texture
