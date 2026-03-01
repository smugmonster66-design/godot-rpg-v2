# res://scripts/autoload/game_state.gd
# Central autoload for all game progression state.
# Owns the SaveData resource and provides convenience APIs.
#
# Usage:
#   GameState.flags.met_king = true
#   GameState.counters.increment(&"enemies_killed")
#   GameState.quests.accept_quest(&"main_quest_1")
#   GameState.map.set_current_location(&"village")
#   GameState.save()
extends Node

# ============================================================================
# SIGNALS
# ============================================================================
signal state_loaded
signal state_saved
signal flag_changed(flag_name: StringName, value: bool)
signal counter_changed(counter_name: StringName, old_value: int, new_value: int)
signal relationship_changed(npc_id: StringName, old_value: int, new_value: int)

# ============================================================================
# THE SAVE DATA
# ============================================================================
var _save_data: SaveData = null

# Typed accessors for convenience
var flags: StoryFlags:
	get: return _save_data.flags

var counters: Counters:
	get: return _save_data.counters

var relationships: Relationships:
	get: return _save_data.relationships

var quests: QuestJournal:
	get: return _save_data.quests

var map: MapProgress:
	get: return _save_data.map

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Load or create save data
	_save_data = SaveData.load_from_disk()
	_connect_signals()
	print("GameState ready - %s" % ("Loaded existing save" if SaveData.save_exists() else "New game"))
	state_loaded.emit()

func _connect_signals():
	"""Wire up sub-resource signals to bubble up."""
	if _save_data.flags:
		_save_data.flags.flag_changed.connect(_on_flag_changed)
	if _save_data.counters:
		_save_data.counters.counter_changed.connect(_on_counter_changed)
	if _save_data.relationships:
		_save_data.relationships.relationship_changed.connect(_on_relationship_changed)

func _on_flag_changed(flag_name: StringName, value: bool):
	flag_changed.emit(flag_name, value)

func _on_counter_changed(counter_name: StringName, old_value: int, new_value: int):
	counter_changed.emit(counter_name, old_value, new_value)

func _on_relationship_changed(npc_id: StringName, old_value: int, new_value: int):
	relationship_changed.emit(npc_id, old_value, new_value)

# ============================================================================
# SAVE/LOAD
# ============================================================================

func save() -> Error:
	"""Save current state to disk."""
	var error = _save_data.save_to_disk()
	if error == OK:
		state_saved.emit()
	return error

func load_game() -> void:
	"""Reload from disk (discards current state)."""
	_save_data = SaveData.load_from_disk()
	_connect_signals()
	state_loaded.emit()

func new_game() -> void:
	"""Start a new game (discards current state)."""
	_save_data = SaveData.new()
	_connect_signals()
	state_loaded.emit()

func delete_save() -> Error:
	"""Delete the save file."""
	return SaveData.delete_save()

func has_save() -> bool:
	"""Check if a save file exists."""
	return SaveData.save_exists()

# ============================================================================
# CONVENIENCE - FLAGS
# ============================================================================

func set_flag(flag_name: StringName, value: bool = true) -> void:
	"""Set a story flag."""
	_save_data.flags.set_flag(flag_name, value)

func get_flag(flag_name: StringName) -> bool:
	"""Get a story flag."""
	return _save_data.flags.get_flag(flag_name)

# ============================================================================
# CONVENIENCE - COUNTERS
# ============================================================================

func increment_counter(counter_name: StringName, amount: int = 1) -> int:
	"""Increment a counter and return new value."""
	return _save_data.counters.increment(counter_name, amount)

func get_counter(counter_name: StringName) -> int:
	"""Get a counter value."""
	return _save_data.counters.get_counter(counter_name)

# ============================================================================
# CONVENIENCE - RELATIONSHIPS
# ============================================================================

func modify_relationship(npc_id: StringName, delta: int) -> int:
	"""Modify NPC relationship and return new value."""
	return _save_data.relationships.modify(npc_id, delta)

func get_relationship(npc_id: StringName) -> int:
	"""Get NPC relationship value."""
	return _save_data.relationships.get_relationship(npc_id)

# ============================================================================
# CONVENIENCE - PLAYER
# ============================================================================

func get_player_level() -> int:
	return _save_data.player_level

func set_player_level(level: int) -> void:
	_save_data.player_level = level

func get_class_level(class_id: StringName) -> int:
	return _save_data.get_class_level(class_id)

func set_class_level(class_id: StringName, level: int) -> void:
	_save_data.set_class_level(class_id, level)

# ============================================================================
# CONVENIENCE - TIMESTAMPS
# ============================================================================

func set_timestamp(key: StringName) -> void:
	_save_data.set_timestamp(key)

func get_time_since(key: StringName) -> float:
	return _save_data.get_time_since(key)

# ============================================================================
# PLAY TIME TRACKING
# ============================================================================

var _session_start: float = 0.0

func _enter_tree():
	_session_start = Time.get_unix_time_from_system()

func _exit_tree():
	# Update play time on exit
	if _save_data:
		_save_data.play_time += Time.get_unix_time_from_system() - _session_start
		save()

func get_play_time() -> float:
	"""Get total play time in seconds, including current session."""
	var session_time = Time.get_unix_time_from_system() - _session_start
	return _save_data.play_time + session_time

# ============================================================================
# CONDITION EVALUATION
# ============================================================================

func evaluate_condition(condition: GameCondition) -> bool:
	"""Evaluate a condition against current game state."""
	if condition == null or condition.is_empty():
		return true
	return condition.evaluate(create_condition_context())

func create_condition_context() -> GameCondition.ConditionContext:
	"""Create a condition context for the current game state."""
	return GameStateConditionContext.new(self)


# ============================================================================
# CONDITION CONTEXT IMPLEMENTATION
# ============================================================================

class GameStateConditionContext extends GameCondition.ConditionContext:
	var _game_state: Node  # Reference to GameState autoload
	
	func _init(game_state: Node):
		_game_state = game_state
	
	func get_flag(name: StringName) -> bool:
		return _game_state.flags.get_flag(name)
	
	func get_counter(name: StringName) -> int:
		return _game_state.counters.get_counter(name)
	
	func get_relationship(npc_id: StringName) -> int:
		return _game_state.relationships.get_relationship(npc_id)
	
	func get_item_count(item_id: StringName) -> int:
		# Inventory is Array[EquippableItem], count by item_name
		if GameManager and GameManager.player and GameManager.player.inventory:
			var count := 0
			for item in GameManager.player.inventory:
				if item and item.item_name == String(item_id):
					count += 1
			return count
		return 0
	
	func get_player_level() -> int:
		return _game_state.get_player_level()
	
	func get_class_level(class_id: StringName) -> int:
		return _game_state.get_class_level(class_id)
	
	func get_quest_state(quest_id: StringName) -> String:
		return _game_state.quests.get_state_string(quest_id)
	
	func has_visited_location(location_id: StringName) -> bool:
		return _game_state.map.has_visited(location_id)
	
	func evaluate_custom(key: StringName) -> bool:
		# For edge cases - emit a signal and let game code respond
		# You could add: custom_condition_checked.emit(key)
		# And have listeners call set_custom_result(key, bool)
		push_warning("Custom condition '%s' not implemented" % key)
		return false
