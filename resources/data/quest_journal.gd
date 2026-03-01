# res://resources/data/quest_journal.gd
# Collection of all quest progress. Part of SaveData.
# Tracks which quests are active, complete, etc.
extends Resource
class_name QuestJournal

signal quest_state_changed(quest_id: StringName, old_state: int, new_state: int)
signal quest_accepted(quest_id: StringName)
signal quest_completed(quest_id: StringName)
signal quest_failed(quest_id: StringName)
signal objective_updated(quest_id: StringName, objective_id: StringName, progress: int)
signal objective_completed(quest_id: StringName, objective_id: StringName)

# ============================================================================
# STORAGE
# ============================================================================
## All quest progress: { quest_id: QuestProgress }
@export var _quests: Dictionary = {}

# ============================================================================
# API - QUERIES
# ============================================================================

func has_quest(quest_id: StringName) -> bool:
	"""Check if we have any record of this quest."""
	return quest_id in _quests

func get_progress(quest_id: StringName) -> QuestProgress:
	"""Get progress for a quest. Creates LOCKED entry if doesn't exist."""
	if quest_id not in _quests:
		_quests[quest_id] = QuestProgress.create(quest_id, QuestProgress.QuestState.LOCKED)
	return _quests[quest_id]

func get_state(quest_id: StringName) -> QuestProgress.QuestState:
	"""Get current state of a quest."""
	return get_progress(quest_id).state

func get_state_string(quest_id: StringName) -> String:
	"""Get state as a string for condition checking."""
	match get_state(quest_id):
		QuestProgress.QuestState.LOCKED: return "locked"
		QuestProgress.QuestState.AVAILABLE: return "available"
		QuestProgress.QuestState.ACTIVE: return "active"
		QuestProgress.QuestState.READY_TO_TURN_IN: return "ready"
		QuestProgress.QuestState.COMPLETE: return "complete"
		QuestProgress.QuestState.FAILED: return "failed"
	return "unknown"

func is_active(quest_id: StringName) -> bool:
	return get_progress(quest_id).is_active()

func is_complete(quest_id: StringName) -> bool:
	return get_progress(quest_id).is_complete()

func is_available(quest_id: StringName) -> bool:
	return get_progress(quest_id).is_available()

func is_locked(quest_id: StringName) -> bool:
	return get_progress(quest_id).is_locked()

# ============================================================================
# API - STATE CHANGES
# ============================================================================

func make_available(quest_id: StringName) -> void:
	"""Make a quest available to accept."""
	var progress = get_progress(quest_id)
	if progress.state == QuestProgress.QuestState.LOCKED:
		var old_state = progress.state
		progress.state = QuestProgress.QuestState.AVAILABLE
		quest_state_changed.emit(quest_id, old_state, progress.state)

func accept_quest(quest_id: StringName) -> bool:
	"""Accept an available quest. Returns true if successful."""
	var progress = get_progress(quest_id)
	if progress.state != QuestProgress.QuestState.AVAILABLE:
		return false
	
	var old_state = progress.state
	progress.state = QuestProgress.QuestState.ACTIVE
	progress.accepted_at = Time.get_unix_time_from_system()
	progress.objective_progress.clear()
	progress.objectives_complete.clear()
	
	quest_state_changed.emit(quest_id, old_state, progress.state)
	quest_accepted.emit(quest_id)
	return true

func complete_quest(quest_id: StringName) -> bool:
	"""Mark a quest as complete (after turn-in). Returns true if successful."""
	var progress = get_progress(quest_id)
	if progress.state != QuestProgress.QuestState.READY_TO_TURN_IN and progress.state != QuestProgress.QuestState.ACTIVE:
		return false
	
	var old_state = progress.state
	progress.state = QuestProgress.QuestState.COMPLETE
	progress.completed_at = Time.get_unix_time_from_system()
	progress.completion_count += 1
	
	quest_state_changed.emit(quest_id, old_state, progress.state)
	quest_completed.emit(quest_id)
	return true

func fail_quest(quest_id: StringName) -> bool:
	"""Mark a quest as failed. Returns true if successful."""
	var progress = get_progress(quest_id)
	if not progress.is_active():
		return false
	
	var old_state = progress.state
	progress.state = QuestProgress.QuestState.FAILED
	
	quest_state_changed.emit(quest_id, old_state, progress.state)
	quest_failed.emit(quest_id)
	return true

func set_ready_to_turn_in(quest_id: StringName) -> void:
	"""Mark quest as ready for turn-in (all objectives complete)."""
	var progress = get_progress(quest_id)
	if progress.state == QuestProgress.QuestState.ACTIVE:
		var old_state = progress.state
		progress.state = QuestProgress.QuestState.READY_TO_TURN_IN
		quest_state_changed.emit(quest_id, old_state, progress.state)

# ============================================================================
# API - OBJECTIVE PROGRESS
# ============================================================================

func update_objective(quest_id: StringName, objective_id: StringName, progress_delta: int = 1) -> void:
	"""Increment objective progress. Use with QuestDefinition to check completion."""
	var progress = get_progress(quest_id)
	if not progress.is_active():
		return
	
	var new_value = progress.increment_objective(objective_id, progress_delta)
	objective_updated.emit(quest_id, objective_id, new_value)

func complete_objective(quest_id: StringName, objective_id: StringName) -> void:
	"""Mark an objective as complete."""
	var progress = get_progress(quest_id)
	if not progress.is_active():
		return
	
	if not progress.is_objective_complete(objective_id):
		progress.set_objective_complete(objective_id, true)
		objective_completed.emit(quest_id, objective_id)

func get_objective_progress(quest_id: StringName, objective_id: StringName) -> int:
	"""Get current progress for an objective."""
	return get_progress(quest_id).get_objective_progress(objective_id)

func is_objective_complete(quest_id: StringName, objective_id: StringName) -> bool:
	"""Check if a specific objective is complete."""
	return get_progress(quest_id).is_objective_complete(objective_id)

# ============================================================================
# API - BULK QUERIES
# ============================================================================

func get_active_quests() -> Array[StringName]:
	"""Get IDs of all active quests."""
	var result: Array[StringName] = []
	for quest_id in _quests:
		if _quests[quest_id].is_active():
			result.append(quest_id)
	return result

func get_completed_quests() -> Array[StringName]:
	"""Get IDs of all completed quests."""
	var result: Array[StringName] = []
	for quest_id in _quests:
		if _quests[quest_id].is_complete():
			result.append(quest_id)
	return result

func get_available_quests() -> Array[StringName]:
	"""Get IDs of all available (not yet accepted) quests."""
	var result: Array[StringName] = []
	for quest_id in _quests:
		if _quests[quest_id].is_available():
			result.append(quest_id)
	return result

func get_quests_by_state(state: QuestProgress.QuestState) -> Array[StringName]:
	"""Get all quest IDs matching a specific state."""
	var result: Array[StringName] = []
	for quest_id in _quests:
		if _quests[quest_id].state == state:
			result.append(quest_id)
	return result

func get_all_quest_ids() -> Array[StringName]:
	"""Get all tracked quest IDs."""
	var result: Array[StringName] = []
	for quest_id in _quests:
		result.append(quest_id)
	return result
