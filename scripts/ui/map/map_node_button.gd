# res://scripts/ui/map/map_node_button.gd
# Visual button representing a LocationNode on the world map.
# Positioned in MapContent space (pans/zooms with the container).
extends Button

signal node_pressed(location: LocationNode, screen_pos: Vector2)
signal node_drag_updated(location: LocationNode)
signal node_drag_ended(location: LocationNode)
signal node_right_clicked_edit(location: LocationNode)

var location_node: LocationNode = null
var _real_icon: Texture2D = null  # cached from setup(), restored when fog lifts

# Edit mode state
var _edit_mode: bool   = false
var _drag_active: bool = false

@onready var _icon_rect: TextureRect = find_child("Icon", true, false)
@onready var _label_node: Label = find_child("NodeLabel", true, false)
@onready var _circle_rect: TextureRect = find_child("NodeCircleTexture", true, false)
@onready var _selection_ring: Panel = find_child("SelectionRing", true, false)
@onready var _fog_overlay: ColorRect = find_child("FogOverlay", true, false)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# All child Controls must not consume mouse events — clicks need to reach the Button root.
	# VBoxContainers default to mouse_filter=STOP which swallows clicks before Button._gui_input fires.
	for child in find_children("*", "Control", true, false):
		child.mouse_filter = MOUSE_FILTER_IGNORE
	# Recompute anchor whenever the layout engine resizes the circle (texture load, relayout).
	if _circle_rect:
		_circle_rect.resized.connect(_update_pivot_and_position)

# ============================================================================
# SETUP
# ============================================================================

func setup(loc: LocationNode) -> void:
	location_node = loc
	name = str(loc.location_id)
	# Set initial position immediately using the scene's pivot_offset so the button
	# is always at a clickable location. _update_pivot_and_position() refines this
	# to the exact circle center once layout has settled.
	position = loc.map_position - pivot_offset

	_real_icon = loc.map_icon
	if _real_icon and _icon_rect:
		_icon_rect.texture = _real_icon

	# Per-location circle override; tscn default is used when null
	if loc.node_circle_texture and _circle_rect:
		_circle_rect.texture = loc.node_circle_texture

	refresh_state()
	# Try immediately; resized signal catches the layout-settled case.
	_update_pivot_and_position()

func _update_pivot_and_position() -> void:
	if location_node == null or not is_instance_valid(_circle_rect):
		return
	if _circle_rect.size == Vector2.ZERO:
		return  # Layout not ready yet — resized signal will fire when it is
	var circle_center := _circle_rect.position + _circle_rect.size * 0.5
	pivot_offset = circle_center
	position = location_node.map_position - pivot_offset

func refresh_state() -> void:
	if location_node == null:
		return

	var loc_id = location_node.location_id
	var is_current = GameState.map.current_location == loc_id
	var is_visited = GameState.map.has_visited(loc_id)
	var is_unlocked = GameState.map.is_unlocked(loc_id)
	var is_revealed = GameState.map.is_revealed(loc_id)

	# Selection ring shows for current location
	_selection_ring.visible = is_current

	# Fog: show "?" label but keep the real icon; once visited, show real name
	var in_fog = location_node.initial_visibility == LocationNode.VisibilityState.FOG and not is_visited
	_fog_overlay.visible = false
	_label_node.text = "?" if in_fog else location_node.get_display_name()
	_label_node.visible = true

	# Greyed out if locked
	modulate = Color.WHITE if is_unlocked else Color(0.5, 0.5, 0.5, 0.8)

	# Not interactable if locked or not revealed
	disabled = not is_unlocked or not is_revealed

# ============================================================================
# EDIT MODE
# ============================================================================

func set_edit_mode(enabled: bool) -> void:
	_edit_mode = enabled
	_drag_active = false
	if enabled:
		disabled = false   # interactable regardless of unlock state
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		refresh_state()    # restore disabled state from game logic

func _gui_input(event: InputEvent) -> void:
	if not _edit_mode:
		# BaseButton processes clicks via NOTIFICATION_GUI_INPUT internally —
		# not through this GDVIRTUAL — so simply returning is sufficient.
		return

	# Dragging is handled at MapScene level (_input) — button _gui_input
	# never fires because the button rect doesn't match hit-test radius.
	# Only right-click (context menu) is handled here.
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					node_right_clicked_edit.emit(location_node)
					accept_event()

# ============================================================================
# SIGNALS
# ============================================================================

func _on_pressed() -> void:
	if location_node == null:
		return
	# Use pivot_offset (circle center in local space) → screen space via global transform.
	var screen_pos = get_global_transform() * pivot_offset
	node_pressed.emit(location_node, screen_pos)
