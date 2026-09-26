@tool
extends Window
## Draggable window for compositing multiple BBCode text effects onto selected
## text. Supports stacking effects, editing each effect's parameters, and
## previewing the combined result live.

# ============================================================================
# STYLE DEFINITIONS
# ============================================================================

## Each entry: {tag, group, params: [{name, default, type}]}
## type is "float" or "color". For color, name is "" (tag uses =value not key=value).
const STYLES: Array[Dictionary] = [
	# ── Built-in ──
	{"tag": "shake", "group": "built_in", "params": [
		{"name": "rate", "default": 10.0, "type": "float"},
		{"name": "level", "default": 5.0, "type": "float"},
	]},
	{"tag": "wave", "group": "built_in", "params": [
		{"name": "amp", "default": 30.0, "type": "float"},
		{"name": "freq", "default": 2.0, "type": "float"},
	]},
	{"tag": "rainbow", "group": "built_in", "params": [
		{"name": "freq", "default": 0.2, "type": "float"},
	]},
	{"tag": "color", "group": "built_in", "params": [
		{"name": "", "default": "#ff0000", "type": "color"},
	]},
	# ── Custom ──
	{"tag": "pulse", "group": "custom", "params": [
		{"name": "freq", "default": 2.0, "type": "float"},
		{"name": "amp", "default": 0.15, "type": "float"},
	]},
	{"tag": "appear", "group": "custom", "params": [
		{"name": "speed", "default": 10.0, "type": "float"},
	]},
	{"tag": "tremble", "group": "custom", "params": [
		{"name": "rate", "default": 15.0, "type": "float"},
		{"name": "amp", "default": 2.0, "type": "float"},
	]},
	{"tag": "ghost", "group": "custom", "params": [
		{"name": "freq", "default": 1.0, "type": "float"},
		{"name": "min", "default": 0.3, "type": "float"},
	]},
	{"tag": "ember", "group": "custom", "params": [
		{"name": "rate", "default": 3.0, "type": "float"},
		{"name": "amp", "default": 0.15, "type": "float"},
	]},
	{"tag": "frost", "group": "custom", "params": [
		{"name": "drift", "default": 1.0, "type": "float"},
		{"name": "amp", "default": 0.5, "type": "float"},
	]},
	{"tag": "zap", "group": "custom", "params": [
		{"name": "rate", "default": 20.0, "type": "float"},
		{"name": "amp", "default": 4.0, "type": "float"},
	]},
	{"tag": "toxic", "group": "custom", "params": [
		{"name": "rate", "default": 1.0, "type": "float"},
		{"name": "amp", "default": 3.0, "type": "float"},
	]},
	{"tag": "shadow", "group": "custom", "params": [
		{"name": "lag", "default": 0.15, "type": "float"},
		{"name": "amp", "default": 2.0, "type": "float"},
	]},
	{"tag": "whisper", "group": "custom", "params": []},
	{"tag": "shout", "group": "custom", "params": [
		{"name": "amp", "default": 0.12, "type": "float"},
		{"name": "rate", "default": 8.0, "type": "float"},
	]},
	{"tag": "impact", "group": "custom", "params": [
		{"name": "duration", "default": 0.5, "type": "float"},
		{"name": "bounce", "default": 1.3, "type": "float"},
	]},
	{"tag": "heartbeat", "group": "custom", "params": [
		{"name": "bpm", "default": 72.0, "type": "float"},
	]},
	{"tag": "glitch", "group": "custom", "params": [
		{"name": "rate", "default": 3.0, "type": "float"},
		{"name": "amp", "default": 5.0, "type": "float"},
	]},
	{"tag": "fade_pulse", "group": "custom", "params": [
		{"name": "freq", "default": 1.0, "type": "float"},
		{"name": "min", "default": 0.3, "type": "float"},
	]},
]

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var style_dropdown: OptionButton = %StyleDropdown
@onready var add_button: Button = %AddButton
@onready var stack_container: VBoxContainer = %StackContainer
@onready var preview_label: RichTextLabel = %PreviewLabel
@onready var apply_button: Button = %ApplyButton
@onready var remove_all_button: Button = %RemoveAllButton
@onready var close_button: Button = %CloseButton

# ============================================================================
# STATE
# ============================================================================

var _target_text_edit: TextEdit = null
var _target_line_edit: LineEdit = null
var _selected_text: String = ""  # cached at open time

## [{style_index: int, param_values: Dictionary}]
var _effect_stack: Array[Dictionary] = []

## Maps dropdown item index → STYLES array index (skipping separators)
var _dropdown_to_style: Array[int] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if add_button:
		add_button.pressed.connect(_on_add_pressed)
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	if remove_all_button:
		remove_all_button.pressed.connect(_on_remove_all_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	close_requested.connect(_on_close_pressed)

	# Register custom BBCode effects on the preview
	if preview_label:
		DialogueTextEffects.register_all(preview_label)

	_populate_dropdown()

func _populate_dropdown() -> void:
	if not style_dropdown:
		return
	style_dropdown.clear()
	_dropdown_to_style.clear()

	var prev_group := ""
	for i in STYLES.size():
		var style = STYLES[i]
		if style.group != prev_group and prev_group != "":
			style_dropdown.add_separator("── Custom ──")
			_dropdown_to_style.append(-1)
		prev_group = style.group

		style_dropdown.add_item(style.tag)
		_dropdown_to_style.append(i)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_for_text_edit(target: TextEdit, anchor_node: Control) -> void:
	_target_text_edit = target
	_target_line_edit = null
	_selected_text = target.get_selected_text() if target.has_selection() else "Sample Text"
	_update_preview()
	_show_above_node(anchor_node)

func show_for_line_edit(target: LineEdit, anchor_node: Control) -> void:
	_target_line_edit = target
	_target_text_edit = null
	_selected_text = target.get_selected_text() if target.has_selection() else "Sample Text"
	_update_preview()
	_show_above_node(anchor_node)

func _show_above_node(anchor_node: Control) -> void:
	var node_screen_pos = anchor_node.get_screen_position()
	var popup_pos = Vector2i(node_screen_pos) + Vector2i(0, -size.y - 8)
	popup_pos.y = maxi(popup_pos.y, 4)
	position = popup_pos
	show()

# ============================================================================
# EFFECT STACK MANAGEMENT
# ============================================================================

func _on_add_pressed() -> void:
	if not style_dropdown:
		return
	var dropdown_idx = style_dropdown.selected
	if dropdown_idx < 0 or dropdown_idx >= _dropdown_to_style.size():
		return
	var style_idx = _dropdown_to_style[dropdown_idx]
	if style_idx < 0:
		return

	var style = STYLES[style_idx]
	var param_values := {}
	for p in style.params:
		param_values[p.name] = p["default"]

	_effect_stack.append({"style_index": style_idx, "param_values": param_values})
	_rebuild_stack_ui()
	_update_preview()

func _remove_effect(index: int) -> void:
	if index >= 0 and index < _effect_stack.size():
		_effect_stack.remove_at(index)
		_rebuild_stack_ui()
		_update_preview()

func _rebuild_stack_ui() -> void:
	if not stack_container:
		return

	# Clear existing rows
	for child in stack_container.get_children():
		stack_container.remove_child(child)
		child.queue_free()

	if _effect_stack.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No effects added yet"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		stack_container.add_child(empty_label)
		return

	for i in _effect_stack.size():
		var effect = _effect_stack[i]
		var style = STYLES[effect.style_index]
		var row = _create_effect_row(i, style, effect.param_values)
		stack_container.add_child(row)

func _create_effect_row(index: int, style: Dictionary, param_values: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	# Panel background for visual grouping
	var panel = PanelContainer.new()
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 4)
	panel.add_child(inner_vbox)
	container.add_child(panel)

	# Header row: tag name + remove button
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	inner_vbox.add_child(header_row)

	var tag_label = Label.new()
	tag_label.text = style.tag
	tag_label.add_theme_font_size_override("font_size", 13)
	tag_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	tag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(tag_label)

	var remove_btn = Button.new()
	remove_btn.text = "×"
	remove_btn.custom_minimum_size = Vector2(28, 0)
	remove_btn.pressed.connect(_remove_effect.bind(index))
	header_row.add_child(remove_btn)

	# Parameter rows
	for p in style.params:
		var param_row = HBoxContainer.new()
		param_row.add_theme_constant_override("separation", 6)
		inner_vbox.add_child(param_row)

		if p.type == "color":
			var color_label = Label.new()
			color_label.text = "color:"
			color_label.add_theme_font_size_override("font_size", 11)
			param_row.add_child(color_label)

			var color_edit = LineEdit.new()
			color_edit.text = str(param_values.get(p.name, p["default"]))
			color_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			color_edit.custom_minimum_size = Vector2(80, 0)
			color_edit.placeholder_text = "#rrggbb"
			color_edit.text_changed.connect(_on_param_text_changed.bind(index, p.name))
			param_row.add_child(color_edit)
		else:
			# Float parameter
			var param_label = Label.new()
			param_label.text = "%s:" % p.name
			param_label.add_theme_font_size_override("font_size", 11)
			param_label.custom_minimum_size = Vector2(50, 0)
			param_row.add_child(param_label)

			var spin = SpinBox.new()
			spin.min_value = 0.0
			spin.max_value = 9999.0
			spin.step = 0.01
			spin.value = float(param_values.get(p.name, p["default"]))
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(_on_param_value_changed.bind(index, p.name))
			param_row.add_child(spin)

	return container

# ============================================================================
# PARAMETER CHANGE HANDLERS
# ============================================================================

func _on_param_value_changed(new_value: float, effect_index: int, param_name: String) -> void:
	if effect_index >= 0 and effect_index < _effect_stack.size():
		_effect_stack[effect_index].param_values[param_name] = new_value
		_update_preview()

func _on_param_text_changed(new_text: String, effect_index: int, param_name: String) -> void:
	if effect_index >= 0 and effect_index < _effect_stack.size():
		_effect_stack[effect_index].param_values[param_name] = new_text
		_update_preview()

# ============================================================================
# PREVIEW
# ============================================================================

func _update_preview() -> void:
	if not preview_label:
		return

	var text = _selected_text if _selected_text != "" else "Sample Text"
	var bbcode = _build_stacked_bbcode(text)
	preview_label.text = bbcode

func _build_stacked_bbcode(inner_text: String) -> String:
	"""Build nested BBCode: first effect in stack = outermost wrapper."""
	var result = inner_text
	# Wrap from last to first so first effect is outermost
	for i in range(_effect_stack.size() - 1, -1, -1):
		var effect = _effect_stack[i]
		var style = STYLES[effect.style_index]
		var open_tag = _build_open_tag(style, effect.param_values)
		var close_tag = "[/%s]" % style.tag
		result = open_tag + result + close_tag
	return result

func _build_open_tag(style: Dictionary, param_values: Dictionary) -> String:
	var tag = style.tag
	var parts: Array[String] = []

	for p in style.params:
		var val = param_values.get(p.name, p["default"])
		if p.type == "color":
			# Color tag uses [color=#hex] format (no space-separated key)
			return "[%s=%s]" % [tag, str(val)]
		else:
			# Format float nicely — strip trailing zeros
			var val_str = _format_number(float(val))
			parts.append("%s=%s" % [p.name, val_str])

	if parts.is_empty():
		return "[%s]" % tag
	return "[%s %s]" % [tag, " ".join(parts)]

func _format_number(val: float) -> String:
	"""Format a number: use int form if whole, otherwise trim trailing zeros."""
	if val == int(val):
		return str(int(val))
	# Up to 2 decimal places, strip trailing zeros
	var s = "%.2f" % val
	s = s.rstrip("0").rstrip(".")
	return s

# ============================================================================
# APPLY
# ============================================================================

func _on_apply_pressed() -> void:
	if _effect_stack.is_empty():
		return

	var selected = _get_selected_text()
	if selected == "":
		return

	var wrapped = _build_stacked_bbcode(selected)

	if _target_text_edit:
		_apply_to_text_edit(wrapped)
	elif _target_line_edit:
		_apply_to_line_edit(wrapped)

func _apply_to_text_edit(wrapped: String) -> void:
	if not _target_text_edit or not _target_text_edit.has_selection():
		return

	var from_line = _target_text_edit.get_selection_from_line()
	var from_col = _target_text_edit.get_selection_from_column()
	var to_line = _target_text_edit.get_selection_to_line()
	var to_col = _target_text_edit.get_selection_to_column()

	_target_text_edit.begin_complex_operation()
	_target_text_edit.select(from_line, from_col, to_line, to_col)
	_target_text_edit.delete_selection()
	_target_text_edit.insert_text_at_caret(wrapped)
	_target_text_edit.end_complex_operation()
	_target_text_edit.text_changed.emit()

func _apply_to_line_edit(wrapped: String) -> void:
	if not _target_line_edit or not _target_line_edit.has_selection():
		return

	var full_text = _target_line_edit.text
	var sel_start = _target_line_edit.get_selection_from_column()
	var sel_end = sel_start + _target_line_edit.get_selected_text().length()

	var before = full_text.substr(0, sel_start)
	var after = full_text.substr(sel_end)

	_target_line_edit.text = before + wrapped + after
	_target_line_edit.text_changed.emit(_target_line_edit.text)

# ============================================================================
# REMOVE ALL
# ============================================================================

func _on_remove_all_pressed() -> void:
	if _effect_stack.is_empty():
		return

	var selected = _get_selected_text()
	if selected == "":
		return

	# Strip each effect's tags from the selected text
	var stripped = selected
	for effect in _effect_stack:
		var style = STYLES[effect.style_index]
		stripped = _strip_bbcode_tag(stripped, style.tag)

	if stripped == selected:
		return  # Nothing changed

	if _target_text_edit:
		_apply_to_text_edit(stripped)
	elif _target_line_edit:
		_apply_to_line_edit(stripped)

func _strip_bbcode_tag(text: String, tag_name: String) -> String:
	"""Strip all matching BBCode tag pairs from text (outermost first)."""
	var regex = RegEx.new()
	var pattern = "\\[%s[^\\]]*\\](.*?)\\[/%s\\]" % [tag_name, tag_name]
	regex.compile(pattern)
	var result = regex.sub(text, "$1", true)
	return result

# ============================================================================
# HELPERS
# ============================================================================

func _get_selected_text() -> String:
	if _target_text_edit and _target_text_edit.has_selection():
		return _target_text_edit.get_selected_text()
	elif _target_line_edit and _target_line_edit.has_selection():
		return _target_line_edit.get_selected_text()
	return ""

func _on_close_pressed() -> void:
	hide()
