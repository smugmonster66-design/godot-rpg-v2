@tool
extends EditorPlugin

const Dock = preload("res://addons/theme_editor/theme_editor_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.name = "ThemeEditor"
	_dock.undo_redo = get_undo_redo()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	print("🎨 Theme Editor plugin loaded")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	print("🎨 Theme Editor plugin unloaded")
