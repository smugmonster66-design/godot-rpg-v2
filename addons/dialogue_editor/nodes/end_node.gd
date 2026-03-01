@tool
extends "res://addons/dialogue_editor/nodes/base_dialogue_node.gd"

func _ready() -> void:
	title = "END"
	
	# Visual styling
	add_theme_color_override("title_color", Color(0.8, 0.3, 0.3))
	
	# One input, no outputs
	set_slot(0, true, 0, Color(0.8, 0.3, 0.3), false, 0, Color.WHITE)

func get_node_type() -> String:
	return "end"

func get_node_data() -> Dictionary:
	var data = super.get_node_data()
	return data
