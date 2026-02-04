# player_menu.gd - Main player menu controller
# Uses signal bubbling with button-based tab navigation
extends Control

# ============================================================================
# SIGNALS
# ============================================================================
signal menu_closed()
signal tab_changed(tab_name: String)

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var active_tabs: Array[Control] = []
var tab_buttons: Array[Button] = []
var tab_content_panels: Dictionary = {}
var current_tab_name: String = ""

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	await get_tree().process_frame  # Wait for children to be ready
	_discover_and_connect_children()

func _discover_and_connect_children():
	"""Discover all menu tabs and connect their signals"""
	print("📋 PlayerMenu: Discovering components...")
	
	# Find tab buttons by group
	var buttons = get_tree().get_nodes_in_group("player_menu_tab_button")
	for button in buttons:
		if button is Button:
			tab_buttons.append(button)
		var tab_name = button.get_meta("tab_name", "")
		if tab_name:
			button.toggled.connect(_on_tab_button_toggled.bind(tab_name))
			print("  ✓ Connected button: %s" % tab_name)
	
	# Find tab content panels by group
	var content_nodes = get_tree().get_nodes_in_group("player_menu_tab_content")
	for node in content_nodes:
		var tab_name = node.get_meta("tab_name", "")
		if tab_name:
			tab_content_panels[tab_name] = node
			_register_tab(node)
			print("  ✓ Registered content: %s" % tab_name)
	
	# Find the close button
	var close_buttons = find_children("*", "Button", true, false)
	for button in close_buttons:
		if "close" in button.name.to_lower():
			button.pressed.connect(_on_close_pressed)
			print("  ✓ Connected close button")
			break

func _register_tab(tab: Control):
	"""Register a menu tab"""
	if tab in active_tabs:
		return
	
	active_tabs.append(tab)
	
	# Connect tab signals if they exist
	if tab.has_signal("refresh_requested"):
		tab.refresh_requested.connect(_on_tab_refresh_requested.bind(tab))
	
	if tab.has_signal("data_changed"):
		tab.data_changed.connect(_on_tab_data_changed.bind(tab))
	
	# Connect skill_learned signal from SkillsTab
	if tab.has_signal("skill_learned"):
		tab.skill_learned.connect(_on_skill_learned)

# ============================================================================
# PUBLIC API
# ============================================================================

func open_menu(p_player: Player):
	"""Open menu with player data"""
	player = p_player
	_distribute_player_data()
	
	# Hide ALL tabs first
	for name in tab_content_panels:
		tab_content_panels[name].hide()
	
	# Always show Character tab by default
	_show_tab("Character")
	
	# Set Character button as pressed
	for button in tab_buttons:
		var tab_name = button.get_meta("tab_name", "")
		button.button_pressed = (tab_name == "Character")
	
	show()
	print("📋 PlayerMenu: Opened")


func close_menu():
	"""Close the menu"""
	hide()
	menu_closed.emit()
	print("📋 PlayerMenu: Closed")

func refresh_all_tabs():
	"""Request all tabs to refresh their displays"""
	for tab in active_tabs:
		if tab.has_method("refresh"):
			tab.refresh()

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _distribute_player_data():
	"""Send player data to all registered tabs"""
	for tab in active_tabs:
		if tab.has_method("set_player"):
			tab.set_player(player)

func _show_tab(tab_name: String):
	"""Show the specified tab, hide all others"""
	if current_tab_name == tab_name:
		return
	
	current_tab_name = tab_name
	
	# Hide all content panels
	for name in tab_content_panels:
		var panel = tab_content_panels[name]
		panel.hide()
	
	# Show selected panel
	if tab_content_panels.has(tab_name):
		tab_content_panels[tab_name].show()
		tab_changed.emit(tab_name)
		print("📋 Switched to tab: %s" % tab_name)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_tab_button_toggled(button_pressed: bool, tab_name: String):
	"""Tab button toggled"""
	if button_pressed:
		_show_tab(tab_name)

func _on_close_pressed():
	"""Close button pressed"""
	close_menu()

func _on_tab_refresh_requested(tab: Control):
	"""Tab requested a refresh"""
	if player and tab.has_method("set_player"):
		tab.set_player(player)

func _on_tab_data_changed(tab: Control):
	"""Tab reports data changed - notify other tabs"""
	for other_tab in active_tabs:
		if other_tab != tab and other_tab.has_method("on_external_data_change"):
			other_tab.on_external_data_change()

func _on_skill_learned(skill: SkillResource, new_rank: int):
	"""A skill was learned - notify other tabs"""
	print("📋 PlayerMenu: Skill learned - %s rank %d" % [skill.skill_name, new_rank])
	
	# Notify all other tabs that data changed
	for tab in active_tabs:
		if tab.has_method("on_external_data_change"):
			tab.on_external_data_change()

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
