# res://scripts/game/game_root.gd
# Main game controller - manages map, combat, and persistent UI layers
extends Node

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var map_layer: CanvasLayer = $MapLayer
@onready var combat_layer: CanvasLayer = $CombatLayer
@onready var ui_layer: CanvasLayer = $PersistentUILayer

@onready var map_scene: Node = $MapLayer/MapScene
@onready var combat_scene: Node = $CombatLayer/CombatScene
@onready var bottom_ui: Control = $PersistentUILayer/BottomUIPanel

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
	"""Find PlayerMenu in MapScene and connect to BottomUI"""
	if not map_scene:
		print("  ⚠️ No map_scene to search for PlayerMenu")
		return
	
	# Look for PlayerMenu in MapScene's UILayer
	player_menu = map_scene.find_child("PlayerMenu", true, false)
	
	if player_menu:
		print("  ✅ Found PlayerMenu in MapScene")
		# Pass reference to BottomUI
		if bottom_ui and bottom_ui.has_method("set_player_menu"):
			bottom_ui.set_player_menu(player_menu)
			print("  ✅ Connected PlayerMenu to BottomUI")
	else:
		print("  ⚠️ PlayerMenu not found in MapScene")

func _on_player_created(player: Resource):
	"""Called when GameManager creates the player"""
	print("🎮 GameRoot: Player created, initializing UI")
	print("  player: %s" % player)
	print("  player.dice_pool: %s" % player.get("dice_pool"))
	if player.dice_pool:
		print("  dice_pool.dice.size(): %d" % player.dice_pool.dice.size())
	print("  bottom_ui: %s" % bottom_ui)
	
	# Initialize BottomUI with player
	if bottom_ui:
		if bottom_ui.has_method("initialize"):
			bottom_ui.initialize(player)
			print("  ✅ BottomUI initialized with player")
		else:
			print("  ❌ BottomUI has no initialize method - is script attached?")
	else:
		print("  ❌ bottom_ui is null!")

# ============================================================================
# LAYER MANAGEMENT
# ============================================================================

func start_combat(encounter: Resource = null):
	"""Show combat layer on top of map, pause map"""
	if is_in_combat:
		push_warning("GameRoot: Already in combat!")
		return
	
	print("⚔️ GameRoot: Starting combat overlay")
	is_in_combat = true
	
	# Pause map (stays visible underneath but frozen)
	map_scene.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Show and enable combat layer
	combat_layer.visible = true
	combat_layer.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Notify UI
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
