# res://tests/story_systems_test.gd
# Headless test of the story-plumbing engine fixes (engine/story-gaps, Phase 2).
# Boots GameRoot, starts a NEW game, then exercises each fix with resources
# built in code. WRITES user://save.tres (autosave). Back up your save first.
#
#   godot --headless --path . res://tests/story_systems_test.tscn
#
# Exit code 0 = pass, 1 = fail.
extends Node

const TONIC := "res://resources/consumables/region_1/restoratives/sanctum_tonic.tres"

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


func _run(root_scene: Node) -> void:
	await _frames(10)
	var title: Node = root_scene.find_child("TitleScreen", true, false)
	if title:
		title.new_game_confirmed.emit()
	await _frames(30)
	_check(GameManager.player != null, "new game has a player")

	await _test_line_and_encounter_flags()
	await _test_grant_and_heal_actions()
	_test_counter_compare()
	_test_fight_result_conditions()
	await _test_deliver_on_talk()
	_test_quest_failure()
	_test_repeatable()
	_test_stable_tie_order()
	await _test_oneshot_skip()
	_finish()


# ---------------------------------------------------------------------------

func _line(text: String) -> DialogueLine:
	var l := DialogueLine.new()
	l.text = text
	return l


func _encounter(first: DialogueLine, id: StringName = &"test_enc") -> DialogueEncounter:
	var e := DialogueEncounter.new()
	e.encounter_id = id
	e.first_line = first
	return e


func _end_current_dialogue() -> void:
	# Walk to the end: advance until the manager is idle.
	for i in 20:
		if not DialogueManager.is_active:
			return
		DialogueManager.advance()
		await get_tree().process_frame


func _test_line_and_encounter_flags() -> void:
	print("-- gap 8: line and encounter flags")
	var line := _line("Hello.")
	line.set_flags = [&"tutorial_dice_complete"]
	var enc := _encounter(line)
	enc.set_flags_on_start = [&"tutorial_combat_complete"]
	enc.set_flags_on_end = [&"tutorial_skills_complete"]
	DialogueManager.start_dialogue(enc)
	await _end_current_dialogue()
	_check(GameState.get_flag(&"tutorial_combat_complete"), "encounter start flag set")
	_check(GameState.get_flag(&"tutorial_dice_complete"), "line flag set")
	_check(GameState.get_flag(&"tutorial_skills_complete"), "encounter end flag set")


func _consumable_count(item_name: String) -> int:
	var n := 0
	for c in GameManager.player.consumables:
		if c and c.item_name == item_name:
			n += c.current_stack
	return n


func _test_grant_and_heal_actions() -> void:
	print("-- gaps 3 and 43: GRANT_ITEM and HEAL dialogue actions")
	var tonic: ConsumableItem = load(TONIC)
	var before := _consumable_count(tonic.item_name)
	var grant := _line("")
	grant.event_tag = StringName("game_action:8:%s:2" % TONIC)
	var heal := _line("")
	heal.event_tag = &"game_action:9:50%"
	grant.next_line = heal
	heal.next_line = _line("Done.")
	GameManager.player.current_hp = 1
	DialogueManager.start_dialogue(_encounter(grant, &"grant_test"))
	await _end_current_dialogue()
	_check(_consumable_count(tonic.item_name) == before + 2,
		"GRANT_ITEM gave 2 %s (had %d, now %d)" % [tonic.item_name, before, _consumable_count(tonic.item_name)])
	_check(GameManager.player.current_hp > 1, "HEAL restored HP (now %d)" % GameManager.player.current_hp)


func _test_counter_compare() -> void:
	print("-- gap 42: compare two counters")
	GameState.set_counter(&"test_a", 5)
	GameState.set_counter(&"test_b", 3)
	var sc := SingleCheck.new()
	sc.check_type = SingleCheck.CheckType.COUNTER
	sc.key = &"test_a"
	sc.compare_counter = &"test_b"
	sc.compare_operator = ">"
	var cond := GameCondition.new()
	cond.condition_type = GameCondition.ConditionType.SINGLE
	cond.single_check = sc
	_check(GameState.evaluate_condition(cond), "test_a (5) > test_b (3)")
	sc.compare_operator = "<"
	_check(not GameState.evaluate_condition(cond), "test_a (5) < test_b (3) is false")


func _custom(key: String) -> GameCondition:
	var sc := SingleCheck.new()
	sc.check_type = SingleCheck.CheckType.CUSTOM
	sc.key = StringName(key)
	var cond := GameCondition.new()
	cond.condition_type = GameCondition.ConditionType.SINGLE
	cond.single_check = sc
	return cond


func _test_fight_result_conditions() -> void:
	print("-- gap 7: branch on the last fight / dungeon")
	GameState.last_combat_won = true
	_check(GameState.evaluate_condition(_custom("last_combat_won")), "last_combat_won after a win")
	GameState.last_combat_won = false
	_check(GameState.evaluate_condition(_custom("last_combat_lost")), "last_combat_lost after a loss")
	GameState.last_dungeon_cleared = true
	_check(GameState.evaluate_condition(_custom("last_dungeon_cleared")), "last_dungeon_cleared")


func _quest(id: StringName, objectives: Array) -> QuestDefinition:
	var q := QuestDefinition.new()
	q.quest_id = id
	q.display_name = String(id)
	var typed: Array[QuestObjective] = []
	for o in objectives:
		typed.append(o)
	q.objectives = typed
	q.rewards = QuestRewards.new()
	QuestManager.register_definition(q)
	return q


func _test_deliver_on_talk() -> void:
	print("-- gap 11: DELIVER on talking to the recipient")
	var tonic: ConsumableItem = load(TONIC)
	ItemGrant.grant(tonic, 1)
	var obj := QuestObjective.new()
	obj.objective_id = &"deliver_tonic"
	obj.objective_type = QuestObjective.ObjectiveType.DELIVER
	obj.target_id = &"test_recipient"
	obj.track_tag = StringName(tonic.item_name)
	_quest(&"test_deliver", [obj])
	QuestManager.make_quest_available(&"test_deliver")
	QuestManager.try_accept_quest(&"test_deliver")
	var before := _consumable_count(tonic.item_name)
	QuestManager.report_talk_to(&"test_recipient")
	_check(GameState.quests.is_objective_complete(&"test_deliver", &"deliver_tonic"), "DELIVER objective complete")
	_check(_consumable_count(tonic.item_name) == before - 1, "delivered item was taken")


func _test_quest_failure() -> void:
	print("-- gap 12: quest failure")
	var obj := QuestObjective.new()
	obj.objective_id = &"never"
	obj.objective_type = QuestObjective.ObjectiveType.CUSTOM
	obj.target_id = &"never_happens"
	var q := _quest(&"test_fail", [obj])
	q.can_fail = true
	var sc := SingleCheck.new()
	sc.check_type = SingleCheck.CheckType.FLAG
	sc.key = &"bridge_repaired"
	q.fail_condition = GameCondition.new()
	q.fail_condition.condition_type = GameCondition.ConditionType.SINGLE
	q.fail_condition.single_check = sc
	QuestManager.make_quest_available(&"test_fail")
	QuestManager.try_accept_quest(&"test_fail")
	_check(GameState.quests.is_active(&"test_fail"), "fail-test quest active")
	GameState.set_flag(&"bridge_repaired", true)
	_check(GameState.quests.get_state(&"test_fail") == QuestProgress.QuestState.FAILED, "quest failed when its fail_condition became true")


func _test_repeatable() -> void:
	print("-- gap 12: repeatable quests")
	var q := _quest(&"test_repeat", [])
	q.repeatable = true
	q.repeat_cooldown = 0.0
	QuestManager.make_quest_available(&"test_repeat")
	QuestManager.try_accept_quest(&"test_repeat")
	QuestManager.try_complete_quest(&"test_repeat")
	_check(GameState.quests.is_complete(&"test_repeat"), "repeatable quest completed")
	QuestManager._check_repeats()
	_check(GameState.quests.is_available(&"test_repeat"), "repeatable quest available again after cooldown")


func _npc_with_ties() -> NPCDefinition:
	var npc := NPCDefinition.new()
	npc.npc_id = &"test_npc"
	var table: Array[NPCDialogueEntry] = []
	for id in [&"first", &"second", &"third"]:
		var e := NPCDialogueEntry.new()
		e.encounter_id = id
		e.priority = 10
		e.encounter = _encounter(_line("Hi."), id)
		table.append(e)
	npc.dialogue_table = table
	return npc


func _test_stable_tie_order() -> void:
	print("-- gap 20: stable order for tied conversations")
	var npc := _npc_with_ties()
	var stable := true
	for i in 30:
		var entries = NPCManager.get_active_encounters(npc)
		var ids: Array = entries.map(func(e): return e.encounter_id)
		if ids != [&"first", &"second", &"third"]:
			stable = false
			break
	_check(stable, "tied entries always come out in table order")


func _test_oneshot_skip() -> void:
	print("-- gap 19: skipping doesn't use up a one-shot")
	var npc := _npc_with_ties()
	var entry: NPCDialogueEntry = npc.dialogue_table[0]
	entry.one_shot = true
	entry.encounter.skippable = true
	NPCManager.begin_npc_encounter(npc.npc_id, entry)
	DialogueManager.skip_dialogue()
	await _frames(2)
	_check(not NPCManager._is_encounter_seen(npc.npc_id, entry.encounter_id), "skipped one-shot not marked seen")
	NPCManager.begin_npc_encounter(npc.npc_id, entry)
	await _end_current_dialogue()
	await _frames(2)
	_check(NPCManager._is_encounter_seen(npc.npc_id, entry.encounter_id), "finished one-shot marked seen")


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("story_systems_test: ALL PASSED")
		get_tree().quit(0)
	else:
		print("story_systems_test: %d FAILED" % _failures.size())
		for f in _failures:
			print("   - " + f)
		get_tree().quit(1)
