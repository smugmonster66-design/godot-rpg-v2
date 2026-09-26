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
## Emitted after an autosave attempt that was blocked (combat, dungeon, dialogue).
signal autosave_deferred
signal flag_changed(flag_name: StringName, value: bool)
signal counter_changed(counter_name: StringName, old_value: int, new_value: int)
signal relationship_changed(npc_id: StringName, old_value: int, new_value: int)
signal approval_changed(npc_id: StringName, old_value: int, new_value: int)

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

var approvals: Approvals:
	get: return _save_data.approvals

var quests: QuestJournal:
	get: return _save_data.quests

var map: MapProgress:
	get: return _save_data.map

var stash: StashData:
	get: return _save_data.stash

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Start with blank, in-memory state. The title screen decides whether this
	# session is a new game (new_game()) or a continue (load_game()). Nothing is
	# read from or written to disk until then.
	_save_data = SaveData.new()
	_connect_signals()
	print("GameState ready - %s on disk" % ("save found" if SaveData.save_exists() else "no save"))

func _restore_npc_state() -> void:
	if NPCManager and not _save_data.seen_npc_encounters.is_empty():
		NPCManager.restore_seen_encounters(_save_data.seen_npc_encounters)

func _connect_signals():
	"""Wire up sub-resource signals to bubble up."""
	if _save_data.flags:
		_save_data.flags.flag_changed.connect(_on_flag_changed)
	if _save_data.counters:
		_save_data.counters.counter_changed.connect(_on_counter_changed)
	if _save_data.relationships:
		_save_data.relationships.relationship_changed.connect(_on_relationship_changed)
	if _save_data.approvals:
		_save_data.approvals.approval_changed.connect(_on_approval_changed)

func _on_flag_changed(flag_name: StringName, value: bool):
	flag_changed.emit(flag_name, value)

func _on_counter_changed(counter_name: StringName, old_value: int, new_value: int):
	counter_changed.emit(counter_name, old_value, new_value)

func _on_relationship_changed(npc_id: StringName, old_value: int, new_value: int):
	relationship_changed.emit(npc_id, old_value, new_value)

func _on_approval_changed(npc_id: StringName, old_value: int, new_value: int):
	approval_changed.emit(npc_id, old_value, new_value)

# ============================================================================
# SAVE/LOAD
# ============================================================================

func save() -> Error:
	"""Save current state to disk. Snapshots player state from GameManager."""
	if GameManager and GameManager.player:
		_save_data.snapshot_player(GameManager.player, GameManager)
	# Snapshot NPC seen encounters
	if NPCManager:
		_save_data.seen_npc_encounters = NPCManager.get_seen_encounters_snapshot()
	# Snapshot the map stack (which zone the player is in)
	if MapManager:
		_save_data.map_stack = MapManager.get_stack_snapshot()
	# A fight in progress (saved only at the start of the player's turn)
	_save_data.combat_state = {}
	var gr_c = GameManager.game_root if GameManager else null
	if gr_c and gr_c.is_in_combat and gr_c.has_method("get_combat_manager"):
		var cm = gr_c.get_combat_manager()
		if cm and cm.is_at_turn_save_point():
			_save_data.combat_state = cm.serialize_combat()
	# A dungeon run in progress (saved only at safe points between nodes)
	_save_data.dungeon_run_state = {}
	_save_data.dungeon_run_affixes = []
	var gr = GameManager.game_root if GameManager else null
	if gr and gr.is_in_dungeon and gr.dungeon_scene and gr.dungeon_scene.current_run:
		_save_data.dungeon_run_state = gr.dungeon_scene.serialize_run()
		var affs: Array[Resource] = []
		for a in gr.dungeon_scene.get_run_stat_affixes():
			affs.append(a)
		_save_data.dungeon_run_affixes = affs
	# Fold the current session into play time
	_save_data.play_time = get_play_time()
	_session_start = Time.get_unix_time_from_system()
	var error = _save_data.save_to_disk()
	if error == OK:
		state_saved.emit()
	return error

# ============================================================================
# AUTOSAVE
# ============================================================================

## True once the player has started or continued a game (set by GameRoot).
## Nothing autosaves before that, so sitting on the title screen never
## touches the save file.
var session_active: bool = false

## Master switch for autosaving.
var autosave_enabled: bool = true

var _autosave_queued: bool = false
var _autosave_pending: bool = false

func request_autosave() -> void:
	"""Ask for a save at the next safe moment. Cheap to call often: requests in
	the same frame collapse into one save, and a request made during combat,
	a dungeon run or dialogue is held until the next request after it ends."""
	if not session_active or not autosave_enabled:
		return
	if _autosave_queued:
		return
	_autosave_queued = true
	call_deferred(&"_do_autosave")

func _do_autosave() -> void:
	_autosave_queued = false
	if not _can_autosave():
		_autosave_pending = true
		autosave_deferred.emit()
		return
	_autosave_pending = false
	save()

func flush_pending_autosave() -> void:
	"""Retry an autosave that was held back. GameRoot calls this when combat,
	a dungeon run or a dialogue ends."""
	if _autosave_pending:
		request_autosave()

func _can_autosave() -> bool:
	if not session_active:
		return false
	if GameManager and GameManager.game_root and GameManager.game_root.has_method("can_autosave"):
		return GameManager.game_root.can_autosave()
	return true

func load_game() -> void:
	"""Reload from disk (discards current state)."""
	_save_data = SaveData.load_from_disk()
	_connect_signals()
	# Restore NPC seen encounters
	if NPCManager:
		NPCManager.restore_seen_encounters(_save_data.seen_npc_encounters)
	_session_start = Time.get_unix_time_from_system()
	state_loaded.emit()

func new_game() -> void:
	"""Start a new game (discards current state). The old save file stays on
	disk until the first autosave of the new game overwrites it."""
	_save_data = SaveData.new()
	_connect_signals()
	# Clear NPC seen encounters
	if NPCManager:
		NPCManager.clear_seen_encounters()
	_session_start = Time.get_unix_time_from_system()
	state_loaded.emit()

func set_last_rest(stack_snapshot: Array, location_id: StringName) -> void:
	"""Record the map place the player last rested at."""
	_save_data.last_rest = {"stack": stack_snapshot.duplicate(true), "location": location_id}

func get_last_rest() -> Dictionary:
	"""{stack, location} of the last rest, or {} if the player never rested."""
	return _save_data.last_rest

func get_saved_combat() -> Dictionary:
	"""A fight in progress in the loaded save, or {}."""
	return _save_data.combat_state

func save_now_if_allowed() -> void:
	"""Save immediately if this is a safe moment (used at the start of the
	player's turn in a fight, where the moment passes within the frame)."""
	if not session_active or not autosave_enabled:
		return
	if _can_autosave():
		_autosave_pending = false
		save()

func get_saved_dungeon_run() -> Dictionary:
	"""{state, affixes} of a run in progress in the loaded save, or {}."""
	if _save_data.dungeon_run_state.is_empty():
		return {}
	return {"state": _save_data.dungeon_run_state, "affixes": _save_data.dungeon_run_affixes}

func get_saved_map_stack() -> Array:
	"""Map stack recorded in the loaded save (empty for a new game)."""
	return _save_data.map_stack

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

func set_counter(counter_name: StringName, value: int) -> void:
	"""Set a counter to an exact value."""
	_save_data.counters.set_counter(counter_name, value)

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
# CONVENIENCE - APPROVALS (hidden from player)
# ============================================================================

func modify_approval(npc_id: StringName, delta: int) -> int:
	"""Modify hidden NPC approval and return new value."""
	return _save_data.approvals.modify(npc_id, delta)

func get_approval(npc_id: StringName) -> int:
	"""Get hidden NPC approval value."""
	return _save_data.approvals.get_approval(npc_id)

# ============================================================================
# CONVENIENCE - PLAYER
# ============================================================================

func get_player_level() -> int:
	"""The player's current level. Reads the live player when there is one;
	the saved snapshot is only a fallback (it's stale between saves)."""
	if GameManager and GameManager.player:
		return int(GameManager.player.level)
	return _save_data.player_stats.get("level", 1)

func set_player_level(level: int) -> void:
	_save_data.player_stats["level"] = level

func has_player_state() -> bool:
	"""Whether a saved player state exists to restore."""
	return _save_data.has_player_state

func restore_player(player: Player, game_manager = null) -> bool:
	"""Restore player state from save data. Returns false if no state saved."""
	return _save_data.restore_player(player, game_manager)

func get_class_level(class_id: StringName) -> int:
	"""A class's current level. Live player first, saved snapshot as fallback."""
	if GameManager and GameManager.player:
		var pc = GameManager.player.available_classes.get(String(class_id))
		if pc == null:
			pc = GameManager.player.available_classes.get(class_id)
		if pc:
			return int(pc.level)
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

func _notification(what: int) -> void:
	# Save when the app is closed or sent to the background (mobile), but only
	# at a safe moment: a save mid-combat would record half a fight.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if session_active and autosave_enabled and _can_autosave():
			save()

func get_play_time() -> float:
	"""Get total play time in seconds, including current session."""
	var session_time = Time.get_unix_time_from_system() - _session_start
	return _save_data.play_time + session_time

# ============================================================================
# LAST FIGHT / DUNGEON RESULT
# ============================================================================
# Dialogue that starts a fight or a dungeon resumes afterwards whether the
# player won or lost. These let the resumed line branch on the result, via
# CUSTOM conditions: last_combat_won, last_combat_lost, last_dungeon_cleared,
# last_dungeon_failed. Set by GameRoot.

var last_combat_won: bool = false
var last_dungeon_cleared: bool = false
## The last dungeon run ended in death (false before any run, unlike
## "not cleared") / the player left with their loot at a way out.
var last_dungeon_failed: bool = false
var last_dungeon_left: bool = false

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

	func get_approval(npc_id: StringName) -> int:
		return _game_state.approvals.get_approval(npc_id)

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
		var key_str = str(key)
		# Quest objective progress: "quest_objective_progress:quest_id:obj_id:op:value"
		if key_str.begins_with("quest_objective_progress:"):
			var parts = key_str.split(":")
			if parts.size() >= 5:
				var progress = _game_state.quests.get_objective_progress(StringName(parts[1]), StringName(parts[2]))
				var op = parts[3]
				var target = int(parts[4])
				return _compare_int(progress, op, target)
			return false
		# Quest objective completion: "quest_objective:quest_id:objective_id"
		if key_str.begins_with("quest_objective:"):
			var parts = key_str.split(":")
			if parts.size() >= 3:
				return _game_state.quests.is_objective_complete(StringName(parts[1]), StringName(parts[2]))
			return false
		# Fight won at least once: "encounter_won:<CombatEncounter.encounter_id>"
		if key_str.begins_with("encounter_won:"):
			var enc_id: String = key_str.substr("encounter_won:".length())
			return GameManager != null and GameManager.has_completed_encounter(enc_id)
		match key_str:
			"last_combat_won": return _game_state.last_combat_won
			"last_combat_lost": return not _game_state.last_combat_won
			"last_dungeon_cleared": return _game_state.last_dungeon_cleared
			"last_dungeon_failed": return _game_state.last_dungeon_failed
			"last_dungeon_left": return _game_state.last_dungeon_left
		push_warning("Custom condition '%s' not implemented" % key)
		return false

	func _compare_int(value: int, op: String, target: int) -> bool:
		match op:
			"==": return value == target
			"!=": return value != target
			">":  return value > target
			"<":  return value < target
			">=": return value >= target
			"<=": return value <= target
		return false
