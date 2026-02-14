# res://scripts/dungeon/corridor_debug_overlay.gd
## Debug visualization for the 2.5D corridor vanishing point.
## Add as a child of CorridorBuilder. Toggle via @export enabled.
##
## Draws:
##   - Yellow crosshair at the computed vanishing point
##   - Red/blue perspective lines from corridor edges → VP
##   - Green horizontal lines where each floor SHOULD be (true perspective)
##   - White dashed lines where each floor ACTUALLY is (current scale)
##   - VP info label in the corner
##
## All drawing is in world space via _draw(). The camera transform
## handles screen projection automatically.
extends Node2D
class_name CorridorDebugOverlay

# ============================================================================
# CONFIGURATION — tweak in Inspector
# ============================================================================
@export var enabled: bool = true

@export_group("Vanishing Point")
## Where the VP sits in the playable area.
## 0.0 = top edge, 0.5 = center, 1.0 = bottom edge.
@export_range(0.0, 1.0, 0.01) var vp_ratio: float = 0.1

@export_group("Corridor Shape")
## Half-width of the corridor at the player's feet (floor 0 / nearest wall).
## Matches torch positions in dungeon_wall_layer.tscn (±480).
@export var corridor_half_width: float = 480.0

## How far below the VP the "floor line" (player's feet) sits.
## 0.0 = VP, 1.0 = bottom of playable area.  Default puts it at ~70%.
@export_range(0.0, 1.0, 0.01) var floor_line_ratio: float = 0.70

@export_group("Colors")
@export var color_vp: Color = Color(1.0, 1.0, 0.0, 0.9)
@export var color_left_wall: Color = Color(1.0, 0.2, 0.2, 0.6)
@export var color_right_wall: Color = Color(0.2, 0.4, 1.0, 0.6)
@export var color_ideal_floor: Color = Color(0.2, 1.0, 0.3, 0.5)
@export var color_actual_floor: Color = Color(1.0, 1.0, 1.0, 0.35)
@export var color_center_line: Color = Color(1.0, 1.0, 1.0, 0.15)

@export_group("Drawing")
@export var line_width: float = 2.0
@export var marker_radius: float = 5.0
@export var dash_length: float = 12.0
@export var gap_length: float = 8.0

# ============================================================================
# REFERENCES — set by CorridorBuilder
# ============================================================================
var camera: GameCamera = null
var walls: Dictionary = {}          # floor_num -> DungeonWallLayer
var floor_spacing: float = 600.0

# ============================================================================
# PROCESS
# ============================================================================

func _process(_delta: float):
	if enabled:
		queue_redraw()

func _draw():
	if not enabled or not camera:
		return

	var cam_pos: Vector2 = camera.global_position
	var playable_h: float = camera.get_playable_height()
	var cam_offset_y: float = camera.offset.y

	# --- Compute key world-space positions ---

	# Top and bottom of the playable viewport in world space
	var playable_top_y: float = cam_pos.y + cam_offset_y - playable_h / 2.0
	var playable_bot_y: float = cam_pos.y + cam_offset_y + playable_h / 2.0
	var center_x: float = cam_pos.x

	# Vanishing point
	var vp := Vector2(center_x, playable_top_y + playable_h * vp_ratio)

	# Floor line — where the corridor is at full width (player's feet level)
	var floor_y: float = lerpf(vp.y, playable_bot_y, floor_line_ratio)

	# Bottom-left and bottom-right corners of the corridor at floor level
	var bl := Vector2(center_x - corridor_half_width, floor_y)
	var br := Vector2(center_x + corridor_half_width, floor_y)

	# --- 1. Center line (subtle vertical guide) ---
	_draw_dashed_line(
		Vector2(center_x, playable_top_y - 200),
		Vector2(center_x, playable_bot_y + 200),
		color_center_line, line_width * 0.5
	)

	# --- 2. Perspective wall lines: corridor edges → VP (and beyond) ---
	var extend: float = 3000.0
	var dir_left: Vector2 = (vp - bl).normalized()
	var dir_right: Vector2 = (vp - br).normalized()
	# Draw from well below floor line up through VP and beyond
	var line_start_left := bl + dir_left * -400.0
	var line_end_left := vp + dir_left * extend
	var line_start_right := br + dir_right * -400.0
	var line_end_right := vp + dir_right * extend

	draw_line(line_start_left, line_end_left, color_left_wall, line_width)
	draw_line(line_start_right, line_end_right, color_right_wall, line_width)

	# --- 3. VP crosshair ---
	var cross := 25.0
	draw_line(vp + Vector2(-cross, 0), vp + Vector2(cross, 0), color_vp, line_width * 1.5)
	draw_line(vp + Vector2(0, -cross), vp + Vector2(0, cross), color_vp, line_width * 1.5)
	draw_circle(vp, 8.0, Color(color_vp, 0.4))
	draw_circle(vp, 4.0, color_vp)

	# --- 4. Floor markers — ideal (perspective) vs actual (current scale) ---
	for floor_num in walls:
		var wall: DungeonWallLayer = walls[floor_num]
		if not is_instance_valid(wall):
			continue

		var wall_y: float = wall.global_position.y

		# -- Ideal perspective width at this floor's Y --
		# Parametric t: 0 at floor_y (full width), 1 at VP (zero width)
		var t: float = _get_t_for_y(bl.y, vp.y, wall_y)
		if t < -0.5 or t > 2.0:
			continue

		var ideal_left_x: float = lerpf(bl.x, vp.x, t)
		var ideal_right_x: float = lerpf(br.x, vp.x, t)

		# Green: ideal perspective line
		draw_line(
			Vector2(ideal_left_x, wall_y),
			Vector2(ideal_right_x, wall_y),
			color_ideal_floor, line_width * 0.75
		)
		draw_circle(Vector2(ideal_left_x, wall_y), marker_radius, color_left_wall)
		draw_circle(Vector2(ideal_right_x, wall_y), marker_radius, color_right_wall)

		# -- Actual width: current wall scale × corridor_half_width --
		var actual_half_w: float = corridor_half_width * wall.scale.x
		var actual_left_x: float = center_x - actual_half_w
		var actual_right_x: float = center_x + actual_half_w

		# White dashed: actual scaled width
		_draw_dashed_line(
			Vector2(actual_left_x, wall_y),
			Vector2(actual_right_x, wall_y),
			color_actual_floor, line_width * 0.5
		)

		# Small floor number label (drawn as circles with count for simplicity)
		# We'll use small dots to indicate floor number
		_draw_floor_tag(Vector2(ideal_right_x + 15.0, wall_y), floor_num)

	# --- 5. Floor line indicator (where player stands) ---
	draw_line(bl, br, Color(1.0, 0.6, 0.0, 0.5), line_width * 1.5)

	# --- 6. Info readout at top-left of visible area ---
	_draw_info_panel(vp, playable_top_y, center_x)


# ============================================================================
# HELPERS
# ============================================================================

func _get_t_for_y(start_y: float, end_y: float, target_y: float) -> float:
	"""Parametric t along a line from start_y to end_y at target_y."""
	var denom: float = end_y - start_y
	if absf(denom) < 0.001:
		return 0.0
	return (target_y - start_y) / denom


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float):
	"""Draw a dashed line between two world-space points."""
	var dir: Vector2 = (to - from)
	var total_len: float = dir.length()
	if total_len < 1.0:
		return
	dir = dir / total_len  # normalize

	var drawn: float = 0.0
	var on: bool = true
	while drawn < total_len:
		var seg: float = dash_length if on else gap_length
		seg = minf(seg, total_len - drawn)
		if on:
			draw_line(
				from + dir * drawn,
				from + dir * (drawn + seg),
				color, width
			)
		drawn += seg
		on = not on


func _draw_floor_tag(pos: Vector2, floor_num: int):
	"""Draw a small colored dot + number indicator for a floor."""
	var tag_color := color_ideal_floor
	# Tint boss floor differently
	draw_circle(pos, 3.0, tag_color)
	# We can't easily draw text in _draw() without a font reference,
	# but the floor's position on the perspective line is the real info.


func _draw_info_panel(vp: Vector2, playable_top_y: float, center_x: float):
	"""Draw small colored reference squares as a legend in the corner."""
	# Position in world space near top-left of visible area
	var base := Vector2(center_x - 500.0, playable_top_y + 20.0)
	var box_size := 10.0
	var spacing := 16.0

	# VP marker
	draw_rect(Rect2(base, Vector2(box_size, box_size)), color_vp)

	# Left wall
	draw_rect(Rect2(base + Vector2(0, spacing), Vector2(box_size, box_size)), color_left_wall)

	# Right wall
	draw_rect(Rect2(base + Vector2(0, spacing * 2), Vector2(box_size, box_size)), color_right_wall)

	# Ideal floor
	draw_rect(Rect2(base + Vector2(0, spacing * 3), Vector2(box_size, box_size)), color_ideal_floor)

	# Actual floor
	draw_rect(Rect2(base + Vector2(0, spacing * 4), Vector2(box_size, box_size)), color_actual_floor)


# ============================================================================
# PUBLIC — for CorridorBuilder to call
# ============================================================================

func sync_from_builder(p_camera: GameCamera, p_walls: Dictionary, p_floor_spacing: float):
	"""Call after build_corridor to feed references."""
	camera = p_camera
	walls = p_walls
	floor_spacing = p_floor_spacing
