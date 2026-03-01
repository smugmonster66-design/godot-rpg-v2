@tool
extends "res://addons/dialogue_editor/nodes/base_dialogue_node.gd"

# ============================================================================
# ACTION TYPES
# ============================================================================
enum ActionType {
	SET_FLAG,
	CLEAR_FLAG,
	INCREMENT_COUNTER,
	DECREMENT_COUNTER,
	SET_COUNTER,
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
var action_type: ActionType = ActionType.SET_FLAG
var flag_name: String = ""
var value: int = 1

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	title = "SET FLAG"
	
	# Visual styling
	add_theme_color_override("title_color", Color(0.9, 0.5, 0.7))
	
	# One input, one output (pass-through)
	set_slot(0, true, 0, Color(0.9, 0.5, 0.7), true, 0, Color(0.9, 0.5, 0.7))
	
	# Populate type dropdown
	if type_dropdown:
		type_dropdown.clear()
		type_dropdown.add_item("Set Flag", ActionType.SET_FLAG)
		type_dropdown.add_item("Clear Flag", ActionType.CLEAR_FLAG)
		type_dropdown.add_item("Increment Counter", ActionType.INCREMENT_COUNTER)
		type_dropdown.add_item("Decrement Counter", ActionType.DECREMENT_COUNTER)
		type_dropdown.add_item("Set Counter To", ActionType.SET_COUNTER)
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
	action_type = index as ActionType
	_update_value_visibility()
	_update_title()
	_emit_modified()

func _on_flag_changed(new_text: String) -> void:
	flag_name = new_text
	_emit_modified()

func _on_value_changed(new_value: float) -> void:
	value = int(new_value)
	_emit_modified()

func _update_value_visibility() -> void:
	if not value_row:
		return
	
	# Show value spinner for counter operations
	var needs_value = action_type in [
		ActionType.INCREMENT_COUNTER,
		ActionType.DECREMENT_COUNTER,
		ActionType.SET_COUNTER,
	]
	value_row.visible = needs_value

func _update_title() -> void:
	match action_type:
		ActionType.SET_FLAG, ActionType.CLEAR_FLAG:
			title = "SET FLAG"
		_:
			title = "SET COUNTER"

# ============================================================================
# SERIALIZATION
# ============================================================================

func get_node_type() -> String:
	return "set_flag"

func get_node_data() -> Dictionary:
	var data = super.get_node_data()
	data.action_type = action_type
	data.flag_name = flag_name
	data.value = value
	return data

func set_node_data(data: Dictionary) -> void:
	super.set_node_data(data)
	
	action_type = data.get("action_type", ActionType.SET_FLAG)
	flag_name = data.get("flag_name", "")
	value = data.get("value", 1)
	
	if type_dropdown:
		type_dropdown.select(action_type)
	if flag_edit:
		flag_edit.text = flag_name
	if value_spin:
		value_spin.value = value
	
	_update_value_visibility()
	_update_title()
