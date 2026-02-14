@tool
# theme_editor_dock.gd
# Main dock panel for the Theme Editor plugin.
# Parses theme_manager.gd to read PALETTE / FONT_SIZES / status colors,
# displays them in organized collapsible sections with live color pickers,
# and writes changes back to the script file.
#
# Layer 3 of the theme architecture:
#   Layer 1 — base_theme.tres (edit StyleBoxes in Godot's Theme Editor)
#   Layer 2 — ThemeManager (runtime: PALETTE, helpers, applies theme)
#   Layer 3 — This plugin (edit PALETTE colors, fonts, status colors)
extends Control

const THEME_MANAGER_PATH := "res://scripts/ui/theme_manager.gd"
const PRESETS_DIR := "res://addons/theme_editor/presets/"
const PaletteIO = preload("res://addons/theme_editor/palette_io.gd")

# ============================================================================
# PALETTE CATEGORY DEFINITIONS
# ============================================================================

const CATEGORIES := {
	"Backgrounds": [
		"bg_darkest", "bg_dark", "bg_panel", "bg_elevated", "bg_input", "bg_hover",
	],
	"Borders": [
		"border_subtle", "border_default", "border_accent", "border_focus",
	],
	"Text": [
		"text_primary", "text_secondary", "text_muted", "text_shadow",
	],
	"Semantic": [
		"primary", "primary_hover", "primary_pressed", "secondary",
		"success", "danger", "warning", "info",
	],
	"Game States": [
		"locked", "available", "maxed",
	],
	"Elements": [
		"fire", "ice", "shock", "poison", "shadow",
		"slashing", "blunt", "piercing",
	],
	"Rarity": [
		"rarity_common", "rarity_uncommon", "rarity_rare",
		"rarity_epic", "rarity_legendary",
	],
	"Combat": [
		"health", "health_low", "mana", "experience", "armor", "barrier",
	],
	"Stats": [
		"strength", "agility", "intellect", "luck",
	],
	"Cate": [
		"cate_happy", "cate_neutral", "cate_annoyed",
	],
}

const STATUS_KEYS := [
	"poison", "burn", "bleed", "chill", "stunned", "slowed",
	"corrode", "shadow", "block", "dodge", "overhealth",
	"expose", "enfeeble", "ignition",
]

# ============================================================================
# STATE
# ============================================================================
## Working copy of PALETTE colors
var working_palette: Dictionary = {}
## Working copy of FONT_SIZES
var working_fonts: Dictionary = {}
## Working copy of status colors
var working_status: Dictionary = {}

## EditorUndoRedoManager (set by plugin.gd)
var undo_redo: EditorUndoRedoManager = null

## Snapshot: color before the picker opened, for undo
var _pre_edit_color: Color = Color.WHITE
## Snapshot: font value before editing, for undo
var _pre_edit_font_values: Dictionary = {}

## Tracks which categories are collapsed
var _collapsed: Dictionary = {}

# UI references
var _scroll: ScrollContainer
var _main_vbox: VBoxContainer
var _swatch_rects: Dictionary = {}       # palette_key -> ColorRect
var _hex_labels: Dictionary = {}         # palette_key -> Label
var _font_spinboxes: Dictionary = {}     # font_key -> SpinBox
var _status_rects: Dictionary = {}       # status_key -> ColorRect
var _status_hex_labels: Dictionary = {}  # status_key -> Label
var _element_preview: HBoxContainer
var _rarity_preview: HBoxContainer
var _popup: PopupPanel
var _picker: ColorPicker
var _editing_key: String = ""
var _editing_source: String = ""  # "palette" or "status"
var _dirty: bool = false
var _dirty_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	custom_minimum_size = Vector2(280, 400)
	_load_from_script()
	_build_ui()


func _load_from_script() -> void:
	# Parse theme_manager.gd to populate working dicts.
	working_palette = PaletteIO.parse_palette(THEME_MANAGER_PATH)
	working_fonts = PaletteIO.parse_font_sizes(THEME_MANAGER_PATH)
	working_status = PaletteIO.parse_status_colors(THEME_MANAGER_PATH)

	if working_palette.is_empty():
		push_warning("ThemeEditor: Could not parse PALETTE from %s" % THEME_MANAGER_PATH)
	else:
		print("🎨 ThemeEditor: Loaded %d palette colors, %d font sizes, %d status colors" % [
			working_palette.size(), working_fonts.size(), working_status.size()])

# ============================================================================
# UI CONSTRUCTION
# ============================================================================

func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 2)
	_scroll.add_child(_main_vbox)

	_build_toolbar()
	_add_separator()

	# PALETTE sections
	for category_name in CATEGORIES:
		_build_palette_section(category_name, CATEGORIES[category_name])

	# Previews
	_add_separator()
	_build_element_preview()
	_build_rarity_preview()

	# Font sizes
	_add_separator()
	_build_font_section()

	# Status colors
	_add_separator()
	_build_status_section()

	# Info label about StyleBox editing
	_add_separator()
	_build_stylebox_info()

	# Color picker popup (shared, repositioned on use)
	_popup = PopupPanel.new()
	_popup.size = Vector2(320, 360)
	_popup.popup_hide.connect(_on_picker_closed)
	_picker = ColorPicker.new()
	_picker.edit_alpha = true
	_picker.color_changed.connect(_on_picker_color_changed)
	_popup.add_child(_picker)
	add_child(_popup)


func _build_toolbar() -> void:
	var toolbar = VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	_main_vbox.add_child(toolbar)

	var title = Label.new()
	title.text = "🎨 Theme Editor"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(title)

	_dirty_label = Label.new()
	_dirty_label.text = ""
	_dirty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dirty_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_dirty_label.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(_dirty_label)

	# Row 1: Reload + Write
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	toolbar.add_child(row1)

	var apply_btn = Button.new()
	apply_btn.text = "⟳ Reload"
	apply_btn.tooltip_text = "Re-read theme_manager.gd (discard unsaved edits)"
	apply_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	apply_btn.pressed.connect(_on_reload_pressed)
	row1.add_child(apply_btn)

	var write_btn = Button.new()
	write_btn.text = "💾 Write to Script"
	write_btn.tooltip_text = "Save current colors into theme_manager.gd"
	write_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	write_btn.pressed.connect(_on_write_pressed)
	row1.add_child(write_btn)

	# Row 2: Export + Import
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	toolbar.add_child(row2)

	var export_btn = Button.new()
	export_btn.text = "📤 Export JSON"
	export_btn.tooltip_text = "Save current palette as a JSON preset"
	export_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	export_btn.pressed.connect(_on_export_pressed)
	row2.add_child(export_btn)

	var import_btn = Button.new()
	import_btn.text = "📥 Import JSON"
	import_btn.tooltip_text = "Load a JSON preset file"
	import_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	import_btn.pressed.connect(_on_import_pressed)
	row2.add_child(import_btn)


func _build_palette_section(category_name: String, keys: Array) -> void:
	var header = Button.new()
	header.text = "▼ %s" % category_name
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_main_vbox.add_child(header)

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 1)
	_main_vbox.add_child(container)

	header.pressed.connect(_toggle_section.bind(category_name, container, header))
	_collapsed[category_name] = false

	for key in keys:
		if not working_palette.has(key):
			continue
		var row = _build_swatch_row(key, working_palette[key], "palette")
		container.add_child(row)


func _build_swatch_row(key: String, color: Color, source: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size.y = 24

	# Color preview rect (clickable)
	var rect = ColorRect.new()
	rect.custom_minimum_size = Vector2(28, 20)
	rect.color = color
	rect.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	rect.gui_input.connect(_on_swatch_clicked.bind(key, source, rect))
	rect.tooltip_text = "Click to edit"
	row.add_child(rect)

	# Key label
	var name_label = Label.new()
	name_label.text = _display_name(key)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.clip_text = true
	row.add_child(name_label)

	# Hex label (click to copy)
	var hex_label = Label.new()
	hex_label.text = _color_to_hex(color)
	hex_label.add_theme_font_size_override("font_size", 11)
	hex_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hex_label.tooltip_text = "Click to copy hex"
	hex_label.mouse_filter = MOUSE_FILTER_STOP
	hex_label.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	hex_label.gui_input.connect(_on_hex_clicked.bind(key, source))
	row.add_child(hex_label)

	# Store references
	if source == "palette":
		_swatch_rects[key] = rect
		_hex_labels[key] = hex_label
	elif source == "status":
		_status_rects[key] = rect
		_status_hex_labels[key] = hex_label

	return row


func _build_element_preview() -> void:
	var header = Label.new()
	header.text = "Element Preview"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_main_vbox.add_child(header)

	_element_preview = HBoxContainer.new()
	_element_preview.add_theme_constant_override("separation", 2)
	_main_vbox.add_child(_element_preview)
	_refresh_element_preview()


func _build_rarity_preview() -> void:
	var header = Label.new()
	header.text = "Rarity Preview"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_main_vbox.add_child(header)

	_rarity_preview = HBoxContainer.new()
	_rarity_preview.add_theme_constant_override("separation", 3)
	_main_vbox.add_child(_rarity_preview)
	_refresh_rarity_preview()


func _build_font_section() -> void:
	var header = Button.new()
	header.text = "▼ Font Sizes"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_main_vbox.add_child(header)

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	_main_vbox.add_child(container)

	header.pressed.connect(_toggle_section.bind("Font Sizes", container, header))
	_collapsed["Font Sizes"] = false

	var sorted_keys = working_fonts.keys()
	sorted_keys.sort_custom(func(a, b): return working_fonts[a] < working_fonts[b])

	for key in sorted_keys:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.y = 28
		container.add_child(row)

		var name_label = Label.new()
		name_label.text = key.capitalize()
		name_label.custom_minimum_size.x = 70
		name_label.add_theme_font_size_override("font_size", 12)
		row.add_child(name_label)

		var spinbox = SpinBox.new()
		spinbox.min_value = 6
		spinbox.max_value = 72
		spinbox.step = 1
		spinbox.value = working_fonts[key]
		spinbox.size_flags_horizontal = SIZE_EXPAND_FILL
		spinbox.custom_minimum_size.x = 60
		# Snapshot on focus for undo
		spinbox.get_line_edit().focus_entered.connect(
			_on_font_focus_entered.bind(key))
		spinbox.value_changed.connect(_on_font_changed.bind(key))
		row.add_child(spinbox)
		_font_spinboxes[key] = spinbox

		# Preview text
		var preview = Label.new()
		preview.text = "Aa"
		preview.add_theme_font_size_override("font_size", working_fonts[key])
		preview.size_flags_horizontal = SIZE_EXPAND_FILL
		preview.clip_text = true
		row.add_child(preview)
		spinbox.set_meta("preview_label", preview)


func _build_status_section() -> void:
	var header = Button.new()
	header.text = "▼ Status Colors"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_main_vbox.add_child(header)

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 1)
	_main_vbox.add_child(container)

	header.pressed.connect(_toggle_section.bind("Status Colors", container, header))
	_collapsed["Status Colors"] = false

	for key in STATUS_KEYS:
		if not working_status.has(key):
			continue
		var row = _build_swatch_row(key, working_status[key], "status")
		container.add_child(row)


func _build_stylebox_info() -> void:
	# Info label directing users to the native Theme Editor for StyleBoxes.
	var info = Label.new()
	info.text = "StyleBox editing → open base_theme.tres\nin Godot's Theme Editor"
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_vbox.add_child(info)


# ============================================================================
# PREVIEWS
# ============================================================================

func _refresh_element_preview() -> void:
	for child in _element_preview.get_children():
		child.queue_free()

	var element_keys = ["fire", "ice", "shock", "poison", "shadow",
		"slashing", "blunt", "piercing"]

	for key in element_keys:
		var color = working_palette.get(key, Color.WHITE)
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 1)

		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(0, 20)
		rect.size_flags_horizontal = SIZE_EXPAND_FILL
		rect.color = color
		vbox.add_child(rect)

		var lbl = Label.new()
		lbl.text = key.left(3).capitalize()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 9)
		vbox.add_child(lbl)

		_element_preview.add_child(vbox)


func _refresh_rarity_preview() -> void:
	for child in _rarity_preview.get_children():
		child.queue_free()

	var rarity_keys = ["rarity_common", "rarity_uncommon", "rarity_rare",
		"rarity_epic", "rarity_legendary"]
	var rarity_labels = ["C", "U", "R", "E", "L"]

	for i in rarity_keys.size():
		var color = working_palette.get(rarity_keys[i], Color.GRAY)
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = SIZE_EXPAND_FILL

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12)
		style.border_color = color
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", style)

		var lbl = Label.new()
		lbl.text = rarity_labels[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", color)
		panel.add_child(lbl)

		_rarity_preview.add_child(panel)


# ============================================================================
# SECTION COLLAPSE
# ============================================================================

func _toggle_section(category_name: String, container: VBoxContainer, header: Button) -> void:
	var is_collapsed = not _collapsed.get(category_name, false)
	_collapsed[category_name] = is_collapsed
	container.visible = not is_collapsed
	header.text = "%s %s" % ["►" if is_collapsed else "▼", category_name]


# ============================================================================
# COLOR EDITING (with undo/redo)
# ============================================================================

func _on_swatch_clicked(event: InputEvent, key: String, source: String, rect: ColorRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_editing_key = key
		_editing_source = source
		var current_color = working_palette[key] if source == "palette" else working_status.get(key, Color.WHITE)
		# Snapshot for undo
		_pre_edit_color = current_color
		_picker.color = current_color
		var global_pos = rect.global_position + Vector2(rect.size.x + 8, 0)
		_popup.position = Vector2i(int(global_pos.x), int(global_pos.y))
		_popup.popup()


func _on_picker_color_changed(color: Color) -> void:
	if _editing_key.is_empty():
		return

	# Apply live (visual feedback during picking)
	if _editing_source == "palette":
		working_palette[_editing_key] = color
		if _swatch_rects.has(_editing_key):
			_swatch_rects[_editing_key].color = color
		if _hex_labels.has(_editing_key):
			_hex_labels[_editing_key].text = _color_to_hex(color)
		if _editing_key.begins_with("rarity_"):
			_refresh_rarity_preview()
		elif _editing_key in ["fire", "ice", "shock", "poison", "shadow",
				"slashing", "blunt", "piercing"]:
			_refresh_element_preview()
	elif _editing_source == "status":
		working_status[_editing_key] = color
		if _status_rects.has(_editing_key):
			_status_rects[_editing_key].color = color
		if _status_hex_labels.has(_editing_key):
			_status_hex_labels[_editing_key].text = _color_to_hex(color)

	_mark_dirty()


func _on_picker_closed() -> void:
	# Commit undo/redo action when the picker closes.
	if _editing_key.is_empty():
		return

	var final_color: Color
	if _editing_source == "palette":
		final_color = working_palette.get(_editing_key, Color.WHITE)
	else:
		final_color = working_status.get(_editing_key, Color.WHITE)

	# Only commit if the color actually changed
	if not _pre_edit_color.is_equal_approx(final_color) and undo_redo:
		var key = _editing_key
		var source = _editing_source
		var old_color = _pre_edit_color
		var new_color = final_color

		undo_redo.create_action("Theme: Change %s '%s'" % [source, key])
		undo_redo.add_do_method(self, "_apply_color", key, source, new_color)
		undo_redo.add_undo_method(self, "_apply_color", key, source, old_color)
		undo_redo.commit_action(false)  # false = don't execute do (already applied live)

	_editing_key = ""
	_editing_source = ""


func _apply_color(key: String, source: String, color: Color) -> void:
	# Apply a color value — called by undo/redo system.
	if source == "palette":
		working_palette[key] = color
		if _swatch_rects.has(key):
			_swatch_rects[key].color = color
		if _hex_labels.has(key):
			_hex_labels[key].text = _color_to_hex(color)
	elif source == "status":
		working_status[key] = color
		if _status_rects.has(key):
			_status_rects[key].color = color
		if _status_hex_labels.has(key):
			_status_hex_labels[key].text = _color_to_hex(color)

	_refresh_element_preview()
	_refresh_rarity_preview()
	_mark_dirty()


func _on_hex_clicked(event: InputEvent, key: String, source: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var color = working_palette[key] if source == "palette" else working_status.get(key, Color.WHITE)
		DisplayServer.clipboard_set(_color_to_hex(color))
		print("📋 Copied %s: %s" % [key, _color_to_hex(color)])


# ============================================================================
# FONT EDITING (with undo/redo)
# ============================================================================

func _on_font_focus_entered(key: String) -> void:
	# Snapshot current font value when spinbox gains focus.
	_pre_edit_font_values[key] = working_fonts.get(key, 16)


func _on_font_changed(value: float, key: String) -> void:
	var old_value = _pre_edit_font_values.get(key, working_fonts.get(key, 16))
	var new_value = int(value)
	working_fonts[key] = new_value

	if _font_spinboxes.has(key):
		var preview: Label = _font_spinboxes[key].get_meta("preview_label")
		if preview:
			preview.add_theme_font_size_override("font_size", new_value)

	# Commit undo/redo
	if undo_redo and old_value != new_value:
		undo_redo.create_action("Theme: Font '%s' %d → %d" % [key, old_value, new_value])
		undo_redo.add_do_method(self, "_apply_font", key, new_value)
		undo_redo.add_undo_method(self, "_apply_font", key, old_value)
		undo_redo.commit_action(false)
		# Update snapshot for next edit
		_pre_edit_font_values[key] = new_value

	_mark_dirty()


func _apply_font(key: String, value: int) -> void:
	# Apply a font size value — called by undo/redo system.
	working_fonts[key] = value
	if _font_spinboxes.has(key):
		_font_spinboxes[key].value = value
		var preview: Label = _font_spinboxes[key].get_meta("preview_label")
		if preview:
			preview.add_theme_font_size_override("font_size", value)
	_mark_dirty()


# ============================================================================
# TOOLBAR ACTIONS
# ============================================================================

func _on_reload_pressed() -> void:
	_load_from_script()
	_rebuild_all_swatches()
	_dirty = false
	_dirty_label.text = ""
	print("🎨 ThemeEditor: Reloaded from script")


func _on_write_pressed() -> void:
	var result = PaletteIO.write_to_script(
		THEME_MANAGER_PATH, working_palette, working_fonts, working_status)
	if result:
		_dirty = false
		_dirty_label.text = "✓ Written to theme_manager.gd"
		print("🎨 ThemeEditor: Written to %s" % THEME_MANAGER_PATH)
	else:
		_dirty_label.text = "✗ Write failed — check Output"
		push_error("ThemeEditor: Failed to write to %s" % THEME_MANAGER_PATH)


func _on_export_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.json ; Theme Preset"])
	dialog.current_dir = "res://addons/theme_editor/presets"
	dialog.current_file = "custom_theme.json"
	dialog.file_selected.connect(func(path: String):
		var success = PaletteIO.export_json(path, working_palette, working_fonts, working_status)
		if success:
			_dirty_label.text = "✓ Exported to %s" % path.get_file()
			print("🎨 Exported to %s" % path)
		else:
			_dirty_label.text = "✗ Export failed"
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(500, 400))


func _on_import_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.json ; Theme Preset"])
	dialog.current_dir = "res://addons/theme_editor/presets"
	dialog.file_selected.connect(func(path: String):
		var data = PaletteIO.import_json(path)
		if data.is_empty():
			_dirty_label.text = "✗ Import failed — invalid JSON"
			dialog.queue_free()
			return
		if data.has("palette"):
			for key in data.palette:
				working_palette[key] = data.palette[key]
		if data.has("fonts"):
			for key in data.fonts:
				working_fonts[key] = data.fonts[key]
		if data.has("status"):
			for key in data.status:
				working_status[key] = data.status[key]
		_rebuild_all_swatches()
		_mark_dirty()
		_dirty_label.text = "✓ Imported %s" % path.get_file()
		print("🎨 Imported from %s" % path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(500, 400))


# ============================================================================
# UI REFRESH
# ============================================================================

func _rebuild_all_swatches() -> void:
	# Sync all swatch rects and hex labels to working dict values.
	for key in _swatch_rects:
		if working_palette.has(key):
			_swatch_rects[key].color = working_palette[key]
	for key in _hex_labels:
		if working_palette.has(key):
			_hex_labels[key].text = _color_to_hex(working_palette[key])
	for key in _status_rects:
		if working_status.has(key):
			_status_rects[key].color = working_status[key]
	for key in _status_hex_labels:
		if working_status.has(key):
			_status_hex_labels[key].text = _color_to_hex(working_status[key])
	for key in _font_spinboxes:
		if working_fonts.has(key):
			_font_spinboxes[key].value = working_fonts[key]
			var preview: Label = _font_spinboxes[key].get_meta("preview_label")
			if preview:
				preview.add_theme_font_size_override("font_size", working_fonts[key])
	_refresh_element_preview()
	_refresh_rarity_preview()


func _mark_dirty() -> void:
	_dirty = true
	_dirty_label.text = "● Unsaved changes"


# ============================================================================
# HELPERS
# ============================================================================

func _add_separator() -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_main_vbox.add_child(sep)


static func _color_to_hex(c: Color) -> String:
	if c.a < 0.999:
		return "#%s" % c.to_html(true)
	return "#%s" % c.to_html(false)


static func _display_name(key: String) -> String:
	# Convert palette key to readable name: bg_darkest -> Bg Darkest
	return key.replace("_", " ").capitalize()
