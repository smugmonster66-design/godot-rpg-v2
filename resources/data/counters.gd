# res://resources/data/counters.gd
# Named integer counters for tracking quantities.
# Unlike StoryFlags, these are stored in a dictionary for flexibility.
# Common counters can still have helper properties for autocomplete.
extends Resource
class_name Counters

signal counter_changed(counter_name: StringName, old_value: int, new_value: int)

# ============================================================================
# STORAGE
# ============================================================================
@export var _data: Dictionary = {}  # StringName -> int

# ============================================================================
# COMMON COUNTERS - Properties for autocomplete on frequently-used counters
# These are backed by the dictionary, not separate storage.
# ============================================================================

var enemies_killed: int:
	get: return get_counter(&"enemies_killed")
	set(v): set_counter(&"enemies_killed", v)

var gold_donated: int:
	get: return get_counter(&"gold_donated")
	set(v): set_counter(&"gold_donated", v)

var deaths: int:
	get: return get_counter(&"deaths")
	set(v): set_counter(&"deaths", v)

var quests_completed: int:
	get: return get_counter(&"quests_completed")
	set(v): set_counter(&"quests_completed", v)

var dice_rolled: int:
	get: return get_counter(&"dice_rolled")
	set(v): set_counter(&"dice_rolled", v)

var criticals_landed: int:
	get: return get_counter(&"criticals_landed")
	set(v): set_counter(&"criticals_landed", v)

# ============================================================================
# API
# ============================================================================

func set_counter(counter_name: StringName, value: int) -> void:
	"""Set a counter to a specific value."""
	var old_value = _data.get(counter_name, 0)
	if old_value != value:
		_data[counter_name] = value
		counter_changed.emit(counter_name, old_value, value)

func get_counter(counter_name: StringName) -> int:
	"""Get a counter value. Returns 0 if not set."""
	return _data.get(counter_name, 0)

func increment(counter_name: StringName, amount: int = 1) -> int:
	"""Increment a counter and return the new value."""
	var new_value = get_counter(counter_name) + amount
	set_counter(counter_name, new_value)
	return new_value

func decrement(counter_name: StringName, amount: int = 1) -> int:
	"""Decrement a counter and return the new value. Does not go below 0."""
	var new_value = maxi(0, get_counter(counter_name) - amount)
	set_counter(counter_name, new_value)
	return new_value

func get_all_counters() -> Dictionary:
	"""Get all counters as a dictionary."""
	return _data.duplicate()

func get_counter_names() -> Array[StringName]:
	"""Get list of all counter names that have been set."""
	var result: Array[StringName] = []
	for key in _data.keys():
		result.append(key)
	return result
