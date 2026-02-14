## Tracks runtime state of a single dungeon run (entrance to exit/death).
class_name DungeonRun

var definition: DungeonDefinition = null

var nodes: Dictionary = {}          # id -> DungeonNodeData
var floors: Array[Array] = []       # floor_num -> [node_ids]

var current_node_id: int = -1
var current_floor: int = 0

# Rollback tracking
var gold_snapshot_on_entry: int = 0
var gold_earned: int = 0
var exp_earned: int = 0
var items_earned: Array[EquippableItem] = []
var temp_affixes_applied: Array[DiceAffix] = []
var shrine_affixes_applied: Array[Affix] = []
var events_seen: Array[String] = []

var is_complete: bool = false
var is_failed: bool = false
var floors_cleared: int = 0

func start(def: DungeonDefinition, player_gold: int):
	definition = def
	gold_snapshot_on_entry = player_gold

func add_node(node: DungeonNodeData):
	nodes[node.id] = node

func get_node(id: int) -> DungeonNodeData:
	return nodes.get(id) as DungeonNodeData

func get_floor_nodes(floor_num: int) -> Array:
	if floor_num < 0 or floor_num >= floors.size(): return []
	var result = []
	for node_id in floors[floor_num]:
		result.append(get_node(node_id))
	return result

func get_available_nodes() -> Array:
	var available = []
	if current_floor + 1 >= floors.size(): return available
	for node_id in floors[current_floor + 1]:
		var node = get_node(node_id)
		if node and node.is_available(current_node_id):
			available.append(node)
	return available

func visit_node(node_id: int):
	var node = get_node(node_id)
	if not node: return
	node.visited = true
	current_node_id = node_id
	current_floor = node.floor_num

func complete_node(node_id: int):
	var node = get_node(node_id)
	if not node: return
	node.completed = true
	floors_cleared = max(floors_cleared, node.floor_num)

func track_gold(amount: int): gold_earned += amount
func track_exp(amount: int): exp_earned += amount
func track_item(item: EquippableItem): items_earned.append(item)
func track_temp_affix(affix: DiceAffix): temp_affixes_applied.append(affix)
func track_shrine_affix(affix: Affix): shrine_affixes_applied.append(affix)
func track_event(event_id: String): events_seen.append(event_id)
func was_event_seen(event_id: String) -> bool: return events_seen.has(event_id)
