# res://scripts/game/game_root.gd
# Main game controller - manages map, combat, and persistent UI layers
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
@onready var portrait_controller: PortraitController = $PersistentUILayer/PortraitVBox/PortraitContainer


# Found from MapScene
var player_menu: Control = null

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
		# Connect to player_created signal for future player creation
		if not GameManager.player_created.is_connected(_on_player_created):
			GameManager.player_created.connect(_on_player_created)
	
	# Initialize map
	_show_map()
	
	# Find and connect PlayerMenu from MapScene
	_setup_player_menu()
	
	# TIMING FIX: Check if player already exists (GameManager autoload ran first)
	# Use call_deferred to ensure all nodes are ready
	call_deferred("_check_existing_player")
	
	print("🎮 GameRoot ready")

func _check_existing_player():
	"""Check if GameManager already created the player before we connected"""
	if GameManager and GameManager.player:
		print("🎮 GameRoot: Player already exists, initializing UI now")
		_on_player_created(GameManager.player)


func _setup_player_menu():
	if not map_scene:
		return
	
	player_menu = map_scene.find_child("PlayerMenu", true, false)
	
	if player_menu:
		print("  ✅ Found PlayerMenu in MapScene — reparenting to PersistentUILayer")
		
		player_menu.get_parent().remove_child(player_menu)
		ui_layer.add_child(player_menu)
		player_menu.hide()
		player_menu.z_index = -1
		
		# Match bottom to PanelContainer's top using anchor instead of offset
		if bottom_panel:
			player_menu.anchor_bottom = bottom_panel.anchor_top
			player_menu.offset_bottom = bottom_panel.offset_top
		
		if bottom_ui and bottom_ui.has_method("set_player_menu"):
			bottom_ui.set_player_menu(player_menu)
			print("  ✅ Connected PlayerMenu to BottomUI")


func _on_player_created(player: Resource):
	"""Called when GameManager creates the player"""
	print("🎮 GameRoot: Player created, initializing UI")
	
	# Initialize BottomUI with player
	if bottom_ui:
		if bottom_ui.has_method("initialize"):
			bottom_ui.initialize(player)
			print("  ✅ BottomUI initialized with player")
	
	# Initialize portrait controller
	if portrait_controller:
		portrait_controller.set_player(player)
		portrait_controller.portrait_clicked.connect(_on_portrait_clicked)
		print("  ✅ PortraitController initialized with player")

func _on_portrait_clicked():
	"""Portrait clicked — open character sheet."""
	if bottom_ui and bottom_ui.has_method("_on_menu_button_pressed"):
		bottom_ui._on_menu_button_pressed()
	elif player_menu:
		if player_menu.visible:
			if player_menu.has_method("close_menu"):
				player_menu.close_menu()
			else:
				player_menu.hide()
		else:
			if player_menu.has_method("open_menu") and GameManager.player:
				player_menu.open_menu(GameManager.player)
			else:
				player_menu.show()


# ============================================================================
# LAYER MANAGEMENT
# ============================================================================

func start_combat(encounter: Resource = null):
	if is_in_combat:
		push_warning("GameRoot: Already in combat!")
		return
	
	print("⚔️ GameRoot: Starting combat overlay")
	is_in_combat = true
	
	map_scene.process_mode = Node.PROCESS_MODE_DISABLED
	combat_layer.visible = true
	combat_layer.process_mode = Node.PROCESS_MODE_INHERIT
	
	ui_layer.layer = 5
	
	# >>> NEW: Tell CombatManager to pick up the encounter <
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
# UI ACCESS
# ============================================================================

func get_bottom_ui() -> Control:
	return bottom_ui

func get_dice_panel() -> Control:
	if bottom_ui and bottom_ui.has_method("get_dice_panel"):
		return bottom_ui.get_dice_panel()
	return null
