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
signal quest_auto_completed(quest_id: StringName, definition: QuestDefinition)
signal quest_failed(quest_id: StringName, definition: QuestDefinition)

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
	# Defer availability check so notification display UI is connected first
	check_all_quest_availability.call_deferred()
	# Time limits and repeat cooldowns are checked every couple of seconds.
	var timer := Timer.new()
	timer.name = "QuestClock"
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_on_quest_clock)
	add_child(timer)
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
	# Persistent autoloads — connect directly
	GameState.flag_changed.connect(_on_state_changed)
	# A new or loaded game replaces the whole journal: re-check availability.
	GameState.state_loaded.connect(check_all_quest_availability)
	GameState.counter_changed.connect(_on_counter_changed)
	GameState.relationship_changed.connect(_on_relationship_changed)
	MapManager.location_entered.connect(_on_location_entered)
	DialogueManager.event_triggered.connect(_on_dialogue_event)

	# Wire quest signals to NotificationManager
	quest_became_available.connect(_notify_quest_available)
	quest_objectives_updated.connect(_notify_quest_updated)
	quest_ready_for_turn_in.connect(_notify_quest_ready)
	quest_auto_completed.connect(_notify_quest_auto_completed)
	quest_failed.connect(_notify_quest_failed)

# ============================================================================
# GAME EVENT HANDLERS
# ============================================================================

func _on_state_changed(_flag_name: StringName, _value: bool) -> void:
	"""When flags change, check if new quests became available (or failed)."""
	check_all_quest_availability()
	_check_failures()

func _on_counter_changed(_counter_name: StringName, _old_value: int, _new_value: int) -> void:
	"""When counters change, check if new quests became available (or failed)."""
	check_all_quest_availability()
	_check_failures()

func _on_relationship_changed(_npc_id: StringName, _old_value: int, _new_value: int) -> void:
	"""When relationships change, check if companion quests unlocked (or failed)."""
	check_all_quest_availability()
	_check_failures()

# ============================================================================
# FAILURE, TIME LIMITS, REPEATING
# ============================================================================

func _on_quest_clock() -> void:
	if not GameState.session_active:
		return
	_check_failures()
	_check_repeats()

func _check_failures() -> void:
	"""Fail active quests whose fail_condition is true or whose time_limit
	(seconds of play time since accepting) has run out. Only quests with
	can_fail = true can fail."""
	var now: float = GameState.get_play_time()
	for quest_id in GameState.quests.get_active_quests():
		var definition = get_definition(quest_id)
		if definition == null or not definition.can_fail:
			continue
		var progress = GameState.quests.get_progress(quest_id)
		var failed := false
		if definition.fail_condition and not definition.fail_condition.is_empty():
			failed = GameState.evaluate_condition(definition.fail_condition)
		if not failed and definition.time_limit > 0.0 and progress.accepted_play_time > 0.0:
			failed = now - progress.accepted_play_time >= definition.time_limit
		if failed:
			fail_quest(quest_id)

func fail_quest(quest_id: StringName) -> bool:
	"""Fail an active quest: fires on_fail_events and notifies. Repeatable
	quests come back after their cooldown."""
	var definition = get_definition(quest_id)
	if definition == null:
		return false
	if not GameState.quests.fail_quest(quest_id):
		return false
	_mark_ended(quest_id)
	for event_tag in definition.on_fail_events:
		_fire_event(event_tag)
	quest_failed.emit(quest_id, definition)
	return true

func _check_repeats() -> void:
	"""Make repeatable quests available again once repeat_cooldown seconds of
	play time have passed since they were completed or failed."""
	var now: float = GameState.get_play_time()
	for quest_id in _definitions:
		var definition: QuestDefinition = _definitions[quest_id]
		if not definition.repeatable:
			continue
		var progress = GameState.quests.get_progress(quest_id)
		if progress.state != QuestProgress.QuestState.COMPLETE and progress.state != QuestProgress.QuestState.FAILED:
			continue
		if now - progress.ended_play_time < definition.repeat_cooldown:
			continue
		if not check_quest_availability(quest_id):
			continue
		var old_state = progress.state
		progress.reset_progress()
		GameState.quests.quest_state_changed.emit(quest_id, old_state, progress.state)
		quest_became_available.emit(quest_id, definition)

func _mark_ended(quest_id: StringName) -> void:
	GameState.quests.get_progress(quest_id).ended_play_time = GameState.get_play_time()

func is_quest_listed(quest_id: StringName) -> bool:
	"""False for quests that should stay out of the quest log and notifications
	for now (hidden_until_accepted and not yet accepted)."""
	var definition = get_definition(quest_id)
	if definition == null:
		return false
	if definition.hidden_until_accepted:
		var state = GameState.quests.get_state(quest_id)
		return state != QuestProgress.QuestState.LOCKED and state != QuestProgress.QuestState.AVAILABLE
	return true

func _on_location_entered(location_id: StringName, _location: LocationNode, _first_visit: bool) -> void:
	"""When player enters a location, report VISIT objective progress."""
	report_visit(location_id)

func _on_dialogue_event(event_tag: StringName) -> void:
	"""Route dialogue events with quest: prefix to appropriate handlers."""
	var tag_str: String = String(event_tag)
	if not tag_str.begins_with("quest:"):
		return

	var parts: PackedStringArray = tag_str.split(":")
	if parts.size() < 3:
		push_warning("QuestManager: Malformed quest event tag: %s" % tag_str)
		return

	var action: String = parts[1]
	var target: StringName = StringName(parts[2])

	match action:
		"accept":
			make_quest_available(target)
			try_accept_quest(target)
		"talk":
			report_talk_to(target)
		"interact":
			report_interact(target)
		"collect":
			report_collect(target)
		"complete":
			try_complete_quest(target)
		"custom":
			report_custom(target)
		_:
			push_warning("QuestManager: Unknown quest event action: %s" % action)

## Called by GameRoot/GameManager after combat ends with a victory.
## Iterates defeated enemies and reports kills by tag and derived ID.
func report_combat_kills(enemies: Array) -> void:
	"""Report kills for all defeated enemies. Each enemy reports by tags and resource name."""
	for enemy_data in enemies:
		if enemy_data == null:
			continue
		# Report by each tag (e.g., "naval", "humanoid")
		if enemy_data.enemy_tags:
			for tag in enemy_data.enemy_tags:
				report_kill(StringName(tag))
		# Report by resource file name as a fallback ID
		var path: String = enemy_data.resource_path
		if path != "":
			var file_id: String = path.get_file().get_basename()
			report_kill(StringName(file_id))

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
	GameState.quests.get_progress(quest_id).accepted_play_time = GameState.get_play_time()

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
	_mark_ended(quest_id)

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

	For KILL objectives, also matches against the objective's track_tag field,
	allowing tag-based matching (e.g., "naval" matches any enemy with that tag).
	"""
	for quest_id in GameState.quests.get_active_quests():
		var definition = get_definition(quest_id)
		if definition == null:
			continue

		var progress_made = false
		for objective in definition.objectives:
			if objective.objective_type != objective_type:
				continue
			# Match by target_id OR by track_tag (for tag-based kill tracking).
			# SURVIVE with an empty target counts any fight.
			var matches: bool = objective.target_id == target_id
			if objective_type == QuestObjective.ObjectiveType.SURVIVE and objective.target_id == &"":
				matches = true
			if not matches and objective.track_tag != &"" and objective.track_tag == target_id:
				matches = true
			if matches and not GameState.quests.is_objective_complete(quest_id, objective.objective_id):
				# Check prerequisite objectives are complete before allowing progress
				if not _prerequisites_met(quest_id, objective):
					continue
				GameState.quests.update_objective(quest_id, objective.objective_id, count)
				_check_objective_completion(quest_id, objective)
				progress_made = true

		if progress_made:
			quest_objectives_updated.emit(quest_id, definition)
			_check_quest_ready_for_turn_in(quest_id)

func report_talk_to(npc_id: StringName) -> void:
	"""Report talking to an NPC. Auto-checks TALK_TO objectives, and DELIVER
	objectives whose recipient (target_id) is this NPC."""
	report_objective_progress(QuestObjective.ObjectiveType.TALK_TO, npc_id, 1)
	_report_deliveries(npc_id)

func _report_deliveries(npc_id: StringName) -> void:
	"""DELIVER: target_id = recipient npc_id; track_tag = the item's display
	name (optional). If an item is named, the player must carry required_count
	of it, and they're taken on delivery. With no item named, talking to the
	recipient completes it."""
	for quest_id in GameState.quests.get_active_quests():
		var definition = get_definition(quest_id)
		if definition == null:
			continue
		for objective in definition.objectives:
			if objective.objective_type != QuestObjective.ObjectiveType.DELIVER:
				continue
			if objective.target_id != npc_id:
				continue
			if GameState.quests.is_objective_complete(quest_id, objective.objective_id):
				continue
			if not _prerequisites_met(quest_id, objective):
				continue
			var needed: int = max(1, objective.required_count) - GameState.quests.get_objective_progress(quest_id, objective.objective_id)
			if objective.track_tag != &"":
				var item_name := String(objective.track_tag)
				var have: int = GameState.create_condition_context().get_item_count(objective.track_tag) + _count_consumables(item_name)
				if have < needed:
					continue
				ItemGrant.remove_by_name(item_name, needed)
			report_objective_by_id(quest_id, objective.objective_id, needed)

func _count_consumables(item_name: String) -> int:
	var n := 0
	if GameManager and GameManager.player:
		for c in GameManager.player.consumables:
			if c and c.item_name == item_name:
				n += c.current_stack
	return n

func report_combat_won(encounter: Resource) -> void:
	"""SURVIVE: counts fights won. target_id = a CombatEncounter file name
	(e.g. keel_brawl) to count only that fight, or empty to count any fight."""
	var enc_id: StringName = &""
	if encounter and encounter.resource_path != "":
		enc_id = StringName(encounter.resource_path.get_file().get_basename())
	report_objective_progress(QuestObjective.ObjectiveType.SURVIVE, enc_id, 1)

func report_kill(enemy_type: StringName, count: int = 1) -> void:
	"""Report killing enemies. Auto-checks KILL objectives."""
	report_objective_progress(QuestObjective.ObjectiveType.KILL, enemy_type, count)

func report_collect(item_id: StringName, count: int = 1) -> void:
	"""Report collecting items. Auto-checks COLLECT objectives."""
	report_objective_progress(QuestObjective.ObjectiveType.COLLECT, item_id, count)

func report_visit(location_id: StringName) -> void:
	"""Report visiting a location. Auto-checks VISIT objectives, and ESCORT
	objectives whose destination (target_id) is this location."""
	report_objective_progress(QuestObjective.ObjectiveType.VISIT, location_id, 1)
	report_objective_progress(QuestObjective.ObjectiveType.ESCORT, location_id, 1)

func report_interact(interaction_id: StringName) -> void:
	"""Report interacting with something. Auto-checks INTERACT objectives."""
	report_objective_progress(QuestObjective.ObjectiveType.INTERACT, interaction_id, 1)

func report_custom(custom_id: StringName, count: int = 1) -> void:
	"""Report a custom objective event. Auto-checks CUSTOM objectives."""
	report_objective_progress(QuestObjective.ObjectiveType.CUSTOM, custom_id, count)

func report_objective_by_id(quest_id: StringName, objective_id: StringName, count: int = 1) -> void:
	"""Directly report progress on a specific objective by quest_id and objective_id."""
	var definition = get_definition(quest_id)
	if definition == null:
		push_warning("QuestManager: Unknown quest: %s" % quest_id)
		return
	var progress = GameState.quests.get_progress(quest_id)
	if progress.state != QuestProgress.QuestState.ACTIVE:
		return
	var obj = definition.get_objective(objective_id)
	if obj == null:
		push_warning("QuestManager: Unknown objective '%s' in quest '%s'" % [objective_id, quest_id])
		return
	if GameState.quests.is_objective_complete(quest_id, objective_id):
		return
	GameState.quests.update_objective(quest_id, objective_id, count)
	_check_objective_completion(quest_id, obj)
	quest_objectives_updated.emit(quest_id, definition)
	_check_quest_ready_for_turn_in(quest_id)

# ============================================================================
# INTERNAL HELPERS
# ============================================================================

func _prerequisites_met(quest_id: StringName, objective: QuestObjective) -> bool:
	"""Check if all prerequisite objectives for this objective are complete."""
	if objective.prerequisite_objectives.is_empty():
		return true
	for prereq_id in objective.prerequisite_objectives:
		if not GameState.quests.is_objective_complete(quest_id, prereq_id):
			return false
	return true

func _check_objective_completion(quest_id: StringName, objective: QuestObjective) -> void:
	"""Check if a specific objective is now complete."""
	var current = GameState.quests.get_objective_progress(quest_id, objective.objective_id)
	if current >= objective.required_count:
		GameState.quests.complete_objective(quest_id, objective.objective_id)
		_notify_objective_completed(quest_id, objective)

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
	"""Check if quest should transition to ready-for-turn-in or auto-complete."""
	if _check_all_objectives_complete(quest_id):
		var progress = GameState.quests.get_progress(quest_id)
		if progress.state == QuestProgress.QuestState.ACTIVE:
			var definition = get_definition(quest_id)
			if definition and definition.auto_complete:
				# Auto-complete: skip READY_TO_TURN_IN, go straight to COMPLETE
				_grant_rewards(definition.rewards)
				GameState.quests.complete_quest(quest_id)
				_mark_ended(quest_id)
				for event_tag in definition.on_complete_events:
					_fire_event(event_tag)
				GameState.counters.increment(&"quests_completed")
				quest_auto_completed.emit(quest_id, definition)
			else:
				GameState.quests.set_ready_to_turn_in(quest_id)
				quest_ready_for_turn_in.emit(quest_id, definition)

func _grant_rewards(rewards: QuestRewards) -> void:
	"""Grant quest rewards to the player."""
	if rewards == null:
		return

	# XP
	if rewards.experience > 0:
		GameManager.player.add_experience(rewards.experience)

	# Gold
	if rewards.gold > 0:
		GameManager.player.add_gold(rewards.gold)

	# Items
	for template in rewards.reward_items:
		if template:
			ItemGrant.grant(template, 1, rewards.reward_item_level)
	for item_reward in rewards.items:  # legacy inner-class rewards (code-built only)
		if item_reward and item_reward.item_resource:
			ItemGrant.grant(item_reward.item_resource, max(1, item_reward.quantity), rewards.reward_item_level)

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

	# Counter changes (morality, etc.)
	for counter_name in rewards.counter_changes:
		var delta = rewards.counter_changes[counter_name]
		GameState.counters.increment(counter_name, delta)

func _notify_quest_available(quest_id: StringName, definition: QuestDefinition) -> void:
	if not is_quest_listed(quest_id):
		return
	NotificationManager.notify_quest_available(definition.get_display_name())

func _notify_quest_failed(_quest_id: StringName, definition: QuestDefinition) -> void:
	NotificationManager.notify("Quest Failed: %s" % definition.get_display_name(), &"quest")

func _notify_objective_completed(_quest_id: StringName, completed_obj: QuestObjective) -> void:
	"""Show strikethrough notification for the completed objective."""
	var completed_text = completed_obj.get_display_description(completed_obj.required_count)
	NotificationManager.notify_objective_complete(completed_text)

func _notify_quest_updated(quest_id: StringName, definition: QuestDefinition) -> void:
	# Build a summary of objective progress for the notification
	# Skip if an objective was just completed (handled by _notify_objective_completed)
	var progress = GameState.quests.get_progress(quest_id)
	for obj in definition.objectives:
		if not obj.notify_on_progress:
			continue
		if progress.is_objective_complete(obj.objective_id):
			continue
		var current: int = progress.get_objective_progress(obj.objective_id)
		NotificationManager.notify_quest_updated(obj.get_display_description(current))
		break  # Only show one objective update per notification

func _notify_quest_ready(_quest_id: StringName, definition: QuestDefinition) -> void:
	NotificationManager.notify_quest_updated("Ready to turn in: %s" % definition.get_display_name())

func _notify_quest_auto_completed(_quest_id: StringName, definition: QuestDefinition) -> void:
	NotificationManager.notify_quest_complete(definition.get_display_name())

func _fire_event(event_tag: StringName) -> void:
	"""Fire a game event via GameEventBus."""
	GameEventBus.emit_custom(String(event_tag))
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

func npc_has_available_quest(npc_id: StringName) -> bool:
	"""Check if an NPC has a quest available for the player to accept."""
	for quest_id in _definitions:
		var def: QuestDefinition = _definitions[quest_id]
		if def.quest_giver_id != npc_id:
			continue
		var state = GameState.quests.get_state(quest_id)
		if state == QuestProgress.QuestState.AVAILABLE:
			return true
	return false

func npc_has_turn_in(npc_id: StringName) -> bool:
	"""Check if an NPC has a quest ready for turn-in."""
	for quest_id in _definitions:
		var def: QuestDefinition = _definitions[quest_id]
		var turn_in: StringName = def.get_turn_in_npc()
		if turn_in != npc_id:
			continue
		var state = GameState.quests.get_state(quest_id)
		if state == QuestProgress.QuestState.READY_TO_TURN_IN:
			return true
	return false

func npc_has_quest_indicator(npc_id: StringName) -> bool:
	"""Check if an NPC should show any quest indicator (available or turn-in)."""
	return npc_has_available_quest(npc_id) or npc_has_turn_in(npc_id)

func get_quest_display_info(quest_id: StringName) -> Dictionary:
	"""Get all info needed to display a quest in the UI."""
	var definition = get_definition(quest_id)
	var progress = GameState.quests.get_progress(quest_id)

	if definition == null:
		return {}

	var objectives_info: Array[Dictionary] = []
	var previous_complete := true
	for obj in definition.objectives:
		var obj_progress = progress.get_objective_progress(obj.objective_id)
		var obj_complete = progress.is_objective_complete(obj.objective_id)
		# hidden_until_previous: don't reveal this objective until the one
		# listed before it is complete.
		var hide_it: bool = obj.hidden_until_previous and not previous_complete
		previous_complete = obj_complete
		if hide_it:
			continue
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
		"turn_in_location": definition.get_turn_in_location(),
		"sort_priority": definition.sort_priority,
		"recommended_level": definition.recommended_level,
		"auto_complete": definition.auto_complete
	}
