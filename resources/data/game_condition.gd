# res://resources/data/game_condition.gd
# Flexible condition system with AND/OR logic.
# Used for dialogue choices, quest prerequisites, location unlocks, etc.
#
# Usage:
#   Single check:     condition.check_type = SINGLE, fill in single_check
#   AND logic:        condition.check_type = AND, add sub_conditions
#   OR logic:         condition.check_type = OR, add sub_conditions
#   Always true:      condition.check_type = ALWAYS_TRUE
#   Always false:     condition.check_type = ALWAYS_FALSE
extends Resource
class_name GameCondition

enum ConditionType {
	ALWAYS_TRUE,    # Always passes (default state, no requirements)
	ALWAYS_FALSE,   # Always fails (useful for WIP content)
	SINGLE,         # Single check
	AND,            # All sub_conditions must pass
	OR              # Any sub_condition must pass
}

# ============================================================================
# CONDITION STRUCTURE
# ============================================================================
@export var condition_type: ConditionType = ConditionType.ALWAYS_TRUE

## For SINGLE type - the actual check to perform
@export var single_check: SingleCheck = null

## For AND/OR types - nested conditions
@export var sub_conditions: Array[GameCondition] = []

## Invert the final result
@export var invert: bool = false

# ============================================================================
# EVALUATION
# ============================================================================

func evaluate(context: ConditionContext) -> bool:
	"""Evaluate this condition against the game state."""
	var result: bool = false
	
	match condition_type:
		ConditionType.ALWAYS_TRUE:
			result = true
		
		ConditionType.ALWAYS_FALSE:
			result = false
		
		ConditionType.SINGLE:
			if single_check:
				result = single_check.evaluate(context)
			else:
				push_warning("GameCondition: SINGLE type but no single_check set")
				result = false
		
		ConditionType.AND:
			result = true
			for sub in sub_conditions:
				if not sub.evaluate(context):
					result = false
					break
		
		ConditionType.OR:
			result = false
			for sub in sub_conditions:
				if sub.evaluate(context):
					result = true
					break
	
	return not result if invert else result

func is_empty() -> bool:
	"""Returns true if this is effectively 'no condition' (always passes)."""
	return condition_type == ConditionType.ALWAYS_TRUE and not invert

# ============================================================================
# BUILDER HELPERS (for creating conditions in code)
# ============================================================================

static func always_true() -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.ALWAYS_TRUE
	return c

static func always_false() -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.ALWAYS_FALSE
	return c

static func flag(flag_name: StringName, expected: bool = true) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.FLAG
	c.single_check.key = flag_name
	c.single_check.bool_value = expected
	return c

static func counter_at_least(counter_name: StringName, minimum: int) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.COUNTER
	c.single_check.key = counter_name
	c.single_check.compare_operator = ">="
	c.single_check.int_value = minimum
	return c

static func all_of(conditions: Array[GameCondition]) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.AND
	c.sub_conditions = conditions
	return c

static func any_of(conditions: Array[GameCondition]) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.OR
	c.sub_conditions = conditions
	return c

static func counter_compare(counter_name: StringName, op: String, value: int) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.COUNTER
	c.single_check.key = counter_name
	c.single_check.compare_operator = op
	c.single_check.int_value = value
	return c

static func relationship(npc_id: StringName, op: String, value: int) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.RELATIONSHIP
	c.single_check.key = npc_id
	c.single_check.compare_operator = op
	c.single_check.int_value = value
	return c

static func approval(npc_id: StringName, op: String, value: int) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.APPROVAL
	c.single_check.key = npc_id
	c.single_check.compare_operator = op
	c.single_check.int_value = value
	return c

static func has_item(item_id: StringName, op: String = ">=", count: int = 1) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.HAS_ITEM
	c.single_check.key = item_id
	c.single_check.compare_operator = op
	c.single_check.int_value = count
	return c

static func player_level(op: String, level: int) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.PLAYER_LEVEL
	c.single_check.compare_operator = op
	c.single_check.int_value = level
	return c

static func class_level(p_class_id: StringName, op: String, level: int) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.CLASS_LEVEL
	c.single_check.key = p_class_id
	c.single_check.class_id = p_class_id
	c.single_check.compare_operator = op
	c.single_check.int_value = level
	return c

static func quest_state(quest_id: StringName, state: String) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.QUEST_STATE
	c.single_check.key = quest_id
	c.single_check.quest_state = state
	return c

static func location_visited(location_id: StringName) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.LOCATION_VISITED
	c.single_check.key = location_id
	return c

static func quest_objective(composite_key: StringName) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.CUSTOM
	c.single_check.key = composite_key
	return c

static func quest_objective_progress(quest_id: StringName, objective_id: StringName, op: String, value: int) -> GameCondition:
	var c = GameCondition.new()
	c.condition_type = ConditionType.SINGLE
	c.single_check = SingleCheck.new()
	c.single_check.check_type = SingleCheck.CheckType.CUSTOM
	c.single_check.key = StringName("quest_objective_progress:%s:%s:%s:%d" % [quest_id, objective_id, op, value])
	return c


# ============================================================================
# CONDITION CONTEXT - Interface for accessing game state
# ============================================================================
# NOTE: SingleCheck was extracted to res://resources/data/single_check.gd
# to fix .tres serialization (Godot loses inner class script references).

class ConditionContext extends RefCounted:
	"""
	Override this class to provide access to your game state.
	GameState autoload will create a concrete implementation.
	"""
	
	func get_flag(_name: StringName) -> bool:
		return false
	
	func get_counter(_name: StringName) -> int:
		return 0
	
	func get_relationship(_npc_id: StringName) -> int:
		return 0

	func get_approval(_npc_id: StringName) -> int:
		return 0

	func get_item_count(_item_id: StringName) -> int:
		return 0
	
	func get_player_level() -> int:
		return 1
	
	func get_class_level(_class_id: StringName) -> int:
		return 0
	
	func get_quest_state(_quest_id: StringName) -> String:
		return "locked"
	
	func has_visited_location(_location_id: StringName) -> bool:
		return false
	
	func evaluate_custom(_key: StringName) -> bool:
		return false
