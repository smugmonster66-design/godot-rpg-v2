# res://scripts/game/game_root.gd
# Main game controller - manages map, combat, and persistent UI layers
# PlayerMenu and PostCombatSummary live directly in PersistentUILayer (no reparenting)
extends Node

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var map_layer: CanvasLayer = $MapLayer
@onready var combat_layer: CanvasLayer = $CombatLayer
@onready var ui_layer: CanvasLayer = $PersistentUILayer
@onready var bottom_panel: PanelContainer = $PersistentUILayer/PanelContainer
@onready var map_scene: Node = $MapLayer/MapScene
@onready var combat_scene: Node = $CombatLayer/CombatScene
@onready var bottom_ui: Control = $PersistentUILayer/BottomUIPanel

# Persistent UI elements (direct children of PersistentUILayer)
var player_menu: Control = null
var post_combat_summary: Control = null

# Add to node references section
var portrait_controller: Control = null

# ============================================================================
# STATE
# ============================================================================
var is_in_combat: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🎮 GameRoot initializing...")

	# Start with combat hidden
	combat_layer.visible = false
	combat_layer.process_mode = Node.PROCESS_MODE_DISABLED

	# Register with GameManager
	if GameManager:
		GameManager.game_root = self
		if not GameManager.player_created.is_connected(_on_player_created):
			GameManager.player_created.connect(_on_player_created)

	# Initialize map
	_show_map()

	# Find persistent UI elements
	_setup_persistent_ui()

	# TIMING FIX: Check if player already exists (GameManager autoload ran first)
	call_deferred("_check_existing_player")

	# Debug: center line
	var debug_line = Control.new()
	debug_line.name = "DebugCenterLine"
	debug_line.z_index = 100
	debug_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_line.draw.connect(func():
		var cx = debug_line.size.x / 2.0
		debug_line.draw_line(Vector2(cx, 0), Vector2(cx, debug_line.size.y), Color.RED, 2.0)
	)
	ui_layer.add_child(debug_line)
	
	
	
	
	
	
	
	
	
	
	
	
	
	



	print("🎮 GameRoot ready")

func _check_existing_player():
	"""Check if GameManager already created the player before we connected"""
	if GameManager and GameManager.player:
		print("🎮 GameRoot: Player already exists, initializing UI now")
		_on_player_created(GameManager.player)

func _setup_persistent_ui():
	"""Find and wire up persistent UI elements in PersistentUILayer"""
	
	# PlayerMenu — lives directly in PersistentUILayer
	player_menu = ui_layer.find_child("PlayerMenu", true, false)
	if player_menu:
		player_menu.hide()
		player_menu.z_index = -1
		
		# Position menu above the bottom panel
		if bottom_panel:
			player_menu.anchor_bottom = bottom_panel.anchor_top
			player_menu.offset_bottom = bottom_panel.offset_top
			
		# Give BottomUIPanel the menu reference for toggle
		if bottom_ui and bottom_ui.has_method("set_player_menu"):
			bottom_ui.set_player_menu(player_menu)
			print("  ✅ PlayerMenu wired to BottomUI")
	else:
		push_warning("GameRoot: PlayerMenu not found in PersistentUILayer!")
		
	# PostCombatSummary — also in PersistentUILayer
	post_combat_summary = ui_layer.find_child("PostCombatSummary", true, false)
	if post_combat_summary:
		post_combat_summary.hide()
		if post_combat_summary.has_signal("summary_closed"):
			if not post_combat_summary.summary_closed.is_connected(_on_summary_closed):
				post_combat_summary.summary_closed.connect(_on_summary_closed)
		print("  ✅ PostCombatSummary found")
	else:
		print("  ⚠️ PostCombatSummary not found in PersistentUILayer")
	
	# PortraitController — click-to-open menu
	portrait_controller = ui_layer.find_child("PortraitContainer", true, false)
	if portrait_controller and portrait_controller.has_signal("portrait_clicked"):
		if not portrait_controller.portrait_clicked.is_connected(_on_portrait_clicked):
			portrait_controller.portrait_clicked.connect(_on_portrait_clicked)
		print("  ✅ PortraitController connected")
	else:
		print("  ⚠️ PortraitController not found or missing portrait_clicked signal")
	

func _on_player_created(player: Resource):
	"""Called when GameManager creates the player"""
	print("🎮 GameRoot: Player created, initializing UI")

	# Initialize BottomUI with player
	if bottom_ui:
		if bottom_ui.has_method("initialize"):
			bottom_ui.initialize(player)
			print("  ✅ BottomUI initialized with player")
		else:
			push_warning("BottomUI has no initialize method")
	else:
		push_warning("bottom_ui is null!")
		
	
	# Initialize portrait controller with player
	if portrait_controller and portrait_controller.has_method("set_player"):
		portrait_controller.set_player(player)
		print("  ✅ PortraitController initialized with player")


func _on_portrait_clicked():
	"""Portrait clicked — toggle player menu"""
	if not _can_open_menu():
		print("📋 Menu blocked — combat action phase")
		return
	if player_menu and player_menu.has_method("toggle_menu") and GameManager.player:
		player_menu.toggle_menu(GameManager.player)

func _can_open_menu() -> bool:
	"""Check if the menu is allowed to open right now."""
	if not is_in_combat:
		return true
	# Allow menu during prep phase, block during action/enemy/animation
	var combat_manager = combat_scene.find_child("CombatManager", true, false) if combat_scene else null
	if not combat_manager:
		combat_manager = combat_scene
	if combat_manager and combat_manager.has_method("is_in_prep_phase"):
		return combat_manager.is_in_prep_phase()
	# If we can't find the combat manager, block by default during combat
	return false



# ============================================================================
# LAYER MANAGEMENT
# ============================================================================

func start_combat(encounter: Resource = null):
	if is_in_combat:
		push_warning("GameRoot: Already in combat!")
		return

	print("⚔️ GameRoot: Starting combat overlay")
	is_in_combat = true

	# Close the player menu if it's open
	if player_menu and player_menu.visible and player_menu.has_method("close_menu"):
		player_menu.close_menu()

	map_scene.process_mode = Node.PROCESS_MODE_DISABLED
	combat_layer.visible = true
	combat_layer.process_mode = Node.PROCESS_MODE_INHERIT

	ui_layer.layer = 5

	# Tell CombatManager to pick up the encounter
	var combat_manager = combat_scene.find_child("CombatManager", true, false)
	if not combat_manager:
		combat_manager = combat_scene  # CombatScene might BE the manager
	if combat_manager and combat_manager.has_method("check_pending_encounter"):
		combat_manager.check_pending_encounter()

	if bottom_ui and bottom_ui.has_method("on_combat_started"):
		bottom_ui.on_combat_started()

func end_combat(player_won: bool = true):
	"""Hide combat layer, resume map"""
	if not is_in_combat:
		push_warning("GameRoot: Not in combat!")
		return

	print("⚔️ GameRoot: Ending combat (player_won=%s)" % player_won)
	is_in_combat = false

	# Hide and disable combat layer
	combat_layer.visible = false
	combat_layer.process_mode = Node.PROCESS_MODE_DISABLED

	# Reset combat scene for next time
	if combat_scene and combat_scene.has_method("reset_combat"):
		combat_scene.reset_combat()

	# Resume map
	map_scene.process_mode = Node.PROCESS_MODE_INHERIT

	ui_layer.layer = 100

	# Notify UI
	if bottom_ui and bottom_ui.has_method("on_combat_ended"):
		bottom_ui.on_combat_ended(player_won)

	# Notify GameManager
	if GameManager:
		GameManager.on_combat_ended(player_won)

func _show_map():
	"""Ensure map is visible and running"""
	map_layer.visible = true
	map_scene.process_mode = Node.PROCESS_MODE_INHERIT

# ============================================================================
# PUBLIC API
# ============================================================================

func show_post_combat_summary(results: Dictionary):
	"""Show the post-combat summary popup"""
	if post_combat_summary and post_combat_summary.has_method("show_summary"):
		post_combat_summary.show_summary(results)

func get_bottom_ui() -> Control:
	return bottom_ui

func get_dice_panel() -> Control:
	if bottom_ui and bottom_ui.has_method("get_dice_panel"):
		return bottom_ui.get_dice_panel()
	return null

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_summary_closed():
	"""Post-combat summary closed"""
	print("📊 Summary closed")
