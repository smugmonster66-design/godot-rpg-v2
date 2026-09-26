# res://tests/defeat_and_runs_test.gd
# Headless test of losing and dungeon runs (engine/defeat-and-runs):
# the shellkeepers' rescue, run-loss rules, ways out, depth scaling,
# first-clear recording. WRITES user://save.tres. Back up your save first.
#
#   godot --headless --path . res://tests/defeat_and_runs_test.tscn
extends Node

const NAVY := "res://resources/dungeon/sanctum_navy.tres"
const BRUTE := "res://resources/enemies/baseline/trash/brute.tres"
const TONIC := "res://resources/consumables/region_1/restoratives/sanctum_tonic.tres"

var _failures: Array[String] = []
var _root: Node = null


func _ready() -> void:
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


func _encounter() -> CombatEncounter:
	var enc := CombatEncounter.new()
	enc.encounter_id = "test_defeat"
	var enemies: Array[EnemyData] = [load(BRUTE)]
	enc.enemies = enemies
	return enc


func _count(item_name: String) -> int:
	var n := 0
	for c in GameManager.player.consumables:
		if c and c.item_name == item_name:
			n += c.current_stack
	return n


func _run() -> void:
	await _frames(10)
	var title: Node = _root.find_child("TitleScreen", true, false)
	if title:
		title.new_game_confirmed.emit()
	await _frames(30)
	var p = GameManager.player
	_check(not GameState.last_dungeon_failed, "no dungeon has 'failed' before any run")

	# --- never rested: a loss wakes you at Imbry's practice
	GameState.set_flag(&"arrived_veritas_port", true)
	GameState.set_flag(&"met_margery", true)
	GameState.set_flag(&"keel_brawl_done", true)
	await _frames(3)
	p.gold = 100
	_root.start_combat(_encounter())
	await _frames(60)
	p.current_hp = 0
	_root.end_combat(false)
	await _frames(10)
	_check(GameState.map.current_location == &"loc_vp_imbrys_practice", "never rested: woke at Imbry's practice (%s)" % GameState.map.current_location)
	_check(p.current_hp == p.max_hp, "rescued at full HP")
	_check(p.gold == 88, "donated 12%% of carried gold (100 -> %d)" % p.gold)
	_check(GameState.get_counter(&"times_rescued") == 1, "rescue counted")

	# --- rest somewhere, get beaten elsewhere: wake at the last rest
	GameState.set_last_rest(MapManager.get_stack_snapshot(), &"loc_vp_imbrys_practice")
	MapManager.travel_along_path(&"loc_vp_government")
	await _frames(3)
	_check(GameState.map.current_location == &"loc_vp_government", "walked away from the rest")
	p.gold = 0
	_root.start_combat(_encounter())
	await _frames(60)
	_root.end_combat(false)
	await _frames(10)
	_check(GameState.map.current_location == &"loc_vp_imbrys_practice", "woke at the last rest")
	_check(p.gold == 0 and p.current_hp == p.max_hp, "broke: rescued for free, full HP")

	# --- a story fight's loss: the scene decides, but never 0 HP
	var line := DialogueLine.new()
	line.event_tag = &"game_action:0:res://resources/encounters/baseline/trash/brute_skirmisher.tres"
	var after := DialogueLine.new()
	after.text = "After."
	line.next_line = after
	var denc := DialogueEncounter.new()
	denc.encounter_id = &"test_story_fight"
	denc.first_line = line
	var here: StringName = GameState.map.current_location
	DialogueManager.start_dialogue(denc)
	await _frames(60)
	p.current_hp = 0
	_root.end_combat(false)
	await _frames(10)
	_check(p.current_hp >= 1 and GameState.map.current_location == here, "story-fight loss: HP >= 1, no rescue move")
	DialogueManager.skip_dialogue()
	await _frames(3)

	# --- dungeon death: run loot lost, own spending not refunded, XP kept, free rescue
	var def: DungeonDefinition = load(NAVY)
	p.gold = 50
	_root.enter_dungeon(def)
	await _frames(20)
	var ds = _root.dungeon_scene
	var run: DungeonRun = ds.current_run
	_check(run != null and _root.is_in_dungeon, "entered the Navy dungeon")
	p.add_gold(40)
	run.track_gold(40)            # earned 40 in the run (gold 90)
	p.gold -= 60                  # spent 60 in the shop (gold 30): 40 run gold + 20 of their own
	var tonic: ConsumableItem = load(TONIC).duplicate()
	var tonics_before := _count(tonic.item_name)
	p.add_consumable(tonic)
	run.track_consumable(tonic)
	var xp_before: int = p.active_class.experience
	p.add_experience(10)
	run.track_exp(10)
	p.current_hp = 0
	ds._on_player_died()
	await _frames(10)
	_check(not _root.is_in_dungeon, "left the dungeon after dying")
	_check(p.gold == 30, "run gold lost, own spending not refunded (gold %d, expected 30)" % p.gold)
	_check(_count(tonic.item_name) == tonics_before, "run consumable taken back")
	_check(p.active_class.experience >= xp_before + 10 or p.active_class.level > 1, "XP kept")
	_check(p.current_hp == p.max_hp, "free rescue: full HP")
	_check(p.gold == 30, "no donation after a dungeon death")
	_check(GameState.last_dungeon_failed and not GameState.last_dungeon_left, "last_dungeon_failed recorded")

	# --- ways out: generated on safe floors by chance; taking one keeps the loot
	var gen := DungeonMapGenerator.new()
	var always: DungeonDefinition = def.duplicate()
	always.bank_chance = 1.0
	var never: DungeonDefinition = def.duplicate()
	never.bank_chance = 0.0
	var exits_always := 0
	for n in gen.generate(always).nodes.values():
		if n.node_type == DungeonEnums.NodeType.EXIT:
			exits_always += 1
	var exits_never := 0
	for n in gen.generate(never).nodes.values():
		if n.node_type == DungeonEnums.NodeType.EXIT:
			exits_never += 1
	_check(exits_always >= 1 and exits_never == 0, "ways out follow bank_chance (always %d, never %d)" % [exits_always, exits_never])

	_root.enter_dungeon(def)
	await _frames(20)
	run = ds.current_run
	var gold_in: int = p.gold
	p.add_gold(25)
	run.track_gold(25)
	ds._bank_and_leave()
	await _frames(10)
	_check(not _root.is_in_dungeon and p.gold == gold_in + 25, "took the way out and kept the loot")
	_check(GameState.last_dungeon_left and not GameState.last_dungeon_failed, "last_dungeon_left recorded")

	# --- depth: later floors are tougher
	var d0: Dictionary = CombatTuning.depth_multipliers(0, 1.0)
	var d4: Dictionary = CombatTuning.depth_multipliers(4, 1.0)
	_check(is_equal_approx(d0.stats, 1.0) and is_equal_approx(d4.stats, 1.2) and is_equal_approx(d4.damage, 1.12), "depth multipliers (floor 4: x1.2 stats, x1.12 damage)")
	GameManager.pending_depth = d4
	var enc := _encounter()
	GameManager.pending_encounter = enc
	_root.start_combat(enc)
	await _frames(60)
	var cm = _root.combat_scene.find_child("CombatManager", true, false)
	if cm == null:
		cm = _root.combat_scene
	var e0: Combatant = cm.enemy_combatants[0] if cm and cm.enemy_combatants.size() > 0 else null
	_check(e0 != null and is_equal_approx(e0.encounter_stat_multiplier, 1.2) and is_equal_approx(e0.encounter_damage_multiplier, 1.12), "a floor-4 enemy spawns tougher")
	_root.end_combat(true)
	await _frames(10)
	_check(GameManager.pending_depth.is_empty(), "depth cleared after the fight")

	# --- first clear pays and records without a first-clear item
	var no_item: DungeonDefinition = def.duplicate()
	no_item.dungeon_id = "test_first_clear"
	no_item.first_clear_item = null
	no_item.first_clear_gold = 77
	_root.enter_dungeon(no_item)
	await _frames(20)
	var g0: int = p.gold
	ds._on_dungeon_complete()
	await _frames(10)
	_check(GameManager.completed_encounters.has("dungeon_test_first_clear"), "first clear recorded without a first-clear item")
	_check(p.gold >= g0 + 77, "first-clear gold paid (%d -> %d)" % [g0, p.gold])

	_finish()


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("defeat_and_runs_test: ALL PASSED")
		get_tree().quit(0)
	else:
		print("defeat_and_runs_test: %d FAILED" % _failures.size())
		for f in _failures:
			print("   - " + f)
		get_tree().quit(1)
