# res://resources/data/map_definition.gd
# Defines a named map: a set of LocationNodes and their layout.
# Used for region overworld maps and sub-maps (towns, dungeons, etc.).
# To create a new map: make a .tres file of this type, drag LocationNode
# .tres files into location_nodes, and set a starting_location_id.
extends Resource
class_name MapDefinition

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## Unique ID for this map (e.g., &"region_ashlands", &"town_ember_gate")
@export var map_id: StringName = &""
## Display name shown in the map header
@export var display_name: String = ""
## Optional region this map belongs to (for grouping/unlock logic)
@export var region_id: StringName = &""

# ============================================================================
# CONTENT
# ============================================================================
@export_group("Content")
## All LocationNode resources that make up this map.
## Drag .tres files here — no need to put them in the locations folder
## (MapManager will register them automatically when this map is loaded).
@export var location_nodes: Array[LocationNode] = []
## Location where the player appears when entering this map for the first time.
## Leave empty to use the first node in location_nodes.
@export var starting_location_id: StringName = &""
## Location where the player returns to in the PARENT map when leaving this sub-map.
## Only relevant for sub-maps; ignored for root maps.
@export var return_location_id: StringName = &""

# ============================================================================
# EDITOR DATA  (written by the in-game map editor tool only)
# ============================================================================
@export_group("Editor")
## Waypoints for curved paths. Key format:
##   Bidirectional — "id_a_id_b" (alphabetically sorted, separated by "_")
##   One-way       — "from_id>to_id"
## Value: Array[Vector2] of intermediate control points for Catmull-Rom spline.
## Leave empty for a straight-line path.
@export var connection_waypoints: Dictionary = {}

# ============================================================================
# VISUAL
# ============================================================================
@export_group("Visual")
## Background texture for this map
@export var background_texture: Texture2D = null
## Ambient music track ID
@export var ambient_music_id: StringName = &""

# ============================================================================
# DECOR
# ============================================================================
@export_group("Decor")
## Decorative elements placed on the map (trees, rocks, ruins, fog patches, etc.).
## Authored via the in-game map editor's Decor tool.
@export var decor_items: Array[MapDecorItem] = []

# ============================================================================
# LIGHTING
# ============================================================================
@export_group("Lighting")
## Atmospheric lighting configuration (ambient tint, point lights, vignette).
## Leave null for no lighting overlay.
@export var lighting_config: MapLightingConfig = null

# ============================================================================
# UNLOCK
# ============================================================================
@export_group("Unlock")
## Condition that must be met to enter this map
@export var unlock_condition: GameCondition = null
## Text shown when access is blocked
@export var locked_hint: String = ""

# ============================================================================
# API
# ============================================================================

func get_starting_location_id() -> StringName:
	if starting_location_id != &"":
		return starting_location_id
	if not location_nodes.is_empty() and location_nodes[0] != null:
		return location_nodes[0].location_id
	return &""

func get_location_node(location_id: StringName) -> LocationNode:
	for node in location_nodes:
		if node and node.location_id == location_id:
			return node
	return null

func contains_location(location_id: StringName) -> bool:
	return get_location_node(location_id) != null
