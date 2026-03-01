# res://resources/data/quest_progress.gd
# Runtime state for a single quest. This IS saved data.
# Paired with a QuestDefinition which defines what the quest IS.
extends Resource
class_name QuestProgress

enum QuestState {
	LOCKED,         # Prerequisites not met, not visible
	AVAILABLE,      # Can be accepted but hasn't been
	ACTIVE,         # Currently in progress
	READY_TO_TURN_IN, # All objectives complete, awaiting turn-in
	COMPLETE,       # Finished and turned in
	FAILED          # Failed (if quest can fail)
}

# ============================================================================
# IDENTITY
# ============================================================================
## Quest definition this progress tracks
@export var quest_id: StringName = &""

# ============================================================================
# STATE
# ============================================================================
@export var state: QuestState = QuestState.LOCKED

## When quest was accepted (unix timestamp, 0 if not accepted)
@export var accepted_at: float = 0.0

## When quest was completed (unix timestamp, 0 if not complete)
@export var completed_at: float = 0.0

## For repeatable quests - how many times completed
@export var completion_count: int = 0

# ============================================================================
# OBJECTIVE PROGRESS
# ============================================================================
## Progress per objective: { objective_id: current_count }
@export var objective_progress: Dictionary = {}

## Objectives that are complete: { objective_id: true }
@export var objectives_complete: Dictionary = {}

# ============================================================================
# API
# ============================================================================

func is_active() -> bool:
	return state == QuestState.ACTIVE or state == QuestState.READY_TO_TURN_IN

func is_complete() -> bool:
	return state == QuestState.COMPLETE

func is_available() -> bool:
	return state == QuestState.AVAILABLE

func is_locked() -> bool:
	return state == QuestState.LOCKED

func is_failed() -> bool:
	return state == QuestState.FAILED

func get_objective_progress(objective_id: StringName) -> int:
	"""Get current progress for an objective."""
	return objective_progress.get(objective_id, 0)

func is_objective_complete(objective_id: StringName) -> bool:
	"""Check if a specific objective is complete."""
	return objectives_complete.get(objective_id, false)

func increment_objective(objective_id: StringName, amount: int = 1) -> int:
	"""Increment objective progress. Returns new value."""
	var current = objective_progress.get(objective_id, 0)
	var new_value = current + amount
	objective_progress[objective_id] = new_value
	return new_value

func set_objective_complete(objective_id: StringName, complete: bool = true) -> void:
	"""Mark an objective as complete."""
	objectives_complete[objective_id] = complete

func get_time_elapsed() -> float:
	"""Get seconds since quest was accepted."""
	if accepted_at <= 0:
		return 0.0
	return Time.get_unix_time_from_system() - accepted_at

func reset_progress() -> void:
	"""Reset all progress (for repeatable quests)."""
	objective_progress.clear()
	objectives_complete.clear()
	accepted_at = 0.0
	completed_at = 0.0
	state = QuestState.AVAILABLE

# ============================================================================
# FACTORY
# ============================================================================

static func create(quest_id: StringName, initial_state: QuestState = QuestState.LOCKED) -> QuestProgress:
	var progress = QuestProgress.new()
	progress.quest_id = quest_id
	progress.state = initial_state
	return progress
