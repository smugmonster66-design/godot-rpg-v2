# res://scripts/effects/shader_effect.gd
# Applies a temporary shader effect to a target node
extends CombatEffectBase
class_name ShaderEffect

@export_group("Shader")
@export var shader: Shader

@export_group("Flash Parameters")
@export var flash_color: Color = Color(1, 1, 1, 1)
@export_range(0.0, 1.0) var flash_intensity: float = 0.8
@export var preserve_alpha: bool = true
@export var additive_mode: bool = false

@export_group("Timing")
@export var fade_in: float = 0.05
@export var fade_out: float = 0.15

var target_node: CanvasItem
var original_material: Material

func setup(target: CanvasItem):
	"""Set the target node to apply the shader to"""
	target_node = target
	if target_node:
		original_material = target_node.material

func play():
	if not target_node:
		print("⚠️ ShaderEffect: No target node set")
		_on_finished()
		return
	
	if not shader:
		print("⚠️ ShaderEffect: No shader assigned")
		_on_finished()
		return
	
	effect_started.emit()
	
	# Create and apply shader material
	var mat = ShaderMaterial.new()
	mat.shader = shader
	
	# Set parameters from exported fields
	mat.set_shader_parameter("flash_color", flash_color)
	mat.set_shader_parameter("flash_intensity", 0.0)  # Start at 0
	mat.set_shader_parameter("preserve_alpha", preserve_alpha)
	mat.set_shader_parameter("additive_mode", additive_mode)
	
	target_node.material = mat
	
	# Animate flash_intensity: 0 → peak → 0
	var tween = create_tween()
	tween.tween_method(
		func(val): mat.set_shader_parameter("flash_intensity", val),
		0.0,
		flash_intensity,
		fade_in
	)
	tween.tween_method(
		func(val): mat.set_shader_parameter("flash_intensity", val),
		flash_intensity,
		0.0,
		fade_out
	)
	await tween.finished
	
	# Restore original material
	target_node.material = original_material
	_on_finished()
