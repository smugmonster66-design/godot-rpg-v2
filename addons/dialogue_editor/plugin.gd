@tool
extends EditorPlugin

const DialogueEditorDock = preload("res://addons/dialogue_editor/dialogue_editor_dock.tscn")

var _dock_instance: Control = null

func _enter_tree() -> void:
	_dock_instance = DialogueEditorDock.instantiate()
	add_control_to_bottom_panel(_dock_instance, "Dialogue Editor")
	print("[DialogueEditor] Plugin enabled")

func _exit_tree() -> void:
	if _dock_instance:
		remove_control_from_bottom_panel(_dock_instance)
		_dock_instance.queue_free()
		_dock_instance = null
	print("[DialogueEditor] Plugin disabled")

func _has_main_screen() -> bool:
	return false

func _get_plugin_name() -> String:
	return "Dialogue Editor"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Dialogue", "EditorIcons")
