@tool
extends "res://addons/dialogue_editor/nodes/base_dialogue_node.gd"

func _ready() -> void:
	title = "START"
	
	# Visual styling
	add_theme_color_override("title_color", Color(0.3, 0.8, 0.3))
	
	# No inputs, one output
	set_slot(0, false, 0, Color.WHITE, true, 0, Color(0.3, 0.8, 0.3))

func get_node_type() -> String:
	return "start"

func get_node_data() -> Dictionary:
	var data = super.get_node_data()
	return data
