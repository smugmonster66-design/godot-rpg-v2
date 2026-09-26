# res://scripts/autoload/game_event_registry.gd
# Centralized registry for game events defined as resources.
# Scans res://resources/events/ recursively, indexes by event_id,
# and dispatches events with optional auto-applied effects.
extends Node

# ============================================================================
# CONSTANTS
# ============================================================================
const EVENT_ROOT := "res://resources/events/"

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted after every fire_event call (even for unknown IDs).
## Code listeners connect here for custom reactions beyond data-driven effects.
signal event_fired(event_id: StringName)

# ============================================================================
# STATE
# ============================================================================
var _events: Dictionary = {}  # StringName → GameEventDefinition
var _categories: Dictionary = {}  # String (folder) → Array[StringName] (event_ids)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_all_events()
	print("[GameEventRegistry] Loaded %d event definitions" % _events.size())

func _load_all_events() -> void:
	_events.clear()
	_categories.clear()
	_scan_directory(EVENT_ROOT, "")

func _scan_directory(path: String, category: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_category = file_name if category == "" else "%s/%s" % [category, file_name]
			_scan_directory(path.path_join(file_name), sub_category)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var full_path = path.path_join(file_name)
			var res = load(full_path)
			if res is GameEventDefinition:
				_register_event(res, category)
		file_name = dir.get_next()
	dir.list_dir_end()

func _register_event(def: GameEventDefinition, category: String) -> void:
	if def.event_id == &"":
		push_warning("[GameEventRegistry] Skipping event with empty event_id")
		return
	if _events.has(def.event_id):
		push_warning("[GameEventRegistry] Duplicate event_id '%s' — overwriting" % def.event_id)

	_events[def.event_id] = def

	if not _categories.has(category):
		_categories[category] = []
	_categories[category].append(def.event_id)

# ============================================================================
# PUBLIC API
# ============================================================================

func fire_event(event_id: StringName) -> void:
	"""Fire an event: apply its effects (if defined), then emit signal."""
	var def = _events.get(event_id) as GameEventDefinition
	if def:
		def.apply_effects()
	else:
		# Unknown event IDs still fire — allows ad-hoc signal-only events
		push_warning("[GameEventRegistry] Unknown event '%s' — signal only" % event_id)

	event_fired.emit(event_id)

func get_event(event_id: StringName) -> GameEventDefinition:
	"""Look up an event definition by ID. Returns null if not found."""
	return _events.get(event_id)

func has_event(event_id: StringName) -> bool:
	"""Check if an event definition exists."""
	return _events.has(event_id)

func get_all_event_ids() -> Array[StringName]:
	"""Get all registered event IDs."""
	var ids: Array[StringName] = []
	for key in _events:
		ids.append(key)
	ids.sort()
	return ids

func get_events_in_category(category: String) -> Array[GameEventDefinition]:
	"""Get all events in a category (subfolder name)."""
	var result: Array[GameEventDefinition] = []
	var ids = _categories.get(category, [])
	for event_id in ids:
		var def = _events.get(event_id)
		if def:
			result.append(def)
	return result

func get_categorized_event_ids() -> Dictionary:
	"""Get all event IDs grouped by category. Returns { category_string: Array[StringName] }."""
	return _categories.duplicate(true)

func get_all_categories() -> Array[String]:
	"""Get sorted list of all category names."""
	var cats: Array[String] = []
	for key in _categories:
		cats.append(key)
	cats.sort()
	return cats
