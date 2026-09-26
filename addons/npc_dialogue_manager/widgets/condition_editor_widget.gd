@tool
extends VBoxContainer

## Emitted whenever the condition is modified.
signal condition_changed(condition: Resource)

const QUEST_ROOT := "res://resources/definitions/quests/"

# ============================================================================
# CONDITION MODE
# ============================================================================
enum ConditionMode {
	ALWAYS_TRUE,    # 0
	SINGLE,         # 1
	AND,            # 2
	OR,             # 3
}

# Single check types (matches SingleCheck.CheckType)
enum CheckType {
	FLAG,               # 0
	COUNTER,            # 1
	RELATIONSHIP,       # 2
	HAS_ITEM,           # 3
	PLAYER_LEVEL,       # 4
	CLASS_LEVEL,        # 5
	QUEST_STATE,        # 6
	LOCATION_VISITED,   # 7
	CUSTOM,             # 8
}

const OPERATOR_OPTIONS: Array[String] = ["==", "!=", ">", "<", ">=", "<="]
const QUEST_STATE_OPTIONS: Array[String] = ["locked", "available", "active", "ready", "complete", "failed"]
const BOOL_LABELS: Dictionary = {
	CheckType.FLAG: ["Set", "Not Set"],
	CheckType.LOCATION_VISITED: ["Visited", "Not Visited"],
	CheckType.HAS_ITEM: ["Has Item", "Does Not Have"],
}

# ============================================================================
# NODE REFS
# ============================================================================
@onready var mode_dropdown: OptionButton = %ModeDropdown
@onready var invert_check: CheckBox = %InvertCheck

# Single check rows
@onready var single_container: VBoxContainer = %SingleContainer
@onready var type_dropdown: OptionButton = %TypeDropdown
@onready var key_row: HBoxContainer = %KeyRow
@onready var key_label: Label = %KeyLabel
@onready var key_edit: LineEdit = %KeyEdit
@onready var operator_row: HBoxContainer = %OperatorRow
@onready var operator_dropdown: OptionButton = %OperatorDropdown
@onready var value_row: HBoxContainer = %ValueRow
@onready var value_spin: SpinBox = %ValueSpin
@onready var bool_row: HBoxContainer = %BoolRow
@onready var bool_dropdown: OptionButton = %BoolDropdown
@onready var quest_state_row: HBoxContainer = %QuestStateRow
@onready var quest_state_dropdown: OptionButton = %QuestStateDropdown
@onready var class_id_row: HBoxContainer = %ClassIdRow
@onready var class_id_edit: LineEdit = %ClassIdEdit
@onready var quest_dropdown_row: HBoxContainer = %QuestDropdownRow
@onready var quest_dropdown: OptionButton = %QuestDropdown
@onready var objective_row: HBoxContainer = %ObjectiveRow
@onready var objective_dropdown: OptionButton = %ObjectiveDropdown

# Compound container
@onready var compound_container: VBoxContainer = %CompoundContainer
@onready var add_sub_button: Button = %AddSubButton

# ============================================================================
# STATE
# ============================================================================
var _mode: ConditionMode = ConditionMode.ALWAYS_TRUE
var _invert: bool = false

# Single check state
var _check_type: CheckType = CheckType.FLAG
var _key: String = ""
var _operator: String = ">="
var _int_value: int = 0
var _bool_value: bool = true
var _quest_state: String = "complete"
var _class_id: String = ""
var _objective_id: String = ""

# Compound state
var _sub_widgets: Array = []

var _scan_cache: Dictionary = {}
var _suppress_signals: bool = false

# ============================================================================
# INIT
# ============================================================================

func _ready() -> void:
	_resolve_refs()
	_connect_signals()
	_populate_dropdowns()
	call_deferred("_update_ui")

func _resolve_refs() -> void:
	# Safety for @tool context where @onready may not fire
	if mode_dropdown == null:
		mode_dropdown = get_node_or_null("%ModeDropdown")
	if invert_check == null:
		invert_check = get_node_or_null("%InvertCheck")
	if single_container == null:
		single_container = get_node_or_null("%SingleContainer")
	if type_dropdown == null:
		type_dropdown = get_node_or_null("%TypeDropdown")
	if key_row == null:
		key_row = get_node_or_null("%KeyRow")
	if key_label == null:
		key_label = get_node_or_null("%KeyLabel")
	if key_edit == null:
		key_edit = get_node_or_null("%KeyEdit")
	if operator_row == null:
		operator_row = get_node_or_null("%OperatorRow")
	if operator_dropdown == null:
		operator_dropdown = get_node_or_null("%OperatorDropdown")
	if value_row == null:
		value_row = get_node_or_null("%ValueRow")
	if value_spin == null:
		value_spin = get_node_or_null("%ValueSpin")
	if bool_row == null:
		bool_row = get_node_or_null("%BoolRow")
	if bool_dropdown == null:
		bool_dropdown = get_node_or_null("%BoolDropdown")
	if quest_state_row == null:
		quest_state_row = get_node_or_null("%QuestStateRow")
	if quest_state_dropdown == null:
		quest_state_dropdown = get_node_or_null("%QuestStateDropdown")
	if class_id_row == null:
		class_id_row = get_node_or_null("%ClassIdRow")
	if class_id_edit == null:
		class_id_edit = get_node_or_null("%ClassIdEdit")
	if quest_dropdown_row == null:
		quest_dropdown_row = get_node_or_null("%QuestDropdownRow")
	if quest_dropdown == null:
		quest_dropdown = get_node_or_null("%QuestDropdown")
	if objective_row == null:
		objective_row = get_node_or_null("%ObjectiveRow")
	if objective_dropdown == null:
		objective_dropdown = get_node_or_null("%ObjectiveDropdown")
	if compound_container == null:
		compound_container = get_node_or_null("%CompoundContainer")
	if add_sub_button == null:
		add_sub_button = get_node_or_null("%AddSubButton")

func _connect_signals() -> void:
	if mode_dropdown:
		mode_dropdown.item_selected.connect(_on_mode_selected)
	if invert_check:
		invert_check.toggled.connect(_on_invert_toggled)
	if type_dropdown:
		type_dropdown.item_selected.connect(_on_type_selected)
	if key_edit:
		key_edit.text_changed.connect(_on_key_changed)
	if operator_dropdown:
		operator_dropdown.item_selected.connect(_on_operator_selected)
	if value_spin:
		value_spin.value_changed.connect(_on_value_changed)
	if bool_dropdown:
		bool_dropdown.item_selected.connect(_on_bool_selected)
	if quest_state_dropdown:
		quest_state_dropdown.item_selected.connect(_on_quest_state_selected)
	if class_id_edit:
		class_id_edit.text_changed.connect(_on_class_id_changed)
	if quest_dropdown:
		quest_dropdown.item_selected.connect(_on_quest_dropdown_selected)
	if objective_dropdown:
		objective_dropdown.item_selected.connect(_on_objective_selected)
	if add_sub_button:
		add_sub_button.pressed.connect(_on_add_sub_pressed)

func _populate_dropdowns() -> void:
	if mode_dropdown:
		mode_dropdown.clear()
		mode_dropdown.add_item("Always True")
		mode_dropdown.add_item("Single Check")
		mode_dropdown.add_item("All Of (AND)")
		mode_dropdown.add_item("Any Of (OR)")

	if type_dropdown:
		type_dropdown.clear()
		type_dropdown.add_item("Flag")
		type_dropdown.add_item("Counter")
		type_dropdown.add_item("Relationship")
		type_dropdown.add_item("Has Item")
		type_dropdown.add_item("Player Level")
		type_dropdown.add_item("Class Level")
		type_dropdown.add_item("Quest State")
		type_dropdown.add_item("Location Visited")
		type_dropdown.add_item("Quest Objective")

	if operator_dropdown:
		operator_dropdown.clear()
		for op in OPERATOR_OPTIONS:
			operator_dropdown.add_item(op)

	if quest_state_dropdown:
		quest_state_dropdown.clear()
		for state in QUEST_STATE_OPTIONS:
			quest_state_dropdown.add_item(state)

# ============================================================================
# PUBLIC API
# ============================================================================

func load_condition(condition: Resource) -> void:
	"""Load a GameCondition resource into the widget."""
	_suppress_signals = true

	if condition == null:
		_mode = ConditionMode.ALWAYS_TRUE
		_invert = false
		_check_type = CheckType.FLAG
		_key = ""
		_operator = ">="
		_int_value = 0
		_bool_value = true
		_quest_state = "complete"
		_class_id = ""
		_objective_id = ""
		_clear_sub_widgets()
	else:
		_invert = condition.get("invert") == true
		var ctype = condition.get("condition_type")
		match ctype:
			0:  # ALWAYS_TRUE
				_mode = ConditionMode.ALWAYS_TRUE
			1:  # ALWAYS_FALSE
				_mode = ConditionMode.ALWAYS_TRUE
				_invert = true
			2:  # SINGLE
				_mode = ConditionMode.SINGLE
				_load_single_check(condition.get("single_check"))
			3:  # AND
				_mode = ConditionMode.AND
				_load_compound(condition.get("sub_conditions"))
			4:  # OR
				_mode = ConditionMode.OR
				_load_compound(condition.get("sub_conditions"))

	if mode_dropdown:
		mode_dropdown.select(_mode)
	if invert_check:
		invert_check.button_pressed = _invert

	_suppress_signals = false
	_update_ui()

func build_condition() -> Resource:
	"""Build a GameCondition resource from the current widget state."""
	var GameConditionScript = load("res://resources/data/game_condition.gd")
	if not GameConditionScript:
		return null

	var condition = GameConditionScript.new()
	condition.invert = _invert

	match _mode:
		ConditionMode.ALWAYS_TRUE:
			condition.condition_type = 0  # ALWAYS_TRUE

		ConditionMode.SINGLE:
			condition.condition_type = 2  # SINGLE
			condition.single_check = _build_single_check()

		ConditionMode.AND:
			condition.condition_type = 3  # AND
			condition.sub_conditions = _build_sub_conditions()

		ConditionMode.OR:
			condition.condition_type = 4  # OR
			condition.sub_conditions = _build_sub_conditions()

	return condition

# ============================================================================
# SINGLE CHECK LOAD/BUILD
# ============================================================================

func _load_single_check(check: Resource) -> void:
	if check == null:
		return
	_check_type = check.get("check_type") as CheckType
	_key = str(check.get("key"))
	_operator = str(check.get("compare_operator"))
	_int_value = check.get("int_value") if check.get("int_value") != null else 0
	_bool_value = check.get("bool_value") == true
	_quest_state = str(check.get("quest_state"))
	_class_id = str(check.get("class_id"))

	# Handle CUSTOM quest_objective keys
	if _check_type == CheckType.CUSTOM:
		var key_str = _key
		if key_str.begins_with("quest_objective:"):
			var parts = key_str.split(":")
			if parts.size() >= 3:
				_key = parts[1]  # quest_id
				_objective_id = parts[2]

	if type_dropdown:
		var select_index = _check_type as int
		if select_index < type_dropdown.item_count:
			type_dropdown.select(select_index)
	if key_edit:
		key_edit.text = _key
	if operator_dropdown:
		var op_idx = OPERATOR_OPTIONS.find(_operator)
		if op_idx >= 0:
			operator_dropdown.select(op_idx)
	if value_spin:
		value_spin.value = _int_value
	if quest_state_dropdown:
		var state_idx = QUEST_STATE_OPTIONS.find(_quest_state)
		if state_idx >= 0:
			quest_state_dropdown.select(state_idx)
	if class_id_edit:
		class_id_edit.text = _class_id

func _build_single_check() -> Resource:
	var check = SingleCheck.new()
	check.check_type = _check_type as int

	# For CUSTOM quest objective checks, reconstruct the composite key
	if _check_type == CheckType.CUSTOM and _objective_id != "":
		check.key = StringName("quest_objective:%s:%s" % [_key, _objective_id])
	else:
		check.key = StringName(_key)

	check.compare_operator = _operator
	check.int_value = _int_value
	check.bool_value = _bool_value
	check.quest_state = _quest_state
	check.class_id = StringName(_class_id)
	return check

# ============================================================================
# COMPOUND LOAD/BUILD
# ============================================================================

func _load_compound(sub_conditions) -> void:
	_clear_sub_widgets()
	if sub_conditions == null:
		return
	for sub in sub_conditions:
		_add_sub_widget(sub)

func _build_sub_conditions() -> Array:
	var GameConditionScript = load("res://resources/data/game_condition.gd")
	var result: Array = []
	for widget in _sub_widgets:
		if widget and widget.has_method("build_condition"):
			var sub = widget.build_condition()
			if sub:
				result.append(sub)
	return result

func _clear_sub_widgets() -> void:
	for widget in _sub_widgets:
		if is_instance_valid(widget):
			widget.queue_free()
	_sub_widgets.clear()

func _add_sub_widget(condition: Resource = null) -> void:
	if not compound_container:
		return

	var widget_scene = load("res://addons/npc_dialogue_manager/widgets/condition_editor_widget.tscn")
	if not widget_scene:
		return

	var row = HBoxContainer.new()
	compound_container.add_child(row)

	var widget = widget_scene.instantiate()
	row.add_child(widget)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var remove_btn = Button.new()
	remove_btn.text = "−"
	remove_btn.tooltip_text = "Remove this sub-condition"
	remove_btn.pressed.connect(func():
		var idx = _sub_widgets.find(widget)
		if idx >= 0:
			_sub_widgets.remove_at(idx)
		row.queue_free()
		_emit_changed()
	)
	row.add_child(remove_btn)

	_sub_widgets.append(widget)

	if condition:
		widget.call_deferred("load_condition", condition)

	widget.condition_changed.connect(func(_c): _emit_changed())

# ============================================================================
# UI UPDATE
# ============================================================================

func _update_ui() -> void:
	_resolve_refs()

	var show_single = _mode == ConditionMode.SINGLE
	var show_compound = _mode == ConditionMode.AND or _mode == ConditionMode.OR

	if single_container:
		single_container.visible = show_single
	if compound_container:
		compound_container.visible = show_compound
	if add_sub_button:
		add_sub_button.visible = show_compound

	if show_single:
		_update_single_ui()

func _update_single_ui() -> void:
	# Hide all optional rows
	if key_row: key_row.visible = false
	if operator_row: operator_row.visible = false
	if value_row: value_row.visible = false
	if bool_row: bool_row.visible = false
	if quest_state_row: quest_state_row.visible = false
	if class_id_row: class_id_row.visible = false
	if quest_dropdown_row: quest_dropdown_row.visible = false
	if objective_row: objective_row.visible = false

	match _check_type:
		CheckType.FLAG:
			_show_key_row("Flag Name:", "flag_name")
			_show_bool_dropdown(CheckType.FLAG)
		CheckType.COUNTER:
			_show_key_row("Counter:", "counter_name")
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true
		CheckType.RELATIONSHIP:
			_show_key_row("NPC ID:", "npc_id")
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true
		CheckType.HAS_ITEM:
			_show_key_row("Item ID:", "item_id")
			_show_bool_dropdown(CheckType.HAS_ITEM)
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true
		CheckType.PLAYER_LEVEL:
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true
		CheckType.CLASS_LEVEL:
			if operator_row: operator_row.visible = true
			if value_row: value_row.visible = true
			if class_id_row: class_id_row.visible = true
		CheckType.QUEST_STATE:
			_show_quest_dropdown()
			if quest_state_row: quest_state_row.visible = true
		CheckType.LOCATION_VISITED:
			_show_key_row("Location ID:", "location_id")
			_show_bool_dropdown(CheckType.LOCATION_VISITED)
		CheckType.CUSTOM:
			_show_quest_dropdown()
			_show_objective_dropdown()

func _show_key_row(label_text: String, placeholder: String) -> void:
	if key_row: key_row.visible = true
	if key_label: key_label.text = label_text
	if key_edit: key_edit.placeholder_text = placeholder

func _show_bool_dropdown(ctype: CheckType) -> void:
	if not bool_row or not bool_dropdown:
		return
	bool_row.visible = true
	bool_dropdown.clear()
	var labels: Array = BOOL_LABELS.get(ctype, ["True", "False"])
	for label in labels:
		bool_dropdown.add_item(label)
	bool_dropdown.select(0 if _bool_value else 1)

func _show_quest_dropdown() -> void:
	if not quest_dropdown_row or not quest_dropdown:
		return
	quest_dropdown_row.visible = true

	if not _scan_cache.has(QUEST_ROOT):
		var results: Array = []
		_scan_quest_dir(QUEST_ROOT, results)
		results.sort_custom(func(a, b): return a.display < b.display)
		_scan_cache[QUEST_ROOT] = results

	quest_dropdown.clear()
	var entries = _scan_cache[QUEST_ROOT] as Array
	for entry in entries:
		var idx = quest_dropdown.item_count
		quest_dropdown.add_item(entry.display)
		quest_dropdown.set_item_metadata(idx, entry.id)

	if entries.is_empty():
		quest_dropdown.add_item("(no quests found)")
		quest_dropdown.set_item_disabled(0, true)
		return

	# Select current value
	_select_dropdown_value(quest_dropdown, _key)
	if _key == "" and quest_dropdown.selected >= 0:
		var meta = quest_dropdown.get_item_metadata(quest_dropdown.selected)
		if meta != null and str(meta) != "":
			_key = str(meta)

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

func _resource_matches_type(res: Resource, type_name: String) -> bool:
	var script = res.get_script()
	if script == null:
		return false
	if script.get_global_name() == type_name:
		return true
	var path = script.resource_path as String
	return path.ends_with(type_name.to_snake_case() + ".gd")

func _show_objective_dropdown() -> void:
	if not objective_row or not objective_dropdown:
		return
	objective_row.visible = true
	objective_dropdown.clear()

	# Need a quest_id to populate objectives
	var quest_id = _key
	if quest_id == "":
		objective_dropdown.add_item("(select a quest first)")
		objective_dropdown.set_item_disabled(0, true)
		return

	# Load the quest definition and extract objectives
	var quest_res = _find_quest_resource(quest_id)
	if quest_res == null:
		objective_dropdown.add_item("(quest not found)")
		objective_dropdown.set_item_disabled(0, true)
		return

	var objectives = quest_res.get("objectives")
	if objectives == null or objectives.is_empty():
		objective_dropdown.add_item("(no objectives)")
		objective_dropdown.set_item_disabled(0, true)
		return

	for obj in objectives:
		var obj_id = str(obj.get("objective_id"))
		var desc = str(obj.get("description"))
		var display = "%s (%s)" % [obj_id, desc] if desc != "" else obj_id
		var idx = objective_dropdown.item_count
		objective_dropdown.add_item(display)
		objective_dropdown.set_item_metadata(idx, obj_id)

	# Select current objective
	if _objective_id != "":
		_select_dropdown_value(objective_dropdown, _objective_id)
	if objective_dropdown.selected >= 0 and _objective_id == "":
		var meta = objective_dropdown.get_item_metadata(objective_dropdown.selected)
		if meta != null and str(meta) != "":
			_objective_id = str(meta)

func _find_quest_resource(quest_id: String) -> Resource:
	"""Find and load a quest definition by its quest_id."""
	if not _scan_cache.has(QUEST_ROOT):
		var results: Array = []
		_scan_quest_dir(QUEST_ROOT, results)
		results.sort_custom(func(a, b): return a.display < b.display)
		_scan_cache[QUEST_ROOT] = results

	# Search quest files for the matching quest_id
	var dir = DirAccess.open(QUEST_ROOT)
	if dir == null:
		return null
	return _find_quest_in_dir(QUEST_ROOT, quest_id)

func _find_quest_in_dir(path: String, quest_id: String) -> Resource:
	var dir = DirAccess.open(path)
	if dir == null:
		return null
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var result = _find_quest_in_dir(path.path_join(file_name), quest_id)
			if result:
				dir.list_dir_end()
				return result
		elif file_name.ends_with(".tres"):
			var full_path = path.path_join(file_name)
			var res = load(full_path)
			if res and str(res.get("quest_id")) == quest_id:
				dir.list_dir_end()
				return res
		file_name = dir.get_next()
	dir.list_dir_end()
	return null

func _select_dropdown_value(dropdown: OptionButton, value: String) -> void:
	if not dropdown or value == "":
		return
	for i in dropdown.item_count:
		var meta = dropdown.get_item_metadata(i)
		if meta != null and str(meta) == value:
			dropdown.select(i)
			return

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_mode_selected(index: int) -> void:
	_mode = index as ConditionMode
	_update_ui()
	_emit_changed()

func _on_invert_toggled(pressed: bool) -> void:
	_invert = pressed
	_emit_changed()

func _on_type_selected(index: int) -> void:
	_check_type = index as CheckType
	_key = ""
	_operator = ">="
	_int_value = 0
	_bool_value = true
	if key_edit:
		key_edit.text = ""
	_update_single_ui()
	_emit_changed()

func _on_key_changed(new_text: String) -> void:
	_key = new_text
	_emit_changed()

func _on_operator_selected(index: int) -> void:
	if index >= 0 and index < OPERATOR_OPTIONS.size():
		_operator = OPERATOR_OPTIONS[index]
	_emit_changed()

func _on_value_changed(new_value: float) -> void:
	_int_value = int(new_value)
	_emit_changed()

func _on_bool_selected(index: int) -> void:
	_bool_value = (index == 0)
	_emit_changed()

func _on_quest_state_selected(index: int) -> void:
	if index >= 0 and index < QUEST_STATE_OPTIONS.size():
		_quest_state = QUEST_STATE_OPTIONS[index]
	_emit_changed()

func _on_class_id_changed(new_text: String) -> void:
	_class_id = new_text
	_emit_changed()

func _on_quest_dropdown_selected(index: int) -> void:
	if quest_dropdown and index >= 0:
		var meta = quest_dropdown.get_item_metadata(index)
		_key = str(meta) if meta != null and str(meta) != "" else quest_dropdown.get_item_text(index)
	# Refresh objective dropdown when quest changes in CUSTOM mode
	if _check_type == CheckType.CUSTOM:
		_objective_id = ""
		_show_objective_dropdown()
	_emit_changed()

func _on_objective_selected(index: int) -> void:
	if objective_dropdown and index >= 0:
		var meta = objective_dropdown.get_item_metadata(index)
		_objective_id = str(meta) if meta != null and str(meta) != "" else objective_dropdown.get_item_text(index)
	_emit_changed()

func _on_add_sub_pressed() -> void:
	_add_sub_widget(null)
	_emit_changed()

func _emit_changed() -> void:
	if _suppress_signals:
		return
	condition_changed.emit(build_condition())
