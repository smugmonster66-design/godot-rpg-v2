# res://resources/data/action_ai_hint.gd
# Inspector-friendly AI hint attached to an Action resource.
# Tells the enemy AI when to prefer (or avoid) this action.
#
# Uses enum dropdowns + _validate_property() to show only relevant fields,
# following the ActionEffectCondition pattern.
extends Resource
class_name ActionAIHint

# ============================================================================
# ENUMS
# ============================================================================

enum HintCondition {
	NONE,                    ## No condition — hint always applies.
	SELF_HP_BELOW,           ## Trigger when own HP% < threshold.
	SELF_HP_ABOVE,           ## Trigger when own HP% >= threshold.
	TARGET_HP_BELOW,         ## Trigger when target HP% < threshold.
	TARGET_HP_ABOVE,         ## Trigger when target HP% >= threshold.
	TARGET_HAS_STATUS,       ## Trigger when target has a specific status.
	TARGET_MISSING_STATUS,   ## Trigger when target lacks a specific status.
	SELF_HAS_STATUS,         ## Trigger when self has a specific status.
	SELF_MISSING_STATUS,     ## Trigger when self lacks a specific status.
	ALLY_COUNT_ABOVE,        ## Trigger when alive allied enemies >= threshold.
	ALLY_COUNT_BELOW,        ## Trigger when alive allied enemies < threshold.
	TURN_NUMBER_ABOVE,       ## Trigger after turn X (late-fight abilities).
}

enum HintEffect {
	SCORE_BONUS,             ## Add flat bonus to action score.
	SCORE_MULTIPLIER,        ## Multiply action score.
	FORCE_ACTION,            ## Always pick this action when condition met.
}

# ============================================================================
# EXPORTS
# ============================================================================

@export var condition: HintCondition = HintCondition.NONE

## Numeric threshold for HP%, ally count, or turn number conditions.
@export var threshold: float = 0.5

## Status ID for status-based conditions (e.g. "burn", "poison").
@export var status_id: String = ""

@export var effect: HintEffect = HintEffect.SCORE_BONUS

## Flat score bonus added when condition passes. Used with SCORE_BONUS.
@export var bonus_value: float = 30.0

## Score multiplier applied when condition passes. Used with SCORE_MULTIPLIER.
@export var multiplier_value: float = 1.5

## If true, invert the condition (pass ↔ fail).
@export var invert: bool = false

# ============================================================================
# INSPECTOR — show/hide fields based on condition + effect type
# ============================================================================

func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property["name"]

	# threshold: only for HP, ally count, and turn conditions
	if prop_name == "threshold":
		match condition:
			HintCondition.NONE, \
			HintCondition.TARGET_HAS_STATUS, \
			HintCondition.TARGET_MISSING_STATUS, \
			HintCondition.SELF_HAS_STATUS, \
			HintCondition.SELF_MISSING_STATUS:
				property["usage"] = PROPERTY_USAGE_NO_EDITOR

	# status_id: only for status-based conditions
	if prop_name == "status_id":
		match condition:
			HintCondition.TARGET_HAS_STATUS, \
			HintCondition.TARGET_MISSING_STATUS, \
			HintCondition.SELF_HAS_STATUS, \
			HintCondition.SELF_MISSING_STATUS:
				pass  # show
			_:
				property["usage"] = PROPERTY_USAGE_NO_EDITOR

	# bonus_value: only for SCORE_BONUS
	if prop_name == "bonus_value":
		if effect != HintEffect.SCORE_BONUS:
			property["usage"] = PROPERTY_USAGE_NO_EDITOR

	# multiplier_value: only for SCORE_MULTIPLIER
	if prop_name == "multiplier_value":
		if effect != HintEffect.SCORE_MULTIPLIER:
			property["usage"] = PROPERTY_USAGE_NO_EDITOR

# ============================================================================
# EVALUATION
# ============================================================================

## Evaluate the hint condition against runtime context.
## context keys:
##   "self_hp_percent"  : float (0..1)
##   "target_hp_percent": float (0..1)
##   "self_tracker"     : StatusTracker (or null)
##   "target_tracker"   : StatusTracker (or null)
##   "ally_count"       : int (alive allied enemies, excluding self)
##   "turn_number"      : int
## Returns true if the condition is met (respecting invert).
func evaluate(context: Dictionary) -> bool:
	var raw := _check(context)
	return (not raw) if invert else raw


func _check(context: Dictionary) -> bool:
	match condition:
		HintCondition.NONE:
			return true

		HintCondition.SELF_HP_BELOW:
			return context.get("self_hp_percent", 1.0) < threshold
		HintCondition.SELF_HP_ABOVE:
			return context.get("self_hp_percent", 1.0) >= threshold

		HintCondition.TARGET_HP_BELOW:
			return context.get("target_hp_percent", 1.0) < threshold
		HintCondition.TARGET_HP_ABOVE:
			return context.get("target_hp_percent", 1.0) >= threshold

		HintCondition.TARGET_HAS_STATUS:
			var tracker = context.get("target_tracker")
			if tracker and tracker.has_method("has_status"):
				return tracker.has_status(status_id)
			return false
		HintCondition.TARGET_MISSING_STATUS:
			var tracker = context.get("target_tracker")
			if tracker and tracker.has_method("has_status"):
				return not tracker.has_status(status_id)
			return true

		HintCondition.SELF_HAS_STATUS:
			var tracker = context.get("self_tracker")
			if tracker and tracker.has_method("has_status"):
				return tracker.has_status(status_id)
			return false
		HintCondition.SELF_MISSING_STATUS:
			var tracker = context.get("self_tracker")
			if tracker and tracker.has_method("has_status"):
				return not tracker.has_status(status_id)
			return true

		HintCondition.ALLY_COUNT_ABOVE:
			return context.get("ally_count", 0) >= int(threshold)
		HintCondition.ALLY_COUNT_BELOW:
			return context.get("ally_count", 0) < int(threshold)

		HintCondition.TURN_NUMBER_ABOVE:
			return context.get("turn_number", 1) >= int(threshold)

	return false
