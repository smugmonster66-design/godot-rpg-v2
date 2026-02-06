# res://resources/data/combat_modifier.gd
# Persistent modifier that lasts across turns within a single combat.
# Created by ON_COMBAT_START affixes (e.g., Vanguard) or special effects
# (e.g., Sacrifice's "all others +50% for rest of combat").
#
# PlayerDiceCollection stores an array of these and reapplies them
# each time roll_hand() creates fresh hand copies.
extends Resource
class_name CombatModifier

# ============================================================================
# ENUMS
# ============================================================================

## How long does this modifier last?
enum Duration {
	COMBAT,          ## Entire combat (cleared on combat end)
	TURNS,           ## Fixed number of turns (decremented each turn)
}

## What type of modification does this apply?
enum ModType {
	FLAT_BONUS,          ## Add flat value to dice
	PERCENT_BONUS,       ## Multiply dice value
	MIN_VALUE_BONUS,     ## Raise minimum roll value
	MAX_VALUE_BONUS,     ## Cap maximum roll value
	GRANT_REROLL,        ## Grant reroll ability
	ADD_TAG,             ## Add a tag to affected dice
}

## Which dice does this modifier affect?
enum TargetFilter {
	ALL_DICE,            ## Every die in hand
	ALL_EXCEPT_SOURCE,   ## All dice except the one that created this modifier
	DICE_RIGHT_OF,       ## All dice to the right of source_slot_index
	DICE_LEFT_OF,        ## All dice to the left of source_slot_index
	SPECIFIC_SLOT,       ## Only the die at source_slot_index
	DICE_WITH_TAG,       ## Only dice that have filter_tag
	DICE_WITHOUT_TAG,    ## Only dice that don't have filter_tag
}

# ============================================================================
# INSPECTOR CONFIGURATION
# ============================================================================

@export_group("Modifier")
## The type of modification to apply each turn.
@export var mod_type: ModType = ModType.FLAT_BONUS

## Numeric value for the modifier (flat bonus amount, percent, min value, etc.)
@export var value: float = 0.0

## Tag to add (only used with ModType.ADD_TAG)
@export var tag: String = ""

@export_group("Duration")
## How long this modifier persists.
@export var duration: Duration = Duration.COMBAT

## Number of turns remaining (only used when duration == TURNS).
## Decremented at end of each turn. Removed when it reaches 0.
@export var turns_remaining: int = 0

@export_group("Targeting")
## Which dice are affected by this modifier.
@export var target_filter: TargetFilter = TargetFilter.ALL_DICE

## The pool slot index of the die that created this modifier.
## Used by DICE_RIGHT_OF, DICE_LEFT_OF, ALL_EXCEPT_SOURCE, and SPECIFIC_SLOT.
@export var source_slot_index: int = 0

## Tag filter (only used with DICE_WITH_TAG / DICE_WITHOUT_TAG).
@export var filter_tag: String = ""

@export_group("Source Tracking")
## Name of the affix/die that created this modifier (for display/debug).
@export var source_name: String = ""

# ============================================================================
# APPLICATION
# ============================================================================

func applies_to_die(die, die_index: int) -> bool:
	"""Check if this modifier should affect the given die at the given index."""
	match target_filter:
		TargetFilter.ALL_DICE:
			return true
		TargetFilter.ALL_EXCEPT_SOURCE:
			return die.slot_index != source_slot_index
		TargetFilter.DICE_RIGHT_OF:
			return die_index > source_slot_index
		TargetFilter.DICE_LEFT_OF:
			return die_index < source_slot_index
		TargetFilter.SPECIFIC_SLOT:
			return die_index == source_slot_index
		TargetFilter.DICE_WITH_TAG:
			return die.has_tag(filter_tag)
		TargetFilter.DICE_WITHOUT_TAG:
			return not die.has_tag(filter_tag)
	return false

func apply_to_die(die) -> void:
	"""Apply this modifier's effect to a single die."""
	match mod_type:
		ModType.FLAT_BONUS:
			die.apply_flat_modifier(value)
		ModType.PERCENT_BONUS:
			die.apply_percent_modifier(value)
		ModType.MIN_VALUE_BONUS:
			die.set_minimum_value(int(value))
		ModType.MAX_VALUE_BONUS:
			die.set_maximum_value(int(value))
		ModType.GRANT_REROLL:
			die.can_reroll = true
		ModType.ADD_TAG:
			if tag:
				die.add_tag(tag)

# ============================================================================
# TURN MANAGEMENT
# ============================================================================

func tick_turn() -> bool:
	"""Called at end of turn. Returns true if this modifier should be removed."""
	if duration == Duration.COMBAT:
		return false  # Never expires from turn ticking
	
	turns_remaining -= 1
	return turns_remaining <= 0

func is_expired() -> bool:
	"""Check if this modifier has expired."""
	if duration == Duration.COMBAT:
		return false
	return turns_remaining <= 0

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	return {
		"mod_type": mod_type,
		"value": value,
		"tag": tag,
		"duration": duration,
		"turns_remaining": turns_remaining,
		"target_filter": target_filter,
		"source_slot_index": source_slot_index,
		"filter_tag": filter_tag,
		"source_name": source_name,
	}

static func from_dict(data: Dictionary) -> CombatModifier:
	var mod = CombatModifier.new()
	mod.mod_type = data.get("mod_type", ModType.FLAT_BONUS)
	mod.value = data.get("value", 0.0)
	mod.tag = data.get("tag", "")
	mod.duration = data.get("duration", Duration.COMBAT)
	mod.turns_remaining = data.get("turns_remaining", 0)
	mod.target_filter = data.get("target_filter", TargetFilter.ALL_DICE)
	mod.source_slot_index = data.get("source_slot_index", 0)
	mod.filter_tag = data.get("filter_tag", "")
	mod.source_name = data.get("source_name", "")
	return mod

func _to_string() -> String:
	return "CombatModifier<%s: %s %.1f from %s>" % [
		ModType.keys()[mod_type], TargetFilter.keys()[target_filter],
		value, source_name
	]
