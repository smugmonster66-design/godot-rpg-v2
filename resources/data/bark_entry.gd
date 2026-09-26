# res://resources/data/bark_entry.gd
# A single bark line — one thing a character can say as a quick reaction.
# Used in BarkReaction pools and Action.barks_on_use arrays.
extends Resource
class_name BarkEntry

## The text to display. Supports BBCode.
@export var text: String = ""

## Who speaks this line. Maps to DialogueSpeaker for name_color and voice_blip.
## If empty, inherits from the parent BarkSet's speaker_id.
@export var speaker_id: StringName = &""

## How long the bark stays visible (seconds)
@export var duration: float = 2.0

## Optional one-shot sound to play (overrides speaker's voice_blip)
@export var sound: AudioStream = null

## Priority for replacement logic. Higher priority barks replace lower ones.
@export var priority: int = 0
