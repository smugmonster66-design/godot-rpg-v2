## Procedurally generates a dungeon map from a DungeonDefinition.
## Pure logic — no scene or node dependencies.
class_name DungeonMapGenerator

const TYPE_WEIGHTS = {
	DungeonEnums.NodeType.COMBAT: 50,
	DungeonEnums.NodeType.EVENT: 20,
	DungeonEnums.NodeType.TREASURE: 10,
	DungeonEnums.NodeType.SHRINE: 5,
}
const ELITE_MIN_FLOOR_RATIO = 0.4

var _next_id: int = 0

func generate(definition: DungeonDefinition) -> DungeonRun:
	_next_id = 0
	var run = DungeonRun.new()
	run.definition = definition
	run.floors.resize(definition.floor_count)
	for i in definition.floor_count:
		run.floors[i] = []

	_build_start_floor(run)
	_build_middle_floors(run, definition)
	_build_boss_floor(run, definition)
	_generate_paths(run, definition)
	_populate_node_content(run, definition)

	print("🏰 Generated: %s (%d floors, %d nodes)" % [
		definition.dungeon_name, definition.floor_count, run.nodes.size()])
	return run

# --- Floor building ---

func _build_start_floor(run: DungeonRun):
	var node = _create_node(0, 0, DungeonEnums.NodeType.START)
	run.add_node(node)
	run.floors[0] = [node.id]

func _build_boss_floor(run: DungeonRun, def: DungeonDefinition):
	var f = def.floor_count - 1
	var node = _create_node(f, 0, DungeonEnums.NodeType.BOSS)
	run.add_node(node)
	run.floors[f] = [node.id]

func _build_middle_floors(run: DungeonRun, def: DungeonDefinition):
	var mid = def.get_mid_floor()
	var pre_boss = def.floor_count - 2
	var elite_min = int(def.floor_count * ELITE_MIN_FLOOR_RATIO)

	for f in range(1, def.floor_count - 1):
		var is_safe = (def.safe_floor_before_boss and f == pre_boss) or \
					  (def.mid_safe_floor and f == mid)
		if is_safe:
			_build_safe_floor(run, def, f)
		elif f >= elite_min and f == pre_boss - 1:
			_build_elite_floor(run, def, f)
		else:
			_build_standard_floor(run, def, f)

func _build_safe_floor(run: DungeonRun, def: DungeonDefinition, f: int):
	var types = [DungeonEnums.NodeType.REST, DungeonEnums.NodeType.SHOP]
	types.shuffle()
	var count = randi_range(1, 2)
	for i in count:
		var node = _create_node(f, i, types[i % types.size()])
		run.add_node(node)
		run.floors[f].append(node.id)

func _build_elite_floor(run: DungeonRun, def: DungeonDefinition, f: int):
	for i in randi_range(1, 2):
		var node = _create_node(f, i, DungeonEnums.NodeType.ELITE)
		run.add_node(node)
		run.floors[f].append(node.id)

func _build_standard_floor(run: DungeonRun, def: DungeonDefinition, f: int):
	for i in randi_range(def.min_nodes_per_floor, def.max_nodes_per_floor):
		var node = _create_node(f, i, _pick_weighted_type())
		run.add_node(node)
		run.floors[f].append(node.id)

# --- Path generation ---

func _generate_paths(run: DungeonRun, def: DungeonDefinition):
	for f in range(0, def.floor_count - 1):
		var curr = run.floors[f]
		var next = run.floors[f + 1]
		if curr.size() == 0 or next.size() == 0: continue

		# Sort both floors by column index so positional mapping is stable
		curr.sort_custom(func(a, b): return run.get_node(a).column < run.get_node(b).column)
		next.sort_custom(func(a, b): return run.get_node(a).column < run.get_node(b).column)

		# Each current node connects to its nearest neighbor(s) on next floor
		for ci in curr.size():
			# Map position proportionally: which next-floor index is "closest"?
			var ratio = float(ci) / max(curr.size() - 1, 1)
			var target_idx = roundi(ratio * (next.size() - 1))
			_connect(run, curr[ci], next[target_idx])

			# Optionally also connect to an adjacent neighbor (one step left or right)
			if next.size() > 1 and randf() < 0.35:
				var offset = 1 if randf() > 0.5 else -1
				var adj_idx = clampi(target_idx + offset, 0, next.size() - 1)
				if adj_idx != target_idx:
					_connect(run, curr[ci], next[adj_idx])

		# Guarantee no orphans on next floor
		for nid in next:
			var node = run.get_node(nid)
			if node.connections_from.size() == 0:
				# Find nearest current-floor node by index
				var ni = next.find(nid)
				var ratio2 = float(ni) / max(next.size() - 1, 1)
				var best_ci = roundi(ratio2 * (curr.size() - 1))
				_connect(run, curr[best_ci], nid)



func _connect(run: DungeonRun, from_id: int, to_id: int):
	var f = run.get_node(from_id)
	var t = run.get_node(to_id)
	if not f or not t: return
	if not f.connections_to.has(to_id): f.connections_to.append(to_id)
	if not t.connections_from.has(from_id): t.connections_from.append(from_id)

# --- Content population ---

func _populate_node_content(run: DungeonRun, def: DungeonDefinition):
	for node in run.nodes.values():
		match node.node_type:
			DungeonEnums.NodeType.COMBAT: node.encounter = def.get_random_combat()
			DungeonEnums.NodeType.ELITE: node.encounter = def.get_random_elite()
			DungeonEnums.NodeType.BOSS: node.encounter = def.get_random_boss()
			DungeonEnums.NodeType.EVENT: node.event = def.get_random_event(node.floor_num)
			DungeonEnums.NodeType.SHRINE: node.shrine = def.get_random_shrine()

# --- Helpers ---

func _create_node(f: int, col: int, type: DungeonEnums.NodeType) -> DungeonNodeData:
	var n = DungeonNodeData.new()
	n.id = _next_id; n.floor_num = f; n.column = col; n.node_type = type
	_next_id += 1
	return n

func _pick_weighted_type() -> DungeonEnums.NodeType:
	var total = 0
	for w in TYPE_WEIGHTS.values(): total += w
	var roll = randi() % total
	var cum = 0
	for type in TYPE_WEIGHTS:
		cum += TYPE_WEIGHTS[type]
		if roll < cum: return type
	return DungeonEnums.NodeType.COMBAT
