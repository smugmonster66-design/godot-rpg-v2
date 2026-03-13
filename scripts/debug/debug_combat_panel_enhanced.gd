# res://scripts/debug/debug_combat_panel_enhanced.gd
# Enhanced debug panel with filesystem-scanning encounter selection
# Toggle with Ctrl + = (equals key)
extends Control
class_name DebugCombatPanelEnhanced

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var panel_container: PanelContainer = $PanelContainer
@onready var category_dropdown: OptionButton = $PanelContainer/MarginContainer/VBox/CategoryBar/CategoryDropdown
@onready var encounter_dropdown: OptionButton = $PanelContainer/MarginContainer/VBox/EncounterBar/EncounterDropdown
@onready var start_button: Button = $PanelContainer/MarginContainer/VBox/StartButton
@onready var title_label: Label = $PanelContainer/MarginContainer/VBox/TitleBar/Title
@onready var close_button: Button = $PanelContainer/MarginContainer/VBox/TitleBar/CloseButton
@onready var stats_label: Label = $PanelContainer/MarginContainer/VBox/StatsBar/StatsLabel
@onready var refresh_button: Button = $PanelContainer/MarginContainer/VBox/TitleBar/RefreshButton

# ============================================================================
# CONSTANTS
# ============================================================================
const ENCOUNTERS_BASE_PATH := "res://resources/encounters/"

# ============================================================================
# STATE
# ============================================================================
var is_panel_visible: bool = false
## { "Category Name": [{ "path": String, "resource": CombatEncounter }, ...] }
var categories: Dictionary = {}
## Sorted category names for stable dropdown ordering
var category_names: Array[String] = []
## Currently selected encounter resource
var selected_encounter: CombatEncounter = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	_setup_ui()
	_scan_encounters()
	_populate_category_dropdown()
	_connect_signals()

	print("DebugCombatPanelEnhanced initialized - Press Ctrl + = to toggle")

func _setup_ui():
	if panel_container:
		panel_container.custom_minimum_size = Vector2(450, 350)

	if title_label:
		title_label.text = "Debug Combat Panel"

	if close_button:
		close_button.text = "X"

	if start_button:
		start_button.text = "Start Encounter"
		start_button.disabled = true

func _connect_signals():
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)

	if category_dropdown:
		category_dropdown.item_selected.connect(_on_category_selected)

	if encounter_dropdown:
		encounter_dropdown.item_selected.connect(_on_encounter_selected)

	if start_button:
		start_button.pressed.connect(_on_start_pressed)

# ============================================================================
# FILESYSTEM SCANNING
# ============================================================================

func _scan_encounters():
	"""Recursively scan res://resources/encounters/ for .tres files and group by subfolder."""
	categories.clear()
	category_names.clear()

	var all_files: Array[String] = []
	_scan_directory(ENCOUNTERS_BASE_PATH, all_files)

	for file_path in all_files:
		# Derive category from the relative path between base and the file
		var relative := file_path.trim_prefix(ENCOUNTERS_BASE_PATH)
		var category_name := _category_from_relative(relative)
		if not categories.has(category_name):
			categories[category_name] = []
		var encounter = load(file_path) as CombatEncounter
		if encounter:
			categories[category_name].append({
				"path": file_path,
				"resource": encounter,
			})
		else:
			push_warning("DebugCombatPanel: Failed to load encounter at %s" % file_path)

	# Sort categories: "Root" first, then alphabetical
	category_names.assign(categories.keys())
	category_names.sort()
	# Move "Root" to front if present
	if category_names.has("Root"):
		category_names.erase("Root")
		category_names.insert(0, "Root")

	# Sort encounters within each category by name
	for cat_name in category_names:
		var entries: Array = categories[cat_name]
		entries.sort_custom(func(a, b): return a["resource"].encounter_name.naturalcasecmp_to(b["resource"].encounter_name) < 0)

	_update_stats_total()

func _scan_directory(path: String, results: Array[String]):
	"""Recursively find all .tres files under path."""
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("DebugCombatPanel: Cannot open directory %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_directory(path.path_join(file_name), results)
		else:
			# Handle both .tres and .tres.remap (exported projects)
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var clean_name = file_name.replace(".remap", "")
				results.append(path.path_join(clean_name))
		file_name = dir.get_next()
	dir.list_dir_end()

func _category_from_relative(relative_path: String) -> String:
	"""Turn 'baseline/trash/lone_brute.tres' into 'Baseline > Trash'."""
	var parts = relative_path.get_base_dir().split("/")
	# Filter empty parts (file is in root of encounters/)
	var meaningful: Array[String] = []
	for p in parts:
		if p != "":
			meaningful.append(p.capitalize())
	if meaningful.is_empty():
		return "Root"
	return " > ".join(meaningful)

# ============================================================================
# DROPDOWN POPULATION
# ============================================================================

func _populate_category_dropdown():
	if not category_dropdown:
		return

	category_dropdown.clear()

	if category_names.is_empty():
		category_dropdown.add_item("No encounters found")
		category_dropdown.disabled = true
		return

	category_dropdown.disabled = false
	for cat_name in category_names:
		var count = categories[cat_name].size()
		category_dropdown.add_item("%s (%d)" % [cat_name, count])

	# Auto-select first category
	category_dropdown.selected = 0
	_on_category_selected(0)

func _populate_encounter_dropdown():
	if not encounter_dropdown:
		return

	encounter_dropdown.clear()
	selected_encounter = null
	if start_button:
		start_button.disabled = true

	var idx = category_dropdown.selected
	if idx < 0 or idx >= category_names.size():
		return

	var cat_name = category_names[idx]
	var entries: Array = categories[cat_name]

	if entries.is_empty():
		encounter_dropdown.add_item("No encounters")
		encounter_dropdown.disabled = true
		return

	encounter_dropdown.disabled = false
	for entry in entries:
		var enc: CombatEncounter = entry["resource"]
		var label = enc.encounter_name
		# Append brief stats
		var stats_parts: Array[String] = []
		if enc.enemies.size() > 0:
			stats_parts.append("%d enemy%s" % [enc.enemies.size(), "" if enc.enemies.size() == 1 else "ies"])
		if "difficulty_tier" in enc and enc.difficulty_tier > 0:
			stats_parts.append("T%d" % enc.difficulty_tier)
		if not stats_parts.is_empty():
			label += "  [%s]" % ", ".join(stats_parts)
		encounter_dropdown.add_item(label)

	# Auto-select first encounter
	encounter_dropdown.selected = 0
	_on_encounter_selected(0)

# ============================================================================
# STATS
# ============================================================================

func _update_stats_total():
	if not stats_label:
		return
	var total := 0
	for cat_name in category_names:
		total += categories[cat_name].size()
	stats_label.text = "%d encounters in %d categories" % [total, category_names.size()]

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		# Ctrl + = (equals key) to toggle
		if event.keycode == KEY_EQUAL and event.ctrl_pressed:
			toggle_panel()
			get_viewport().set_input_as_handled()

		# Escape to close when visible
		elif event.keycode == KEY_ESCAPE and is_panel_visible:
			hide_panel()
			get_viewport().set_input_as_handled()

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_category_selected(_index: int):
	_populate_encounter_dropdown()

func _on_encounter_selected(index: int):
	var cat_idx = category_dropdown.selected
	if cat_idx < 0 or cat_idx >= category_names.size():
		return
	var cat_name = category_names[cat_idx]
	var entries: Array = categories[cat_name]
	if index < 0 or index >= entries.size():
		return

	selected_encounter = entries[index]["resource"]
	if start_button:
		start_button.disabled = false

func _on_start_pressed():
	if not selected_encounter:
		return
	if not GameManager:
		push_error("DebugCombatPanel: GameManager not found")
		return

	print("DebugCombatPanel: Starting encounter '%s'" % selected_encounter.encounter_name)
	hide_panel()
	GameManager.start_combat_encounter(selected_encounter)

func _on_close_button_pressed():
	hide_panel()

func _on_refresh_pressed():
	_scan_encounters()
	_populate_category_dropdown()
	print("DebugCombatPanel: Refreshed encounters from filesystem")

# ============================================================================
# PANEL CONTROL
# ============================================================================

func toggle_panel():
	is_panel_visible = !is_panel_visible
	visible = is_panel_visible

	if is_panel_visible and category_dropdown:
		category_dropdown.grab_focus()

func show_panel():
	is_panel_visible = true
	visible = true
	if category_dropdown:
		category_dropdown.grab_focus()

func hide_panel():
	is_panel_visible = false
	visible = false
