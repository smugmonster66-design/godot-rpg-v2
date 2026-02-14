# res://scripts/shared/game_camera.gd
## Shared camera used by both the map and dungeon systems.
## Provides two movement modes: free pan (map) and corridor scroll (dungeon).
## Offset accounts for the BottomUIPanel covering the lower 450px.
extends Camera2D
class_name GameCamera

enum Mode { MAP, DUNGEON }

# ============================================================================
# CONFIGURATION
# ============================================================================
## Height of the BottomUIPanel in pixels
@export var bottom_panel_height: float = 450.0

## MAP MODE
@export_group("Map Mode")
@export var pan_speed: float = 800.0          ## pixels/sec for keyboard/drag
@export var pan_smoothing: float = 5.0        ## lerp speed toward target
@export var zoom_min: float = 0.5
@export var zoom_max: float = 2.0
@export var zoom_step: float = 0.1

@export var extra_offset_y: float = 0.0

## DUNGEON MODE
@export_group("Dungeon Mode")
@export var corridor_tween_duration: float = 0.8
@export var intro_duration: float = 2.0

# ============================================================================
# STATE
# ============================================================================
var mode: Mode = Mode.MAP
var _pan_target: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _camera_start: Vector2 = Vector2.ZERO
var _corridor_transitioning: bool = false

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	_apply_offset()
	enabled = true

func _apply_offset():
	var viewport_h = get_viewport_rect().size.y
	var playable_center = (viewport_h - bottom_panel_height) / 2.0
	var viewport_center = viewport_h / 2.0
	offset = Vector2(0, -(viewport_center - playable_center) + extra_offset_y)


# ============================================================================
# MODE SWITCHING
# ============================================================================

func set_mode(new_mode: Mode):
	mode = new_mode
	_corridor_transitioning = false
	match mode:
		Mode.MAP:
			_pan_target = global_position
		Mode.DUNGEON:
			pass  # Position driven by corridor methods

# ============================================================================
# MAP MODE — free pan with touch drag and pinch zoom
# ============================================================================

func _process(delta: float):
	if mode != Mode.MAP: return
	# Smooth pan toward target
	if global_position.distance_to(_pan_target) > 1.0:
		global_position = global_position.lerp(_pan_target, pan_smoothing * delta)

func _unhandled_input(event: InputEvent):
	if mode != Mode.MAP: return

	# Touch drag — pan
	if event is InputEventScreenTouch:
		if event.pressed:
			_is_dragging = true
			_drag_start = event.position
			_camera_start = global_position
		else:
			_is_dragging = false

	elif event is InputEventScreenDrag and _is_dragging:
		var drag_delta = event.position - _drag_start
		# Invert: dragging finger right moves camera left (world scrolls right)
		_pan_target = _camera_start - drag_delta / zoom

	# Mouse drag fallback (desktop testing)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start = event.position
				_camera_start = global_position
			else:
				_is_dragging = false
		# Scroll wheel zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = (zoom + Vector2.ONE * zoom_step).clampf(zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = (zoom - Vector2.ONE * zoom_step).clampf(zoom_min, zoom_max)

	elif event is InputEventMouseMotion and _is_dragging:
		var drag_delta = event.position - _drag_start
		_pan_target = _camera_start - drag_delta / zoom

func pan_to(world_pos: Vector2, instant: bool = false):
	"""Programmatic pan — used by map system to focus on a node."""
	_pan_target = world_pos
	if instant:
		global_position = world_pos

# ============================================================================
# DUNGEON MODE — corridor scroll via tweens
# ============================================================================

func corridor_advance(target_world_pos: Vector2):
	"""Tween the camera to a new floor position."""
	if _corridor_transitioning: return
	_corridor_transitioning = true
	var tw = create_tween()
	tw.tween_property(self, "global_position", target_world_pos, corridor_tween_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_on_corridor_arrived)

func corridor_intro(start_pos: Vector2, end_pos: Vector2):
	"""Opening sweep — boss door down to start."""
	_corridor_transitioning = true
	global_position = start_pos
	var tw = create_tween()
	tw.tween_property(self, "global_position", end_pos, intro_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_on_corridor_arrived)

func corridor_set_position(world_pos: Vector2):
	"""Instantly place camera (no tween)."""
	global_position = world_pos
	_corridor_transitioning = false

signal corridor_arrived

func _on_corridor_arrived():
	_corridor_transitioning = false
	corridor_arrived.emit()

# ============================================================================
# HELPERS
# ============================================================================

func get_playable_rect() -> Rect2:
	"""Returns the world-space rectangle of the visible playable area
	(above the BottomUIPanel)."""
	var vp = get_viewport_rect().size
	var playable_h = vp.y - bottom_panel_height
	var top_left = global_position + offset - Vector2(vp.x / 2.0, playable_h / 2.0) / zoom
	var size = Vector2(vp.x, playable_h) / zoom
	return Rect2(top_left, size)

func get_playable_height() -> float:
	"""Playable area height in pixels (viewport minus panel)."""
	return get_viewport_rect().size.y - bottom_panel_height
