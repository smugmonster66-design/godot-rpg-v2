# res://resources/data/dialogue_encounter.gd
# A complete dialogue encounter - the entry point for a conversation.
# Contains speakers, initial setup, and the first line of dialogue.
extends Resource
class_name DialogueEncounter

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## Unique identifier for this encounter
@export var encounter_id: StringName = &""
## Display name (for editor/debug)
@export var display_name: String = ""

# ============================================================================
# SPEAKERS
# ============================================================================
@export_group("Speakers")
## All speakers who appear in this encounter
@export var speakers: Array[DialogueSpeaker] = []

# ============================================================================
# INITIAL SETUP
# ============================================================================
@export_group("Initial Busts")
## Speaker to show in the left bust slot at start
@export var initial_left_bust: StringName = &""
## Speaker to show in the center bust slot at start
@export var initial_center_bust: StringName = &""
## Speaker to show in the right bust slot at start
@export var initial_right_bust: StringName = &""

# ============================================================================
# ENTRY POINT
# ============================================================================
@export_group("Dialogue")
## The first line of dialogue
@export var first_line: DialogueLine = null

# ============================================================================
# SETTINGS
# ============================================================================
@export_group("Settings")
## If true, pause the game while dialogue is active
@export var pause_game: bool = false
## If true, show a dim overlay behind the dialogue UI
@export var show_dim_overlay: bool = true
## Intensity of the dim overlay (0-1)
@export var dim_intensity: float = 0.4
## If true, this encounter can only trigger once per save file
@export var one_shot: bool = false
## If true, player can skip this dialogue with Escape
@export var skippable: bool = true

# ============================================================================
# EVENTS
# ============================================================================
@export_group("Events")
## Event tag to fire when this encounter starts
@export var on_start_event: StringName = &""
## Event tag to fire when this encounter ends
@export var on_end_event: StringName = &""
## Flags to set when encounter starts
@export var set_flags_on_start: Array[StringName] = []
## Flags to set when encounter ends
@export var set_flags_on_end: Array[StringName] = []

# ============================================================================
# API
# ============================================================================

func get_speaker(speaker_id: StringName) -> DialogueSpeaker:
	"""Look up a speaker by ID."""
	for speaker in speakers:
		if speaker.speaker_id == speaker_id:
			return speaker
	return null

func has_speaker(speaker_id: StringName) -> bool:
	"""Check if a speaker is registered in this encounter."""
	return get_speaker(speaker_id) != null

func get_speaker_ids() -> Array[StringName]:
	"""Get list of all speaker IDs in this encounter."""
	var result: Array[StringName] = []
	for speaker in speakers:
		result.append(speaker.speaker_id)
	return result

func apply_start_effects() -> void:
	"""Apply effects when encounter starts."""
	for flag_name in set_flags_on_start:
		if Engine.has_singleton("GameState"):
			GameState.set_flag(flag_name, true)

func apply_end_effects() -> void:
	"""Apply effects when encounter ends."""
	for flag_name in set_flags_on_end:
		if Engine.has_singleton("GameState"):
			GameState.set_flag(flag_name, true)
