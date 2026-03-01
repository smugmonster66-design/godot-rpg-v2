# res://scripts/autoload/map_manager.gd
# Manages the world map: location definitions, travel logic, unlock checking.
# Works with LocationNode definitions and MapProgress (via GameState).
extends Node

# ============================================================================
# SIGNALS
# ============================================================================
signal location_entered(location_id: StringName, location: LocationNode, first_visit: bool)
signal location_unlocked(location_id: StringName, location: LocationNode)
signal location_revealed(location_id: StringName, location: LocationNode)
signal travel_blocked(from_id: StringName, to_id: StringName, reason: String)

# ============================================================================
# LOCATION DEFINITIONS REGISTRY
# ============================================================================
## All loaded location definitions: { location_id: LocationNode }
var _locations: Dictionary = {}

## Path to location definition resources
const LOCATIONS_PATH := "res://resources/definitions/locations/"

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_load_all_locations()
	_connect_signals()
	print("MapManager ready - %d locations loaded" % _locations.size())

func _load_all_locations():
	"""Load all location definitions from the locations folder."""
	var dir = DirAccess.open(LOCATIONS_PATH)
	if dir == null:
		push_warning("MapManager: Locations folder not found: %s" % LOCATIONS_PATH)
		return
	
	_load_locations_recursive(LOCATIONS_PATH)

func _load_locations_recursive(path: String):
	"""Recursively load locations from a directory."""
	var dir = DirAccess.open(path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_load_locations_recursive(full_path)
		elif file_name.ends_with(".tres"):
			var location = load(full_path) as LocationNode
			if location and location.location_id != &"":
				_locations[location.location_id] = location
		file_name = dir.get_next()
	dir.list_dir_end()

func _connect_signals():
	"""Connect to GameState.map signals."""
	GameState.map.location_visited.connect(_on_location_visited)
	GameState.map.location_unlocked.connect(_on_location_unlocked)
	GameState.map.location_revealed.connect(_on_location_revealed)

# ============================================================================
# LOCATION ACCESS
# ============================================================================

func get_location(location_id: StringName) -> LocationNode:
	"""Get a location definition by ID."""
	return _locations.get(location_id)

func get_all_locations() -> Array[LocationNode]:
	"""Get all location definitions."""
	var result: Array[LocationNode] = []
	for loc in _locations.values():
		result.append(loc)
	return result

func get_locations_in_region(region_id: StringName) -> Array[LocationNode]:
	"""Get all locations in a region."""
	var result: Array[LocationNode] = []
	for loc in _locations.values():
		if loc.region_id == region_id:
			result.append(loc)
	return result

func register_location(location: LocationNode) -> void:
	"""Register a location at runtime."""
	if location and location.location_id != &"":
		_locations[location.location_id] = location

# ============================================================================
# CURRENT LOCATION
# ============================================================================

func get_current_location() -> LocationNode:
	"""Get the current location definition."""
	return get_location(GameState.map.current_location)

func get_current_location_id() -> StringName:
	"""Get the current location ID."""
	return GameState.map.current_location

# ============================================================================
# TRAVEL
# ============================================================================

func can_travel_to(location_id: StringName) -> bool:
	"""Check if the player can travel to a location."""
	var location = get_location(location_id)
	if location == null:
		return false
	
	# Must be unlocked
	if not GameState.map.is_unlocked(location_id):
		return false
	
	# Must be connected to current location (or current is empty for initial placement)
	var current_id = GameState.map.current_location
	if current_id != &"":
		var current_location = get_location(current_id)
		if current_location and not current_location.has_connection_to(location_id):
			return false
	
	return true

func travel_to(location_id: StringName) -> bool:
	"""
	Travel to a location. Returns true if successful.
	Handles first visit events, dialogue triggers, etc.
	"""
	if not can_travel_to(location_id):
		var location = get_location(location_id)
		if location:
			travel_blocked.emit(GameState.map.current_location, location_id, 
				location.get_locked_hint() if not GameState.map.is_unlocked(location_id) else "Not connected")
		return false
	
	var first_visit = not GameState.map.has_visited(location_id)
	var location = get_location(location_id)
	
	# Move to the location
	GameState.map.set_current_location(location_id)
	
	# Handle first visit
	if first_visit and location:
		_handle_first_visit(location)
	elif location:
		_handle_visit(location)
	
	# Auto-unlock connected locations
	_unlock_connected_locations(location_id)
	
	location_entered.emit(location_id, location, first_visit)
	return true

func _handle_first_visit(location: LocationNode) -> void:
	"""Handle first visit to a location."""
	# Set flags
	for flag_name in location.set_flags_on_visit:
		GameState.set_flag(flag_name, true)
	
	# Fire first visit events
	for event_tag in location.on_first_visit_events:
		_fire_event(event_tag)
	
	# Trigger first visit dialogue if set
	if location.first_visit_dialogue != &"":
		_trigger_dialogue(location.first_visit_dialogue)
	
	# Report to quest system
	QuestManager.report_visit(location.location_id)

func _handle_visit(location: LocationNode) -> void:
	"""Handle subsequent visits to a location."""
	# Fire visit events
	for event_tag in location.on_visit_events:
		_fire_event(event_tag)
	
	# Trigger visit dialogue if set
	if location.visit_dialogue != &"":
		_trigger_dialogue(location.visit_dialogue)

func _unlock_connected_locations(from_location_id: StringName) -> void:
	"""Unlock locations connected to the given location (if their conditions are met)."""
	var location = get_location(from_location_id)
	if location == null:
		return
	
	for connected_id in location.get_all_connections():
		var connected = get_location(connected_id)
		if connected == null:
			continue
		
		# Check if already unlocked
		if GameState.map.is_unlocked(connected_id):
			continue
		
		# Check unlock condition
		if connected.unlock_condition == null or connected.unlock_condition.is_empty():
			# No condition - unlock if revealed
			if _should_be_revealed(connected):
				GameState.map.unlock(connected_id)
		elif GameState.evaluate_condition(connected.unlock_condition):
			GameState.map.unlock(connected_id)
		else:
			# Can't unlock, but maybe reveal?
			if _should_be_revealed(connected):
				GameState.map.reveal(connected_id)

# ============================================================================
# VISIBILITY & UNLOCK CHECKING
# ============================================================================

func check_location_visibility(location_id: StringName) -> bool:
	"""Check if a location should be visible on the map."""
	var location = get_location(location_id)
	if location == null:
		return false
	
	# Already revealed?
	if GameState.map.is_revealed(location_id):
		return true
	
	return _should_be_revealed(location)

func _should_be_revealed(location: LocationNode) -> bool:
	"""Check if a location should be revealed based on its visibility settings."""
	match location.initial_visibility:
		LocationNode.VisibilityState.VISIBLE:
			return true
		LocationNode.VisibilityState.FOG:
			return true  # Shown as "?" but visible
		LocationNode.VisibilityState.HIDDEN:
			# Check reveal condition
			if location.reveal_condition and not location.reveal_condition.is_empty():
				return GameState.evaluate_condition(location.reveal_condition)
			return false
	return false

func check_location_unlock(location_id: StringName) -> bool:
	"""Check if a location can be unlocked."""
	var location = get_location(location_id)
	if location == null:
		return false
	
	# Already unlocked?
	if GameState.map.is_unlocked(location_id):
		return true
	
	# Check unlock condition
	if location.unlock_condition == null or location.unlock_condition.is_empty():
		return true  # No condition = unlockable
	
	return GameState.evaluate_condition(location.unlock_condition)

func get_unlock_blockers(location_id: StringName) -> String:
	"""Get human-readable reason why a location is locked."""
	var location = get_location(location_id)
	if location == null:
		return "Unknown location"
	
	if GameState.map.is_unlocked(location_id):
		return ""  # Not locked
	
	return location.get_locked_hint()

# ============================================================================
# MAP STATE REFRESH
# ============================================================================

func refresh_all_visibility() -> void:
	"""
	Re-check visibility and unlock status for all locations.
	Call after major state changes (quest complete, level up, etc.).
	"""
	for location_id in _locations:
		var location = get_location(location_id)
		if location == null:
			continue
		
		# Check reveal
		if not GameState.map.is_revealed(location_id):
			if _should_be_revealed(location):
				GameState.map.reveal(location_id)
		
		# Check unlock (only for revealed locations)
		if GameState.map.is_revealed(location_id) and not GameState.map.is_unlocked(location_id):
			if check_location_unlock(location_id):
				GameState.map.unlock(location_id)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_location_visited(location_id: StringName):
	pass  # Handled in travel_to

func _on_location_unlocked(location_id: StringName):
	var location = get_location(location_id)
	if location:
		location_unlocked.emit(location_id, location)

func _on_location_revealed(location_id: StringName):
	var location = get_location(location_id)
	if location:
		location_revealed.emit(location_id, location)

# ============================================================================
# HELPERS
# ============================================================================

func _fire_event(event_tag: StringName) -> void:
	"""Fire a game event."""
	# TODO: Connect to your event system
	print("MapManager: Event fired - %s" % event_tag)

func _trigger_dialogue(dialogue_id: StringName) -> void:
	"""Trigger a dialogue encounter."""
	# TODO: Connect to dialogue system
	# var encounter = load("res://resources/dialogues/%s.tres" % dialogue_id)
	# DialogueManager.start_dialogue(encounter)
	print("MapManager: Dialogue triggered - %s" % dialogue_id)

# ============================================================================
# UI HELPERS
# ============================================================================

func get_available_destinations() -> Array[Dictionary]:
	"""Get all locations the player can currently travel to."""
	var current = get_current_location()
	if current == null:
		return []
	
	var result: Array[Dictionary] = []
	for connected_id in current.get_all_connections():
		var connected = get_location(connected_id)
		if connected == null:
			continue
		
		var is_unlocked = GameState.map.is_unlocked(connected_id)
		var is_revealed = GameState.map.is_revealed(connected_id)
		var is_visited = GameState.map.has_visited(connected_id)
		
		if is_revealed:
			result.append({
				"location_id": connected_id,
				"name": connected.get_display_name() if is_visited else "???",
				"type": connected.node_type,
				"unlocked": is_unlocked,
				"visited": is_visited,
				"locked_hint": connected.get_locked_hint() if not is_unlocked else "",
				"recommended_level": connected.recommended_level,
				"position": connected.map_position
			})
	
	return result

func get_location_info(location_id: StringName) -> Dictionary:
	"""Get display info for a location."""
	var location = get_location(location_id)
	if location == null:
		return {}
	
	var is_visited = GameState.map.has_visited(location_id)
	
	return {
		"location_id": location_id,
		"name": location.get_display_name(),
		"description": location.description if is_visited else "",
		"type": location.node_type,
		"region": location.region_id,
		"unlocked": GameState.map.is_unlocked(location_id),
		"revealed": GameState.map.is_revealed(location_id),
		"visited": is_visited,
		"visit_count": GameState.map.get_visit_count(location_id),
		"has_shops": location.has_shops(),
		"has_npcs": location.has_npcs(),
		"allows_rest": location.allows_rest,
		"safe_zone": location.safe_zone,
		"recommended_level": location.recommended_level,
		"position": location.map_position
	}
