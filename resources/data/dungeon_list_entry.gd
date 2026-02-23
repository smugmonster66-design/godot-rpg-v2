# res://resources/data/dungeon_list_entry.gd
## Lightweight wrapper displayed in the dungeon selection screen.
## Points to a DungeonDefinition and adds unlock conditions + preview info.
extends Resource
class_name DungeonListEntry

# ============================================================================
# IDENTITY
# ============================================================================
@export var dungeon_definition: DungeonDefinition = null

# ============================================================================
# UNLOCK CONDITIONS
# ============================================================================
@export_group("Unlock")

enum UnlockType {
	NONE,                ## Always available
	PLAYER_LEVEL,        ## Requires player level >= unlock_value
	DUNGEON_CLEARED,     ## Requires another dungeon_id cleared
	CUSTOM,              ## Check unlock_flag in GameManager
}

@export var unlock_type: UnlockType = UnlockType.NONE
@export var unlock_value: int = 0
@export var unlock_dungeon_id: String = ""
@export var unlock_flag: String = ""
@export var lock_reason: String = ""

# ============================================================================
# DISPLAY OVERRIDES
# ============================================================================
@export_group("Display")
@export var recommended_level: int = 0
@export var reward_preview: String = ""
@export var sort_order: int = 0

# ============================================================================
# HELPERS
# ============================================================================

func is_unlocked(player: Player) -> bool:
	match unlock_type:
		UnlockType.NONE:
			return true
		UnlockType.PLAYER_LEVEL:
			return player != null and player.level >= unlock_value
		UnlockType.DUNGEON_CLEARED:
			if not GameManager: return false
			return GameManager.completed_encounters.has("dungeon_" + unlock_dungeon_id)
		UnlockType.CUSTOM:
			if not GameManager: return false
			return GameManager.completed_encounters.has(unlock_flag)
	return false

func get_display_name() -> String:
	if dungeon_definition: return dungeon_definition.dungeon_name
	return "???"

func get_display_level() -> int:
	if recommended_level > 0: return recommended_level
	if dungeon_definition: return dungeon_definition.dungeon_level
	return 1

func get_description() -> String:
	if dungeon_definition: return dungeon_definition.description
	return ""

func get_icon() -> Texture2D:
	if dungeon_definition: return dungeon_definition.icon
	return null

func get_floor_count() -> int:
	if dungeon_definition: return dungeon_definition.floor_count
	return 0

func get_lock_text() -> String:
	if lock_reason != "": return lock_reason
	match unlock_type:
		UnlockType.PLAYER_LEVEL:
			return "Requires Level %d" % unlock_value
		UnlockType.DUNGEON_CLEARED:
			return "Clear %s first" % unlock_dungeon_id
		UnlockType.CUSTOM:
			return "Locked"
	return ""

func validate() -> Array[String]:
	var warnings: Array[String] = []
	if not dungeon_definition:
		warnings.append("No dungeon_definition assigned")
	else:
		warnings.append_array(dungeon_definition.validate())
	if unlock_type == UnlockType.DUNGEON_CLEARED and unlock_dungeon_id == "":
		warnings.append("DUNGEON_CLEARED unlock but no unlock_dungeon_id")
	return warnings
