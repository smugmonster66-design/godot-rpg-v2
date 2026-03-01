# res://resources/data/dialogue_speaker.gd
# Defines a character who can speak in dialogue.
# Contains display info, bust textures, and voice settings.
@tool
extends Resource
class_name DialogueSpeaker

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## Unique identifier for this speaker (e.g., "merchant_hilda", "guard_marcus")
@export var speaker_id: StringName = &""
## Display name shown in dialogue UI
@export var display_name: String = ""
## Localization key for display_name (if empty, uses display_name directly)
@export var name_key: String = ""
## Color for the speaker's name in the dialogue box
@export var name_color: Color = Color.WHITE

# ============================================================================
# BUST TEXTURES
# ============================================================================
@export_group("Busts")
## Default bust texture (used when no mood is specified or mood not found)
@export var bust_texture: Texture2D = null
## Mood-specific bust textures (expressions)
@export var mood_textures: Array[MoodTexture] = []

# ============================================================================
# VOICE
# ============================================================================
@export_group("Voice")
## Sound effect for voice blips during text reveal
@export var voice_blip: AudioStream = null
## Pitch variation for voice blips
@export var voice_pitch: float = 1.0
## How often to play blips (characters per blip)
@export var blip_frequency: int = 3

# ============================================================================
# BUST API
# ============================================================================

func get_display_name() -> String:
	"""Get the localized display name."""
	if name_key != "":
		# TODO: Hook into localization system
		# return tr(name_key)
		pass
	return display_name

func get_bust(mood_name: String = "") -> Texture2D:
	"""Get the bust texture for a given mood name, falling back to default."""
	# For base/default, try bust_texture first, then check mood_textures for BASE
	if mood_name == "" or mood_name == "base" or mood_name == "default":
		if bust_texture:
			return bust_texture
		# Fall back to BASE mood in mood_textures array
		for mood_tex in mood_textures:
			if mood_tex.mood == MoodTypes.Mood.BASE and mood_tex.texture:
				return mood_tex.texture
		return null
	
	# Search mood_textures array for the specified mood
	for mood_tex in mood_textures:
		if mood_tex.get_mood_name() == mood_name:
			if mood_tex.texture:
				return mood_tex.texture
	
	# Fall back to bust_texture or BASE mood
	if bust_texture:
		return bust_texture
	for mood_tex in mood_textures:
		if mood_tex.mood == MoodTypes.Mood.BASE and mood_tex.texture:
			return mood_tex.texture
	
	return null

func get_bust_for_mood(mood: MoodTypes.Mood) -> Texture2D:
	"""Get the bust texture for a given mood enum, falling back to default."""
	if mood == MoodTypes.Mood.BASE:
		if bust_texture:
			return bust_texture
		# Check mood_textures for BASE
		for mood_tex in mood_textures:
			if mood_tex.mood == MoodTypes.Mood.BASE and mood_tex.texture:
				return mood_tex.texture
		return null
	
	for mood_tex in mood_textures:
		if mood_tex.mood == mood:
			if mood_tex.texture:
				return mood_tex.texture
	
	# Fall back to bust_texture or BASE mood
	if bust_texture:
		return bust_texture
	for mood_tex in mood_textures:
		if mood_tex.mood == MoodTypes.Mood.BASE and mood_tex.texture:
			return mood_tex.texture
	return null

func has_mood(mood_name: String) -> bool:
	"""Check if this speaker has a specific mood texture."""
	if mood_name == "" or mood_name == "base" or mood_name == "default":
		if bust_texture != null:
			return true
		# Check mood_textures for BASE
		for mood_tex in mood_textures:
			if mood_tex.mood == MoodTypes.Mood.BASE and mood_tex.texture != null:
				return true
		return false
	
	for mood_tex in mood_textures:
		if mood_tex.get_mood_name() == mood_name and mood_tex.texture != null:
			return true
	return false

func get_available_busts() -> Array[String]:
	"""Get list of available bust/mood names."""
	var result: Array[String] = []
	
	# Check for base texture (either bust_texture or BASE mood in array)
	var has_base = bust_texture != null
	if not has_base:
		for mood_tex in mood_textures:
			if mood_tex.mood == MoodTypes.Mood.BASE and mood_tex.texture != null:
				has_base = true
				break
	
	if has_base:
		result.append("base")
	
	# Add all moods that have textures (except BASE which we already handled)
	for mood_tex in mood_textures:
		if mood_tex.texture != null and mood_tex.mood != MoodTypes.Mood.BASE:
			var name = mood_tex.get_mood_name()
			if name not in result:
				result.append(name)
	
	return result

func get_available_moods() -> Array[StringName]:
	"""Get list of available mood names (legacy API compatibility)."""
	var result: Array[StringName] = []
	for mood_tex in mood_textures:
		if mood_tex.texture != null:
			result.append(StringName(mood_tex.get_mood_name()))
	return result

# ============================================================================
# MIGRATION HELPER
# ============================================================================

func migrate_from_dictionary(old_mood_dict: Dictionary) -> void:
	"""Helper to migrate from old Dictionary format to new Array[MoodTexture]."""
	mood_textures.clear()
	for key in old_mood_dict:
		var mood_tex = MoodTexture.new()
		mood_tex.mood = MoodTypes.string_to_mood(str(key))
		mood_tex.texture = old_mood_dict[key]
		mood_textures.append(mood_tex)
	print("[DialogueSpeaker] Migrated %d mood textures" % mood_textures.size())
