# res://resources/data/dialogue_line.gd
# A single line of dialogue - one "beat" in a conversation.
# Contains text, speaker info, bust management, and branching.
extends Resource
class_name DialogueLine

# ============================================================================
# CONTENT
# ============================================================================
@export_group("Content")
## The speaker's ID (matches DialogueSpeaker.speaker_id). Empty for narration.
@export var speaker_id: StringName = &""
## The dialogue text. Supports BBCode: [b], [i], [color], [wave], [shake], etc.
@export_multiline var text: String = ""
## Localization key for text (if empty, uses text directly)
@export var text_key: String = ""
## Speaker's mood for this line (changes bust texture if speaker has mood variants)
@export var mood: StringName = &""

# ============================================================================
# BUST MANAGEMENT
# ============================================================================
@export_group("Bust Slots")
## Set the left bust slot to this speaker_id (empty = no change)
@export var set_left_bust: StringName = &""
## Set the center bust slot to this speaker_id (empty = no change)
@export var set_center_bust: StringName = &""
## Set the right bust slot to this speaker_id (empty = no change)
@export var set_right_bust: StringName = &""
## Clear the left bust slot
@export var clear_left: bool = false
## Clear the center bust slot
@export var clear_center: bool = false
## Clear the right bust slot
@export var clear_right: bool = false

# ============================================================================
# FLOW CONTROL
# ============================================================================
@export_group("Flow")
## Next line to show (if no choices). Null = end of conversation branch.
@export var next_line: Resource = null  # DialogueLine (circular ref workaround)
## Player choices at this line. If non-empty, these are shown instead of auto-advancing.
@export var choices: Array[DialogueChoice] = []

# ============================================================================
# TIMING
# ============================================================================
@export_group("Timing")
## Override text speed for this line (chars/sec). 0 = use default.
@export var text_speed_override: float = 0.0
## If true, automatically advance after text finishes (no click required)
@export var auto_advance: bool = false
## Delay before auto-advancing (seconds). Only used if auto_advance is true.
@export var auto_advance_delay: float = 1.5

# ============================================================================
# EVENTS
# ============================================================================
@export_group("Events")
## Event tag to fire when this line is displayed
@export var event_tag: StringName = &""
## Flags to set when this line is displayed
@export var set_flags: Array[StringName] = []
## Sound effect to play when this line appears
@export var sfx: AudioStream = null

# ============================================================================
# API
# ============================================================================

func get_text() -> String:
	"""Get the localized dialogue text."""
	# TODO: Hook into localization system
	if text_key != "":
		# return tr(text_key)
		pass
	return text

func is_narration() -> bool:
	"""Returns true if this is narrator text (no speaker)."""
	return speaker_id == &"" or speaker_id == &"narrator"

func has_choices() -> bool:
	"""Returns true if this line has player choices."""
	return choices.size() > 0

func get_available_choices() -> Array[DialogueChoice]:
	"""Get choices that should be displayed (condition met or show_when_locked)."""
	var available: Array[DialogueChoice] = []
	for choice in choices:
		if choice.should_display():
			available.append(choice)
	return available

func has_bust_changes() -> bool:
	"""Returns true if this line modifies any bust slots."""
	return (set_left_bust != &"" or set_center_bust != &"" or set_right_bust != &""
		or clear_left or clear_center or clear_right)

func apply_effects() -> void:
	"""Apply side effects when this line is displayed."""
	for flag_name in set_flags:
		if Engine.has_singleton("GameState"):
			GameState.set_flag(flag_name, true)
