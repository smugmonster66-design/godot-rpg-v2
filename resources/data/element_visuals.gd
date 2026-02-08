# res://resources/data/element_visuals.gd
# Single element's visual configuration — fill/stroke/value materials + icon
extends Resource
class_name ElementVisuals

@export var fill_material: ShaderMaterial
@export var stroke_material: ShaderMaterial
@export var value_material: ShaderMaterial
@export var icon: Texture2D
@export var tint_color: Color = Color.WHITE
