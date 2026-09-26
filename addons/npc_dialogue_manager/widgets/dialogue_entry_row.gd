@tool
extends PanelContainer

signal row_clicked(index: int)

@onready var pri_label: Label = %PriLabel
@onready var id_label: Label = %IdLabel
@onready var condition_label: Label = %ConditionLabel
@onready var oneshot_label: Label = %OneShotLabel

var _index: int = -1
var _is_selected: bool = false

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func set_entry_data(index: int, entry: Resource) -> void:
	_index = index
	if not entry:
		return

	if pri_label:
		pri_label.text = str(entry.get("priority"))
	if id_label:
		var eid = str(entry.get("encounter_id"))
		id_label.text = eid if eid != "" else "(unnamed)"
	if condition_label:
		condition_label.text = _summarize_condition(entry.get("condition"))
	if oneshot_label:
		oneshot_label.text = "●" if entry.get("one_shot") else ""

func get_entry_index() -> int:
	return _index

func set_selected(selected: bool) -> void:
	_is_selected = selected
	if _is_selected:
		add_theme_stylebox_override("panel", _make_selected_style())
	else:
		remove_theme_stylebox_override("panel")

func _make_selected_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.8, 0.3)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		row_clicked.emit(_index)

func _summarize_condition(condition: Resource) -> String:
	if condition == null:
		return "(always)"

	# Check condition_type
	var ctype = condition.get("condition_type")
	if ctype == null:
		return "(always)"

	# ALWAYS_TRUE = 0, ALWAYS_FALSE = 1, SINGLE = 2, AND = 3, OR = 4
	match ctype:
		0:  # ALWAYS_TRUE
			var invert = condition.get("invert")
			if invert:
				return "(never)"
			return "(always)"
		1:  # ALWAYS_FALSE
			return "(never)"
		2:  # SINGLE
			return _summarize_single_check(condition.get("single_check"))
		3:  # AND
			var subs = condition.get("sub_conditions")
			if subs:
				return "AND (%d)" % subs.size()
			return "AND (empty)"
		4:  # OR
			var subs = condition.get("sub_conditions")
			if subs:
				return "OR (%d)" % subs.size()
			return "OR (empty)"

	return "(?)"

func _summarize_single_check(check: Resource) -> String:
	if check == null:
		return "(empty)"

	var ctype = check.get("check_type")
	var key = str(check.get("key"))

	# FLAG=0, COUNTER=1, RELATIONSHIP=2, HAS_ITEM=3, PLAYER_LEVEL=4,
	# CLASS_LEVEL=5, QUEST_STATE=6, LOCATION_VISITED=7, CUSTOM=8
	match ctype:
		0:  # FLAG
			var bval = check.get("bool_value")
			return "Flag: %s %s" % [key, "✓" if bval else "✗"]
		1:  # COUNTER
			return "Counter: %s %s %s" % [key, str(check.get("compare_operator")), str(check.get("int_value"))]
		2:  # RELATIONSHIP
			return "Rel: %s %s %s" % [key, str(check.get("compare_operator")), str(check.get("int_value"))]
		3:  # HAS_ITEM
			return "Item: %s" % key
		4:  # PLAYER_LEVEL
			return "Level %s %s" % [str(check.get("compare_operator")), str(check.get("int_value"))]
		5:  # CLASS_LEVEL
			return "Class: %s %s %s" % [str(check.get("class_id")), str(check.get("compare_operator")), str(check.get("int_value"))]
		6:  # QUEST_STATE
			return "Quest: %s = %s" % [key, str(check.get("quest_state"))]
		7:  # LOCATION_VISITED
			return "Visited: %s" % key
		8:  # CUSTOM
			if key.begins_with("quest_objective:"):
				return "Objective: %s" % key.trim_prefix("quest_objective:")
			return "Custom: %s" % key

	return "(?)"
