# res://resources/data/location_node.gd
# Definition of a map location/node. This is static data, NOT saved.
# Runtime state (visited, unlocked) is tracked in MapProgress.
extends Resource
class_name LocationNode

enum NodeType {
	TOWN,           # Safe area with shops, NPCs
	CAMP,           # Rest point, minor services
	DUNGEON,        # Combat area with encounters
	BOSS,           # Boss encounter
	EVENT,          # Story/dialogue event
	SHRINE,         # Buff/upgrade location
	TREASURE,       # Loot location
	CROSSROADS,     # Pure navigation node
	HIDDEN          # Secret location
}

## High-level category used for visual grouping and map node icon style.
## Add new values here freely — existing .tres resources default to OTHER.
enum MapNodeCategory {
	TOWN,       # Settlement, hub
	DUNGEON,    # Dungeon entrance
	ENCOUNTER,  # Combat encounter
	ZONE,       # Sub-zone / sub-map entrance
	OTHER,      # Catch-all
}

enum VisibilityState {
	VISIBLE,        # Always shown on map
	HIDDEN,         # Not shown until reveal condition met
	FOG,            # Shown as "?" until visited
}

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
## Unique location identifier
@export var location_id: StringName = &""
## Display name on map
@export var display_name: String = ""
## Localization key
@export var name_key: String = ""
## Location type for visual styling
@export var node_type: NodeType = NodeType.TOWN

# ============================================================================
# MAP NODE
# ============================================================================
@export_group("Map Node")
## High-level category — controls icon style on the map
@export var map_node_category: MapNodeCategory = MapNodeCategory.OTHER
## Buttons to show in this node's radial menu when clicked
@export var radial_buttons: Array[MapNodeButtonDef] = []

# ============================================================================
# DESCRIPTION
# ============================================================================
@export_group("Description")
## Short description shown on hover
@export_multiline var description: String = ""
## Region this location belongs to
@export var region_id: StringName = &""

# ============================================================================
# MAP POSITION
# ============================================================================
@export_group("Map Position")
## Position on the world map (in map coordinates)
@export var map_position: Vector2 = Vector2.ZERO
## Visual layer/depth for parallax (higher = further back)
@export var depth_layer: int = 0

# ============================================================================
# CONNECTIONS
# ============================================================================
@export_group("Connections")
## Location IDs this node connects to (bidirectional). Use StringNames or drag resources below.
@export var connections: Array[StringName] = []
## One-way connections (can travel TO these but not back). Use StringNames or drag resources below.
@export var one_way_connections: Array[StringName] = []
## Inspector shortcut: drag LocationNode .tres files here to add bidirectional connections.
## IDs are resolved at runtime — no need to also fill the StringName array above.
@export var connected_node_resources: Array[LocationNode] = []
## Inspector shortcut: drag LocationNode .tres files here to add one-way connections.
@export var one_way_connected_node_resources: Array[LocationNode] = []

# ============================================================================
# VISIBILITY & UNLOCK CONDITIONS
# ============================================================================
@export_group("Visibility")
## Initial visibility state
@export var initial_visibility: VisibilityState = VisibilityState.VISIBLE
## Condition to reveal this location (if HIDDEN)
@export var reveal_condition: GameCondition = null

@export_group("Unlock")
## Condition to unlock travel to this location
@export var unlock_condition: GameCondition = null
## Text shown when locked (e.g., "Requires Level 10")
@export var locked_hint: String = ""
## Localization key for locked hint
@export var locked_hint_key: String = ""

# ============================================================================
# CONTENT
# ============================================================================
@export_group("Content")
## NPCs present at this location
@export var npc_ids: Array[StringName] = []
## Quests that can be started here
@export var available_quest_ids: Array[StringName] = []
## Shop IDs available here
@export var shop_ids: Array[StringName] = []
## Encounter table for random battles (if dungeon)
@export var encounter_table_id: StringName = &""
## Dialogue encounter to trigger on first visit
@export var first_visit_dialogue: StringName = &""
## Dialogue encounter to trigger on subsequent visits
@export var visit_dialogue: StringName = &""

# ============================================================================
# EVENTS
# ============================================================================
@export_group("Events")
## Event tags fired when location is first visited
@export var on_first_visit_events: Array[StringName] = []
## Event tags fired on every visit
@export var on_visit_events: Array[StringName] = []
## Flags to set when visited
@export var set_flags_on_visit: Array[StringName] = []

# ============================================================================
# VISUAL
# ============================================================================
@export_group("Visual")
## Icon for map marker
@export var map_icon: Texture2D = null
## Base circle/plate texture drawn beneath the map icon. Leave null to use whatever
## is set as the default in the map_node_button.tscn scene.
@export var node_circle_texture: Texture2D = null
## Background scene for location
@export var background_scene: PackedScene = null
## Ambient music track
@export var music_id: StringName = &""

# ============================================================================
# GAMEPLAY
# ============================================================================
@export_group("Gameplay")
## Recommended player level
@export var recommended_level: int = 1
## Can the player rest here?
@export var allows_rest: bool = false
## Is this a safe zone? (no random encounters)
@export var safe_zone: bool = true

# ============================================================================
# API
# ============================================================================

func get_display_name() -> String:
	# TODO: Localization
	return display_name if name_key == "" else display_name

func get_locked_hint() -> String:
	# TODO: Localization
	return locked_hint if locked_hint_key == "" else locked_hint

func get_bidirectional_connections() -> Array[StringName]:
	"""Get bidirectional connection IDs (StringName list + resource list merged)."""
	var result: Array[StringName] = []
	result.append_array(connections)
	for node in connected_node_resources:
		if node and not node.location_id in result:
			result.append(node.location_id)
	return result

func get_one_way_connections_all() -> Array[StringName]:
	"""Get one-way connection IDs (StringName list + resource list merged)."""
	var result: Array[StringName] = []
	result.append_array(one_way_connections)
	for node in one_way_connected_node_resources:
		if node and not node.location_id in result:
			result.append(node.location_id)
	return result

func get_all_connections() -> Array[StringName]:
	"""Get all outgoing connection IDs (bidirectional + one-way, both sources)."""
	var result = get_bidirectional_connections()
	for id in get_one_way_connections_all():
		if not id in result:
			result.append(id)
	return result

func has_connection_to(target_id: StringName) -> bool:
	"""Check if this node connects to another (checks both StringName and resource arrays)."""
	if target_id in connections or target_id in one_way_connections:
		return true
	for node in connected_node_resources:
		if node and node.location_id == target_id:
			return true
	for node in one_way_connected_node_resources:
		if node and node.location_id == target_id:
			return true
	return false

func is_dungeon() -> bool:
	return node_type == NodeType.DUNGEON or node_type == NodeType.BOSS

func has_shops() -> bool:
	return shop_ids.size() > 0

func has_npcs() -> bool:
	return npc_ids.size() > 0
