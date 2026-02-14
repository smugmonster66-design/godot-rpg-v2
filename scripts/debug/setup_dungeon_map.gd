@tool
extends EditorScript
## ==========================================================================
## setup_dungeon_map.gd — ONE-CLICK DUNGEON MAP INSTALLER
## ==========================================================================
## Run via: Script Editor → File → Run  (or Ctrl+Shift+X)
##
## This script:
##   1. Creates dungeon_map_node.gd + dungeon_map.gd
##   2. Creates dungeon_map_node.tscn + dungeon_map.tscn (text format)
##   3. Patches dungeon_definition.gd — adds Map Visuals exports
##   4. Patches dungeon_scene.gd — swaps CorridorBuilder → DungeonMap
##   5. Patches game_root.gd — updates CorridorBuilder reference
##   6. Prints manual steps for dungeon_scene.tscn
##
## SAFE: Won't overwrite files that already exist (prints skip message).
## REVERSIBLE: Old corridor code is NOT deleted — just unreferenced.
## ==========================================================================

const DRY_RUN := false  ## Set true to preview without writing

func _run():
	print("")
	print("╔══════════════════════════════════════════╗")
	print("║   DUNGEON MAP INSTALLER                  ║")
	print("╚══════════════════════════════════════════╝")
	if DRY_RUN:
		print("⚠️  DRY RUN — no files will be written")
	print("")

	# Step 1: Create new scripts
	_create_file("res://scripts/dungeon/dungeon_map_node.gd", _SRC_MAP_NODE)
	_create_file("res://scripts/dungeon/dungeon_map.gd", _SRC_MAP)

	# Step 2: Create new scenes (.tscn as text)
	_create_file("res://scenes/dungeon/dungeon_map_node.tscn", _TSCN_MAP_NODE)
	_create_file("res://scenes/dungeon/dungeon_map.tscn", _TSCN_MAP)

	# Step 3: Patch DungeonDefinition — add Map Visuals exports
	_patch_definition()

	# Step 4: Patch DungeonScene — swap corridor → map
	_patch_dungeon_scene()

	# Step 5: Patch GameRoot — update CorridorBuilder reference
	_patch_game_root()

	# Step 6: Manual instructions
	print("")
	print("═══════════════════════════════════════════")
	print("📋 MANUAL STEPS REQUIRED IN EDITOR:")
	print("═══════════════════════════════════════════")
	print("")
	print("1. Open res://scenes/dungeon/dungeon_scene.tscn")
	print("")
	print("2. DELETE these nodes (right-click → Delete):")
	print("   • CorridorBuilder (and its child PlayerSprite)")
	print("   • CorridorFrame")
	print("   • AmbientLayer")
	print("")
	print("3. ADD new child to DungeonScene root:")
	print("   • Instance res://scenes/dungeon/dungeon_map.tscn")
	print("   • Rename to 'DungeonMap' (should auto-name)")
	print("   • Drag it ABOVE ProgressUI in the tree")
	print("")
	print("4. On the DungeonMap node, set in Inspector:")
	print("   • Node Scene → res://scenes/dungeon/dungeon_map_node.tscn")
	print("   (Should already be set from the .tscn)")
	print("")
	print("5. On PlayerToken (child of DungeonMap):")
	print("   • Assign a sprite texture for your player token")
	print("   (Reuse the d4-fill-basic.png or a custom icon)")
	print("")
	print("6. Provide node type icons at these paths")
	print("   (already referenced by DungeonEnums.get_node_icon_path):")
	print("   • res://assets/dungeon/icons/start.png")
	print("   • res://assets/dungeon/icons/combat.png")
	print("   • res://assets/dungeon/icons/elite.png")
	print("   • res://assets/dungeon/icons/boss.png")
	print("   • res://assets/dungeon/icons/shop.png")
	print("   • res://assets/dungeon/icons/rest.png")
	print("   • res://assets/dungeon/icons/event.png")
	print("   • res://assets/dungeon/icons/treasure.png")
	print("   • res://assets/dungeon/icons/shrine.png")
	print("   (Nodes will work without icons — just show colored circles)")
	print("")
	print("7. Save the scene. Reload project (Project → Reload).")
	print("")
	print("═══════════════════════════════════════════")
	print("✅ INSTALLER COMPLETE")
	print("═══════════════════════════════════════════")
	print("")
	print("Old corridor files are NOT deleted:")
	print("  • scripts/dungeon/dungeon_corridor_builder.gd")
	print("  • scripts/dungeon/dungeon_wall_layer.gd")
	print("  • scenes/dungeon/dungeon_wall_layer.tscn")
	print("  • scenes/dungeon/dungeon_door.tscn")
	print("You can remove these manually when ready.")


# ============================================================================
# FILE OPERATIONS
# ============================================================================

func _create_file(path: String, content: String):
	if FileAccess.file_exists(path):
		print("  ⏭️  SKIP (exists): %s" % path)
		return
	if DRY_RUN:
		print("  🔍 WOULD CREATE: %s (%d chars)" % [path, content.length()])
		return

	# Ensure directory exists
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("Failed to create: %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	f.store_string(content)
	f.close()
	print("  ✅ CREATED: %s" % path)


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_error("File not found: %s" % path)
		return ""
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return ""
	var text = f.get_as_text()
	f.close()
	return text


func _write_file(path: String, content: String):
	if DRY_RUN:
		print("  🔍 WOULD PATCH: %s" % path)
		return
	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("Failed to write: %s" % path)
		return
	f.store_string(content)
	f.close()


func _safe_replace(text: String, old: String, new: String, label: String) -> String:
	if text.find(old) == -1:
		print("    ⚠️  Pattern not found for '%s' — may already be patched" % label)
		return text
	return text.replace(old, new)


# ============================================================================
# PATCHERS
# ============================================================================

func _patch_definition():
	print("\n📝 Patching dungeon_definition.gd...")
	var path = "res://resources/data/dungeon_definition.gd"
	var text = _read_file(path)
	if text == "": return

	# Check if already patched
	if text.find("Map Visuals") != -1:
		print("  ⏭️  Already patched (Map Visuals found)")
		return

	# Find the Theme group end — insert after torch_color line
	var insert_after = '@export var torch_color: Color = Color(1.0, 0.7, 0.3, 1.0)'
	var idx = text.find(insert_after)
	if idx == -1:
		# Try alternate (user may have changed default)
		insert_after = "@export var torch_color"
		idx = text.find(insert_after)
		if idx != -1:
			# Find end of this line
			idx = text.find("\n", idx)
		else:
			push_error("  ❌ Can't find torch_color export — patch manually")
			return
	else:
		idx += insert_after.length()

	var patch = """

# ============================================================================
# MAP VISUALS (Slay the Spire-style flowchart map)
# ============================================================================
@export_group("Map Visuals")
@export var map_background: Texture2D = null       ## cross-section stone/earth bg
@export var map_node_backing: Texture2D = null     ## chamber circle behind icons
@export var map_path_color: Color = Color(0.55, 0.45, 0.3, 0.7)
## 0 = desaturate (dim locked nodes), 1 = hard fog (hide behind overlay)
@export_range(0, 1) var map_fog_mode: int = 0"""

	text = text.insert(idx, patch)
	_write_file(path, text)
	print("  ✅ Patched: added Map Visuals exports")


func _patch_dungeon_scene():
	print("\n📝 Patching dungeon_scene.gd...")
	var path = "res://scripts/dungeon/dungeon_scene.gd"
	var text = _read_file(path)
	if text == "": return

	# Check if already patched
	if text.find("dungeon_map: DungeonMap") != -1:
		print("  ⏭️  Already patched")
		return

	var changes = 0

	# 1. Variable declaration
	text = _safe_replace(text,
		"var corridor_builder: DungeonCorridorBuilder = null",
		"var dungeon_map: DungeonMap = null",
		"var declaration")
	changes += 1

	# 2. Node discovery
	text = _safe_replace(text,
		'corridor_builder = find_child("CorridorBuilder", true, false) as DungeonCorridorBuilder',
		'dungeon_map = find_child("DungeonMap", true, false) as DungeonMap',
		"discover nodes")
	changes += 1

	# 2b. Discovery print
	text = _safe_replace(text,
		'"CorridorBuilder: %s" % ("✓" if corridor_builder else "✗")',
		'"DungeonMap: %s" % ("✓" if dungeon_map else "✗")',
		"discover print")

	# 3. Signal connection block — replace the whole corridor_builder connect block
	var old_connect = """if corridor_builder:
		corridor_builder.camera = dungeon_camera
		corridor_builder.player_sprite = corridor_builder.find_child("PlayerSprite", true, false)
		if not corridor_builder.door_selected.is_connected(_on_door_selected):
			corridor_builder.door_selected.connect(_on_door_selected)"""

	var new_connect = """if dungeon_map:
		dungeon_map.camera = dungeon_camera
		if not dungeon_map.node_selected.is_connected(_on_node_selected):
			dungeon_map.node_selected.connect(_on_node_selected)"""

	text = _safe_replace(text, old_connect, new_connect, "signal connect")
	changes += 1

	# 4. build_corridor → build_map
	text = _safe_replace(text,
		"if corridor_builder:\n\t\tcorridor_builder.build_corridor(current_run)",
		"if dungeon_map:\n\t\tdungeon_map.build_map(current_run)",
		"build corridor→map")
	changes += 1

	# 5. clear_corridor → clear_map
	text = _safe_replace(text,
		"if corridor_builder:\n\t\tcorridor_builder.clear_corridor()",
		"if dungeon_map:\n\t\tdungeon_map.clear_map()",
		"clear corridor→map")
	changes += 1

	# 6. _on_door_selected → _on_node_selected
	text = _safe_replace(text,
		"func _on_door_selected(node_id: int):",
		"func _on_node_selected(node_id: int):",
		"handler rename")
	changes += 1

	# 7. advance_to_floor → complete_node
	# The old pattern: corridor_builder.advance_to_floor(node.floor_num + 1)
	# May have whitespace variations, so try a few patterns
	text = _safe_replace(text,
		"if corridor_builder:\n\t\tcorridor_builder.advance_to_floor(node.floor_num + 1)",
		"if dungeon_map:\n\t\tdungeon_map.complete_node(node.id)",
		"advance→complete")

	# Also catch single-tab version
	text = _safe_replace(text,
		"if corridor_builder:\n\tcorridor_builder.advance_to_floor(node.floor_num + 1)",
		"if dungeon_map:\n\tdungeon_map.complete_node(node.id)",
		"advance→complete (alt)")

	_write_file(path, text)
	print("  ✅ Patched: corridor → map references swapped")


func _patch_game_root():
	print("\n📝 Patching game_root.gd...")
	var path = "res://scripts/game/game_root.gd"
	var text = _read_file(path)
	if text == "": return

	if text.find("DungeonMap") != -1 and text.find("CorridorBuilder") == -1:
		print("  ⏭️  Already patched")
		return

	# Replace the CorridorBuilder camera assignment block
	var old_block = """var builder = dungeon_scene.find_child("CorridorBuilder", true, false)
	if builder:
		builder.camera = camera"""

	var new_block = """var dmap = dungeon_scene.find_child("DungeonMap", true, false)
	if dmap:
		dmap.camera = camera"""

	text = _safe_replace(text, old_block, new_block, "game_root camera ref")

	_write_file(path, text)
	print("  ✅ Patched: CorridorBuilder → DungeonMap reference")


# ============================================================================
# EMBEDDED SOURCE — dungeon_map_node.gd
# ============================================================================
const _SRC_MAP_NODE := \
"""# res://scripts/dungeon/dungeon_map_node.gd
## A single clickable node on the dungeon map.
## Visual states: LOCKED, AVAILABLE, CURRENT, COMPLETED, FOGGED.
## Spawned by DungeonMap.build_map(). Uses _draw() for the backing
## circle so it works immediately without texture assets.
extends Area2D
class_name DungeonMapNode

signal node_clicked(node_id: int)

enum State { LOCKED, AVAILABLE, CURRENT, COMPLETED, FOGGED }

# ============================================================================
# CONFIGURATION
# ============================================================================
@export var backing_radius: float = 40.0
@export var icon_scale: float = 0.6

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var icon_sprite: Sprite2D = $Icon

# ============================================================================
# VISUAL CONSTANTS
# ============================================================================
const LOCKED_MODULATE    := Color(0.45, 0.45, 0.45, 0.65)
const AVAILABLE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const CURRENT_MODULATE   := Color(1.15, 1.05, 0.9, 1.0)
const COMPLETED_MODULATE := Color(0.55, 0.55, 0.55, 0.8)
const FOGGED_MODULATE    := Color(0.0, 0.0, 0.0, 0.0)

const BACKING_FILL_ALPHA   := 0.7
const BACKING_BORDER_WIDTH := 2.5
const GLOW_RING_WIDTH      := 3.0
const GLOW_RING_ALPHA      := 0.5

# ============================================================================
# STATE
# ============================================================================
var node_id: int = -1
var node_data: DungeonNodeData = null
var state: State = State.LOCKED
var type_color: Color = Color.WHITE

var _pulse_tween: Tween = null
var _glow_alpha: float = 0.0

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	input_event.connect(_on_input_event)

func configure(data: DungeonNodeData, icon_texture: Texture2D = null):
	node_data = data
	node_id = data.id
	type_color = data.get_color()

	if icon_sprite:
		if icon_texture:
			icon_sprite.texture = icon_texture
		else:
			var path = data.get_icon_path()
			if ResourceLoader.exists(path):
				icon_sprite.texture = load(path)
		icon_sprite.scale = Vector2.ONE * icon_scale

	set_state(State.LOCKED)
	queue_redraw()

# ============================================================================
# STATE MACHINE
# ============================================================================

func set_state(new_state: State):
	state = new_state
	_stop_pulse()

	match state:
		State.LOCKED:
			modulate = LOCKED_MODULATE
			input_pickable = false
			_glow_alpha = 0.0
		State.AVAILABLE:
			modulate = AVAILABLE_MODULATE
			input_pickable = true
			_start_pulse()
		State.CURRENT:
			modulate = CURRENT_MODULATE
			input_pickable = false
			_glow_alpha = GLOW_RING_ALPHA
		State.COMPLETED:
			modulate = COMPLETED_MODULATE
			input_pickable = false
			_glow_alpha = 0.0
		State.FOGGED:
			modulate = FOGGED_MODULATE
			input_pickable = false
			_glow_alpha = 0.0

	queue_redraw()

# ============================================================================
# DRAWING — procedural backing circle
# ============================================================================

func _draw():
	# Outer glow ring (AVAILABLE / CURRENT)
	if _glow_alpha > 0.01:
		var glow_color = type_color
		glow_color.a = _glow_alpha
		draw_arc(Vector2.ZERO, backing_radius + GLOW_RING_WIDTH,
			0, TAU, 64, glow_color, GLOW_RING_WIDTH, true)

	# Dark filled backing
	draw_circle(Vector2.ZERO, backing_radius, Color(0.08, 0.06, 0.1, BACKING_FILL_ALPHA))

	# Colored border ring
	var border = type_color
	border.a = 0.9
	draw_arc(Vector2.ZERO, backing_radius, 0, TAU, 64, border, BACKING_BORDER_WIDTH, true)

	# Subtle inner glow
	var inner = type_color
	inner.a = 0.15
	draw_circle(Vector2.ZERO, backing_radius * 0.6, inner)

# ============================================================================
# PULSE (available nodes)
# ============================================================================

func _start_pulse():
	_stop_pulse()
	_glow_alpha = GLOW_RING_ALPHA
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_glow, GLOW_RING_ALPHA, 0.15, 0.7) \\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_method(_set_glow, 0.15, GLOW_RING_ALPHA, 0.7) \\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _set_glow(val: float):
	_glow_alpha = val
	queue_redraw()

func _stop_pulse():
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null

# ============================================================================
# INPUT
# ============================================================================

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if state != State.AVAILABLE: return
	var clicked = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked = true
	elif event is InputEventScreenTouch and event.pressed:
		clicked = true
	if clicked:
		node_clicked.emit(node_id)
"""


# ============================================================================
# EMBEDDED SOURCE — dungeon_map.gd
# ============================================================================
const _SRC_MAP := \
"""# res://scripts/dungeon/dungeon_map.gd
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

	# Apply theme overrides from definition
	_apply_theme(run.definition)

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
			if node_data.node_type != DungeonEnums.NodeType.START and \\
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
			if fn.state == DungeonMapNode.State.COMPLETED and \\
			   tn.state == DungeonMapNode.State.COMPLETED:
				line.default_color = path_color_completed
			elif (fn.state == DungeonMapNode.State.CURRENT or \\
				  fn.state == DungeonMapNode.State.COMPLETED) and \\
				 tn.state == DungeonMapNode.State.AVAILABLE:
				line.default_color = path_color_available
			elif fn.state == DungeonMapNode.State.COMPLETED and \\
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
		tw.tween_property(fog, "color:a", 0.0, 0.5) \\
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
		tw.tween_property(player_token, "global_position", to_pos, token_tween_duration) \\
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
			tw.tween_property(camera, "global_position", target, camera_tween_duration) \\
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

func _play_intro():
	if not camera or _run == null: return
	_intro_playing = true
	var last_floor = _run.definition.floor_count - 1
	var boss_id = _run.floors[last_floor][0] if _run.floors[last_floor].size() > 0 else -1
	var start_id = _run.floors[0][0] if _run.floors[0].size() > 0 else -1
	var boss_y = _node_positions.get(boss_id, Vector2.ZERO).y if boss_id >= 0 else 0.0
	var start_y = _node_positions.get(start_id, Vector2.ZERO).y if start_id >= 0 else 0.0
	var boss_cam = Vector2(map_width / 2.0, boss_y)
	var start_cam = Vector2(map_width / 2.0, start_y)
	if camera.has_method("corridor_set_position"):
		camera.corridor_set_position(boss_cam)
	else:
		camera.global_position = boss_cam
	var tw = create_tween()
	tw.tween_interval(intro_pause_at_boss)
	tw.tween_property(camera, "global_position", start_cam, intro_duration) \\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_on_intro_finished)

func _on_intro_finished():
	_intro_playing = false
	if _current_node_id >= 0:
		_camera_follow_node(_current_node_id, true)

# ============================================================================
# INTERACTION
# ============================================================================

func _on_node_clicked(node_id: int):
	if _transitioning or _intro_playing: return
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

func get_current_node_id() -> int:
	return _current_node_id

func get_node_position(node_id: int) -> Vector2:
	return _node_positions.get(node_id, Vector2.ZERO)
"""


# ============================================================================
# EMBEDDED SCENES (.tscn text format)
# ============================================================================

const _TSCN_MAP_NODE := \
"""[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/dungeon/dungeon_map_node.gd" id="1_script"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 40.0

[node name="DungeonMapNode" type="Area2D"]
script = ExtResource("1_script")
input_pickable = true

[node name="Icon" type="Sprite2D" parent="."]

[node name="CollisionShape" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
"""


const _TSCN_MAP := \
"""[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/dungeon/dungeon_map.gd" id="1_map"]
[ext_resource type="PackedScene" path="res://scenes/dungeon/dungeon_map_node.tscn" id="2_node"]

[node name="DungeonMap" type="Node2D"]
script = ExtResource("1_map")
node_scene = ExtResource("2_node")

[node name="PathLines" type="Node2D" parent="."]

[node name="Nodes" type="Node2D" parent="."]

[node name="FogOverlays" type="Node2D" parent="."]

[node name="PlayerToken" type="Sprite2D" parent="."]
z_index = 10
"""
