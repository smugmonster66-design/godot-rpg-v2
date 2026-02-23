# res://resources/data/run_affix_entry.gd
## A single run affix that can be offered to the player during a dungeon run.
## Wraps either a DiceAffix (die-level), an Affix (stat-level), or both.
## Lives in DungeonDefinition.run_affix_pool arrays.
##
## Application flow:
##   DICE   → DungeonScene._apply_temp_affix(dice_affix)   → stamps "dungeon_temp"
##   STAT   → player.affix_manager.add_affix(stat_affix)   → tracked in run
##   HYBRID → both of the above
##
## Cleaned up automatically by DungeonScene._cleanup_temp_effects() on run end.
extends Resource
class_name RunAffixEntry

# ============================================================================
# ENUMS
# ============================================================================

enum AffixType {
	DICE,       ## Applied to all dice via _apply_temp_affix()
	STAT,       ## Applied to player via affix_manager
	HYBRID,     ## Both dice and stat effects
}

enum Rarity {
	COMMON,     ## Appears frequently in offers
	UNCOMMON,   ## Moderate appearance rate
	RARE,       ## Seldom offered, powerful effects
}

# ============================================================================
# IDENTITY
# ============================================================================
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var affix_id: String = ""

# ============================================================================
# TYPE & EFFECTS
# ============================================================================
@export_group("Effect")
@export var affix_type: AffixType = AffixType.DICE
@export var rarity: Rarity = Rarity.COMMON

## DiceAffix applied to all player dice (null if affix_type == STAT)
@export var dice_affix: DiceAffix = null

## Stat Affix applied to player affix_manager (null if affix_type == DICE)
@export var stat_affix: Affix = null

# ============================================================================
# OFFER RULES
# ============================================================================
@export_group("Offer Rules")

## Tags for filtering and mutual exclusion (e.g., "fire", "offense", "defense")
@export var tags: Array[String] = []

## If the player already has a run affix with any of these tags, skip this one
@export var mutually_exclusive_tags: Array[String] = []

## How many times this can be picked in a single run (1 = unique)
@export_range(1, 5) var max_stacks: int = 1

## Offer weight — higher = more likely to appear. Rarity also affects weight.
@export_range(1, 100) var offer_weight: int = 10

# ============================================================================
# RARITY COLORS
# ============================================================================

static var RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.7, 0.7, 0.7),
	Rarity.UNCOMMON: Color(0.3, 0.8, 0.3),
	Rarity.RARE: Color(0.4, 0.6, 1.0),
}

# ============================================================================
# HELPERS
# ============================================================================

func get_rarity_name() -> String:
	return Rarity.keys()[rarity].capitalize()

func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

func get_effective_weight() -> int:
	## Common = full weight, Uncommon = 60%, Rare = 30%
	match rarity:
		Rarity.COMMON: return offer_weight
		Rarity.UNCOMMON: return int(offer_weight * 0.6)
		Rarity.RARE: return int(offer_weight * 0.3)
	return offer_weight

func has_tag(tag: String) -> bool:
	return tag in tags

## Accepts untyped Array to prevent silent abort when caller builds
## tags list dynamically (Godot 4.x typed array mismatch safety).
func has_any_exclusive_tag(active_tags: Array) -> bool:
	for tag in mutually_exclusive_tags:
		if tag in active_tags:
			return true
	return false

func get_display_text() -> String:
	if description != "":
		return description
	var parts := []
	if dice_affix and dice_affix.display_name != "":
		parts.append(dice_affix.display_name)
	if stat_affix and stat_affix.affix_name != "":
		parts.append(stat_affix.affix_name)
	return " + ".join(parts) if parts.size() > 0 else display_name

func validate() -> Array[String]:
	var warnings: Array[String] = []
	if display_name == "":
		warnings.append("Missing display_name")
	if affix_id == "":
		warnings.append("Missing affix_id")
	if affix_type == AffixType.DICE and not dice_affix:
		warnings.append("DICE type but no dice_affix assigned")
	if affix_type == AffixType.STAT and not stat_affix:
		warnings.append("STAT type but no stat_affix assigned")
	if affix_type == AffixType.HYBRID and (not dice_affix or not stat_affix):
		warnings.append("HYBRID type requires both dice_affix and stat_affix")
	return warnings
