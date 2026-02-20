# game_manager.gd - Main game orchestrator
extends Node

# ============================================================================
# PRELOADED SCENES
# ============================================================================
const COMBAT_SCENE = preload("res://scenes/game/combat_scene.tscn")
const MAP_SCENE = preload("res://scenes/game/map_scene.tscn")
const ELEMENT_VISUALS = preload("res://resources/element_visuals.tres")
const DIE_BASE_TEXTURES = preload("res://resources/die_base_textures.tres")




## Active region loot config. Set this when the player enters a new region.
## For Region 1, drag region_1_loot_config.tres here in Inspector.
var region_loot_config: RegionLootConfig = null

# ============================================================================
# STARTING ITEMS CONFIGURATION
# ============================================================================
@export_group("Starting Items")
@export var starting_items: Array[EquippableItem] = []

@export_group("Player Base Classes")
@export var warrior = load("res://resources/player_classes/warrior.tres") as PlayerClass
@export var mage = preload("res://resources/player_classes/mage.tres")

@export_group("Element Visuals")
## Central element visual configuration - fill/stroke shaders per element
@export var element_visuals: ElementVisualConfig


# ============================================================================
# GAME STATE
# ============================================================================
var player: Player = null
var current_scene: Node = null

# Scene instances for hide/show pattern (legacy mode)
var map_scene_instance: Node2D = null
var combat_scene_instance: Node2D = null

# GameRoot reference (new layer system)
var game_root: Node = null

# Combat results to pass to summary
var last_combat_results: Dictionary = {}





const REGION_LOOT_CONFIGS := {
	1: "res://resources/loot_tables/regions/region_1_loot_config.tres",
	# 2: "res://resources/loot_tables/regions/region_2_loot_config.tres",
}







# ============================================================================
# COMBAT ENCOUNTER SYSTEM
# ============================================================================
var pending_encounter: CombatEncounter = null
var completed_encounters: Array[String] = []

# ============================================================================
# SIGNALS
# ============================================================================
signal player_created(player: Player)
signal scene_changed(new_scene: Node)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	randomize()
	print("🎮 GameManager AutoLoad ready (waiting for scene)")
	
	var transparent = preload("res://assets/ui/1x1-00000000.png")
	Input.set_custom_mouse_cursor(transparent, Input.CURSOR_FORBIDDEN)
	
	# Wait for scene tree to be ready
	await get_tree().process_frame
	
	# Check if we have a current scene
	var root = get_tree().root
	var current = root.get_child(root.get_child_count() - 1)
	
	print("🎮 Current scene: %s" % current.name)
	
	# Check if running under GameRoot (new layer system)
	if DIE_BASE_TEXTURES:
		DIE_BASE_TEXTURES.register()
	
	if current.name == "GameRoot":
		print("🎮 Running under GameRoot - using layer system")
		# GameRoot will set game_root reference and handle scene management
		# Just initialize player - GameRoot will receive player_created signal
		initialize_player()
		return
	
	
	# Legacy: Direct MapScene as main scene
	if current.name == "MapScene":
		print("🎮 Legacy mode: Direct MapScene")
		map_scene_instance = current
		print("🎮 MapScene instance scene_file_path: %s" % map_scene_instance.scene_file_path)
		
		# Initialize player
		initialize_player()
		
		# Initialize the map
		if map_scene_instance.has_method("initialize_map"):
			map_scene_instance.initialize_map(player)
		
		# Connect signals
		if map_scene_instance.has_signal("start_combat"):
			map_scene_instance.start_combat.connect(_on_start_combat)
			print("🎮 Connected to map's start_combat signal")
		
		current_scene = map_scene_instance
	else:
		print("🎮 Starting fresh - loading map scene")
		initialize_player()
		load_map_scene()

func initialize_player():
	"""Create persistent player"""
	print("Creating player...")
	
	player = Player.new()
	add_child(player.dice_pool)
	add_child(player.status_tracker)
	print("  ✅ Dice pool added to scene tree")
	print("  ✅ Status tracker added to scene tree")
	
	# Load warrior class resource
	player.add_class("Warrior", warrior)
	player.add_class("Mage", mage)
	
	
	player.switch_class("Mage")
	
	
	
	if player.active_class:
		print("Player created: %s Level %d" % [player.active_class.player_class_name, player.active_class.level])
	else:
		print("Player created but no active class")
	
	# Emit signal so other systems can initialize with player
	player_created.emit(player)


# ============================================================================
# SCENE MANAGEMENT
# ============================================================================

func load_map_scene():
	"""Load the map exploration scene"""
	print("🗺️ Loading map scene...")
	
	if map_scene_instance:
		map_scene_instance.show()
		current_scene = map_scene_instance
	else:
		map_scene_instance = MAP_SCENE.instantiate()
		get_tree().root.add_child(map_scene_instance)
		current_scene = map_scene_instance
		
		# Initialize after adding to tree
		if map_scene_instance.has_method("initialize_map"):
			map_scene_instance.initialize_map(player)
		
		# Connect signals
		if map_scene_instance.has_signal("start_combat"):
			map_scene_instance.start_combat.connect(_on_start_combat)
	
	scene_changed.emit(map_scene_instance)


func load_combat_scene():
	"""Load the combat scene (legacy mode)"""
	print("⚔️ Loading combat scene...")
	
	if combat_scene_instance:
		combat_scene_instance.show()
		current_scene = combat_scene_instance
	else:
		combat_scene_instance = COMBAT_SCENE.instantiate()
		get_tree().root.add_child(combat_scene_instance)
		current_scene = combat_scene_instance
		
		# Initialize after adding to tree
		if combat_scene_instance.has_method("initialize_combat"):
			combat_scene_instance.initialize_combat(player)
	
	# Hide map
	if map_scene_instance:
		map_scene_instance.hide()
	
	scene_changed.emit(combat_scene_instance)


# ============================================================================
# COMBAT ENCOUNTER SYSTEM
# ============================================================================

func start_combat_encounter(encounter: CombatEncounter):
	"""Start a combat encounter - stores encounter and transitions to combat"""
	if not encounter:
		push_error("GameManager: Cannot start null encounter")
		return
	
	print("🎮 GameManager: Starting encounter '%s'" % encounter.encounter_name)
	
	# Validate encounter
	var warnings = encounter.validate()
	if warnings.size() > 0:
		print("  ⚠️ Encounter warnings:")
		for warning in warnings:
			print("    - %s" % warning)
	
	# Store encounter for combat scene to read
	pending_encounter = encounter
	
	# Use GameRoot layer system if available
	if game_root:
		game_root.start_combat(encounter)
	else:
		# Fallback to old scene switching
		load_combat_scene()

func start_random_encounter(encounter_pool: Array[CombatEncounter]):
	"""Start a random encounter from a pool"""
	if encounter_pool.size() == 0:
		push_error("GameManager: Empty encounter pool")
		return
	
	var random_index = randi() % encounter_pool.size()
	var encounter = encounter_pool[random_index]
	start_combat_encounter(encounter)

func get_pending_encounter() -> CombatEncounter:
	"""Get the pending encounter (called by combat scene)"""
	return pending_encounter

func clear_pending_encounter():
	"""Clear pending encounter after it's been loaded"""
	pending_encounter = null

func mark_encounter_completed(encounter: CombatEncounter):
	"""Mark an encounter as completed"""
	if encounter and encounter.encounter_id != "":
		if encounter.encounter_id not in completed_encounters:
			completed_encounters.append(encounter.encounter_id)
			print("🎮 Encounter completed: %s" % encounter.encounter_id)

func has_completed_encounter(encounter_id: String) -> bool:
	"""Check if an encounter has been completed"""
	return encounter_id in completed_encounters


func on_combat_ended(player_won: bool):
	"""Called when combat ends (from GameRoot.end_combat).
	Rolls loot per-enemy from the encounter using the tier loot system."""
	if player_won and pending_encounter:
		mark_encounter_completed(pending_encounter)

		# ── XP ──
		var exp: int = pending_encounter.get_total_experience()

		# Capture pre-combat XP state for animated bar
		var pre_level: int = 1
		var pre_xp: int = 0
		var pre_xp_needed: int = 100
		if player and player.active_class:
			pre_level = player.active_class.level
			pre_xp = player.active_class.experience
			pre_xp_needed = player.active_class.get_exp_for_next_level()

		# ── Loot: roll per-enemy ──
		var all_loot: Array[Dictionary] = []
		var total_gold: int = 0

		# Collect effective levels from spawned combatants if available
		var combatant_levels: Array[int] = []
		if game_root and game_root.combat_scene:
			var spawner: Node = game_root.combat_scene.find_child(
				"EncounterSpawner", true, false)
			if spawner and spawner.has_method("get_spawned_enemies"):
				for enemy: Combatant in spawner.get_spawned_enemies():
					combatant_levels.append(enemy.get_effective_level())

		for i: int in range(pending_encounter.enemies.size()):
			var enemy_data: EnemyData = pending_encounter.enemies[i]
			if not enemy_data:
				continue

			# Use effective level from spawned combatant, fall back to floor
			var eff_level: int = enemy_data.enemy_level_floor
			if i < combatant_levels.size():
				eff_level = combatant_levels[i]

			if region_loot_config:
				var luck: float = 0.0
				if player:
					luck = float(player.get_total_stat("luck"))

				var enemy_results: Array[Dictionary] = LootManager.roll_loot_from_combat(
					region_loot_config,
					enemy_data.enemy_tier,
					enemy_data.enemy_archetype,
					eff_level,
					luck,
				)

				for result: Dictionary in enemy_results:
					if result.get("type") == "currency":
						total_gold += result.get("amount", 0)
					else:
						all_loot.append(result)
			else:
				total_gold += enemy_data.get_gold_reward()

		# ── Apply rewards ──
		if player:
			player.add_experience(exp)
			if total_gold > 0:
				player.add_gold(total_gold)

			# Add equipment to inventory
			for loot_result: Dictionary in all_loot:
				var item: EquippableItem = loot_result.get("item")
				if item:
					player.add_to_inventory(item)

		print("🎮 Combat rewards: %d XP, %d gold, %d items" % [
			exp, total_gold, all_loot.size()])

		# ── Post-combat summary ──
		if game_root and game_root.has_method("show_post_combat_summary"):
			game_root.show_post_combat_summary({
				"victory": true,
				"xp_gained": exp,
				"gold_gained": total_gold,
				"loot": all_loot,
				"pre_level": pre_level,
				"pre_xp": pre_xp,
				"pre_xp_needed": pre_xp_needed,
			})

	clear_pending_encounter()

	if not game_root:
		load_map_scene()



# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func set_active_region(region_num: int):
	var path: String = REGION_LOOT_CONFIGS.get(region_num, "")
	if path != "" and ResourceLoader.exists(path):
		region_loot_config = load(path)
		print("🗺️ Active region loot: R%d" % region_num)
	else:
		region_loot_config = null
		push_warning("No loot config for region %d" % region_num)


func _on_start_combat():
	"""Handle start combat from map"""
	print("🎮 Starting combat...")
	load_combat_scene()
