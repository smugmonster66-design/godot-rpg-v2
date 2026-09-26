# res://tests/fight_resume_test.gd
# Headless two-step test: a fight survives closing the app.
#   godot --headless --path . res://tests/fight_resume_test.tscn -- start_dungeon
#   godot --headless --path . res://tests/fight_resume_test.tscn -- continue
#   godot --headless --path . res://tests/fight_resume_test.tscn -- start_field
#   godot --headless --path . res://tests/fight_resume_test.tscn -- continue
# The start step gets to the player's turn in a fight, hurts an enemy, adds
# statuses, saves at the turn's save point and quits. Continue must put the
# same fight back. WRITES user://save.tres. Back up your save.
extends Node

const NAVY := "res://resources/dungeon/sanctum_navy.tres"
const FIELD_FIGHT := "res://resources/encounters/baseline/trash/brute_skirmisher.tres"
const EXPECT := "user://_fight_resume_expect.json"

var _failures: Array[String] = []
var _root: Node = null
var _mode := "start_dungeon"


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


func _cm():
	return _root.get_combat_manager()


func _wait_for_player_turn(max_frames: int = 600) -> bool:
	for i in max_frames:
		var cm = _cm()
		if cm and _root.is_in_combat and cm.combat_state == cm.CombatState.PLAYER_TURN and cm.turn_phase == cm.TurnPhase.PREP:
			return true
		await get_tree().process_frame
	return false


func _run() -> void:
	await _frames(10)
	var title: Node = _root.find_child("TitleScreen", true, false)
	if _mode == "continue":
		if title:
			title.continue_requested.emit()
	else:
		if title:
			title.new_game_confirmed.emit()
	await _frames(40)
	match _mode:
		"start_dungeon": await _start(true)
		"start_field": await _start(false)
		_: await _continue()
	_finish()


func _start(in_dungeon: bool) -> void:
	if in_dungeon:
		_root.enter_dungeon(load(NAVY))
		await _frames(40)
		var ds = _root.dungeon_scene
		if ds._awaiting_affix_choice:
			ds._on_popup_closed({"type": "run_affix", "skipped": true, "trigger": "entry"})
			if ds.run_affix_popup:
				ds.run_affix_popup.hide()
			await _frames(5)
		var fight: DungeonNodeData = null
		for n in ds.current_run.get_available_nodes():
			if n.node_type == DungeonEnums.NodeType.COMBAT and n.encounter:
				fight = n
		if fight == null:
			# make the first door a fight so the test is deterministic
			fight = ds.current_run.get_available_nodes()[0]
			fight.node_type = DungeonEnums.NodeType.COMBAT
			fight.encounter = ds.current_run.definition.combat_encounters[0]
		ds._enter_node(fight.id)
	else:
		var enc: CombatEncounter = load(FIELD_FIGHT)
		GameManager.pending_encounter = enc
		_root.start_combat(enc)
	var ok: bool = await _wait_for_player_turn()
	_check(ok, "reached the player's turn in the fight")
	if not ok:
		return
	var cm = _cm()
	# Change the fight so a restore has something to prove
	var e0: Combatant = cm.enemy_combatants[0]
	e0.current_health = maxi(1, e0.current_health - 3)
	var burn: StatusAffix = load("res://resources/statuses/burn.tres")
	cm._get_status_tracker(e0).apply_status(burn, 3, "test")
	var p = GameManager.player
	p.current_hp = maxi(1, p.current_hp - 7)
	var fort: StatusAffix = load("res://resources/statuses/fortified.tres")
	p.status_tracker.apply_status(fort, 2, "test")
	cm._turn_save_point = true
	GameState.save_now_if_allowed()
	cm._turn_save_point = false
	var saved = load("user://save.tres")
	_check(saved != null and not saved.combat_state.is_empty(), "the save holds the fight")
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"dungeon": in_dungeon, "round": cm.current_round, "enemies": cm.enemy_combatants.size(),
		"e0_hp": e0.current_health, "e0_max": e0.max_health, "burn": cm._get_status_tracker(e0).get_stacks("burn"),
		"p_hp": p.current_hp, "fortified": p.status_tracker.get_stacks("fortified"),
	}))
	f.close()
	GameState.session_active = false   # close the app mid-fight


func _continue() -> void:
	var f := FileAccess.open(EXPECT, FileAccess.READ)
	_check(f != null, "found the start step's expectations")
	if f == null:
		return
	var ex: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var ok: bool = await _wait_for_player_turn()
	_check(ok, "Continue put the player back in the fight, on their turn")
	if not ok:
		return
	var cm = _cm()
	var p = GameManager.player
	_check(_root.is_in_dungeon == bool(ex.dungeon), "same place (%s)" % ("dungeon" if ex.dungeon else "field"))
	_check(cm.current_round == int(ex.round), "same round (%d)" % cm.current_round)
	_check(cm.enemy_combatants.size() == int(ex.enemies), "same enemies (%d)" % cm.enemy_combatants.size())
	var e0: Combatant = cm.enemy_combatants[0]
	_check(e0.max_health == int(ex.e0_max), "enemy max HP kept (%d)" % e0.max_health)
	# the turn start replays once (burn ticks at end of turn, so HP is as saved)
	_check(e0.current_health <= int(ex.e0_hp) and e0.current_health >= int(ex.e0_hp) - 3, "enemy HP restored (%d, saved %d)" % [e0.current_health, int(ex.e0_hp)])
	_check(cm._get_status_tracker(e0).get_stacks("burn") > 0, "enemy statuses restored (burn %d)" % cm._get_status_tracker(e0).get_stacks("burn"))
	_check(abs(p.current_hp - int(ex.p_hp)) <= 5, "player HP restored (%d, saved %d)" % [p.current_hp, int(ex.p_hp)])
	if bool(ex.dungeon):
		var run: DungeonRun = _root.dungeon_scene.current_run
		var node: DungeonNodeData = run.get_node(run.current_node_id)
		_check(node != null and not node.completed and _root.dungeon_scene._awaiting_combat, "the dungeon node is still being fought")
	# Finish the fight: the save no longer holds it
	_root.end_combat(true)
	await _frames(20)
	if _root.dungeon_scene and _root.post_combat_summary and _root.post_combat_summary.visible:
		_root._on_summary_closed()
	GameState.flush_pending_autosave()
	GameState.request_autosave()
	await _frames(10)
	var saved = load("user://save.tres")
	_check(saved.combat_state.is_empty(), "after the fight, the save holds no fight")
	if bool(ex.dungeon):
		var run2: DungeonRun = _root.dungeon_scene.current_run
		_check(run2 != null and run2.get_node(run2.current_node_id).completed, "the fought node is now completed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EXPECT))


func _finish() -> void:
	if _mode == "continue":
		GameState.session_active = false
	if _failures.is_empty():
		print("fight_resume_test: ALL PASSED (%s)" % _mode)
		get_tree().quit(0)
	else:
		print("fight_resume_test: %d FAILED (%s)" % [_failures.size(), _mode])
		for fl in _failures:
			print("   - " + fl)
		get_tree().quit(1)
