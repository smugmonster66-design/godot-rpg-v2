# res://scripts/game/game_root.gd
# Main game controller - manages map, combat, and persistent UI layers
# PlayerMenu and PostCombatSummary live directly in PersistentUILayer (no reparenting)
extends Node



# ============================================================================
# DEV MODE
# ============================================================================
@export_group("Map")
## Drag a MapDefinition .tres here to load a specific map on startup.
## Leave empty to use legacy fallback (displays all registered locations).
@export var starting_map: MapDefinition = null
## Zone pushed on top of starting_map when a NEW game begins, so the player
## starts inside it (e.g. the Veritas Port docks). Leave empty to start on the
## root map's starting location. Continue restores wherever the save was.
@export var new_game_zone: MapDefinition = null

@export_group("Boot")
## Show the splash / main menu at startup. Off = skip straight in (continues
## the save if one exists, otherwise starts a new game).
@export var show_title_screen: bool = true

@export_group("Dev Mode")
@export var dev_mode: bool = false
@export var dev_level: int = 10
@export var dev_skill_points: int = 30
@export var dev_dice: Array[DieResource] = []
@export var dev_items: Array[EquippableItem] = []
@export_range(1, 100) var dev_item_level: int = 15
@export_range(1, 6) var dev_item_region: int = 1
@export_range(1, 6) var debug_region: int = 1
@export var dev_companions: Array[CompanionData] = []
@export var dev_camp_companions: Array[CompanionData] = []


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
@onready var dialogue_layer: CanvasLayer = $DialogueLayer
@onready var dialogue_ui: Control = $DialogueLayer/DialogueUI


var is_in_dungeon: bool = false

const TITLE_SCREEN_SCENE := preload("res://scenes/ui/menus/title_screen.tscn")
var _title_layer: CanvasLayer = null
var _title_screen: Control = null
## True once a game has started (new or continued) and the map is live.
var _session_started: bool = false

var _pending_post_combat: Dictionary = {}

# Persistent UI elements (direct children of PersistentUILayer)
var player_menu: Control = null
var post_combat_summary: Control = null
var dungeon_selection: Control = null

# Add to node references section
var portrait_controller: Control = null
var companion_panel: CompanionPanel = null
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

	# Find persistent UI elements
	_setup_persistent_ui()

	if show_title_screen:
		_show_title_screen()
	else:
		_show_map()

	_connect_autosave_triggers()

	# TIMING FIX: Check if player already exists (GameManager autoload ran first)
	call_deferred("_check_existing_player")

	
	
	
	
	
	
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			print("🔍 CanvasLayer: %s, layer=%d" % [child.name, child.layer])
	
	
	
	# Listen for dialogue events (smithing, etc.)
	if not DialogueManager.event_triggered.is_connected(_on_dialogue_event):
		DialogueManager.event_triggered.connect(_on_dialogue_event)

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
		if not dungeon_scene.chain_completed.is_connected(_on_chain_completed):
			dungeon_scene.chain_completed.connect(_on_chain_completed)
		if not dungeon_scene.chain_failed.is_connected(_on_chain_failed):
			dungeon_scene.chain_failed.connect(_on_chain_failed)
		if not dungeon_scene.chain_dungeon_cemented.is_connected(_on_chain_dungeon_cemented):
			dungeon_scene.chain_dungeon_cemented.connect(_on_chain_dungeon_cemented)
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
		#player_menu.z_index = -1
		
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
	# DungeonSelectionScreen
	dungeon_selection = ui_layer.find_child("DungeonSelectionScreen", true, false)
	if dungeon_selection:
		dungeon_selection.hide()
		if dungeon_selection.has_signal("dungeon_selected"):
			if not dungeon_selection.dungeon_selected.is_connected(_on_dungeon_selection_made):
				dungeon_selection.dungeon_selected.connect(_on_dungeon_selection_made)
		if dungeon_selection.has_signal("selection_closed"):
			if not dungeon_selection.selection_closed.is_connected(_on_dungeon_selection_closed):
				dungeon_selection.selection_closed.connect(_on_dungeon_selection_closed)
		print("  ✅ DungeonSelectionScreen found")
	else:
		print("  ⚠️ DungeonSelectionScreen not found in PersistentUILayer")

	# Companion panel — persistent display above portrait
	companion_panel = ui_layer.find_child("CombatCompanionPanelVBox", true, false) as CompanionPanel
	if companion_panel:
		print("  ✅ CompanionPanel found (%d slots)" % companion_panel.companion_slots.size())
	else:
		print("  ⚠️ CompanionPanel not found in PersistentUILayer")

	# PortraitController — click-to-open menu
	portrait_controller = ui_layer.find_child("PortraitContainer", true, false)
	if portrait_controller and portrait_controller.has_signal("portrait_clicked"):
		if not portrait_controller.portrait_clicked.is_connected(_on_portrait_clicked):
			portrait_controller.portrait_clicked.connect(_on_portrait_clicked)
		print("  ✅ PortraitController connected")
	else:
		print("  ⚠️ PortraitController not found or missing portrait_clicked signal")
	

# ============================================================================
# TITLE SCREEN / BOOT
# ============================================================================

func _show_title_screen() -> void:
	map_layer.visible = false
	map_scene.process_mode = Node.PROCESS_MODE_DISABLED
	ui_layer.visible = false
	_title_layer = CanvasLayer.new()
	_title_layer.name = "TitleLayer"
	_title_layer.layer = 200
	add_child(_title_layer)
	_title_screen = TITLE_SCREEN_SCENE.instantiate()
	_title_layer.add_child(_title_screen)
	_title_screen.new_game_confirmed.connect(_on_title_new_game)
	_title_screen.continue_requested.connect(_on_title_continue)

func _close_title_screen() -> void:
	if _title_layer:
		_title_layer.queue_free()
		_title_layer = null
		_title_screen = null
	ui_layer.visible = true
	_show_map()

func _on_title_new_game() -> void:
	print("🎮 GameRoot: New Game")
	_close_title_screen()
	GameManager.start_new_game()

func _on_title_continue() -> void:
	print("🎮 GameRoot: Continue")
	_close_title_screen()
	GameManager.continue_game()

# ============================================================================
# AUTOSAVE
# ============================================================================

func can_autosave() -> bool:
	"""Safe moments only: never mid-combat, mid-dungeon-run or mid-dialogue."""
	if not _session_started:
		return false
	if is_in_combat or is_in_dungeon:
		return false
	if DialogueManager.is_active:
		return false
	return true

func _connect_autosave_triggers() -> void:
	MapManager.location_entered.connect(func(_id, _loc, _first): GameState.request_autosave())
	MapManager.map_changed.connect(func(_m): GameState.request_autosave())
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended_autosave)
	QuestManager.quest_objectives_updated.connect(func(_q, _d): GameState.request_autosave())
	QuestManager.quest_ready_for_turn_in.connect(func(_q, _d): GameState.request_autosave())
	QuestManager.quest_auto_completed.connect(func(_q, _d): GameState.request_autosave())

func _on_dialogue_ended_autosave() -> void:
	# dialogue_ended fires before is_active is cleared in some paths; defer.
	GameState.flush_pending_autosave()
	GameState.request_autosave()

func _on_player_created(player: Resource):
	"""Called when GameManager creates the player"""
	print("🎮 GameRoot: Player created, initializing UI")
	var is_continue: bool = GameManager.boot_mode == "continue"

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

	# Initialize map scene with player. Continue restores the saved zones;
	# a new game enters new_game_zone (the docks) if one is set.
	if map_scene and map_scene.has_method("initialize_map"):
		var stack: Array = GameState.get_saved_map_stack() if is_continue else []
		map_scene.initialize_map(player, starting_map, stack)
		if not is_continue and new_game_zone != null:
			MapManager.push_map(new_game_zone)
		print("  ✅ MapScene initialized with player (%s)" % ("continue" if is_continue else "new game"))
		
		
		
	
	
	# Apply dev mode overrides (new games only: a continued save already has them)
	if dev_mode and player and not is_continue:
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
		
		for comp_data in dev_companions:
			if comp_data:
				var instance = CompanionInstance.new()
				instance.companion_data = comp_data
				player.active_companions.append(instance)
				player.companion_roster.append(instance)
				print("  [Dev] Companion: %s" % comp_data.companion_name)

		for comp_data in dev_camp_companions:
			if comp_data:
				var instance = CompanionInstance.new()
				instance.companion_data = comp_data
				player.companion_roster.append(instance)
				print("  [Dev] Camp companion: %s" % comp_data.companion_name)

		# Sync player.level and recalculate stats so HP/mana/affixes reflect dev_level
		player.level = pc.level
		player.recalculate_stats()

		# Refresh bottom UI so it reads the patched level/stats
		if bottom_ui and bottom_ui.has_method("refresh_stats"):
			bottom_ui.refresh_stats()

		print("[Dev] Dev mode — Lv.%d, %d SP, +%d dice, +%d items, +%d companions, +%d camp" % [
			dev_level, dev_skill_points, dev_dice.size(), dev_items.size(),
			dev_companions.size(), dev_camp_companions.size()])
	
	# Populate companion panel (after dev companions are added)
	if companion_panel and player:
		companion_panel.refresh_from_player(player)

	# The game is live: allow autosaves, and write the first one now so a new
	# game can be continued straight away.
	_session_started = true
	GameState.session_active = true
	GameState.request_autosave()
	
	


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

	map_layer.visible = false
	if map_scene.has_method("set_ui_layer_visible"):
		map_scene.set_ui_layer_visible(false)
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

	# Hide combat layer
	combat_layer.visible = false
	combat_layer.process_mode = Node.PROCESS_MODE_DISABLED
	if combat_scene and combat_scene.has_method("reset_combat"):
		combat_scene.reset_combat()

	ui_layer.layer = 100

	# Store context for post-summary transition
	_pending_post_combat = {
		"player_won": player_won,
		"was_dungeon": is_in_dungeon,
	}

	# Bottom UI updates immediately (underneath the summary overlay)
	if bottom_ui and bottom_ui.has_method("on_combat_ended"):
		bottom_ui.on_combat_ended(player_won)

	# Report kills to QuestManager for objective tracking
	if player_won and GameManager and GameManager.pending_encounter:
		QuestManager.report_combat_kills(GameManager.pending_encounter.enemies)

	if not is_in_dungeon:
		GameState.flush_pending_autosave()
		GameState.request_autosave()

	if is_in_dungeon:
		# Dungeon owns rewards — let it apply them, then show summary
		_handle_dungeon_post_combat(player_won)
	else:
		# Map path — GameManager handles rewards + shows summary
		map_layer.visible = true
		if map_scene.has_method("set_ui_layer_visible"):
			map_scene.set_ui_layer_visible(true)
		map_scene.process_mode = Node.PROCESS_MODE_INHERIT
		if GameManager:
			GameManager.on_combat_ended(player_won)

	# If dialogue was suspended for this combat and no summary is shown,
	# resume dialogue immediately (otherwise _on_summary_closed handles it)
	var summary_visible = post_combat_summary and post_combat_summary.visible
	if not summary_visible and DialogueManager.has_pending_resume():
		print("📊 No summary shown — resuming dialogue directly")
		DialogueManager.resume_dialogue()



func _handle_dungeon_post_combat(player_won: bool) -> void:
	"""Let dungeon apply its run-tracked rewards, then show a summary."""
	# Snapshot pre-combat XP for animated bar
	var pre_level: int = 1
	var pre_xp: int = 0
	var pre_xp_needed: int = 100
	if GameManager and GameManager.player and GameManager.player.active_class:
		var pc = GameManager.player.active_class
		pre_level = pc.level
		pre_xp = pc.experience
		pre_xp_needed = pc.get_exp_for_next_level()

	# Snapshot gold/items before dungeon applies rewards
	var gold_before: int = GameManager.player.gold if GameManager and GameManager.player else 0
	var inv_before: int = GameManager.player.inventory.size() if GameManager and GameManager.player else 0

	# Dungeon applies its own run-tracked rewards
	dungeon_scene.process_mode = Node.PROCESS_MODE_INHERIT
	dungeon_scene.on_combat_ended(player_won)
	# Pause dungeon again — resume after summary closes
	dungeon_scene.process_mode = Node.PROCESS_MODE_DISABLED

	# Build summary from what changed
	var gold_earned: int = 0
	var new_items: Array[Dictionary] = []
	if GameManager and GameManager.player:
		gold_earned = GameManager.player.gold - gold_before
		# Items added since snapshot
		if GameManager.player.inventory.size() > inv_before:
			for i in range(inv_before, GameManager.player.inventory.size()):
				new_items.append({"item": GameManager.player.inventory[i]})

	var xp_earned: int = 0
	if GameManager and GameManager.player and GameManager.player.active_class:
		# Calculate XP earned by comparing states
		var pc = GameManager.player.active_class
		if pc.level == pre_level:
			xp_earned = pc.experience - pre_xp
		else:
			# Crossed level boundary — reconstruct
			xp_earned = (pre_xp_needed - pre_xp)  # remainder of old level
			for lv in range(pre_level + 1, pc.level):
				xp_earned += lv * 100  # intermediate levels
			xp_earned += pc.experience  # current partial

	show_post_combat_summary({
		"victory": player_won,
		"xp_gained": xp_earned,
		"gold_gained": gold_earned,
		"loot": new_items,
		"pre_level": pre_level,
		"pre_xp": pre_xp,
		"pre_xp_needed": pre_xp_needed,
	})

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
	map_layer.visible = false
	if map_scene.has_method("set_ui_layer_visible"):
		map_scene.set_ui_layer_visible(false)
	map_scene.process_mode = Node.PROCESS_MODE_DISABLED
	dungeon_layer.visible = true
	dungeon_layer.process_mode = Node.PROCESS_MODE_INHERIT
	camera.set_mode(GameCamera.Mode.DUNGEON)
	# Pass camera BEFORE enter so build_corridor has it for the intro sweep
	var dmap = dungeon_scene.find_child("DungeonMap", true, false)
	if dmap:
		dmap.camera = camera
	dungeon_scene.enter_dungeon(definition, GameManager.player)

func enter_dungeon_chain(chain: DungeonChain):
	if is_in_dungeon or is_in_combat:
		push_warning("GameRoot: Can't enter dungeon chain now")
		return
	print("[Chain] Entering chain '%s' (%d dungeons)" % [
		chain.get_display_name(), chain.get_dungeon_count()])
	is_in_dungeon = true
	map_layer.visible = false
	if map_scene.has_method("set_ui_layer_visible"):
		map_scene.set_ui_layer_visible(false)
	map_scene.process_mode = Node.PROCESS_MODE_DISABLED
	dungeon_layer.visible = true
	dungeon_layer.process_mode = Node.PROCESS_MODE_INHERIT
	camera.set_mode(GameCamera.Mode.DUNGEON)
	var dmap = dungeon_scene.find_child("DungeonMap", true, false)
	if dmap:
		dmap.camera = camera
	dungeon_scene.enter_chain(chain, GameManager.player)

func exit_dungeon():
	camera.set_mode(GameCamera.Mode.MAP)
	print("🏰 GameRoot: Exiting dungeon")
	is_in_dungeon = false
	dungeon_scene.exit_dungeon()
	dungeon_layer.visible = false
	dungeon_layer.process_mode = Node.PROCESS_MODE_DISABLED
	map_layer.visible = true
	if map_scene.has_method("set_ui_layer_visible"):
		map_scene.set_ui_layer_visible(true)
	map_scene.process_mode = Node.PROCESS_MODE_INHERIT
	GameState.flush_pending_autosave()
	GameState.request_autosave()

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
	# Report dungeon completion to QuestManager for CUSTOM objectives
	if run.definition and run.definition.dungeon_id != "":
		QuestManager.report_custom(StringName(run.definition.dungeon_id))
	exit_dungeon()
	# Resume dialogue if it was suspended for this dungeon entry
	if DialogueManager.has_pending_resume():
		DialogueManager.resume_dialogue()

func _on_dungeon_failed(run: DungeonRun):
	print("💀 Failed. Gold rolled back to %d" % run.gold_snapshot_on_entry)
	exit_dungeon()
	# Resume dialogue if it was suspended for this dungeon entry
	if DialogueManager.has_pending_resume():
		DialogueManager.resume_dialogue()

func _on_chain_completed(chain_runner: DungeonChainRunner):
	print("[Chain] Complete! %d dungeons cleared" % chain_runner.completed_runs.size())
	if chain_runner.chain and chain_runner.chain.chain_id != &"":
		QuestManager.report_custom(chain_runner.chain.chain_id)

func _on_chain_failed(run: DungeonRun, chain_runner: DungeonChainRunner):
	print("[Chain] Failed at dungeon %d/%d" % [
		chain_runner.current_index + 1, chain_runner.chain.get_dungeon_count()])

func _on_chain_dungeon_cemented(run: DungeonRun, chain_runner: DungeonChainRunner):
	print("[Chain] Cemented dungeon %d: %s (progress: %s)" % [
		chain_runner.current_index, run.definition.dungeon_name,
		chain_runner.get_progress_text()])

func show_dungeon_selection():
	"""Open the dungeon selection screen. Called from map UI."""
	if is_in_dungeon or is_in_combat:
		push_warning("GameRoot: Can't open dungeon selection now")
		return
	if dungeon_selection and dungeon_selection.has_method("open"):
		dungeon_selection.open(GameManager.player)

func _on_dungeon_selection_made(definition: DungeonDefinition):
	"""Player picked a dungeon from the selection screen."""
	print("🏰 GameRoot: Dungeon selected from list — '%s'" % definition.dungeon_name)
	enter_dungeon(definition)

func _on_dungeon_selection_closed():
	"""Player backed out of the selection screen."""
	print("🏰 GameRoot: Dungeon selection closed")






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
	"""Post-combat summary closed — resume the correct scene."""
	print("📊 Summary closed — transitioning back")
	print("📊 DialogueManager.has_pending_resume() = %s" % DialogueManager.has_pending_resume())
	print("📊 _pending_resume_line = %s, _suspended_encounter = %s" % [DialogueManager._pending_resume_line, DialogueManager._suspended_encounter])
	var info = _pending_post_combat
	_pending_post_combat = {}

	if info.get("was_dungeon", false):
		# Re-enable dungeon — floor advancement already happened
		dungeon_scene.process_mode = Node.PROCESS_MODE_INHERIT

	# Resume dialogue if it was suspended for this combat/dungeon
	if DialogueManager.has_pending_resume():
		DialogueManager.resume_dialogue()
	# Map path already re-enabled in end_combat()

# ============================================================================
# MAP POPUPS (stubs — implemented as systems are built)
# ============================================================================

func show_quest_popup(location = null) -> void:
	"""Stub: opens quest grid for the given location. Implement when quest UI is ready."""
	push_warning("GameRoot.show_quest_popup: Quest UI not yet implemented (location: %s)" % str(location))

func show_stash_popup() -> void:
	var popup = preload("res://scenes/ui/stash/stash_popup.tscn").instantiate()
	dialogue_layer.add_child(popup)
	popup.stash_closed.connect(func(): popup.queue_free())
	popup.setup(GameManager.player, GameState.stash)

func show_party_popup() -> void:
	var popup = preload("res://scenes/ui/popups/party_management_popup.tscn").instantiate()
	dialogue_layer.add_child(popup)
	popup.show_party(GameManager.player)
	popup.party_closed.connect(func(): popup.queue_free())

# ============================================================================
# DIALOGUE EVENT HANDLER
# ============================================================================

func _on_dialogue_event(tag: StringName) -> void:
	var tag_str = str(tag)
	print("[GameRoot] _on_dialogue_event: '%s'" % tag_str)
	if tag_str.begins_with("open_smithing:"):
		var config_path = tag_str.substr("open_smithing:".length())
		print("[GameRoot] Opening smithing with config: '%s'" % config_path)
		_show_smithing_popup(config_path)

func _show_smithing_popup(config_path: String) -> void:
	print("[GameRoot] _show_smithing_popup: config_path='%s'" % config_path)
	var config = load(config_path) if config_path != "" else null
	print("[GameRoot] config loaded: %s" % config)
	if not config:
		config = load("res://resources/crafting/smithing_config.tres")
		print("[GameRoot] fallback config: %s" % config)
	if not config:
		push_warning("GameRoot: No SmithingConfig found at '%s'" % config_path)
		return
	print("[GameRoot] instantiating smithing popup...")
	var popup = preload("res://scenes/ui/smithing/smithing_popup.tscn").instantiate()
	print("[GameRoot] popup instantiated: %s" % popup)
	dialogue_layer.add_child(popup)
	print("[GameRoot] popup added to DialogueLayer, calling show_smithing")
	popup.smithing_closed.connect(func(): popup.queue_free())
	popup.show_smithing(GameManager.player, config)
	print("[GameRoot] show_smithing completed")

func _unhandled_input(event: InputEvent) -> void:
	# Ctrl+Shift+= to test dialogue
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACKSPACE and event.ctrl_pressed and event.shift_pressed:
			TestDialogue.launch_test()
			get_viewport().set_input_as_handled()
