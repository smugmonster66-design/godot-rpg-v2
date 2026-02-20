# res://scripts/dungeon/dungeon_map.gd
## Vertical flowchart dungeon map (Slay the Spire style).
## Replaces DungeonCorridorBuilder.
##
## Reads DungeonRun → lays out nodes → draws bezier paths → manages fog
## and a player token that tweens along chosen paths.
extends Node2D
class_name DungeonMap

signal node_selected(node_id: int)

# ============================================================================
# CONFIGURATION
# ============================================================================
@export var node_scene: PackedScene = null

@export_group("Layout")
@export var row_spacing: float = 200.0
@export var column_spacing: float = 200.0
@export var jitter_x: float = 20.0
@export var jitter_y: float = 12.0
@export var map_width: float = 1080.0
@export var vertical_padding: float = 150.0

@export_group("Paths")
@export var path_width: float = 3.5
@export var path_color: Color = Color(0.55, 0.45, 0.3, 0.7)
@export var path_color_completed: Color = Color(0.85, 0.75, 0.5, 0.95)
@export var path_color_available: Color = Color(0.75, 0.65, 0.4, 0.9)
@export var path_color_locked: Color = Color(0.25, 0.22, 0.2, 0.35)
@export var bezier_segments: int = 20

@export_group("Fog")
@export_range(0, 1) var fog_mode: int = 0
@export var fog_color: Color = Color(0.08, 0.06, 0.12, 0.92)
@export var fog_reveal_ahead: int = 1

@export_group("Player Token")
@export var token_tween_duration: float = 0.5
@export var token_scale: float = 0.8

@export_group("Camera")
@export var camera_tween_duration: float = 0.6
@export var intro_duration: float = 2.5
@export var intro_pause_at_boss: float = 0.4

# ============================================================================
# REFERENCES
# ============================================================================
var camera: Camera2D = null

@onready var path_container: Node2D = $PathLines
@onready var node_container: Node2D = $Nodes
@onready var fog_container: Node2D = $FogOverlays
@onready var player_token: Sprite2D = $PlayerToken

# ============================================================================
# STATE
# ============================================================================
var _run: DungeonRun = null
var _map_nodes: Dictionary = {}
var _node_positions: Dictionary = {}
var _path_lines: Dictionary = {}
var _path_points: Dictionary = {}
var _fog_rects: Dictionary = {}
var _current_node_id: int = -1
var _transitioning: bool = false
var _intro_playing: bool = false

# ============================================================================
# BUILD / CLEAR
# ============================================================================

func build_map(run: DungeonRun):
	clear_map()
	_run = run

	if not node_scene:
		push_error("DungeonMap: No node_scene assigned!")
		return

	_layout_nodes()
	_draw_all_paths()
	_setup_fog()
	_init_player_token()
	_set_initial_states()
	_apply_theme(run.definition)

	_fit_camera_zoom()    # ← ADD THIS

	_play_intro()
	print("🗺️ Map built: %d nodes, %d floors" % [_map_nodes.size(), run.definition.floor_count])


func clear_map():
	for n in _map_nodes.values():
		if is_instance_valid(n): n.queue_free()
	_map_nodes.clear()
	_node_positions.clear()
	for line in _path_lines.values():
		if is_instance_valid(line): line.queue_free()
	_path_lines.clear()
	_path_points.clear()
	for fog in _fog_rects.values():
		if is_instance_valid(fog): fog.queue_free()
	_fog_rects.clear()
	_run = null
	_current_node_id = -1
	_transitioning = false
	_intro_playing = false

# ============================================================================
# LAYOUT
# ============================================================================

func _layout_nodes():
	var center_x = map_width / 2.0
	for f in range(_run.definition.floor_count):
		var node_ids: Array = _run.floors[f]
		var count = node_ids.size()
		for i in count:
			var node_data: DungeonNodeData = _run.get_node(node_ids[i])
			if not node_data: continue
			var x = _get_node_x(i, count, center_x)
			var y = -(f * row_spacing) - vertical_padding
			if node_data.node_type != DungeonEnums.NodeType.START and \
			   node_data.node_type != DungeonEnums.NodeType.BOSS:
				x += randf_range(-jitter_x, jitter_x)
				y += randf_range(-jitter_y, jitter_y)
			var pos = Vector2(x, y)
			_node_positions[node_data.id] = pos
			_spawn_node(node_data, pos)

func _get_node_x(index: int, total: int, center_x: float) -> float:
	if total == 1: return center_x
	var row_width = (total - 1) * column_spacing
	return center_x - row_width / 2.0 + index * column_spacing

func _spawn_node(data: DungeonNodeData, pos: Vector2):
	var instance: DungeonMapNode = node_scene.instantiate()
	node_container.add_child(instance)
	instance.global_position = pos
	var icon_tex: Texture2D = null
	var icon_path = data.get_icon_path()
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_tex = load(icon_path)
	instance.configure(data, icon_tex)
	instance.node_clicked.connect(_on_node_clicked)
	_map_nodes[data.id] = instance

# ============================================================================
# BEZIER PATHS
# ============================================================================

func _draw_all_paths():
	for node_data in _run.nodes.values():
		for to_id in node_data.connections_to:
			var key = _path_key(node_data.id, to_id)
			if _path_lines.has(key): continue
			var from_pos = _node_positions.get(node_data.id)
			var to_pos = _node_positions.get(to_id)
			if from_pos == null or to_pos == null: continue
			var points = _compute_bezier(from_pos, to_pos)
			_path_points[key] = points
			var line = Line2D.new()
			line.points = points
			line.width = path_width
			line.default_color = path_color_locked
			line.antialiased = true
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			path_container.add_child(line)
			_path_lines[key] = line

func _compute_bezier(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points = PackedVector2Array()
	var dy = to.y - from.y
	var dx = to.x - from.x
	var cp1 = Vector2(from.x + dx * 0.15, from.y + dy * 0.4)
	var cp2 = Vector2(to.x - dx * 0.15, to.y - dy * 0.4)
	for i in range(bezier_segments + 1):
		var t = float(i) / bezier_segments
		points.append(_cubic_bezier(from, cp1, cp2, to, t))
	return points

func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	return u*u*u * p0 + 3.0*u*u*t * p1 + 3.0*u*t*t * p2 + t*t*t * p3

func _path_key(from_id: int, to_id: int) -> String:
	return "%d-%d" % [from_id, to_id]

func _update_path_states():
	for node_data in _run.nodes.values():
		for to_id in node_data.connections_to:
			var key = _path_key(node_data.id, to_id)
			var line: Line2D = _path_lines.get(key)
			if not line: continue
			var fn: DungeonMapNode = _map_nodes.get(node_data.id)
			var tn: DungeonMapNode = _map_nodes.get(to_id)
			if not fn or not tn: continue
			if fn.state == DungeonMapNode.State.COMPLETED and \
			   tn.state == DungeonMapNode.State.COMPLETED:
				line.default_color = path_color_completed
			elif (fn.state == DungeonMapNode.State.CURRENT or \
				  fn.state == DungeonMapNode.State.COMPLETED) and \
				 tn.state == DungeonMapNode.State.AVAILABLE:
				line.default_color = path_color_available
			elif fn.state == DungeonMapNode.State.COMPLETED and \
				 tn.state == DungeonMapNode.State.CURRENT:
				line.default_color = path_color_completed
			else:
				line.default_color = path_color_locked

# ============================================================================
# FOG
# ============================================================================

func _setup_fog():
	if fog_mode != 1: return
	for f in range(_run.definition.floor_count):
		var fog_rect = ColorRect.new()
		fog_rect.color = fog_color
		var row_y = -(f * row_spacing) - vertical_padding
		fog_rect.position = Vector2(0, row_y - row_spacing * 0.5)
		fog_rect.size = Vector2(map_width, row_spacing)
		fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fog_container.add_child(fog_rect)
		_fog_rects[f] = fog_rect
	_dissolve_fog(0, true)

func _reveal_floor_fog(floor_num: int):
	if fog_mode != 1: return
	_dissolve_fog(floor_num, false)

func _dissolve_fog(floor_num: int, instant: bool = false):
	var fog: ColorRect = _fog_rects.get(floor_num)
	if not fog or not fog.visible: return
	if instant:
		fog.color.a = 0.0
		fog.visible = false
	else:
		var tw = create_tween()
		tw.tween_property(fog, "color:a", 0.0, 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func(): fog.visible = false)

func _update_fog_visibility():
	if fog_mode != 1: return
	var current_floor = 0
	if _current_node_id >= 0:
		var nd = _run.get_node(_current_node_id)
		if nd: current_floor = nd.floor_num
	for f in range(_run.definition.floor_count):
		if f <= current_floor + fog_reveal_ahead:
			_reveal_floor_fog(f)

# ============================================================================
# NODE STATES
# ============================================================================

func _set_initial_states():
	for map_node in _map_nodes.values():
		map_node.set_state(DungeonMapNode.State.LOCKED)
	if _run.floors[0].size() > 0:
		var start_id = _run.floors[0][0]
		_current_node_id = start_id
		var sn = _map_nodes.get(start_id)
		if sn: sn.set_state(DungeonMapNode.State.CURRENT)
	_update_fog_visibility()
	_update_path_states()

func complete_node(node_id: int):
	print("🗺️ complete_node(%d) called" % node_id)
	var map_node: DungeonMapNode = _map_nodes.get(node_id)
	if map_node:
		map_node.set_state(DungeonMapNode.State.COMPLETED)
	_current_node_id = node_id
	var node_data = _run.get_node(node_id)
	if not node_data: return
	var next_floor = node_data.floor_num + 1
	if next_floor >= _run.definition.floor_count:
		_update_path_states()
		return
	_update_fog_visibility()
	for to_id in node_data.connections_to:
		var to_data = _run.get_node(to_id)
		if to_data and to_data.floor_num == next_floor:
			var to_mn = _map_nodes.get(to_id)
			if to_mn and to_mn.state == DungeonMapNode.State.LOCKED:
				to_mn.set_state(DungeonMapNode.State.AVAILABLE)
	_update_path_states()

# ============================================================================
# PLAYER TOKEN
# ============================================================================

func _init_player_token():
	if not player_token: return
	player_token.scale = Vector2.ONE * token_scale
	player_token.z_index = 10
	if _current_node_id >= 0 and _node_positions.has(_current_node_id):
		player_token.global_position = _node_positions[_current_node_id]
		player_token.visible = true
	else:
		player_token.visible = false

func _tween_token_to_node(target_id: int):
	if not player_token: return
	_transitioning = true
	var to_pos = _node_positions.get(target_id)
	if to_pos == null:
		_transitioning = false
		return
	var key = _path_key(_current_node_id, target_id)
	var points: PackedVector2Array = _path_points.get(key, PackedVector2Array())
	if points.size() > 1:
		_tween_along_points(points, target_id)
	else:
		var tw = create_tween()
		tw.tween_property(player_token, "global_position", to_pos, token_tween_duration) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(_on_token_arrived.bind(target_id))

func _tween_along_points(points: PackedVector2Array, target_id: int):
	var tw = create_tween()
	var total_dist = 0.0
	for i in range(1, points.size()):
		total_dist += points[i - 1].distance_to(points[i])
	if total_dist < 1.0:
		player_token.global_position = points[points.size() - 1]
		_on_token_arrived(target_id)
		return
	for i in range(1, points.size()):
		var seg_dist = points[i - 1].distance_to(points[i])
		var seg_time = (seg_dist / total_dist) * token_tween_duration
		tw.tween_property(player_token, "global_position", points[i], seg_time)
	tw.tween_callback(_on_token_arrived.bind(target_id))

func _on_token_arrived(target_id: int):
	_current_node_id = target_id
	_transitioning = false
	node_selected.emit(target_id)

# ============================================================================
# CAMERA
# ============================================================================

func _camera_follow_node(node_id: int, instant: bool = false):
	if not camera: return
	var pos = _node_positions.get(node_id)
	if pos == null: return
	var target = Vector2(camera.global_position.x, pos.y)
	if instant:
		if camera.has_method("corridor_set_position"):
			camera.corridor_set_position(target)
		else:
			camera.global_position = target
	else:
		if camera.has_method("corridor_advance"):
			camera.corridor_tween_duration = camera_tween_duration
			camera.corridor_advance(target)
		else:
			var tw = create_tween()
			tw.tween_property(camera, "global_position", target, camera_tween_duration) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

func _play_intro():
	if not camera or _run == null: return
	_intro_playing = true
	var last_floor = _run.definition.floor_count - 1
	var boss_id = _run.floors[last_floor][0] if _run.floors[last_floor].size() > 0 else -1
	var start_id = _run.floors[0][0] if _run.floors[0].size() > 0 else -1
	var boss_y = _node_positions.get(boss_id, Vector2.ZERO).y if boss_id >= 0 else 0.0
	var start_y = _node_positions.get(start_id, Vector2.ZERO).y if start_id >= 0 else 0.0

	# Offset camera down so boss appears 2/3 up the playable area
	var viewport_h = get_viewport_rect().size.y
	var playable_h = viewport_h - camera.bottom_panel_height if camera else viewport_h
	var boss_offset = playable_h / 3.0

	var boss_cam = Vector2(map_width / 2.0, boss_y + boss_offset)
	var start_cam = Vector2(map_width / 2.0, start_y)
	if camera.has_method("corridor_set_position"):
		camera.corridor_set_position(boss_cam)
	else:
		camera.global_position = boss_cam
	var tw = create_tween()
	tw.tween_interval(intro_pause_at_boss)
	tw.tween_property(camera, "global_position", start_cam, intro_duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_on_intro_finished)

func _on_intro_finished():
	print("🗺️ Intro finished")
	_intro_playing = false
	if _current_node_id >= 0:
		_camera_follow_node(_current_node_id, true)

# ============================================================================
# INTERACTION
# ============================================================================

func _on_node_clicked(node_id: int):
	print("🗺️ Node clicked: %d, transitioning=%s, intro=%s" % [node_id, _transitioning, _intro_playing])
	if _transitioning or _intro_playing: return
	# ... rest of function
	var map_node: DungeonMapNode = _map_nodes.get(node_id)
	if not map_node or map_node.state != DungeonMapNode.State.AVAILABLE: return
	map_node.set_state(DungeonMapNode.State.CURRENT)
	var node_data = _run.get_node(node_id)
	if node_data:
		for sibling_id in _run.floors[node_data.floor_num]:
			if sibling_id != node_id:
				var sibling = _map_nodes.get(sibling_id)
				if sibling and sibling.state == DungeonMapNode.State.AVAILABLE:
					sibling.set_state(DungeonMapNode.State.LOCKED)
	_update_path_states()
	_camera_follow_node(node_id)
	_tween_token_to_node(node_id)

# ============================================================================
# THEME
# ============================================================================

func _apply_theme(definition: DungeonDefinition):
	if definition.fog_color != Color.BLACK:
		fog_color = definition.fog_color
		for fr in _fog_rects.values():
			if is_instance_valid(fr): fr.color = fog_color
	if "map_path_color" in definition and definition.map_path_color != Color():
		path_color = definition.map_path_color
	if "map_fog_mode" in definition:
		fog_mode = definition.map_fog_mode
	if "map_background" in definition and definition.map_background != null:
		if has_node("Background"):
			var bg = $Background as Sprite2D
			if bg: bg.texture = definition.map_background

# ============================================================================
# HELPERS
# ============================================================================

func _fit_camera_zoom():
	"""Set camera zoom so the map width fills the viewport with a margin."""
	if not camera: return
	var viewport_w = get_viewport_rect().size.x
	# Fit map_width into viewport, with 10% margin on each side
	var ideal_zoom = viewport_w / (map_width * 1.2)
	ideal_zoom = clampf(ideal_zoom, camera.zoom_min, camera.zoom_max)
	camera.zoom = Vector2(ideal_zoom, ideal_zoom)


func get_current_node_id() -> int:
	return _current_node_id

func get_node_position(node_id: int) -> Vector2:
	return _node_positions.get(node_id, Vector2.ZERO)
