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
				result = true
		
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


# ============================================================================
# SINGLE CHECK - The atomic unit of condition checking
# ============================================================================

class SingleCheck extends Resource:
	enum CheckType {
		FLAG,           # Check a StoryFlags boolean
		COUNTER,        # Compare a counter value
		RELATIONSHIP,   # Compare relationship value
		HAS_ITEM,       # Check player inventory
		PLAYER_LEVEL,   # Check player level
		CLASS_LEVEL,    # Check specific class level
		QUEST_STATE,    # Check quest status
		LOCATION_VISITED, # Check if location was visited
		CUSTOM          # Emit signal for game-specific logic
	}
	
	@export var check_type: CheckType = CheckType.FLAG
	
	## Key - flag name, counter name, NPC id, item id, quest id, location id, etc.
	@export var key: StringName = &""
	
	## For FLAG checks - expected value
	@export var bool_value: bool = true
	
	## For numeric comparisons (COUNTER, RELATIONSHIP, PLAYER_LEVEL, CLASS_LEVEL)
	@export var compare_operator: String = ">="  # ==, !=, >, <, >=, <=
	@export var int_value: int = 0
	
	## For QUEST_STATE - expected state
	@export var quest_state: String = "complete"  # locked, available, active, complete, failed
	
	## For CLASS_LEVEL - which class
	@export var class_id: StringName = &""
	
	func evaluate(context: ConditionContext) -> bool:
		"""Evaluate this single check."""
		match check_type:
			CheckType.FLAG:
				return context.get_flag(key) == bool_value
			
			CheckType.COUNTER:
				return _compare(context.get_counter(key), compare_operator, int_value)
			
			CheckType.RELATIONSHIP:
				return _compare(context.get_relationship(key), compare_operator, int_value)
			
			CheckType.HAS_ITEM:
				var count = context.get_item_count(key)
				if int_value > 0:
					return _compare(count, compare_operator, int_value)
				else:
					return count > 0
			
			CheckType.PLAYER_LEVEL:
				return _compare(context.get_player_level(), compare_operator, int_value)
			
			CheckType.CLASS_LEVEL:
				return _compare(context.get_class_level(class_id), compare_operator, int_value)
			
			CheckType.QUEST_STATE:
				return context.get_quest_state(key) == quest_state
			
			CheckType.LOCATION_VISITED:
				return context.has_visited_location(key)
			
			CheckType.CUSTOM:
				return context.evaluate_custom(key)
		
		return false
	
	func _compare(value: int, op: String, target: int) -> bool:
		match op:
			"==": return value == target
			"!=": return value != target
			">":  return value > target
			"<":  return value < target
			">=": return value >= target
			"<=": return value <= target
		return false


# ============================================================================
# CONDITION CONTEXT - Interface for accessing game state
# ============================================================================

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
