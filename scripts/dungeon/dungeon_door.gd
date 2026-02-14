# res://scripts/dungeon/dungeon_door.gd
## A single clickable door on a dungeon wall.
## Self-contained packed scene — configured externally, emits click signal.
extends Node2D
class_name DungeonDoor

signal door_clicked(node_id: int)

# ============================================================================
# STATE
# ============================================================================
var node_id: int = -1
var node_type: DungeonEnums.NodeType = DungeonEnums.NodeType.COMBAT
var _is_interactive: bool = false

# ============================================================================
# NODE REFERENCES — editor-placed, discovered in _ready
# ============================================================================
var door_sprite: Sprite2D = null
var icon_sprite: Sprite2D = null
var type_label: Label = null
var glow_sprite: Sprite2D = null
var click_area: Area2D = null

func _ready():
	door_sprite = $DoorSprite
	icon_sprite = $IconSprite
	type_label = $TypeLabel
	glow_sprite = $GlowSprite
	click_area = $ClickArea

	if glow_sprite: glow_sprite.hide()

	# Connect click via Area2D input_event
	if click_area:
		click_area.input_event.connect(_on_click_area_input)

# ============================================================================
# CONFIGURATION
# ============================================================================

func configure(data: DungeonNodeData):
	node_id = data.id
	node_type = data.node_type

	# Set icon texture
	var icon_path = data.get_icon_path()
	if icon_path != "" and ResourceLoader.exists(icon_path):
		if icon_sprite: icon_sprite.texture = load(icon_path)

	# Tint icon by node type color
	if icon_sprite:
		icon_sprite.modulate = data.get_color()

	# Set type label text (4.5 stacked effects handle outline+shadow)
	if type_label:
		type_label.text = DungeonEnums.get_node_type_name(data.node_type)

func set_interactive(interactive: bool):
	_is_interactive = interactive
	if glow_sprite:
		glow_sprite.visible = interactive

# ============================================================================
# INPUT — handled by Area2D, not _input override
# ============================================================================

func _on_click_area_input(viewport: Node, event: InputEvent, shape_idx: int):
	if not _is_interactive: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		door_clicked.emit(node_id)
	elif event is InputEventScreenTouch and event.pressed:
		door_clicked.emit(node_id)
