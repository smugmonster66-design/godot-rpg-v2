# res://resources/data/single_check.gd
# The atomic unit of condition checking.
# Extracted from GameCondition inner class to fix .tres serialization —
# Godot loses inner class script references when saving resources to disk.
extends Resource
class_name SingleCheck

enum CheckType {
	FLAG,           # Check a StoryFlags boolean
	COUNTER,        # Compare a counter value
	RELATIONSHIP,   # Compare relationship value
	HAS_ITEM,       # Check player inventory
	PLAYER_LEVEL,   # Check player level
	CLASS_LEVEL,    # Check specific class level
	QUEST_STATE,    # Check quest status
	LOCATION_VISITED, # Check if location was visited
	APPROVAL,       # Compare hidden NPC approval value
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
## COUNTER only: if set, compare `key` against this counter's value instead of
## int_value (e.g. standing_navy > standing_presidium).
@export var compare_counter: StringName = &""

## For QUEST_STATE - expected state
@export var quest_state: String = "complete"  # locked, available, active, complete, failed

## For CLASS_LEVEL - which class
@export var class_id: StringName = &""

func evaluate(context) -> bool:
	"""Evaluate this single check."""
	match check_type:
		CheckType.FLAG:
			return context.get_flag(key) == bool_value

		CheckType.COUNTER:
			var rhs: int = context.get_counter(compare_counter) if compare_counter != &"" else int_value
			return _compare(context.get_counter(key), compare_operator, rhs)

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

		CheckType.APPROVAL:
			return _compare(context.get_approval(key), compare_operator, int_value)

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
