# res://tests/balance_fixes_test.gd
# Headless test of the distorting-bug fixes (engine/balance-fixes):
# affix roll fuzz, Titanic rounding, upgrade stacking, Empowered / Braced /
# Slowed, and enemy dice affixes (ON_USE, ON_ROLL statuses).
# WRITES user://save.tres. Back up your save first.
#
#   godot --headless --path . res://tests/balance_fixes_test.tscn
extends Node

const SHIELDBEARER := "res://resources/enemies/region1/navy/trash/navy_shieldbearer.tres"
const ENFORCER := "res://resources/enemies/region1/navy/trash/navy_enforcer.tres"

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


func _run() -> void:
	await _frames(10)
	var title: Node = _root.find_child("TitleScreen", true, false)
	if title:
		title.new_game_confirmed.emit()
	await _frames(30)
	var p = GameManager.player

	# --- A1: the fuzz floor follows the range
	var cfg: AffixScalingConfig = AffixTableRegistry.scaling_config
	var mult: Dictionary = cfg.compute_fuzz_range(1.05, 1.05, 1.6)
	_check(mult.max - mult.min < 0.2, "a x1.05-1.6 multiplier at low level rolls near 1.05 (%.2f-%.2f)" % [mult.min, mult.max])
	var flat: Dictionary = cfg.compute_fuzz_range(2.0, 1.0, 30.0)
	_check(flat.max - flat.min >= 1.9, "a 1-30 affix still gets its +-1 at low level (%.1f-%.1f)" % [flat.min, flat.max])

	# --- A2: Titanic keeps its decimals
	var titanic := DiceAffix.new()
	titanic.effect_value_min = 1.5
	titanic.effect_value_max = 2.0
	_check(is_equal_approx(titanic._round_dice_value(1.73), 1.73), "x1.5-2.0 rolls keep decimals (1.73)")
	var sturdy := DiceAffix.new()
	sturdy.effect_value_min = 1.0
	sturdy.effect_value_max = 3.0
	_check(is_equal_approx(sturdy._round_dice_value(2.4), 2.0), "integer ranges still round (2.4 -> 2)")

	# --- A3: regenerating a generated die doesn't stack affixes
	var template: DieResource = load("res://resources/dice/base/d6_fire.tres")
	var gen1: DieResource = DieGenerator.generate_from_template(template, EquippableItem.Rarity.RARE, 20, "Test")
	var gen2: DieResource = DieGenerator.generate_from_template(gen1, EquippableItem.Rarity.RARE, 40, "Test")
	var rolled1 := gen1.applied_affixes.filter(func(a): return a.source_type == "item_grant").size()
	var rolled2 := gen2.applied_affixes.filter(func(a): return a.source_type == "item_grant").size()
	_check(rolled2 == rolled1 and rolled1 > 0, "upgrade re-rolls, doesn't stack (%d then %d affixes)" % [rolled1, rolled2])
	_check(gen2.display_name.count("Rare") == 1, "no doubled rarity name (%s)" % gen2.display_name)

	# --- B: statuses
	var empowered: StatusAffix = load("res://resources/statuses/empowered.tres")
	var braced: StatusAffix = load("res://resources/statuses/braced.tres")
	var slowed: StatusAffix = load("res://resources/statuses/slowed.tres")
	p.status_tracker.apply_status(empowered, 2, "test")
	_check(is_equal_approx(p.status_tracker.get_total_stat_modifier("damage_multiplier"), 0.2), "Empowered x2 = +20% damage")

	var enc := CombatEncounter.new()
	enc.encounter_id = "test_balance_fixes"
	var enemies: Array[EnemyData] = [load(SHIELDBEARER), load(ENFORCER)]
	enc.enemies = enemies
	GameManager.pending_encounter = enc
	_root.start_combat(enc)
	await _frames(90)
	var cm = _root.combat_scene.find_child("CombatManager", true, false)
	if cm == null:
		cm = _root.combat_scene
	var pc: Combatant = cm.player_combatant
	_check(cm.enemy_combatants.size() == 2, "fight started")
	if cm.enemy_combatants.size() < 2:
		_finish()
		return
	var shield: Combatant = cm.enemy_combatants[0]
	var enforcer: Combatant = cm.enemy_combatants[1]

	p.status_tracker.apply_status(braced, 4, "test")
	var def_res: Dictionary = cm._apply_defensive_statuses(pc, 100)
	_check(def_res.final_damage == 80 or def_res.dodged, "Braced x4 takes 20%% off a hit (100 -> %d)" % def_res.final_damage)

	p.status_tracker.apply_status(slowed, 2, "test")
	var d5: DieResource = load("res://resources/dice/base/d6_none.tres").duplicate_die()
	d5.set_value(5)
	p.dice_pool._apply_status_die_penalty(d5)
	var d2: DieResource = load("res://resources/dice/base/d6_none.tres").duplicate_die()
	d2.set_value(2)
	p.dice_pool._apply_status_die_penalty(d2)
	_check(d5.get_total_value() == 3 and d2.get_total_value() == 1, "Slowed x2: 5 -> %d, 2 -> %d (never below 1)" % [d5.get_total_value(), d2.get_total_value()])

	# --- C1: enemy ON_ROLL status dice affixes resolve (Shield Brace: Fortified)
	var got_fortified := false
	var s_tracker: StatusTracker = cm._get_status_tracker(shield)
	for i in 10:
		shield.dice_collection.roll_hand()
		cm._resolve_combat_events(shield.dice_collection.drain_combat_events(), pc, 0, shield)
		if s_tracker and s_tracker.has_status("fortified"):
			got_fortified = true
			break
	_check(got_fortified, "an enemy's on-roll dice affix gives it its status (Shield Brace -> Fortified)")
	_check(not p.status_tracker.has_status("fortified"), "...and not the player")

	# --- C2: enemy ON_USE dice affixes apply (Weighted Head: first die +1)
	enforcer.dice_collection.roll_hand()
	var hand: Array = enforcer.dice_collection.get_hand_dice()
	var ok_on_use := false
	if hand.size() > 0:
		var die: DieResource = hand[0]
		var before: int = die.get_total_value()
		cm._process_enemy_on_use(enforcer, [die], pc)
		ok_on_use = die.get_total_value() > before
		print("    Weighted Head: %d -> %d" % [before, die.get_total_value()])
	_check(ok_on_use, "an enemy's on-use dice affix changes its die (Weighted Head)")

	_root.end_combat(true)
	await _frames(10)
	_finish()


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("balance_fixes_test: ALL PASSED")
		get_tree().quit(0)
	else:
		print("balance_fixes_test: %d FAILED" % _failures.size())
		for f in _failures:
			print("   - " + f)
		get_tree().quit(1)
