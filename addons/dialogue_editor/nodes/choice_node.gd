@tool
extends "res://addons/dialogue_editor/nodes/base_dialogue_node.gd"

# ============================================================================
# CONSTANTS
# ============================================================================
const MAX_CHOICES = 6

# ============================================================================
# STATE
# ============================================================================
var choices: Array[Dictionary] = []  # [{label: ""}, ...]

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	title = "CHOICES"
	add_theme_color_override("title_color", Color(0.9, 0.7, 0.3))
	
	# Build initial UI
	_rebuild_all()

# ============================================================================
# REBUILD UI
# ============================================================================

func _rebuild_all() -> void:
	"""Completely rebuild all children and slots."""
	# Remove all children - must iterate backwards or use while loop
	while get_child_count() > 0:
		var child = get_child(0)
		remove_child(child)
		child.queue_free()
	
	# Clear all slots
	for i in range(MAX_CHOICES + 2):
		clear_slot(i)
	
	# Ensure at least one choice
	if choices.is_empty():
		choices.append({"label": ""})
	
	# Child 0: Header (input slot)
	var header = Label.new()
	header.text = "Player choices:"
	add_child(header)
	set_slot(0, true, 0, Color(0.9, 0.7, 0.3), false, 0, Color.WHITE)
	
	# Children 1..N: Choice rows (output slots)
	for i in choices.size():
		var row = _create_choice_row(i)
		add_child(row)
		set_slot(i + 1, false, 0, Color.WHITE, true, 1, Color(0.9, 0.7, 0.3))
	
	# Last child: Add button (no slots)
	var add_btn = Button.new()
	add_btn.text = "+ Add Choice"
	add_btn.pressed.connect(_on_add_pressed)
	add_child(add_btn)
	var btn_idx = choices.size() + 1
	set_slot(btn_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
	
	# Force layout update
	queue_redraw()

func _create_choice_row(index: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.name = "Choice_%d" % index
	
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "Choice %d..." % (index + 1)
	line_edit.text = choices[index].get("label", "")
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_changed.connect(_on_text_changed.bind(index))
	row.add_child(line_edit)
	
	var remove_btn = Button.new()
	remove_btn.text = "×"
	remove_btn.custom_minimum_size = Vector2(24, 0)
	remove_btn.pressed.connect(_on_remove_pressed.bind(index))
	row.add_child(remove_btn)
	
	return row

# ============================================================================
# HANDLERS
# ============================================================================

func _on_add_pressed() -> void:
	if choices.size() >= MAX_CHOICES:
		return
	choices.append({"label": ""})
	_rebuild_all()
	_emit_modified()

func _on_remove_pressed(index: int) -> void:
	if choices.size() <= 1:
		return
	choices.remove_at(index)
	_rebuild_all()
	_emit_modified()

func _on_text_changed(new_text: String, index: int) -> void:
	if index >= 0 and index < choices.size():
		choices[index].label = new_text
		_emit_modified()

# ============================================================================
# SERIALIZATION
# ============================================================================

func get_node_type() -> String:
	return "choice"

func is_multi_output() -> bool:
	return true

func get_node_data() -> Dictionary:
	var data = super.get_node_data()
	data.choices = choices.duplicate(true)
	return data

func set_node_data(data: Dictionary) -> void:
	super.set_node_data(data)
	
	choices.clear()
	var loaded = data.get("choices", [])
	if loaded.is_empty():
		loaded = [{"label": ""}]
	
	for c in loaded:
		choices.append({"label": c.get("label", "")})
	
	_rebuild_all()

# ============================================================================
# PORT MAPPING
# ============================================================================

func get_output_port_for_choice(choice_index: int) -> int:
	"""Choice 0 is on port 1, choice 1 is on port 2, etc."""
	return choice_index + 1
