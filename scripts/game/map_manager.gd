# map_manager.gd - Map exploration scene manager
extends Node2D

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var is_initialized: bool = false

# ============================================================================
# NODE REFERENCES
# ============================================================================
var menu_button: Button = null
var combat_button: Button = null
var player_menu: Control = null
var post_combat_summary: Control = null
var map_dice_panel: MapDicePanel = null

# ============================================================================
# SIGNALS
# ============================================================================
signal start_combat()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🗺️ MapScene _ready called")
	
	# Find UI nodes first
	find_ui_nodes()
	
	# Setup UI connections
	setup_ui()
	
	print("🗺️ MapScene ready - waiting for initialization")

func find_ui_nodes():
	"""Find UI nodes in the scene tree"""
	print("🔍 Finding UI nodes...")
	
	# Try to find UILayer
	var ui_layer = find_child("UILayer", true, false)
	if not ui_layer:
		print("❌ UILayer not found!")
		return
	
	print("  ✅ UILayer found")
	
	# Find TopBar
	var top_bar = ui_layer.find_child("TopBar", true, false)
	if top_bar:
		print("  ✅ TopBar found")
		
		# Find buttons
		menu_button = top_bar.find_child("MenuButton", true, false)
		combat_button = top_bar.find_child("CombatButton", true, false)
		
		if menu_button:
			print("  ✅ MenuButton found")
		else:
			print("  ❌ MenuButton NOT found")
		
		if combat_button:
			print("  ✅ CombatButton found")
		else:
			print("  ❌ CombatButton NOT found")
	else:
		print("  ❌ TopBar not found")
	
	
		if combat_button:
			print("  ✅ CombatButton found")
			print("     script: %s" % combat_button.get_script())
			print("     path: %s" % combat_button.get_path())
		else:
			print("  ❌ CombatButton NOT found")
	
	# Find PlayerMenu
	player_menu = ui_layer.find_child("PlayerMenu", true, false)
	if player_menu:
		print("  ✅ PlayerMenu found")
	else:
		print("  ❌ PlayerMenu NOT found")
	
	# Find PostCombatSummary
	post_combat_summary = ui_layer.find_child("PostCombatSummary", true, false)
	if post_combat_summary:
		print("  ✅ PostCombatSummary found")
	else:
		print("  ❌ PostCombatSummary NOT found")
		
	# Find MapDicePanel
	map_dice_panel = ui_layer.find_child("MapDicePanel", true, false)
	if map_dice_panel:
		print("  ✅ MapDicePanel found")
	else:
		print("  ❌ MapDicePanel NOT found")

func setup_ui():
	"""Setup UI connections"""
	print("🔧 Setting up UI...")
	
	# Menu button
	if menu_button:
		if not menu_button.pressed.is_connected(_on_menu_button_pressed):
			menu_button.pressed.connect(_on_menu_button_pressed)
		# Don't set disabled here - let initialize_map() handle it
		print("  ✅ Menu button connected")
	else:
		print("  ❌ Cannot setup menu button - not found")
	
	# Combat button
	if combat_button:
		if not combat_button.pressed.is_connected(_on_combat_button_pressed):
			combat_button.pressed.connect(_on_combat_button_pressed)
		# Don't set disabled here - let initialize_map() handle it
		print("  ✅ Combat button connected")
	else:
		print("  ❌ Cannot setup combat button - not found")
	
	# Player menu
	if player_menu:
		player_menu.hide()
		if player_menu.has_signal("menu_closed") and not player_menu.menu_closed.is_connected(_on_menu_closed):
			player_menu.menu_closed.connect(_on_menu_closed)
		print("  ✅ Player menu setup")
	else:
		print("  ❌ Cannot setup player menu - not found")
	
	# Post-combat summary
	if post_combat_summary:
		post_combat_summary.hide()
		if post_combat_summary.has_signal("summary_closed") and not post_combat_summary.summary_closed.is_connected(_on_summary_closed):
			post_combat_summary.summary_closed.connect(_on_summary_closed)
		print("  ✅ Post-combat summary setup")
	else:
		print("  ❌ Cannot setup post-combat summary - not found")

func initialize_map(p_player: Player):
	"""Initialize with player reference"""
	print("🗺️ Initializing map with player")
	player = p_player
	is_initialized = true
	
	# Enable buttons NOW
	if menu_button:
		menu_button.disabled = false
		print("  ✅ Menu button ENABLED (disabled=%s)" % menu_button.disabled)
	else:
		print("  ❌ Cannot enable menu button - is null")
	
	if combat_button:
		combat_button.disabled = false
		print("  ✅ Combat button ENABLED (disabled=%s)" % combat_button.disabled)
	else:
		print("  ❌ Cannot enable combat button - is null")
	
	print("  Player HP: %d/%d" % [player.current_hp, player.max_hp])
	
	# Initialize MapDicePanel
	if map_dice_panel:
		map_dice_panel.initialize(player)
		print("  ✅ MapDicePanel initialized")
	else:
		print("  ⚠️ MapDicePanel not found - cannot initialize")
	
	print("🗺️ Map initialization complete")

# ============================================================================
# PUBLIC API
# ============================================================================

func show_post_combat_summary(results: Dictionary):
	"""Show the post-combat summary popup"""
	if post_combat_summary and post_combat_summary.has_method("show_summary"):
		post_combat_summary.show_summary(results)
	else:
		print("❌ Cannot show summary - post_combat_summary is null or missing method")

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_menu_button_pressed():
	"""Menu button clicked"""
	print("📋 Menu button pressed!")
	
	if not is_initialized:
		print("❌ Map not initialized yet")
		return
	
	if not player:
		print("❌ Cannot open menu: no player")
		return
	
	if not player_menu:
		print("❌ Cannot open menu: player_menu is null")
		return
	
	if player_menu.visible:
		print("📋 Closing menu")
		player_menu.hide()
		_on_menu_closed()
	else:
		print("📋 Opening menu")
		if player_menu.has_method("open_menu"):
			player_menu.open_menu(player)
		else:
			player_menu.show()

func _on_combat_button_pressed():
	"""Test combat button clicked"""
	print("\n🔴 Combat button pressed!")
	

func _on_menu_closed():
	"""Player menu closed"""
	print("📋 Menu closed")

func _on_summary_closed():
	"""Post-combat summary closed"""
	print("📊 Summary closed")

# ============================================================================
# INPUT
# ============================================================================

func _input(event):
	if is_initialized and event.is_action_pressed("ui_menu") and player:
		_on_menu_button_pressed()
		get_viewport().set_input_as_handled()
