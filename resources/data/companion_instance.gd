# res://resources/data/companion_instance.gd
# Persistent runtime state for an NPC companion.
# Summons don't use this — they're combat-scoped and ephemeral.
extends Resource
class_name CompanionInstance

## The template defining this companion's behavior.
@export var companion_data: CompanionData = null

## Current HP — persists between combats for NPC companions.
@export var current_hp: int = -1  # -1 = uninitialized, will be set to max on first use

## Whether this companion is dead (persists until restored).
@export var is_dead: bool = false

## How this companion was recruited.
@export var recruitment_source: String = "story"  # "story", "quest", "hired"

## If true, this companion cannot be dismissed (e.g. story-critical NPC).
@export var is_permanent: bool = false

# ============================================================================
# METHODS
# ============================================================================

func initialize_hp(player_max_hp: int, player_level: int) -> void:
	"""Set HP to max if uninitialized. Called on first combat entry."""
	if current_hp < 0 and companion_data:
		current_hp = companion_data.calculate_max_hp(player_max_hp, player_level)

func get_max_hp(player_max_hp: int, player_level: int) -> int:
	"""Get calculated max HP."""
	if companion_data:
		return companion_data.calculate_max_hp(player_max_hp, player_level)
	return 1

func restore() -> void:
	"""Restore this companion to full HP (used by rest/consumables)."""
	is_dead = false
	current_hp = -1  # Will recalculate on next combat entry

func get_display_name() -> String:
	if companion_data:
		return companion_data.companion_name
	return "Unknown"
