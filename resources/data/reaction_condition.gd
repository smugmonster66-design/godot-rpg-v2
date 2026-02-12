# res://resources/data/reaction_condition.gd
# Configurable condition that gates whether an AnimationReaction fires.
# Evaluated against a CombatEvent's values dictionary.
#
# Multiple conditions on a single AnimationReaction are ANDed together.
# For OR logic, create separate AnimationReaction resources.
#
# Examples:
#   "Only when delta > 0"        → key="delta", op=GREATER_THAN, num=0
#   "Only fire element"          → key="element", op=EQUALS, str="FIRE"
#   "Only if source is siphon"   → key="", op=TAG_EQUALS, str="siphon"
#   "Only if amount >= 10"       → key="amount", op=GREATER_EQUAL, num=10
#   "Only crits"                 → key="is_crit", op=IS_TRUE
extends Resource
class_name ReactionCondition

# ============================================================================
# COMPARISON OPERATORS
# ============================================================================

enum Operator {
	EQUALS,            ## values[key] == compare_number (or compare_string)
	NOT_EQUALS,        ## values[key] != compare_number (or compare_string)
	GREATER_THAN,      ## values[key] > compare_number
	GREATER_EQUAL,     ## values[key] >= compare_number
	LESS_THAN,         ## values[key] < compare_number
	LESS_EQUAL,        ## values[key] <= compare_number
	IS_TRUE,           ## values[key] is truthy (bool true, int > 0, non-empty string)
	IS_FALSE,          ## values[key] is falsy
	TAG_EQUALS,        ## event.source_tag == compare_string (key is ignored)
	TAG_CONTAINS,      ## event.source_tag contains compare_string (key is ignored)
	HAS_KEY,           ## values.has(key) — checks presence, ignores value
	ARRAY_CONTAINS,    ## values[key] is Array and contains compare_string
}

# ============================================================================
# CONFIGURATION
# ============================================================================

## The key to look up in event.values (ignored for TAG_EQUALS/TAG_CONTAINS)
@export var key: String = ""

## The comparison operator
@export var operator: Operator = Operator.GREATER_THAN

## Numeric value for numeric comparisons (EQUALS, GREATER_THAN, etc.)
@export var compare_number: float = 0.0

## String value for string comparisons (EQUALS, TAG_EQUALS, ARRAY_CONTAINS)
@export var compare_string: String = ""

## When true, this condition is negated (NOT of the result)
@export var negate: bool = false

# ============================================================================
# EVALUATION
# ============================================================================

func evaluate(event: CombatEvent) -> bool:
	"""Test whether this condition passes for the given event.
	Returns true if the condition is met (after optional negation)."""
	var result = _evaluate_inner(event)
	return not result if negate else result


func _evaluate_inner(event: CombatEvent) -> bool:
	"""Core evaluation logic without negation."""
	match operator:
		Operator.TAG_EQUALS:
			return event.source_tag == compare_string
		Operator.TAG_CONTAINS:
			return compare_string in event.source_tag
		Operator.HAS_KEY:
			return event.values.has(key)
		_:
			pass

	# All other operators need a value from the event dict
	if not event.values.has(key):
		return false

	var val = event.values[key]

	match operator:
		Operator.IS_TRUE:
			return _is_truthy(val)
		Operator.IS_FALSE:
			return not _is_truthy(val)
		Operator.EQUALS:
			if compare_string != "":
				return str(val) == compare_string
			return _to_float(val) == compare_number
		Operator.NOT_EQUALS:
			if compare_string != "":
				return str(val) != compare_string
			return _to_float(val) != compare_number
		Operator.GREATER_THAN:
			return _to_float(val) > compare_number
		Operator.GREATER_EQUAL:
			return _to_float(val) >= compare_number
		Operator.LESS_THAN:
			return _to_float(val) < compare_number
		Operator.LESS_EQUAL:
			return _to_float(val) <= compare_number
		Operator.ARRAY_CONTAINS:
			if val is Array:
				return compare_string in val
			return false

	return false


func _is_truthy(val) -> bool:
	if val is bool:
		return val
	if val is int or val is float:
		return val != 0
	if val is String:
		return val != ""
	if val is Array:
		return val.size() > 0
	return val != null


func _to_float(val) -> float:
	if val is float:
		return val
	if val is int:
		return float(val)
	if val is bool:
		return 1.0 if val else 0.0
	if val is String and val.is_valid_float():
		return float(val)
	return 0.0

# ============================================================================
# DEBUG
# ============================================================================

func describe() -> String:
	"""Human-readable description for debugging / inspector."""
	var op_name = Operator.keys()[operator]
	match operator:
		Operator.TAG_EQUALS:
			return "tag == \"%s\"" % compare_string
		Operator.TAG_CONTAINS:
			return "tag contains \"%s\"" % compare_string
		Operator.HAS_KEY:
			return "has key \"%s\"" % key
		Operator.IS_TRUE:
			return "\"%s\" is true" % key
		Operator.IS_FALSE:
			return "\"%s\" is false" % key
		_:
			var cmp = compare_string if compare_string != "" else str(compare_number)
			var neg = "NOT " if negate else ""
			return "%s\"%s\" %s %s" % [neg, key, op_name, cmp]
