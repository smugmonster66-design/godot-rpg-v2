@tool
extends EditorPlugin

const AffixBuilderDock = preload("res://addons/affix_builder/affix_builder_dock.gd")

var dock: Control = null

func _enter_tree():
	dock = AffixBuilderDock.new()
	dock.name = "AffixBuilder"
	dock.editor_interface = EditorInterface
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree():
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
