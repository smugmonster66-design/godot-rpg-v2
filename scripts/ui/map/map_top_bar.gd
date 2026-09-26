# res://scripts/ui/map/map_top_bar.gd
# Top bar for MapScene showing current/selected location name.
# Notifications slide in from behind its bottom edge.
extends Control

# ============================================================================
# NODES
# ============================================================================
@onready var _panel: PanelContainer = $Panel
@onready var _location_label: Label = $Panel/Margin/LocationLabel
@onready var _notification_container: PanelContainer = $NotificationPanel
@onready var _notification_icon: TextureRect = $NotificationPanel/Margin/HBox/NotificationIcon
@onready var _notification_label: RichTextLabel = $NotificationPanel/Margin/HBox/NotificationLabel

# ============================================================================
# STATE
# ============================================================================
var _current_location_name: String = ""
var _selected_location_name: String = ""
var _notification_tween: Tween = null
const BAR_HEIGHT: float = 72.0
const NOTIFICATION_HEIGHT: float = 52.0

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	_connect_signals()
	# Initialize with player's current location
	if GameState and GameState.map:
		var loc_id: StringName = GameState.map.current_location
		if loc_id != &"":
			var loc = MapManager.get_location(loc_id)
			if loc:
				_current_location_name = loc.display_name
				_update_label()

func _connect_signals():
	NotificationManager.notification_shown.connect(_on_notification_shown)
	MapManager.location_entered.connect(_on_location_entered)

# ============================================================================
# LOCATION DISPLAY
# ============================================================================

func show_selected_location(location_name: String) -> void:
	"""Show the name of the location whose radial menu is open."""
	_selected_location_name = location_name
	_update_label()

func clear_selected_location() -> void:
	"""Revert to showing the player's current location."""
	_selected_location_name = ""
	_update_label()

func _on_location_entered(location_id: StringName, location: LocationNode, _first_visit: bool) -> void:
	_current_location_name = location.display_name if location else String(location_id)
	_update_label()

func _update_label() -> void:
	var display: String = _selected_location_name if _selected_location_name != "" else _current_location_name
	_location_label.text = display

# ============================================================================
# NOTIFICATION DISPLAY
# ============================================================================

func _on_notification_shown(data: Dictionary) -> void:
	"""Animate notification sliding out from behind the bar."""
	var category: StringName = data.get("category", &"system")

	if category == &"objective_complete":
		_show_objective_complete_notification(data)
		return

	var text: String = data.get("text", "")
	var icon: Texture2D = data.get("icon", null)
	var duration: float = data.get("duration", 3.0)

	_notification_label.text = "[center]%s[/center]" % text
	if icon:
		_notification_icon.texture = icon
		_notification_icon.visible = true
	else:
		_notification_icon.visible = false

	_animate_slide_in_hold_out(duration)

func _animate_slide_in_hold_out(duration: float) -> void:
	"""Standard notification: slide in, hold, slide out."""
	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()

	_notification_tween = create_tween()
	_notification_tween.set_ease(Tween.EASE_OUT)
	_notification_tween.set_trans(Tween.TRANS_CUBIC)

	# Slide down from behind bar
	_notification_container.position.y = BAR_HEIGHT - NOTIFICATION_HEIGHT
	_notification_container.modulate.a = 0.0

	_notification_tween.tween_property(
		_notification_container, "position:y", BAR_HEIGHT, 0.3)
	_notification_tween.parallel().tween_property(
		_notification_container, "modulate:a", 1.0, 0.2)

	# Hold
	_notification_tween.tween_interval(duration)

	# Slide back up behind bar
	_notification_tween.tween_property(
		_notification_container, "position:y", BAR_HEIGHT - NOTIFICATION_HEIGHT, 0.3).set_ease(Tween.EASE_IN)
	_notification_tween.parallel().tween_property(
		_notification_container, "modulate:a", 0.0, 0.2).set_delay(0.1)

	# Tell NotificationManager we're done
	_notification_tween.tween_callback(NotificationManager.on_display_finished)

func _show_objective_complete_notification(data: Dictionary) -> void:
	"""Show completed objective with strikethrough, then dismiss normally."""
	var completed_text: String = data.get("completed_text", "")
	var duration: float = data.get("duration", 1.5)

	_notification_icon.visible = false
	_notification_label.text = "[center][s]%s[/s][/center]" % completed_text

	_animate_slide_in_hold_out(duration)
