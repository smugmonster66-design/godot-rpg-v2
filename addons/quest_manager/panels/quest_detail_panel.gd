@tool
extends PanelContainer

## Emitted when any quest-level field changes.
signal quest_modified()
## Emitted when an objective's fields change.
signal objective_modified(index: int)
## Emitted when user clicks "Back to Quest" from objective view.
signal back_to_quest_requested()

const NPC_ROOT := "res://resources/npcs/"
const LOCATION_ROOTS: Array[String] = [
	"res://resources/definitions/locations/",
	"res://resources/maps/",
]

const QUEST_TYPE_NAMES = ["MAIN", "SIDE", "COMPANION", "BOUNTY", "COLLECTION", "EXPLORATION", "HIDDEN"]
const OBJECTIVE_TYPE_NAMES = ["TALK_TO", "KILL", "COLLECT", "VISIT", "DELIVER", "INTERACT", "ESCORT", "SURVIVE", "CUSTOM"]

# ============================================================================
# ONREADY — Quest detail
# ============================================================================
@onready var no_selection_label: Label = %NoSelectionLabel
@onready var quest_detail_container: VBoxContainer = %QuestDetailContainer
@onready var objective_detail_container: VBoxContainer = %ObjectiveDetailContainer

# Identity
@onready var quest_id_edit: LineEdit = %QuestIdEdit
@onready var display_name_edit: LineEdit = %DisplayNameEdit
@onready var quest_type_dropdown: OptionButton = %QuestTypeDropdown

# Description
@onready var summary_edit: TextEdit = %SummaryEdit
@onready var description_edit: TextEdit = %DescriptionEdit

# Quest Giver
@onready var quest_giver_dropdown: OptionButton = %QuestGiverDropdown
@onready var quest_giver_location_dropdown: OptionButton = %QuestGiverLocationDropdown
@onready var turn_in_npc_dropdown: OptionButton = %TurnInNpcDropdown
@onready var turn_in_location_dropdown: OptionButton = %TurnInLocationDropdown

# Prerequisites
@onready var required_level_spin: SpinBox = %RequiredLevelSpin
@onready var recommended_level_spin: SpinBox = %RecommendedLevelSpin
@onready var sort_priority_spin: SpinBox = %SortPrioritySpin
@onready var prerequisites_widget = %PrerequisitesWidget

# Flags
@onready var objectives_unordered_check: CheckBox = %ObjectivesUnorderedCheck
@onready var hidden_until_accepted_check: CheckBox = %HiddenUntilAcceptedCheck
@onready var auto_complete_check: CheckBox = %AutoCompleteCheck
@onready var repeatable_check: CheckBox = %RepeatableCheck
@onready var repeat_cooldown_spin: SpinBox = %RepeatCooldownSpin

# Failure
@onready var can_fail_check: CheckBox = %CanFailCheck
@onready var time_limit_spin: SpinBox = %TimeLimitSpin
@onready var fail_condition_widget = %FailConditionWidget

# Rewards / Events
@onready var rewards_widget = %RewardsWidget
@onready var events_widget = %EventsWidget

# Visual
@onready var icon_path_label: Label = %IconPathLabel
@onready var pick_icon_button: Button = %PickIconButton
@onready var clear_icon_button: Button = %ClearIconButton
@onready var marker_icon_path_label: Label = %MarkerIconPathLabel
@onready var pick_marker_icon_button: Button = %PickMarkerIconButton
@onready var clear_marker_icon_button: Button = %ClearMarkerIconButton

# ============================================================================
# ONREADY — Objective detail
# ============================================================================
@onready var back_to_quest_button: Button = %BackToQuestButton
@onready var objective_id_edit: LineEdit = %ObjectiveIdEdit
@onready var obj_description_edit: TextEdit = %ObjDescriptionEdit
@onready var objective_type_dropdown: OptionButton = %ObjectiveTypeDropdown
@onready var target_id_edit: LineEdit = %TargetIdEdit
@onready var required_count_spin: SpinBox = %RequiredCountSpin
@onready var track_tag_edit: LineEdit = %TrackTagEdit
@onready var optional_check: CheckBox = %OptionalCheck
@onready var hidden_until_previous_check: CheckBox = %HiddenUntilPreviousCheck
@onready var notify_on_progress_check: CheckBox = %NotifyOnProgressCheck
@onready var prereq_obj_list: VBoxContainer = %PrereqObjList
@onready var hint_location_edit: LineEdit = %HintLocationEdit
@onready var hint_text_edit: LineEdit = %HintTextEdit

# ============================================================================
# STATE
# ============================================================================
var _quest_resource: Resource = null
var _current_objective: Resource = null
var _current_objective_index: int = -1
var _suppress_signals: bool = false

var _npc_cache: Array = []       # [{id: String, display: String}]
var _location_cache: Array = []  # [{id: String}]

# ============================================================================
# READY
# ============================================================================
func _ready() -> void:
	# --- Quest identity ---
	if quest_id_edit:
		quest_id_edit.text_changed.connect(_on_quest_id_changed)
	if display_name_edit:
		display_name_edit.text_changed.connect(_on_display_name_changed)
	if quest_type_dropdown:
		_populate_quest_type_dropdown()
		quest_type_dropdown.item_selected.connect(_on_quest_type_selected)

	# --- Description ---
	if summary_edit:
		summary_edit.text_changed.connect(_on_summary_changed)
	if description_edit:
		description_edit.text_changed.connect(_on_description_changed)

	# --- Quest giver ---
	if quest_giver_dropdown:
		quest_giver_dropdown.item_selected.connect(_on_quest_giver_selected)
	if quest_giver_location_dropdown:
		quest_giver_location_dropdown.item_selected.connect(_on_quest_giver_location_selected)
	if turn_in_npc_dropdown:
		turn_in_npc_dropdown.item_selected.connect(_on_turn_in_npc_selected)
	if turn_in_location_dropdown:
		turn_in_location_dropdown.item_selected.connect(_on_turn_in_location_selected)

	# --- Prerequisites ---
	if required_level_spin:
		required_level_spin.value_changed.connect(_on_required_level_changed)
	if recommended_level_spin:
		recommended_level_spin.value_changed.connect(_on_recommended_level_changed)
	if sort_priority_spin:
		sort_priority_spin.value_changed.connect(_on_sort_priority_changed)
	if prerequisites_widget:
		prerequisites_widget.condition_changed.connect(_on_prerequisites_changed)

	# --- Flags ---
	if objectives_unordered_check:
		objectives_unordered_check.toggled.connect(_on_objectives_unordered_toggled)
	if hidden_until_accepted_check:
		hidden_until_accepted_check.toggled.connect(_on_hidden_until_accepted_toggled)
	if auto_complete_check:
		auto_complete_check.toggled.connect(_on_auto_complete_toggled)
	if repeatable_check:
		repeatable_check.toggled.connect(_on_repeatable_toggled)
	if repeat_cooldown_spin:
		repeat_cooldown_spin.value_changed.connect(_on_repeat_cooldown_changed)

	# --- Failure ---
	if can_fail_check:
		can_fail_check.toggled.connect(_on_can_fail_toggled)
	if time_limit_spin:
		time_limit_spin.value_changed.connect(_on_time_limit_changed)
	if fail_condition_widget:
		fail_condition_widget.condition_changed.connect(_on_fail_condition_changed)

	# --- Rewards / Events ---
	if rewards_widget:
		rewards_widget.rewards_modified.connect(_on_rewards_modified)
	if events_widget:
		events_widget.events_modified.connect(_on_events_modified)

	# --- Visual ---
	if pick_icon_button:
		pick_icon_button.pressed.connect(_on_pick_icon_pressed)
	if clear_icon_button:
		clear_icon_button.pressed.connect(_on_clear_icon_pressed)
	if pick_marker_icon_button:
		pick_marker_icon_button.pressed.connect(_on_pick_marker_icon_pressed)
	if clear_marker_icon_button:
		clear_marker_icon_button.pressed.connect(_on_clear_marker_icon_pressed)

	# --- Objective detail ---
	if back_to_quest_button:
		back_to_quest_button.pressed.connect(_on_back_to_quest_pressed)
	if objective_id_edit:
		objective_id_edit.text_changed.connect(_on_objective_id_changed)
	if obj_description_edit:
		obj_description_edit.text_changed.connect(_on_obj_description_changed)
	if objective_type_dropdown:
		_populate_objective_type_dropdown()
		objective_type_dropdown.item_selected.connect(_on_objective_type_selected)
	if target_id_edit:
		target_id_edit.text_changed.connect(_on_target_id_changed)
	if required_count_spin:
		required_count_spin.value_changed.connect(_on_required_count_changed)
	if track_tag_edit:
		track_tag_edit.text_changed.connect(_on_track_tag_changed)
	if optional_check:
		optional_check.toggled.connect(_on_optional_toggled)
	if hidden_until_previous_check:
		hidden_until_previous_check.toggled.connect(_on_hidden_until_previous_toggled)
	if notify_on_progress_check:
		notify_on_progress_check.toggled.connect(_on_notify_on_progress_toggled)
	if hint_location_edit:
		hint_location_edit.text_changed.connect(_on_hint_location_changed)
	if hint_text_edit:
		hint_text_edit.text_changed.connect(_on_hint_text_changed)

	_show_no_selection()

# ============================================================================
# PUBLIC API
# ============================================================================

func load_quest(quest_resource: Resource) -> void:
	_quest_resource = quest_resource
	_current_objective = null
	_current_objective_index = -1
	_show_quest_detail()

func load_objective(index: int, objective: Resource) -> void:
	_current_objective_index = index
	_current_objective = objective
	if not objective:
		clear_objective()
		return
	_show_objective_detail()

func clear_objective() -> void:
	_current_objective = null
	_current_objective_index = -1
	if _quest_resource:
		_show_quest_detail()
	else:
		_show_no_selection()

func clear_all() -> void:
	_quest_resource = null
	_current_objective = null
	_current_objective_index = -1
	_show_no_selection()

# ============================================================================
# DISPLAY STATES
# ============================================================================

func _show_no_selection() -> void:
	if no_selection_label:
		no_selection_label.visible = true
		no_selection_label.text = "Select a quest from the browser"
	if quest_detail_container:
		quest_detail_container.visible = false
	if objective_detail_container:
		objective_detail_container.visible = false

func _show_quest_detail() -> void:
	_suppress_signals = true

	if no_selection_label:
		no_selection_label.visible = false
	if objective_detail_container:
		objective_detail_container.visible = false
	if quest_detail_container:
		quest_detail_container.visible = true

	if _quest_resource:
		# Identity
		if quest_id_edit:
			quest_id_edit.text = str(_quest_resource.get("quest_id"))
		if display_name_edit:
			display_name_edit.text = str(_quest_resource.get("display_name"))
		if quest_type_dropdown:
			var qt = _quest_resource.get("quest_type")
			if qt != null:
				quest_type_dropdown.select(int(qt))

		# Description
		if summary_edit:
			summary_edit.text = str(_quest_resource.get("summary")) if _quest_resource.get("summary") != null else ""
		if description_edit:
			description_edit.text = str(_quest_resource.get("description")) if _quest_resource.get("description") != null else ""

		# Quest giver
		_populate_npc_dropdowns()
		_populate_location_dropdowns()

		var giver_id = str(_quest_resource.get("quest_giver_id"))
		_select_dropdown_by_meta(quest_giver_dropdown, giver_id)
		var giver_loc = str(_quest_resource.get("quest_giver_location"))
		_select_dropdown_by_meta(quest_giver_location_dropdown, giver_loc)
		var turn_in_id = str(_quest_resource.get("turn_in_npc_id"))
		_select_dropdown_by_meta(turn_in_npc_dropdown, turn_in_id)
		var turn_in_loc = str(_quest_resource.get("turn_in_location"))
		_select_dropdown_by_meta(turn_in_location_dropdown, turn_in_loc)

		# Prerequisites
		if required_level_spin:
			required_level_spin.value = _quest_resource.get("required_level") if _quest_resource.get("required_level") != null else 0
		if recommended_level_spin:
			recommended_level_spin.value = _quest_resource.get("recommended_level") if _quest_resource.get("recommended_level") != null else 0
		if sort_priority_spin:
			sort_priority_spin.value = _quest_resource.get("sort_priority") if _quest_resource.get("sort_priority") != null else 0
		if prerequisites_widget:
			prerequisites_widget.load_condition(_quest_resource.get("prerequisites"))

		# Flags
		if objectives_unordered_check:
			objectives_unordered_check.button_pressed = _quest_resource.get("objectives_unordered") == true
		if hidden_until_accepted_check:
			hidden_until_accepted_check.button_pressed = _quest_resource.get("hidden_until_accepted") == true
		if auto_complete_check:
			auto_complete_check.button_pressed = _quest_resource.get("auto_complete") == true
		if repeatable_check:
			repeatable_check.button_pressed = _quest_resource.get("repeatable") == true
		if repeat_cooldown_spin:
			repeat_cooldown_spin.value = _quest_resource.get("repeat_cooldown") if _quest_resource.get("repeat_cooldown") != null else 0.0

		# Failure
		if can_fail_check:
			can_fail_check.button_pressed = _quest_resource.get("can_fail") == true
		if time_limit_spin:
			time_limit_spin.value = _quest_resource.get("time_limit") if _quest_resource.get("time_limit") != null else 0.0
		if fail_condition_widget:
			fail_condition_widget.load_condition(_quest_resource.get("fail_condition"))

		# Rewards
		if rewards_widget:
			rewards_widget.load_rewards(_quest_resource.get("rewards"))

		# Events
		if events_widget:
			events_widget.load_events(
				_quest_resource.get("on_accept_events"),
				_quest_resource.get("on_complete_events"),
				_quest_resource.get("on_fail_events")
			)

		# Visual — icon
		var icon = _quest_resource.get("icon")
		if icon and icon.resource_path != "":
			if icon_path_label:
				icon_path_label.text = icon.resource_path.get_file()
		else:
			if icon_path_label:
				icon_path_label.text = "(none)"

		# Visual — marker icon
		var marker = _quest_resource.get("marker_icon")
		if marker and marker.resource_path != "":
			if marker_icon_path_label:
				marker_icon_path_label.text = marker.resource_path.get_file()
		else:
			if marker_icon_path_label:
				marker_icon_path_label.text = "(none)"

	_suppress_signals = false

func _show_objective_detail() -> void:
	_suppress_signals = true

	if no_selection_label:
		no_selection_label.visible = false
	if quest_detail_container:
		quest_detail_container.visible = false
	if objective_detail_container:
		objective_detail_container.visible = true

	if _current_objective:
		# Identity
		if objective_id_edit:
			objective_id_edit.text = str(_current_objective.get("objective_id"))
		if obj_description_edit:
			obj_description_edit.text = str(_current_objective.get("description")) if _current_objective.get("description") != null else ""

		# Details
		if objective_type_dropdown:
			var ot = _current_objective.get("objective_type")
			if ot != null:
				objective_type_dropdown.select(int(ot))
		if target_id_edit:
			target_id_edit.text = str(_current_objective.get("target_id"))
		if required_count_spin:
			required_count_spin.value = _current_objective.get("required_count") if _current_objective.get("required_count") != null else 1
		if track_tag_edit:
			track_tag_edit.text = str(_current_objective.get("track_tag"))

		# Flow
		if optional_check:
			optional_check.button_pressed = _current_objective.get("optional") == true
		if hidden_until_previous_check:
			hidden_until_previous_check.button_pressed = _current_objective.get("hidden_until_previous") == true
		if notify_on_progress_check:
			notify_on_progress_check.button_pressed = _current_objective.get("notify_on_progress") != false  # defaults true

		# Prerequisite objectives
		_build_prereq_objective_checkboxes()

		# Hints
		if hint_location_edit:
			hint_location_edit.text = str(_current_objective.get("hint_location"))
		if hint_text_edit:
			hint_text_edit.text = str(_current_objective.get("hint_text"))

	_suppress_signals = false

# ============================================================================
# DROPDOWN POPULATION
# ============================================================================

func _populate_quest_type_dropdown() -> void:
	if not quest_type_dropdown:
		return
	quest_type_dropdown.clear()
	for type_name in QUEST_TYPE_NAMES:
		quest_type_dropdown.add_item(type_name)

func _populate_objective_type_dropdown() -> void:
	if not objective_type_dropdown:
		return
	objective_type_dropdown.clear()
	for type_name in OBJECTIVE_TYPE_NAMES:
		objective_type_dropdown.add_item(type_name)

func _populate_npc_dropdowns() -> void:
	if _npc_cache.is_empty():
		_scan_npcs(NPC_ROOT)
		_npc_cache.sort_custom(func(a, b): return a.id < b.id)

	_fill_npc_dropdown(quest_giver_dropdown)
	_fill_npc_dropdown(turn_in_npc_dropdown)

func _fill_npc_dropdown(dropdown: OptionButton) -> void:
	if not dropdown:
		return
	dropdown.clear()
	dropdown.add_item("(none)")
	dropdown.set_item_metadata(0, "")
	for entry in _npc_cache:
		var idx = dropdown.item_count
		dropdown.add_item(entry.display)
		dropdown.set_item_metadata(idx, entry.id)

func _scan_npcs(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_npcs(full_path)
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res and _resource_matches_type(res, "NPCDefinition"):
				var npc_id = str(res.get("npc_id"))
				var npc_name = str(res.get("display_name"))
				if npc_name == "":
					npc_name = npc_id
				var display = "%s (%s)" % [npc_name, npc_id]
				# Deduplicate
				var found = false
				for existing in _npc_cache:
					if existing.id == npc_id:
						found = true
						break
				if not found:
					_npc_cache.append({"id": npc_id, "display": display})
		file_name = dir.get_next()
	dir.list_dir_end()

func _populate_location_dropdowns() -> void:
	if _location_cache.is_empty():
		for root_path in LOCATION_ROOTS:
			_scan_locations(root_path)
		_location_cache.sort_custom(func(a, b): return a.id < b.id)

	_fill_location_dropdown(quest_giver_location_dropdown)
	_fill_location_dropdown(turn_in_location_dropdown)

func _fill_location_dropdown(dropdown: OptionButton) -> void:
	if not dropdown:
		return
	dropdown.clear()
	dropdown.add_item("(none)")
	dropdown.set_item_metadata(0, "")
	for entry in _location_cache:
		var idx = dropdown.item_count
		dropdown.add_item(entry.id)
		dropdown.set_item_metadata(idx, entry.id)

func _scan_locations(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_locations(full_path)
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res is LocationNode and res.location_id != &"":
				var lid = String(res.location_id)
				var found = false
				for existing in _location_cache:
					if existing.id == lid:
						found = true
						break
				if not found:
					_location_cache.append({"id": lid})
		file_name = dir.get_next()
	dir.list_dir_end()

# ============================================================================
# PREREQUISITE OBJECTIVE CHECKBOXES
# ============================================================================

func _build_prereq_objective_checkboxes() -> void:
	if not prereq_obj_list:
		return
	# Clear existing
	for child in prereq_obj_list.get_children():
		prereq_obj_list.remove_child(child)
		child.queue_free()

	if not _quest_resource or not _current_objective:
		return

	var objectives = _quest_resource.get("objectives")
	if not objectives:
		return

	var current_id = _current_objective.get("objective_id")
	var prereqs = _current_objective.get("prerequisite_objectives")
	if prereqs == null:
		prereqs = []

	for obj in objectives:
		var obj_id = obj.get("objective_id")
		if obj_id == null or str(obj_id) == "" or obj_id == current_id:
			continue

		var cb = CheckBox.new()
		cb.text = str(obj_id)
		cb.button_pressed = StringName(str(obj_id)) in prereqs
		cb.toggled.connect(_on_prereq_obj_checkbox_toggled.bind(StringName(str(obj_id))))
		prereq_obj_list.add_child(cb)

# ============================================================================
# HELPERS
# ============================================================================

func _resource_matches_type(res: Resource, type_name: String) -> bool:
	var script = res.get_script()
	if script == null:
		return false
	if script.get_global_name() == type_name:
		return true
	var p = script.resource_path as String
	return p.ends_with(type_name.to_snake_case() + ".gd")

func _select_dropdown_by_meta(dropdown: OptionButton, value: String) -> void:
	if not dropdown or value == "":
		return
	for i in dropdown.item_count:
		var meta = dropdown.get_item_metadata(i)
		if meta != null and str(meta) == value:
			dropdown.select(i)
			return

# ============================================================================
# QUEST-LEVEL HANDLERS
# ============================================================================

func _on_quest_id_changed(new_text: String) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("quest_id", StringName(new_text))
		_emit_quest_modified()

func _on_display_name_changed(new_text: String) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("display_name", new_text)
		_emit_quest_modified()

func _on_quest_type_selected(index: int) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("quest_type", index)
		_emit_quest_modified()

func _on_summary_changed() -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("summary", summary_edit.text)
		_emit_quest_modified()

func _on_description_changed() -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("description", description_edit.text)
		_emit_quest_modified()

func _on_quest_giver_selected(index: int) -> void:
	if _quest_resource and not _suppress_signals and quest_giver_dropdown:
		var meta = quest_giver_dropdown.get_item_metadata(index)
		_quest_resource.set("quest_giver_id", StringName(str(meta) if meta != null else ""))
		_emit_quest_modified()

func _on_quest_giver_location_selected(index: int) -> void:
	if _quest_resource and not _suppress_signals and quest_giver_location_dropdown:
		var meta = quest_giver_location_dropdown.get_item_metadata(index)
		_quest_resource.set("quest_giver_location", StringName(str(meta) if meta != null else ""))
		_emit_quest_modified()

func _on_turn_in_npc_selected(index: int) -> void:
	if _quest_resource and not _suppress_signals and turn_in_npc_dropdown:
		var meta = turn_in_npc_dropdown.get_item_metadata(index)
		_quest_resource.set("turn_in_npc_id", StringName(str(meta) if meta != null else ""))
		_emit_quest_modified()

func _on_turn_in_location_selected(index: int) -> void:
	if _quest_resource and not _suppress_signals and turn_in_location_dropdown:
		var meta = turn_in_location_dropdown.get_item_metadata(index)
		_quest_resource.set("turn_in_location", StringName(str(meta) if meta != null else ""))
		_emit_quest_modified()

func _on_required_level_changed(value: float) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("required_level", int(value))
		_emit_quest_modified()

func _on_recommended_level_changed(value: float) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("recommended_level", int(value))
		_emit_quest_modified()

func _on_sort_priority_changed(value: float) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("sort_priority", int(value))
		_emit_quest_modified()

func _on_prerequisites_changed(condition: Resource) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("prerequisites", condition)
		_emit_quest_modified()

func _on_objectives_unordered_toggled(pressed: bool) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("objectives_unordered", pressed)
		_emit_quest_modified()

func _on_hidden_until_accepted_toggled(pressed: bool) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("hidden_until_accepted", pressed)
		_emit_quest_modified()

func _on_auto_complete_toggled(pressed: bool) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("auto_complete", pressed)
		_emit_quest_modified()

func _on_repeatable_toggled(pressed: bool) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("repeatable", pressed)
		_emit_quest_modified()

func _on_repeat_cooldown_changed(value: float) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("repeat_cooldown", value)
		_emit_quest_modified()

func _on_can_fail_toggled(pressed: bool) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("can_fail", pressed)
		_emit_quest_modified()

func _on_time_limit_changed(value: float) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("time_limit", value)
		_emit_quest_modified()

func _on_fail_condition_changed(condition: Resource) -> void:
	if _quest_resource and not _suppress_signals:
		_quest_resource.set("fail_condition", condition)
		_emit_quest_modified()

func _on_rewards_modified() -> void:
	if _quest_resource and not _suppress_signals and rewards_widget:
		_quest_resource.set("rewards", rewards_widget.build_rewards())
		_emit_quest_modified()

func _on_events_modified() -> void:
	if _quest_resource and not _suppress_signals and events_widget:
		_quest_resource.set("on_accept_events", events_widget.get_on_accept_events())
		_quest_resource.set("on_complete_events", events_widget.get_on_complete_events())
		_quest_resource.set("on_fail_events", events_widget.get_on_fail_events())
		_emit_quest_modified()

# --- Visual ---

func _on_pick_icon_pressed() -> void:
	if not _quest_resource:
		return
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.png, *.jpg, *.webp, *.svg", "Images")
	dialog.current_dir = "res://assets/"
	dialog.file_selected.connect(_on_icon_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

func _on_icon_file_selected(path: String) -> void:
	if not _quest_resource:
		return
	var tex = load(path)
	if tex:
		_quest_resource.set("icon", tex)
		if icon_path_label:
			icon_path_label.text = path.get_file()
		_emit_quest_modified()

func _on_clear_icon_pressed() -> void:
	if not _quest_resource:
		return
	_quest_resource.set("icon", null)
	if icon_path_label:
		icon_path_label.text = "(none)"
	_emit_quest_modified()

func _on_pick_marker_icon_pressed() -> void:
	if not _quest_resource:
		return
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.png, *.jpg, *.webp, *.svg", "Images")
	dialog.current_dir = "res://assets/"
	dialog.file_selected.connect(_on_marker_icon_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

func _on_marker_icon_file_selected(path: String) -> void:
	if not _quest_resource:
		return
	var tex = load(path)
	if tex:
		_quest_resource.set("marker_icon", tex)
		if marker_icon_path_label:
			marker_icon_path_label.text = path.get_file()
		_emit_quest_modified()

func _on_clear_marker_icon_pressed() -> void:
	if not _quest_resource:
		return
	_quest_resource.set("marker_icon", null)
	if marker_icon_path_label:
		marker_icon_path_label.text = "(none)"
	_emit_quest_modified()

# ============================================================================
# OBJECTIVE-LEVEL HANDLERS
# ============================================================================

func _on_back_to_quest_pressed() -> void:
	_current_objective = null
	_current_objective_index = -1
	_show_quest_detail()
	back_to_quest_requested.emit()

func _on_objective_id_changed(new_text: String) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("objective_id", StringName(new_text))
		_emit_objective_modified()

func _on_obj_description_changed() -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("description", obj_description_edit.text)
		_emit_objective_modified()

func _on_objective_type_selected(index: int) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("objective_type", index)
		_emit_objective_modified()

func _on_target_id_changed(new_text: String) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("target_id", StringName(new_text))
		_emit_objective_modified()

func _on_required_count_changed(value: float) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("required_count", int(value))
		_emit_objective_modified()

func _on_track_tag_changed(new_text: String) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("track_tag", StringName(new_text))
		_emit_objective_modified()

func _on_optional_toggled(pressed: bool) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("optional", pressed)
		_emit_objective_modified()

func _on_hidden_until_previous_toggled(pressed: bool) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("hidden_until_previous", pressed)
		_emit_objective_modified()

func _on_notify_on_progress_toggled(pressed: bool) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("notify_on_progress", pressed)
		_emit_objective_modified()

func _on_prereq_obj_checkbox_toggled(pressed: bool, obj_id: StringName) -> void:
	if not _current_objective or _suppress_signals:
		return

	var prereqs = _current_objective.get("prerequisite_objectives")
	if prereqs == null:
		prereqs = []

	# Build fresh array to avoid typed array issues
	var new_prereqs: Array[StringName] = []
	for existing in prereqs:
		if existing != obj_id:
			new_prereqs.append(existing)
	if pressed:
		new_prereqs.append(obj_id)

	_current_objective.set("prerequisite_objectives", new_prereqs)
	_emit_objective_modified()

func _on_hint_location_changed(new_text: String) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("hint_location", StringName(new_text))
		_emit_objective_modified()

func _on_hint_text_changed(new_text: String) -> void:
	if _current_objective and not _suppress_signals:
		_current_objective.set("hint_text", new_text)
		_emit_objective_modified()

# ============================================================================
# SIGNAL HELPERS
# ============================================================================

func _emit_quest_modified() -> void:
	if not _suppress_signals:
		quest_modified.emit()

func _emit_objective_modified() -> void:
	if not _suppress_signals:
		objective_modified.emit(_current_objective_index)
