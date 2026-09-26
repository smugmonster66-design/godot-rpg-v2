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

	# --- D1: orphaned dice affixes are in their tables; reroll-needing ones aren't
	var names: Array = []
	for t in ["combat_tier_2", "combat_tier_3", "positional_tier_2", "positional_tier_3", "value_tier_3", "value_tier_1"]:
		var table = load("res://resources/dice_affix_tables/%s.tres" % t)
		for a in table.available_affixes:
			if a:
				names.append(a.affix_name)
	var want := ["Erupting", "Arcing", "Attuned", "Echoing", "Ascendant", "Persistent", "Fracturing"]
	var missing := want.filter(func(nm): return not names.has(nm))
	_check(missing.is_empty(), "orphaned dice affixes now roll (missing: %s)" % [missing])
	_check(not names.has("Lucky"), "Lucky (needs a reroll button) stays out")
	var util3 = load("res://resources/affix_tables/base/utility_tier_3.tres")
	var util_names: Array = []
	for a in util3.available_affixes:
		if a:
			util_names.append(a.affix_name)
	_check(not util_names.has("Reroll Any Die"), "Reroll Any Die (needs a reroll button) is out of the loot table")

	# --- D2: gear dice effects
	var flat_aff: Affix = load("res://resources/affixes/base/utility/tier_2/bonus_die_value_flat.tres").duplicate()
	flat_aff.effect_number = 2.0
	var pct_aff: Affix = load("res://resources/affixes/base/utility/tier_3/bonus_die_value_pct.tres").duplicate()
	pct_aff.effect_number = 0.5
	p.affix_manager.add_affix(flat_aff)
	p.affix_manager.add_affix(pct_aff)
	p.status_tracker.remove_status("slowed")
	var gd: DieResource = load("res://resources/dice/base/d6_none.tres").duplicate_die()
	var stat_only: int = p.dice_pool.stat_bonus_for_die(gd)
	p.dice_pool.apply_stat_bonus(gd)
	gd.set_value(4)   # current 4 + modifier (stat + flat)
	var before_pct: int = gd.get_total_value()
	p.dice_pool._finish_die_roll(gd)
	_check(before_pct == 4 + stat_only + 2, "Bonus Die Value: +2 on the die (%d)" % before_pct)
	_check(gd.get_total_value() == roundi(before_pct * 1.5), "Bonus Die Value %%: x1.5 (%d -> %d)" % [before_pct, gd.get_total_value()])
	p.affix_manager.remove_affix(flat_aff)
	p.affix_manager.remove_affix(pct_aff)

	var extra_aff: Affix = load("res://resources/affixes/base/utility/tier_2/extra_die_on_turn_start.tres").duplicate()
	p.affix_manager.add_affix(extra_aff)
	if p.dice_pool.dice.is_empty():
		p.dice_pool.add_die(load("res://resources/dice/base/d6_fire.tres").duplicate_die())
	p.dice_pool.roll_hand()
	_check(p.dice_pool.hand.size() == p.dice_pool.dice.size() + 1, "Extra Die on Turn Start: hand %d from %d dice" % [p.dice_pool.hand.size(), p.dice_pool.dice.size()])
	p.affix_manager.remove_affix(extra_aff)

	# --- D3: Duplicate Die on Max
	var dup_aff: Affix = load("res://resources/affixes/base/utility/tier_3/duplicate_die_on_max.tres").duplicate()
	dup_aff.proc_chance = 1.0
	p.affix_manager.add_affix(dup_aff)
	var maxed: DieResource = p.dice_pool.hand[0]
	maxed.set_value(maxed.die_type)
	var hand_before: int = p.dice_pool.hand.size()
	var pres: Dictionary = cm.proc_processor.process_procs(p.affix_manager, Affix.ProcTrigger.ON_DIE_USED, cm._build_proc_context({"die_used": maxed}))
	cm._apply_proc_results(pres)
	_check(p.dice_pool.hand.size() == hand_before + 1, "Duplicate Die on Max: a max roll comes back as a copy")
	p.affix_manager.remove_affix(dup_aff)

	_root.end_combat(true)
	await _frames(10)
	_test_loot(p)
	_finish()


func _find_affix(file: String, value: float) -> Affix:
	var a: Affix = load("res://resources/affixes/base/utility/tier_1/%s.tres" % file).duplicate()
	a.effect_number = value
	return a


func _test_loot(p) -> void:
	# --- E1: gold and XP find
	var gf := _find_affix("gold_find_bonus", 0.5)
	var xf := _find_affix("xp_find_bonus", 0.5)
	p.affix_manager.add_affix(gf)
	p.affix_manager.add_affix(xf)
	var g0: int = p.gold
	p.add_gold(10)
	_check(p.gold == g0 + 15, "Gold Find +50%%: 10 gold -> %d" % (p.gold - g0))
	var lvl0: int = p.active_class.level
	var x0: int = p.active_class.experience
	p.add_experience(10)
	_check(p.active_class.level > lvl0 or p.active_class.experience == x0 + 15, "XP Find +50%: 10 XP -> 15")
	p.affix_manager.remove_affix(gf)
	p.affix_manager.remove_affix(xf)

	# --- E2: loot find and rarity find in combat loot
	var cfg: RegionLootConfig = GameManager.region_loot_config
	var lf := _find_affix("loot_find_bonus", 1.0)
	p.affix_manager.add_affix(lf)
	var every_has_item := true
	for i in 10:
		var res: Array = LootManager.roll_loot_from_combat(cfg, EnemyTierLootConfig.EnemyTier.TRASH, EnemyTierLootConfig.Archetype.NONE, 5, 0.0)
		if res.filter(func(r): return r.get("type") != "currency").is_empty():
			every_has_item = false
	_check(every_has_item, "Loot Find 100%: trash always drops an item")
	p.affix_manager.remove_affix(lf)
	var rf := _find_affix("rarity_find_bonus", 1.0)
	p.affix_manager.add_affix(rf)
	var no_common := true
	for i in 15:
		for r in LootManager.roll_loot_from_combat(cfg, EnemyTierLootConfig.EnemyTier.ELITE, EnemyTierLootConfig.Archetype.NONE, 5, 0.0):
			var it = r.get("item")
			if it and it.rarity == EquippableItem.Rarity.COMMON:
				no_common = false
	_check(no_common, "Rarity Find 100%: every drop steps up from Common")
	p.affix_manager.remove_affix(rf)

	# --- E3: drops are always equippable when they drop
	var template: EquippableItem = load("res://resources/items/region_1/head/arcane_circlet.tres")
	var drop: Dictionary = LootManager.generate_drop(template, 60, 1)
	var item: EquippableItem = drop.get("item")
	_check(item != null and item.required_level <= p.level, "a level-60 drop is equippable at level %d (requires %d)" % [p.level, item.required_level if item else -1])

	# --- E4: static affixes count by their item's level
	var st := Affix.new()
	st.power_weight = 80.0
	st.source_item_level = 1
	var low: float = st.get_affix_power()
	st.source_item_level = 100
	var high: float = st.get_affix_power()
	_check(is_equal_approx(low, 8.0) and is_equal_approx(high, 80.0), "static affix power follows item level (lvl 1: %.0f, lvl 100: %.0f)" % [low, high])


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
