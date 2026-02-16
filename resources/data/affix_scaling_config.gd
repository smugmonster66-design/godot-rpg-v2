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
	
	# Percentage-based fuzz
	var pct_fuzz: float = absf(center) * fuzz_pct
	
	# Absolute minimum fuzz (prevents tiny-range determinism)
	var actual_fuzz: float = maxf(pct_fuzz, min_absolute_fuzz)
	
	return {
		"min": maxf(effect_min, center - actual_fuzz),
		"max": minf(effect_max, center + actual_fuzz),
	}
