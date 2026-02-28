# res://addons/action_effect_editor/plugin.gd
# Registers the ActionEffect inspector enhancement plugin.
@tool
extends EditorPlugin

var _inspector_plugin: EditorInspectorPlugin = null


func _enter_tree() -> void:
	_inspector_plugin = preload("res://addons/action_effect_editor/action_effect_inspector_plugin.gd").new()
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	if _inspector_plugin:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
