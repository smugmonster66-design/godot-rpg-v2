# res://scripts/autoload/dialogue_manager.gd
# Dialogue state machine. Pure logic, no UI.
# Drives conversation flow, choice selection, and event firing.
extends Node

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when a dialogue encounter starts
signal dialogue_started(encounter: DialogueEncounter)
## Emitted when a new line should be displayed
signal line_displayed(line: DialogueLine, speaker: DialogueSpeaker)
## Emitted when choices should be shown
signal choices_presented(choices: Array[DialogueChoice])
## Emitted when dialogue ends
signal dialogue_ended
## Emitted when an event tag should be processed
signal event_triggered(event_tag: StringName)

# ============================================================================
# STATE
# ============================================================================
var is_active: bool = false
var current_encounter: DialogueEncounter = null
var current_line: DialogueLine = null

## Speaker registry for current encounter
var _speaker_registry: Dictionary = {}  # speaker_id -> DialogueSpeaker

## Track one-shot encounters that have been completed
var _completed_oneshots: Dictionary = {}  # encounter_id -> true

# ============================================================================
# PUBLIC API
# ============================================================================

func start_dialogue(encounter: DialogueEncounter) -> bool:
	"""Start a dialogue encounter. Returns false if already in dialogue or one-shot completed."""
	if is_active:
		push_warning("DialogueManager: Already in dialogue, ignoring start_dialogue")
		return false
	
	if encounter == null or encounter.first_line == null:
		push_warning("DialogueManager: Invalid encounter or no first_line")
		return false
	
	# Check one-shot
	if encounter.one_shot and _completed_oneshots.get(encounter.encounter_id, false):
		print("DialogueManager: One-shot encounter '%s' already completed" % encounter.encounter_id)
		return false
	
	# Initialize
	is_active = true
	current_encounter = encounter
	_build_speaker_registry()
	
	# Apply start effects
	encounter.apply_start_effects()
	
	# Fire start event
	if encounter.on_start_event != &"":
		event_triggered.emit(encounter.on_start_event)
	
	dialogue_started.emit(encounter)
	
	# Show first line
	_display_line(encounter.first_line)
	return true

func advance() -> void:
	"""Advance to the next line (when no choices are present)."""
	if not is_active or current_line == null:
		return
	
	# Don't advance if there are choices
	if current_line.has_choices():
		return
	
	# Move to next line
	if current_line.next_line:
		_display_line(current_line.next_line)
	else:
		_end_dialogue()

func select_choice(index: int) -> void:
	"""Select a choice by index."""
	if not is_active or current_line == null:
		return
	
	var available = current_line.get_available_choices()
	if index < 0 or index >= available.size():
		push_warning("DialogueManager: Invalid choice index %d" % index)
		return
	
	var choice = available[index]
	
	# Check if choice is actually available (not just shown when locked)
	if not choice.is_available():
		push_warning("DialogueManager: Choice is locked")
		return
	
	# Apply choice effects
	choice.apply_effects()
	
	# Fire choice event
	if choice.event_tag != &"":
		event_triggered.emit(choice.event_tag)
	
	# Move to next line
	if choice.next_line:
		_display_line(choice.next_line)
	else:
		_end_dialogue()

func skip_dialogue() -> void:
	"""Skip the current dialogue (if skippable)."""
	if not is_active:
		return
	
	if current_encounter and not current_encounter.skippable:
		return
	
	_end_dialogue()

func notify_text_finished() -> void:
	"""Called by UI when text reveal is complete."""
	if not is_active or current_line == null:
		return
	
	# If there are choices, present them
	if current_line.has_choices():
		var available = current_line.get_available_choices()
		if available.size() > 0:
			choices_presented.emit(available)
		else:
			# All choices were filtered out - auto advance or end
			if current_line.next_line:
				_display_line(current_line.next_line)
			else:
				_end_dialogue()
	elif current_line.auto_advance:
		# Auto-advance after delay
		await get_tree().create_timer(current_line.auto_advance_delay).timeout
		if is_active:  # Check we're still active after the wait
			advance()

func get_speaker(speaker_id: StringName) -> DialogueSpeaker:
	"""Get a speaker from the current encounter's registry."""
	return _speaker_registry.get(speaker_id)

# ============================================================================
# INTERNAL
# ============================================================================

func _build_speaker_registry() -> void:
	"""Build lookup dictionary for speakers in current encounter."""
	_speaker_registry.clear()
	if current_encounter:
		for speaker in current_encounter.speakers:
			_speaker_registry[speaker.speaker_id] = speaker

func _display_line(line: DialogueLine) -> void:
	"""Display a dialogue line."""
	current_line = line
	
	# Apply line effects (set flags, etc.)
	line.apply_effects()
	
	# Fire line event
	if line.event_tag != &"":
		event_triggered.emit(line.event_tag)
	
	# Get speaker
	var speaker = get_speaker(line.speaker_id)
	
	# Emit signal for UI
	line_displayed.emit(line, speaker)

func _end_dialogue() -> void:
	"""End the current dialogue."""
	if not is_active:
		return
	
	# Mark one-shot as complete
	if current_encounter and current_encounter.one_shot:
		_completed_oneshots[current_encounter.encounter_id] = true
	
	# Apply end effects
	if current_encounter:
		current_encounter.apply_end_effects()
		if current_encounter.on_end_event != &"":
			event_triggered.emit(current_encounter.on_end_event)
	
	# Reset state
	is_active = false
	var ended_encounter = current_encounter
	current_encounter = null
	current_line = null
	_speaker_registry.clear()
	
	dialogue_ended.emit()

# ============================================================================
# SAVE/LOAD INTEGRATION
# ============================================================================

func mark_oneshot_complete(encounter_id: StringName) -> void:
	"""Manually mark a one-shot encounter as complete."""
	_completed_oneshots[encounter_id] = true

func is_oneshot_complete(encounter_id: StringName) -> bool:
	"""Check if a one-shot encounter has been completed."""
	return _completed_oneshots.get(encounter_id, false)

func get_completed_oneshots() -> Dictionary:
	"""Get all completed one-shot encounter IDs (for saving)."""
	return _completed_oneshots.duplicate()

func set_completed_oneshots(data: Dictionary) -> void:
	"""Restore completed one-shot encounters (from loading)."""
	_completed_oneshots = data.duplicate()
