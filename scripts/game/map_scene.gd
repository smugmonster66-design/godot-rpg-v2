# res://scripts/game/map_scene.gd
# Map scene controller. Spawns MapNodeButton instances from LocationNode resources,
# draws connection paths, and manages the radial action menu.
# Extends Control (not Node2D) so Godot's GUI input system dispatches correctly
# to the MapNodeButton children inside the CanvasLayer.
extends Control

# ============================================================================
# CONSTANTS
# ============================================================================
const MapNodeButtonScene = preload("res://scenes/ui/map/map_node_button.tscn")
const MapRadialMenuScene = preload("res://scenes/ui/map/map_radial_menu.tscn")
# MapEditorToolbar and MapWaypointHandle are available via class_name — no preload needed.

const ZOOM_MIN := 0.4
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.12
# Offset applied to path endpoints to aim at button center
const NODE_CENTER_OFFSET := Vector2.ZERO
# Hit radius (in NodesLayer local pixels) for clicking map nodes.
# Uses map_position as center — immune to pivot/scale timing issues.
const NODE_HIT_RADIUS := 50.0
# Maximum distance (in NodesLayer pixels) to click-select a path for waypoint insertion.
const PATH_HIT_RADIUS := 15.0
const WAYPOINT_HIT_RADIUS := 20.0
const DECOR_HIT_RADIUS := 30.0
const LIGHT_HIT_RADIUS := 25.0

# ============================================================================
# STATE
# ============================================================================
var player = null
var is_initialized: bool = false
var _node_buttons: Dictionary = {}   # location_id → MapNodeButton
var _radial_menu: Control = null
var _current_zoom := 1.0

# Pan drag state
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _pan_start: Vector2 = Vector2.ZERO

# Camera follow state
var _is_traveling: bool = false
@export_range(1.0, 10.0, 0.5) var camera_follow_speed: float = 3.0  # exponential smoothing rate

## Fallback lighting config used when a map has no lighting_config of its own.
@export var default_lighting_config: MapLightingConfig = null

# ============================================================================
# EDIT MODE STATE
# ============================================================================
enum EditTool { SELECT, ADD_NODE, CONNECT, DECOR, LIGHTING }

var _edit_mode: bool         = false
var _active_tool: EditTool   = EditTool.SELECT
var _editor_toolbar: MapEditorToolbar = null
var _connect_from_id: StringName = &""
var _dirty_resources: Array  = []
var _waypoint_handles: Dictionary = {}   # connection_key → Array[MapWaypointHandle]
var _drag_node_btn: Control  = null      # node currently being dragged (edit mode)
var _drag_wp_key: String     = ""        # waypoint handle drag: connection key
var _drag_wp_index: int      = -1        # waypoint handle drag: index in waypoints array
var _drag_decor_index: int   = -1        # decor item drag: index into decor_items
var _drag_light_index: int   = -1        # light drag: index into lighting_config.lights
var _decor_nodes: Array      = []        # TextureRect children of DecorLayer (index-matched)
var _light_markers: Array    = []        # visual markers for lights in edit mode
var _shadow_nodes: Array     = []        # shadow TextureRects/ColorRects in the ShadowLayer

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var _map_content: Control = $MapContent
@onready var _paths_drawer = $MapContent/PathsDrawer   # MapPathsDrawer
@onready var _shadow_layer: Control = $MapContent/ShadowLayer
@onready var _decor_layer: Control = $MapContent/DecorLayer
@onready var _nodes_layer: Control = $MapContent/NodesLayer
@onready var _markers_layer: Control = $MapContent/MarkersLayer
@onready var _player_marker: Control = $MapContent/MarkersLayer/PlayerMarker
@onready var _player_map_sprite: AnimatedSprite2D = $MapContent/MarkersLayer/PlayerMarker/PlayerMapSprite
@onready var _light_rays_overlay: ColorRect = $MapContent/LightRaysOverlay
@onready var _lighting_overlay: ColorRect = $MapContent/LightingOverlay
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _top_bar: Control = $UILayer/MapTopBar

func set_ui_layer_visible(visible: bool) -> void:
	if _ui_layer:
		_ui_layer.visible = visible

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_spawn_radial_menu()
	_spawn_editor_toolbar()

	var leave_btn = _ui_layer.get_node_or_null("LeaveZoneButton")
	if leave_btn:
		leave_btn.pressed.connect(_on_leave_zone_pressed)

func _process(delta: float) -> void:
	if _is_traveling:
		var target: Vector2 = _get_player_centered_pos()
		# Exponential smoothing: closes ~95% of the gap in 1/speed seconds.
		# Framerate-independent and always smooth — never overshoots.
		var weight: float = 1.0 - exp(-camera_follow_speed * delta)
		_map_content.position = _map_content.position.lerp(target, weight)
		_clamp_pan()

func _spawn_radial_menu() -> void:
	_radial_menu = MapRadialMenuScene.instantiate()
	_ui_layer.add_child(_radial_menu)
	_radial_menu.action_completed.connect(_on_action_completed)
	_radial_menu.radial_closed.connect(_on_radial_closed)
	_radial_menu.travel_requested.connect(_on_travel_requested)
	_radial_menu.zone_entered.connect(_on_zone_entered)

func _spawn_editor_toolbar() -> void:
	# Only show the edit-mode button in debug/editor builds.
	if not (OS.is_debug_build() or OS.has_feature("editor")):
		return

	# Small "Edit Map" button anchored top-right, always visible in debug
	var toggle_btn := Button.new()
	toggle_btn.text = "Edit Map"
	toggle_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle_btn.offset_left   = -90.0
	toggle_btn.offset_top    =  6.0
	toggle_btn.offset_right  = -6.0
	toggle_btn.offset_bottom =  34.0
	_ui_layer.add_child(toggle_btn)
	toggle_btn.pressed.connect(_toggle_edit_mode)

	# Toolbar (hidden until edit mode is active)
	_editor_toolbar = MapEditorToolbar.new()
	_editor_toolbar.visible = false
	_ui_layer.add_child(_editor_toolbar)
	_editor_toolbar.add_node_mode_changed.connect(_on_add_node_mode_changed)
	_editor_toolbar.connect_mode_changed.connect(_on_connect_mode_changed)
	_editor_toolbar.decor_mode_changed.connect(_on_decor_mode_changed)
	_editor_toolbar.lighting_mode_changed.connect(_on_lighting_mode_changed)
	_editor_toolbar.save_requested.connect(_on_save_requested)
	_editor_toolbar.discard_requested.connect(_on_discard_requested)
	_editor_toolbar.exit_edit_requested.connect(_toggle_edit_mode)

func initialize_map(p_player, map_def: MapDefinition = null, stack_snapshot: Array = []) -> void:
	"""Initialize the map scene. Pass a MapDefinition to display a specific map;
	omit to display all registered locations (legacy/debug fallback).
	stack_snapshot restores the zones a saved game was inside."""
	player = p_player
	is_initialized = true

	if not MapManager.location_entered.is_connected(_on_location_entered):
		MapManager.location_entered.connect(_on_location_entered)
	if not MapManager.map_changed.is_connected(_on_map_changed):
		MapManager.map_changed.connect(_on_map_changed)

	if map_def != null:
		MapManager.initialize_with_map(map_def, stack_snapshot)
	else:
		_rebuild_map_display()

# ============================================================================
# MAP NODE SPAWNING
# ============================================================================

func _rebuild_map_display() -> void:
	"""Full rebuild: nodes + paths + decor + lighting + background + marker + Leave button state."""
	var map_def = MapManager.get_current_map()
	var map_name = map_def.display_name if map_def else "null"
	print("[MapLighting] _rebuild_map_display — map: %s" % map_name)
	print("[MapLighting]   _map_content.size: %s, .position: %s, .scale: %s" % [_map_content.size, _map_content.position, _map_content.scale])
	_spawn_map_nodes()
	_build_path_data()
	_paths_drawer.queue_redraw()
	_snap_player_marker_to_current()
	_update_map_background()
	print("[MapLighting]   After _update_map_background — _map_content.size: %s" % _map_content.size)
	_update_leave_button()
	_rebuild_waypoint_handles()
	_rebuild_decor()
	_apply_lighting()
	_enforce_min_zoom()
	print("[MapLighting]   After _enforce_min_zoom — _map_content.scale: %s, _current_zoom: %s" % [_map_content.scale, _current_zoom])
	_center_on_player()
	print("[MapLighting]   After _center_on_player — _map_content.position: %s" % _map_content.position)
	# Shadows depend on VBoxContainer layout inside MapNodeButtons which
	# hasn't been computed yet on the same frame they're instantiated.
	# Defer one frame so icon sizes/positions are final.
	_rebuild_shadows_deferred()

func _spawn_map_nodes() -> void:
	for child in _nodes_layer.get_children():
		child.queue_free()
	_node_buttons.clear()

	var locations = MapManager.get_current_map_locations()
	for location in locations:
		if not MapManager.check_location_visibility(location.location_id):
			continue
		_spawn_node_button(location)

func _spawn_node_button(location: LocationNode) -> void:
	var btn = MapNodeButtonScene.instantiate()
	_nodes_layer.add_child(btn)
	btn.size = btn.custom_minimum_size   # Guarantee size independent of layout
	btn.setup(location)
	btn.node_pressed.connect(_on_node_pressed)
	btn.node_drag_updated.connect(_on_node_drag_updated)
	btn.node_drag_ended.connect(_on_node_drag_ended)
	btn.node_right_clicked_edit.connect(_on_node_right_clicked_edit)
	btn.set_edit_mode(_edit_mode)
	_node_buttons[location.location_id] = btn

func _refresh_node_states() -> void:
	for loc_id in _node_buttons:
		var btn = _node_buttons[loc_id]
		if btn and is_instance_valid(btn):
			btn.refresh_state()

func _update_map_background() -> void:
	var bg: TextureRect = _map_content.get_node_or_null("MapBackground")
	if bg == null:
		return
	var map = MapManager.get_current_map()
	if map and map.background_texture:
		bg.texture = map.background_texture
		# Resize MapContent to match the background texture so all anchored
		# child layers (PathsDrawer, DecorLayer, NodesLayer, etc.) expand to
		# the full map area. Without this, _draw() calls are clipped to viewport size.
		var tex_size = Vector2(map.background_texture.get_width(), map.background_texture.get_height())
		_map_content.custom_minimum_size = tex_size
		_map_content.size = tex_size

func _update_leave_button() -> void:
	var btn = _ui_layer.get_node_or_null("LeaveZoneButton")
	if btn:
		btn.visible = MapManager.is_in_sub_map()

# ============================================================================
# PATH DRAWING
# ============================================================================

func _build_path_data() -> void:
	var segments: Array = []
	var drawn_pairs: Dictionary = {}
	var map_def = MapManager.get_current_map()
	var locations = MapManager.get_current_map_locations()

	for location in locations:
		for connected_id in location.get_bidirectional_connections():
			var key = _pair_key(location.location_id, connected_id)
			if drawn_pairs.has(key):
				continue
			drawn_pairs[key] = true
			var connected = MapManager.get_location(connected_id)
			if connected:
				var wps: Array = map_def.connection_waypoints.get(key, []) if map_def else []
				segments.append({
					"a": location.map_position + NODE_CENTER_OFFSET,
					"b": connected.map_position + NODE_CENTER_OFFSET,
					"one_way": false,
					"waypoints": wps,
					"key": key,
				})

		for connected_id in location.get_one_way_connections_all():
			var key = str(location.location_id) + ">" + str(connected_id)
			var connected = MapManager.get_location(connected_id)
			if connected:
				var wps: Array = map_def.connection_waypoints.get(key, []) if map_def else []
				segments.append({
					"a": location.map_position + NODE_CENTER_OFFSET,
					"b": connected.map_position + NODE_CENTER_OFFSET,
					"one_way": true,
					"waypoints": wps,
					"key": key,
				})

	_paths_drawer.path_segments = segments

## Separator used in bidirectional pair keys.  Must never appear in a location_id.
const PAIR_SEP := "<->"

func _pair_key(a: StringName, b: StringName) -> String:
	var sa = str(a)
	var sb = str(b)
	if sa < sb:
		return sa + PAIR_SEP + sb
	return sb + PAIR_SEP + sa

# ============================================================================
# PAN / ZOOM (right-click drag + scroll wheel)
# ============================================================================

func _input(event: InputEvent) -> void:
	if not is_initialized:
		return
	if _is_interaction_blocked():
		_dragging = false
		return
	if _radial_menu and _radial_menu.visible:
		return

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not event.pressed:
					# End node drag on release
					if _drag_node_btn != null:
						_on_node_drag_ended(_drag_node_btn.location_node)
						_drag_node_btn = null
						get_viewport().set_input_as_handled()
					# End waypoint drag on release
					elif _drag_wp_index >= 0:
						_drag_wp_key = ""
						_drag_wp_index = -1
						get_viewport().set_input_as_handled()
					# End decor drag on release
					elif _drag_decor_index >= 0:
						_drag_decor_index = -1
						get_viewport().set_input_as_handled()
					# End light drag on release
					elif _drag_light_index >= 0:
						_drag_light_index = -1
						get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				# In edit mode, right-click is for context menus; don't pan.
				if not _edit_mode or event.button_index == MOUSE_BUTTON_MIDDLE:
					_dragging = event.pressed
					if _dragging:
						_drag_start = event.position
						_pan_start = _map_content.position
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(_current_zoom + ZOOM_STEP, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(_current_zoom - ZOOM_STEP, event.position)

	elif event is InputEventMouseMotion:
		if _drag_node_btn != null:
			# Edit-mode node drag
			var new_center: Vector2 = _nodes_layer.get_local_mouse_position()
			_drag_node_btn.location_node.map_position = new_center
			_drag_node_btn.position = new_center - _drag_node_btn.pivot_offset
			_on_node_drag_updated(_drag_node_btn.location_node)
			get_viewport().set_input_as_handled()
		elif _drag_wp_index >= 0:
			# Edit-mode waypoint drag
			var new_pos: Vector2 = _nodes_layer.get_local_mouse_position()
			_on_waypoint_moved(_drag_wp_key, _drag_wp_index, new_pos)
			# Update the handle's visual position
			if _waypoint_handles.has(_drag_wp_key):
				var handles: Array = _waypoint_handles[_drag_wp_key]
				if _drag_wp_index < handles.size():
					handles[_drag_wp_index].update_position(new_pos)
			get_viewport().set_input_as_handled()
		elif _drag_decor_index >= 0:
			# Edit-mode decor drag
			var new_pos: Vector2 = _nodes_layer.get_local_mouse_position()
			_update_decor_position(_drag_decor_index, new_pos)
			get_viewport().set_input_as_handled()
		elif _drag_light_index >= 0:
			# Edit-mode light drag
			var new_pos: Vector2 = _nodes_layer.get_local_mouse_position()
			_update_light_position(_drag_light_index, new_pos)
			get_viewport().set_input_as_handled()
		elif _dragging:
			_map_content.position = _pan_start + (event.position - _drag_start)
			_clamp_pan()

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	if _is_interaction_blocked():
		return

	if not (event is InputEventMouseButton and event.pressed):
		return

	var local_pos = _nodes_layer.get_local_mouse_position()

	# ── Edit mode: left-click routing ───────────────────────────────────────
	if _edit_mode and event.button_index == MOUSE_BUTTON_LEFT:
		# 1) Check waypoint handles first (small targets on paths)
		if _active_tool == EditTool.SELECT:
			var wp_hit := _find_waypoint_at(local_pos)
			if wp_hit["found"]:
				_drag_wp_key = wp_hit["key"]
				_drag_wp_index = wp_hit["index"]
				get_viewport().set_input_as_handled()
				return

		# 2) Check for node hit
		var hit_btn = _find_node_at(local_pos)

		if hit_btn != null:
			get_viewport().set_input_as_handled()
			if _active_tool == EditTool.CONNECT:
				_handle_connect_click(hit_btn.location_node)
			elif _active_tool == EditTool.SELECT:
				# Start node drag — motion handled in _input
				_drag_node_btn = hit_btn
			return

		# 3) No node hit — check active tool
		match _active_tool:
			EditTool.ADD_NODE:
				get_viewport().set_input_as_handled()
				_begin_add_node_at(local_pos)
				return
			EditTool.SELECT:
				# Check for path click → add waypoint
				var hit = _paths_drawer.find_path_at(local_pos, PATH_HIT_RADIUS / _current_zoom)
				if hit["found"]:
					get_viewport().set_input_as_handled()
					_add_waypoint(hit["key"], hit["insert_index"], hit["point"])
					return
			EditTool.DECOR:
				# Check for existing decor hit → start drag
				var decor_idx := _find_decor_at(local_pos)
				if decor_idx >= 0:
					_drag_decor_index = decor_idx
				else:
					# Click on empty space → place new decor item
					_place_decor_at(local_pos)
				get_viewport().set_input_as_handled()
				return
			EditTool.LIGHTING:
				# Check for existing light hit → start drag
				var light_idx := _find_light_at(local_pos)
				if light_idx >= 0:
					_drag_light_index = light_idx
				else:
					# Click on empty space → place new light
					_place_light_at(local_pos)
				get_viewport().set_input_as_handled()
				return
		return

	# ── Edit mode: right-click routing ────────────────────────────────────────
	if _edit_mode and event.button_index == MOUSE_BUTTON_RIGHT:
		# Check tool-specific right-click targets first
		if _active_tool == EditTool.DECOR:
			var decor_idx := _find_decor_at(local_pos)
			if decor_idx >= 0:
				get_viewport().set_input_as_handled()
				_show_decor_context_menu(decor_idx)
				return
		elif _active_tool == EditTool.LIGHTING:
			var light_idx := _find_light_at(local_pos)
			if light_idx >= 0:
				get_viewport().set_input_as_handled()
				_show_light_context_menu(light_idx)
				return
		# Fall back to path context menu
		var hit = _paths_drawer.find_path_at(local_pos, PATH_HIT_RADIUS / _current_zoom)
		if hit["found"]:
			get_viewport().set_input_as_handled()
			_show_path_context_menu(hit["key"])
			return
		return   # don't fall through to radial / pan logic

	# ── Normal mode: node hit-test ────────────────────────────────────────────
	if player == null or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var best_btn = _find_node_at(local_pos)
	if best_btn != null:
		get_viewport().set_input_as_handled()
		var screen_pos = best_btn.get_global_transform() * best_btn.pivot_offset
		_on_node_pressed(best_btn.location_node, screen_pos)

func _find_node_at(local_pos: Vector2) -> Control:
	var best_btn: Control = null
	var best_dist_sq: float = NODE_HIT_RADIUS * NODE_HIT_RADIUS
	for loc_id in _node_buttons:
		var btn: Control = _node_buttons[loc_id]
		if not is_instance_valid(btn) or btn.location_node == null:
			continue
		var dist_sq = local_pos.distance_squared_to(btn.location_node.map_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_btn = btn
	return best_btn

## Returns {found: bool, key: String, index: int} for the nearest waypoint handle.
func _find_waypoint_at(local_pos: Vector2) -> Dictionary:
	var best := {"found": false, "key": "", "index": -1}
	var best_dist_sq: float = WAYPOINT_HIT_RADIUS * WAYPOINT_HIT_RADIUS
	var map_def := MapManager.get_current_map()
	if map_def == null:
		return best
	for key in map_def.connection_waypoints:
		var wps: Array = map_def.connection_waypoints[key]
		for i in range(wps.size()):
			var wp_pos: Vector2 = wps[i]
			var dist_sq: float = local_pos.distance_squared_to(wp_pos)
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best = {"found": true, "key": key, "index": i}
	return best

func _zoom_at(new_zoom: float, screen_center: Vector2) -> void:
	var old_zoom = _current_zoom
	if _is_dev_mode():
		_current_zoom = clamp(new_zoom, ZOOM_MIN, ZOOM_MAX)
	else:
		_current_zoom = clamp(new_zoom, _get_min_zoom(), ZOOM_MAX)
	var factor = _current_zoom / old_zoom
	_map_content.position = screen_center + (_map_content.position - screen_center) * factor
	_map_content.scale = Vector2(_current_zoom, _current_zoom)
	_clamp_pan()

## Returns the minimum zoom level that keeps the background texture filling the
## entire viewport. The player can never zoom out far enough to see grey.
func _get_min_zoom() -> float:
	var bg: TextureRect = _map_content.get_node_or_null("MapBackground")
	if bg == null or bg.texture == null:
		return ZOOM_MIN
	var vp_size: Vector2 = get_viewport_rect().size
	var tex_size: Vector2 = Vector2(bg.texture.get_width(), bg.texture.get_height())
	# The map must cover the viewport on BOTH axes, so take the larger ratio.
	var min_zoom: float = maxf(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	# Never go below the hardcoded floor (e.g. tiny viewports shouldn't force huge zoom).
	return maxf(min_zoom, ZOOM_MIN)

## Snaps _current_zoom up to the dynamic minimum if it's currently too low.
## Called on map load / rebuild so the initial view never shows grey.
func _enforce_min_zoom() -> void:
	if _is_dev_mode():
		return
	var min_z := _get_min_zoom()
	if _current_zoom < min_z:
		_current_zoom = min_z
		_map_content.scale = Vector2(_current_zoom, _current_zoom)

## Constrains MapContent position so the background texture edges never scroll
## inside the viewport. The player cannot pan past the map boundary.
func _clamp_pan() -> void:
	if _is_dev_mode():
		return
	var bg: TextureRect = _map_content.get_node_or_null("MapBackground")
	if bg == null or bg.texture == null:
		return

	var vp_size: Vector2 = get_viewport_rect().size
	var map_size: Vector2 = Vector2(bg.texture.get_width(), bg.texture.get_height()) * _current_zoom

	# MapContent.position is the screen-space position of the map's top-left corner.
	# Constraints:
	#   Right edge of map  >= right edge of viewport  →  pos.x + map_size.x >= vp_size.x
	#   Bottom edge of map >= bottom edge of viewport →  pos.y + map_size.y >= vp_size.y
	#   Left edge of map   <= left edge of viewport   →  pos.x <= 0
	#   Top edge of map    <= top edge of viewport     →  pos.y <= 0
	var pos: Vector2 = _map_content.position

	if map_size.x <= vp_size.x:
		# Map smaller than viewport: center it
		pos.x = (vp_size.x - map_size.x) * 0.5
	else:
		pos.x = clampf(pos.x, vp_size.x - map_size.x, 0.0)

	if map_size.y <= vp_size.y:
		pos.y = (vp_size.y - map_size.y) * 0.5
	else:
		pos.y = clampf(pos.y, vp_size.y - map_size.y, 0.0)

	_map_content.position = pos

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_node_pressed(location: LocationNode, screen_pos: Vector2) -> void:
	if not is_initialized:
		return
	if _edit_mode:
		return   # edit-mode clicks are handled in _unhandled_input / _gui_input
	if player == null:
		return
	var game_root = _find_game_root()
	_radial_menu.show_for_node(location, screen_pos, player, game_root)
	if _top_bar:
		_top_bar.show_selected_location(location.display_name)

func _on_action_completed() -> void:
	_refresh_node_states()

func _on_radial_closed() -> void:
	if _top_bar:
		_top_bar.clear_selected_location()

func _on_location_entered(_location_id: StringName, _location: LocationNode, _first_visit: bool) -> void:
	_refresh_node_states()

func _on_travel_requested(destination: LocationNode) -> void:
	var waypoints = MapManager.find_path(GameState.map.current_location, destination.location_id)
	MapManager.travel_to_any(destination.location_id)
	_animate_player_marker_path(waypoints)

func _on_zone_entered(map_def: MapDefinition) -> void:
	MapManager.push_map(map_def)

func _on_map_changed(_map_def: MapDefinition) -> void:
	_rebuild_map_display()

func _on_leave_zone_pressed() -> void:
	MapManager.pop_map()

# ============================================================================
# EDIT MODE — TOGGLE
# ============================================================================

func _toggle_edit_mode() -> void:
	_set_edit_mode(not _edit_mode)

func _set_edit_mode(enabled: bool) -> void:
	_edit_mode = enabled
	_active_tool = EditTool.SELECT
	_connect_from_id = &""
	_drag_node_btn = null
	_drag_wp_key = ""
	_drag_wp_index = -1
	_drag_decor_index = -1
	_drag_light_index = -1
	_paths_drawer.preview_segment = {}
	_paths_drawer.queue_redraw()

	if _editor_toolbar:
		_editor_toolbar.visible = enabled
		_editor_toolbar.deactivate_tools()

	# Propagate to all node buttons
	for loc_id in _node_buttons:
		var btn = _node_buttons[loc_id]
		if is_instance_valid(btn):
			btn.set_edit_mode(enabled)

	_rebuild_waypoint_handles()
	_rebuild_light_markers()

# ============================================================================
# EDIT MODE — TOOLBAR CALLBACKS
# ============================================================================

func _on_add_node_mode_changed(active: bool) -> void:
	_active_tool = EditTool.ADD_NODE if active else EditTool.SELECT
	_connect_from_id = &""
	_paths_drawer.preview_segment = {}
	_paths_drawer.queue_redraw()

func _on_connect_mode_changed(active: bool) -> void:
	_active_tool = EditTool.CONNECT if active else EditTool.SELECT
	_connect_from_id = &""
	_paths_drawer.preview_segment = {}
	_paths_drawer.queue_redraw()

func _on_decor_mode_changed(active: bool) -> void:
	_active_tool = EditTool.DECOR if active else EditTool.SELECT

func _on_lighting_mode_changed(active: bool) -> void:
	_active_tool = EditTool.LIGHTING if active else EditTool.SELECT

# ============================================================================
# EDIT MODE — DIRTY TRACKING & SAVE
# ============================================================================

func _mark_dirty(res: Resource) -> void:
	if res not in _dirty_resources:
		_dirty_resources.append(res)
	if _editor_toolbar:
		_editor_toolbar.mark_dirty()

func _on_save_requested() -> void:
	for res in _dirty_resources:
		if is_instance_valid(res) and res.resource_path != "":
			ResourceSaver.save(res)
	_dirty_resources.clear()
	if _editor_toolbar:
		_editor_toolbar.mark_clean()

func _on_discard_requested() -> void:
	if _dirty_resources.is_empty():
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Discard all unsaved changes and reload from disk?"
	_ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void:
		_dirty_resources.clear()
		if _editor_toolbar:
			_editor_toolbar.mark_clean()
		_rebuild_map_display()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())

# ============================================================================
# EDIT MODE — NODE DRAG
# ============================================================================

func _on_node_drag_updated(location: LocationNode) -> void:
	_mark_dirty(location)
	_build_path_data()
	_paths_drawer.queue_redraw()
	# Update waypoint handle positions so they stay attached to the dragged node
	# (waypoints are on connections not on nodes, so no repositioning needed here)

func _on_node_drag_ended(_location: LocationNode) -> void:
	pass   # already dirty from _on_node_drag_updated

func _on_node_right_clicked_edit(location: LocationNode) -> void:
	var popup := PopupMenu.new()
	popup.add_item("Delete Node", 0)
	add_child(popup)
	popup.popup_on_parent(Rect2(get_local_mouse_position(), Vector2.ZERO))
	popup.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			_delete_node(location)
		popup.queue_free()
	)
	popup.popup_hide.connect(func() -> void: popup.queue_free())

func _delete_node(location: LocationNode) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null:
		return
	# Remove from map definition
	map_def.location_nodes.erase(location)
	# Remove connection references in all remaining nodes
	for node in map_def.location_nodes:
		if node == null:
			continue
		node.connections.erase(location.location_id)
		node.one_way_connections.erase(location.location_id)
		_mark_dirty(node)
	# Remove any waypoints associated with this node
	var keys_to_remove: Array = []
	for key in map_def.connection_waypoints:
		if str(location.location_id) in key:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		map_def.connection_waypoints.erase(key)
	_mark_dirty(map_def)
	_rebuild_map_display()

# ============================================================================
# EDIT MODE — CONNECTION TOOL
# ============================================================================

func _handle_connect_click(location: LocationNode) -> void:
	if _connect_from_id == &"":
		# First click — store origin and show preview endpoint at this node
		_connect_from_id = location.location_id
		_highlight_connect_from(true)
	else:
		# Second click — complete the connection
		var to_id := location.location_id
		if to_id != _connect_from_id:
			_show_connection_type_dialog(_connect_from_id, to_id)
		_connect_from_id = &""
		_highlight_connect_from(false)
		_paths_drawer.preview_segment = {}
		_paths_drawer.queue_redraw()

func _highlight_connect_from(active: bool) -> void:
	var btn = _node_buttons.get(_connect_from_id)
	if btn and is_instance_valid(btn):
		btn.modulate = Color(0.6, 1.0, 0.6) if active else Color.WHITE

func _show_connection_type_dialog(from_id: StringName, to_id: StringName) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Connection Type"
	dialog.dialog_text = str(from_id) + "  →  " + str(to_id)
	dialog.get_ok_button().text = "Bidirectional"
	dialog.add_button("One-Way", true, "one_way")
	_ui_layer.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void:
		_create_connection(from_id, to_id, false)
		dialog.queue_free()
	)
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"one_way":
			_create_connection(from_id, to_id, true)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())

func _create_connection(from_id: StringName, to_id: StringName, one_way: bool) -> void:
	var from_node := MapManager.get_location(from_id)
	var to_node   := MapManager.get_location(to_id)
	if from_node == null or to_node == null:
		return
	if one_way:
		if not from_node.one_way_connections.has(to_id):
			from_node.one_way_connections.append(to_id)
			_mark_dirty(from_node)
	else:
		if not from_node.connections.has(to_id):
			from_node.connections.append(to_id)
			_mark_dirty(from_node)
		if not to_node.connections.has(from_id):
			to_node.connections.append(from_id)
			_mark_dirty(to_node)
	_build_path_data()
	_paths_drawer.queue_redraw()

func _show_path_context_menu(key: String) -> void:
	var popup := PopupMenu.new()
	popup.add_item("Delete Connection", 0)
	popup.add_item("Clear Waypoints",   1)
	add_child(popup)
	popup.popup_on_parent(Rect2(get_local_mouse_position(), Vector2.ZERO))
	popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _delete_connection(key)
			1: _clear_waypoints(key)
		popup.queue_free()
	)
	popup.popup_hide.connect(func() -> void: popup.queue_free())

func _delete_connection(key: String) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null:
		return
	# Determine the two node IDs from the key.
	# One-way keys use ">" separator, bidirectional keys use PAIR_SEP ("<->").
	if ">" in key and PAIR_SEP not in key:
		var sep_idx := key.find(">")
		var from_id := StringName(key.left(sep_idx))
		var to_id   := StringName(key.substr(sep_idx + 1))
		var from_node := MapManager.get_location(from_id)
		if from_node:
			from_node.one_way_connections.erase(to_id)
			_mark_dirty(from_node)
	elif PAIR_SEP in key:
		var sep_idx := key.find(PAIR_SEP)
		var id_a := StringName(key.left(sep_idx))
		var id_b := StringName(key.substr(sep_idx + PAIR_SEP.length()))
		var node_a := MapManager.get_location(id_a)
		var node_b := MapManager.get_location(id_b)
		if node_a:
			node_a.connections.erase(id_b)
			_mark_dirty(node_a)
		if node_b:
			node_b.connections.erase(id_a)
			_mark_dirty(node_b)
	map_def.connection_waypoints.erase(key)
	_mark_dirty(map_def)
	_rebuild_waypoint_handles()
	_build_path_data()
	_paths_drawer.queue_redraw()

# ============================================================================
# EDIT MODE — WAYPOINTS
# ============================================================================

func _add_waypoint(key: String, insert_index: int, pos: Vector2) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null:
		return
	if not map_def.connection_waypoints.has(key):
		map_def.connection_waypoints[key] = []
	var waypoints: Array = map_def.connection_waypoints[key]
	waypoints.insert(insert_index, pos)
	_mark_dirty(map_def)
	_rebuild_waypoint_handles()
	_build_path_data()
	_paths_drawer.queue_redraw()

func _clear_waypoints(key: String) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null:
		return
	map_def.connection_waypoints.erase(key)
	_mark_dirty(map_def)
	_rebuild_waypoint_handles()
	_build_path_data()
	_paths_drawer.queue_redraw()

func _rebuild_waypoint_handles() -> void:
	# Remove all existing handles
	for k in _waypoint_handles:
		for handle in _waypoint_handles[k]:
			if is_instance_valid(handle):
				handle.queue_free()
	_waypoint_handles.clear()

	if not _edit_mode:
		return

	var map_def := MapManager.get_current_map()
	if map_def == null:
		return

	for key in map_def.connection_waypoints:
		var wps: Array = map_def.connection_waypoints[key]
		var handles: Array = []
		for i in range(wps.size()):
			var handle = MapWaypointHandle.new()
			_nodes_layer.add_child(handle)
			handle.setup(key, i, wps[i])
			handle.handle_moved.connect(_on_waypoint_moved)
			handle.handle_right_clicked.connect(_on_waypoint_right_clicked)
			handles.append(handle)
		_waypoint_handles[key] = handles

func _on_waypoint_moved(key: String, index: int, new_pos: Vector2) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null or not map_def.connection_waypoints.has(key):
		return
	map_def.connection_waypoints[key][index] = new_pos
	_mark_dirty(map_def)
	_build_path_data()
	_paths_drawer.queue_redraw()

func _on_waypoint_right_clicked(key: String, index: int) -> void:
	var popup := PopupMenu.new()
	popup.add_item("Delete Waypoint", 0)
	add_child(popup)
	popup.popup_on_parent(Rect2(get_local_mouse_position(), Vector2.ZERO))
	popup.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			_delete_waypoint(key, index)
		popup.queue_free()
	)
	popup.popup_hide.connect(func() -> void: popup.queue_free())

func _delete_waypoint(key: String, index: int) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null or not map_def.connection_waypoints.has(key):
		return
	map_def.connection_waypoints[key].remove_at(index)
	if map_def.connection_waypoints[key].is_empty():
		map_def.connection_waypoints.erase(key)
	_mark_dirty(map_def)
	_rebuild_waypoint_handles()
	_build_path_data()
	_paths_drawer.queue_redraw()

# ============================================================================
# EDIT MODE — ADD NODE
# ============================================================================

func _begin_add_node_at(map_pos: Vector2) -> void:
	_editor_toolbar.deactivate_tools()
	_active_tool = EditTool.SELECT

	var win := Window.new()
	win.title       = "New Map Location"
	win.size        = Vector2i(340, 170)
	win.unresizable = true
	win.wrap_controls = true

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var id_lbl := Label.new()
	id_lbl.text = "Location ID  (unique snake_case name):"
	vbox.add_child(id_lbl)

	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "e.g.  forest_camp"
	vbox.add_child(id_edit)

	var hbox_type := HBoxContainer.new()
	vbox.add_child(hbox_type)
	var type_lbl := Label.new()
	type_lbl.text = "Type:"
	hbox_type.add_child(type_lbl)
	var type_opt := OptionButton.new()
	type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for type_name in ["Town", "Camp", "Dungeon", "Boss", "Event", "Shrine", "Treasure", "Crossroads", "Hidden"]:
		type_opt.add_item(type_name)
	hbox_type.add_child(type_opt)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancel"
	btn_row.add_child(btn_cancel)

	var btn_ok := Button.new()
	btn_ok.text = "Create"
	btn_row.add_child(btn_ok)

	_ui_layer.add_child(win)
	win.popup_centered()
	id_edit.grab_focus()

	# Map type_opt index to LocationNode.NodeType enum
	const TYPE_MAP: Dictionary = {
		0: LocationNode.NodeType.TOWN,
		1: LocationNode.NodeType.CAMP,
		2: LocationNode.NodeType.DUNGEON,
		3: LocationNode.NodeType.BOSS,
		4: LocationNode.NodeType.EVENT,
		5: LocationNode.NodeType.SHRINE,
		6: LocationNode.NodeType.TREASURE,
		7: LocationNode.NodeType.CROSSROADS,
		8: LocationNode.NodeType.HIDDEN,
	}

	btn_ok.pressed.connect(func() -> void:
		var node_id := StringName(id_edit.text.strip_edges().to_lower().replace(" ", "_"))
		if node_id == &"":
			return
		_create_new_location(node_id, TYPE_MAP.get(type_opt.get_selected_id(), LocationNode.NodeType.EVENT), map_pos)
		win.queue_free()
	)
	btn_cancel.pressed.connect(func() -> void: win.queue_free())
	win.close_requested.connect(func() -> void: win.queue_free())

func _create_new_location(node_id: StringName, node_type: int, map_pos: Vector2) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null:
		push_error("MapEditor: cannot create node — no active MapDefinition")
		return

	if MapManager.get_location(node_id) != null:
		push_warning("MapEditor: location_id '%s' already exists, skipping." % node_id)
		return

	var loc := LocationNode.new()
	loc.location_id      = node_id
	loc.display_name     = str(node_id).replace("_", " ").capitalize()
	loc.map_position     = map_pos
	loc.node_type        = node_type
	loc.initial_visibility = LocationNode.VisibilityState.VISIBLE

	# Derive save path from the MapDefinition's folder
	var map_folder := map_def.resource_path.get_base_dir()   # e.g. "res://resources/maps/test"
	var save_path  := map_folder + "/loc_" + str(node_id) + ".tres"
	loc.resource_path = save_path
	ResourceSaver.save(loc)

	map_def.location_nodes.append(loc)
	MapManager.register_location(loc)

	# Auto-unlock/reveal since we just created it (editor convenience)
	GameState.map.unlock(node_id)
	GameState.map.reveal(node_id)

	_mark_dirty(map_def)
	_spawn_node_button(loc)
	_build_path_data()
	_paths_drawer.queue_redraw()

# ============================================================================
# PLAYER MARKER
# ============================================================================

const MARKER_HALF := Vector2(16.0, 16.0)
## Player marker travel speed in map-space pixels per second.
## Higher = faster travel. Duration is computed from path length.
@export var travel_speed: float = 800.0

func _snap_player_marker_to_current() -> void:
	var center = _get_current_location_center()
	if center == Vector2.ZERO:
		_player_marker.visible = false
		return
	_player_marker.position = center - MARKER_HALF
	_player_marker.visible = true

## Returns the MapContent position that would center the player marker on screen.
func _get_player_centered_pos() -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	var marker_center: Vector2 = _player_marker.position + MARKER_HALF
	return (vp_size * 0.5) - (marker_center * _current_zoom)

## Instantly centers the viewport on the player marker's current position.
func _center_on_player() -> void:
	_map_content.position = _get_player_centered_pos()
	_clamp_pan()

func _animate_player_marker_path(path_ids: Array[StringName]) -> void:
	_player_marker.visible = true
	if path_ids.is_empty():
		_refresh_node_states()
		_open_radial_for_current_location()
		return

	_is_traveling = true

	var start_loc = MapManager.get_location(path_ids[0])
	if start_loc:
		_player_marker.position = start_loc.map_position + NODE_CENTER_OFFSET - MARKER_HALF

	var map_def := MapManager.get_current_map()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)

	for i in range(1, path_ids.size()):
		var from_loc = MapManager.get_location(path_ids[i - 1])
		var to_loc   = MapManager.get_location(path_ids[i])
		if from_loc == null or to_loc == null:
			continue

		# Look up curve waypoints for this connection
		var curve_wps: Array = _get_connection_waypoints(
			map_def, path_ids[i - 1], path_ids[i],
			from_loc.map_position, to_loc.map_position)

		if curve_wps.is_empty():
			# Straight line — duration from distance
			var dist: float = from_loc.map_position.distance_to(to_loc.map_position)
			var dur: float = maxf(dist / travel_speed, 0.05)
			tween.tween_property(_player_marker, "position",
				to_loc.map_position + NODE_CENTER_OFFSET - MARKER_HALF, dur)
		else:
			# Bake spline and tween through each baked point
			var all_pts: Array = [from_loc.map_position] + curve_wps + [to_loc.map_position]
			var baked: PackedVector2Array = _paths_drawer._bake_catmull_rom(all_pts, 10)
			for j in range(1, baked.size()):
				var seg_dist: float = baked[j - 1].distance_to(baked[j])
				var seg_dur: float = maxf(seg_dist / travel_speed, 0.01)
				tween.tween_property(_player_marker, "position",
					baked[j] + NODE_CENTER_OFFSET - MARKER_HALF, seg_dur)

	tween.tween_callback(func() -> void: _is_traveling = false)
	tween.tween_callback(_refresh_node_states)
	tween.tween_callback(_open_radial_for_current_location)

## Returns the curve waypoints for the connection between two locations,
## handling both bidirectional and one-way key formats. Reverses the array
## when the travel direction is opposite to the key's stored order.
func _get_connection_waypoints(map_def: Resource, from_id: StringName, to_id: StringName,
		from_pos: Vector2, to_pos: Vector2) -> Array:
	if map_def == null or map_def.connection_waypoints.is_empty():
		return []

	# Try bidirectional key
	var bidir_key := _pair_key(from_id, to_id)
	if map_def.connection_waypoints.has(bidir_key):
		var wps: Array = map_def.connection_waypoints[bidir_key]
		# _pair_key sorts alphabetically — if from_id sorted second, we're
		# travelling in the reverse direction, so reverse the waypoints.
		var sa := str(from_id)
		var sb := str(to_id)
		if sa > sb:
			var reversed: Array = wps.duplicate()
			reversed.reverse()
			return reversed
		return wps

	# Try one-way key (from>to)
	var oneway_key := str(from_id) + ">" + str(to_id)
	if map_def.connection_waypoints.has(oneway_key):
		return map_def.connection_waypoints[oneway_key]

	# Try reverse one-way (to>from) — shouldn't normally be traversed this way,
	# but return reversed waypoints just in case.
	var reverse_key := str(to_id) + ">" + str(from_id)
	if map_def.connection_waypoints.has(reverse_key):
		var reversed: Array = map_def.connection_waypoints[reverse_key].duplicate()
		reversed.reverse()
		return reversed

	return []

func _open_radial_for_current_location() -> void:
	var loc = MapManager.get_current_location()
	if loc == null:
		return
	var btn = _node_buttons.get(loc.location_id)
	if btn == null or not is_instance_valid(btn):
		return
	var screen_pos = btn.get_global_transform() * btn.pivot_offset
	_radial_menu.show_for_node(loc, screen_pos, player, _find_game_root())

func _get_current_location_center() -> Vector2:
	var current_id = GameState.map.current_location
	if current_id == &"":
		return Vector2.ZERO
	var location = MapManager.get_location(current_id)
	if location == null:
		return Vector2.ZERO
	return location.map_position + NODE_CENTER_OFFSET

# ============================================================================
# HELPERS
# ============================================================================

func _find_game_root() -> Node:
	var node = get_parent()
	while node:
		if node.has_method("enter_dungeon"):
			return node
		node = node.get_parent()
	return null

func _is_interaction_blocked() -> bool:
	"""Returns true when an overlay (menu, dialogue, combat) should block map input."""
	if DialogueManager and DialogueManager.is_active:
		return true
	var gr = _find_game_root()
	if gr:
		if gr.get("is_in_combat") == true:
			return true
		var menu = gr.get("player_menu")
		if menu and menu.visible:
			return true
	return false

func _is_dev_mode() -> bool:
	var gr = _find_game_root()
	return gr != null and gr.get("dev_mode") == true

# ============================================================================
# DECOR LAYER
# ============================================================================

func _rebuild_decor() -> void:
	# Clear existing decor nodes
	for node in _decor_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_decor_nodes.clear()

	var map_def := MapManager.get_current_map()
	if map_def == null:
		return

	for item: MapDecorItem in map_def.decor_items:
		if item == null or item.texture == null:
			_decor_nodes.append(null)
			continue
		var tex_rect := TextureRect.new()
		tex_rect.texture = item.texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex_size: Vector2 = Vector2(item.texture.get_width(), item.texture.get_height()) * item.item_scale
		tex_rect.size = tex_size
		tex_rect.pivot_offset = tex_size * 0.5
		tex_rect.position = item.position - tex_size * 0.5
		tex_rect.rotation = deg_to_rad(item.rotation_deg)
		tex_rect.modulate = item.tint
		tex_rect.flip_h = item.flip_h
		tex_rect.z_index = item.z_offset
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_decor_layer.add_child(tex_rect)
		_decor_nodes.append(tex_rect)

func _find_decor_at(local_pos: Vector2) -> int:
	var map_def := MapManager.get_current_map()
	if map_def == null:
		return -1
	var best_index: int = -1
	var best_dist_sq: float = DECOR_HIT_RADIUS * DECOR_HIT_RADIUS
	for i in range(map_def.decor_items.size()):
		var item: MapDecorItem = map_def.decor_items[i]
		if item == null:
			continue
		var dist_sq: float = local_pos.distance_squared_to(item.position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_index = i
	return best_index

func _place_decor_at(pos: Vector2) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null:
		return
	var item := MapDecorItem.new()
	item.position = pos
	# Texture will be null until the user configures it via right-click or palette.
	# For now, create a placeholder with a visible marker.
	map_def.decor_items.append(item)
	_mark_dirty(map_def)
	_rebuild_decor()

func _delete_decor(index: int) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null or index < 0 or index >= map_def.decor_items.size():
		return
	map_def.decor_items.remove_at(index)
	_mark_dirty(map_def)
	_rebuild_decor()

func _update_decor_position(index: int, new_pos: Vector2) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null or index < 0 or index >= map_def.decor_items.size():
		return
	map_def.decor_items[index].position = new_pos
	# Update the visual node directly (no full rebuild needed during drag)
	if index < _decor_nodes.size() and is_instance_valid(_decor_nodes[index]):
		var tex_rect: TextureRect = _decor_nodes[index]
		var half_size: Vector2 = tex_rect.size * 0.5
		tex_rect.position = new_pos - half_size
	_mark_dirty(map_def)

func _show_decor_context_menu(index: int) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null or index < 0 or index >= map_def.decor_items.size():
		return
	var item: MapDecorItem = map_def.decor_items[index]
	var popup := PopupMenu.new()
	popup.add_item("Delete Decor", 0)
	popup.add_item("Flip Horizontal", 1)
	popup.add_separator()
	popup.add_item("Scale Up (x1.25)", 2)
	popup.add_item("Scale Down (x0.8)", 3)
	popup.add_separator()
	popup.add_item("Rotate +15°", 4)
	popup.add_item("Rotate -15°", 5)
	add_child(popup)
	popup.popup_on_parent(Rect2(get_local_mouse_position(), Vector2.ZERO))
	popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _delete_decor(index)
			1:
				item.flip_h = not item.flip_h
				_mark_dirty(map_def)
				_rebuild_decor()
			2:
				item.item_scale *= 1.25
				_mark_dirty(map_def)
				_rebuild_decor()
			3:
				item.item_scale *= 0.8
				_mark_dirty(map_def)
				_rebuild_decor()
			4:
				item.rotation_deg += 15.0
				_mark_dirty(map_def)
				_rebuild_decor()
			5:
				item.rotation_deg -= 15.0
				_mark_dirty(map_def)
				_rebuild_decor()
		popup.queue_free()
	)
	popup.popup_hide.connect(func() -> void: popup.queue_free())

# ============================================================================
# LIGHTING OVERLAY
# ============================================================================

func _get_lighting_config() -> MapLightingConfig:
	"""Return the current map's lighting config, falling back to the scene default."""
	var map_def := MapManager.get_current_map()
	if map_def and map_def.lighting_config:
		print("[MapLighting] _get_lighting_config → map's own config")
		return map_def.lighting_config
	if default_lighting_config == null:
		# Export may be null if the .tres hasn't been imported yet.
		# Build the default in code so every map gets shadows + light rays.
		default_lighting_config = MapLightingConfig.new()
		default_lighting_config.ambient_color = Color(0, 0, 0, 0)
		default_lighting_config.light_direction = Vector2(-0.5, -0.9)
		default_lighting_config.shadow_opacity = 0.65
		default_lighting_config.shadow_softness = 4.0
		default_lighting_config.light_rays_enabled = true
		print("[MapLighting] _get_lighting_config → created default in code")
	print("[MapLighting] _get_lighting_config → default fallback")
	return default_lighting_config

func _apply_lighting() -> void:
	var config: MapLightingConfig = _get_lighting_config()

	if config == null:
		_lighting_overlay.visible = false
		_light_rays_overlay.visible = false
		_clear_shadows()
		return

	_lighting_overlay.visible = true
	# Match overlay size to MapContent so UV calculations are correct
	_lighting_overlay.size = _map_content.size
	var mat: ShaderMaterial = _lighting_overlay.material
	mat.set_shader_parameter("ambient_color", config.ambient_color)
	mat.set_shader_parameter("vignette_strength", config.vignette_strength)
	mat.set_shader_parameter("vignette_softness", config.vignette_softness)

	# Pack light data into uniform arrays
	var count: int = mini(config.lights.size(), 8)
	mat.set_shader_parameter("light_count", count)

	var overlay_size: Vector2 = _lighting_overlay.size
	var positions: Array = []
	var colors: Array = []
	var energies: Array = []
	var radii: Array = []

	for i in range(8):
		if i < count and config.lights[i] != null:
			var light: MapLightEntry = config.lights[i]
			# Convert map-space position to UV (0..1) relative to overlay rect
			positions.append(light.position / overlay_size)
			colors.append(Vector3(light.color.r, light.color.g, light.color.b))
			energies.append(light.energy)
			radii.append(light.radius / overlay_size.x)  # normalize by width
		else:
			positions.append(Vector2.ZERO)
			colors.append(Vector3.ZERO)
			energies.append(0.0)
			radii.append(0.0)

	mat.set_shader_parameter("light_positions", positions)
	mat.set_shader_parameter("light_colors", colors)
	mat.set_shader_parameter("light_energies", energies)
	mat.set_shader_parameter("light_radii", radii)

	# --- Drop shadows (offset duplicate nodes in ShadowLayer) ---
	_rebuild_shadows(config)

	# --- Light rays ---
	var dir = config.light_direction.normalized()
	if config.light_rays_enabled:
		_light_rays_overlay.visible = true
		_light_rays_overlay.size = _map_content.size
		var rays_mat: ShaderMaterial = _light_rays_overlay.material
		rays_mat.set_shader_parameter("light_direction", dir)
		rays_mat.set_shader_parameter("ray_color", config.light_rays_color)
		rays_mat.set_shader_parameter("energy", config.light_rays_energy)
	else:
		_light_rays_overlay.visible = false

func _rebuild_shadows_deferred() -> void:
	"""Wait two frames for VBoxContainer layout, then rebuild shadows.
	Frame 1: queue_free'd old buttons are cleaned up.
	Frame 2: layout engine computes final sizes for new buttons."""
	await get_tree().process_frame
	await get_tree().process_frame
	# Force pivot recalculation on all node buttons. On re-entry from a zone
	# the VBoxContainer may already be at its final size so the resized signal
	# never fires, leaving pivot_offset at the scene default.
	for loc_id in _node_buttons:
		var btn = _node_buttons[loc_id]
		if is_instance_valid(btn) and btn.has_method("_update_pivot_and_position"):
			btn._update_pivot_and_position()
	var config: MapLightingConfig = _get_lighting_config()
	if config:
		_rebuild_shadows(config)

func _clear_shadows() -> void:
	for node in _shadow_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_shadow_nodes.clear()

func _rebuild_shadows(config: MapLightingConfig) -> void:
	var is_deferred = not _shadow_nodes.is_empty()
	var call_label = "DEFERRED" if is_deferred else "IMMEDIATE"
	print("[MapLighting] _rebuild_shadows (%s)" % call_label)
	print("[MapLighting]   _shadow_layer.position: %s, .size: %s, .global_position: %s" % [_shadow_layer.position, _shadow_layer.size, _shadow_layer.global_position])
	print("[MapLighting]   _map_content.position: %s, .size: %s, .scale: %s" % [_map_content.position, _map_content.size, _map_content.scale])
	_clear_shadows()
	if config.shadow_opacity <= 0.0:
		return

	var shadow_dir: Vector2 = -config.light_direction.normalized() * config.shadow_offset
	var shadow_color := Color(0.0, 0.0, 0.0, config.shadow_opacity)
	# Slight scale-up gives a natural soft edge from texture filtering
	var softness_scale: float = 1.0 + config.shadow_softness * 0.005

	# --- Decor shadows ---
	var decor_count := 0
	var map_def := MapManager.get_current_map()
	if map_def:
		for item: MapDecorItem in map_def.decor_items:
			if item == null or item.texture == null:
				continue
			var shadow := TextureRect.new()
			shadow.texture = item.texture
			shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var tex_size: Vector2 = Vector2(item.texture.get_width(), item.texture.get_height()) * item.item_scale * softness_scale
			shadow.size = tex_size
			shadow.pivot_offset = tex_size * 0.5
			shadow.position = item.position + shadow_dir - tex_size * 0.5
			shadow.rotation = deg_to_rad(item.rotation_deg)
			shadow.modulate = shadow_color
			shadow.flip_h = item.flip_h
			shadow.z_index = item.z_offset
			shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_shadow_layer.add_child(shadow)
			_shadow_nodes.append(shadow)
			if decor_count < 3:
				print("[MapLighting]   Decor shadow '%s': item.pos=%s, shadow.pos=%s, shadow.size=%s" % [item.texture.resource_path.get_file(), item.position, shadow.position, shadow.size])
			decor_count += 1
		print("[MapLighting]   Total decor shadows: %d" % decor_count)

	# --- Node button shadows ---
	# Use the icon's actual layout rect (not texture natural size) so the shadow
	# matches the displayed size and position within the button.
	var node_shadow_count := 0
	var node_skipped_layout := 0
	for loc_id in _node_buttons:
		var btn = _node_buttons[loc_id]
		if not is_instance_valid(btn) or btn.location_node == null:
			continue
		var icon_rect = btn.find_child("Icon", true, false)
		if not icon_rect or not icon_rect is TextureRect or not icon_rect.texture:
			continue
		if icon_rect.size.x < 1.0 or icon_rect.size.y < 1.0:
			node_skipped_layout += 1
			print("[MapLighting]   SKIPPED node '%s' — icon.size=%s (layout not ready)" % [loc_id, icon_rect.size])
			continue  # Layout not computed yet — skip
		var btn_scale = Vector2(btn.scale)
		var btn_pivot = Vector2(btn.pivot_offset)
		# Get icon's position relative to the button root by walking up the tree
		var icon_local_pos := Vector2(icon_rect.position)
		var parent_node = icon_rect.get_parent()
		while parent_node != null and parent_node != btn:
			icon_local_pos += Vector2(parent_node.position)
			parent_node = parent_node.get_parent()
		# Icon's center in button-local coords
		var icon_local_center: Vector2 = icon_local_pos + Vector2(icon_rect.size) * 0.5
		# Map to parent space accounting for pivot_offset + scale:
		# visual_pos = btn.position + pivot + scale * (local - pivot)
		var icon_center: Vector2 = Vector2(btn.position) + btn_pivot + btn_scale * (icon_local_center - btn_pivot)
		var shadow_size = Vector2(icon_rect.size) * btn_scale * softness_scale
		var btn_shadow := TextureRect.new()
		btn_shadow.texture = icon_rect.texture
		btn_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		btn_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btn_shadow.size = shadow_size
		btn_shadow.pivot_offset = shadow_size * 0.5
		btn_shadow.position = icon_center + shadow_dir - shadow_size * 0.5
		btn_shadow.modulate = shadow_color
		btn_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shadow_layer.add_child(btn_shadow)
		_shadow_nodes.append(btn_shadow)
		if node_shadow_count < 3:
			print("[MapLighting]   Node shadow '%s': btn.pos=%s, btn.pivot=%s, btn.scale=%s, icon_center=%s, shadow.pos=%s" % [loc_id, btn.position, btn_pivot, btn_scale, icon_center, btn_shadow.position])
		node_shadow_count += 1
	print("[MapLighting]   Total node shadows: %d, skipped (no layout): %d" % [node_shadow_count, node_skipped_layout])

	# --- Player marker shadow (shader on AnimatedSprite2D) ---
	if _player_map_sprite and _player_map_sprite.material is ShaderMaterial:
		var sprite_mat: ShaderMaterial = _player_map_sprite.material
		sprite_mat.set_shader_parameter("shadow_direction", config.light_direction.normalized())
		sprite_mat.set_shader_parameter("shadow_offset_px", config.shadow_offset)
		sprite_mat.set_shader_parameter("shadow_opacity", config.shadow_opacity)
		sprite_mat.set_shader_parameter("shadow_softness_px", config.shadow_softness)

func _find_light_at(local_pos: Vector2) -> int:
	var map_def := MapManager.get_current_map()
	if map_def == null or map_def.lighting_config == null:
		return -1
	var best_index: int = -1
	var best_dist_sq: float = LIGHT_HIT_RADIUS * LIGHT_HIT_RADIUS
	for i in range(map_def.lighting_config.lights.size()):
		var light: MapLightEntry = map_def.lighting_config.lights[i]
		if light == null:
			continue
		var dist_sq: float = local_pos.distance_squared_to(light.position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_index = i
	return best_index

func _place_light_at(pos: Vector2) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null:
		return
	if map_def.lighting_config == null:
		map_def.lighting_config = MapLightingConfig.new()
	var light := MapLightEntry.new()
	light.position = pos
	map_def.lighting_config.lights.append(light)
	_mark_dirty(map_def)
	_apply_lighting()
	_rebuild_light_markers()

func _delete_light(index: int) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null or map_def.lighting_config == null:
		return
	if index < 0 or index >= map_def.lighting_config.lights.size():
		return
	map_def.lighting_config.lights.remove_at(index)
	_mark_dirty(map_def)
	_apply_lighting()
	_rebuild_light_markers()

func _update_light_position(index: int, new_pos: Vector2) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null or map_def.lighting_config == null:
		return
	if index < 0 or index >= map_def.lighting_config.lights.size():
		return
	map_def.lighting_config.lights[index].position = new_pos
	_mark_dirty(map_def)
	_apply_lighting()
	# Update marker visual
	if index < _light_markers.size() and is_instance_valid(_light_markers[index]):
		_light_markers[index].position = new_pos - Vector2(8, 8)

func _rebuild_light_markers() -> void:
	for marker in _light_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_light_markers.clear()

	if not _edit_mode:
		return

	var map_def := MapManager.get_current_map()
	if map_def == null or map_def.lighting_config == null:
		return

	for light: MapLightEntry in map_def.lighting_config.lights:
		if light == null:
			continue
		var marker := _create_light_marker(light)
		_nodes_layer.add_child(marker)
		_light_markers.append(marker)

func _create_light_marker(light: MapLightEntry) -> Control:
	"""Creates a small sun-shaped marker for a light source in edit mode."""
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(16, 16)
	ctrl.size = Vector2(16, 16)
	ctrl.position = light.position - Vector2(8, 8)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Draw a simple colored circle via a ColorRect for now
	var dot := ColorRect.new()
	dot.color = Color(light.color.r, light.color.g, light.color.b, 0.9)
	dot.size = Vector2(16, 16)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(dot)
	return ctrl

func _show_light_context_menu(index: int) -> void:
	var map_def := MapManager.get_current_map()
	if map_def == null or map_def.lighting_config == null:
		return
	if index < 0 or index >= map_def.lighting_config.lights.size():
		return
	var light: MapLightEntry = map_def.lighting_config.lights[index]
	var popup := PopupMenu.new()
	popup.add_item("Delete Light", 0)
	popup.add_separator()
	popup.add_item("Radius +50", 1)
	popup.add_item("Radius -50", 2)
	popup.add_separator()
	popup.add_item("Energy +0.25", 3)
	popup.add_item("Energy -0.25", 4)
	add_child(popup)
	popup.popup_on_parent(Rect2(get_local_mouse_position(), Vector2.ZERO))
	popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _delete_light(index)
			1:
				light.radius = maxf(light.radius + 50.0, 10.0)
				_mark_dirty(map_def)
				_apply_lighting()
			2:
				light.radius = maxf(light.radius - 50.0, 10.0)
				_mark_dirty(map_def)
				_apply_lighting()
			3:
				light.energy = minf(light.energy + 0.25, 3.0)
				_mark_dirty(map_def)
				_apply_lighting()
			4:
				light.energy = maxf(light.energy - 0.25, 0.0)
				_mark_dirty(map_def)
				_apply_lighting()
		popup.queue_free()
	)
	popup.popup_hide.connect(func() -> void: popup.queue_free())
