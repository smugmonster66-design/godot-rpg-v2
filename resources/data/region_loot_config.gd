# region_loot_config.gd — Master loot configuration for a region
#
# Wires together:
#   - 5 EnemyTierLootConfigs (one per tier)
#   - 1 shared item pool (all region items, slot-weighted)
#   - 3 archetype bonus pools (STR/AGI/INT filtered subsets)
#   - 1 world legendary pool (hand-curated legendaries)
#
# LootManager.roll_loot_from_combat() reads this to drive the full
# combat loot flow. Every field is @export for Inspector tuning.
#
extends Resource
class_name RegionLootConfig

# ============================================================================
# REGION IDENTITY
# ============================================================================

@export var region_name: String = "Region 1"
@export var region_number: int = 1

# ============================================================================
# TIER CONFIGURATIONS — One per enemy tier, all Inspector-editable
# ============================================================================
@export_group("Enemy Tier Configs")

@export var trash_config: EnemyTierLootConfig
@export var elite_config: EnemyTierLootConfig
@export var mini_boss_config: EnemyTierLootConfig
@export var boss_config: EnemyTierLootConfig
@export var world_boss_config: EnemyTierLootConfig

# ============================================================================
# ITEM POOLS
# ============================================================================
@export_group("Item Pools")

## The shared pool containing all region items with slot-based weights.
## All enemies roll from this pool for their primary equipment drops.
@export var shared_item_pool: LootTable

## Archetype-filtered pools. Enemies with a matching archetype get a
## bonus roll from their stat pool (chance controlled by tier config).
@export var str_bonus_pool: LootTable
@export var agi_bonus_pool: LootTable
@export var int_bonus_pool: LootTable

## Hand-curated legendary pool. Any enemy can trigger this (chance
## controlled by tier config). Items always drop at Legendary rarity.
@export var world_legendary_pool: LootTable

# ============================================================================
# PUBLIC API
# ============================================================================

func get_tier_config(tier: EnemyTierLootConfig.EnemyTier) -> EnemyTierLootConfig:
	"""Get the config for a specific enemy tier."""
	match tier:
		EnemyTierLootConfig.EnemyTier.TRASH: return trash_config
		EnemyTierLootConfig.EnemyTier.ELITE: return elite_config
		EnemyTierLootConfig.EnemyTier.MINI_BOSS: return mini_boss_config
		EnemyTierLootConfig.EnemyTier.BOSS: return boss_config
		EnemyTierLootConfig.EnemyTier.WORLD_BOSS: return world_boss_config
	push_warning("RegionLootConfig: Unknown tier %d" % tier)
	return trash_config


func get_archetype_pool(archetype: EnemyTierLootConfig.Archetype) -> LootTable:
	"""Get the bonus pool for a stat archetype."""
	match archetype:
		EnemyTierLootConfig.Archetype.STR: return str_bonus_pool
		EnemyTierLootConfig.Archetype.AGI: return agi_bonus_pool
		EnemyTierLootConfig.Archetype.INT: return int_bonus_pool
	return null
