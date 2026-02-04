@tool
extends EditorPlugin

var documenter_script: Script

func _enter_tree() -> void:
	documenter_script = load("res://addons/scene_tree_documenter.gd")
	resource_saved.connect(_on_resource_saved)

func _exit_tree() -> void:
	if resource_saved.is_connected(_on_resource_saved):
		resource_saved.disconnect(_on_resource_saved)

func _on_resource_saved(resource: Resource) -> void:
	# Only regenerate when scene files are saved
	if resource is PackedScene:
		var script_instance = documenter_script.new()
		script_instance._run()
