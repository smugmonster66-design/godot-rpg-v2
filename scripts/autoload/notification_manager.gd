# res://scripts/autoload/notification_manager.gd
# General-purpose notification system for quest updates, loot, level ups, etc.
# Notifications are displayed by a UI scene (NotificationDisplay) added to PersistentUILayer.
# This autoload manages the queue and exposes the API; the display scene handles visuals.
extends Node

# ============================================================================
# SIGNALS
# ============================================================================
signal notification_queued(data: Dictionary)
signal notification_shown(data: Dictionary)
signal notification_dismissed(data: Dictionary)

# ============================================================================
# CONFIGURATION
# ============================================================================
const DEFAULT_DURATION: float = 1.5
const MAX_QUEUE_SIZE: int = 20

# ============================================================================
# STATE
# ============================================================================
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _is_showing: bool = false

# ============================================================================
# PUBLIC API
# ============================================================================

func notify(text: String, category: StringName = &"system", icon: Texture2D = null, duration: float = DEFAULT_DURATION) -> void:
	"""Queue a notification to be displayed."""
	var data: Dictionary = {
		"text": text,
		"category": category,
		"icon": icon,
		"duration": duration,
		"timestamp": Time.get_ticks_msec()
	}

	if _queue.size() >= MAX_QUEUE_SIZE:
		_queue.pop_front()

	_queue.append(data)
	notification_queued.emit(data)

	if not _is_showing:
		_show_next()

func notify_quest_available(quest_name: String) -> void:
	notify("New Quest: %s" % quest_name, &"quest")

func notify_quest_updated(text: String) -> void:
	notify(text, &"quest")

func notify_objective_complete(completed_text: String) -> void:
	"""Show completed objective with strikethrough."""
	var data: Dictionary = {
		"text": completed_text,
		"category": &"objective_complete",
		"icon": null,
		"duration": DEFAULT_DURATION,
		"completed_text": completed_text,
		"timestamp": Time.get_ticks_msec()
	}

	if _queue.size() >= MAX_QUEUE_SIZE:
		_queue.pop_front()

	_queue.append(data)
	notification_queued.emit(data)

	if not _is_showing:
		_show_next()

func notify_quest_complete(quest_name: String) -> void:
	notify("Quest Complete: %s" % quest_name, &"quest")

func notify_loot(item_name: String, rarity: String = "") -> void:
	var text: String = item_name
	if rarity != "":
		text = "%s %s" % [rarity, item_name]
	notify(text, &"loot")

func notify_level_up(new_level: int) -> void:
	notify("Level Up! You are now level %d" % new_level, &"level")

func notify_companion(companion_name: String) -> void:
	notify("New Companion: %s" % companion_name, &"companion")

# ============================================================================
# INTERNAL
# ============================================================================

func _show_next() -> void:
	"""Show the next notification in the queue."""
	if _queue.is_empty():
		_is_showing = false
		_current = {}
		return

	_is_showing = true
	_current = _queue.pop_front()
	notification_shown.emit(_current)

func on_display_finished() -> void:
	"""Called by the display scene when the current notification has finished animating out."""
	var finished: Dictionary = _current
	_current = {}
	notification_dismissed.emit(finished)
	_show_next()

func clear_queue() -> void:
	"""Clear all pending notifications."""
	_queue.clear()

func get_current() -> Dictionary:
	"""Get the currently-displayed notification data, or empty dict if none."""
	return _current

func is_showing() -> bool:
	return _is_showing
