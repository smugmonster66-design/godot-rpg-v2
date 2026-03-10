# res://resources/data/dice_mutation.gd
# Enum-only class defining the types of mutations that can be recorded
# against a hand die. Used by PlayerDiceCollection._pending_dice_mutations
# and consumed by CombatManager._flush_dice_mutations.
extends RefCounted
class_name DiceMutation

enum Type {
	VALUE_CHANGED,    # Flat or conditional modifier applied — carries delta + new_value
	LOCKED,           # die.is_locked = true
	CONSUMED,         # die.is_consumed = true (by a status, not a player action)
	ELEMENT_CHANGED,  # die.element mutated
	TAG_ADDED,
	TAG_REMOVED,
}
