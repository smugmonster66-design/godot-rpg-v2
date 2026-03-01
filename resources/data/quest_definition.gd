# res://resources/data/quest_definition.gd
# Static definition of a quest - its objectives, rewards, giver, etc.
# This is NOT saved data - it's the template that defines what a quest IS.
# Runtime state is tracked in QuestProgress.
extends Resource
class_name QuestDefinition

enum QuestType {
	MAIN,           # Main storyline quests
	SIDE,           # Optional side content
	COMPANION,      # Companion-specific quests
	BOUNTY,         # Repeatable kill quests
	COLLECTION,     # Gathering quests
	EXPLORATION,    # Discovery quests
	HIDDEN          # Secret/unmarked quests
}

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## Unique quest identifier
@export var quest_id: StringName = &""
## Display name in quest log
@export var display_name: String = ""
## Localization key for display_name (if empty, uses display_name)
@export var name_key: String = ""
## Quest category for organization
@export var quest_type: QuestType = QuestType.SIDE

# ============================================================================
# DESCRIPTION
# ============================================================================
@export_group("Description")
## Short summary shown in quest list
@export_multiline var summary: String = ""
## Full description shown in quest details
@export_multiline var description: String = ""
## Localization keys
@export var summary_key: String = ""
@export var description_key: String = ""

# ============================================================================
# QUEST GIVER
# ============================================================================
@export_group("Quest Giver")
## NPC who gives this quest (speaker_id)
@export var quest_giver_id: StringName = &""
## Location where quest giver can be found
@export var quest_giver_location: StringName = &""
## NPC who receives turn-in (if different from giver)
@export var turn_in_npc_id: StringName = &""
## Location for turn-in (if different from giver location)
@export var turn_in_location: StringName = &""

# ============================================================================
# OBJECTIVES
# ============================================================================
@export_group("Objectives")
## List of objectives to complete
@export var objectives: Array[QuestObjective] = []
## If true, objectives can be completed in any order
@export var objectives_unordered: bool = false

# ============================================================================
# REWARDS
# ============================================================================
@export_group("Rewards")
@export var rewards: QuestRewards = null

# ============================================================================
# PREREQUISITES & AVAILABILITY
# ============================================================================
@export_group("Prerequisites")
## Condition that must be met for quest to become available
@export var prerequisites: GameCondition = null
## Level requirement (0 = no requirement)
@export var required_level: int = 0
## If true, quest is not shown in log until accepted
@export var hidden_until_accepted: bool = false
## If true, quest can be repeated after completion
@export var repeatable: bool = false
## Cooldown in seconds before repeatable quest is available again
@export var repeat_cooldown: float = 0.0

# ============================================================================
# FAILURE CONDITIONS
# ============================================================================
@export_group("Failure")
## If true, quest can be failed
@export var can_fail: bool = false
## Condition that causes quest failure (checked periodically)
@export var fail_condition: GameCondition = null
## Time limit in seconds (0 = no limit)
@export var time_limit: float = 0.0

# ============================================================================
# EVENTS
# ============================================================================
@export_group("Events")
## Event tags fired when quest is accepted
@export var on_accept_events: Array[StringName] = []
## Event tags fired when quest is completed
@export var on_complete_events: Array[StringName] = []
## Event tags fired when quest is failed
@export var on_fail_events: Array[StringName] = []

# ============================================================================
# VISUAL
# ============================================================================
@export_group("Visual")
@export var icon: Texture2D = null
## Map marker icon override
@export var marker_icon: Texture2D = null

# ============================================================================
# API
# ============================================================================

func get_display_name() -> String:
	# TODO: Localization lookup
	return display_name if name_key == "" else display_name

func get_summary() -> String:
	# TODO: Localization lookup
	return summary if summary_key == "" else summary

func get_description() -> String:
	# TODO: Localization lookup
	return description if description_key == "" else description

func get_turn_in_npc() -> StringName:
	"""Get NPC to turn quest in to. Falls back to quest giver."""
	return turn_in_npc_id if turn_in_npc_id != &"" else quest_giver_id

func get_turn_in_location() -> StringName:
	"""Get location for turn-in. Falls back to quest giver location."""
	return turn_in_location if turn_in_location != &"" else quest_giver_location

func get_required_objective_count() -> int:
	"""Get number of non-optional objectives."""
	var count = 0
	for obj in objectives:
		if not obj.optional:
			count += 1
	return count

func get_objective(objective_id: StringName) -> QuestObjective:
	"""Look up an objective by ID."""
	for obj in objectives:
		if obj.objective_id == objective_id:
			return obj
	return null

func get_rewards_preview() -> String:
	"""Get reward summary for UI."""
	if rewards:
		return rewards.get_preview_text()
	return "No rewards"
