@tool
extends Control
class_name DialogueEditorDock

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var graph_edit: DialogueGraphEdit = %DialogueGraphEdit
@onready var speakers_panel: Control = %SpeakersPanel
@onready var preview_panel: Control = %PreviewPanel
@onready var validation_panel: Control = %ValidationPanel
@onready var file_menu: MenuButton = %FileMenu
@onready var edit_menu: MenuButton = %EditMenu
@onready var add_menu: MenuButton = %AddMenu
@onready var current_file_label: Label = %CurrentFileLabel
@onready var right_tabs: TabContainer = %RightTabs

# ============================================================================
# STATE
# ============================================================================
var current_file_path: String = ""
var is_dirty: bool = false

# ============================================================================
# MENU IDS
# ============================================================================
enum FileMenuID {
	NEW,
	OPEN,
	SAVE,
	SAVE_AS,
	EXPORT_TEST,
}

enum EditMenuID {
	UNDO,
	REDO,
	DELETE_SELECTED,
	SELECT_ALL,
	VALIDATE,
}

enum AddMenuID {
	LINE,
	CHOICE,
	CONDITION,
	SET_FLAG,
	END,
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_setup_menus()
	_connect_signals()
	_new_dialogue()
	print("[DialogueEditor] Dock ready")

func _setup_menus() -> void:
	# File menu
	var file_popup = file_menu.get_popup()
	file_popup.clear()
	file_popup.add_item("New", FileMenuID.NEW)
	file_popup.add_item("Open...", FileMenuID.OPEN)
	file_popup.add_separator()
	file_popup.add_item("Save", FileMenuID.SAVE)
	file_popup.add_item("Save As...", FileMenuID.SAVE_AS)
	file_popup.add_separator()
	file_popup.add_item("Export Test Script", FileMenuID.EXPORT_TEST)
	file_popup.id_pressed.connect(_on_file_menu_pressed)
	
	# Edit menu
	var edit_popup = edit_menu.get_popup()
	edit_popup.clear()
	edit_popup.add_item("Undo", EditMenuID.UNDO)
	edit_popup.add_item("Redo", EditMenuID.REDO)
	edit_popup.add_separator()
	edit_popup.add_item("Delete Selected", EditMenuID.DELETE_SELECTED)
	edit_popup.add_item("Select All", EditMenuID.SELECT_ALL)
	edit_popup.add_separator()
	edit_popup.add_item("Validate", EditMenuID.VALIDATE)
	edit_popup.id_pressed.connect(_on_edit_menu_pressed)
	
	# Add node menu
	var add_popup = add_menu.get_popup()
	add_popup.clear()
	add_popup.add_item("Line Node", AddMenuID.LINE)
	add_popup.add_item("Choice Node", AddMenuID.CHOICE)
	add_popup.add_separator()
	add_popup.add_item("Condition Node", AddMenuID.CONDITION)
	add_popup.add_item("Set Flag Node", AddMenuID.SET_FLAG)
	add_popup.add_separator()
	add_popup.add_item("End Node", AddMenuID.END)
	add_popup.id_pressed.connect(_on_add_menu_pressed)

func _connect_signals() -> void:
	if graph_edit:
		graph_edit.modified.connect(_on_graph_modified)
		graph_edit.dialogue_node_selected.connect(_on_node_selected)
	
	if speakers_panel:
		speakers_panel.speaker_selected.connect(_on_speaker_selected)
		speakers_panel.speakers_changed.connect(_on_speakers_changed)
	
	if preview_panel:
		preview_panel.set_graph(graph_edit)
	
	if validation_panel:
		validation_panel.set_graph(graph_edit)
		validation_panel.issue_selected.connect(_on_issue_selected)

# ============================================================================
# FILE OPERATIONS
# ============================================================================

func _new_dialogue() -> void:
	if is_dirty:
		# TODO: Show confirmation dialog
		pass
	
	current_file_path = ""
	is_dirty = false
	_update_title()
	
	if graph_edit:
		graph_edit.clear_graph()
		graph_edit.add_start_node()
	
	if speakers_panel:
		speakers_panel.clear_speakers()
	
	_sync_speakers()

func _open_dialogue() -> void:
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Dialogue Encounter")
	dialog.file_selected.connect(_on_file_selected_open)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)

func _save_dialogue() -> void:
	if current_file_path == "":
		_save_dialogue_as()
		return
	
	# Validate first
	if validation_panel:
		validation_panel.validate()
		if validation_panel.has_errors():
			push_warning("[DialogueEditor] Saving with errors - check validation panel")
	
	_do_save(current_file_path)

func _save_dialogue_as() -> void:
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Dialogue Encounter")
	dialog.current_path = "res://resources/dialogues/"
	dialog.file_selected.connect(_on_file_selected_save)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)

func _do_save(path: String) -> void:
	var serializer = preload("res://addons/dialogue_editor/io/dialogue_serializer.gd").new()
	var encounter = serializer.serialize(graph_edit, speakers_panel.get_speakers())
	
	var error = ResourceSaver.save(encounter, path)
	if error == OK:
		current_file_path = path
		is_dirty = false
		_update_title()
		print("[DialogueEditor] Saved: ", path)
	else:
		push_error("[DialogueEditor] Failed to save: ", path)

func _do_load(path: String) -> void:
	var encounter = load(path) as DialogueEncounter
	if not encounter:
		push_error("[DialogueEditor] Failed to load: ", path)
		return
	
	var deserializer = preload("res://addons/dialogue_editor/io/dialogue_deserializer.gd").new()
	deserializer.deserialize(encounter, graph_edit, speakers_panel)
	
	current_file_path = path
	is_dirty = false
	_update_title()
	_sync_speakers()
	print("[DialogueEditor] Loaded: ", path)

func _update_title() -> void:
	var title = "Untitled"
	if current_file_path != "":
		title = current_file_path.get_file()
	if is_dirty:
		title += " *"
	current_file_label.text = title

# ============================================================================
# SPEAKER SYNC
# ============================================================================

func _sync_speakers() -> void:
	"""Sync speakers to all panels that need them."""
	var speakers = speakers_panel.get_speakers() if speakers_panel else []
	
	if graph_edit:
		graph_edit.set_available_speakers(speakers)
	
	if preview_panel:
		preview_panel.set_speakers(speakers)
	
	if validation_panel:
		validation_panel.set_speakers(speakers)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_file_menu_pressed(id: int) -> void:
	match id:
		FileMenuID.NEW:
			_new_dialogue()
		FileMenuID.OPEN:
			_open_dialogue()
		FileMenuID.SAVE:
			_save_dialogue()
		FileMenuID.SAVE_AS:
			_save_dialogue_as()
		FileMenuID.EXPORT_TEST:
			_export_test_script()

func _on_edit_menu_pressed(id: int) -> void:
	match id:
		EditMenuID.DELETE_SELECTED:
			if graph_edit:
				graph_edit.delete_selected_nodes()
		EditMenuID.SELECT_ALL:
			if graph_edit:
				graph_edit.select_all_nodes()
		EditMenuID.VALIDATE:
			if validation_panel:
				validation_panel.validate()
				# Switch to validation tab
				if right_tabs:
					right_tabs.current_tab = 1  # Validation tab

func _on_add_menu_pressed(id: int) -> void:
	if not graph_edit:
		return
	
	match id:
		AddMenuID.LINE:
			graph_edit.add_line_node()
		AddMenuID.CHOICE:
			graph_edit.add_choice_node()
		AddMenuID.CONDITION:
			graph_edit.add_condition_node()
		AddMenuID.SET_FLAG:
			graph_edit.add_set_flag_node()
		AddMenuID.END:
			graph_edit.add_end_node()

func _on_file_selected_open(path: String) -> void:
	_do_load(path)

func _on_file_selected_save(path: String) -> void:
	_do_save(path)

func _on_graph_modified() -> void:
	is_dirty = true
	_update_title()

func _on_node_selected(node: GraphNode) -> void:
	# Update preview
	if preview_panel:
		preview_panel.preview_node(node)

func _on_speaker_selected(speaker: DialogueSpeaker) -> void:
	pass

func _on_speakers_changed() -> void:
	_sync_speakers()
	is_dirty = true
	_update_title()

func _on_issue_selected(node: GraphNode) -> void:
	# When an issue is clicked, select and focus the node
	if graph_edit and node:
		# Center view on node
		graph_edit.scroll_offset = node.position_offset - graph_edit.size / 2

# ============================================================================
# TEST EXPORT
# ============================================================================

func _export_test_script() -> void:
	print("[DialogueEditor] Export test not yet implemented")
