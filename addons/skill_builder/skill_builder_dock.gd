@tool
extends Control

# ============================================================================
# SKILL BUILDER DOCK
# ============================================================================
# Visual editor for SkillResource .tres files.
# Features:
#   - Templates for common skill patterns
#   - Load existing .tres (CACHE_MODE_IGNORE for fresh reads)
#   - Dynamic prerequisite list with file browsing
#   - 5 rank affix sections with file browsing
#   - Auto-generate skill_id from name
#   - Validation before save
#   - take_over_path for cache busting
# ============================================================================

# ============================================================================
# STATE — UI references
# ============================================================================

# Toolbar
var _template_btn: OptionButton
var _status_label: Label

# Save / Load
var _save_path_edit: LineEdit
var _load_path_label: Label  # Shows currently loaded file

# Basic Info
var _skill_id_edit: LineEdit
var _skill_name_edit: LineEdit
var _description_edit: TextEdit
var _icon_path_edit: LineEdit

# Tree Position
var _tier_spin: SpinBox
var _column_spin: SpinBox
var _cost_spin: SpinBox

# Requirements
var _tree_points_spin: SpinBox
var _prereqs_container: VBoxContainer  # Holds prerequisite rows
var _add_prereq_btn: Button

# Rank Affixes — one container per rank (index 0 = rank 1)
var _rank_containers: Array[VBoxContainer] = []
var _rank_add_btns: Array[Button] = []

# File Dialog
var _file_dialog: EditorFileDialog
var _dialog_target: LineEdit = null
var _dialog_mode: String = ""  # "open", "save", "load", "load_tree"

# Skill Picker (for loading from tree)
var _skill_picker: AcceptDialog
var _skill_picker_list: ItemList
var _skill_picker_skills: Array = []  # Holds SkillResource refs for picker

# Track the source tree for context
var _source_tree: SkillTree = null

# ============================================================================
# CONSTANTS
# ============================================================================
const MAX_RANKS := 5
const SECTION_COLOR := Color(0.7, 0.85, 1.0)
const HEADER_COLOR := Color(1.0, 0.85, 0.4)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_build_file_dialog()
	_build_ui()
	tree_exiting.connect(_cleanup)

func _cleanup():
	if _skill_picker and is_instance_valid(_skill_picker):
		_skill_picker.queue_free()
		_skill_picker = null

func _build_file_dialog():
	_file_dialog = EditorFileDialog.new()
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.file_selected.connect(_on_file_dialog_selected)
	add_child(_file_dialog)

	# Skill picker popup — shown after loading a SkillTree
	# Must be parented to editor base control, not the dock, to display properly
	_skill_picker = AcceptDialog.new()
	_skill_picker.title = "Pick a Skill"
	_skill_picker.min_size = Vector2i(500, 500)
	_skill_picker.ok_button_text = "Load"
	_skill_picker.confirmed.connect(_on_skill_picker_confirmed)

	var picker_vbox = VBoxContainer.new()
	_skill_picker.add_child(picker_vbox)

	var picker_label = Label.new()
	picker_label.text = "Select a skill to load into the builder:"
	picker_vbox.add_child(picker_label)

	_skill_picker_list = ItemList.new()
	_skill_picker_list.size_flags_vertical = SIZE_EXPAND_FILL
	_skill_picker_list.custom_minimum_size.y = 400
	_skill_picker_list.item_activated.connect(func(_idx): _on_skill_picker_confirmed())
	picker_vbox.add_child(_skill_picker_list)

	EditorInterface.get_base_control().add_child(_skill_picker)

# ============================================================================
# UI BUILDING
# ============================================================================

func _build_ui():
	# Main scroll
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(main_vbox)

	# -- Toolbar --
	main_vbox.add_child(_build_toolbar())
	main_vbox.add_child(_build_save_load_row())
	main_vbox.add_child(HSeparator.new())

	# -- Basic Info --
	main_vbox.add_child(_make_section_header("📋 Basic Info"))
	main_vbox.add_child(_build_basic_info_section())
	main_vbox.add_child(HSeparator.new())

	# -- Tree Position --
	main_vbox.add_child(_make_section_header("🌳 Tree Position"))
	main_vbox.add_child(_build_tree_position_section())
	main_vbox.add_child(HSeparator.new())

	# -- Requirements --
	main_vbox.add_child(_make_section_header("🔒 Requirements"))
	main_vbox.add_child(_build_requirements_section())
	main_vbox.add_child(HSeparator.new())

	# -- Rank Affix Sections --
	var rank_colors := [
		Color(0.6, 0.9, 0.6),   # Rank 1 — green
		Color(0.5, 0.7, 1.0),   # Rank 2 — blue
		Color(0.9, 0.7, 0.4),   # Rank 3 — orange
		Color(0.8, 0.5, 0.9),   # Rank 4 — purple
		Color(1.0, 0.85, 0.3),  # Rank 5 — gold
	]
	for i in range(MAX_RANKS):
		var rank_num = i + 1
		var header = _make_section_header("⭐ Rank %d Affixes" % rank_num, rank_colors[i])
		main_vbox.add_child(header)
		main_vbox.add_child(_build_rank_section(i))
		if i < MAX_RANKS - 1:
			main_vbox.add_child(HSeparator.new())

	# -- Status --
	main_vbox.add_child(HSeparator.new())
	_status_label = Label.new()
	_status_label.text = "Ready"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_label)

# ── Toolbar ──

func _build_toolbar() -> HBoxContainer:
	var hbox = HBoxContainer.new()

	# Template selector
	_template_btn = OptionButton.new()
	_template_btn.add_item("Template...")
	_template_btn.add_item("Blank")
	_template_btn.add_item("T1 Unlock Skill")
	_template_btn.add_item("Multi-Rank Passive")
	_template_btn.add_item("Action Skill (1 rank)")
	_template_btn.add_item("Crossover Node")
	_template_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_template_btn.item_selected.connect(_on_template_selected)
	hbox.add_child(_template_btn)

	# Load button (standalone skill)
	var load_btn = Button.new()
	load_btn.text = "📂 Load"
	load_btn.tooltip_text = "Load standalone SkillResource .tres"
	load_btn.pressed.connect(_on_load_pressed)
	hbox.add_child(load_btn)

	# Load from Tree button
	var load_tree_btn = Button.new()
	load_tree_btn.text = "🌳 From Tree"
	load_tree_btn.tooltip_text = "Pick a skill from inside a SkillTree .tres"
	load_tree_btn.pressed.connect(_on_load_from_tree_pressed)
	hbox.add_child(load_tree_btn)

	# Save button
	var save_btn = Button.new()
	save_btn.text = "💾 Save"
	save_btn.pressed.connect(_on_save_pressed)
	hbox.add_child(save_btn)

	# Extract All button
	var extract_all_btn = Button.new()
	extract_all_btn.text = "📤 Extract All"
	extract_all_btn.tooltip_text = "Extract all inline sub-resource affixes to standalone .tres files"
	extract_all_btn.pressed.connect(_on_extract_all_pressed)
	hbox.add_child(extract_all_btn)

	return hbox

# ── Save / Load Row ──

func _build_save_load_row() -> VBoxContainer:
	var vbox = VBoxContainer.new()

	# Save path
	var path_row = HBoxContainer.new()
	path_row.add_child(_make_label_small("Save path:"))
	_save_path_edit = LineEdit.new()
	_save_path_edit.placeholder_text = "res://resources/skills/classes/mage/flame/t1/my_skill.tres"
	_save_path_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	path_row.add_child(_save_path_edit)
	var browse_btn = Button.new()
	browse_btn.text = "📁"
	browse_btn.pressed.connect(_browse_save_path)
	path_row.add_child(browse_btn)
	vbox.add_child(path_row)

	# Loaded file indicator
	_load_path_label = Label.new()
	_load_path_label.text = ""
	_load_path_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(_load_path_label)

	return vbox

# ── Basic Info ──

func _build_basic_info_section() -> VBoxContainer:
	var vbox = VBoxContainer.new()

	# Skill ID + auto-generate button
	var id_row = HBoxContainer.new()
	id_row.add_child(_make_label_small("ID:"))
	_skill_id_edit = LineEdit.new()
	_skill_id_edit.placeholder_text = "flame_kindling"
	_skill_id_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	id_row.add_child(_skill_id_edit)
	var gen_btn = Button.new()
	gen_btn.text = "🔄"
	gen_btn.tooltip_text = "Generate ID from name"
	gen_btn.pressed.connect(_auto_generate_id)
	id_row.add_child(gen_btn)
	vbox.add_child(id_row)

	# Skill Name
	var name_row = HBoxContainer.new()
	name_row.add_child(_make_label_small("Name:"))
	_skill_name_edit = LineEdit.new()
	_skill_name_edit.placeholder_text = "Kindling"
	_skill_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(_skill_name_edit)
	vbox.add_child(name_row)

	# Description (multi-line, supports BBCode)
	vbox.add_child(_make_label_small("Description (BBCode):"))
	_description_edit = TextEdit.new()
	_description_edit.custom_minimum_size.y = 60
	_description_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_description_edit.placeholder_text = "+2 [color=orange]fire[/color] damage per adjacent fire die."
	vbox.add_child(_description_edit)

	# Icon path
	var icon_row = HBoxContainer.new()
	icon_row.add_child(_make_label_small("Icon:"))
	_icon_path_edit = LineEdit.new()
	_icon_path_edit.placeholder_text = "res://art/icons/skills/kindling.png"
	_icon_path_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	icon_row.add_child(_icon_path_edit)
	var icon_browse = Button.new()
	icon_browse.text = "📁"
	icon_browse.pressed.connect(func():
		_browse_for(_icon_path_edit, "*.png,*.jpg,*.svg,*.webp ; Images", "Select Icon"))
	icon_row.add_child(icon_browse)
	vbox.add_child(icon_row)

	return vbox

# ── Tree Position ──

func _build_tree_position_section() -> VBoxContainer:
	var vbox = VBoxContainer.new()

	var row1 = HBoxContainer.new()
	row1.add_child(_make_label_small("Tier:"))
	_tier_spin = SpinBox.new()
	_tier_spin.min_value = 1
	_tier_spin.max_value = 10
	_tier_spin.value = 1
	_tier_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	row1.add_child(_tier_spin)

	row1.add_child(_make_label_small("Col:"))
	_column_spin = SpinBox.new()
	_column_spin.min_value = 0
	_column_spin.max_value = 6
	_column_spin.value = 3
	_column_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	row1.add_child(_column_spin)
	vbox.add_child(row1)

	var row2 = HBoxContainer.new()
	row2.add_child(_make_label_small("SP Cost:"))
	_cost_spin = SpinBox.new()
	_cost_spin.min_value = 1
	_cost_spin.max_value = 5
	_cost_spin.value = 1
	_cost_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	row2.add_child(_cost_spin)
	vbox.add_child(row2)

	return vbox

# ── Requirements ──

func _build_requirements_section() -> VBoxContainer:
	var vbox = VBoxContainer.new()

	# Tree points required
	var tp_row = HBoxContainer.new()
	tp_row.add_child(_make_label_small("Tree Pts:"))
	_tree_points_spin = SpinBox.new()
	_tree_points_spin.min_value = 0
	_tree_points_spin.max_value = 30
	_tree_points_spin.value = 0
	_tree_points_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	tp_row.add_child(_tree_points_spin)
	vbox.add_child(tp_row)

	# Auto-fill button
	var auto_tp_btn = Button.new()
	auto_tp_btn.text = "🔄 Auto-fill tree points from tier"
	auto_tp_btn.pressed.connect(_auto_fill_tree_points)
	vbox.add_child(auto_tp_btn)

	# Prerequisites header
	vbox.add_child(_make_label_small("Prerequisites:"))

	# Dynamic prereq rows container
	_prereqs_container = VBoxContainer.new()
	vbox.add_child(_prereqs_container)

	# Add prerequisite button
	_add_prereq_btn = Button.new()
	_add_prereq_btn.text = "+ Add Prerequisite"
	_add_prereq_btn.pressed.connect(func(): _add_prereq_row())
	vbox.add_child(_add_prereq_btn)

	return vbox

# ── Rank Affix Section ──

func _build_rank_section(rank_index: int) -> VBoxContainer:
	var vbox = VBoxContainer.new()

	# Rows container
	var rows_container = VBoxContainer.new()
	vbox.add_child(rows_container)
	_rank_containers.append(rows_container)

	# Add affix button
	var add_btn = Button.new()
	add_btn.text = "+ Add Affix"
	add_btn.pressed.connect(_add_affix_row.bind(rank_index))
	vbox.add_child(add_btn)
	_rank_add_btns.append(add_btn)

	return vbox

# ============================================================================
# HELPER UI BUILDERS
# ============================================================================

func _make_section_header(text: String, color: Color = HEADER_COLOR) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	return label

func _make_label_small(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.custom_minimum_size.x = 65
	return label

# ============================================================================
# DYNAMIC LIST: PREREQUISITES
# ============================================================================

func _add_prereq_row(skill_path: String = "", rank: int = 1):
	var row = HBoxContainer.new()

	# Skill path
	var path_edit = LineEdit.new()
	path_edit.placeholder_text = "res://resources/skills/.../skill.tres"
	path_edit.text = skill_path
	path_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(path_edit)

	# Browse button
	var browse = Button.new()
	browse.text = "📁"
	browse.pressed.connect(func():
		_browse_for(path_edit, "*.tres ; Skill Resource", "Select Prerequisite Skill"))
	row.add_child(browse)

	# Rank spinbox
	var rank_label = Label.new()
	rank_label.text = "R"
	row.add_child(rank_label)
	var rank_spin = SpinBox.new()
	rank_spin.min_value = 1
	rank_spin.max_value = 5
	rank_spin.value = rank
	rank_spin.custom_minimum_size.x = 55
	row.add_child(rank_spin)

	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "✕"
	remove_btn.pressed.connect(func(): _remove_row(row, _prereqs_container))
	row.add_child(remove_btn)

	_prereqs_container.add_child(row)

# ============================================================================
# DYNAMIC LIST: RANK AFFIXES
# ============================================================================

func _add_affix_row(rank_index: int, affix_path: String = "", inline_affix: Affix = null):
	if rank_index < 0 or rank_index >= _rank_containers.size():
		return

	var container = _rank_containers[rank_index]
	var row = HBoxContainer.new()

	# Store inline affix reference as metadata on the row
	if inline_affix:
		row.set_meta("inline_affix", inline_affix)
		row.set_meta("rank_index", rank_index)

	# Affix path
	var path_edit = LineEdit.new()
	path_edit.placeholder_text = "res://resources/affixes/.../affix.tres"
	path_edit.text = affix_path
	path_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(path_edit)

	# Browse
	var browse = Button.new()
	browse.text = "📁"
	browse.pressed.connect(func():
		_browse_for(path_edit, "*.tres ; Affix Resource", "Select Affix for Rank %d" % (rank_index + 1)))
	row.add_child(browse)

	# Extract button — only for inline sub-resources
	if inline_affix:
		var extract_btn = Button.new()
		extract_btn.text = "📤"
		extract_btn.tooltip_text = "Extract inline affix to standalone .tres file"
		extract_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		extract_btn.pressed.connect(func():
			_extract_inline_affix(row, path_edit, extract_btn, inline_affix, rank_index))
		row.add_child(extract_btn)

	# Preview label (shows affix name after path is set)
	var preview = Label.new()
	preview.custom_minimum_size.x = 80
	preview.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	row.add_child(preview)

	# Auto-preview on text change
	path_edit.text_changed.connect(func(new_text: String):
		_update_affix_preview(new_text, preview))

	# Initial preview
	if inline_affix:
		preview.text = inline_affix.affix_name
	elif affix_path != "":
		_update_affix_preview(affix_path, preview)

	# Remove
	var remove_btn = Button.new()
	remove_btn.text = "✕"
	remove_btn.pressed.connect(func(): _remove_row(row, container))
	row.add_child(remove_btn)

	container.add_child(row)

func _update_affix_preview(path: String, label: Label):
	if path.is_empty() or not ResourceLoader.exists(path):
		label.text = ""
		return
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res and res.get("affix_name"):
		label.text = res.affix_name
	else:
		label.text = "(not an Affix)"
		label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

# ============================================================================
# SHARED LIST HELPERS
# ============================================================================

func _remove_row(row: HBoxContainer, container: VBoxContainer):
	container.remove_child(row)
	row.queue_free()

func _clear_container(container: VBoxContainer):
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

# ============================================================================
# FILE DIALOG
# ============================================================================

func _browse_for(target: LineEdit, filter: String, title: String = "Select File"):
	_dialog_target = target
	_dialog_mode = "open"
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.clear_filters()
	_file_dialog.add_filter(filter)
	_file_dialog.title = title
	_file_dialog.popup_centered_ratio(0.5)

func _browse_save_path():
	_dialog_target = _save_path_edit
	_dialog_mode = "save"
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.clear_filters()
	_file_dialog.add_filter("*.tres ; Godot Resource")
	_file_dialog.title = "Save Skill Resource"
	_file_dialog.popup_centered_ratio(0.5)

func _on_load_pressed():
	_dialog_target = null
	_dialog_mode = "load"
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.clear_filters()
	_file_dialog.add_filter("*.tres ; Skill Resource")
	_file_dialog.title = "Load Existing Skill"
	_file_dialog.popup_centered_ratio(0.5)

func _on_load_from_tree_pressed():
	_dialog_target = null
	_dialog_mode = "load_tree"
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.clear_filters()
	_file_dialog.add_filter("*.tres ; Skill Tree Resource")
	_file_dialog.title = "Select Skill Tree"
	_file_dialog.popup_centered_ratio(0.5)

func _on_file_dialog_selected(path: String):
	if _dialog_mode == "load":
		_load_skill(path)
	elif _dialog_mode == "load_tree":
		_open_tree_picker(path)
	elif _dialog_target:
		_dialog_target.text = path
	_dialog_target = null
	_dialog_mode = ""

# ============================================================================
# LOAD FROM SKILL TREE
# ============================================================================

func _open_tree_picker(tree_path: String):
	"""Load a SkillTree and show a picker with all its skills."""
	if not ResourceLoader.exists(tree_path):
		_set_status("❌ File not found: %s" % tree_path, Color.RED)
		return

	var tree = ResourceLoader.load(tree_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not tree or not tree is SkillTree:
		_set_status("❌ Not a SkillTree: %s" % tree_path, Color.RED)
		return

	_source_tree = tree
	_skill_picker_skills.clear()
	_skill_picker_list.clear()

	# Collect all skills tier by tier
	for tier in range(1, 11):
		var tier_skills = tree.get_skills_for_tier(tier)
		# Sort by column
		tier_skills.sort_custom(func(a, b): return a.column < b.column)
		for skill in tier_skills:
			if skill:
				var rank_info = ""
				var max_r = skill.get_max_rank()
				var affix_count = skill.get_total_affix_count()
				rank_info = "%d rank(s), %d affix(es)" % [max_r, affix_count]

				var label = "T%d C%d │ %s │ %s" % [skill.tier, skill.column, skill.skill_name, rank_info]
				_skill_picker_list.add_item(label)
				_skill_picker_skills.append(skill)

	if _skill_picker_skills.is_empty():
		_set_status("⚠️ No skills found in tree: %s" % tree_path, Color.YELLOW)
		return

	_skill_picker.title = "Pick a Skill from: %s" % tree.tree_name
	_skill_picker.popup_centered()

func _on_skill_picker_confirmed():
	"""User selected a skill from the tree picker."""
	var selected = _skill_picker_list.get_selected_items()
	if selected.is_empty():
		return

	var idx = selected[0]
	if idx < 0 or idx >= _skill_picker_skills.size():
		return

	var skill: SkillResource = _skill_picker_skills[idx]
	_skill_picker.hide()
	_load_skill_from_resource(skill)

# ============================================================================
# AUTO-GENERATE ID
# ============================================================================

func _auto_generate_id():
	var name_text = _skill_name_edit.text.strip_edges()
	if name_text.is_empty():
		_set_status("⚠️ Enter a skill name first", Color.YELLOW)
		return
	# Convert "Burning Vengeance" → "flame_burning_vengeance" (or just underscore-lower)
	var id = name_text.to_lower().replace(" ", "_").replace("-", "_")
	# Remove non-alphanumeric/underscore
	var clean = ""
	for ch in id:
		if ch.is_valid_identifier() or ch == "_":
			clean += ch
	_skill_id_edit.text = clean
	_set_status("✅ Generated ID: %s" % clean, Color.GREEN)

# ============================================================================
# AUTO-FILL TREE POINTS FROM TIER
# ============================================================================

func _auto_fill_tree_points():
	var tier = int(_tier_spin.value)
	var pts = _tier_to_points(tier)
	_tree_points_spin.value = pts
	_set_status("✅ Tier %d → %d tree points required" % [tier, pts], Color.GREEN)

func _tier_to_points(tier: int) -> int:
	match tier:
		1: return 0
		2: return 1
		3: return 3
		4: return 5
		5: return 8
		6: return 11
		7: return 15
		8: return 20
		9: return 25
		10: return 28
		_: return 0

# ============================================================================
# TEMPLATES
# ============================================================================

func _on_template_selected(index: int):
	if index == 0:
		return  # "Template..." placeholder

	_clear_all_fields()

	match index:
		1:  # Blank
			pass

		2:  # T1 Unlock Skill
			_tier_spin.value = 1
			_column_spin.value = 3
			_cost_spin.value = 1
			_tree_points_spin.value = 0
			_description_edit.text = "Unlocks [color=orange]fire[/color] element."

		3:  # Multi-Rank Passive
			_tier_spin.value = 2
			_column_spin.value = 1
			_cost_spin.value = 1
			_tree_points_spin.value = 1
			_description_edit.text = "+X / +Y / +Z bonus per rank."
			# Pre-create 3 rank affix rows
			for i in range(3):
				_add_affix_row(i)

		4:  # Action Skill (1 rank)
			_tier_spin.value = 3
			_column_spin.value = 3
			_cost_spin.value = 1
			_tree_points_spin.value = 3
			_description_edit.text = "[color=yellow]ACTION:[/color] 1 die → effect."
			_add_affix_row(0)  # One affix at rank 1 (the grant-action affix)

		5:  # Crossover Node
			_tier_spin.value = 6
			_column_spin.value = 3
			_cost_spin.value = 1
			_tree_points_spin.value = 11
			_description_edit.text = "★ Crossover: requires skills from 2 branches."
			_add_prereq_row()  # Two empty prereq rows
			_add_prereq_row()
			_add_affix_row(0)

	_template_btn.selected = 0
	_set_status("✅ Template applied", Color.GREEN)

func _clear_all_fields():
	_skill_id_edit.text = ""
	_skill_name_edit.text = ""
	_description_edit.text = ""
	_icon_path_edit.text = ""
	_tier_spin.value = 1
	_column_spin.value = 3
	_cost_spin.value = 1
	_tree_points_spin.value = 0
	_save_path_edit.text = ""
	_load_path_label.text = ""
	_source_tree = null

	# Clear prerequisites
	_clear_container(_prereqs_container)

	# Clear all rank containers
	for container in _rank_containers:
		_clear_container(container)

# ============================================================================
# LOAD EXISTING SKILL
# ============================================================================

func _load_skill(path: String):
	if not ResourceLoader.exists(path):
		_set_status("❌ File not found: %s" % path, Color.RED)
		return

	var skill = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not skill or not skill is SkillResource:
		_set_status("❌ Not a SkillResource: %s" % path, Color.RED)
		return

	_load_skill_from_resource(skill, path)

func _load_skill_from_resource(skill: SkillResource, override_save_path: String = ""):
	"""Populate all builder fields from a SkillResource (standalone or sub-resource)."""
	_clear_all_fields()

	# Basic info
	_skill_id_edit.text = skill.skill_id
	_skill_name_edit.text = skill.skill_name
	_description_edit.text = skill.description
	if skill.icon:
		_icon_path_edit.text = skill.icon.resource_path

	# Tree position
	_tier_spin.value = skill.tier
	_column_spin.value = skill.column
	_cost_spin.value = skill.skill_point_cost

	# Requirements
	_tree_points_spin.value = skill.tree_points_required

	# Prerequisites
	for prereq in skill.prerequisites:
		if prereq and prereq.required_skill:
			var prereq_path = prereq.required_skill.resource_path
			# Sub-resource prereqs won't have a usable path — show name as hint
			if prereq_path.is_empty() or "::" in prereq_path:
				_add_prereq_row("# INLINE: %s" % prereq.required_skill.skill_name, prereq.required_rank)
			else:
				_add_prereq_row(prereq_path, prereq.required_rank)
		elif prereq:
			_add_prereq_row("", prereq.required_rank)

	# Rank affixes
	for rank_idx in range(MAX_RANKS):
		var affixes = skill.get_affixes_for_rank(rank_idx + 1)
		for affix in affixes:
			if affix:
				var affix_path = affix.resource_path
				if affix_path.is_empty() or "::" in affix_path:
					# Inline sub-resource — pass reference for extraction
					_add_affix_row(rank_idx, "# INLINE: %s" % affix.affix_name, affix)
				else:
					_add_affix_row(rank_idx, affix_path)

	# Save path
	if not override_save_path.is_empty():
		_save_path_edit.text = override_save_path
		_load_path_label.text = "Loaded: %s" % override_save_path
	else:
		# Generate a suggested save path for sub-resource skills
		var suggested = _suggest_save_path(skill)
		_save_path_edit.text = suggested
		_load_path_label.text = "Loaded from tree: %s (sub-resource)" % skill.skill_name

	_set_status("✅ Loaded: %s (%d affixes across %d ranks)" % [
		skill.skill_name, skill.get_total_affix_count(), skill.get_max_rank()], Color.GREEN)

func _suggest_save_path(skill: SkillResource) -> String:
	"""Generate a suggested save path for a skill loaded from a tree."""
	var tree_id = ""
	var class_id = ""

	# Try to infer from source tree
	if _source_tree:
		tree_id = _source_tree.tree_id  # e.g. "mage_flame"
		# Try to split tree_id into class_element
		var parts = tree_id.split("_", true, 1)
		if parts.size() >= 2:
			class_id = parts[0]  # "mage"

	var tier_str = "t%d" % skill.tier
	var id = skill.skill_id if not skill.skill_id.is_empty() else "unnamed"

	if not class_id.is_empty() and not tree_id.is_empty():
		var element = tree_id.trim_prefix(class_id + "_")  # "flame"
		return "res://resources/skills/classes/%s/%s/%s/%s.tres" % [class_id, element, tier_str, id]
	else:
		return "res://resources/skills/%s/%s.tres" % [tier_str, id]

# ============================================================================
# SAVE
# ============================================================================

func _on_save_pressed():
	# Validate
	var warnings = _validate()
	if warnings.size() > 0:
		_set_status("⚠️ " + " | ".join(warnings), Color.YELLOW)
		return

	# Build the skill resource
	var skill = SkillResource.new()

	# Basic info
	skill.skill_id = _skill_id_edit.text.strip_edges()
	skill.skill_name = _skill_name_edit.text.strip_edges()
	skill.description = _description_edit.text

	# Icon
	var icon_path = _icon_path_edit.text.strip_edges()
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		skill.icon = load(icon_path) as Texture2D

	# Tree position
	skill.tier = int(_tier_spin.value)
	skill.column = int(_column_spin.value)
	skill.skill_point_cost = int(_cost_spin.value)

	# Requirements
	skill.tree_points_required = int(_tree_points_spin.value)

	# Prerequisites
	var prereqs = _collect_prerequisites()
	skill.prerequisites.assign(prereqs)

	# Rank affixes
	for rank_idx in range(MAX_RANKS):
		var affixes = _collect_rank_affixes(rank_idx)
		match rank_idx:
			0: skill.rank_1_affixes.assign(affixes)
			1: skill.rank_2_affixes.assign(affixes)
			2: skill.rank_3_affixes.assign(affixes)
			3: skill.rank_4_affixes.assign(affixes)
			4: skill.rank_5_affixes.assign(affixes)

	# Save
	var path = _save_path_edit.text.strip_edges()
	if not path.ends_with(".tres"):
		path += ".tres"

	# Ensure directory exists
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	skill.take_over_path(path)
	var err = ResourceSaver.save(skill, path)
	if err == OK:
		_set_status("✅ Saved: %s (%s)" % [skill.skill_name, path], Color.GREEN)
		_load_path_label.text = "Saved: %s" % path
	else:
		_set_status("❌ Save failed (error %d): %s" % [err, path], Color.RED)

# ============================================================================
# DATA COLLECTION
# ============================================================================

func _collect_prerequisites() -> Array[SkillPrerequisite]:
	var result: Array[SkillPrerequisite] = []

	for row in _prereqs_container.get_children():
		if not row is HBoxContainer:
			continue

		var path_edit = row.get_child(0) as LineEdit
		# Child layout: [LineEdit, Button(browse), Label("R"), SpinBox, Button(remove)]
		var rank_spin = row.get_child(3) as SpinBox
		if not path_edit or not rank_spin:
			continue

		var skill_path = path_edit.text.strip_edges()
		if skill_path.is_empty() or skill_path.begins_with("#"):
			continue

		if not ResourceLoader.exists(skill_path):
			print("⚠️ SkillBuilder: Prerequisite not found: %s" % skill_path)
			continue

		var skill_res = ResourceLoader.load(skill_path) as SkillResource
		if not skill_res:
			print("⚠️ SkillBuilder: Not a SkillResource: %s" % skill_path)
			continue

		var prereq = SkillPrerequisite.new()
		prereq.required_skill = skill_res
		prereq.required_rank = int(rank_spin.value)
		result.append(prereq)

	return result

func _collect_rank_affixes(rank_index: int) -> Array[Affix]:
	var result: Array[Affix] = []

	if rank_index < 0 or rank_index >= _rank_containers.size():
		return result

	var container = _rank_containers[rank_index]
	for row in container.get_children():
		if not row is HBoxContainer:
			continue

		# Check for inline affix that hasn't been extracted yet
		if row.has_meta("inline_affix"):
			var inline: Affix = row.get_meta("inline_affix")
			if inline:
				result.append(inline)
				continue

		var path_edit = row.get_child(0) as LineEdit
		if not path_edit:
			continue

		var affix_path = path_edit.text.strip_edges()
		if affix_path.is_empty() or affix_path.begins_with("#"):
			continue

		if not ResourceLoader.exists(affix_path):
			print("⚠️ SkillBuilder: Affix not found: %s" % affix_path)
			continue

		var affix = ResourceLoader.load(affix_path) as Affix
		if affix:
			result.append(affix)
		else:
			print("⚠️ SkillBuilder: Not an Affix: %s" % affix_path)

	return result

# ============================================================================
# VALIDATION
# ============================================================================

func _validate() -> Array[String]:
	var warnings: Array[String] = []

	if _skill_id_edit.text.strip_edges().is_empty():
		warnings.append("Skill ID is empty")
	if _skill_name_edit.text.strip_edges().is_empty():
		warnings.append("Skill Name is empty")
	if _save_path_edit.text.strip_edges().is_empty():
		warnings.append("Save path is empty")

	# Check that at least rank 1 has an affix
	var has_any_r1 = false
	if _rank_containers.size() > 0:
		for row in _rank_containers[0].get_children():
			if row is HBoxContainer:
				# Check for inline affix
				if row.has_meta("inline_affix"):
					has_any_r1 = true
					break
				var pe = row.get_child(0) as LineEdit
				if pe and not pe.text.strip_edges().is_empty() and not pe.text.begins_with("#"):
					has_any_r1 = true
					break
	if not has_any_r1:
		warnings.append("Rank 1 has no affixes")

	# Validate prerequisite paths exist
	for row in _prereqs_container.get_children():
		if not row is HBoxContainer:
			continue
		var pe = row.get_child(0) as LineEdit
		if pe:
			var p = pe.text.strip_edges()
			if not p.is_empty() and not p.begins_with("#") and not ResourceLoader.exists(p):
				warnings.append("Prereq not found: %s" % p.get_file())

	return warnings

# ============================================================================
# INLINE AFFIX EXTRACTION
# ============================================================================

func _extract_inline_affix(row: HBoxContainer, path_edit: LineEdit, extract_btn: Button,
		affix: Affix, rank_index: int):
	"""Extract a single inline affix to a standalone .tres file."""
	var target_path = _generate_extract_path(affix, rank_index)
	if target_path.is_empty():
		_set_status("❌ Cannot generate extract path — set a save path first", Color.RED)
		return

	# Ensure directory exists
	var dir_path = target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Duplicate the affix so we get a clean standalone copy
	var standalone = affix.duplicate(true)

	# Cache-bust and save
	standalone.take_over_path(target_path)
	var err = ResourceSaver.save(standalone, target_path)
	if err != OK:
		_set_status("❌ Extract failed (error %d): %s" % [err, target_path], Color.RED)
		return

	# Update the row — swap path text, remove extract button, clear metadata
	path_edit.text = target_path
	extract_btn.queue_free()
	row.remove_meta("inline_affix")

	_set_status("📤 Extracted: %s → %s" % [affix.affix_name, target_path], Color.GREEN)

func _on_extract_all_pressed():
	"""Extract ALL inline affix sub-resources across all ranks."""
	var extracted := 0
	var failed := 0

	for rank_idx in range(MAX_RANKS):
		if rank_idx >= _rank_containers.size():
			continue
		var container = _rank_containers[rank_idx]

		# Collect rows first to avoid modifying during iteration
		var rows_to_extract: Array = []
		for row in container.get_children():
			if row is HBoxContainer and row.has_meta("inline_affix"):
				rows_to_extract.append(row)

		for row in rows_to_extract:
			var affix: Affix = row.get_meta("inline_affix")
			var path_edit: LineEdit = row.get_child(0) as LineEdit
			# Find the extract button — it's the one with "📤" text
			var extract_btn: Button = null
			for child in row.get_children():
				if child is Button and child.text == "📤":
					extract_btn = child
					break

			if not affix or not path_edit or not extract_btn:
				failed += 1
				continue

			var target_path = _generate_extract_path(affix, rank_idx)
			if target_path.is_empty():
				failed += 1
				continue

			var dir_path = target_path.get_base_dir()
			if not DirAccess.dir_exists_absolute(dir_path):
				DirAccess.make_dir_recursive_absolute(dir_path)

			var standalone = affix.duplicate(true)
			standalone.take_over_path(target_path)
			var err = ResourceSaver.save(standalone, target_path)
			if err == OK:
				path_edit.text = target_path
				extract_btn.queue_free()
				row.remove_meta("inline_affix")
				extracted += 1
			else:
				failed += 1

	if failed == 0:
		_set_status("📤 Extracted %d affix(es) to standalone files" % extracted, Color.GREEN)
	else:
		_set_status("📤 Extracted %d, failed %d" % [extracted, failed], Color.YELLOW)

func _generate_extract_path(affix: Affix, rank_index: int) -> String:
	"""Generate a sensible file path for an extracted affix.

	Strategy:
	  1. Derive from the skill's save path, replacing 'skills' → 'affixes'
	  2. Filename: {skill_id}_r{rank}_{sanitized_affix_name}.tres
	  3. Fallback to a generic path if save path is empty
	"""
	var skill_id = _skill_id_edit.text.strip_edges()
	var rank_num = rank_index + 1

	# Sanitize affix name for filename
	var affix_slug = affix.affix_name.to_lower()
	affix_slug = affix_slug.replace(" ", "_").replace(":", "").replace("'", "")
	affix_slug = affix_slug.replace("+", "plus").replace("-", "_")
	# Remove duplicate underscores
	while "__" in affix_slug:
		affix_slug = affix_slug.replace("__", "_")
	affix_slug = affix_slug.strip_edges().trim_suffix("_").trim_prefix("_")

	# Try to derive from skill save path
	var base_path = _save_path_edit.text.strip_edges()
	if not base_path.is_empty():
		var dir = base_path.get_base_dir()

		# Replace 'skills' with 'affixes' in path for conventional layout
		var affix_dir = dir.replace("/skills/", "/affixes/")

		# If no change occurred (path doesn't contain /skills/), put in same dir
		if affix_dir == dir:
			affix_dir = dir

		var filename = "%s_r%d_%s.tres" % [skill_id, rank_num, affix_slug]
		return affix_dir.path_join(filename)

	# Fallback: generic path
	if skill_id.is_empty():
		skill_id = "unnamed_skill"
	return "res://resources/affixes/extracted/%s_r%d_%s.tres" % [skill_id, rank_num, affix_slug]

# ============================================================================
# STATUS
# ============================================================================

func _set_status(text: String, color: Color = Color.WHITE):
	if _status_label:
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", color)
