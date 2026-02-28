# res://scripts/ui/combat/status_effect_display.gd
# Reactive status effect icon strip.
# Connects to a StatusTracker's signals and manages child StatusEffectIcons.
# Handles tooltip spawning — only one tooltip visible at a time.
extends HBoxContainer
class_name StatusEffectDisplay

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_ICONS := 8

# ============================================================================
# STATE
# ============================================================================

var _tracker: StatusTracker = null
var _icons: Dictionary = {}  # {status_id: StatusEffectIcon}
var _active_tooltip: StatusTooltipPopup = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_PASS

# ============================================================================
# PUBLIC API
# ============================================================================

func connect_tracker(tracker: StatusTracker) -> void:
	"""Connect to a StatusTracker and populate from its current state."""
	disconnect_tracker()
	_tracker = tracker

	if not _tracker:
		return

	# Connect signals
	_tracker.status_applied.connect(_on_status_applied)
	_tracker.status_stacks_changed.connect(_on_status_stacks_changed)
	_tracker.status_removed.connect(_on_status_removed)
	_tracker.statuses_cleansed.connect(_on_statuses_cleansed)

	# Populate from existing active statuses
	for instance in _tracker.get_all_active():
		var affix: StatusAffix = instance.get("status_affix")
		if affix and instance.get("current_stacks", 0) > 0:
			_add_icon(affix.status_id, instance)

func disconnect_tracker() -> void:
	"""Disconnect from the current tracker and clear all icons."""
	if _tracker:
		if _tracker.status_applied.is_connected(_on_status_applied):
			_tracker.status_applied.disconnect(_on_status_applied)
		if _tracker.status_stacks_changed.is_connected(_on_status_stacks_changed):
			_tracker.status_stacks_changed.disconnect(_on_status_stacks_changed)
		if _tracker.status_removed.is_connected(_on_status_removed):
			_tracker.status_removed.disconnect(_on_status_removed)
		if _tracker.statuses_cleansed.is_connected(_on_statuses_cleansed):
			_tracker.statuses_cleansed.disconnect(_on_statuses_cleansed)
	_tracker = null
	clear_all()

func clear_all() -> void:
	"""Remove all status icons."""
	for child in get_children():
		child.queue_free()
	_icons.clear()
	_dismiss_tooltip()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_status_applied(status_id: String, instance: Dictionary) -> void:
	if _icons.has(status_id):
		# Already have an icon — just update stacks
		_icons[status_id].update_stacks(instance)
	else:
		_add_icon(status_id, instance)

func _on_status_stacks_changed(status_id: String, instance: Dictionary) -> void:
	if _icons.has(status_id):
		_icons[status_id].update_stacks(instance)

func _on_status_removed(status_id: String) -> void:
	_remove_icon(status_id)

func _on_statuses_cleansed(removed_ids: Array[String]) -> void:
	for sid in removed_ids:
		_remove_icon(sid)

# ============================================================================
# ICON MANAGEMENT
# ============================================================================

func _add_icon(status_id: String, instance: Dictionary) -> void:
	if _icons.size() >= MAX_ICONS:
		return  # Cap reached

	var icon := StatusEffectIcon.new()
	icon.setup(instance)
	icon.tooltip_requested.connect(_on_tooltip_requested)
	add_child(icon)
	_icons[status_id] = icon

func _remove_icon(status_id: String) -> void:
	if not _icons.has(status_id):
		return
	var icon: StatusEffectIcon = _icons[status_id]
	_icons.erase(status_id)
	if is_instance_valid(icon):
		icon.queue_free()

# ============================================================================
# TOOLTIP
# ============================================================================

func _on_tooltip_requested(status_data: Dictionary, icon_global_pos: Vector2) -> void:
	"""Spawn a tooltip for the tapped status icon."""
	_dismiss_tooltip()

	var tooltip := StatusTooltipPopup.new()
	
	# Add directly to root (tooltip is already a CanvasLayer)
	var root := get_tree().root
	root.add_child(tooltip)
	
	tooltip.show_for_status(status_data, icon_global_pos)
	_active_tooltip = tooltip

	# Clean up reference when tooltip is freed
	tooltip.tree_exiting.connect(func():
		if _active_tooltip == tooltip:
			_active_tooltip = null
	)
	
	print("  🔔 Tooltip setup complete")

func _dismiss_tooltip() -> void:
	if _active_tooltip and is_instance_valid(_active_tooltip):
		_active_tooltip.dismiss()
	_active_tooltip = null
