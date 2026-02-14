@tool
extends EditorPlugin

var editor_panel: Control = null

func _enter_tree():
	print("🏰 Dungeon Editor: _enter_tree() called")
	var panel_script = load("res://addons/dungeon_editor/dungeon_definition_editor.gd")
	if not panel_script:
		push_error("🏰 Dungeon Editor: Failed to load dungeon_definition_editor.gd — check for parse errors")
		return
	print("🏰 Dungeon Editor: Script loaded, creating instance...")
	editor_panel = panel_script.new()
	editor_panel.name = "DungeonDefinitionEditor"
	editor_panel.editor_interface = EditorInterface
	print("🏰 Dungeon Editor: Adding to bottom panel...")
	add_control_to_bottom_panel(editor_panel, "Dungeon Editor")
	print("🏰 Dungeon Editor: Ready!")

func _exit_tree():
	print("🏰 Dungeon Editor: _exit_tree()")
	if editor_panel:
		remove_control_from_bottom_panel(editor_panel)
		editor_panel.queue_free()
		editor_panel = null
