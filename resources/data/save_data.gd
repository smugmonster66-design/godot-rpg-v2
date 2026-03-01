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
@export var version: int = 1
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

# ============================================================================
# PLAYER STATE
# ============================================================================
@export_group("Player")
## Snapshot of player stats (level, class levels, etc.)
## Note: This may duplicate data from your existing Player resource.
## You can either store the full Player resource here, or just key stats.
@export var player_level: int = 1
@export var class_levels: Dictionary = {}  # StringName -> int
@export var experience: int = 0

## Inventory is likely its own system - store reference or IDs
@export var inventory_data: Dictionary = {}

## Equipment slots
@export var equipped_items: Dictionary = {}  # slot_name -> item_id

## Current dice pool (for your dice RPG)
@export var dice_pool: Array[StringName] = []

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
	if quests == null:
		quests = QuestJournal.new()
	if map == null:
		map = MapProgress.new()
	
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
	return class_levels.get(class_id, 0)

func set_class_level(class_id: StringName, level: int) -> void:
	"""Set level for a specific class."""
	class_levels[class_id] = level

# ============================================================================
# DEBUG
# ============================================================================

func get_summary() -> String:
	"""Get a debug summary of save state."""
	var lines: Array[String] = []
	lines.append("=== Save Data Summary ===")
	lines.append("Version: %d" % version)
	lines.append("Play Time: %.1f hours" % (play_time / 3600.0))
	lines.append("Player Level: %d" % player_level)
	lines.append("Current Location: %s" % map.current_location)
	lines.append("Flags Set: %d" % flags.get_all_flags().values().count(true))
	lines.append("Locations Visited: %d" % map.visited_locations.size())
	lines.append("Quests Active: %d" % quests.get_active_quests().size())
	lines.append("Quests Complete: %d" % quests.get_completed_quests().size())
	return "\n".join(lines)
