# res://resources/data/floater_condition.gd
# Configurable condition that gates whether a FloaterReaction or BarkReaction fires.
# Evaluated against a GameEvent's values dictionary.
# Mirrors ReactionCondition but for GameEvent instead of CombatEvent.
extends Resource
class_name FloaterCondition

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
	IS_TRUE,           ## values[key] is truthy
	IS_FALSE,          ## values[key] is falsy
	TAG_EQUALS,        ## event.source_tag == compare_string
	TAG_CONTAINS,      ## event.source_tag contains compare_string
	HAS_KEY,           ## values.has(key)
}

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var key: String = ""
@export var operator: Operator = Operator.GREATER_THAN
@export var compare_number: float = 0.0
@export var compare_string: String = ""
@export var negate: bool = false

# ============================================================================
# EVALUATION
# ============================================================================

func evaluate(event: GameEvent) -> bool:
	var result = _evaluate_inner(event)
	return not result if negate else result


func _evaluate_inner(event: GameEvent) -> bool:
	match operator:
		Operator.TAG_EQUALS:
			return event.source_tag == compare_string
		Operator.TAG_CONTAINS:
			return compare_string in event.source_tag
		Operator.HAS_KEY:
			return event.values.has(key)
		_:
			pass

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

	return false


func _is_truthy(val) -> bool:
	if val is bool: return val
	if val is int or val is float: return val != 0
	if val is String: return val != ""
	return val != null


func _to_float(val) -> float:
	if val is float: return val
	if val is int: return float(val)
	if val is bool: return 1.0 if val else 0.0
	return 0.0
