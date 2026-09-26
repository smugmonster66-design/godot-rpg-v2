# res://scripts/ui/map/map_waypoint_handle.gd
# Small draggable diamond-shaped handle placed on map connection curves
# in edit mode.  Lives in NodesLayer so it shares the same coordinate space
# as the node buttons (map_position units, zoomed/panned with MapContent).
extends Control
class_name MapWaypointHandle

signal handle_moved(key: String, index: int, new_pos: Vector2)
signal handle_right_clicked(key: String, index: int)

const HANDLE_SIZE := 14.0
const HALF        := HANDLE_SIZE * 0.5

const COLOR_FILL    := Color(1.00, 0.75, 0.10, 0.95)
const COLOR_OUTLINE := Color(0.15, 0.08, 0.00, 1.00)
const COLOR_HOVER   := Color(1.00, 1.00, 0.50, 1.00)

var connection_key: String = ""
var waypoint_index: int    = 0

var _dragging: bool  = false
var _hovered: bool   = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	custom_minimum_size = Vector2(HANDLE_SIZE, HANDLE_SIZE)
	size                = custom_minimum_size
	mouse_filter        = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE

func setup(key: String, index: int, map_pos: Vector2) -> void:
	connection_key  = key
	waypoint_index  = index
	_place_at(map_pos)

func update_position(map_pos: Vector2) -> void:
	_place_at(map_pos)

func _place_at(map_pos: Vector2) -> void:
	position = map_pos - Vector2(HALF, HALF)

# ============================================================================
# DRAWING
# ============================================================================

func _draw() -> void:
	var c   := Vector2(HALF, HALF)
	var pts := PackedVector2Array([
		c + Vector2(0.0,  -HALF),
		c + Vector2(HALF,  0.0),
		c + Vector2(0.0,   HALF),
		c + Vector2(-HALF, 0.0),
	])
	var fill := COLOR_HOVER if _hovered else COLOR_FILL
	draw_colored_polygon(pts, fill)
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])   # close the loop
	draw_polyline(ring, COLOR_OUTLINE, 1.5)

# ============================================================================
# INPUT
# ============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
				accept_event()
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					handle_right_clicked.emit(connection_key, waypoint_index)
					accept_event()

	elif event is InputEventMouseMotion:
		if _dragging:
			# get_parent() is NodesLayer; get_local_mouse_position() accounts for zoom/pan.
			var new_center: Vector2 = (get_parent() as Control).get_local_mouse_position()
			_place_at(new_center)
			handle_moved.emit(connection_key, waypoint_index, new_center)
			accept_event()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			queue_redraw()
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			queue_redraw()
