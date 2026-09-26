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

## Last line that was actually shown in the UI (not action nodes)
var _last_visible_line: DialogueLine = null

## Track one-shot encounters that have been completed
var _completed_oneshots: Dictionary = {}  # encounter_id -> true

## Suspend/resume for blocking game actions (combat, dungeon) triggered mid-dialogue
var _pending_resume_line: DialogueLine = null
var _suspended_encounter: DialogueEncounter = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	print("[DialogueManager] _ready — script loaded OK")

# ============================================================================
# PUBLIC API
# ============================================================================

func start_dialogue(encounter: DialogueEncounter) -> bool:
	"""Start a dialogue encounter. Returns false if already in dialogue or one-shot completed."""
	print("[DialogueManager] start_dialogue called: encounter=%s" % encounter)
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
	print("[DialogueManager] select_choice: next_line=%s" % choice.next_line)
	if choice.next_line:
		print("[DialogueManager] select_choice: advancing to next_line")
		_display_line(choice.next_line)
	else:
		print("[DialogueManager] select_choice: NO next_line — ending dialogue")
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
	print("[DialogueManager] _display_line called")
	current_line = line

	# Apply line effects (set flags, etc.)
	line.apply_effects()

	# Intercept game action tags before showing to UI
	if line.event_tag != &"":
		if str(line.event_tag).begins_with("game_action:"):
			_handle_game_action(line)
			return  # Don't show this line in the dialogue UI
		event_triggered.emit(line.event_tag)

	# Track this as the last line shown in the UI
	_last_visible_line = line

	# Get speaker
	var speaker = get_speaker(line.speaker_id)

	# Emit signal for UI
	line_displayed.emit(line, speaker)

func _handle_game_action(line: DialogueLine) -> void:
	"""Parse and dispatch a game_action event tag."""
	var tag_str = str(line.event_tag)
	var first_colon = tag_str.find(":")
	var second_colon = tag_str.find(":", first_colon + 1)
	if first_colon < 0 or second_colon < 0:
		push_warning("DialogueManager: Malformed game_action tag: %s" % tag_str)
		_auto_advance_or_end(line)
		return

	var action_type = int(tag_str.substr(first_colon + 1, second_colon - first_colon - 1))
	var param = tag_str.substr(second_colon + 1)

	print("[DialogueManager] _handle_game_action: type=%d param='%s' next_line=%s" % [action_type, param, line.next_line])

	match action_type:
		0:  # START_COMBAT
			_pending_resume_line = line.next_line
			print("[DialogueManager] START_COMBAT — _pending_resume_line=%s" % _pending_resume_line)
			_suspend_dialogue()
			if GameManager and GameManager.game_root:
				var encounter = load(param) as Resource
				if encounter:
					GameManager.pending_encounter = encounter
					GameManager.game_root.start_combat(encounter)
				else:
					push_warning("DialogueManager: Failed to load combat encounter: %s" % param)
					resume_dialogue()
			else:
				push_warning("DialogueManager: No GameManager.game_root for START_COMBAT")
				resume_dialogue()

		1:  # OPEN_SHOP
			event_triggered.emit(StringName("open_shop:%s" % param))
			_auto_advance_or_end(line)

		2:  # CUSTOM_EVENT
			GameEventRegistry.fire_event(StringName(param))
			_auto_advance_or_end(line)

		3:  # ENTER_DUNGEON
			_pending_resume_line = line.next_line
			_suspend_dialogue()
			if GameManager and GameManager.game_root:
				var dungeon_def = load(param) as Resource
				if dungeon_def:
					GameManager.game_root.enter_dungeon(dungeon_def)
				else:
					push_warning("DialogueManager: Failed to load dungeon: %s" % param)
					resume_dialogue()
			else:
				push_warning("DialogueManager: No GameManager.game_root for ENTER_DUNGEON")
				resume_dialogue()

		4:  # ACCEPT_QUEST
			var quest_id = StringName(param)
			QuestManager.make_quest_available(quest_id)
			QuestManager.try_accept_quest(quest_id)
			_auto_advance_or_end(line)

		5:  # COMPLETE_QUEST
			var quest_id = StringName(param)
			QuestManager.try_complete_quest(quest_id)
			_auto_advance_or_end(line)

		6:  # REPORT_OBJECTIVE
			var sep = param.find(":")
			if sep >= 0:
				QuestManager.report_objective_by_id(
					StringName(param.substr(0, sep)),
					StringName(param.substr(sep + 1)))
			else:
				push_warning("DialogueManager: REPORT_OBJECTIVE param must be quest_id:objective_id, got: %s" % param)
			_auto_advance_or_end(line)

		7:  # OPEN_SMITHING
			print("[DialogueManager] OPEN_SMITHING — emitting open_smithing:%s" % param)
			event_triggered.emit(StringName("open_smithing:%s" % param))
			_auto_advance_or_end(line)

		_:
			push_warning("DialogueManager: Unknown game_action type: %d" % action_type)
			_auto_advance_or_end(line)

func _auto_advance_or_end(line: DialogueLine) -> void:
	"""Auto-advance to the next line, show choices, or end dialogue."""
	if line.next_line:
		_display_line(line.next_line)
	elif line.choices.size() > 0:
		# Action node connected directly to a choice node — present choices
		# on top of the last visible line so the dialogue text stays on screen.
		# Keep current_line pointing to the action node so select_choice works,
		# but don't clear the UI's displayed text (_last_visible_line stays).
		current_line = line
		# Present the FILTERED list: select_choice() indexes into
		# get_available_choices(), so presenting the raw list misindexed clicks
		# (and showed hidden choices) when any choice had a condition.
		var available: Array[DialogueChoice] = line.get_available_choices()
		if available.is_empty():
			_end_dialogue()
			return
		print("[DialogueManager] _auto_advance_or_end: presenting %d choices from action node" % available.size())
		choices_presented.emit(available)
	else:
		print("[DialogueManager] _auto_advance_or_end: no next_line, no choices — ending dialogue")
		_end_dialogue()

func _suspend_dialogue() -> void:
	"""Suspend dialogue for a blocking action (combat, dungeon). UI hides."""
	_suspended_encounter = current_encounter
	print("[DialogueManager] _suspend_dialogue — _suspended_encounter=%s _pending_resume_line=%s" % [_suspended_encounter, _pending_resume_line])
	is_active = false
	current_encounter = null
	current_line = null
	dialogue_ended.emit()

func resume_dialogue() -> void:
	"""Resume dialogue after a blocking action completes."""
	print("[DialogueManager] resume_dialogue called — _pending_resume_line=%s _suspended_encounter=%s" % [_pending_resume_line, _suspended_encounter])
	if _pending_resume_line and _suspended_encounter:
		current_encounter = _suspended_encounter
		_suspended_encounter = null
		is_active = true
		_build_speaker_registry()
		dialogue_started.emit(current_encounter)
		_display_line(_pending_resume_line)
		_pending_resume_line = null
	else:
		_suspended_encounter = null
		_pending_resume_line = null
		_end_dialogue()

func has_pending_resume() -> bool:
	"""Check if dialogue is waiting to resume after a blocking action."""
	return _pending_resume_line != null or _suspended_encounter != null

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
	_last_visible_line = null
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
