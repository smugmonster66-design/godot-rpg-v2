# enemy_tier_loot_config.gd — Per-tier loot tuning knobs
#
# One resource per enemy tier (Trash, Elite, Mini-Boss, Boss, World Boss).
# Every value is @export for full Inspector control.
#
# Used by RegionLootConfig + LootManager.roll_loot_from_combat().
#
extends Resource
class_name EnemyTierLootConfig

# ============================================================================
# ENUMS
# ============================================================================

enum EnemyTier {
	TRASH,
	ELITE,
	MINI_BOSS,
	BOSS,
	WORLD_BOSS,
}

enum Archetype {
	NONE,
	STR,
	AGI,
	INT,
}

# ============================================================================
# TIER IDENTITY
# ============================================================================

@export var tier_name: String = "Trash"
@export var tier: EnemyTier = EnemyTier.TRASH

# ============================================================================
# RARITY WEIGHTS — Higher = more likely. Set to 0 to disable a rarity.
# ============================================================================
@export_group("Rarity Weights")

## Weight for Common drops (0 rolled affixes).
@export_range(0, 1000) var common_weight: int = 50

## Weight for Uncommon drops (1 rolled affix).
@export_range(0, 1000) var uncommon_weight: int = 35

## Weight for Rare drops (2 rolled affixes).
@export_range(0, 1000) var rare_weight: int = 12

## Weight for Epic drops (3 rolled affixes).
@export_range(0, 1000) var epic_weight: int = 3

# ============================================================================
# EQUIPMENT DROP COUNT
# ============================================================================
@export_group("Equipment Drops")

## Minimum equipment items dropped per combat.
@export_range(0, 5) var drop_count_min: int = 0

## Maximum equipment items dropped per combat.
@export_range(0, 5) var drop_count_max: int = 1

## Weight for dropping nothing (competes with drop_count_min=0).
## Only relevant when drop_count_min is 0. Higher = more "nothing" results.
## Set to 0 to guarantee at least 1 drop.
@export_range(0, 1000) var nothing_weight: int = 60

# ============================================================================
# ARCHETYPE BONUS
# ============================================================================
@export_group("Archetype Bonus")

## Chance (0.0–1.0) that an archetype-matching enemy rolls a bonus item
## from the stat-filtered pool (in addition to normal drops).
@export_range(0.0, 1.0) var archetype_bonus_chance: float = 0.0

# ============================================================================
# WORLD LEGENDARY
# ============================================================================
@export_group("World Legendary")

## Chance (0.0–1.0) to roll from the world legendary table.
## Hit = one item from the legendary pool at Legendary rarity.
@export_range(0.0, 1.0) var world_legendary_chance: float = 0.0

# ============================================================================
# CURRENCY
# ============================================================================
@export_group("Currency")

## Gold range for this tier. Always dropped.
@export var currency_min: int = 5
@export var currency_max: int = 15

# ============================================================================
# PUBLIC API
# ============================================================================

func roll_rarity() -> int:
	"""Weighted random rarity selection from this tier's weights.
	
	Returns:
		EquippableItem.Rarity enum value (0=Common through 3=Epic).
	"""
	var total: int = common_weight + uncommon_weight + rare_weight + epic_weight
	if total <= 0:
		return EquippableItem.Rarity.COMMON
	
	var roll: int = randi_range(0, total - 1)
	
	if roll < common_weight:
		return EquippableItem.Rarity.COMMON
	roll -= common_weight
	
	if roll < uncommon_weight:
		return EquippableItem.Rarity.UNCOMMON
	roll -= uncommon_weight
	
	if roll < rare_weight:
		return EquippableItem.Rarity.RARE
	
	return EquippableItem.Rarity.EPIC


func roll_drop_count() -> int:
	"""Roll how many equipment items this tier drops.
	
	When drop_count_min is 0, nothing_weight competes with the chance
	of getting at least 1 item. When drop_count_min >= 1, nothing_weight
	is ignored.
	
	Returns:
		Number of equipment drops (0 to drop_count_max).
	"""
	if drop_count_min >= 1:
		# Always drops something
		if drop_count_min == drop_count_max:
			return drop_count_min
		return randi_range(drop_count_min, drop_count_max)
	
	# drop_count_min is 0 — compete with nothing_weight
	# Effective: nothing_weight vs (total - nothing_weight) for getting 1+
	var something_weight: int = 100  # Base chance of getting something
	var total: int = nothing_weight + something_weight
	if randi_range(0, total - 1) < nothing_weight:
		return 0
	
	# We're getting something — roll count from 1 to max
	if drop_count_max <= 1:
		return 1
	return randi_range(1, drop_count_max)


func roll_currency() -> int:
	"""Roll gold amount for this tier."""
	if currency_min == currency_max:
		return currency_min
	return randi_range(currency_min, currency_max)


func should_roll_archetype_bonus() -> bool:
	"""Check if the archetype bonus triggers."""
	return archetype_bonus_chance > 0.0 and randf() < archetype_bonus_chance


func should_roll_world_legendary() -> bool:
	"""Check if the world legendary triggers."""
	return world_legendary_chance > 0.0 and randf() < world_legendary_chance
