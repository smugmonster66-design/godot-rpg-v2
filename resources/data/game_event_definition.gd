# res://resources/data/game_event_definition.gd
# A named game event with optional auto-applied effects.
# Organized in res://resources/events/ by category subfolders.
extends Resource
class_name GameEventDefinition

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## Unique identifier for this event. Used as the lookup key in GameEventRegistry.
@export var event_id: StringName = &""
## Human-readable name shown in dropdowns and debug output.
@export var display_name: String = ""
## Optional description for documentation / tooltips.
@export var description: String = ""

# ============================================================================
# EFFECTS
# ============================================================================
@export_group("Effects")
## Optional effects auto-applied when this event fires.
## Leave empty for signal-only events handled by code listeners.
@export var effects: Array[GameEventEffect] = []

# ============================================================================
# API
# ============================================================================

func apply_effects() -> void:
	"""Execute all effects in order."""
	for effect in effects:
		if effect:
			effect.apply()
