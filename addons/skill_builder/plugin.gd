@tool
extends EditorPlugin

var dock: Control = null

func _enter_tree():
	var script = load("res://addons/skill_builder/skill_builder_dock.gd")
	if not script:
		push_error("SkillBuilder: Could not load dock script")
		return

	dock = Control.new()
	dock.set_script(script)
	dock.name = "SkillBuilder"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree():
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
