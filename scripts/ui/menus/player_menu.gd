# player_menu.gd - Main player menu controller
# Uses button-based tab navigation with self-scoped discovery
# All child discovery is scoped to this node's subtree (not tree-global)
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
var tab_content_panels: Dictionary = {}  # tab_name -> Control
var current_tab_name: String = ""
var close_button: Button = null

var _content_area: Control = null
var _tab_buttons: Control = null


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	_set_panel_container_visible(false)
	await get_tree().process_frame
	_discover_and_connect_children()

func _set_panel_container_visible(vis: bool):
	for child in get_children():
		if child is PanelContainer:
			child.visible = vis


func _discover_and_connect_children():
	"""Discover all menu components within our own subtree"""
	print("📋 PlayerMenu: Discovering components...")

	# --- Tab Buttons ---
	# Find buttons with tab_name metadata inside our subtree
	var all_buttons = find_children("*", "Button", true, true)
	for button in all_buttons:
		var tab_name = button.get_meta("tab_name", "")
		if tab_name:
			tab_buttons.append(button)
			button.toggled.connect(_on_tab_button_toggled.bind(tab_name))
			print("  ✓ Connected tab button: %s" % tab_name)
	# --- Tab Content Panels ---
	# Find controls with tab_name metadata that are in the content group
	var all_controls = find_children("*", "Control", true, true)
	for node in all_controls:
		# Check if it has tab_name metadata AND is meant to be tab content
		# (tab buttons also have tab_name, so filter by group membership)
		if node.is_in_group("player_menu_tab_content"):
			var tab_name = node.get_meta("tab_name", "")
			if tab_name:
				tab_content_panels[tab_name] = node
				_register_tab(node)
				print("  ✓ Registered content: %s" % tab_name)
				# Cache for click-outside detection
	_content_area = find_child("ContentArea", true, false)
	_tab_buttons = find_child("TabButtons", true, false)

	# --- Close Button ---
	# Find by name within our subtree (owned=true to include scene-defined nodes)
	var close_btn = find_child("CloseButton", true, true)
	if close_btn and close_btn is Button:
		close_button = close_btn
		close_button.pressed.connect(_on_close_pressed)
		print("  ✓ Connected close button")
	else:
		push_warning("PlayerMenu: CloseButton not found in subtree!")

	print("📋 Found %d tab buttons, %d content panels" % [
		tab_buttons.size(), tab_content_panels.size()
	])

func _register_tab(tab: Control):
	"""Register a menu tab and connect its signals"""
	if tab in active_tabs:
		return

	active_tabs.append(tab)

	if tab.has_signal("refresh_requested"):
		tab.refresh_requested.connect(_on_tab_refresh_requested.bind(tab))

	if tab.has_signal("data_changed"):
		tab.data_changed.connect(_on_tab_data_changed.bind(tab))

	if tab.has_signal("skill_learned"):
		tab.skill_learned.connect(_on_skill_learned)

# ============================================================================
# PUBLIC API
# ============================================================================

func toggle_menu(p_player: Player):
	"""Toggle menu open/closed. Single entry point for callers."""
	if visible:
		close_menu()
	else:
		open_menu(p_player)

func open_menu(p_player: Player):
	"""Open menu with player data"""
	player = p_player
	_distribute_player_data()

	# Hide ALL tabs first
	for tab_name in tab_content_panels:
		tab_content_panels[tab_name].hide()

	# Always show Character tab by default
	_show_tab("Character")

	# Set Character button as pressed
	for button in tab_buttons:
		var tab_name = button.get_meta("tab_name", "")
		button.button_pressed = (tab_name == "Character")

	_update_button_visuals()
	_set_panel_container_visible(true)
	show()
	print("📋 PlayerMenu: Opened")

func close_menu():
	"""Close the menu"""
	hide()
	_set_panel_container_visible(false)
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

func _has_visible_popup() -> bool:
	"""Check if any tab has an open sub-popup (blocks Escape from closing menu)."""
	for tab in active_tabs:
		if tab.has_method("has_active_popup") and tab.has_active_popup():
			return true
	return false


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

	for name in tab_content_panels:
		tab_content_panels[name].hide()

	if tab_content_panels.has(tab_name):
		tab_content_panels[tab_name].show()
		tab_changed.emit(tab_name)
		print("📋 Switched to tab: %s" % tab_name)

func _update_button_visuals():
	"""Update tab button active/inactive appearance"""
	for btn in tab_buttons:
		if btn.button_pressed:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			btn.modulate = Color(ThemeManager.PALETTE.text_muted.r,
				ThemeManager.PALETTE.text_muted.g,
				ThemeManager.PALETTE.text_muted.b, 1.0)



# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_tab_button_toggled(button_pressed: bool, tab_name: String):
	"""Tab button toggled"""
	if button_pressed:
		_show_tab(tab_name)
	_update_button_visuals()

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
	for tab in active_tabs:
		if tab.has_method("on_external_data_change"):
			tab.on_external_data_change()

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event):
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		if _has_visible_popup():
			return
		close_menu()
		get_viewport().set_input_as_handled()
		return

	# Click outside visible menu content → close
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var inside := false
		if _content_area and _content_area.get_global_rect().has_point(event.position):
			inside = true
		if _tab_buttons and _tab_buttons.get_global_rect().has_point(event.position):
			inside = true
		if not inside:
			close_menu()
			get_viewport().set_input_as_handled()
