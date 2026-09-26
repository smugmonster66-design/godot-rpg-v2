# res://scripts/autoload/npc_manager.gd
# Registry for all NPCDefinition resources. Resolves which NPCs are at a
# given location, evaluates dialogue tables, and tracks seen encounters.
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when an encounter is marked as seen (npc_id, encounter_id).
signal encounter_seen(npc_id: StringName, encounter_id: StringName)

# ============================================================================
# CONSTANTS
# ============================================================================

const NPC_ROOT := "res://resources/npcs/"

# ============================================================================
# INTERNAL STATE
# ============================================================================

## All loaded NPCs keyed by npc_id.
var _npcs: Dictionary = {}  # StringName → NPCDefinition

## NPCs indexed by home_location_id for fast lookup.
var _npcs_by_location: Dictionary = {}  # StringName → Array[NPCDefinition]

## Tracks which encounter_ids each NPC has shown the player.
## Persisted via SaveData.seen_npc_encounters.
var _seen_encounters: Dictionary = {}  # StringName npc_id → Array[StringName]

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_all_npcs()
	print("NPCManager: Loaded %d NPCs" % _npcs.size())

# ============================================================================
# PUBLIC API — QUERIES
# ============================================================================

func get_npc(npc_id: StringName) -> NPCDefinition:
	"""Get an NPC by its unique ID. Returns null if not found."""
	return _npcs.get(npc_id) as NPCDefinition

func get_all_npcs() -> Array:
	"""Get all registered NPCDefinitions."""
	return _npcs.values()

func get_npcs_at_location(location_id: StringName) -> Array[NPCDefinition]:
	"""Get all NPCs whose home is this location AND whose availability
	condition passes. Returns empty array if none."""
	var result: Array[NPCDefinition] = []
	var candidates: Array = _npcs_by_location.get(location_id, [])
	for npc in candidates:
		var n = npc as NPCDefinition
		if n == null:
			continue
		if n.availability_condition != null and not GameState.evaluate_condition(n.availability_condition):
			continue
		result.append(n)
	return result

# ============================================================================
# PUBLIC API — DIALOGUE TABLE
# ============================================================================

func get_active_encounter(npc: NPCDefinition) -> NPCDialogueEntry:
	"""Evaluate an NPC's dialogue table and return the first matching entry.
	Entries are sorted by priority (descending). Returns null if no match."""
	if npc == null or npc.dialogue_table.is_empty():
		return null

	# Sort by priority descending (stable sort preserves array order for ties)
	var sorted_table: Array[NPCDialogueEntry] = npc.dialogue_table.duplicate()
	sorted_table.sort_custom(func(a, b): return a.priority > b.priority)

	for entry in sorted_table:
		if entry == null:
			continue
		# Skip completed one-shots
		if entry.one_shot and _is_encounter_seen(npc.npc_id, entry.encounter_id):
			continue
		# Check condition
		if entry.condition != null and not GameState.evaluate_condition(entry.condition):
			continue
		return entry

	return null

func get_active_encounters(npc: NPCDefinition) -> Array[NPCDialogueEntry]:
	"""Evaluate an NPC's dialogue table and return all matching entries at the
	highest available priority. Used to populate conversation sub-radial when
	an NPC has multiple available dialogues."""
	var result: Array[NPCDialogueEntry] = []
	if npc == null or npc.dialogue_table.is_empty():
		return result

	# Sort by priority descending (stable sort preserves array order for ties)
	var sorted_table: Array[NPCDialogueEntry] = npc.dialogue_table.duplicate()
	sorted_table.sort_custom(func(a, b): return a.priority > b.priority)

	var highest_priority: int = -999999
	for entry in sorted_table:
		if entry == null:
			continue
		# Skip completed one-shots
		if entry.one_shot and _is_encounter_seen(npc.npc_id, entry.encounter_id):
			continue
		# Check condition
		if entry.condition != null and not GameState.evaluate_condition(entry.condition):
			continue
		# First match sets the highest priority level
		if result.is_empty():
			highest_priority = entry.priority
		# Only include entries at the highest priority level
		if entry.priority < highest_priority:
			break
		result.append(entry)

	return result

func get_encounter_by_id(npc: NPCDefinition, encounter_id: StringName) -> NPCDialogueEntry:
	"""Find a specific dialogue entry by encounter_id. Returns null if not found."""
	if npc == null or encounter_id == &"":
		return null
	for entry in npc.dialogue_table:
		if entry != null and entry.encounter_id == encounter_id:
			return entry
	return null

# ============================================================================
# PUBLIC API — NEW CONTENT TRACKING
# ============================================================================

func has_new_content(npc: NPCDefinition) -> bool:
	"""Returns true if this NPC's active encounter hasn't been seen yet."""
	if npc == null:
		return false
	var entry = get_active_encounter(npc)
	if entry == null:
		return false
	return not _is_encounter_seen(npc.npc_id, entry.encounter_id)

func location_has_new_npc_content(location_id: StringName) -> bool:
	"""Returns true if ANY NPC at this location has unseen content."""
	var npcs = get_npcs_at_location(location_id)
	for npc in npcs:
		if has_new_content(npc):
			return true
	return false

func mark_encounter_seen(npc_id: StringName, encounter_id: StringName) -> void:
	"""Record that the player has seen this encounter."""
	if encounter_id == &"":
		return
	if not _seen_encounters.has(npc_id):
		_seen_encounters[npc_id] = [] as Array[StringName]
	var seen_list: Array = _seen_encounters[npc_id]
	if encounter_id not in seen_list:
		seen_list.append(encounter_id)
		encounter_seen.emit(npc_id, encounter_id)

# ============================================================================
# PERSISTENCE
# ============================================================================

func get_seen_encounters_snapshot() -> Dictionary:
	"""Returns a copy of seen encounters for saving."""
	return _seen_encounters.duplicate(true)

func restore_seen_encounters(data: Dictionary) -> void:
	"""Restore seen encounters from save data."""
	_seen_encounters = data.duplicate(true) if data else {}

func clear_seen_encounters() -> void:
	"""Clear all seen encounter tracking (for new game)."""
	_seen_encounters.clear()

# ============================================================================
# INTERNAL
# ============================================================================

func _is_encounter_seen(npc_id: StringName, encounter_id: StringName) -> bool:
	if encounter_id == &"":
		return false
	var seen_list: Array = _seen_encounters.get(npc_id, [])
	return encounter_id in seen_list

func _load_all_npcs() -> void:
	"""Recursively load all NPCDefinition .tres files from NPC_ROOT."""
	_npcs.clear()
	_npcs_by_location.clear()
	_scan_directory(NPC_ROOT)

func _scan_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			_scan_directory(path.path_join(file_name))
		elif file_name.ends_with(".tres"):
			var full_path = path.path_join(file_name)
			var res = load(full_path)
			if res is NPCDefinition:
				_register_npc(res as NPCDefinition)
		file_name = dir.get_next()
	dir.list_dir_end()

func _register_npc(npc: NPCDefinition) -> void:
	if npc.npc_id == &"":
		push_warning("NPCManager: NPC at '%s' has no npc_id, skipping" % npc.resource_path)
		return
	if _npcs.has(npc.npc_id):
		push_warning("NPCManager: Duplicate npc_id '%s', overwriting" % npc.npc_id)
	_npcs[npc.npc_id] = npc

	# Index by location
	if npc.home_location_id != &"":
		if not _npcs_by_location.has(npc.home_location_id):
			_npcs_by_location[npc.home_location_id] = []
		_npcs_by_location[npc.home_location_id].append(npc)
