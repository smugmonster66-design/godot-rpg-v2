@tool
extends Control

@onready var quest_browser: PanelContainer = %QuestBrowserPanel
@onready var objective_list: PanelContainer = %ObjectiveListPanel
@onready var quest_detail: PanelContainer = %QuestDetailPanel
@onready var save_button: Button = %SaveButton
@onready var validate_button: Button = %ValidateButton
@onready var current_quest_label: Label = %CurrentQuestLabel

var _current_quest: Resource = null
var _current_file_path: String = ""
var _is_dirty: bool = false

func _ready() -> void:
	# Connect browser
	if quest_browser:
		quest_browser.quest_selected.connect(_on_quest_selected)
		quest_browser.quest_created.connect(_on_quest_selected)

	# Connect objective list
	if objective_list:
		objective_list.objective_selected.connect(_on_objective_selected)
		objective_list.table_modified.connect(_on_table_modified)

	# Connect detail panel
	if quest_detail:
		quest_detail.quest_modified.connect(_on_quest_modified)
		quest_detail.objective_modified.connect(_on_objective_modified)
		quest_detail.back_to_quest_requested.connect(_on_back_to_quest)

	# Buttons
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if validate_button:
		validate_button.pressed.connect(_on_validate_pressed)

# ============================================================================
# PUBLIC
# ============================================================================

func set_editor_plugin(p: EditorPlugin) -> void:
	"""Called by plugin.gd so we can reference the editor plugin if needed."""
	_editor_plugin = p

var _editor_plugin: EditorPlugin = null

# ============================================================================
# QUEST SELECTION
# ============================================================================

func _on_quest_selected(quest_resource: Resource, file_path: String) -> void:
	if _is_dirty:
		push_warning("[QuestManager] Unsaved changes to %s" % _current_file_path)

	_current_quest = quest_resource
	_current_file_path = file_path
	_is_dirty = false

	_update_title()

	# Load into panels
	if objective_list:
		objective_list.load_quest(quest_resource)
	if quest_detail:
		quest_detail.load_quest(quest_resource)

# ============================================================================
# OBJECTIVE SELECTION
# ============================================================================

func _on_objective_selected(index: int, objective: Resource) -> void:
	if quest_detail:
		quest_detail.load_objective(index, objective)

func _on_objective_modified(index: int) -> void:
	_is_dirty = true
	_update_title()
	if objective_list:
		objective_list.notify_objective_changed(index)

func _on_table_modified() -> void:
	_is_dirty = true
	_update_title()

func _on_quest_modified() -> void:
	_is_dirty = true
	_update_title()

func _on_back_to_quest() -> void:
	if objective_list:
		objective_list.clear_selection()

# ============================================================================
# SAVE
# ============================================================================

func _on_save_pressed() -> void:
	if not _current_quest or _current_file_path == "":
		push_warning("[QuestManager] No quest loaded to save")
		return

	var err = ResourceSaver.save(_current_quest, _current_file_path)
	if err == OK:
		_is_dirty = false
		_update_title()
		print("[QuestManager] Saved: %s" % _current_file_path)
	else:
		push_error("[QuestManager] Failed to save: %s — %s" % [_current_file_path, error_string(err)])

# ============================================================================
# VALIDATION
# ============================================================================

func _on_validate_pressed() -> void:
	if not _current_quest:
		return

	var warnings: Array[String] = []
	var errors: Array[String] = []

	# Quest ID check
	var quest_id = str(_current_quest.get("quest_id"))
	if quest_id == "" or quest_id == "null":
		errors.append("Missing quest_id")

	# Display name
	var display = str(_current_quest.get("display_name"))
	if display == "" or display == "null":
		warnings.append("Missing display_name")

	# Objectives
	var objectives = _current_quest.get("objectives")
	if objectives == null or objectives.size() == 0:
		warnings.append("Quest has no objectives")
		_show_validation_results(errors, warnings)
		return

	var seen_obj_ids: Dictionary = {}
	var all_obj_ids: Array[StringName] = []

	for i in objectives.size():
		var obj = objectives[i]
		var oid = str(obj.get("objective_id"))

		# Collect all objective IDs
		if oid != "" and oid != "null":
			all_obj_ids.append(StringName(oid))

		# Check empty objective_id
		if oid == "" or oid == "null":
			errors.append("Objective %d: missing objective_id" % i)

		# Check duplicate objective_id
		if oid in seen_obj_ids:
			errors.append("Objective %d: duplicate objective_id '%s' (also at %d)" % [i, oid, seen_obj_ids[oid]])
		else:
			seen_obj_ids[oid] = i

		# Check missing target_id
		var target = str(obj.get("target_id"))
		var obj_type = obj.get("objective_type")
		# CUSTOM type (8) may not need a target_id
		if (target == "" or target == "null") and obj_type != 8:
			warnings.append("Objective %d (%s): no target_id set" % [i, oid])

	# Check prerequisite_objectives reference valid IDs
	for i in objectives.size():
		var obj = objectives[i]
		var prereqs = obj.get("prerequisite_objectives")
		if prereqs:
			for prereq_id in prereqs:
				if prereq_id not in all_obj_ids:
					errors.append("Objective %d (%s): prerequisite '%s' does not exist" % [i, str(obj.get("objective_id")), str(prereq_id)])

	# Check rewards
	var rewards = _current_quest.get("rewards")
	if rewards == null:
		warnings.append("No rewards defined")

	# Check quest giver
	var giver = str(_current_quest.get("quest_giver_id"))
	if giver == "" or giver == "null":
		warnings.append("No quest_giver_id set")

	_show_validation_results(errors, warnings)

func _show_validation_results(errors: Array[String], warnings: Array[String]) -> void:
	if errors.is_empty() and warnings.is_empty():
		print("[QuestManager] ✓ Validation passed — no issues found")
		return

	for e in errors:
		push_error("[QuestManager] ✗ %s" % e)
	for w in warnings:
		push_warning("[QuestManager] ⚠ %s" % w)

	print("[QuestManager] Validation: %d error(s), %d warning(s)" % [errors.size(), warnings.size()])

# ============================================================================
# UI HELPERS
# ============================================================================

func _update_title() -> void:
	if not current_quest_label:
		return
	if _current_quest:
		var display = str(_current_quest.get("display_name"))
		var qid = str(_current_quest.get("quest_id"))
		var dirty_marker = " *" if _is_dirty else ""
		current_quest_label.text = "%s (%s)%s" % [display, qid, dirty_marker]
	else:
		current_quest_label.text = ""
