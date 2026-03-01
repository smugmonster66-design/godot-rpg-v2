@tool
extends "res://addons/dialogue_editor/nodes/base_dialogue_node.gd"

# ============================================================================
# CONDITION TYPES
# ============================================================================
enum ConditionType {
	FLAG_SET,
	FLAG_NOT_SET,
	COUNTER_AT_LEAST,
	COUNTER_LESS_THAN,
	COUNTER_EQUALS,
}

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var type_dropdown: OptionButton = $VBox/TypeRow/TypeDropdown
@onready var flag_edit: LineEdit = $VBox/FlagRow/FlagEdit
@onready var value_row: HBoxContainer = $VBox/ValueRow
@onready var value_spin: SpinBox = $VBox/ValueRow/ValueSpin

# ============================================================================
# STATE
# ============================================================================
var condition_type: ConditionType = ConditionType.FLAG_SET
var flag_name: String = ""
var compare_value: int = 0

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
		type_dropdown.add_item("Flag is Set", ConditionType.FLAG_SET)
		type_dropdown.add_item("Flag is Not Set", ConditionType.FLAG_NOT_SET)
		type_dropdown.add_item("Counter ≥", ConditionType.COUNTER_AT_LEAST)
		type_dropdown.add_item("Counter <", ConditionType.COUNTER_LESS_THAN)
		type_dropdown.add_item("Counter =", ConditionType.COUNTER_EQUALS)
		type_dropdown.item_selected.connect(_on_type_selected)
	
	if flag_edit:
		flag_edit.text_changed.connect(_on_flag_changed)
	
	if value_spin:
		value_spin.value_changed.connect(_on_value_changed)
	
	_update_value_visibility()

# ============================================================================
# UI HANDLERS
# ============================================================================

func _on_type_selected(index: int) -> void:
	condition_type = index as ConditionType
	_update_value_visibility()
	_emit_modified()

func _on_flag_changed(new_text: String) -> void:
	flag_name = new_text
	_emit_modified()

func _on_value_changed(new_value: float) -> void:
	compare_value = int(new_value)
	_emit_modified()

func _update_value_visibility() -> void:
	if not value_row:
		return
	
	# Show value spinner only for counter comparisons
	var needs_value = condition_type in [
		ConditionType.COUNTER_AT_LEAST,
		ConditionType.COUNTER_LESS_THAN,
		ConditionType.COUNTER_EQUALS,
	]
	value_row.visible = needs_value

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
	return data

func set_node_data(data: Dictionary) -> void:
	super.set_node_data(data)
	
	condition_type = data.get("condition_type", ConditionType.FLAG_SET)
	flag_name = data.get("flag_name", "")
	compare_value = data.get("compare_value", 0)
	
	if type_dropdown:
		type_dropdown.select(condition_type)
	if flag_edit:
		flag_edit.text = flag_name
	if value_spin:
		value_spin.value = compare_value
	
	_update_value_visibility()
