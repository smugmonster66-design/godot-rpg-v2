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
var consumables_earned: Array[ConsumableItem] = []
var temp_affixes_applied: Array[DiceAffix] = []
var shrine_affixes_applied: Array[Affix] = []
var events_seen: Array[String] = []

# ── Roguelite Run Affix State ──
var run_affixes_chosen: Array[RunAffixEntry] = []
var affix_offers_given: int = 0

var is_complete: bool = false
var is_failed: bool = false
var floors_cleared: int = 0

func _init():
	# Force fresh array instance — breaks shared-default-array link
	run_affixes_chosen = []

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
func track_consumable(item: ConsumableItem): consumables_earned.append(item)
func track_temp_affix(affix: DiceAffix): temp_affixes_applied.append(affix)
func track_shrine_affix(affix: Affix): shrine_affixes_applied.append(affix)
func track_event(event_id: String): events_seen.append(event_id)
func was_event_seen(event_id: String) -> bool: return events_seen.has(event_id)

# ── Roguelite Run Affix Tracking ──

func track_run_affix(entry: RunAffixEntry):
	run_affixes_chosen.append(entry)
	affix_offers_given += 1

func get_run_affix_stack_count(entry: RunAffixEntry) -> int:
	var count: int = 0
	for chosen in run_affixes_chosen:
		if chosen == entry or (chosen.affix_id != "" and chosen.affix_id == entry.affix_id):
			count += 1
	return count

func has_run_affix_tag(tag: String) -> bool:
	for entry in run_affixes_chosen:
		if tag in entry.tags:
			return true
	return false

func get_all_run_affix_tags() -> Array[String]:
	var result: Array[String] = []
	for entry in run_affixes_chosen:
		for tag in entry.tags:
			if tag not in result:
				result.append(tag)
	return result

func skip_affix_offer():
	affix_offers_given += 1

# ── Save / resume (a run survives closing the app) ──
# Resources are stored as indices into the definition's pools, so a save
# stays valid as long as the dungeon's pools keep their order.

func to_dict(player) -> Dictionary:
	var node_list: Array = []
	for n: DungeonNodeData in nodes.values():
		node_list.append({
			"id": n.id, "floor": n.floor_num, "column": n.column, "type": int(n.node_type),
			"to": Array(n.connections_to), "from": Array(n.connections_from),
			"encounter": _encounter_ref(n.encounter),
			"event": definition.event_pool.find(n.event) if n.event else -1,
			"shrine": definition.shrine_pool.find(n.shrine) if n.shrine else -1,
			"visited": n.visited, "completed": n.completed,
		})
	var floor_ids: Array = []
	for f in floors:
		floor_ids.append(Array(f))
	var item_idx: Array = []
	if player:
		for it in items_earned:
			var i: int = player.inventory.find(it)
			if i >= 0:
				item_idx.append(i)
	var consumable_names: Array = []
	for c in consumables_earned:
		if c:
			consumable_names.append(c.item_name)
	var affix_idx: Array = []
	for e in run_affixes_chosen:
		affix_idx.append(definition.run_affix_pool.find(e))
	return {
		"definition": definition.resource_path,
		"nodes": node_list, "floors": floor_ids,
		"current_node_id": current_node_id, "current_floor": current_floor,
		"gold_snapshot_on_entry": gold_snapshot_on_entry, "gold_earned": gold_earned,
		"exp_earned": exp_earned, "items": item_idx, "consumables": consumable_names,
		"events_seen": Array(events_seen), "run_affixes": affix_idx,
		"affix_offers_given": affix_offers_given, "floors_cleared": floors_cleared,
	}

func _encounter_ref(enc: CombatEncounter) -> Dictionary:
	if enc == null:
		return {}
	for pool_name in ["combat_encounters", "elite_encounters", "boss_encounters"]:
		var i: int = definition.get(pool_name).find(enc)
		if i >= 0:
			return {"pool": pool_name, "index": i}
	return {"path": enc.resource_path}

static func from_dict(data: Dictionary, player) -> DungeonRun:
	var path: String = data.get("definition", "")
	var def = load(path) as DungeonDefinition if path != "" and ResourceLoader.exists(path) else null
	if def == null:
		return null
	var run := DungeonRun.new()
	run.definition = def
	for nd in data.get("nodes", []):
		var n := DungeonNodeData.new()
		n.id = int(nd.id); n.floor_num = int(nd.floor); n.column = int(nd.column)
		n.node_type = int(nd.type) as DungeonEnums.NodeType
		for t in nd.get("to", []): n.connections_to.append(int(t))
		for f in nd.get("from", []): n.connections_from.append(int(f))
		var er: Dictionary = nd.get("encounter", {})
		if er.has("pool"):
			var pool: Array = def.get(er.pool)
			var ei: int = int(er.index)
			n.encounter = pool[ei] if ei >= 0 and ei < pool.size() else null
		elif er.has("path") and ResourceLoader.exists(er.path):
			n.encounter = load(er.path)
		var evi: int = int(nd.get("event", -1))
		n.event = def.event_pool[evi] if evi >= 0 and evi < def.event_pool.size() else null
		var shi: int = int(nd.get("shrine", -1))
		n.shrine = def.shrine_pool[shi] if shi >= 0 and shi < def.shrine_pool.size() else null
		n.visited = bool(nd.get("visited", false)); n.completed = bool(nd.get("completed", false))
		run.add_node(n)
	for f in data.get("floors", []):
		var ids: Array = []
		for i in f: ids.append(int(i))
		run.floors.append(ids)
	run.current_node_id = int(data.get("current_node_id", -1))
	run.current_floor = int(data.get("current_floor", 0))
	run.gold_snapshot_on_entry = int(data.get("gold_snapshot_on_entry", 0))
	run.gold_earned = int(data.get("gold_earned", 0))
	run.exp_earned = int(data.get("exp_earned", 0))
	if player:
		for i in data.get("items", []):
			if int(i) >= 0 and int(i) < player.inventory.size():
				run.items_earned.append(player.inventory[int(i)])
	for cname in data.get("consumables", []):
		var c := ConsumableItem.new()
		c.item_name = str(cname)
		run.consumables_earned.append(c)
	for e in data.get("events_seen", []): run.events_seen.append(str(e))
	for ai in data.get("run_affixes", []):
		if int(ai) >= 0 and int(ai) < def.run_affix_pool.size():
			run.run_affixes_chosen.append(def.run_affix_pool[int(ai)])
	run.affix_offers_given = int(data.get("affix_offers_given", 0))
	run.floors_cleared = int(data.get("floors_cleared", 0))
	return run
