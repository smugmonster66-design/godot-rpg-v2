@tool
extends EditorPlugin

const DockScene = preload("res://addons/companion_builder/companion_builder_dock.tscn")

var _dock_instance: Control = null

func _enter_tree() -> void:
	_dock_instance = DockScene.instantiate()
	add_control_to_bottom_panel(_dock_instance, "Companions")
	if _dock_instance.has_method("set_editor_plugin"):
		_dock_instance.set_editor_plugin(self)
	print("[CompanionBuilder] Plugin enabled")

func _exit_tree() -> void:
	if _dock_instance:
		remove_control_from_bottom_panel(_dock_instance)
		_dock_instance.queue_free()
		_dock_instance = null
	print("[CompanionBuilder] Plugin disabled")

func _has_main_screen() -> bool:
	return false

func _get_plugin_name() -> String:
	return "Companion Builder"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("AnimationPlayer", "EditorIcons")
