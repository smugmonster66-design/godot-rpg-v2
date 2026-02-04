# loot_table.gd - Defines a loot table with multiple pools
extends Resource
class_name LootTable

# ============================================================================
# BASIC INFO
# ============================================================================
@export var table_name: String = "New Loot Table"
@export_multiline var description: String = "Describe what this loot table is for"

# ============================================================================
# GUARANTEED DROPS POOL
# ============================================================================
@export_group("Guaranteed Drops")
@export var guaranteed_drops: Array[LootDrop] = []

# ============================================================================
# WEIGHTED DROPS POOL
# ============================================================================
@export_group("Weighted Drops")
@export var weighted_drops: Array[LootDrop] = []

# How many items to roll from weighted pool
@export var num_weighted_rolls_min: int = 1
@export var num_weighted_rolls_max: int = 1

# ============================================================================
# BONUS DROPS POOL
# ============================================================================
@export_group("Bonus Drops")
@export var bonus_drops: Array[LootDrop] = []

# Flat % chance to roll from bonus pool (0.0 to 1.0)
@export_range(0.0, 1.0) var bonus_drop_chance: float = 0.10

# ============================================================================
# UTILITY
# ============================================================================

func get_num_weighted_rolls() -> int:
	"""Get random number of weighted rolls within range"""
	if num_weighted_rolls_min == num_weighted_rolls_max:
		return num_weighted_rolls_min
	return randi_range(num_weighted_rolls_min, num_weighted_rolls_max)

func get_total_weight() -> int:
	"""Calculate total weight of all weighted drops"""
	var total = 0
	for drop in weighted_drops:
		if drop.is_valid():
			total += drop.drop_weight
	return total

func get_valid_drops(pool: Array[LootDrop]) -> Array[LootDrop]:
	"""Filter out invalid drops from a pool"""
	var valid: Array[LootDrop] = []
	for drop in pool:
		if drop and drop.is_valid():
			valid.append(drop)
	return valid
