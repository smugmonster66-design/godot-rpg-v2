# res://resources/data/quest_objective.gd
# A single objective within a quest.
# Quests can have multiple objectives, some optional.
extends Resource
class_name QuestObjective

enum ObjectiveType {
	TALK_TO,        # Speak with an NPC
	KILL,           # Defeat enemies of a type
	COLLECT,        # Gather items
	VISIT,          # Reach a location
	DELIVER,        # Bring item to NPC
	INTERACT,       # Use/activate something
	ESCORT,         # Protect NPC to destination
	SURVIVE,        # Stay alive for duration/waves
	CUSTOM          # Tracked via events
}

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## Unique ID within this quest. Used to track progress.
@export var objective_id: StringName = &""
## Display text shown in quest log. Supports {current}/{required} placeholders.
@export var description: String = ""
## Localization key (if empty, uses description directly)
@export var description_key: String = ""

# ============================================================================
# OBJECTIVE DETAILS
# ============================================================================
@export_group("Objective")
@export var objective_type: ObjectiveType = ObjectiveType.TALK_TO
## Target ID - NPC id, enemy type, item id, location id, etc.
@export var target_id: StringName = &""
## How many times this must be done (1 for talk_to, N for kill/collect)
@export var required_count: int = 1

# ============================================================================
# FLOW CONTROL
# ============================================================================
@export_group("Flow")
## If true, quest can complete without this objective
@export var optional: bool = false
## If true, this objective is hidden until all previous objectives complete
@export var hidden_until_previous: bool = false
## Objectives that must be complete before this one is active
@export var prerequisite_objectives: Array[StringName] = []

# ============================================================================
# HINTS
# ============================================================================
@export_group("Hints")
## Location where this objective can be completed (for map markers)
@export var hint_location: StringName = &""
## Additional hint text
@export var hint_text: String = ""

# ============================================================================
# HELPERS
# ============================================================================

func get_display_description(current: int = 0) -> String:
	"""Get description with progress filled in."""
	var text = description_key if description_key != "" else description
	# TODO: Localization lookup
	text = text.replace("{current}", str(current))
	text = text.replace("{required}", str(required_count))
	return text

func is_count_based() -> bool:
	"""Returns true if this objective requires multiple completions."""
	return required_count > 1
