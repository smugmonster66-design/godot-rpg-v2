# res://resources/data/save_data.gd
# The ONE save file resource. Contains all progression state.
# All sub-resources are typed classes for autocomplete and type safety.
#
# Usage:
#   var save = SaveData.new()
#   save.flags.met_king = true
#   save.counters.increment(&"enemies_killed")
#   save.quests.get_progress(&"main_quest_1").state = QuestProgress.QuestState.ACTIVE
#   save.map.set_current_location(&"starting_village")
#   ResourceSaver.save(save, "user://save.tres")
extends Resource
class_name SaveData

# ============================================================================
# META
# ============================================================================
@export_group("Meta")
## Save file version for migration support
@export var version: int = 2  # 2: adds map_stack
## When save was created
@export var created_at: float = 0.0
## When save was last modified
@export var modified_at: float = 0.0
## Total play time in seconds
@export var play_time: float = 0.0
## Player-chosen save name (if you allow naming saves)
@export var save_name: String = ""

# ============================================================================
# PROGRESSION STATE
# ============================================================================
@export_group("Progression")
## Story flags - explicitly typed booleans
@export var flags: StoryFlags = null
## Counters - named integers
@export var counters: Counters = null
## NPC relationships
@export var relationships: Relationships = null
## Hidden NPC approval (internal, not shown to player)
@export var approvals: Approvals = null

# ============================================================================
# QUEST STATE
# ============================================================================
@export_group("Quests")
## Quest progress tracking
@export var quests: QuestJournal = null

# ============================================================================
# MAP STATE
# ============================================================================
@export_group("Map")
## Map exploration progress
@export var map: MapProgress = null
## The map stack at save time: which zones the player is inside, root first.
## Each entry is {"path": String (MapDefinition resource path), "return": StringName}.
## Written by GameState.save() from MapManager.get_stack_snapshot().
@export var map_stack: Array = []
## Where the player last rested on the map (the shellkeepers carry you back
## here after a loss). {"stack": map stack snapshot, "location": StringName}.
@export var last_rest: Dictionary = {}
## A dungeon run in progress (DungeonScene.serialize_run), or {} if none.
@export var dungeon_run_state: Dictionary = {}
## Stat affixes from the run's shrines / run affixes, re-applied on resume.
@export var dungeon_run_affixes: Array[Resource] = []

# ============================================================================
# PLAYER STATE
# ============================================================================
@export_group("Player")

## Whether player state has been saved at least once. When false,
## GameManager uses its default initialization instead of restoring.
@export var has_player_state: bool = false

## Core stats snapshot
@export var player_stats: Dictionary = {}
# Keys: max_hp, current_hp, base_armor, base_barrier, max_mana, current_mana,
#        strength, agility, intellect, luck, gold, level

## Active class name (e.g., "Mage", "Warrior")
@export var active_class_name: String = ""

## Per-class saved state: { class_name: { "level": int, "experience": int,
##   "skill_ranks": { skill_id: int }, "allocated_points": { tree_id: int } } }
@export var class_data: Dictionary = {}

## Equipment: slot name -> EquippableItem sub-resource. Godot serializes
## @export properties as inline sub-resources in save.tres.
@export var player_equipment: Dictionary = {}  # String -> EquippableItem

## Inventory: unique EquippableItem instances with rolled affixes.
## Stored as sub-resources — ResourceSaver embeds them in save.tres.
@export var player_inventory: Array[EquippableItem] = []

## Consumable inventory: [{path: String, stack: int}]
## ConsumableItems are loaded from .tres paths; only stack count varies.
@export var player_consumables: Array[Dictionary] = []

## Pending consumable buffs queued for next combat (T2/T3 survive save/load).
## Each entry: {"consumable_path": String, "remaining_combats": int, "type": String}
@export var pending_consumable_buffs: Array[Dictionary] = []

## Dice pool serialized via PlayerDiceCollection.to_dict()
@export var dice_pool_data: Dictionary = {}

## Completed encounter IDs (from GameManager)
@export var completed_encounters: Array[String] = []

## Active region number
@export var active_region: int = 1

## NPC encounter tracking: { npc_id: StringName → Array[StringName] of seen encounter_ids }
@export var seen_npc_encounters: Dictionary = {}

# ============================================================================
# STASH
# ============================================================================
@export_group("Stash")
## Persistent stash/bank storage (equipment + consumables)
@export var stash: StashData = null

# ============================================================================
# TIMESTAMPS
# ============================================================================
@export_group("Timestamps")
## Named timestamps for time-gated content
@export var timestamps: Dictionary = {}  # StringName -> float (unix time)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	# Create sub-resources if not loaded from file
	if flags == null:
		flags = StoryFlags.new()
	if counters == null:
		counters = Counters.new()
	if relationships == null:
		relationships = Relationships.new()
	if approvals == null:
		approvals = Approvals.new()
	if quests == null:
		quests = QuestJournal.new()
	if map == null:
		map = MapProgress.new()
	if stash == null:
		stash = StashData.new()

	if created_at == 0.0:
		created_at = Time.get_unix_time_from_system()

# ============================================================================
# SAVE/LOAD
# ============================================================================

const SAVE_PATH := "user://save.tres"

func save_to_disk() -> Error:
	"""Save to disk. Returns OK on success."""
	modified_at = Time.get_unix_time_from_system()
	var error = ResourceSaver.save(self, SAVE_PATH)
	if error != OK:
		push_error("SaveData: Failed to save: %s" % error_string(error))
	return error

static func load_from_disk() -> SaveData:
	"""Load from disk. Returns new SaveData if file doesn't exist."""
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveData: No save file found, creating new")
		return SaveData.new()
	
	var loaded = ResourceLoader.load(SAVE_PATH) as SaveData
	if loaded == null:
		push_error("SaveData: Failed to load save file")
		return SaveData.new()
	
	# Ensure sub-resources exist (in case of version mismatch)
	if loaded.flags == null:
		loaded.flags = StoryFlags.new()
	if loaded.counters == null:
		loaded.counters = Counters.new()
	if loaded.relationships == null:
		loaded.relationships = Relationships.new()
	if loaded.approvals == null:
		loaded.approvals = Approvals.new()
	if loaded.quests == null:
		loaded.quests = QuestJournal.new()
	if loaded.map == null:
		loaded.map = MapProgress.new()
	
	return loaded

static func delete_save() -> Error:
	"""Delete the save file."""
	if FileAccess.file_exists(SAVE_PATH):
		return DirAccess.remove_absolute(SAVE_PATH)
	return OK

static func save_exists() -> bool:
	"""Check if a save file exists."""
	return FileAccess.file_exists(SAVE_PATH)

# ============================================================================
# TIMESTAMP API
# ============================================================================

func set_timestamp(key: StringName) -> void:
	"""Record current time for a named event."""
	timestamps[key] = Time.get_unix_time_from_system()

func get_timestamp(key: StringName) -> float:
	"""Get timestamp for a named event (0 if not set)."""
	return timestamps.get(key, 0.0)

func get_time_since(key: StringName) -> float:
	"""Get seconds since a timestamp was set (INF if not set)."""
	var ts = get_timestamp(key)
	if ts <= 0:
		return INF
	return Time.get_unix_time_from_system() - ts

func has_timestamp(key: StringName) -> bool:
	"""Check if a timestamp exists."""
	return key in timestamps

# ============================================================================
# CLASS LEVEL API
# ============================================================================

func get_class_level(class_id: StringName) -> int:
	"""Get level for a specific class."""
	var cdata: Dictionary = class_data.get(String(class_id), {})
	return cdata.get("level", 0)

func set_class_level(class_id: StringName, level: int) -> void:
	"""Set level for a specific class."""
	if not class_data.has(String(class_id)):
		class_data[String(class_id)] = {}
	class_data[String(class_id)]["level"] = level

# ============================================================================
# PLAYER SNAPSHOT / RESTORE
# ============================================================================

func snapshot_player(player: Player, game_manager = null) -> void:
	"""Capture full player state into this SaveData. Call before save_to_disk().
	Pass game_manager to also snapshot completed_encounters and active_region."""
	if not player:
		return

	has_player_state = true

	# ── Core stats ──
	player_stats = {
		"max_hp": player.max_hp,
		"current_hp": player.current_hp,
		"base_armor": player.base_armor,
		"base_barrier": player.base_barrier,
		"max_mana": player.max_mana,
		"current_mana": player.current_mana,
		"strength": player.strength,
		"agility": player.agility,
		"intellect": player.intellect,
		"luck": player.luck,
		"gold": player.gold,
		"level": player.level,
		"crafting_components": player.crafting_components.duplicate(),
	}

	# ── Active class ──
	active_class_name = player.active_class.player_class_name if player.active_class else ""

	# ── Class data (level, XP, skill ranks for all classes) ──
	class_data.clear()
	for cname in player.available_classes:
		var pc: PlayerClass = player.available_classes[cname]
		var centry: Dictionary = {
			"level": pc.level,
			"experience": pc.experience,
			"skill_points": pc.skill_points,
			"total_skill_points": pc.total_skill_points,
		}
		# Save skill ranks per tree
		var skill_ranks: Dictionary = {}
		for tree in pc.get_skill_trees():
			for skill in tree.get_all_skills():
				if skill:
					var rank: int = pc.get_skill_rank(skill.skill_id)
					if rank > 0:
						skill_ranks[skill.skill_id] = rank
		centry["skill_ranks"] = skill_ranks
		class_data[cname] = centry

	# ── Equipment (EquippableItem sub-resources — Godot serializes in full) ──
	player_equipment.clear()
	for slot in player.equipment:
		var item: EquippableItem = player.equipment[slot]
		if item:
			player_equipment[slot] = item

	# ── Inventory (unique EquippableItem instances) ──
	player_inventory = player.inventory.duplicate()

	# ── Consumables (by resource path + stack) ──
	player_consumables.clear()
	for c in player.consumables:
		if c and c.resource_path != "":
			player_consumables.append({
				"path": c.resource_path,
				"stack": c.current_stack,
			})

	# ── Consumable buffs (by consumable path + metadata) ──
	pending_consumable_buffs.clear()
	for buff in player.active_consumable_buffs:
		var consumable: ConsumableItem = buff.get("consumable")
		if consumable and consumable.resource_path != "":
			pending_consumable_buffs.append({
				"consumable_path": consumable.resource_path,
				"remaining_combats": buff.get("remaining_combats", 1),
				"type": buff.get("type", ""),
			})

	# ── Dice pool ──
	if player.dice_pool:
		dice_pool_data = player.dice_pool.to_dict()

	# ── GameManager state ──
	if game_manager:
		completed_encounters = game_manager.completed_encounters.duplicate()
		if game_manager.region_loot_config:
			active_region = game_manager.region_loot_config.get("region", 1) \
				if game_manager.region_loot_config is Dictionary \
				else 1

	print("SaveData: Player snapshot captured")


func restore_player(player: Player, game_manager = null) -> bool:
	"""Restore player state from this SaveData. Call after Player is created.
	Returns false if no player state was saved (first run).
	Pass game_manager to also restore completed_encounters and active_region."""
	if not has_player_state or not player:
		return false

	# ── Core stats ──
	player.max_hp = player_stats.get("max_hp", 100)
	player.current_hp = player_stats.get("current_hp", player.max_hp)
	player.base_armor = player_stats.get("base_armor", 0)
	player.base_barrier = player_stats.get("base_barrier", 0)
	player.max_mana = player_stats.get("max_mana", 50)
	player.current_mana = player_stats.get("current_mana", player.max_mana)
	player.strength = player_stats.get("strength", 10)
	player.agility = player_stats.get("agility", 10)
	player.intellect = player_stats.get("intellect", 10)
	player.luck = player_stats.get("luck", 10)
	player.gold = player_stats.get("gold", 0)
	player.level = player_stats.get("level", 1)
	player.crafting_components = player_stats.get("crafting_components", {})

	# ── Class data (restore levels, XP, skill ranks) ──
	for cname in class_data:
		if player.available_classes.has(cname):
			var pc: PlayerClass = player.available_classes[cname]
			var centry: Dictionary = class_data[cname]
			pc.level = centry.get("level", 1)
			pc.experience = centry.get("experience", 0)
			pc.skill_points = centry.get("skill_points", 0)
			pc.total_skill_points = centry.get("total_skill_points", 0)
			var skill_ranks: Dictionary = centry.get("skill_ranks", {})
			for skill_id in skill_ranks:
				pc.set_skill_rank(skill_id, skill_ranks[skill_id])

	# ── Switch to saved active class ──
	if active_class_name != "" and player.available_classes.has(active_class_name):
		player.switch_class(active_class_name)

	# ── Equipment ──
	for slot in player_equipment:
		var item: EquippableItem = player_equipment[slot]
		if item:
			# Migration: old saves lack serialized affix arrays — reinitialize
			if item.item_affixes.is_empty() and (item.base_stat_affixes.size() > 0 or item.manual_first_affix or item.slot_definition):
				item.initialize_affixes()
			player.equip_item(item, slot)

	# ── Inventory ──
	player.inventory = player_inventory.duplicate()
	for item in player.inventory:
		if item and item.item_affixes.is_empty():
			if item.base_stat_affixes.size() > 0 or item.manual_first_affix or item.slot_definition:
				item.initialize_affixes()

	# ── Consumables ──
	player.consumables.clear()
	for cdata_entry in player_consumables:
		var path: String = cdata_entry.get("path", "")
		if path != "" and ResourceLoader.exists(path):
			var c: ConsumableItem = load(path) as ConsumableItem
			if c:
				# Duplicate so runtime stack state is independent of the base .tres
				var instance: ConsumableItem = c.duplicate()
				instance.current_stack = cdata_entry.get("stack", 1)
				player.consumables.append(instance)

	# ── Consumable buffs ──
	player.active_consumable_buffs.clear()
	for buff_data in pending_consumable_buffs:
		var cpath: String = buff_data.get("consumable_path", "")
		if cpath != "" and ResourceLoader.exists(cpath):
			var consumable: ConsumableItem = load(cpath) as ConsumableItem
			if consumable:
				player.active_consumable_buffs.append({
					"consumable": consumable,
					"remaining_combats": buff_data.get("remaining_combats", 1),
					"type": buff_data.get("type", ""),
				})

	# ── Dice pool ──
	if not dice_pool_data.is_empty() and player.dice_pool:
		player.dice_pool.from_dict(dice_pool_data)

	# ── GameManager state ──
	if game_manager:
		game_manager.completed_encounters = completed_encounters.duplicate()
		if active_region > 0:
			game_manager.set_active_region(active_region)

	print("SaveData: Player state restored")
	return true


# ============================================================================
# DEBUG
# ============================================================================

func get_summary() -> String:
	"""Get a debug summary of save state."""
	var lines: Array[String] = []
	lines.append("=== Save Data Summary ===")
	lines.append("Version: %d" % version)
	lines.append("Play Time: %.1f hours" % (play_time / 3600.0))
	lines.append("Player Level: %d" % player_stats.get("level", 1))
	lines.append("Class: %s" % active_class_name)
	lines.append("HP: %d/%d" % [player_stats.get("current_hp", 0), player_stats.get("max_hp", 0)])
	lines.append("Gold: %d" % player_stats.get("gold", 0))
	lines.append("Equipment: %d slots" % player_equipment.size())
	lines.append("Inventory: %d items" % player_inventory.size())
	lines.append("Consumables: %d types" % player_consumables.size())
	lines.append("Current Location: %s" % map.current_location)
	lines.append("Flags Set: %d" % flags.get_all_flags().values().count(true))
	lines.append("Locations Visited: %d" % map.visited_locations.size())
	lines.append("Quests Active: %d" % quests.get_active_quests().size())
	lines.append("Quests Complete: %d" % quests.get_completed_quests().size())
	return "\n".join(lines)
