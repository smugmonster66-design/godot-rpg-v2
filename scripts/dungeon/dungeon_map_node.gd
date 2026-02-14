# res://scripts/dungeon/dungeon_map_node.gd
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
	_pulse_tween.tween_method(_set_glow, GLOW_RING_ALPHA, 0.15, 0.7) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_method(_set_glow, 0.15, GLOW_RING_ALPHA, 0.7) \
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
