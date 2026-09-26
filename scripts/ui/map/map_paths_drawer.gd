# res://scripts/ui/map/map_paths_drawer.gd
# Draws connection lines/curves between map nodes.
# Supports straight lines (no waypoints) and smooth Catmull-Rom curves (with waypoints).
# Set path_segments and call queue_redraw() to update.
extends Control

const PATH_COLOR          := Color(0.6, 0.5, 0.3, 0.9)
const PATH_COLOR_ONEWAY   := Color(0.8, 0.5, 0.2, 0.7)
const PATH_COLOR_PREVIEW  := Color(0.4, 0.9, 0.4, 0.7)   # green: connect-mode preview
const PATH_WIDTH          := 4.0
const CATMULL_SEGMENTS    := 20   # curve segments per inter-waypoint span

## Each entry: {a: Vector2, b: Vector2, one_way: bool, waypoints: Array, key: String}
## 'waypoints' may be empty (straight line) or contain intermediate Vector2 control points.
var path_segments: Array = []

## When non-empty, draws a dashed green line from a to b (connect-mode preview).
var preview_segment: Dictionary = {}

func _draw() -> void:
	for seg in path_segments:
		var color = PATH_COLOR_ONEWAY if seg.get("one_way", false) else PATH_COLOR
		_draw_path(seg["a"], seg["b"], seg.get("waypoints", []), color)

	if not preview_segment.is_empty():
		draw_dashed_line(preview_segment["a"], preview_segment["b"], PATH_COLOR_PREVIEW, PATH_WIDTH, 8.0)

# ============================================================================
# INTERNAL DRAWING
# ============================================================================

func _draw_path(a: Vector2, b: Vector2, waypoints: Array, color: Color) -> void:
	if waypoints.is_empty():
		draw_line(a, b, color, PATH_WIDTH, true)
		return
	var pts := _bake_catmull_rom([a] + waypoints + [b], CATMULL_SEGMENTS)
	draw_polyline(pts, color, PATH_WIDTH, true)

# ============================================================================
# CATMULL-ROM MATH
# ============================================================================

## Bakes a smooth Catmull-Rom spline through the given control points.
## Phantom (ghost) points are added at both ends so the curve passes through
## every supplied point, including the first and last.
static func _bake_catmull_rom(points: Array, segments_per_span: int) -> PackedVector2Array:
	if points.size() < 2:
		var v := PackedVector2Array()
		for p in points:
			v.append(p)
		return v

	# Ghost points mirror the slope at each end
	var p_ghost_start: Vector2 = points[0] * 2.0 - points[1]
	var p_ghost_end:   Vector2 = points[-1] * 2.0 - points[-2]
	var pts: Array = [p_ghost_start] + points + [p_ghost_end]

	var result := PackedVector2Array()
	for i in range(1, pts.size() - 2):
		var p0: Vector2 = pts[i - 1]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[i + 2]
		# Include the endpoint of the last span to close the polyline
		var extra := 1 if i == pts.size() - 3 else 0
		for s in range(segments_per_span + extra):
			var t := float(s) / float(segments_per_span)
			result.append(_crp(p0, p1, p2, p3, t))
	return result

static func _crp(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

# ============================================================================
# HIT TESTING  (used by MapScene in edit mode)
# ============================================================================

## Finds the nearest path to local_pos within max_dist.
## Returns: {found: bool, key: String, insert_index: int, point: Vector2}
## insert_index is the index at which to insert a new waypoint into the
## connection's waypoints array (0 = before first existing waypoint, etc.)
func find_path_at(local_pos: Vector2, max_dist: float = 15.0) -> Dictionary:
	var best := {"found": false, "key": "", "insert_index": 0, "point": Vector2.ZERO}
	var best_dist := max_dist

	for seg in path_segments:
		var a: Vector2         = seg["a"]
		var b: Vector2         = seg["b"]
		var wps: Array         = seg.get("waypoints", [])
		var key: String        = seg.get("key", "")
		var all_pts: Array     = [a] + wps + [b]

		for i in range(all_pts.size() - 1):
			var sa: Vector2 = all_pts[i]
			var sb: Vector2 = all_pts[i + 1]
			var closest := _closest_point_on_segment(local_pos, sa, sb)
			var d := local_pos.distance_to(closest)
			if d < best_dist:
				best_dist = d
				best = {"found": true, "key": key, "insert_index": i, "point": closest}

	return best

static func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t
