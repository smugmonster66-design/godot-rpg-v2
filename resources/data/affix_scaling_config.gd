# res://resources/data/affix_scaling_config.gd
# Global configuration for affix value scaling across all regions.
#
# The scaling curve maps item_level (normalized 0.0–1.0) to a power position
# within each affix's effect_min → effect_max range. Region definitions
# determine which level range maps to each zone, creating implicit power
# bands without requiring per-region affix files.
#
# USAGE:
#   var config = preload("res://resources/scaling/affix_scaling_config.tres")
#   var t = config.get_power_position(item_level)
#   var value = affix.roll_value(t)
#
extends Resource
class_name AffixScalingConfig

# ============================================================================
# GLOBAL SCALING CURVE
# ============================================================================

@export_group("Global Scaling")

## The master curve that maps normalized level (0.0–1.0) to power position.
## - Linear: even scaling throughout the game
## - Front-loaded: early levels feel more rewarding
## - Back-loaded: endgame ramp feels significant
## - S-curve: plateau in mid-game, power spikes at region transitions
@export var global_scaling_curve: Curve = null

## Maximum item level in the game. All level normalization uses this.
@export var max_item_level: int = 100

## Minimum absolute fuzz applied to integer-scale affixes.
## Prevents low-level affixes from always rounding to the same value.
## Example: center=2, fuzz_pct=0.2 → range would be 1.6–2.4 (rounds to 2).
## With min_absolute_fuzz=1 → range becomes 1–3 instead.
@export var min_absolute_fuzz: float = 1.0

## Default percentage fuzz (±%) applied around the level-determined center.
## 0.0 = deterministic, 0.2 = ±20% (recommended), 1.0 = fully random.
## Individual affixes can override this via their own roll_fuzz property.
@export_range(0.0, 1.0) var default_fuzz_percent: float = 0.2

# ============================================================================
# REGION DEFINITIONS
# ============================================================================

@export_group("Region Level Bounds")

## Each region defines a min/max level range. Overlapping ranges create
## smooth power transitions between zones. Format: [min_level, max_level]
##
## Example with 6 regions:
##   Region 1: 1–18   (Forest/Plains)
##   Region 2: 15–35  (Sunken Marches)
##   Region 3: 30–52  (Bronze City)
##   Region 4: 48–68
##   Region 5: 65–85
##   Region 6: 80–100

@export var region_1_min_level: int = 1
@export var region_1_max_level: int = 18

@export var region_2_min_level: int = 15
@export var region_2_max_level: int = 35

@export var region_3_min_level: int = 30
@export var region_3_max_level: int = 52

@export var region_4_min_level: int = 48
@export var region_4_max_level: int = 68

@export var region_5_min_level: int = 65
@export var region_5_max_level: int = 85

@export var region_6_min_level: int = 80
@export var region_6_max_level: int = 100

# ============================================================================
# PUBLIC API
# ============================================================================

func get_power_position(item_level: int) -> float:
	"""Convert an item_level to a 0.0–1.0 power position using the global curve.
	
	This is the primary entry point for the scaling system. The returned value
	represents where in an affix's effect_min→effect_max range the center
	should land before fuzz is applied.
	
	Args:
		item_level: The item's level (1 to max_item_level).
	
	Returns:
		Power position from 0.0 (weakest) to 1.0 (strongest).
	"""
	var t_normalized: float = clampf(
		float(item_level - 1) / float(max(max_item_level - 1, 1)),
		0.0, 1.0
	)
	
	if global_scaling_curve:
		return global_scaling_curve.sample(t_normalized)
	
	return t_normalized  # Linear fallback


func get_region_level_range(region: int) -> Dictionary:
	"""Get the min/max level bounds for a region.
	
	Args:
		region: Region number (1–6).
	
	Returns:
		Dictionary with "min" and "max" keys.
	"""
	match region:
		1: return {"min": region_1_min_level, "max": region_1_max_level}
		2: return {"min": region_2_min_level, "max": region_2_max_level}
		3: return {"min": region_3_min_level, "max": region_3_max_level}
		4: return {"min": region_4_min_level, "max": region_4_max_level}
		5: return {"min": region_5_min_level, "max": region_5_max_level}
		6: return {"min": region_6_min_level, "max": region_6_max_level}
		_:
			push_warning("AffixScalingConfig: Invalid region %d, defaulting to full range" % region)
			return {"min": 1, "max": max_item_level}


func get_item_level_for_region(region: int, difficulty_bias: float = 0.5) -> int:
	"""Generate an item level appropriate for a region.
	
	Args:
		region: Region number (1–6).
		difficulty_bias: 0.0 = easiest encounters in region, 1.0 = hardest.
	
	Returns:
		An item level within the region's bounds.
	"""
	var bounds = get_region_level_range(region)
	return int(lerpf(float(bounds.min), float(bounds.max), clampf(difficulty_bias, 0.0, 1.0)))


# ============================================================================
# ENEMY POWER SCALING
# ============================================================================

@export_group("Enemy Power Scaling")

## Curve mapping normalized player level (0.0–1.0) to expected player power
## as a fraction of max_expected_power. Derived from XP→encounters→loot→power
## progression chain. Shape in the editor; defaults to quadratic-ish ramp.
@export var expected_power_curve: Curve = null

## Expected total affix power at level 100 with good (not perfect) gear.
## Derived: 7 slots × EPIC items × ~200 power/slot at position 1.0 ≈ 1400.
@export var max_expected_power: float = 1400.0

## Expected power at level 1 with no gear. Prevents division by zero.
@export var min_expected_power: float = 10.0

@export_subgroup("Scaling Tuning")

## Power ratio below which enemy scaling starts decreasing (undergeared).
@export var power_dead_zone_low: float = 0.7

## Power ratio above which enemy scaling starts increasing (overgeared).
@export var power_dead_zone_high: float = 1.4

## Maximum scaling factor for overgeared players (enemies gain at most 35% stats).
@export_range(1.0, 2.0) var overgeared_max_factor: float = 1.35

## Minimum scaling factor for undergeared players (enemies lose at most 25% stats).
@export_range(0.5, 1.0) var undergeared_min_factor: float = 0.75

## Power ratio at which maximum overgeared scaling is reached.
@export var overgeared_cap_ratio: float = 2.5

## Power ratio at which maximum undergeared scaling is reached.
@export var undergeared_cap_ratio: float = 0.3


func get_expected_power(player_level: int) -> float:
	"""Get the expected total affix power for a normally-geared player at this level.

	Based on the XP→encounters→loot→power progression chain:
	  Level 1: ~10, Level 10: ~85, Level 20: ~220, Level 50: ~560, Level 100: ~1400
	"""
	var t: float = clampf(
		float(player_level - 1) / float(max(max_item_level - 1, 1)),
		0.0, 1.0
	)
	# Fallback if no curve: power ∝ level^1.5 (matches derived anchor points).
	# level^1.5 normalized: (t^1.5) since t = normalized level.
	var curve_value: float = expected_power_curve.sample(t) if expected_power_curve else pow(t, 1.5)
	return lerpf(min_expected_power, max_expected_power, curve_value)


func get_power_ratio(player_level: int, player_power: float) -> float:
	"""Compare actual player power to expected power. Returns ratio (1.0 = on-curve)."""
	var expected: float = get_expected_power(player_level)
	if expected <= 0.0:
		return 1.0
	return player_power / expected


func get_enemy_scaling_factor(power_ratio: float) -> float:
	"""Convert a power ratio into an enemy stat scaling factor.

	Enemies scale WITH the player's power:
	- Overgeared player (ratio > 1.15) → enemies scale UP (up to +50%)
	- Undergeared player (ratio < 0.85) → enemies scale DOWN (up to -25%)
	Dead zone around 1.0 prevents jitter from small gear changes.
	"""
	if power_ratio >= power_dead_zone_low and power_ratio <= power_dead_zone_high:
		return 1.0

	if power_ratio > power_dead_zone_high:
		# Overgeared: enemies scale up to match
		var over: float = (power_ratio - power_dead_zone_high) / (overgeared_cap_ratio - power_dead_zone_high)
		over = clampf(over, 0.0, 1.0)
		return lerpf(1.0, overgeared_max_factor, over)
	else:
		# Undergeared: enemies scale down for mercy
		var under: float = (power_dead_zone_low - power_ratio) / (power_dead_zone_low - undergeared_cap_ratio)
		under = clampf(under, 0.0, 1.0)
		return lerpf(1.0, undergeared_min_factor, under)


func compute_fuzz_range(center: float, effect_min: float, effect_max: float,
						fuzz_override: float = -1.0) -> Dictionary:
	"""Compute the actual min/max roll range after applying fuzz.
	
	Uses the hybrid fuzz system: percentage-based fuzz with an absolute minimum
	to prevent small-integer affixes from being deterministic.
	
	Args:
		center: The level-determined center value.
		effect_min: The affix's minimum possible value.
		effect_max: The affix's maximum possible value.
		fuzz_override: Per-affix fuzz override (-1.0 = use default).
	
	Returns:
		Dictionary with "min" and "max" keys (clamped to effect bounds).
	"""
	var fuzz_pct: float = fuzz_override if fuzz_override >= 0.0 else default_fuzz_percent
	var total_range: float = effect_max - effect_min
	
	# Percentage-based fuzz: a share of the value, but never more than the
	# same share of the affix's range (so x1.05-1.6 multipliers don't get
	# +-0.21 of spread around 1.05)
	var pct_fuzz: float = minf(absf(center) * fuzz_pct, total_range * fuzz_pct)
	
	# Absolute minimum fuzz (prevents tiny-range determinism). It shrinks with
	# the affix's range: a full +-1 only for ranges of 10 or more, so narrow
	# ranges (multipliers like x1.05-1.6, chances, small integers) still follow
	# item level instead of rolling their whole range at any level.
	var abs_floor: float = min_absolute_fuzz * clampf(total_range / 10.0, 0.0, 1.0)
	var actual_fuzz: float = maxf(pct_fuzz, abs_floor)
	
	return {
		"min": maxf(effect_min, center - actual_fuzz),
		"max": minf(effect_max, center + actual_fuzz),
	}
