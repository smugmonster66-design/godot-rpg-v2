# res://resources/data/companion_instance.gd
# Persistent runtime state for an NPC companion (saved with the game).
# Summons don't use this — they're combat-scoped and ephemeral.
extends Resource
class_name CompanionInstance

## The template defining this companion's behavior.
@export var companion_data: CompanionData = null

## Current HP — persists between combats for NPC companions.
@export var current_hp: int = -1  # -1 = uninitialized, will be set to max on first use

## Downed (0 HP). Companions are never killed by combat: a downed companion
## sits out fights until a rest, a revive consumable, a Mender or the
## shellkeeper rescue brings them back. (Named is_dead for old saves.)
@export var is_dead: bool = false

## Revived mid-fight (not by resting): reduced max HP until the next proper rest.
@export var is_wounded: bool = false

## The personal quest's ending upgraded them (bond die becomes the top die).
@export var bond_upgraded: bool = false

## How this companion was recruited.
@export var recruitment_source: String = "story"  # "story", "quest", "hired"

## If true, this companion cannot be dismissed (e.g. story-critical NPC).
@export var is_permanent: bool = false

# ============================================================================
# METHODS
# ============================================================================

func is_downed() -> bool:
	return is_dead

func get_companion_id() -> StringName:
	return companion_data.companion_id if companion_data else &""

func initialize_hp(player_max_hp: int, player_level: int) -> void:
	"""Set HP to max if uninitialized. Called on first combat entry."""
	if current_hp < 0 and companion_data:
		current_hp = get_max_hp(player_max_hp, player_level)

func get_full_max_hp(player_max_hp: int, player_level: int) -> int:
	"""Max HP ignoring Wounded."""
	if companion_data:
		return companion_data.calculate_max_hp(player_max_hp, player_level)
	return 1

func get_max_hp(player_max_hp: int, player_level: int) -> int:
	"""Calculated max HP (reduced while Wounded)."""
	var full := get_full_max_hp(player_max_hp, player_level)
	if is_wounded:
		return maxi(1, roundi(full * CompanionBondRules.get_rules().wounded_max_hp_percent))
	return full

func restore() -> void:
	"""Restore this companion to full HP (used by rest/consumables)."""
	is_dead = false
	current_hp = -1  # Will recalculate on next combat entry

func get_display_name() -> String:
	if companion_data:
		return companion_data.companion_name
	return "Unknown"
