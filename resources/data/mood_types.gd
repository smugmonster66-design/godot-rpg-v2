# res://resources/data/mood_types.gd
# Global mood definitions for character bust expressions.
# Add new moods here as needed - they'll appear in all MoodTexture dropdowns.
class_name MoodTypes
extends RefCounted

enum Mood {
	BASE,           # Default/neutral expression
	AMUSED,         # Light smile, entertained
	ANGRY,          # Frustrated, upset
	LAUGHING,       # Full laugh, joyful
	FROWNING,       # Disapproval, concern
	SAD,            # Melancholy, disappointed
	SURPRISED,      # Shocked, startled
	WORRIED,        # Anxious, nervous
	SMUG,           # Self-satisfied, knowing
	EMBARRASSED,    # Flustered, shy
	DETERMINED,     # Focused, resolute
	TIRED,          # Exhausted, weary
	SKEPTICAL,      # Doubtful, questioning
	EXCITED,        # Eager, enthusiastic
	AFRAID,         # Scared, fearful
	DISGUSTED,      # Revulsion, distaste
	THOUGHTFUL,     # Pondering, contemplative
	PLEADING,       # Begging, desperate
	STERN,          # Serious, authoritative
	SLY,            # Cunning, mischievous
}

# String names for serialization and lookup
const MOOD_NAMES: Array[String] = [
	"base",
	"amused", 
	"angry",
	"laughing",
	"frowning",
	"sad",
	"surprised",
	"worried",
	"smug",
	"embarrassed",
	"determined",
	"tired",
	"skeptical",
	"excited",
	"afraid",
	"disgusted",
	"thoughtful",
	"pleading",
	"stern",
	"sly",
]

static func mood_to_string(mood: Mood) -> String:
	if mood >= 0 and mood < MOOD_NAMES.size():
		return MOOD_NAMES[mood]
	return "base"

static func string_to_mood(mood_name: String) -> Mood:
	var idx = MOOD_NAMES.find(mood_name.to_lower())
	if idx >= 0:
		return idx as Mood
	return Mood.BASE

static func get_mood_display_name(mood: Mood) -> String:
	"""Get a nicely formatted display name for UI."""
	return mood_to_string(mood).capitalize()
