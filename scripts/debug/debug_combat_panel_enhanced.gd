# res://scripts/debug/debug_combat_panel_enhanced.gd
# Enhanced debug panel with filesystem-scanning encounter and dungeon selection
# Toggle with Ctrl + = (equals key)
extends Control
class_name DebugCombatPanelEnhanced

# ============================================================================
# NODE REFERENCES — Encounter tab
# ============================================================================
@onready var panel_container: PanelContainer = $PanelContainer
@onready var tab_bar: TabBar = $PanelContainer/MarginContainer/VBox/TabBar
@onready var encounter_tab: VBoxContainer = $PanelContainer/MarginContainer/VBox/EncounterTab
@onready var category_dropdown: OptionButton = $PanelContainer/MarginContainer/VBox/EncounterTab/CategoryBar/CategoryDropdown
@onready var encounter_dropdown: OptionButton = $PanelContainer/MarginContainer/VBox/EncounterTab/EncounterBar/EncounterDropdown
@onready var start_button: Button = $PanelContainer/MarginContainer/VBox/EncounterTab/StartButton
@onready var title_label: Label = $PanelContainer/MarginContainer/VBox/TitleBar/Title
@onready var close_button: Button = $PanelContainer/MarginContainer/VBox/TitleBar/CloseButton
@onready var stats_label: Label = $PanelContainer/MarginContainer/VBox/EncounterTab/StatsBar/StatsLabel
@onready var refresh_button: Button = $PanelContainer/MarginContainer/VBox/TitleBar/RefreshButton

# ============================================================================
# NODE REFERENCES — Dungeon tab
# ============================================================================
@onready var dungeon_tab: VBoxContainer = $PanelContainer/MarginContainer/VBox/DungeonTab
@onready var dungeon_dropdown: OptionButton = $PanelContainer/MarginContainer/VBox/DungeonTab/DungeonBar/DungeonDropdown
@onready var dungeon_info_label: Label = $PanelContainer/MarginContainer/VBox/DungeonTab/DungeonInfoLabel
@onready var dungeon_stats_label: Label = $PanelContainer/MarginContainer/VBox/DungeonTab/DungeonStatsLabel
@onready var start_dungeon_button: Button = $PanelContainer/MarginContainer/VBox/DungeonTab/StartDungeonButton

# ============================================================================
# CONSTANTS
# ============================================================================
const ENCOUNTERS_BASE_PATH := "res://resources/encounters/"
const DUNGEONS_BASE_PATH := "res://resources/dungeon/"

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

## Dungeon state
var dungeon_entries: Array = []  # [{ "path": String, "resource": DungeonDefinition }]
var selected_dungeon: DungeonDefinition = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	_setup_ui()
	_scan_encounters()
	_scan_dungeons()
	_populate_category_dropdown()
	_populate_dungeon_dropdown()
	_connect_signals()

	print("DebugCombatPanelEnhanced initialized - Press Ctrl + = to toggle")

func _setup_ui():
	if panel_container:
		panel_container.custom_minimum_size = Vector2(450, 400)

	if title_label:
		title_label.text = "Debug Panel"

	if close_button:
		close_button.text = "X"

	if start_button:
		start_button.text = "Start Encounter"
		start_button.disabled = true

	if start_dungeon_button:
		start_dungeon_button.text = "Start Dungeon"
		start_dungeon_button.disabled = true

	# Setup tabs
	if tab_bar:
		tab_bar.add_tab("Encounters")
		tab_bar.add_tab("Dungeons")
		tab_bar.current_tab = 0

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

	if tab_bar:
		tab_bar.tab_changed.connect(_on_tab_changed)

	if dungeon_dropdown:
		dungeon_dropdown.item_selected.connect(_on_dungeon_selected)

	if start_dungeon_button:
		start_dungeon_button.pressed.connect(_on_start_dungeon_pressed)

# ============================================================================
# TAB SWITCHING
# ============================================================================

func _on_tab_changed(tab_index: int):
	if encounter_tab:
		encounter_tab.visible = (tab_index == 0)
	if dungeon_tab:
		dungeon_tab.visible = (tab_index == 1)

# ============================================================================
# ENCOUNTER FILESYSTEM SCANNING
# ============================================================================

func _scan_encounters():
	categories.clear()
	category_names.clear()

	var all_files: Array[String] = []
	_scan_directory(ENCOUNTERS_BASE_PATH, all_files)

	for file_path in all_files:
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

	category_names.assign(categories.keys())
	category_names.sort()
	if category_names.has("Root"):
		category_names.erase("Root")
		category_names.insert(0, "Root")

	for cat_name in category_names:
		var entries: Array = categories[cat_name]
		entries.sort_custom(func(a, b): return a["resource"].encounter_name.naturalcasecmp_to(b["resource"].encounter_name) < 0)

	_update_stats_total()

# ============================================================================
# DUNGEON FILESYSTEM SCANNING
# ============================================================================

func _scan_dungeons():
	dungeon_entries.clear()
	selected_dungeon = null

	# Scan only top-level .tres files in the dungeon directory
	var dir = DirAccess.open(DUNGEONS_BASE_PATH)
	if not dir:
		push_warning("DebugCombatPanel: Cannot open directory %s" % DUNGEONS_BASE_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var clean_name = file_name.replace(".remap", "")
				var full_path = DUNGEONS_BASE_PATH.path_join(clean_name)
				var res = load(full_path)
				if res is DungeonDefinition:
					dungeon_entries.append({
						"path": full_path,
						"resource": res,
					})
		file_name = dir.get_next()
	dir.list_dir_end()

	# Also scan subdirectories one level deep for .tres that are DungeonDefinition
	dir.list_dir_begin()
	file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_path = DUNGEONS_BASE_PATH.path_join(file_name)
			_scan_dungeon_subdir(sub_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by dungeon name
	dungeon_entries.sort_custom(func(a, b): return a["resource"].dungeon_name.naturalcasecmp_to(b["resource"].dungeon_name) < 0)

	if dungeon_stats_label:
		dungeon_stats_label.text = "%d dungeon%s available" % [dungeon_entries.size(), "" if dungeon_entries.size() == 1 else "s"]

func _scan_dungeon_subdir(path: String):
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var clean_name = file_name.replace(".remap", "")
				var full_path = path.path_join(clean_name)
				var res = load(full_path)
				if res is DungeonDefinition:
					# Avoid duplicates
					var already_added := false
					for entry in dungeon_entries:
						if entry["path"] == full_path:
							already_added = true
							break
					if not already_added:
						dungeon_entries.append({
							"path": full_path,
							"resource": res,
						})
		file_name = dir.get_next()
	dir.list_dir_end()

# ============================================================================
# SHARED HELPERS
# ============================================================================

func _scan_directory(path: String, results: Array[String]):
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
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var clean_name = file_name.replace(".remap", "")
				results.append(path.path_join(clean_name))
		file_name = dir.get_next()
	dir.list_dir_end()

func _category_from_relative(relative_path: String) -> String:
	var parts = relative_path.get_base_dir().split("/")
	var meaningful: Array[String] = []
	for p in parts:
		if p != "":
			meaningful.append(p.capitalize())
	if meaningful.is_empty():
		return "Root"
	return " > ".join(meaningful)

# ============================================================================
# ENCOUNTER DROPDOWN POPULATION
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
		var stats_parts: Array[String] = []
		if enc.enemies.size() > 0:
			stats_parts.append("%d enemy%s" % [enc.enemies.size(), "" if enc.enemies.size() == 1 else "ies"])
		if "difficulty_tier" in enc and enc.difficulty_tier > 0:
			stats_parts.append("T%d" % enc.difficulty_tier)
		if not stats_parts.is_empty():
			label += "  [%s]" % ", ".join(stats_parts)
		encounter_dropdown.add_item(label)

	encounter_dropdown.selected = 0
	_on_encounter_selected(0)

# ============================================================================
# DUNGEON DROPDOWN POPULATION
# ============================================================================

func _populate_dungeon_dropdown():
	if not dungeon_dropdown:
		return

	dungeon_dropdown.clear()
	selected_dungeon = null
	if start_dungeon_button:
		start_dungeon_button.disabled = true

	if dungeon_entries.is_empty():
		dungeon_dropdown.add_item("No dungeons found")
		dungeon_dropdown.disabled = true
		return

	dungeon_dropdown.disabled = false
	for entry in dungeon_entries:
		var def: DungeonDefinition = entry["resource"]
		var label = def.dungeon_name
		label += "  [Lv%d, %d floors]" % [def.dungeon_level, def.floor_count]
		dungeon_dropdown.add_item(label)

	dungeon_dropdown.selected = 0
	_on_dungeon_selected(0)

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

func _update_dungeon_info():
	if not dungeon_info_label or not selected_dungeon:
		if dungeon_info_label:
			dungeon_info_label.text = ""
		return

	var d := selected_dungeon
	var parts: Array[String] = []
	if d.combat_encounters.size() > 0:
		parts.append("%d trash" % d.combat_encounters.size())
	if d.elite_encounters.size() > 0:
		parts.append("%d elite" % d.elite_encounters.size())
	if d.boss_encounters.size() > 0:
		parts.append("%d boss" % d.boss_encounters.size())
	if d.event_pool.size() > 0:
		parts.append("%d events" % d.event_pool.size())
	if d.shrine_pool.size() > 0:
		parts.append("%d shrines" % d.shrine_pool.size())

	var info := "Region %d | " % d.dungeon_region if "dungeon_region" in d else ""
	info += ", ".join(parts) if not parts.is_empty() else "Empty pools"
	dungeon_info_label.text = info

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
# ENCOUNTER CALLBACKS
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

# ============================================================================
# DUNGEON CALLBACKS
# ============================================================================

func _on_dungeon_selected(index: int):
	if index < 0 or index >= dungeon_entries.size():
		selected_dungeon = null
		if start_dungeon_button:
			start_dungeon_button.disabled = true
		return

	selected_dungeon = dungeon_entries[index]["resource"]
	if start_dungeon_button:
		start_dungeon_button.disabled = false
	_update_dungeon_info()

func _on_start_dungeon_pressed():
	if not selected_dungeon:
		return
	if not GameManager or not GameManager.game_root:
		push_error("DebugCombatPanel: GameManager.game_root not found")
		return

	print("DebugCombatPanel: Starting dungeon '%s'" % selected_dungeon.dungeon_name)
	hide_panel()
	GameManager.game_root.enter_dungeon(selected_dungeon)

# ============================================================================
# SHARED CALLBACKS
# ============================================================================

func _on_close_button_pressed():
	hide_panel()

func _on_refresh_pressed():
	_scan_encounters()
	_scan_dungeons()
	_populate_category_dropdown()
	_populate_dungeon_dropdown()
	print("DebugCombatPanel: Refreshed from filesystem")

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
