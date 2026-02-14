## Builds the 2.5D corridor from a DungeonRun.
## Spawns DungeonWallLayer instances as children, manages camera transitions.
## Editor-placed as a child of DungeonScene.
extends Node2D
class_name DungeonCorridorBuilder

signal door_selected(node_id: int)

# ============================================================================
# CONFIGURATION — set in Inspector
# ============================================================================
@export var wall_scene: PackedScene = null      ## res://scenes/dungeon/dungeon_wall_layer.tscn
@export var floor_spacing: float = 400.0
@export var camera_tween_duration: float = 0.8
@export var intro_duration: float = 2.0

# Add to CONFIGURATION section, alongside existing exports:
@export_group("Perspective")
@export_range(0.0, 1.0, 0.01) var vp_ratio: float = 0.1
@export_range(0.0, 1.0, 0.01) var floor_line_ratio: float = 0.70
@export var corridor_half_width: float = 480.0

# ============================================================================
# REFERENCES — set by DungeonScene in _connect_signals
# ============================================================================
var camera: GameCamera = null
var player_sprite: Node2D = null
var debug_overlay: CorridorDebugOverlay = null
var corridor_surfaces: CorridorSurfaces = null

# ============================================================================
# STATE
# ============================================================================
var _walls: Dictionary = {}    # floor_num -> DungeonWallLayer
var _run: DungeonRun = null
var _current_floor: int = 0
var _transitioning: bool = false

# ============================================================================
# BUILD / CLEAR
# ============================================================================

func build_corridor(run: DungeonRun):
	clear_corridor()
	_run = run

	if not wall_scene:
		push_error("CorridorBuilder: No wall_scene!")
		return

	for f in range(run.definition.floor_count):
		var wall: DungeonWallLayer = wall_scene.instantiate()
		add_child(wall)

		# Position: negative Y = deeper into dungeon (Godot Y increases down)
		wall.global_position = Vector2(0, -f * floor_spacing)

		# Configure from floor data
		wall.configure(f, run.get_floor_nodes(f), run.definition)
		wall.door_clicked.connect(_on_door_clicked)
		_walls[f] = wall


	if not corridor_surfaces:
		corridor_surfaces = find_child("CorridorSurfaces", true, false) as CorridorSurfaces
	if corridor_surfaces:
		corridor_surfaces.corridor_half_width = corridor_half_width



	if camera:
		camera.global_position = Vector2.ZERO

	# Floor 0 is START (auto-completes), so floor 1 doors should be interactive
	_set_interactive_floor(1)
	_play_intro()
	
	
	
	# Sync debug overlay
	if not debug_overlay:
		debug_overlay = find_child("DebugOverlay", true, false) as CorridorDebugOverlay
	if debug_overlay:
		debug_overlay.vp_ratio = vp_ratio
		debug_overlay.floor_line_ratio = floor_line_ratio
		debug_overlay.corridor_half_width = corridor_half_width
		debug_overlay.sync_from_builder(camera, _walls, floor_spacing)

	print("🏰 Corridor built: %d walls" % _walls.size())

func clear_corridor():
	if debug_overlay:
		debug_overlay.walls = {}
	if corridor_surfaces:
		corridor_surfaces.clear()
	for wall in _walls.values():
		if is_instance_valid(wall): wall.queue_free()
	_walls.clear()
	_run = null

# ============================================================================
# CAMERA
# ============================================================================


# In dungeon_corridor_builder.gd

func advance_to_floor(f: int):
	if not camera or camera._corridor_transitioning: return
	_current_floor = f
	var target = Vector2(0, -f * floor_spacing)
	camera.corridor_advance(target)
	# Wait for camera to arrive, then unlock next floor's doors
	if not camera.corridor_arrived.is_connected(_on_transition_done):
		camera.corridor_arrived.connect(_on_transition_done.bind(f), CONNECT_ONE_SHOT)

func _on_transition_done(f: int):
	if _run and f + 1 < _run.definition.floor_count:
		_set_interactive_floor(f + 1)

func _play_intro():
	if not camera or _walls.size() == 0: return
	var boss_y = -(_run.definition.floor_count - 1) * floor_spacing
	camera.corridor_intro(Vector2(0, boss_y), Vector2.ZERO)


# In DungeonWallLayer or CorridorBuilder

# The vanishing point in world space (relative to camera each frame)
# This is the point all distant walls converge toward
func _get_vanishing_point(camera: GameCamera) -> Vector2:
	var playable_h = camera.get_playable_height()
	# VP sits near the top of the playable area
	# vp_ratio: 0.0 = top edge, 0.5 = center, 1.0 = bottom
	var vp_ratio: float = 0.1  # 10% from top — tweak to taste
	return Vector2(
		camera.global_position.x,
		camera.global_position.y + camera.offset.y - playable_h / 2.0 + playable_h * vp_ratio
	)



# ============================================================================
# DEPTH + PLAYER TRACKING
# ============================================================================

func _process(_delta: float):
	if not camera: return

	var cam_pos := camera.global_position
	var cam_y := cam_pos.y
	var playable_h := camera.get_playable_height()
	var cam_offset_y := camera.offset.y

	var playable_top_y := cam_y + cam_offset_y - playable_h / 2.0
	var playable_bot_y := cam_y + cam_offset_y + playable_h / 2.0
	var vp_y := playable_top_y + playable_h * vp_ratio
	var floor_line_y := lerpf(vp_y, playable_bot_y, floor_line_ratio)
	var vp := Vector2(cam_pos.x, vp_y)

	# Update wall depth
	for wall in _walls.values():
		if is_instance_valid(wall):
			wall.update_depth(cam_y, vp_y, floor_line_y)

	# Update corridor surfaces
	if corridor_surfaces:
		corridor_surfaces.update_surfaces(cam_pos, cam_offset_y, playable_h, vp, floor_line_y)

	# Player sprite
	if player_sprite and camera:
		player_sprite.global_position = Vector2(
			cam_pos.x,
			cam_pos.y + cam_offset_y + playable_h * 0.30
		)


# ============================================================================
# INTERACTION
# ============================================================================

func _set_interactive_floor(f: int):
	for floor_num in _walls:
		_walls[floor_num].set_interactive(floor_num == f)

func _on_door_clicked(node_id: int):
	if _transitioning: return
	var node = _run.get_node(node_id) if _run else null
	if not node: return
	advance_to_floor(node.floor_num)
	door_selected.emit(node_id)
