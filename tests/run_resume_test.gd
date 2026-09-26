# res://tests/run_resume_test.gd
# Headless two-step test: a dungeon run survives closing the app.
#   1) godot --headless --path . res://tests/run_resume_test.tscn -- start
#      New game, enter the Navy dungeon, clear two nodes, pick up a shrine
#      affix and some gold, then quit (the run is autosaved between nodes).
#   2) godot --headless --path . res://tests/run_resume_test.tscn -- continue
#      Continue: the run is back, same map, same place, same run loot; dying
#      then clears the saved run.
# WRITES user://save.tres and user://_run_resume_expect.json. Back up your save.
extends Node

const NAVY := "res://resources/dungeon/sanctum_navy.tres"
const EXPECT := "user://_run_resume_expect.json"

var _failures: Array[String] = []
var _root: Node = null
var _mode := "start"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	_root = load("res://scenes/game/game_root.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_root)
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + what)
	if not cond:
		_failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	await _frames(10)
	var title: Node = _root.find_child("TitleScreen", true, false)
	if _mode == "start":
		if title:
			title.new_game_confirmed.emit()
	else:
		if title:
			title.continue_requested.emit()
	await _frames(40)
	if _mode == "start":
		await _start()
	else:
		await _continue()
	_finish()


func _start() -> void:
	var p = GameManager.player
	_root.enter_dungeon(load(NAVY))
	await _frames(40)
	var ds = _root.dungeon_scene
	var run: DungeonRun = ds.current_run
	_check(run != null, "entered the dungeon")
	if run == null:
		return
	# Close any entry popup (run affix offer) by skipping it
	if ds._awaiting_affix_choice:
		ds._on_popup_closed({"type": "run_affix", "skipped": true, "trigger": "entry"})
		if ds.run_affix_popup:
			ds.run_affix_popup.hide()  # a real tap closes the popup itself
		await _frames(5)
	# Clear two nodes along the path
	for step in 2:
		var avail: Array = run.get_available_nodes()
		if avail.is_empty():
			break
		var n: DungeonNodeData = avail[0]
		run.visit_node(n.id)
		ds._complete_and_advance(n)
		await _frames(3)
	# Run loot: gold and a shrine stat affix
	p.add_gold(33)
	run.track_gold(33)
	var shrine_aff := Affix.new()
	shrine_aff.affix_name = "Test Shrine Blessing"
	shrine_aff.category = Affix.Category.STRENGTH_BONUS
	shrine_aff.effect_number = 7.0
	shrine_aff.source_type = "shrine"
	p.affix_manager.add_affix(shrine_aff)
	run.track_shrine_affix(shrine_aff)
	_check(ds.is_at_safe_point() and _root.can_autosave(), "between nodes counts as a safe point")
	GameState.request_autosave()
	GameState.flush_pending_autosave()
	await _frames(5)
	var saved = load("user://save.tres")
	_check(saved != null and not saved.dungeon_run_state.is_empty(), "the save holds the run in progress")
	var completed := 0
	for n in run.nodes.values():
		if n.completed:
			completed += 1
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"node": run.current_node_id, "floor": run.current_floor, "nodes": run.nodes.size(),
		"completed": completed, "gold_earned": run.gold_earned, "gold": p.gold,
		"str": p.get_total_stat("strength"),
	}))
	f.close()
	GameState.session_active = false   # "close the app" without leaving the run


func _continue() -> void:
	var p = GameManager.player
	var f := FileAccess.open(EXPECT, FileAccess.READ)
	_check(f != null, "found the first step's expectations")
	if f == null:
		return
	var ex: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var ds = _root.dungeon_scene
	var run: DungeonRun = ds.current_run
	_check(_root.is_in_dungeon and run != null, "Continue put the player back in the dungeon")
	if run == null:
		return
	_check(run.current_node_id == int(ex.node) and run.current_floor == int(ex.floor), "same place in the run (node %d, floor %d)" % [run.current_node_id, run.current_floor])
	var completed := 0
	for n in run.nodes.values():
		if n.completed:
			completed += 1
	_check(run.nodes.size() == int(ex.nodes) and completed == int(ex.completed), "same map and progress (%d nodes, %d done)" % [run.nodes.size(), completed])
	_check(run.gold_earned == int(ex.gold_earned) and p.gold == int(ex.gold), "run gold kept track of (%d earned, gold %d)" % [run.gold_earned, p.gold])
	_check(p.get_total_stat("strength") == int(ex.str), "shrine stat affix re-applied (STR %d)" % p.get_total_stat("strength"))
	_check(run.get_available_nodes().size() > 0, "next doors are open")
	var combat_nodes := 0
	for n in run.nodes.values():
		if n.node_type in [DungeonEnums.NodeType.COMBAT, DungeonEnums.NodeType.ELITE, DungeonEnums.NodeType.BOSS] and n.encounter != null:
			combat_nodes += 1
	_check(combat_nodes > 0, "fights restored with their encounters")
	# Dying ends the run and clears it from the save
	ds._on_player_died()
	await _frames(10)
	GameState.flush_pending_autosave()
	GameState.request_autosave()
	await _frames(5)
	var saved = load("user://save.tres")
	_check(not _root.is_in_dungeon and saved.dungeon_run_state.is_empty(), "after the run ends, the save holds no run")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EXPECT))


func _finish() -> void:
	if _mode != "start":
		GameState.session_active = false
	if _failures.is_empty():
		print("run_resume_test: ALL PASSED (%s)" % _mode)
		get_tree().quit(0)
	else:
		print("run_resume_test: %d FAILED (%s)" % [_failures.size(), _mode])
		for fl in _failures:
			print("   - " + fl)
		get_tree().quit(1)
