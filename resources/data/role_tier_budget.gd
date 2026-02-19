# res://resources/data/role_tier_budget.gd
# Per-tier mechanical budget for an enemy combat role.
#
# Defines the "complexity allowance" at each tier: how many dice,
# how large, how many actions, etc. An EnemyTemplate holds one of
# these per tier (trash through world_boss), and EnemyData instances
# built from that template use these values as defaults.
#
# All values are GUIDELINES for generators and designers. Individual
# EnemyData resources can override anything by setting their own values.
#
extends Resource
class_name RoleTierBudget

# ============================================================================
# DICE BUDGET
# ============================================================================
@export_group("Dice Budget")

## Minimum dice in this enemy's starting pool at this tier.
@export_range(1, 8) var dice_count_min: int = 1

## Maximum dice in this enemy's starting pool at this tier.
@export_range(1, 8) var dice_count_max: int = 2

## Smallest die size the role uses at this tier.
## Enum values: D4=4, D6=6, D8=8, D10=10, D12=12, D20=20
@export var die_size_floor: DieResource.DieType = DieResource.DieType.D4

## Largest die size the role uses at this tier.
@export var die_size_ceiling: DieResource.DieType = DieResource.DieType.D6

## If true, this tier can include elemental dice in its pool.
@export var allow_elemental_dice: bool = false

## Preferred elements for elemental dice (empty = any).
## Only relevant when allow_elemental_dice is true.
@export var preferred_elements: Array[DieResource.Element] = []

# ============================================================================
# ACTION BUDGET
# ============================================================================
@export_group("Action Budget")

## Number of combat actions this enemy gets at this tier.
@export_range(1, 6) var action_count: int = 1

## How many actions can require 2+ dice to activate.
## Keeps trash simple (0) while bosses get multi-die combos.
@export_range(0, 4) var multi_die_action_budget: int = 0

## How many actions can apply status effects or have proc-style mechanics.
## The "special trick" allowance. Trash = 0, Elite = 1, Boss = 2-3.
@export_range(0, 4) var special_mechanic_budget: int = 0

# ============================================================================
# STAT SCALING
# ============================================================================
@export_group("Stat Scaling")

## Multiplier on the template's health_weight at this tier.
## 1.0 = template default. Trash might be 0.7, Boss might be 2.5.
@export_range(0.3, 5.0, 0.05) var health_scale: float = 1.0

## Multiplier on the template's defense weights at this tier.
@export_range(0.3, 5.0, 0.05) var defense_scale: float = 1.0

## Level scaling multiplier (flows to EnemyData.level_scaling_multiplier).
## How hard this enemy's affixes scale relative to player level.
## 0.85 = 85% of player level, 1.0 = equal, 1.2 = overleveled.
@export_range(0.5, 2.0, 0.05) var level_scaling: float = 0.85

# ============================================================================
# AI OVERRIDE
# ============================================================================
@export_group("AI Tuning")

## If true, the tier overrides the template's default AI strategy.
## Useful for making trash versions of a Caster role use RANDOM instead
## of the BALANCED the role normally prefers.
@export var override_ai_strategy: bool = false
@export var ai_strategy_override: EnemyData.AIStrategy = EnemyData.AIStrategy.RANDOM

# ============================================================================
# TIMING
# ============================================================================
@export_group("Timing")

## Action delay in seconds. Trash is snappy, bosses are deliberate.
@export_range(0.3, 2.0, 0.1) var action_delay: float = 0.8

## Dice drag animation duration. Faster for trash, slower for bosses.
@export_range(0.2, 1.0, 0.1) var dice_drag_duration: float = 0.4

# ============================================================================
# HELPERS
# ============================================================================

func get_dice_count() -> int:
	"""Roll a dice count within the budget range."""
	if dice_count_min == dice_count_max:
		return dice_count_min
	return randi_range(dice_count_min, dice_count_max)


func get_die_sizes_available() -> Array[DieResource.DieType]:
	"""Return all valid die sizes between floor and ceiling."""
	var sizes: Array[DieResource.DieType] = []
	for size_val in [4, 6, 8, 10, 12, 20]:
		if size_val >= die_size_floor and size_val <= die_size_ceiling:
			sizes.append(size_val as DieResource.DieType)
	return sizes


func get_effective_ai_strategy(template_default: EnemyData.AIStrategy) -> EnemyData.AIStrategy:
	"""Return the AI strategy, respecting tier overrides."""
	if override_ai_strategy:
		return ai_strategy_override
	return template_default
