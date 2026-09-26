@tool
extends "res://addons/dialogue_editor/nodes/base_dialogue_node.gd"

# ============================================================================
# CONSTANTS
# ============================================================================
const QUEST_ROOT := "res://resources/definitions/quests/"

# ============================================================================
# CONDITION TYPES
# ============================================================================
enum ConditionType {
	FLAG,               # 0 — Check a story flag
	COUNTER,            # 1 — Compare a counter value
	RELATIONSHIP,       # 2 — Compare NPC relationship value
	HAS_ITEM,           # 3 — Check player inventory
	PLAYER_LEVEL,       # 4 — Compare player level
	CLASS_LEVEL,        # 5 — Compare class level
	QUEST_STATE,        # 6 — Check quest status
	QUEST_OBJECTIVE,    # 7 — Check objective completion or progress
	LOCATION_VISITED,   # 8 — Check if location was visited
	APPROVAL,           # 9 — Compare hidden NPC approval value
}

# Objective check modes for QUEST_OBJECTIVE type
enum ObjectiveCheckMode {
	IS_COMPLETE,        # 0 — Objective is complete
	IS_NOT_COMPLETE,    # 1 — Objective is not complete
	PROGRESS_GTE,       # 2 — Progress >= value
	PROGRESS_LT,        # 3 — Progress < value
	PROGRESS_EQ,        # 4 — Progress == value
}

const OPERATOR_OPTIONS: Array[String] = ["==", "!=", ">", "<", ">=", "<="]
const QUEST_STATE_OPTIONS: Array[String] = ["locked", "available", "active", "ready", "complete", "failed"]

const OBJECTIVE_CHECK_LABELS: Array[String] = [
	"Is Complete",
	"Is Not Complete",
	"Progress >=",
	"Progress <",
	"Progress ==",
]

# Per-type expected value labels for the ExpectedRow dropdown
const BOOL_LABELS: Dictionary = {
	ConditionType.FLAG: ["Set", "Not Set"],
	ConditionType.LOCATION_VISITED: ["Visited", "Not Visited"],
	ConditionType.HAS_ITEM: ["Has Item", "Does Not Have"],
}

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var type_dropdown: OptionButton = $VBox/TypeRow/TypeDropdown
@onready var flag_row: HBoxContainer = $VBox/FlagRow
@onready var flag_label: Label = $VBox/FlagRow/FlagLabel
@onready var flag_edit: LineEdit = $VBox/FlagRow/FlagEdit
@onready var operator_row: HBoxContainer = $VBox/OperatorRow
@onready var operator_dropdown: OptionButton = $VBox/OperatorRow/OperatorDropdown
@onready var value_row: HBoxContainer = $VBox/ValueRow
@onready var value_spin: SpinBox = $VBox/ValueRow/ValueSpin
@onready var expected_row: HBoxContainer = $VBox/ExpectedRow
@onready var expected_dropdown: OptionButton = $VBox/ExpectedRow/ExpectedDropdown
@onready var quest_state_row: HBoxContainer = $VBox/QuestStateRow
@onready var quest_state_dropdown: OptionButton = $VBox/QuestStateRow/QuestStateDropdown
@onready var class_id_row: HBoxContainer = $VBox/ClassIdRow
@onready var class_id_edit: LineEdit = $VBox/ClassIdRow/ClassIdEdit
@onready var quest_dropdown_row: HBoxContainer = $VBox/QuestDropdownRow
@onready var quest_dropdown: OptionButton = $VBox/QuestDropdownRow/QuestDropdown
@onready var objective_row: HBoxContainer = $VBox/ObjectiveRow
@onready var objective_dropdown: OptionButton = $VBox/ObjectiveRow/ObjectiveDropdown

# ============================================================================
# STATE
# ============================================================================
var condition_type: ConditionType = ConditionType.FLAG
var flag_name: String = ""
var compare_value: int = 0
var compare_operator: String = ">="
var expected_bool: bool = true          # true = Set/Visited/Has Item, false = Not Set/Not Visited/Doesn't Have
var quest_state_value: String = "complete"
var class_id: String = ""
var objective_id: String = ""
var objective_check_mode: int = ObjectiveCheckMode.IS_COMPLETE

## Cached scan results — avoids re-scanning on every UI update.
var _scan_cache: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	title = "CONDITION"

	# Visual styling
	add_theme_color_override("title_color", Color(0.7, 0.5, 0.9))

	# One input, two outputs (true/false)
	set_slot(0, true, 0, Color(0.7, 0.5, 0.9), false, 0, Color.WHITE)
	set_slot(1, false, 0, Color.WHITE, true, 0, Color(0.3, 0.8, 0.3))  # True output (green)
	set_slot(2, false, 0, Color.WHITE, true, 0, Color(0.8, 0.3, 0.3))  # False output (red)

	# Populate type dropdown
	if type_dropdown:
		type_dropdown.clear()
		type_dropdown.add_item("Flag", ConditionType.FLAG)
		type_dropdown.add_item("Counter", ConditionType.COUNTER)
		type_dropdown.add_item("Relationship", ConditionType.RELATIONSHIP)
		type_dropdown.add_item("Has Item", ConditionType.HAS_ITEM)
		type_dropdown.add_item("Player Level", ConditionType.PLAYER_LEVEL)
		type_dropdown.add_item("Class Level", ConditionType.CLASS_LEVEL)
		type_dropdown.add_item("Quest State", ConditionType.QUEST_STATE)
		type_dropdown.add_item("Quest Objective", ConditionType.QUEST_OBJECTIVE)
		type_dropdown.add_item("Location Visited", ConditionType.LOCATION_VISITED)
		type_dropdown.add_item("Approval", ConditionType.APPROVAL)
		type_dropdown.item_selected.connect(_on_type_selected)

	# Populate operator dropdown
	if operator_dropdown:
		operator_dropdown.clear()
		for op in OPERATOR_OPTIONS:
			operator_dropdown.add_item(op)
		operator_dropdown.item_selected.connect(_on_operator_selected)

	# Populate quest state dropdown
	if quest_state_dropdown:
		quest_state_dropdown.clear()
		for state in QUEST_STATE_OPTIONS:
			quest_state_dropdown.add_item(state)
		quest_state_dropdown.item_selected.connect(_on_quest_state_selected)

	if flag_edit:
		flag_edit.text_changed.connect(_on_flag_changed)
	if value_spin:
		value_spin.value_changed.connect(_on_value_changed)
	if class_id_edit:
		class_id_edit.text_changed.connect(_on_class_id_changed)

	# Resolve refs that @onready may miss in @tool context
	_resolve_refs()

	if expected_dropdown:
		expected_dropdown.item_selected.connect(_on_expected_selected)
	if quest_dropdown:
		quest_dropdown.item_selected.connect(_on_quest_dropdown_selected)
	if objective_dropdown:
		objective_dropdown.item_selected.connect(_on_objective_dropdown_selected)

	call_deferred("_update_ui_for_type")

# ============================================================================
# REF RESOLUTION (@tool safety)
# ============================================================================

func _resolve_refs() -> void:
	if expected_row == null:
		expected_row = get_node_or_null("VBox/ExpectedRow")
	if expected_dropdown == null:
		expected_dropdown = get_node_or_null("VBox/ExpectedRow/ExpectedDropdown")
	if quest_dropdown_row == null:
		quest_dropdown_row = get_node_or_null("VBox/QuestDropdownRow")
	if quest_dropdown == null:
		quest_dropdown = get_node_or_null("VBox/QuestDropdownRow/QuestDropdown")
	if objective_row == null:
		objective_row = get_node_or_null("VBox/ObjectiveRow")
	if objective_dropdown == null:
		objective_dropdown = get_node_or_null("VBox/ObjectiveRow/ObjectiveDropdown")

# ============================================================================
# UI HANDLERS
# ============================================================================

func _on_type_selected(index: int) -> void:
	condition_type = index as ConditionType
	# Reset state when switching types
	flag_name = ""
	objective_id = ""
	expected_bool = true
	compare_operator = ">="
	compare_value = 0
	objective_check_mode = ObjectiveCheckMode.IS_COMPLETE
	_update_ui_for_type()
	_emit_modified()

func _on_flag_changed(new_text: String) -> void:
	flag_name = new_text
	_emit_modified()

func _on_value_changed(new_value: float) -> void:
	compare_value = int(new_value)
	_emit_modified()

func _on_operator_selected(index: int) -> void:
	if index >= 0 and index < OPERATOR_OPTIONS.size():
		compare_operator = OPERATOR_OPTIONS[index]
	_emit_modified()

func _on_expected_selected(index: int) -> void:
	if condition_type == ConditionType.QUEST_OBJECTIVE:
		# Objective check mode dropdown
		objective_check_mode = index
		# Show/hide value row based on whether progress mode is selected
		var is_progress = objective_check_mode >= ObjectiveCheckMode.PROGRESS_GTE
		if value_row:
			value_row.visible = is_progress
		_emit_modified()
	else:
		# Boolean check (Set/Not Set, Visited/Not Visited, etc.)
		expected_bool = (index == 0)  # 0 = true option, 1 = false option
		_emit_modified()

func _on_quest_state_selected(index: int) -> void:
	if index >= 0 and index < QUEST_STATE_OPTIONS.size():
		quest_state_value = QUEST_STATE_OPTIONS[index]
	_emit_modified()

func _on_class_id_changed(new_text: String) -> void:
	class_id = new_text
	_emit_modified()

func _on_quest_dropdown_selected(index: int) -> void:
	if quest_dropdown and index >= 0:
		var meta = quest_dropdown.get_item_metadata(index)
		var value: String = str(meta) if meta != null and str(meta) != "" else quest_dropdown.get_item_text(index)
		flag_name = value

		if condition_type == ConditionType.QUEST_OBJECTIVE:
			_populate_objective_dropdown_for_quest(value)
		_emit_modified()

func _on_objective_dropdown_selected(index: int) -> void:
	if objective_dropdown and index >= 0:
		var meta = objective_dropdown.get_item_metadata(index)
		objective_id = str(meta) if meta != null and str(meta) != "" else objective_dropdown.get_item_text(index)
		_emit_modified()

func _update_ui_for_type() -> void:
	_resolve_refs()
	# Defaults: hide everything optional
	if flag_row: flag_row.visible = false
	if operator_row: operator_row.visible = false
	if value_row: value_row.visible = false
	if expected_row: expected_row.visible = false
	if quest_state_row: quest_state_row.visible = false
	if class_id_row: class_id_row.visible = false
	if quest_dropdown_row: quest_dropdown_row.visible = false
	if objective_row: objective_row.visible = false

	match condition_type:
		ConditionType.FLAG:
			_show_flag_row("Flag Name:", "flag_name")
			_show_expected_dropdown(ConditionType.FLAG)

		ConditionType.COUNTER:
			_show_flag_row("Counter:", "counter_name")
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true

		ConditionType.RELATIONSHIP:
			_show_flag_row("NPC ID:", "npc_id")
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true

		ConditionType.HAS_ITEM:
			_show_flag_row("Item ID:", "item_id")
			_show_expected_dropdown(ConditionType.HAS_ITEM)
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true

		ConditionType.PLAYER_LEVEL:
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true

		ConditionType.CLASS_LEVEL:
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true
			if class_id_row: class_id_row.visible = true

		ConditionType.QUEST_STATE:
			_show_quest_dropdown()
			if quest_state_row: quest_state_row.visible = true

		ConditionType.QUEST_OBJECTIVE:
			_show_quest_objective_ui()

		ConditionType.LOCATION_VISITED:
			_show_flag_row("Location ID:", "location_id")
			_show_expected_dropdown(ConditionType.LOCATION_VISITED)

		ConditionType.APPROVAL:
			_show_flag_row("NPC ID:", "npc_id")
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true

func _show_flag_row(label_text: String, placeholder: String) -> void:
	if flag_row: flag_row.visible = true
	if flag_label: flag_label.text = label_text
	if flag_edit: flag_edit.placeholder_text = placeholder

func _show_expected_dropdown(ctype: ConditionType) -> void:
	if not expected_row or not expected_dropdown:
		return
	expected_row.visible = true
	expected_dropdown.clear()
	var labels: Array = BOOL_LABELS.get(ctype, ["True", "False"])
	for label in labels:
		expected_dropdown.add_item(label)
	expected_dropdown.select(0 if expected_bool else 1)

# ============================================================================
# QUEST DROPDOWN (shared by QUEST_STATE and QUEST_OBJECTIVE)
# ============================================================================

func _show_quest_dropdown() -> void:
	if not quest_dropdown_row or not quest_dropdown:
		return
	quest_dropdown_row.visible = true

	if not _scan_cache.has(QUEST_ROOT):
		var results: Array = []
		_scan_quest_dir(QUEST_ROOT, results)
		results.sort_custom(func(a, b): return a.display < b.display)
		_scan_cache[QUEST_ROOT] = results

	_populate_quest_dropdown(_scan_cache[QUEST_ROOT])

func _populate_quest_dropdown(entries: Array) -> void:
	quest_dropdown.clear()
	for entry in entries:
		var idx = quest_dropdown.item_count
		quest_dropdown.add_item(entry.display)
		quest_dropdown.set_item_metadata(idx, entry.id)

	if entries.is_empty():
		quest_dropdown.add_item("(no quests found)")
		quest_dropdown.set_item_disabled(0, true)
		return

	_select_quest_dropdown_value(flag_name)

	# If nothing was pre-selected, sync to first item
	if flag_name == "" and quest_dropdown.selected >= 0:
		var meta = quest_dropdown.get_item_metadata(quest_dropdown.selected)
		if meta != null and str(meta) != "":
			flag_name = str(meta)
		_emit_modified()

func _select_quest_dropdown_value(value: String) -> void:
	if not quest_dropdown or value == "":
		return
	for i in quest_dropdown.item_count:
		var meta = quest_dropdown.get_item_metadata(i)
		if meta != null and str(meta) == value:
			quest_dropdown.select(i)
			return
	# Value not in dropdown — append so it's not silently lost
	if value != "":
		var idx = quest_dropdown.item_count
		quest_dropdown.add_item(value)
		quest_dropdown.set_item_metadata(idx, value)
		quest_dropdown.select(idx)

func _scan_quest_dir(path: String, results: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_quest_dir(path.path_join(file_name), results)
		elif file_name.ends_with(".tres"):
			var full_path = path.path_join(file_name)
			var res = load(full_path)
			if res and _resource_matches_type(res, "QuestDefinition"):
				var qid = str(res.get("quest_id"))
				var display = str(res.get("display_name"))
				if display == "":
					display = qid
				results.append({"display": display, "id": qid})
		file_name = dir.get_next()
	dir.list_dir_end()

# ============================================================================
# QUEST OBJECTIVE — two-dropdown flow (Quest → Objective → Check → Value)
# ============================================================================

func _show_quest_objective_ui() -> void:
	_show_quest_dropdown()
	if objective_row:
		objective_row.visible = true

	# Show the check dropdown with objective-specific options
	_show_objective_check_dropdown()

	# If we already have data, populate objective dropdown
	if flag_name != "":
		_select_quest_dropdown_value(flag_name)
		_populate_objective_dropdown_for_quest(flag_name)
		if objective_id != "":
			_select_objective_dropdown_value(objective_id)

func _show_objective_check_dropdown() -> void:
	if not expected_row or not expected_dropdown:
		return
	expected_row.visible = true
	var exp_label = expected_row.get_node_or_null("ExpectedLabel") as Label
	if exp_label:
		exp_label.text = "Check:"
	expected_dropdown.clear()
	for label in OBJECTIVE_CHECK_LABELS:
		expected_dropdown.add_item(label)
	expected_dropdown.select(clampi(objective_check_mode, 0, OBJECTIVE_CHECK_LABELS.size() - 1))

	# Show value row if progress mode is selected
	var is_progress = objective_check_mode >= ObjectiveCheckMode.PROGRESS_GTE
	if value_row:
		value_row.visible = is_progress

func _populate_objective_dropdown_for_quest(quest_id: String) -> void:
	if not objective_dropdown:
		return

	objective_dropdown.clear()

	var cache_key = "_obj_%s" % quest_id
	if not _scan_cache.has(cache_key):
		var entries: Array = []
		var dir = DirAccess.open(QUEST_ROOT)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres"):
					var res = load(QUEST_ROOT.path_join(file_name))
					if res and _resource_matches_type(res, "QuestDefinition"):
						var qid = str(res.get("quest_id"))
						if qid == quest_id:
							var objectives = res.get("objectives")
							if objectives:
								for obj in objectives:
									var oid = str(obj.get("objective_id"))
									var odesc = str(obj.get("description"))
									var clean_desc = odesc.replace("{current}", "0").replace("{required}", str(obj.get("required_count")))
									entries.append({"display": clean_desc, "id": oid})
							break
				file_name = dir.get_next()
			dir.list_dir_end()
		_scan_cache[cache_key] = entries

	var entries = _scan_cache[cache_key] as Array
	for entry in entries:
		var idx = objective_dropdown.item_count
		objective_dropdown.add_item(entry.display)
		objective_dropdown.set_item_metadata(idx, entry.id)

	if entries.is_empty():
		objective_dropdown.add_item("(no objectives)")
		objective_dropdown.set_item_disabled(0, true)
		return

	# Auto-select first objective if none set
	if objective_id == "" and objective_dropdown.selected >= 0:
		var first_meta = objective_dropdown.get_item_metadata(0)
		if first_meta != null:
			objective_id = str(first_meta)
			_emit_modified()

func _select_objective_dropdown_value(obj_id: String) -> void:
	if not objective_dropdown or obj_id == "":
		return
	for i in objective_dropdown.item_count:
		var meta = objective_dropdown.get_item_metadata(i)
		if meta != null and str(meta) == obj_id:
			objective_dropdown.select(i)
			return

# ============================================================================
# RESOURCE TYPE CHECKING (mirrors action_node pattern)
# ============================================================================

func _resource_matches_type(res: Resource, type_name: String) -> bool:
	var script = res.get_script()
	if script == null:
		return false
	if script.get_global_name() == type_name:
		return true
	var path = script.resource_path as String
	if path.ends_with(type_name.to_snake_case() + ".gd"):
		return true
	return false

# ============================================================================
# SERIALIZATION
# ============================================================================

func get_node_type() -> String:
	return "condition"

func is_multi_output() -> bool:
	return true

func get_node_data() -> Dictionary:
	var data = super.get_node_data()
	data.condition_type = condition_type
	data.flag_name = flag_name
	data.compare_value = compare_value
	data.compare_operator = compare_operator
	data.expected_bool = expected_bool
	data.quest_state_value = quest_state_value
	data.class_id = class_id
	data.objective_id = objective_id
	data.objective_check_mode = objective_check_mode
	return data

func set_node_data(data: Dictionary) -> void:
	super.set_node_data(data)

	condition_type = data.get("condition_type", ConditionType.FLAG)
	flag_name = data.get("flag_name", "")
	compare_value = data.get("compare_value", 0)
	compare_operator = data.get("compare_operator", ">=")
	expected_bool = data.get("expected_bool", true)
	quest_state_value = data.get("quest_state_value", "complete")
	class_id = data.get("class_id", "")
	objective_id = data.get("objective_id", "")
	objective_check_mode = data.get("objective_check_mode", ObjectiveCheckMode.IS_COMPLETE)

	# Legacy enum mapping: old 5-value enum → new 9-value enum
	# Old: FLAG_SET=0, FLAG_NOT_SET=1, COUNTER_AT_LEAST=2, COUNTER_LESS_THAN=3, COUNTER_EQUALS=4
	if not data.has("expected_bool"):
		# Legacy data — infer expected_bool from old enum values
		var raw = data.get("condition_type", 0)
		match raw:
			0:  # Old FLAG_SET
				condition_type = ConditionType.FLAG
				expected_bool = true
			1:  # Old FLAG_NOT_SET
				condition_type = ConditionType.FLAG
				expected_bool = false
			2:  # Old COUNTER_AT_LEAST
				condition_type = ConditionType.COUNTER
				compare_operator = ">="
			3:  # Old COUNTER_LESS_THAN
				condition_type = ConditionType.COUNTER
				compare_operator = "<"
			4:  # Old COUNTER_EQUALS
				condition_type = ConditionType.COUNTER
				compare_operator = "=="

	if type_dropdown:
		type_dropdown.select(condition_type)
	if flag_edit:
		flag_edit.text = flag_name
	if value_spin:
		value_spin.value = compare_value
	if operator_dropdown:
		var op_index = OPERATOR_OPTIONS.find(compare_operator)
		if op_index >= 0:
			operator_dropdown.select(op_index)
	if quest_state_dropdown:
		var state_index = QUEST_STATE_OPTIONS.find(quest_state_value)
		if state_index >= 0:
			quest_state_dropdown.select(state_index)
	if class_id_edit:
		class_id_edit.text = class_id

	# Defer quest dropdown restoration so children are in tree
	call_deferred("_update_ui_for_type")
