@tool
extends "res://addons/dialogue_editor/nodes/base_dialogue_node.gd"

# ============================================================================
# CONSTANTS
# ============================================================================
const MAX_CHOICES = 6

# Condition types available inline per choice
enum ChoiceCondType {
	NONE,           # 0 — No condition (always visible)
	FLAG,           # 1 — Check a story flag
	COUNTER,        # 2 — Compare a counter value
	RELATIONSHIP,   # 3 — Compare NPC relationship
	APPROVAL,       # 4 — Compare hidden NPC approval
}

const COND_TYPE_LABELS = ["None", "Flag", "Counter", "Relationship", "Approval"]
const OPERATOR_OPTIONS = ["==", "!=", ">", "<", ">=", "<="]

# ============================================================================
# STATE
# ============================================================================
var choices: Array[Dictionary] = []  # [{label: "", ...}, ...]
var _bbcode_menu = null

# ============================================================================
# DEFAULT CHOICE DATA
# ============================================================================

static func _default_choice() -> Dictionary:
	return {
		"label": "",
		# Effects
		"virtue": 0,
		"order": 0,
		"approval_npc": "",
		"approval": 0,
		# Condition
		"cond_type": ChoiceCondType.NONE,
		"cond_key": "",
		"cond_op": ">=",
		"cond_value": 0,
		"cond_bool": true,
		"show_when_locked": false,
		"locked_hint": "",
	}

static func _parse_choice(c: Dictionary) -> Dictionary:
	var d = _default_choice()
	for key in d.keys():
		if c.has(key):
			d[key] = c[key]
	return d

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	title = "CHOICES"
	add_theme_color_override("title_color", Color(0.9, 0.7, 0.3))

	# BBCode style context menu (Window must be child of root, not GraphNode)
	var menu_scene = load("res://addons/dialogue_editor/widgets/bbcode_style_menu.tscn")
	if menu_scene:
		_bbcode_menu = menu_scene.instantiate()
		_add_menu_deferred.call_deferred()

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
		choices.append(_default_choice())

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

func _create_choice_row(index: int) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.name = "Choice_%d" % index

	# Top row: label text + remove button
	var top_row = HBoxContainer.new()
	container.add_child(top_row)

	var text_edit = TextEdit.new()
	text_edit.placeholder_text = "Choice %d..." % (index + 1)
	text_edit.text = choices[index].get("label", "")
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.scroll_fit_content_height = true
	text_edit.custom_minimum_size = Vector2(0, 30)
	text_edit.text_changed.connect(_on_choice_text_changed.bind(index, text_edit))
	text_edit.gui_input.connect(_on_choice_gui_input.bind(text_edit))
	top_row.add_child(text_edit)

	# Auto-resize on load
	_auto_resize_choice.call_deferred(text_edit)

	var remove_btn = Button.new()
	remove_btn.text = "×"
	remove_btn.pressed.connect(_on_remove_pressed.bind(index))
	top_row.add_child(remove_btn)
	remove_btn.custom_minimum_size = Vector2(24, 0)

	# Effects row: moral weight spinboxes
	var moral_row = HBoxContainer.new()
	moral_row.add_theme_constant_override("separation", 8)
	container.add_child(moral_row)

	var virtue_label = Label.new()
	virtue_label.text = "Virtue:"
	virtue_label.add_theme_font_size_override("font_size", 11)
	moral_row.add_child(virtue_label)

	var virtue_spin = SpinBox.new()
	virtue_spin.min_value = -100
	virtue_spin.max_value = 100
	virtue_spin.step = 1
	virtue_spin.value = choices[index].get("virtue", 0)
	virtue_spin.custom_minimum_size = Vector2(70, 0)
	virtue_spin.value_changed.connect(_on_moral_value_changed.bind(index, "virtue"))
	moral_row.add_child(virtue_spin)

	var order_label = Label.new()
	order_label.text = "Order:"
	order_label.add_theme_font_size_override("font_size", 11)
	moral_row.add_child(order_label)

	var order_spin = SpinBox.new()
	order_spin.min_value = -100
	order_spin.max_value = 100
	order_spin.step = 1
	order_spin.value = choices[index].get("order", 0)
	order_spin.custom_minimum_size = Vector2(70, 0)
	order_spin.value_changed.connect(_on_moral_value_changed.bind(index, "order"))
	moral_row.add_child(order_spin)

	# Approval row: NPC ID + delta (hidden from player)
	var approval_row = HBoxContainer.new()
	approval_row.add_theme_constant_override("separation", 8)
	container.add_child(approval_row)

	var approval_label = Label.new()
	approval_label.text = "Approval:"
	approval_label.add_theme_font_size_override("font_size", 11)
	approval_row.add_child(approval_label)

	var npc_edit = LineEdit.new()
	npc_edit.placeholder_text = "npc_id"
	npc_edit.text = choices[index].get("approval_npc", "")
	npc_edit.custom_minimum_size = Vector2(80, 0)
	npc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_edit.text_changed.connect(_on_approval_npc_changed.bind(index))
	approval_row.add_child(npc_edit)

	var approval_spin = SpinBox.new()
	approval_spin.min_value = -100
	approval_spin.max_value = 100
	approval_spin.step = 1
	approval_spin.value = choices[index].get("approval", 0)
	approval_spin.custom_minimum_size = Vector2(70, 0)
	approval_spin.value_changed.connect(_on_moral_value_changed.bind(index, "approval"))
	approval_row.add_child(approval_spin)

	# ── Condition section ──
	_create_condition_ui(container, index)

	return container

func _create_condition_ui(container: VBoxContainer, index: int) -> void:
	"""Build inline condition controls for a single choice."""
	var cond_data = choices[index]
	var cond_type = cond_data.get("cond_type", ChoiceCondType.NONE) as int

	# Condition header row: type dropdown
	var cond_header = HBoxContainer.new()
	cond_header.add_theme_constant_override("separation", 8)
	container.add_child(cond_header)

	var cond_label = Label.new()
	cond_label.text = "If:"
	cond_label.add_theme_font_size_override("font_size", 11)
	cond_header.add_child(cond_label)

	var type_dropdown = OptionButton.new()
	type_dropdown.custom_minimum_size = Vector2(100, 0)
	for i in COND_TYPE_LABELS.size():
		type_dropdown.add_item(COND_TYPE_LABELS[i], i)
	type_dropdown.selected = cond_type
	type_dropdown.item_selected.connect(_on_cond_type_changed.bind(index))
	cond_header.add_child(type_dropdown)

	# For FLAG: show a "Set/Not Set" toggle
	if cond_type == ChoiceCondType.FLAG:
		var bool_dropdown = OptionButton.new()
		bool_dropdown.add_item("Set", 0)
		bool_dropdown.add_item("Not Set", 1)
		bool_dropdown.selected = 0 if cond_data.get("cond_bool", true) else 1
		bool_dropdown.item_selected.connect(_on_cond_bool_changed.bind(index))
		cond_header.add_child(bool_dropdown)

	# Condition detail row: key + operator + value (only for non-NONE types)
	if cond_type != ChoiceCondType.NONE:
		var cond_detail = HBoxContainer.new()
		cond_detail.add_theme_constant_override("separation", 4)
		container.add_child(cond_detail)

		# Spacer to align under "If:"
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(20, 0)
		cond_detail.add_child(spacer)

		# Key field (flag name, counter name, NPC ID)
		var key_edit = LineEdit.new()
		key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_edit.custom_minimum_size = Vector2(80, 0)
		key_edit.text = cond_data.get("cond_key", "")
		key_edit.text_changed.connect(_on_cond_key_changed.bind(index))
		cond_detail.add_child(key_edit)

		match cond_type:
			ChoiceCondType.FLAG:
				key_edit.placeholder_text = "flag_name"

			ChoiceCondType.COUNTER:
				key_edit.placeholder_text = "counter"
				_add_operator_and_value(cond_detail, index, cond_data)

			ChoiceCondType.RELATIONSHIP:
				key_edit.placeholder_text = "npc_id"
				_add_operator_and_value(cond_detail, index, cond_data)

			ChoiceCondType.APPROVAL:
				key_edit.placeholder_text = "npc_id"
				_add_operator_and_value(cond_detail, index, cond_data)

		# Show-when-locked + hint row
		var lock_row = HBoxContainer.new()
		lock_row.add_theme_constant_override("separation", 4)
		container.add_child(lock_row)

		var lock_spacer = Control.new()
		lock_spacer.custom_minimum_size = Vector2(20, 0)
		lock_row.add_child(lock_spacer)

		var lock_check = CheckBox.new()
		lock_check.text = "Show locked"
		lock_check.add_theme_font_size_override("font_size", 11)
		lock_check.button_pressed = cond_data.get("show_when_locked", false)
		lock_check.toggled.connect(_on_show_locked_changed.bind(index))
		lock_row.add_child(lock_check)

		var hint_edit = LineEdit.new()
		hint_edit.placeholder_text = "locked hint..."
		hint_edit.text = cond_data.get("locked_hint", "")
		hint_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_edit.custom_minimum_size = Vector2(60, 0)
		hint_edit.text_changed.connect(_on_locked_hint_changed.bind(index))
		lock_row.add_child(hint_edit)

func _add_operator_and_value(parent: HBoxContainer, index: int, cond_data: Dictionary) -> void:
	"""Add operator dropdown + value spinbox for numeric conditions."""
	var op_dropdown = OptionButton.new()
	op_dropdown.custom_minimum_size = Vector2(55, 0)
	for op in OPERATOR_OPTIONS:
		op_dropdown.add_item(op)
	var current_op = cond_data.get("cond_op", ">=")
	var op_idx = OPERATOR_OPTIONS.find(current_op)
	op_dropdown.selected = op_idx if op_idx >= 0 else 4  # Default >=
	op_dropdown.item_selected.connect(_on_cond_op_changed.bind(index))
	parent.add_child(op_dropdown)

	var val_spin = SpinBox.new()
	val_spin.min_value = -999
	val_spin.max_value = 999
	val_spin.step = 1
	val_spin.value = cond_data.get("cond_value", 0)
	val_spin.custom_minimum_size = Vector2(60, 0)
	val_spin.value_changed.connect(_on_cond_value_changed.bind(index))
	parent.add_child(val_spin)

# ============================================================================
# HANDLERS
# ============================================================================

func _on_add_pressed() -> void:
	if choices.size() >= MAX_CHOICES:
		return
	choices.append(_default_choice())
	_rebuild_all()
	_emit_modified()

func _on_remove_pressed(index: int) -> void:
	if choices.size() <= 1:
		return
	choices.remove_at(index)
	_rebuild_all()
	_emit_modified()

func _add_menu_deferred() -> void:
	if _bbcode_menu and not _bbcode_menu.is_inside_tree():
		EditorInterface.get_base_control().add_child(_bbcode_menu)

func _exit_tree() -> void:
	if _bbcode_menu and is_instance_valid(_bbcode_menu):
		_bbcode_menu.queue_free()
		_bbcode_menu = null

func _on_moral_value_changed(value: float, index: int, axis: String) -> void:
	if index >= 0 and index < choices.size():
		choices[index][axis] = int(value)
		_emit_modified()

func _on_approval_npc_changed(new_text: String, index: int) -> void:
	if index >= 0 and index < choices.size():
		choices[index]["approval_npc"] = new_text
		_emit_modified()

func _on_choice_text_changed(index: int, text_edit: TextEdit) -> void:
	if index >= 0 and index < choices.size():
		choices[index].label = text_edit.text
		_auto_resize_choice(text_edit)
		_emit_modified()

func _auto_resize_choice(text_edit: TextEdit) -> void:
	if not text_edit:
		return
	var line_count = text_edit.get_line_count()
	var line_height = text_edit.get_line_height()
	var target_lines = maxi(line_count + 1, 2)
	text_edit.custom_minimum_size.y = target_lines * line_height

func _on_choice_gui_input(event: InputEvent, text_edit: TextEdit) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if text_edit.has_selection() and _bbcode_menu:
			_bbcode_menu.show_for_text_edit(text_edit, self)
			text_edit.accept_event()

# ── Condition handlers ──

func _on_cond_type_changed(type_index: int, choice_index: int) -> void:
	if choice_index >= 0 and choice_index < choices.size():
		choices[choice_index]["cond_type"] = type_index
		# Reset condition fields when type changes
		choices[choice_index]["cond_key"] = ""
		choices[choice_index]["cond_op"] = ">="
		choices[choice_index]["cond_value"] = 0
		choices[choice_index]["cond_bool"] = true
		_rebuild_all()
		_emit_modified()

func _on_cond_key_changed(new_text: String, index: int) -> void:
	if index >= 0 and index < choices.size():
		choices[index]["cond_key"] = new_text
		_emit_modified()

func _on_cond_op_changed(op_index: int, index: int) -> void:
	if index >= 0 and index < choices.size():
		choices[index]["cond_op"] = OPERATOR_OPTIONS[op_index]
		_emit_modified()

func _on_cond_value_changed(value: float, index: int) -> void:
	if index >= 0 and index < choices.size():
		choices[index]["cond_value"] = int(value)
		_emit_modified()

func _on_cond_bool_changed(bool_index: int, index: int) -> void:
	if index >= 0 and index < choices.size():
		choices[index]["cond_bool"] = (bool_index == 0)
		_emit_modified()

func _on_show_locked_changed(pressed: bool, index: int) -> void:
	if index >= 0 and index < choices.size():
		choices[index]["show_when_locked"] = pressed
		_emit_modified()

func _on_locked_hint_changed(new_text: String, index: int) -> void:
	if index >= 0 and index < choices.size():
		choices[index]["locked_hint"] = new_text
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
		loaded = [_default_choice()]

	for c in loaded:
		choices.append(_parse_choice(c))

	_rebuild_all()

# ============================================================================
# PORT MAPPING
# ============================================================================

func get_output_port_for_choice(choice_index: int) -> int:
	"""Choice 0 is on port 1, choice 1 is on port 2, etc."""
	return choice_index + 1
