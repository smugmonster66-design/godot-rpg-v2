# res://resources/data/mood_texture.gd
# Pairs a mood type with its corresponding bust texture.
# Used in DialogueSpeaker to define available expressions.
@tool
extends Resource
class_name MoodTexture

## The mood/expression this texture represents
@export var mood: MoodTypes.Mood = MoodTypes.Mood.BASE

## The bust texture for this mood
@export var texture: Texture2D = null

# ============================================================================
# HELPERS
# ============================================================================

func get_mood_name() -> String:
	"""Get the string name of this mood."""
	return MoodTypes.mood_to_string(mood)

func get_mood_display_name() -> String:
	"""Get a nicely formatted display name."""
	return MoodTypes.get_mood_display_name(mood)

func _to_string() -> String:
	var tex_info = "no texture" if texture == null else "has texture"
	return "MoodTexture(%s, %s)" % [get_mood_name(), tex_info]
