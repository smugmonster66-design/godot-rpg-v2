# res://resources/data/ai_escalation_rule.gd
# Strategy override trigger for adaptive enemy behaviour.
# Attach to EnemyData.escalation_rules. First matching rule wins.
#
# Follows the ActionEffectCondition inspector pattern — enum dropdown
# with _validate_property() to hide irrelevant fields.
extends Resource
class_name AIEscalationRule

# ============================================================================
# ENUMS
# ============================================================================

enum EscalationTrigger {
	SELF_HP_BELOW,       ## Switch when own HP% < threshold.
	SELF_HP_ABOVE,       ## Switch when own HP% >= threshold.
	ALLY_DIED,           ## Switch when any allied enemy has died.
	ALL_ALLIES_DEAD,     ## Switch when this enemy is the last one standing.
	TURN_NUMBER_ABOVE,   ## Switch after turn X.
}

# ============================================================================
# EXPORTS
# ============================================================================

@export var trigger: EscalationTrigger = EscalationTrigger.SELF_HP_BELOW

## Numeric threshold. Used by HP and turn-number triggers.
@export var threshold: float = 0.5

## The strategy to switch to when the trigger condition is met.
@export var new_strategy: EnemyData.AIStrategy = EnemyData.AIStrategy.AGGRESSIVE

# ============================================================================
# INSPECTOR — hide threshold for triggers that don't use it
# ============================================================================

func _validate_property(property: Dictionary) -> void:
	if property["name"] == "threshold":
		match trigger:
			EscalationTrigger.ALLY_DIED, \
			EscalationTrigger.ALL_ALLIES_DEAD:
				property["usage"] = PROPERTY_USAGE_NO_EDITOR

# ============================================================================
# EVALUATION
# ============================================================================

## Evaluate the rule against combat state.
## context keys:
##   "self_hp_percent"    : float (0..1)
##   "alive_ally_count"   : int (allied enemies alive, excluding self)
##   "total_ally_count"   : int (allied enemies at combat start, excluding self)
##   "turn_number"        : int
## Returns true if the trigger condition is met.
func evaluate(context: Dictionary) -> bool:
	match trigger:
		EscalationTrigger.SELF_HP_BELOW:
			return context.get("self_hp_percent", 1.0) < threshold
		EscalationTrigger.SELF_HP_ABOVE:
			return context.get("self_hp_percent", 1.0) >= threshold
		EscalationTrigger.ALLY_DIED:
			var alive: int = context.get("alive_ally_count", 0)
			var total: int = context.get("total_ally_count", 0)
			return alive < total
		EscalationTrigger.ALL_ALLIES_DEAD:
			return context.get("alive_ally_count", 0) == 0
		EscalationTrigger.TURN_NUMBER_ABOVE:
			return context.get("turn_number", 1) >= int(threshold)
	return false
