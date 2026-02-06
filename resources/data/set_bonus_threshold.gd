# res://resources/data/set_bonus_threshold.gd
# Defines a single bonus tier within an equipment set.
# Each threshold activates when the player equips enough pieces.
# Bonuses are expressed as Affix and DiceAffix resources, reusing existing systems.
extends Resource
class_name SetBonusThreshold

# ============================================================================
# THRESHOLD CONFIGURATION
# ============================================================================

## How many set pieces must be equipped to activate this bonus
@export var required_pieces: int = 2

## Human-readable description for tooltips (e.g., "+2 Ice Damage")
@export_multiline var description: String = ""

# ============================================================================
# BONUS EFFECTS - Item-level Affixes
# ============================================================================
@export_group("Item Affixes")

## Standard Affix resources that get registered with AffixPoolManager.
## These work exactly like equipment affixes: stat bonuses, damage mods,
## granted actions, resistances, etc.
@export var affixes: Array[Affix] = []

# ============================================================================
# BONUS EFFECTS - Dice-level Affixes
# ============================================================================
@export_group("Dice Affixes")

## DiceAffix resources applied to dice granted by set items ONLY.
## These trigger during combat: ON_ROLL, ON_USE, PASSIVE, etc.
## They do NOT apply to non-set dice in the player's pool.
@export var dice_affixes: Array[DiceAffix] = []

# ============================================================================
# UTILITY
# ============================================================================

func has_any_bonus() -> bool:
	"""Check if this threshold actually grants anything"""
	return affixes.size() > 0 or dice_affixes.size() > 0

func get_summary() -> String:
	"""Get a formatted summary string for UI"""
	if description != "":
		return "(%d) %s" % [required_pieces, description]
	
	var parts: Array[String] = []
	for affix in affixes:
		parts.append(affix.affix_name)
	for dice_affix in dice_affixes:
		parts.append(dice_affix.affix_name)
	
	if parts.is_empty():
		return "(%d) No effect" % required_pieces
	
	return "(%d) %s" % [required_pieces, ", ".join(parts)]
