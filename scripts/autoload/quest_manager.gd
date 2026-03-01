# res://scripts/autoload/quest_manager.gd
# Manages quest logic: checking prerequisites, updating objectives, granting rewards.
# Works with QuestDefinitions (static data) and QuestJournal (runtime state via GameState).
extends Node

# ============================================================================
# SIGNALS
# ============================================================================
signal quest_became_available(quest_id: StringName, definition: QuestDefinition)
signal quest_objectives_updated(quest_id: StringName, definition: QuestDefinition)
signal quest_ready_for_turn_in(quest_id: StringName, definition: QuestDefinition)

# ============================================================================
# QUEST DEFINITIONS REGISTRY
# ============================================================================
## All loaded quest definitions: { quest_id: QuestDefinition }
var _definitions: Dictionary = {}

## Path to quest definition resources
const QUEST_DEFINITIONS_PATH := "res://resources/definitions/quests/"

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_load_all_definitions()
	_connect_to_game_events()
	print("QuestManager ready - %d quests loaded" % _definitions.size())

func _load_all_definitions():
	"""Load all quest definitions from the quests folder."""
	var dir = DirAccess.open(QUEST_DEFINITIONS_PATH)
	if dir == null:
		push_warning("QuestManager: Quest definitions folder not found: %s" % QUEST_DEFINITIONS_PATH)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path = QUEST_DEFINITIONS_PATH + file_name
			var definition = load(path) as QuestDefinition
			if definition and definition.quest_id != &"":
				_definitions[definition.quest_id] = definition
		file_name = dir.get_next()
	dir.list_dir_end()

func _connect_to_game_events():
	"""Connect to relevant game events for automatic objective tracking."""
	# Example connections - uncomment and adapt to your signals:
	# CombatManager.enemy_defeated.connect(_on_enemy_defeated)
	# DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	# GameState.map.location_visited.connect(_on_location_visited)
	pass

# ============================================================================
# DEFINITION ACCESS
# ============================================================================

func get_definition(quest_id: StringName) -> QuestDefinition:
	"""Get a quest definition by ID."""
	return _definitions.get(quest_id)

func get_all_definitions() -> Array[QuestDefinition]:
	"""Get all quest definitions."""
	var result: Array[QuestDefinition] = []
	for def in _definitions.values():
		result.append(def)
	return result

func register_definition(definition: QuestDefinition) -> void:
	"""Register a quest definition at runtime."""
	if definition and definition.quest_id != &"":
		_definitions[definition.quest_id] = definition

# ============================================================================
# QUEST STATE MANAGEMENT
# ============================================================================

func check_quest_availability(quest_id: StringName) -> bool:
	"""Check if a quest can be made available (prerequisites met)."""
	var definition = get_definition(quest_id)
	if definition == null:
		return false
	
	# Check level requirement
	if definition.required_level > 0:
		if GameState.get_player_level() < definition.required_level:
			return false
	
	# Check prerequisites condition
	if definition.prerequisites and not definition.prerequisites.is_empty():
		if not GameState.evaluate_condition(definition.prerequisites):
			return false
	
	return true

func make_quest_available(quest_id: StringName) -> bool:
	"""Make a quest available if prerequisites are met."""
	if not check_quest_availability(quest_id):
		return false
	
	var progress = GameState.quests.get_progress(quest_id)
	if progress.state != QuestProgress.QuestState.LOCKED:
		return false  # Already available or beyond
	
	GameState.quests.make_available(quest_id)
	quest_became_available.emit(quest_id, get_definition(quest_id))
	return true

func try_accept_quest(quest_id: StringName) -> bool:
	"""Attempt to accept a quest. Returns true if successful."""
	var definition = get_definition(quest_id)
	if definition == null:
		return false
	
	if not GameState.quests.accept_quest(quest_id):
		return false
	
	# Fire accept events
	for event_tag in definition.on_accept_events:
		_fire_event(event_tag)
	
	return true

func try_complete_quest(quest_id: StringName) -> bool:
	"""Attempt to complete/turn-in a quest. Returns true if successful."""
	var definition = get_definition(quest_id)
	if definition == null:
		return false
	
	var progress = GameState.quests.get_progress(quest_id)
	if progress.state != QuestProgress.QuestState.READY_TO_TURN_IN:
		# Check if we should be ready
		if progress.state == QuestProgress.QuestState.ACTIVE:
			if _check_all_objectives_complete(quest_id):
				GameState.quests.set_ready_to_turn_in(quest_id)
			else:
				return false
		else:
			return false
	
	# Grant rewards
	_grant_rewards(definition.rewards)
	
	# Mark complete
	if not GameState.quests.complete_quest(quest_id):
		return false
	
	# Fire complete events
	for event_tag in definition.on_complete_events:
		_fire_event(event_tag)
	
	# Increment counter
	GameState.counters.increment(&"quests_completed")
	
	return true

# ============================================================================
# OBJECTIVE TRACKING
# ============================================================================

func report_objective_progress(objective_type: QuestObjective.ObjectiveType, target_id: StringName, count: int = 1) -> void:
	"""
	Report progress toward objectives of a given type.
	Called by game systems when relevant events occur.
	
	Example:
		QuestManager.report_objective_progress(QuestObjective.ObjectiveType.KILL, &"goblin", 1)
	"""
	# Check all active quests for matching objectives
	for quest_id in GameState.quests.get_active_quests():
		var definition = get_definition(quest_id)
		if definition == null:
			continue
		
		var progress_made = false
		for objective in definition.objectives:
			if objective.objective_type == objective_type and objective.target_id == target_id:
				if not GameState.quests.is_objective_complete(quest_id, objective.objective_id):
					GameState.quests.update_objective(quest_id, objective.objective_id, count)
					_check_objective_completion(quest_id, objective)
					progress_made = true
		
		if progress_made:
			quest_objectives_updated.emit(quest_id, definition)
			_check_quest_ready_for_turn_in(quest_id)

func report_talk_to(npc_id: StringName) -> void:
	"""Report talking to an NPC. Auto-checks TALK_TO objectives."""
	report_objective_progress(QuestObjective.ObjectiveType.TALK_TO, npc_id, 1)

func report_kill(enemy_type: StringName, count: int = 1) -> void:
	"""Report killing enemies. Auto-checks KILL objectives."""
	report_objective_progress(QuestObjective.ObjectiveType.KILL, enemy_type, count)

func report_collect(item_id: StringName, count: int = 1) -> void:
	"""Report collecting items. Auto-checks COLLECT objectives."""
	report_objective_progress(QuestObjective.ObjectiveType.COLLECT, item_id, count)

func report_visit(location_id: StringName) -> void:
	"""Report visiting a location. Auto-checks VISIT objectives."""
	report_objective_progress(QuestObjective.ObjectiveType.VISIT, location_id, 1)

func report_interact(interaction_id: StringName) -> void:
	"""Report interacting with something. Auto-checks INTERACT objectives."""
	report_objective_progress(QuestObjective.ObjectiveType.INTERACT, interaction_id, 1)

# ============================================================================
# INTERNAL HELPERS
# ============================================================================

func _check_objective_completion(quest_id: StringName, objective: QuestObjective) -> void:
	"""Check if a specific objective is now complete."""
	var current = GameState.quests.get_objective_progress(quest_id, objective.objective_id)
	if current >= objective.required_count:
		GameState.quests.complete_objective(quest_id, objective.objective_id)

func _check_all_objectives_complete(quest_id: StringName) -> bool:
	"""Check if all required objectives are complete."""
	var definition = get_definition(quest_id)
	if definition == null:
		return false
	
	for objective in definition.objectives:
		if objective.optional:
			continue
		if not GameState.quests.is_objective_complete(quest_id, objective.objective_id):
			return false
	
	return true

func _check_quest_ready_for_turn_in(quest_id: StringName) -> void:
	"""Check if quest should transition to ready-for-turn-in state."""
	if _check_all_objectives_complete(quest_id):
		var progress = GameState.quests.get_progress(quest_id)
		if progress.state == QuestProgress.QuestState.ACTIVE:
			GameState.quests.set_ready_to_turn_in(quest_id)
			quest_ready_for_turn_in.emit(quest_id, get_definition(quest_id))

func _grant_rewards(rewards: QuestRewards) -> void:
	"""Grant quest rewards to the player."""
	if rewards == null:
		return
	
	# XP
	if rewards.experience > 0:
		# TODO: GameManager.player.add_experience(rewards.experience)
		pass
	
	# Gold
	if rewards.gold > 0:
		# TODO: GameManager.player.add_gold(rewards.gold)
		pass
	
	# Items
	for item_reward in rewards.items:
		# TODO: GameManager.player.inventory.add_item(item_reward.item_id, item_reward.quantity)
		pass
	
	# Unlock flags
	for flag_name in rewards.unlock_flags:
		GameState.set_flag(flag_name, true)
	
	# Unlock locations
	for location_id in rewards.unlock_locations:
		GameState.map.unlock(location_id)
	
	# Unlock quests
	for quest_id in rewards.unlock_quests:
		make_quest_available(quest_id)
	
	# Relationship changes
	for npc_id in rewards.relationship_changes:
		var delta = rewards.relationship_changes[npc_id]
		GameState.modify_relationship(npc_id, delta)

func _fire_event(event_tag: StringName) -> void:
	"""Fire a game event. Hook into your event system."""
	# TODO: Connect to your event system
	# EventBus.fire(event_tag)
	print("QuestManager: Event fired - %s" % event_tag)

# ============================================================================
# QUEST DISCOVERY - Check for newly available quests
# ============================================================================

func check_all_quest_availability() -> Array[StringName]:
	"""
	Check all locked quests to see if any became available.
	Call this after major state changes (level up, quest complete, etc.).
	Returns array of quest_ids that became available.
	"""
	var newly_available: Array[StringName] = []
	
	for quest_id in _definitions:
		var progress = GameState.quests.get_progress(quest_id)
		if progress.state == QuestProgress.QuestState.LOCKED:
			if make_quest_available(quest_id):
				newly_available.append(quest_id)
	
	return newly_available

# ============================================================================
# UI HELPERS
# ============================================================================

func get_quest_display_info(quest_id: StringName) -> Dictionary:
	"""Get all info needed to display a quest in the UI."""
	var definition = get_definition(quest_id)
	var progress = GameState.quests.get_progress(quest_id)
	
	if definition == null:
		return {}
	
	var objectives_info: Array[Dictionary] = []
	for obj in definition.objectives:
		var obj_progress = progress.get_objective_progress(obj.objective_id)
		var obj_complete = progress.is_objective_complete(obj.objective_id)
		objectives_info.append({
			"id": obj.objective_id,
			"description": obj.get_display_description(obj_progress),
			"progress": obj_progress,
			"required": obj.required_count,
			"complete": obj_complete,
			"optional": obj.optional
		})
	
	return {
		"quest_id": quest_id,
		"name": definition.get_display_name(),
		"summary": definition.get_summary(),
		"description": definition.get_description(),
		"type": definition.quest_type,
		"state": progress.state,
		"state_string": GameState.quests.get_state_string(quest_id),
		"objectives": objectives_info,
		"rewards_preview": definition.get_rewards_preview(),
		"quest_giver": definition.quest_giver_id,
		"quest_giver_location": definition.quest_giver_location,
		"turn_in_npc": definition.get_turn_in_npc(),
		"turn_in_location": definition.get_turn_in_location()
	}
