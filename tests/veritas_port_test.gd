# res://tests/veritas_port_test.gd
# Headless walk-through of the Veritas Port map (content/veritas-port):
# new game lands on the Docks, the city unfolds on its story flags, every
# resident is homed where the map plan says, and the ferry reaches Bastion Rock.
# WRITES user://save.tres (autosave). Back up your save first.
#
#   godot --headless --path . res://tests/veritas_port_test.tscn
extends Node

const RESIDENTS := {
	&"loc_vp_docks": [&"teague"],
	&"loc_vp_margerys_stall": [&"margery"],
	&"loc_vp_salted_keel": [&"brogan", &"fjona", &"hask", &"rudo"],
	&"loc_vp_imbrys_practice": [&"imbry", &"clea"],
	&"loc_vp_dry_dock_row": [&"sprock"],
	&"loc_vp_government": [&"yara", &"duskhollow", &"samira"],
	&"loc_vp_customs_house": [&"fenwick", &"grint"],
	&"loc_vp_mercantile": [&"wicket", &"ysolde"],
	&"loc_vp_ferry_terminal": [],
	&"loc_vp_bastion_rock": [&"cedryc", &"hollis", &"rafe", &"posy"],
}

var _failures: Array[String] = []


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


func _go(location_id: StringName) -> void:
	MapManager.travel_along_path(location_id)
	await _frames(3)


func _run(root_scene: Node) -> void:
	await _frames(10)
	var title: Node = root_scene.find_child("TitleScreen", true, false)
	if title:
		title.new_game_confirmed.emit()
	await _frames(30)

	# --- new game lands on the Docks, inside the Veritas Port zone
	_check(MapManager.get_map_depth() == 2, "inside a zone (depth %d)" % MapManager.get_map_depth())
	var top: MapDefinition = MapManager.get_current_map()
	_check(top != null and top.map_id == &"veritas_port_map", "current map is veritas_port_map")
	_check(GameState.map.current_location == &"loc_vp_docks", "new game starts on the Docks (%s)" % GameState.map.current_location)

	# --- residents
	for loc_id in RESIDENTS:
		var got: Array = NPCManager.get_npcs_at_location(loc_id).map(func(n): return n.npc_id)
		var want: Array = RESIDENTS[loc_id]
		var ok := got.size() == want.size()
		for id in want:
			ok = ok and got.has(id)
		_check(ok, "%s homes %s (got %s)" % [loc_id, want, got])
	for loc_id in RESIDENTS:
		for id in RESIDENTS[loc_id]:
			var npc = NPCManager.get_npc(id)
			_check(npc != null and NPCManager.get_active_encounter(npc) != null, "%s has a conversation to open" % id)

	# --- opening state
	_check(GameState.map.is_unlocked(&"loc_vp_government"), "Government District open from the start")
	for id in [&"loc_vp_margerys_stall", &"loc_vp_salted_keel", &"loc_vp_imbrys_practice",
			&"loc_vp_dry_dock_row", &"loc_vp_ferry_terminal"]:
		_check(not GameState.map.is_unlocked(id), "%s locked at the start" % id)
	_check(MapManager.check_location_visibility(&"loc_vp_imbrys_practice"), "Imbry's practice visible from the start")

	await _go(&"loc_vp_government")
	_check(GameState.map.current_location == &"loc_vp_government", "walked to the Government District")
	_check(GameState.map.is_unlocked(&"loc_vp_customs_house"), "Customs House open once the district is reached")
	_check(not GameState.map.is_unlocked(&"loc_vp_mercantile"), "Mercantile locked before Off the Boat")
	await _go(&"loc_vp_customs_house")
	_check(GameState.map.current_location == &"loc_vp_customs_house", "walked to the Customs House")
	await _go(&"loc_vp_docks")

	# --- the city unfolds on its flags
	for step in [[&"arrived_veritas_port", &"loc_vp_margerys_stall"],
			[&"met_margery", &"loc_vp_salted_keel"],
			[&"keel_brawl_done", &"loc_vp_imbrys_practice"]]:
		GameState.set_flag(step[0], true)
		await _frames(3)
		_check(GameState.map.is_unlocked(step[1]), "%s unlocks on %s" % [step[1], step[0]])
		await _go(step[1])
		_check(GameState.map.current_location == step[1], "walked to %s" % step[1])
		await _go(&"loc_vp_docks")

	GameState.set_flag(&"off_the_boat_done", true)
	await _frames(3)
	for id in [&"loc_vp_dry_dock_row", &"loc_vp_ferry_terminal"]:
		_check(GameState.map.is_unlocked(id), "%s unlocks after Off the Boat" % id)
	await _go(&"loc_vp_government")
	_check(GameState.map.is_unlocked(&"loc_vp_mercantile"), "Mercantile unlocks after Off the Boat")
	await _go(&"loc_vp_docks")
	await _go(&"loc_vp_ferry_terminal")
	_check(GameState.map.is_unlocked(&"loc_vp_bastion_rock"), "Bastion Rock reachable from the Ferry Terminal")
	await _go(&"loc_vp_bastion_rock")
	_check(GameState.map.current_location == &"loc_vp_bastion_rock", "took the ferry to Bastion Rock")

	# --- Sprock's placeholder opens smithing
	var sprock = NPCManager.get_npc(&"sprock")
	var line: DialogueLine = NPCManager.get_active_encounter(sprock).encounter.first_line
	_check(line.choices.size() == 2 and line.choices[0].next_line.event_tag.begins_with("game_action:7:"),
		"Sprock's conversation has the smithing action")

	# --- the zone and position survive a save
	GameState.request_autosave()
	GameState.flush_pending_autosave()
	var saved = load("user://save.tres")
	_check(saved != null and saved.map_stack.size() == 2, "save records the zone stack")

	_finish()


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("veritas_port_test: ALL PASSED")
		get_tree().quit(0)
	else:
		print("veritas_port_test: %d FAILED" % _failures.size())
		for f in _failures:
			print("   - " + f)
		get_tree().quit(1)
