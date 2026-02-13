@tool
extends VBoxContainer
## Affix Builder Dock — visual tool for creating Affix .tres files.
## Solves the Godot 4.x Inspector bug where Dictionary edits don't persist.

# ============================================================================
# EXTERNAL REFERENCES
# ============================================================================
var editor_interface  ## Set by plugin.gd

# ============================================================================
# CATEGORY DATA — built from Affix.Category enum at runtime
# ============================================================================
var _category_names: Array[String] = []
var _category_values: Array[int] = []

# ============================================================================
# PRESET TEMPLATES
# ============================================================================
const PRESETS = {
	"Skill Rank Bonus (+N to skill)": {
		"category": "SKILL_RANK_BONUS",
		"number": 1.0,
		"data": {"skill_id": ""},
		"name_tpl": "+%d to %s",
		"desc_tpl": "Grants +%d rank to %s",
	},
	"Tree Rank Bonus (+N to tree)": {
		"category": "TREE_SKILL_RANK_BONUS",
		"number": 1.0,
		"data": {"tree_id": ""},
		"name_tpl": "+%d to all %s skills",
		"desc_tpl": "Grants +%d to all skills in the %s tree",
	},
	"Class Rank Bonus (+N to class)": {
		"category": "CLASS_SKILL_RANK_BONUS",
		"number": 1.0,
		"data": {"class_id": ""},
		"name_tpl": "+%d to all %s skills",
		"desc_tpl": "Grants +%d to all %s class skills",
	},
	"Tag Rank Bonus (+N by tag)": {
		"category": "TAG_SKILL_RANK_BONUS",
		"number": 1.0,
		"data": {"tag": ""},
		"name_tpl": "+%d to all [%s] skills",
		"desc_tpl": "Grants +%d rank to all skills tagged [%s]",
	},
	"Action Damage Bonus": {
		"category": "ACTION_DAMAGE_BONUS",
		"number": 5.0,
		"data": {"action_id": ""},
		"name_tpl": "+%d damage to %s",
		"desc_tpl": "+%d flat damage to %s",
	},
	"Action Damage Multiplier": {
		"category": "ACTION_DAMAGE_MULTIPLIER",
		"number": 1.15,
		"data": {"action_id": ""},
		"name_tpl": "×%.2f damage to %s",
		"desc_tpl": "×%.2f damage multiplier on %s",
	},
	"Action Base Damage Bonus": {
		"category": "ACTION_BASE_DAMAGE_BONUS",
		"number": 3.0,
		"data": {"action_id": ""},
		"name_tpl": "+%d base damage to %s",
		"desc_tpl": "+%d base damage (pre-multiplier) to %s",
	},
	"Action Die Slot Bonus": {
		"category": "ACTION_DIE_SLOT_BONUS",
		"number": 1.0,
		"data": {"action_id": ""},
		"name_tpl": "+%d die slot to %s",
		"desc_tpl": "+%d die slot(s) on %s",
	},
	"Fire Damage Bonus": {
		"category": "FIRE_DAMAGE_BONUS",
		"number": 5.0,
		"data": {},
		"name_tpl": "+%d Fire Damage",
		"desc_tpl": "+%d fire damage",
	},
	"Proc: On Deal Damage": {
		"category": "PROC",
		"number": 0.15,
		"data": {"proc_trigger": "ON_DEAL_DAMAGE", "proc_effect": "apply_status", "status_id": "", "stacks": 1},
	},
	"Blank (empty)": {
		"category": "NONE",
		"number": 0.0,
		"data": {},
	},
}

# ============================================================================
# UI NODES
# ============================================================================
var _scroll: ScrollContainer
var _content: VBoxContainer

# Save section
var _save_path_edit: LineEdit
var _save_path_button: Button

# Preset
var _preset_button: OptionButton

# Basic fields
var _name_edit: LineEdit
var _desc_edit: TextEdit
var _category_option: OptionButton
var _effect_number_spin: SpinBox

# Scaling fields
var _effect_min_spin: SpinBox
var _effect_max_spin: SpinBox

# Tags
var _tags_edit: LineEdit

# Effect data
var _data_container: VBoxContainer
var _data_rows: Array[Dictionary] = []  # [{key: LineEdit, value: LineEdit, type: OptionButton, hbox: HBoxContainer}]
var _add_data_button: Button

# Granted Action
var _action_path_edit: LineEdit

# Bottom buttons
var _save_button: Button
var _load_button: Button
var _clear_button: Button
var _status_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_build_category_lists()
	_build_ui()

func _build_category_lists():
	"""Pull category names and values from the Affix enum."""
	var keys = Affix.Category.keys()
	var vals = Affix.Category.values()
	for i in range(keys.size()):
		_category_names.append(keys[i])
		_category_values.append(vals[i])

# ============================================================================
# UI CONSTRUCTION
# ============================================================================

func _build_ui():
	# Scroll wrapper
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	# ── Preset ──
	_add_section_label("Template")
	_preset_button = OptionButton.new()
	_preset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx = 0
	for key in PRESETS:
		_preset_button.add_item(key, idx)
		idx += 1
	_preset_button.item_selected.connect(_on_preset_selected)
	_content.add_child(_preset_button)
	_add_spacer(8)

	# ── Save Path ──
	_add_section_label("Save Path")
	var path_hbox = HBoxContainer.new()
	path_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_path_edit = LineEdit.new()
	_save_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_path_edit.placeholder_text = "res://resources/affixes/..."
	_save_path_edit.text = "res://resources/affixes/test/new_affix.tres"
	path_hbox.add_child(_save_path_edit)
	_content.add_child(path_hbox)
	_add_spacer(8)

	# ── Basic Info ──
	_add_section_label("Basic Info")

	_add_field_label("Affix Name")
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "e.g. +1 to Kindling"
	_content.add_child(_name_edit)

	_add_field_label("Description")
	_desc_edit = TextEdit.new()
	_desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc_edit.custom_minimum_size.y = 48
	_desc_edit.placeholder_text = "e.g. Grants +1 rank to Kindling"
	_content.add_child(_desc_edit)
	_add_spacer(8)

	# ── Category ──
	_add_section_label("Category")
	_category_option = OptionButton.new()
	_category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(_category_names.size()):
		_category_option.add_item(_category_names[i], _category_values[i])
	_content.add_child(_category_option)
	_add_spacer(8)

	# ── Effect Number ──
	_add_section_label("Effect Number")
	_effect_number_spin = SpinBox.new()
	_effect_number_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_number_spin.min_value = -9999.0
	_effect_number_spin.max_value = 9999.0
	_effect_number_spin.step = 0.01
	_effect_number_spin.allow_greater = true
	_content.add_child(_effect_number_spin)
	_add_spacer(8)

	# ── Scaling (min/max) ──
	_add_section_label("Scaling (0 = no scaling)")
	var scale_hbox = HBoxContainer.new()
	scale_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_add_inline_label(scale_hbox, "Min:")
	_effect_min_spin = SpinBox.new()
	_effect_min_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_min_spin.min_value = 0.0
	_effect_min_spin.max_value = 9999.0
	_effect_min_spin.step = 0.01
	scale_hbox.add_child(_effect_min_spin)

	_add_inline_label(scale_hbox, "Max:")
	_effect_max_spin = SpinBox.new()
	_effect_max_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_max_spin.min_value = 0.0
	_effect_max_spin.max_value = 9999.0
	_effect_max_spin.step = 0.01
	scale_hbox.add_child(_effect_max_spin)

	_content.add_child(scale_hbox)
	_add_spacer(8)

	# ── Tags ──
	_add_section_label("Tags (comma-separated)")
	_tags_edit = LineEdit.new()
	_tags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tags_edit.placeholder_text = "e.g. mage, flame, fire_damage"
	_content.add_child(_tags_edit)
	_add_spacer(8)

	# ── Effect Data (Dictionary) ──
	_add_section_label("Effect Data (Dictionary)")
	_data_container = VBoxContainer.new()
	_data_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_data_container)

	_add_data_button = Button.new()
	_add_data_button.text = "+ Add Key"
	_add_data_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add_data_button.pressed.connect(_on_add_data_row)
	_content.add_child(_add_data_button)
	_add_spacer(8)

	# ── Granted Action Path ──
	_add_section_label("Granted Action (optional)")
	_action_path_edit = LineEdit.new()
	_action_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_path_edit.placeholder_text = "res://resources/actions/... (leave blank if none)"
	_content.add_child(_action_path_edit)
	_add_spacer(16)

	# ── Buttons ──
	var btn_hbox = HBoxContainer.new()
	btn_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_save_button = Button.new()
	_save_button.text = "💾 Save Affix"
	_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_button.pressed.connect(_on_save_pressed)
	btn_hbox.add_child(_save_button)

	_load_button = Button.new()
	_load_button.text = "📂 Load .tres"
	_load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_button.pressed.connect(_on_load_pressed)
	btn_hbox.add_child(_load_button)

	_clear_button = Button.new()
	_clear_button.text = "🗑 Clear"
	_clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_button.pressed.connect(_on_clear_pressed)
	btn_hbox.add_child(_clear_button)

	_content.add_child(btn_hbox)
	_add_spacer(4)

	# Status label
	_status_label = Label.new()
	_status_label.text = "Ready"
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_content.add_child(_status_label)

# ============================================================================
# EFFECT DATA ROWS
# ============================================================================

func _on_add_data_row(key: String = "", value: String = "", type_idx: int = 0):
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Type selector
	var type_opt = OptionButton.new()
	type_opt.add_item("String", 0)
	type_opt.add_item("Int", 1)
	type_opt.add_item("Float", 2)
	type_opt.custom_minimum_size.x = 70
	type_opt.select(type_idx)
	hbox.add_child(type_opt)

	# Key
	var key_edit = LineEdit.new()
	key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_edit.placeholder_text = "key"
	key_edit.text = key
	hbox.add_child(key_edit)

	# Value
	var val_edit = LineEdit.new()
	val_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_edit.placeholder_text = "value"
	val_edit.text = value
	hbox.add_child(val_edit)

	# Delete button
	var del_btn = Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size.x = 28
	del_btn.pressed.connect(_on_delete_data_row.bind(hbox))
	hbox.add_child(del_btn)

	_data_container.add_child(hbox)
	_data_rows.append({"hbox": hbox, "key": key_edit, "value": val_edit, "type": type_opt})

func _on_delete_data_row(hbox: HBoxContainer):
	for i in range(_data_rows.size()):
		if _data_rows[i]["hbox"] == hbox:
			_data_rows.remove_at(i)
			break
	hbox.queue_free()

func _clear_data_rows():
	for row in _data_rows:
		if is_instance_valid(row["hbox"]):
			row["hbox"].queue_free()
	_data_rows.clear()

func _collect_effect_data() -> Dictionary:
	"""Read all data rows into a Dictionary with proper types."""
	var result: Dictionary = {}
	for row in _data_rows:
		if not is_instance_valid(row["hbox"]):
			continue
		var k: String = row["key"].text.strip_edges()
		var v_raw: String = row["value"].text.strip_edges()
		if k.is_empty():
			continue

		var type_idx: int = row["type"].selected
		match type_idx:
			0:  # String
				result[k] = v_raw
			1:  # Int
				result[k] = int(v_raw) if v_raw.is_valid_int() else 0
			2:  # Float
				result[k] = float(v_raw) if v_raw.is_valid_float() else 0.0
	return result

# ============================================================================
# PRESETS
# ============================================================================

func _on_preset_selected(index: int):
	var preset_name = _preset_button.get_item_text(index)
	if preset_name not in PRESETS:
		return

	var preset = PRESETS[preset_name]

	# Set category
	var cat_name: String = preset.get("category", "NONE")
	for i in range(_category_names.size()):
		if _category_names[i] == cat_name:
			_category_option.select(i)
			break

	# Set effect number
	_effect_number_spin.value = preset.get("number", 0.0)

	# Set effect data rows
	_clear_data_rows()
	var data: Dictionary = preset.get("data", {})
	for key in data:
		var val = data[key]
		var type_idx = 0  # String
		var val_str = str(val)
		if val is int:
			type_idx = 1
		elif val is float:
			type_idx = 2
		_on_add_data_row(key, val_str, type_idx)

	_set_status("Template loaded: %s — fill in values and save" % preset_name)

# ============================================================================
# SAVE
# ============================================================================

func _on_save_pressed():
	var path = _save_path_edit.text.strip_edges()
	if path.is_empty() or not path.begins_with("res://"):
		_set_status("❌ Invalid save path", Color.RED)
		return

	if not path.ends_with(".tres"):
		path += ".tres"
		_save_path_edit.text = path

	# Build the affix
	var affix = Affix.new()
	affix.affix_name = _name_edit.text.strip_edges()
	affix.description = _desc_edit.text.strip_edges()

	# Category
	var cat_idx = _category_option.selected
	if cat_idx >= 0 and cat_idx < _category_values.size():
		affix.category = _category_values[cat_idx]

	# Effect number
	affix.effect_number = _effect_number_spin.value

	# Scaling
	affix.effect_min = _effect_min_spin.value
	affix.effect_max = _effect_max_spin.value

	# Tags
	var tags_text = _tags_edit.text.strip_edges()
	if not tags_text.is_empty():
		var typed_tags: Array[String] = []
		for t in tags_text.split(","):
			var tag = t.strip_edges()
			if not tag.is_empty():
				typed_tags.append(tag)
		affix.tags = typed_tags

	# Effect data
	affix.effect_data = _collect_effect_data()

	# Granted action
	var action_path = _action_path_edit.text.strip_edges()
	if not action_path.is_empty() and ResourceLoader.exists(action_path):
		var action_res = load(action_path)
		if action_res is Action:
			affix.granted_action = action_res

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	# Claim the path so Godot's cache maps this instance to the file
	affix.take_over_path(path)

	# Save
	var err = ResourceSaver.save(affix, path)
	if err == OK:
		_set_status("✅ Saved: %s" % path, Color.GREEN)
		print("✅ AffixBuilder saved: %s" % path)
		print("   effect_data = %s" % [affix.effect_data])
		# Refresh filesystem so editor sees it
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
	else:
		_set_status("❌ Save failed (error %d)" % err, Color.RED)

# ============================================================================
# LOAD
# ============================================================================

func _on_load_pressed():
	# Open a file dialog
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.tres ; Affix Resource"])
	dialog.current_dir = "res://resources/affixes/"
	dialog.size = Vector2i(600, 400)
	dialog.file_selected.connect(_on_file_selected)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

func _on_file_selected(path: String):
	# Clean up dialog
	for child in get_children():
		if child is FileDialog:
			child.queue_free()

	# Load the resource fresh (bypass cache)
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not res or not res is Affix:
		_set_status("❌ Not a valid Affix: %s" % path, Color.RED)
		return

	var affix: Affix = res

	# Populate fields
	_save_path_edit.text = path
	_name_edit.text = affix.affix_name
	_desc_edit.text = affix.description
	_effect_number_spin.value = affix.effect_number
	_effect_min_spin.value = affix.effect_min
	_effect_max_spin.value = affix.effect_max

	# Category
	for i in range(_category_values.size()):
		if _category_values[i] == affix.category:
			_category_option.select(i)
			break

	# Tags
	_tags_edit.text = ", ".join(affix.tags)

	# Effect data
	_clear_data_rows()
	for key in affix.effect_data:
		var val = affix.effect_data[key]
		var type_idx = 0
		if val is int:
			type_idx = 1
		elif val is float:
			type_idx = 2
		_on_add_data_row(key, str(val), type_idx)

	# Granted action
	if affix.granted_action:
		_action_path_edit.text = affix.granted_action.resource_path
	else:
		_action_path_edit.text = ""

	_set_status("📂 Loaded: %s (%d data keys)" % [path, affix.effect_data.size()], Color.CYAN)

# ============================================================================
# CLEAR
# ============================================================================

func _on_clear_pressed():
	_name_edit.text = ""
	_desc_edit.text = ""
	_category_option.select(0)
	_effect_number_spin.value = 0.0
	_effect_min_spin.value = 0.0
	_effect_max_spin.value = 0.0
	_tags_edit.text = ""
	_clear_data_rows()
	_action_path_edit.text = ""
	_save_path_edit.text = "res://resources/affixes/test/new_affix.tres"
	_set_status("Cleared", Color(0.6, 0.6, 0.6))

# ============================================================================
# UI HELPERS
# ============================================================================

func _add_section_label(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	label.add_theme_font_size_override("font_size", 13)
	_content.add_child(label)

func _add_field_label(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_content.add_child(label)

func _add_inline_label(parent: Control, text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	parent.add_child(label)

func _add_spacer(height: float):
	var spacer = Control.new()
	spacer.custom_minimum_size.y = height
	_content.add_child(spacer)

func _set_status(text: String, color: Color = Color(0.6, 0.6, 0.6)):
	if _status_label:
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", color)
