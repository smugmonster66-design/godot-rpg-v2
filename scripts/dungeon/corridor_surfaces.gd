# res://scripts/dungeon/corridor_surfaces.gd
## Draws the four corridor surfaces (left wall, right wall, floor, ceiling)
## as perspective-correct Polygon2D trapezoids that converge toward the VP.
##
## Add as a child of CorridorBuilder (sibling of the wall layers).
## Updated each frame by CorridorBuilder passing camera + VP data.
## Textures are set per-dungeon via apply_theme().
##
## Each surface is a Polygon2D with 4 vertices forming a trapezoid:
##
##         narrow edge (near VP)
##        ┌──────────────────┐
##       /                    \
##      /                      \
##     /                        \
##    └──────────────────────────┘
##         wide edge (near player)
##
extends Node2D
class_name CorridorSurfaces

# ============================================================================
# CONFIGURATION
# ============================================================================
@export_group("Textures")
@export var floor_texture: Texture2D = null
@export var left_wall_texture: Texture2D = null
@export var right_wall_texture: Texture2D = null
@export var ceiling_texture: Texture2D = null

@export_group("Dimensions")
## Half-width of the corridor at the player's feet (matches torch positions)
@export var corridor_half_width: float = 480.0

## How tall each side wall appears at the player's feet (full size)
@export var wall_height: float = 300.0

## How far below the visible area the floor/wall bottoms extend
## (prevents gaps when camera moves)
@export var bottom_margin: float = 200.0

## How far above the VP the ceiling/wall tops extend
@export var top_margin: float = 100.0

@export_group("UV")
## How many times the texture tiles along the depth axis
@export var floor_tile_v: float = 4.0
@export var wall_tile_v: float = 3.0
@export var ceiling_tile_v: float = 3.0

# ============================================================================
# POLYGON NODES — created in _ready
# ============================================================================
var _floor_poly: Polygon2D = null
var _left_wall_poly: Polygon2D = null
var _right_wall_poly: Polygon2D = null
var _ceiling_poly: Polygon2D = null

# ============================================================================
# STATE — set each frame by CorridorBuilder
# ============================================================================
var _vp := Vector2.ZERO
var _floor_line_y: float = 0.0
var _cam_offset_y: float = 0.0
var _playable_h: float = 1470.0
var _cam_pos := Vector2.ZERO
var _active: bool = false

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	# Create the four surface polygons
	_floor_poly = _create_surface("FloorSurface", -1)
	_left_wall_poly = _create_surface("LeftWallSurface", 0)
	_right_wall_poly = _create_surface("RightWallSurface", 0)
	_ceiling_poly = _create_surface("CeilingSurface", -2)

	# Z-order: ceiling behind walls behind floor behind wall layers
	# Wall layers have z_index = -floor_num (negative), so these go further back
	_ceiling_poly.z_index = -100
	_left_wall_poly.z_index = -99
	_right_wall_poly.z_index = -99
	_floor_poly.z_index = -98


func _create_surface(surface_name: String, z: int) -> Polygon2D:
	var poly = Polygon2D.new()
	poly.name = surface_name
	poly.z_index = z
	poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	poly.uv = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(poly)
	return poly

# ============================================================================
# THEME — called by DungeonScene._apply_theme()
# ============================================================================

func apply_theme(definition) -> void:
	"""Apply textures from a DungeonDefinition. Accepts duck-typed resource."""
	if "floor_texture" in definition and definition.floor_texture:
		floor_texture = definition.floor_texture
	if "side_wall_texture" in definition and definition.side_wall_texture:
		left_wall_texture = definition.side_wall_texture
		right_wall_texture = definition.side_wall_texture
	if "ceiling_texture" in definition and definition.ceiling_texture:
		ceiling_texture = definition.ceiling_texture

	_apply_textures()


func _apply_textures():
	if _floor_poly and floor_texture:
		_floor_poly.texture = floor_texture
	if _left_wall_poly and left_wall_texture:
		_left_wall_poly.texture = left_wall_texture
	if _right_wall_poly and right_wall_texture:
		_right_wall_poly.texture = right_wall_texture
	if _ceiling_poly and ceiling_texture:
		_ceiling_poly.texture = ceiling_texture

# ============================================================================
# FRAME UPDATE — called by CorridorBuilder._process()
# ============================================================================

func update_surfaces(cam_pos: Vector2, cam_offset_y: float, playable_h: float,
					 vp: Vector2, floor_line_y: float):
	_cam_pos = cam_pos
	_cam_offset_y = cam_offset_y
	_playable_h = playable_h
	_vp = vp
	_floor_line_y = floor_line_y
	_active = true
	_rebuild_geometry()


func _rebuild_geometry():
	if not _active:
		return

	var center_x := _cam_pos.x
	var playable_top_y := _cam_pos.y + _cam_offset_y - _playable_h / 2.0
	var playable_bot_y := _cam_pos.y + _cam_offset_y + _playable_h / 2.0

	# Key Y positions
	var vp_y := _vp.y
	var near_y := _floor_line_y + bottom_margin  # bottom of visible corridor
	var far_y := vp_y - top_margin               # top / beyond VP

	# Width at near (full) and far (converged toward VP)
	# t=0 at floor_line, t=1 at VP
	var near_half_w := corridor_half_width
	# How narrow at the far end — proportional to how close to VP
	var far_t := clampf((_floor_line_y - far_y) / (_floor_line_y - vp_y), 0.0, 0.98)
	var far_half_w := corridor_half_width * (1.0 - far_t)

	# Wall height at near and far
	var near_wall_h := wall_height
	var far_wall_h := wall_height * (1.0 - far_t)

	# ── FLOOR ──────────────────────────────────────────────────────────
	# Trapezoid on the ground plane
	#   near-left, near-right, far-right, far-left
	_set_quad(_floor_poly,
		Vector2(center_x - near_half_w, near_y),       # bottom-left
		Vector2(center_x + near_half_w, near_y),       # bottom-right
		Vector2(center_x + far_half_w, far_y),         # top-right
		Vector2(center_x - far_half_w, far_y),         # top-left
		floor_tile_v
	)

	# ── CEILING ────────────────────────────────────────────────────────
	# Mirror of floor, shifted up by wall_height
	var ceil_near_y := _floor_line_y - near_wall_h
	var ceil_far_y := far_y - far_wall_h

	_set_quad(_ceiling_poly,
		Vector2(center_x - near_half_w, ceil_near_y),
		Vector2(center_x + near_half_w, ceil_near_y),
		Vector2(center_x + far_half_w, ceil_far_y),
		Vector2(center_x - far_half_w, ceil_far_y),
		ceiling_tile_v
	)

	# ── LEFT WALL ──────────────────────────────────────────────────────
	# Vertical surface along the left corridor edge
	#   bottom-left (floor), top-left (ceiling), top-far, bottom-far
	_set_quad(_left_wall_poly,
		Vector2(center_x - near_half_w, near_y),           # bottom-near
		Vector2(center_x - near_half_w, ceil_near_y),      # top-near
		Vector2(center_x - far_half_w, ceil_far_y),        # top-far
		Vector2(center_x - far_half_w, far_y),             # bottom-far
		wall_tile_v
	)

	# ── RIGHT WALL ─────────────────────────────────────────────────────
	_set_quad(_right_wall_poly,
		Vector2(center_x + near_half_w, near_y),
		Vector2(center_x + near_half_w, ceil_near_y),
		Vector2(center_x + far_half_w, ceil_far_y),
		Vector2(center_x + far_half_w, far_y),
		wall_tile_v
	)

func _set_quad(poly: Polygon2D, bl: Vector2, tl: Vector2, tr: Vector2, br: Vector2,
			   tile_v: float):
	if not poly or not poly.texture:
		return

	var tex_size := Vector2(poly.texture.get_size())
	var strips := 20  # more strips = smoother perspective

	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in range(strips + 1):
		var t := float(i) / float(strips)
		# Interpolate left and right edges at this strip height
		var left := bl.lerp(tl, t)
		var right := br.lerp(tr, t)
		# UV: full texture width, tiled along depth
		var v := tex_size.y * tile_v * (1.0 - t)
		verts.append(left)
		verts.append(right)
		uvs.append(Vector2(0.0, v))
		uvs.append(Vector2(tex_size.x, v))

	# Build triangle indices for each strip
	for i in range(strips):
		var row := i * 2
		# Two triangles per strip
		indices.append(row)
		indices.append(row + 2)
		indices.append(row + 1)
		indices.append(row + 1)
		indices.append(row + 2)
		indices.append(row + 3)

	poly.polygon = verts
	poly.uv = uvs
	poly.polygons = [indices]

# ============================================================================
# CLEANUP
# ============================================================================

func clear():
	_active = false
	for poly in [_floor_poly, _left_wall_poly, _right_wall_poly, _ceiling_poly]:
		if poly:
			poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
