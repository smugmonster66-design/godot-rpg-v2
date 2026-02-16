# res://scripts/game/game_root.gd
# Main game controller - manages map, combat, and persistent UI layers
# PlayerMenu and PostCombatSummary live directly in PersistentUILayer (no reparenting)
extends Node



# ============================================================================
# DEV MODE
# ============================================================================
@export_group("Dev Mode")
@export var dev_mode: bool = false
@export var dev_level: int = 10
@export var dev_skill_points: int = 30
@export var dev_dice: Array[DieResource] = []
@export var dev_items: Array[EquippableItem] = []
@export_range(1, 100) var dev_item_level: int = 15
@export_range(1, 6) var dev_item_region: int = 1
@export_range(1, 6) var debug_region: int = 1

signal combat_intro_ready
var _combat_intro_done: bool = false

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
@onready var dungeon_layer: Node2D = $DungeonLayer
@onready var dungeon_scene: DungeonScene = $DungeonLayer/DungeonScene
@onready var camera: GameCamera = $GameCamera
@onready var combat_ui_layer: CanvasLayer = null

var is_in_dungeon: bool = false



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
	
	GameManager.set_active_region(debug_region)
	
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

	
	
	
	
	
	
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			print("🔍 CanvasLayer: %s, layer=%d" % [child.name, child.layer])
	
	
	
	# Dungeon layer — start hidden and disabled
	dungeon_layer.visible = false
	dungeon_layer.process_mode = Node.PROCESS_MODE_DISABLED

	# Connect dungeon signals
	if dungeon_scene:
		if not dungeon_scene.combat_requested.is_connected(_on_dungeon_combat_requested):
			dungeon_scene.combat_requested.connect(_on_dungeon_combat_requested)
		if not dungeon_scene.dungeon_completed.is_connected(_on_dungeon_completed):
			dungeon_scene.dungeon_completed.connect(_on_dungeon_completed)
		if not dungeon_scene.dungeon_failed.is_connected(_on_dungeon_failed):
			dungeon_scene.dungeon_failed.connect(_on_dungeon_failed)
		print("  ✅ DungeonScene signals connected")
	
	
	
	combat_ui_layer = combat_scene.find_child("CombatUILayer", true, false)



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
		
		
		
	
	
	# Apply dev mode overrides
	if dev_mode and player:
		var pc = player.active_class
		if pc:
			pc.level = dev_level
			pc.skill_points = dev_skill_points
			pc.total_skill_points = dev_skill_points
		
		for die in dev_dice:
			if die:
				var copy = die.duplicate_die()
				copy.source = "dev"
				player.dice_pool.add_die(copy)
		
		for item_template in dev_items:
			if item_template:
				var result = LootManager.generate_drop(item_template, dev_item_level, dev_item_region)
				var item: EquippableItem = result.get("item")
				if item:
					player.add_to_inventory(item)
					print("  🧪 Dev item: %s (Lv.%d)" % [item.item_name, item.item_level])
		
		print("🧪 Dev mode — Lv.%d, %d SP, +%d dice, +%d items" % [
			dev_level, dev_skill_points, dev_dice.size(), dev_items.size()])
	
	


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
		
	
	_combat_intro_done = true
	combat_intro_ready.emit()
	

func end_combat(player_won: bool = true):
	_combat_intro_done = false
	if not is_in_combat:
		push_warning("GameRoot: Not in combat!")
		return
	print("⚔️ GameRoot: Ending combat (won=%s, dungeon=%s)" % [player_won, is_in_dungeon])
	is_in_combat = false

	combat_layer.visible = false
	combat_layer.process_mode = Node.PROCESS_MODE_DISABLED
	if combat_scene and combat_scene.has_method("reset_combat"):
		combat_scene.reset_combat()
	
	ui_layer.layer = 100

	if is_in_dungeon:
		# Return to dungeon — SKIP GameManager.on_combat_ended (dungeon owns rewards)
		dungeon_scene.process_mode = Node.PROCESS_MODE_INHERIT
		dungeon_scene.on_combat_ended(player_won)
		if bottom_ui and bottom_ui.has_method("on_combat_ended"):
			bottom_ui.on_combat_ended(player_won)
	else:
		# Return to map — normal flow
		map_scene.process_mode = Node.PROCESS_MODE_INHERIT
		if bottom_ui and bottom_ui.has_method("on_combat_ended"):
			bottom_ui.on_combat_ended(player_won)
		if GameManager:
			GameManager.on_combat_ended(player_won)

func _show_map():
	"""Ensure map is visible and running"""
	map_layer.visible = true
	map_scene.process_mode = Node.PROCESS_MODE_INHERIT






# ============================================================================
# DUNGEON LAYER MANAGEMENT
# ============================================================================

func enter_dungeon(definition: DungeonDefinition):
	if is_in_dungeon or is_in_combat:
		push_warning("GameRoot: Can't enter dungeon now")
		return
	print("🏰 GameRoot: Entering dungeon '%s'" % definition.dungeon_name)
	is_in_dungeon = true
	map_scene.process_mode = Node.PROCESS_MODE_DISABLED
	dungeon_layer.visible = true
	dungeon_layer.process_mode = Node.PROCESS_MODE_INHERIT
	camera.set_mode(GameCamera.Mode.DUNGEON)
	# Pass camera BEFORE enter so build_corridor has it for the intro sweep
	var dmap = dungeon_scene.find_child("DungeonMap", true, false)
	if dmap:
		dmap.camera = camera
	dungeon_scene.enter_dungeon(definition, GameManager.player)

func exit_dungeon():
	camera.set_mode(GameCamera.Mode.MAP)
	print("🏰 GameRoot: Exiting dungeon")
	is_in_dungeon = false
	dungeon_scene.exit_dungeon()
	dungeon_layer.visible = false
	dungeon_layer.process_mode = Node.PROCESS_MODE_DISABLED
	map_scene.process_mode = Node.PROCESS_MODE_INHERIT

func _on_dungeon_combat_requested(encounter: CombatEncounter):
	print("⚔️ GameRoot: Dungeon combat starting")
	is_in_combat = true
	if player_menu and player_menu.visible and player_menu.has_method("close_menu"):
		player_menu.close_menu()
	dungeon_scene.process_mode = Node.PROCESS_MODE_DISABLED
	combat_layer.visible = true
	combat_layer.process_mode = Node.PROCESS_MODE_INHERIT
	ui_layer.layer = 5
	GameManager.pending_encounter = encounter
	var cm = combat_scene.find_child("CombatManager", true, false)
	if not cm: cm = combat_scene
	if cm and cm.has_method("check_pending_encounter"):
		cm.check_pending_encounter()
	if bottom_ui and bottom_ui.has_method("on_combat_started"):
		bottom_ui.on_combat_started()
	# Fade in from black
	_fade_from_black()

func _fade_from_black():
	var overlay = dungeon_scene.find_child("TransitionOverlay", true, false)
	if not overlay or not overlay.visible:
		_combat_intro_done = true
		combat_intro_ready.emit()
		return
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var tw = create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		overlay.visible = false
		overlay.process_mode = Node.PROCESS_MODE_INHERIT
		_combat_intro_done = true
		combat_intro_ready.emit()
	)




func _on_dungeon_completed(run: DungeonRun):
	print("🏰 Complete! Gold: %d, Exp: %d, Items: %d" % [
		run.gold_earned, run.exp_earned, run.items_earned.size()])
	exit_dungeon()

func _on_dungeon_failed(run: DungeonRun):
	print("💀 Failed. Gold rolled back to %d" % run.gold_snapshot_on_entry)
	exit_dungeon()






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
