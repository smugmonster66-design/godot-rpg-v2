## Runtime data for a single node on the dungeon map.
## NOT a Resource — created by generator at runtime.
class_name DungeonNodeData

var id: int = -1
var floor_num: int = 0
var column: int = 0
var node_type: DungeonEnums.NodeType = DungeonEnums.NodeType.COMBAT

var connections_to: Array[int] = []
var connections_from: Array[int] = []

var encounter: CombatEncounter = null
var event: DungeonEvent = null
var shrine: DungeonShrine = null

var visited: bool = false
var completed: bool = false

func is_available(current_node_id: int) -> bool:
	return connections_from.has(current_node_id) and not completed

func get_display_name() -> String:
	match node_type:
		DungeonEnums.NodeType.COMBAT, DungeonEnums.NodeType.ELITE, DungeonEnums.NodeType.BOSS:
			return encounter.encounter_name if encounter else DungeonEnums.get_node_type_name(node_type)
		DungeonEnums.NodeType.EVENT:
			return event.event_name if event else "Event"
		DungeonEnums.NodeType.SHRINE:
			return shrine.shrine_name if shrine else "Shrine"
		_:
			return DungeonEnums.get_node_type_name(node_type)

func get_color() -> Color:
	return DungeonEnums.get_node_color(node_type)

func get_icon_path() -> String:
	return DungeonEnums.get_node_icon_path(node_type)
