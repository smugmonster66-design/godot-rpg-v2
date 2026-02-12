# res://scripts/resources/action_effect_condition.gd
# Conditional gate for ActionEffect execution.
# Evaluates context to determine if an effect should fire and with what multiplier.
extends Resource
class_name ActionEffectCondition

# ============================================================================
# ENUMS
# ============================================================================
enum ConditionType {
	NONE,                  ## Always passes (no condition).
	SOURCE_HP_ABOVE,       ## Source HP% >= threshold.
	SOURCE_HP_BELOW,       ## Source HP% < threshold.
	TARGET_HP_ABOVE,       ## Target HP% >= threshold.
	TARGET_HP_BELOW,       ## Target HP% < threshold.
	TARGET_HAS_STATUS,     ## Target has specific status active.
	TARGET_MISSING_STATUS, ## Target does NOT have specific status.
	SOURCE_HAS_STATUS,     ## Source has specific status active.
	DICE_TOTAL_ABOVE,      ## Dice total >= threshold.
	DICE_TOTAL_BELOW,      ## Dice total < threshold.
	DICE_COUNT_ABOVE,      ## Number of dice >= threshold.
	TURN_NUMBER_ABOVE,     ## Current turn >= threshold.
	MANA_ABOVE,            ## Current mana% >= threshold.
	MANA_BELOW,            ## Current mana% < threshold.
	RANDOM_CHANCE,         ## Random roll < threshold (0.0–1.0).
}

# ============================================================================
# EXPORTS
# ============================================================================
@export var condition_type: ConditionType = ConditionType.NONE

## Numeric threshold for comparison conditions (HP%, dice total, turn, mana%, chance).
@export var threshold: float = 0.5

## Status ID string for status-based conditions.
@export var status_id: String = ""

## If true, a passing condition scales the effect instead of gating it.
## The multiplier is derived from how far past the threshold the value is.
@export var scales_on_pass: bool = false

## Fixed multiplier applied when condition passes (default 1.0 = no change).
@export var pass_multiplier: float = 1.0

## If true, invert the condition (pass becomes fail, fail becomes pass).
@export var invert: bool = false

# ============================================================================
# EVALUATION
# ============================================================================

## Evaluate the condition against the provided context dictionary.
## Returns: { "blocked": bool, "multiplier": float }
##   blocked = true  → effect should be skipped
##   blocked = false → effect should fire with the given multiplier
func evaluate(context: Dictionary) -> Dictionary:
	if condition_type == ConditionType.NONE:
		return {"blocked": false, "multiplier": 1.0}

	var raw_pass := _check(context)
	var final_pass := (not raw_pass) if invert else raw_pass

	if not final_pass:
		return {"blocked": true, "multiplier": 0.0}

	var mult := pass_multiplier
	if scales_on_pass:
		mult = _calculate_scaling(context)

	return {"blocked": false, "multiplier": mult}

# ============================================================================
# INTERNAL CHECK
# ============================================================================

func _check(context: Dictionary) -> bool:
	match condition_type:
		ConditionType.NONE:
			return true

		ConditionType.SOURCE_HP_ABOVE:
			return context.get("source_hp_percent", 1.0) >= threshold

		ConditionType.SOURCE_HP_BELOW:
			return context.get("source_hp_percent", 1.0) < threshold

		ConditionType.TARGET_HP_ABOVE:
			return context.get("target_hp_percent", 1.0) >= threshold

		ConditionType.TARGET_HP_BELOW:
			return context.get("target_hp_percent", 1.0) < threshold

		ConditionType.TARGET_HAS_STATUS:
			var tracker = context.get("target_tracker")
			if tracker and tracker.has_method("has_status"):
				return tracker.has_status(status_id)
			elif tracker and tracker.has_method("get_stacks"):
				return tracker.get_stacks(status_id) > 0
			return false

		ConditionType.TARGET_MISSING_STATUS:
			var tracker = context.get("target_tracker")
			if tracker and tracker.has_method("has_status"):
				return not tracker.has_status(status_id)
			elif tracker and tracker.has_method("get_stacks"):
				return tracker.get_stacks(status_id) == 0
			return true

		ConditionType.SOURCE_HAS_STATUS:
			var tracker = context.get("source_tracker")
			if tracker and tracker.has_method("has_status"):
				return tracker.has_status(status_id)
			elif tracker and tracker.has_method("get_stacks"):
				return tracker.get_stacks(status_id) > 0
			return false

		ConditionType.DICE_TOTAL_ABOVE:
			return float(context.get("dice_total", 0)) >= threshold

		ConditionType.DICE_TOTAL_BELOW:
			return float(context.get("dice_total", 0)) < threshold

		ConditionType.DICE_COUNT_ABOVE:
			return float(context.get("dice_count", 0)) >= threshold

		ConditionType.TURN_NUMBER_ABOVE:
			return float(context.get("turn_number", 1)) >= threshold

		ConditionType.MANA_ABOVE:
			var cm: float = float(context.get("current_mana", 0))
			var mm: float = maxf(float(context.get("max_mana", 1)), 1.0)
			return (cm / mm) >= threshold

		ConditionType.MANA_BELOW:
			var cm: float = float(context.get("current_mana", 0))
			var mm: float = maxf(float(context.get("max_mana", 1)), 1.0)
			return (cm / mm) < threshold

		ConditionType.RANDOM_CHANCE:
			return randf() < threshold

	return true

# ============================================================================
# SCALING
# ============================================================================

## When scales_on_pass is true, calculate a multiplier based on how far
## past the threshold the relevant value is. Returns pass_multiplier as floor.
func _calculate_scaling(context: Dictionary) -> float:
	match condition_type:
		ConditionType.SOURCE_HP_BELOW:
			# Lower HP = higher multiplier (missing HP scaling)
			var hp: float = context.get("source_hp_percent", 1.0)
			var missing: float = 1.0 - hp
			return pass_multiplier * (1.0 + missing)

		ConditionType.TARGET_HP_BELOW:
			var hp: float = context.get("target_hp_percent", 1.0)
			var missing: float = 1.0 - hp
			return pass_multiplier * (1.0 + missing)

		ConditionType.DICE_TOTAL_ABOVE:
			var dt: float = float(context.get("dice_total", 0))
			if threshold > 0:
				return pass_multiplier * (dt / threshold)
			return pass_multiplier

		ConditionType.TURN_NUMBER_ABOVE:
			var tn: float = float(context.get("turn_number", 1))
			if threshold > 0:
				return pass_multiplier * (tn / threshold)
			return pass_multiplier

	return pass_multiplier

# ============================================================================
# DISPLAY
# ============================================================================

func get_description() -> String:
	var prefix := "NOT " if invert else ""
	match condition_type:
		ConditionType.NONE:
			return "Always"
		ConditionType.SOURCE_HP_ABOVE:
			return "%sSource HP >= %d%%" % [prefix, int(threshold * 100)]
		ConditionType.SOURCE_HP_BELOW:
			return "%sSource HP < %d%%" % [prefix, int(threshold * 100)]
		ConditionType.TARGET_HP_ABOVE:
			return "%sTarget HP >= %d%%" % [prefix, int(threshold * 100)]
		ConditionType.TARGET_HP_BELOW:
			return "%sTarget HP < %d%%" % [prefix, int(threshold * 100)]
		ConditionType.TARGET_HAS_STATUS:
			return "%sTarget has '%s'" % [prefix, status_id]
		ConditionType.TARGET_MISSING_STATUS:
			return "%sTarget missing '%s'" % [prefix, status_id]
		ConditionType.SOURCE_HAS_STATUS:
			return "%sSource has '%s'" % [prefix, status_id]
		ConditionType.DICE_TOTAL_ABOVE:
			return "%sDice total >= %d" % [prefix, int(threshold)]
		ConditionType.DICE_TOTAL_BELOW:
			return "%sDice total < %d" % [prefix, int(threshold)]
		ConditionType.DICE_COUNT_ABOVE:
			return "%sDice count >= %d" % [prefix, int(threshold)]
		ConditionType.TURN_NUMBER_ABOVE:
			return "%sTurn >= %d" % [prefix, int(threshold)]
		ConditionType.MANA_ABOVE:
			return "%sMana >= %d%%" % [prefix, int(threshold * 100)]
		ConditionType.MANA_BELOW:
			return "%sMana < %d%%" % [prefix, int(threshold * 100)]
		ConditionType.RANDOM_CHANCE:
			return "%s%d%% chance" % [prefix, int(threshold * 100)]
	return "Unknown"

func _to_string() -> String:
	return "ActionEffectCondition<%s>" % get_description()
