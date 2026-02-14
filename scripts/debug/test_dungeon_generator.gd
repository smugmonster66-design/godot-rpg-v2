@tool
extends EditorScript

func _run():
	print("=== Dungeon Generator Tests ===")
	var def = _make_test_def()
	var gen = DungeonMapGenerator.new()
	var run = gen.generate(def)

	assert(run.nodes.size() > 0)
	assert(run.floors.size() == 10)
	assert(run.floors[0].size() == 1)
	assert(run.floors[9].size() == 1)
	var start = run.get_node(run.floors[0][0])
	assert(start.node_type == DungeonEnums.NodeType.START)
	var boss = run.get_node(run.floors[9][0])
	assert(boss.node_type == DungeonEnums.NodeType.BOSS)

	# Connectivity
	for node in run.nodes.values():
		if node.node_type != DungeonEnums.NodeType.START:
			assert(node.connections_from.size() > 0, "Node %d orphaned" % node.id)
		if node.node_type != DungeonEnums.NodeType.BOSS:
			assert(node.connections_to.size() > 0, "Node %d dead-end" % node.id)

	# Run state
	run.start(def, 500)
	assert(run.gold_snapshot_on_entry == 500)
	run.visit_node(run.floors[0][0])
	run.complete_node(run.floors[0][0])
	assert(run.get_available_nodes().size() > 0)
	run.track_gold(50); run.track_exp(100)
	assert(run.gold_earned == 50 and run.exp_earned == 100)
	print("=== All generator tests passed (%d nodes) ===" % run.nodes.size())

func _make_test_def() -> DungeonDefinition:
	var d = DungeonDefinition.new()
	d.dungeon_name = "Test"; d.dungeon_id = "test"; d.floor_count = 10
	d.dungeon_level = 10; d.dungeon_region = 1
	var ce = CombatEncounter.new(); ce.encounter_name = "Fight"
	var e = EnemyData.new(); e.enemy_name = "Skel"; e.max_health = 20
	ce.enemies.assign([e]); d.combat_encounters.assign([ce])
	var ee = ce.duplicate(true); ee.encounter_name = "Elite"; d.elite_encounters.assign([ee])
	var be = ce.duplicate(true); be.encounter_name = "Boss"; d.boss_encounters.assign([be])
	var ev = DungeonEvent.new(); ev.event_name = "Test"; ev.event_id = "t"
	var ch = DungeonEventChoice.new(); ch.choice_text = "OK"; ev.choices.assign([ch])
	d.event_pool.assign([ev])
	var sh = DungeonShrine.new(); sh.shrine_name = "Shrine"; sh.blessing_affix = Affix.new()
	d.shrine_pool.assign([sh])
	return d
