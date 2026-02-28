# res://scripts/debug/debug_combat_panel_enhanced.gd
# Enhanced debug panel with search, stats preview, and better styling
# Toggle with Ctrl + = (equals key)
extends Control
class_name DebugCombatPanelEnhanced

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var panel_container: PanelContainer = $PanelContainer
@onready var search_box: LineEdit = $PanelContainer/MarginContainer/VBox/SearchBar/SearchBox
@onready var clear_search_button: Button = $PanelContainer/MarginContainer/VBox/SearchBar/ClearButton
@onready var scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBox/ScrollContainer
@onready var encounter_list: VBoxContainer = $PanelContainer/MarginContainer/VBox/ScrollContainer/EncounterList
@onready var title_label: Label = $PanelContainer/MarginContainer/VBox/TitleBar/Title
@onready var close_button: Button = $PanelContainer/MarginContainer/VBox/TitleBar/CloseButton
@onready var stats_label: Label = $PanelContainer/MarginContainer/VBox/StatsBar/StatsLabel

# ============================================================================
# ENCOUNTER CATEGORIES
# ============================================================================
const ENCOUNTER_CATEGORIES = {
	"Test Encounters": [
		"res://resources/encounters/goblins_basic.tres",
		"res://resources/encounters/goblin_solo.tres",
	],
	"Trash (Baseline)": [
		"res://resources/encounters/baseline/trash/lone_brute.tres",
		"res://resources/encounters/baseline/trash/lone_duelist.tres",
		"res://resources/encounters/baseline/trash/lone_skirmisher.tres",
		"res://resources/encounters/baseline/trash/lone_tank.tres",
		"res://resources/encounters/baseline/trash/lone_archmage.tres",
		"res://resources/encounters/baseline/trash/brute_skirmisher.tres",
		"res://resources/encounters/baseline/trash/duelist_trickster.tres",
		"res://resources/encounters/baseline/trash/battlemage_archmage.tres",
		"res://resources/encounters/baseline/trash/tank_marshal.tres",
		"res://resources/encounters/baseline/trash/brute_support.tres",
	],
	"Elite (Baseline)": [
		"res://resources/encounters/baseline/elite/elite_tank_archmage.tres",
		"res://resources/encounters/baseline/elite/elite_brute_marshal.tres",
		"res://resources/encounters/baseline/elite/elite_warmage_duelist.tres",
		"res://resources/encounters/baseline/elite/elite_skirmish_ambush.tres",
		"res://resources/encounters/baseline/elite/elite_war_party.tres",
		"res://resources/encounters/baseline/elite/elite_brute_squad.tres",
	],
	"Boss (Baseline)": [
		"res://resources/encounters/baseline/boss/boss_brute_solo.tres",
		"res://resources/encounters/baseline/boss/boss_archmage_guard.tres",
		"res://resources/encounters/baseline/boss/boss_tank_retinue.tres",
	],
}

# ============================================================================
# STATE
# ============================================================================
var is_panel_visible: bool = false
var all_encounter_buttons: Array[Dictionary] = []  # {button: Button, encounter: CombatEncounter}
var total_encounters: int = 0
var visible_encounters: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	_setup_ui()
	_populate_encounters()
	_connect_signals()
	_update_stats()
	
	print("🎮 DebugCombatPanelEnhanced initialized - Press Ctrl + = to toggle")

func _setup_ui():
	"""Setup the UI appearance"""
	# Make sure panel is properly sized
	if panel_container:
		panel_container.custom_minimum_size = Vector2(450, 650)
	
	# Setup title
	if title_label:
		title_label.text = "🎮 Debug Combat Panel"
	
	# Setup close button
	if close_button:
		close_button.text = "✕"
	
	# Setup search box
	if search_box:
		search_box.placeholder_text = "Search encounters..."
		search_box.clear_button_enabled = true
	
	# Setup clear button
	if clear_search_button:
		clear_search_button.text = "Clear"

func _populate_encounters():
	"""Populate the encounter list"""
	if not encounter_list:
		return
	
	# Clear existing children
	for child in encounter_list.get_children():
		child.queue_free()
	
	all_encounter_buttons.clear()
	total_encounters = 0
	
	# Add encounters by category
	for category_name in ENCOUNTER_CATEGORIES:
		_add_category_section(category_name, ENCOUNTER_CATEGORIES[category_name])

func _add_category_section(category_name: String, encounter_paths: Array):
	"""Add a category section with encounters"""
	# Category header
	var header = Label.new()
	header.text = category_name
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", ThemeManager.PALETTE.warning)
	header.set_meta("is_category_header", true)
	encounter_list.add_child(header)
	
	# Add some spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	spacer1.set_meta("is_spacer", true)
	encounter_list.add_child(spacer1)
	
	# Track if any encounters in this category are visible
	var category_has_visible = false
	
	# Add encounter buttons
	for encounter_path in encounter_paths:
		var encounter = load(encounter_path) as CombatEncounter
		if encounter:
			var button = _add_encounter_button(encounter, category_name)
			if button:
				category_has_visible = true
		else:
			push_warning("DebugCombatPanel: Failed to load encounter at %s" % encounter_path)
	
	# Add spacing after category
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	spacer2.set_meta("is_spacer", true)
	encounter_list.add_child(spacer2)

func _add_encounter_button(encounter: CombatEncounter, category: String) -> Button:
	"""Add a button for a specific encounter"""
	var button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 40)
	
	# Build button text with stats
	var text = encounter.encounter_name
	var stats_text = ""
	
	# Enemy count
	if encounter.enemies.size() > 0:
		stats_text += "%d enemy%s" % [
			encounter.enemies.size(),
			"" if encounter.enemies.size() == 1 else "ies"
		]
	
	# Difficulty tier
	if "difficulty_tier" in encounter and encounter.difficulty_tier > 0:
		stats_text += "  •  T%d" % encounter.difficulty_tier
	
	# Level range
	if "level_range_min" in encounter and "level_range_max" in encounter:
		if encounter.level_range_min > 0 or encounter.level_range_max > 0:
			stats_text += "  •  L%d-%d" % [encounter.level_range_min, encounter.level_range_max]
	
	button.text = text
	if stats_text != "":
		button.text += "\n  " + stats_text
	
	# Store encounter data for search
	button.set_meta("encounter", encounter)
	button.set_meta("category", category)
	button.set_meta("search_text", (text + " " + stats_text).to_lower())
	
	# Style the button based on encounter type
	if "is_boss_encounter" in encounter and encounter.is_boss_encounter:
		button.modulate = ThemeManager.PALETTE.danger  # Danger color for bosses
	elif "difficulty_tier" in encounter:
		if encounter.difficulty_tier >= 5:
			button.modulate = ThemeManager.PALETTE.rarity_epic  # Epic rarity color for elites
	
	# Connect button press
	button.pressed.connect(_on_encounter_button_pressed.bind(encounter))
	
	# Track button
	all_encounter_buttons.append({
		"button": button,
		"encounter": encounter,
		"category": category
	})
	total_encounters += 1
	
	encounter_list.add_child(button)
	return button

func _connect_signals():
	"""Connect UI signals"""
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	if search_box:
		search_box.text_changed.connect(_on_search_text_changed)
	
	if clear_search_button:
		clear_search_button.pressed.connect(_on_clear_search_pressed)

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
# SEARCH FUNCTIONALITY
# ============================================================================

func _on_search_text_changed(new_text: String):
	"""Filter encounters based on search text"""
	var search_lower = new_text.to_lower()
	visible_encounters = 0
	
	# Track which categories have visible encounters
	var visible_categories = {}
	
	# Filter buttons
	for button_data in all_encounter_buttons:
		var button = button_data["button"]
		var search_text = button.get_meta("search_text") as String
		var category = button.get_meta("category") as String
		
		if search_lower == "" or search_lower in search_text:
			button.visible = true
			visible_encounters += 1
			visible_categories[category] = true
		else:
			button.visible = false
	
	# Show/hide category headers based on whether they have visible encounters
	for child in encounter_list.get_children():
		if child.has_meta("is_category_header"):
			var category_name = child.text
			child.visible = visible_categories.get(category_name, false)
	
	_update_stats()

func _on_clear_search_pressed():
	"""Clear search box"""
	if search_box:
		search_box.text = ""

func _update_stats():
	"""Update stats label"""
	if not stats_label:
		return
	
	if search_box and search_box.text != "":
		stats_label.text = "Showing %d / %d encounters" % [visible_encounters, total_encounters]
	else:
		stats_label.text = "%d encounters available" % total_encounters

# ============================================================================
# PANEL CONTROL
# ============================================================================

func toggle_panel():
	"""Toggle panel visibility"""
	is_panel_visible = !is_panel_visible
	visible = is_panel_visible
	
	if is_panel_visible:
		print("🎮 Debug Combat Panel opened")
		# Focus search box when opened
		if search_box:
			search_box.grab_focus()
	else:
		print("🎮 Debug Combat Panel closed")

func show_panel():
	"""Show the panel"""
	is_panel_visible = true
	visible = true
	if search_box:
		search_box.grab_focus()

func hide_panel():
	"""Hide the panel"""
	is_panel_visible = false
	visible = false

# ============================================================================
# BUTTON CALLBACKS
# ============================================================================

func _on_close_button_pressed():
	"""Close button pressed"""
	hide_panel()

func _on_encounter_button_pressed(encounter: CombatEncounter):
	"""Encounter button pressed - start the combat"""
	if not encounter:
		push_error("DebugCombatPanel: No encounter provided")
		return
	
	if not GameManager:
		push_error("DebugCombatPanel: GameManager not found")
		return
	
	print("🎮 DebugCombatPanel: Starting encounter '%s'" % encounter.encounter_name)
	
	# Hide the panel
	hide_panel()
	
	# Start the encounter
	GameManager.start_combat_encounter(encounter)
