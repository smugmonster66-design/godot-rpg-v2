# res://tests/map_systems_test.gd
# Headless test of the map fixes (engine/story-gaps, Phase 3), on a small map
# built in code and pushed as a zone on top of a NEW game.
# WRITES user://save.tres (autosave). Back up your save first.
#
#   godot --headless --path . res://tests/map_systems_test.tscn
#
# Map:   A(start) -- B -- C -- D          F (HIDDEN, reveal on flag)
#        A -- G (locked until flag)        A -- F
#        A -- L (locked, has locked_hint)
extends Node

const ARRIVAL_SCENE := "res://resources/dialogues/test dialogue 3.tres"

var _failures: Array[String] = []
var _notices: Array[String] = []


func _ready() -> void:
	var root_scene: Node = load("res://scenes/game/game_root.tscn").instantiate()
	get_tree().root.add_child.call_deferred(root_scene)
	_run.call_deferred(root_scene)


func _check(cond: bool, what: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + what)
	if not cond:
		_failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _flag_cond(flag: StringName) -> GameCondition:
	var sc := SingleCheck.new()
	sc.check_type = SingleCheck.CheckType.FLAG
	sc.key = flag
	var c := GameCondition.new()
	c.condition_type = GameCondition.ConditionType.SINGLE
	c.single_check = sc
	return c


func _node(id: String, pos: Vector2, links: Array) -> LocationNode:
	var n := LocationNode.new()
	n.location_id = StringName(id)
	n.display_name = id
	n.map_position = pos
	var c: Array[StringName] = []
	for l in links:
		c.append(StringName(l))
	n.connections = c
	return n


func _build_map() -> MapDefinition:
	var a := _node("t_a", Vector2(200, 200), ["t_b", "t_g", "t_l", "t_f"])
	var b := _node("t_b", Vector2(500, 200), ["t_a", "t_c"])
	var c := _node("t_c", Vector2(800, 200), ["t_b", "t_d"])
	var d := _node("t_d", Vector2(1100, 200), ["t_c"])
	var g := _node("t_g", Vector2(200, 500), ["t_a"])
	g.unlock_condition = _flag_cond(&"lighthouse_lit")
	var l := _node("t_l", Vector2(500, 500), ["t_a"])
	l.unlock_condition = _flag_cond(&"secret_passage_discovered")
	l.locked_hint = "Closed for repairs."
	var f := _node("t_f", Vector2(800, 500), ["t_a"])
	f.initial_visibility = LocationNode.VisibilityState.HIDDEN
	f.reveal_condition = _flag_cond(&"boss_tutorial_defeated")
	var m := MapDefinition.new()
	m.map_id = &"test_map_systems"
	m.starting_location_id = &"t_a"
	var nodes: Array[LocationNode] = [a, b, c, d, g, l, f]
	m.location_nodes = nodes
	# Reuse the test map's background so MapScene can size itself.
	var bg_src: MapDefinition = load("res://resources/test_world_map.tres")
	m.background_texture = bg_src.background_texture
	return m


func _run(root_scene: Node) -> void:
	await _frames(10)
	var title: Node = root_scene.find_child("TitleScreen", true, false)
	if title:
		title.new_game_confirmed.emit()
	await _frames(30)
	NotificationManager.notification_queued.connect(func(data): _notices.append(str(data.get("text", ""))))

	var map := _build_map()
	MapManager.push_map(map)
	await _frames(5)
	_check(GameState.map.current_location == &"t_a", "entered test map at t_a")
	_check(not GameState.map.is_unlocked(&"t_g"), "t_g locked while its flag is false")

	# --- 33: VISIT counted once on first arrival
	var vobj := QuestObjective.new()
	vobj.objective_id = &"visit_b"
	vobj.objective_type = QuestObjective.ObjectiveType.VISIT
	vobj.target_id = &"t_b"
	vobj.required_count = 5
	var q := QuestDefinition.new()
	q.quest_id = &"test_visit_once"
	var objs: Array[QuestObjective] = [vobj]
	q.objectives = objs
	q.rewards = QuestRewards.new()
	QuestManager.register_definition(q)
	QuestManager.make_quest_available(q.quest_id)
	QuestManager.try_accept_quest(q.quest_id)

	# --- 32: pass-through arrivals. Multi-hop travel runs through unlocked
	# nodes; unlock B-D ahead of time the way a quest reward would.
	for id in [&"t_b", &"t_c", &"t_d"]:
		GameState.map.unlock(id)
	var travelled: Array[StringName] = MapManager.travel_along_path(&"t_d")
	await _frames(3)
	_check(travelled == [&"t_a", &"t_b", &"t_c", &"t_d"], "travelled A->B->C->D (%s)" % [travelled])
	_check(GameState.map.has_visited(&"t_b") and GameState.map.has_visited(&"t_c"), "passed-through nodes B and C got arrival handling")
	_check(GameState.map.current_location == &"t_d", "ended at D")
	_check(GameState.quests.get_objective_progress(q.quest_id, &"visit_b") == 1, "VISIT counted once (got %d)" % GameState.quests.get_objective_progress(q.quest_id, &"visit_b"))

	# --- 32: stop early at an unvisited node with an arrival scene
	var back: Array[StringName] = MapManager.travel_along_path(&"t_a")
	await _frames(3)
	var map2 := _build_map()
	map2.map_id = &"test_map_systems_2"
	for n in map2.location_nodes:
		n.location_id = StringName(String(n.location_id) + "2")
		var links: Array[StringName] = []
		for l in n.connections:
			links.append(StringName(String(l) + "2"))
		n.connections = links
	map2.starting_location_id = &"t_a2"
	map2.location_nodes[2].first_visit_dialogue = StringName(ARRIVAL_SCENE)  # t_c2
	MapManager.push_map(map2)
	await _frames(3)
	for id in [&"t_b2", &"t_c2", &"t_d2"]:
		GameState.map.unlock(id)
	var stopped: Array[StringName] = MapManager.travel_along_path(&"t_d2")
	await _frames(5)
	_check(stopped.back() == &"t_c2", "travel stopped at t_c2, which has an arrival scene (%s)" % [stopped])
	_check(DialogueManager.is_active, "the arrival scene is playing")
	DialogueManager.skip_dialogue()
	await _frames(3)
	MapManager.pop_map()
	await _frames(3)

	# --- 30: live unlock (neighbour visited) and live reveal
	GameState.set_flag(&"lighthouse_lit", true)
	await _frames(3)
	_check(GameState.map.is_unlocked(&"t_g"), "t_g unlocked live when its flag turned true")
	_check(not MapManager.check_location_visibility(&"t_f"), "t_f hidden before its flag")
	GameState.set_flag(&"boss_tutorial_defeated", true)
	await _frames(3)
	_check(GameState.map.is_revealed(&"t_f"), "t_f revealed live when its flag turned true")

	# --- 31: tapping a locked node shows its hint
	var map_scene: Node = root_scene.find_child("MapScene", true, false)
	var loc_l: LocationNode = MapManager.get_location(&"t_l")
	_notices.clear()
	map_scene._on_node_pressed(loc_l, Vector2.ZERO)
	await _frames(2)
	_check(_notices.has("Closed for repairs."), "locked node showed its hint (%s)" % [_notices])

	# --- 30: paths to hidden nodes aren't drawn (fresh map, flags reset)
	GameState.set_flag(&"boss_tutorial_defeated", false)
	var map3 := _build_map()
	map3.map_id = &"test_map_systems_3"
	for n in map3.location_nodes:
		n.location_id = StringName(String(n.location_id) + "3")
		var links3: Array[StringName] = []
		for l in n.connections:
			links3.append(StringName(String(l) + "3"))
		n.connections = links3
	map3.starting_location_id = &"t_a3"
	MapManager.push_map(map3)
	await _frames(5)
	var f3: LocationNode = MapManager.get_location(&"t_f3")
	var drawn_to_f := false
	for seg in map_scene._paths_drawer.path_segments:
		if seg.get("b") == f3.map_position + map_scene.NODE_CENTER_OFFSET or seg.get("a") == f3.map_position + map_scene.NODE_CENTER_OFFSET:
			drawn_to_f = true
	_check(not drawn_to_f, "no path drawn to the hidden node")

	await _test_donation_rest(root_scene)
	_finish()


func _test_donation_rest(root_scene: Node) -> void:
	print("-- donation rest (shell-houses)")
	var radial: Node = root_scene.find_child("MapRadialMenu", true, false)
	if radial == null:
		for n in root_scene.find_children("*", "", true, false):
			if n.has_method("_take_rest_donation"):
				radial = n
				break
	_check(radial != null, "found the map radial menu")
	if radial == null:
		return
	var player = GameManager.player
	radial._player = player
	var shell := LocationNode.new()
	shell.location_id = &"t_shell_house"
	radial._current_location = shell
	var btn := MapNodeButtonDef.new()
	btn.button_category = MapNodeButtonDef.ButtonCategory.REST
	btn.rest_is_donation = true
	btn.rest_cost_gold = 10
	btn.rest_heal_percent = 1.0
	var donated_before: int = GameState.get_counter(&"gold_donated")

	player.gold = 3
	player.current_hp = 1
	radial._handle_rest(btn)
	_check(player.gold == 0 and player.current_hp == player.max_hp, "gave what they had (3) and rested")
	_check(GameState.get_counter(&"gold_donated") == donated_before + 3, "gold_donated counted the donation")

	player.current_hp = 1
	radial._handle_rest(btn)
	_check(player.current_hp == player.max_hp, "broke: rested free, once")

	player.current_hp = 1
	_notices.clear()
	radial._handle_rest(btn)
	_check(player.current_hp == 1 and _notices.size() > 0, "broke again at the same shell-house: refused, with a notice")

	player.gold = 25
	radial._handle_rest(btn)
	_check(player.gold == 15 and player.current_hp == player.max_hp, "with gold: gives the suggested 10")

	var other := LocationNode.new()
	other.location_id = &"t_other_shell_house"
	radial._current_location = other
	player.gold = 0
	player.current_hp = 1
	radial._handle_rest(btn)
	_check(player.current_hp == player.max_hp, "a different shell-house gives its own free rest")

	var paid := MapNodeButtonDef.new()
	paid.button_category = MapNodeButtonDef.ButtonCategory.REST
	paid.rest_cost_gold = 10
	paid.rest_heal_percent = 1.0
	player.current_hp = 1
	_notices.clear()
	radial._handle_rest(paid)
	_check(player.current_hp == 1 and _notices.size() > 0, "fixed-price rest without gold says why")


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("map_systems_test: ALL PASSED")
		get_tree().quit(0)
	else:
		print("map_systems_test: %d FAILED" % _failures.size())
		for f in _failures:
			print("   - " + f)
		get_tree().quit(1)
