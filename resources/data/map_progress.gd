# res://resources/data/map_progress.gd
# Runtime state for map exploration. This IS saved data.
# Tracks which locations are visited, unlocked, revealed.
extends Resource
class_name MapProgress

signal location_visited(location_id: StringName)
signal location_unlocked(location_id: StringName)
signal location_revealed(location_id: StringName)
signal current_location_changed(old_location: StringName, new_location: StringName)

# ============================================================================
# CURRENT POSITION
# ============================================================================
## Where the player currently is
@export var current_location: StringName = &""

## Stack of previous locations for "back" functionality
@export var location_history: Array[StringName] = []

# ============================================================================
# EXPLORATION STATE
# ============================================================================
## Locations the player has visited at least once
@export var visited_locations: Dictionary = {}  # StringName -> true

## Locations that are unlocked (can travel to)
@export var unlocked_locations: Dictionary = {}  # StringName -> true

## Locations that are revealed (visible on map, even if locked)
@export var revealed_locations: Dictionary = {}  # StringName -> true

## Visit counts per location
@export var visit_counts: Dictionary = {}  # StringName -> int

## First visit timestamps
@export var first_visit_times: Dictionary = {}  # StringName -> float (unix time)

# ============================================================================
# API - QUERIES
# ============================================================================

func has_visited(location_id: StringName) -> bool:
	"""Check if player has ever visited a location."""
	return visited_locations.get(location_id, false)

func is_unlocked(location_id: StringName) -> bool:
	"""Check if player can travel to a location."""
	return unlocked_locations.get(location_id, false)

func is_revealed(location_id: StringName) -> bool:
	"""Check if location is visible on the map."""
	return revealed_locations.get(location_id, false)

func get_visit_count(location_id: StringName) -> int:
	"""Get how many times a location has been visited."""
	return visit_counts.get(location_id, 0)

func get_first_visit_time(location_id: StringName) -> float:
	"""Get unix timestamp of first visit (0 if never visited)."""
	return first_visit_times.get(location_id, 0.0)

func is_at(location_id: StringName) -> bool:
	"""Check if player is currently at a location."""
	return current_location == location_id

# ============================================================================
# API - MUTATIONS
# ============================================================================

func set_current_location(location_id: StringName) -> void:
	"""Move player to a location. Automatically marks as visited/unlocked."""
	var old_location = current_location
	
	# Add to history if we're leaving somewhere
	if old_location != &"" and old_location != location_id:
		location_history.append(old_location)
		# Keep history reasonable
		if location_history.size() > 50:
			location_history.pop_front()
	
	current_location = location_id
	
	# Auto-reveal and unlock
	reveal(location_id)
	unlock(location_id)
	
	# Mark as visited
	if not has_visited(location_id):
		visited_locations[location_id] = true
		first_visit_times[location_id] = Time.get_unix_time_from_system()
		location_visited.emit(location_id)
	
	# Increment visit count
	visit_counts[location_id] = get_visit_count(location_id) + 1
	
	current_location_changed.emit(old_location, location_id)

func unlock(location_id: StringName) -> void:
	"""Unlock a location for travel."""
	if not is_unlocked(location_id):
		unlocked_locations[location_id] = true
		reveal(location_id)  # Unlocking also reveals
		location_unlocked.emit(location_id)

func reveal(location_id: StringName) -> void:
	"""Reveal a location on the map (but don't unlock it)."""
	if not is_revealed(location_id):
		revealed_locations[location_id] = true
		location_revealed.emit(location_id)

func lock(location_id: StringName) -> void:
	"""Lock a location (prevent travel). Does not hide it."""
	unlocked_locations.erase(location_id)

func hide(location_id: StringName) -> void:
	"""Hide a location from the map. Also locks it."""
	revealed_locations.erase(location_id)
	unlocked_locations.erase(location_id)

func go_back() -> StringName:
	"""Return to previous location. Returns the location moved to, or empty if no history."""
	if location_history.is_empty():
		return &""
	var previous = location_history.pop_back()
	set_current_location(previous)
	return previous

# ============================================================================
# BULK OPERATIONS
# ============================================================================

func unlock_all(location_ids: Array[StringName]) -> void:
	"""Unlock multiple locations at once."""
	for loc_id in location_ids:
		unlock(loc_id)

func reveal_all(location_ids: Array[StringName]) -> void:
	"""Reveal multiple locations at once."""
	for loc_id in location_ids:
		reveal(loc_id)

func get_visited_locations() -> Array[StringName]:
	"""Get list of all visited location IDs."""
	var result: Array[StringName] = []
	for key in visited_locations.keys():
		result.append(key)
	return result

func get_unlocked_locations() -> Array[StringName]:
	"""Get list of all unlocked location IDs."""
	var result: Array[StringName] = []
	for key in unlocked_locations.keys():
		result.append(key)
	return result

func get_revealed_locations() -> Array[StringName]:
	"""Get list of all revealed location IDs."""
	var result: Array[StringName] = []
	for key in revealed_locations.keys():
		result.append(key)
	return result
