# res://scripts/dungeon/dungeon_wall_layer.gd
## A single floor's wall in the dungeon corridor.
## Editor-placed scene. Doors are DungeonDoor packed scene instances
## spawned into DoorContainer during configure().
extends Node2D
class_name DungeonWallLayer

signal door_clicked(node_id: int)

# ============================================================================
# CONFIGURATION
# ============================================================================
@export var door_scene: PackedScene = null        ## res://scenes/dungeon/dungeon_door.tscn
@export var max_visible_distance: float = 3600.0
@export var behind_fade_threshold: float = 600.0
@export var min_depth_scale: float = 0.35
@export var door_spacing: float = 300.0  #

# ============================================================================
# NODE REFERENCES — editor-placed
# ============================================================================
@onready var wall_sprite: Sprite2D = $WallSprite
@onready var door_container: Node2D = $DoorContainer
@onready var torch_left: AnimatedSprite2D = $TorchLeft
@onready var torch_right: AnimatedSprite2D = $TorchRight

# ============================================================================
# STATE
# ============================================================================
var floor_num: int = -1
var fog_color: Color = Color(0.1, 0.08, 0.15)
var _doors: Array[DungeonDoor] = []

# ============================================================================
# SETUP
# ============================================================================

func configure(p_floor_num: int, nodes: Array, theme: DungeonDefinition = null):
	floor_num = p_floor_num

	# Apply theme
	if theme:
		if theme.wall_texture and wall_sprite:
			wall_sprite.texture = theme.wall_texture
		if theme.fog_color != Color.BLACK:
			fog_color = theme.fog_color

	# Clear existing doors
	for door in _doors:
		if is_instance_valid(door): door.queue_free()
	_doors.clear()

	if not door_scene:
		push_error("DungeonWallLayer: No door_scene assigned!")
		return

	# Spawn a DungeonDoor for each node, centered horizontally
	var total_width = (nodes.size() - 1) * door_spacing
	var start_x = -total_width / 2.0

	for i in nodes.size():
		var node: DungeonNodeData = nodes[i]
		var door: DungeonDoor = door_scene.instantiate()
		door_container.add_child(door)
		door.position = Vector2(start_x + i * door_spacing, 0)
		door.configure(node)
		door.door_clicked.connect(_on_door_clicked)
		_doors.append(door)

func set_interactive(interactive: bool):
	for door in _doors:
		door.set_interactive(interactive)

# ============================================================================
# DEPTH APPEARANCE — called by CorridorBuilder each frame
# ============================================================================

func update_depth(camera_y: float, vp_y: float, floor_line_y: float):
	# Perspective t: 0.0 at floor line (full width), 1.0 at VP (zero width)
	var denom := vp_y - floor_line_y
	var t: float
	if absf(denom) < 0.001:
		t = 0.0
	else:
		t = (global_position.y - floor_line_y) / denom

	# Scale follows the perspective lines exactly
	var s := clampf(1.0 - t, min_depth_scale, 1.0)
	scale = Vector2(s, s)

	# Fog: ramp with t (deeper = foggier)
	var fog_t := clampf(t, 0.0, 1.0)
	modulate = Color.WHITE.lerp(fog_color, fog_t * 0.6)

	# Alpha fade for very distant walls
	if t > 0.85:
		modulate.a = lerpf(1.0, 0.0, (t - 0.85) / 0.15)
	else:
		modulate.a = 1.0

	# Behind camera — invisible
	if global_position.y > camera_y + behind_fade_threshold:
		modulate.a = 0.0

	z_index = -floor_num


# ============================================================================
# SIGNAL RELAY
# ============================================================================

func _on_door_clicked(node_id: int):
	door_clicked.emit(node_id)
