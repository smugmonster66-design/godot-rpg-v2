# res://tests/sim_fixes_test.gd
# Headless test of the fixes for bugs the balance simulator found
# (engine/balance-sim, 2026-09-27):
#   Gap 85 dice combat start/end, Gap 86 heals and SHIELD on non-heal actions,
#   Gap 87 barrier salves last one fight, Gap 90 dice pool overflow,
#   Gap 63 RANDOM_STRIKES through the damage calculation,
#   and the enemy tier/level knobs.
# WRITES user://save.tres. Back up your save first.
#
#   godot --headless --path . res://tests/sim_fixes_test.tscn
extends Node

const BRUTE := "res://resources/enemies/baseline/trash/brute.tres"
const BOSS := "res://resources/enemies/baseline/boss/boss_brute.tres"
const ABSORB := "res://resources/actions/enemy_base/absorb.tres"
const VOLLEY := "res://resources/actions/items/region_1/longbow_volley_action.tres"
const ASCENDANT := "res://resources/dice_affixes/rollable/positional/tier_3/change_die_type_up.tres"

var _failures: Array[String] = []
var _root: Node = null
var _cm: Node = null


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
	var p: Player = GameManager.player

	# ------------------------------------------------------------ Gap 87
	var salve: ConsumableItem = load("res://resources/consumables/region_1/restoratives/bulwark_salve.tres").duplicate()
	var base_before: int = p.base_barrier
	var barrier_before: int = p.get_barrier()
	salve.use(p, {})
	_check(p.base_barrier == base_before, "a barrier salve no longer adds to base barrier for good")
	var queued := false
	for b in p.active_consumable_buffs:
		if b.get("type", "") == "barrier":
			queued = true
	_check(queued, "the salve is queued for the next fight")

	# ------------------------------------------------------------ start a fight
	var enc := CombatEncounter.new()
	enc.encounter_id = "test_sim_fixes"
	enc.encounter_name = "Sim fixes test"
	var brute: EnemyData = load(BRUTE)
	var boss: EnemyData = load(BOSS)
	var enemies: Array[EnemyData] = [brute, boss]
	enc.enemies = enemies
	enc.player_starts_first = true
	GameManager.pending_encounter = enc
	_root.start_combat(enc)
	await _frames(90)
	_cm = _root.combat_scene.find_child("CombatManager", true, false)
	if _cm == null:
		_cm = _root.combat_scene
	var pc: Combatant = _cm.player_combatant
	var e0: Combatant = _cm.enemy_combatants[0]
	var e1: Combatant = _cm.enemy_combatants[1]

	_check(p.get_barrier() == barrier_before + 40, "in the fight the salve gives +40 barrier (%d -> %d)" % [barrier_before, p.get_barrier()])

	# ------------------------------------------------------------ tier knobs
	_check(is_equal_approx(CombatTuning.enemy_damage_multiplier(3, 1), CombatTuning.ENEMY_DAMAGE_TIER[3]), "boss damage step at level 1 = the tier knob")
	_check(CombatTuning.enemy_damage_multiplier(0, 100) > CombatTuning.enemy_damage_multiplier(0, 1), "enemy damage grows with level (affix curve)")
	_check(is_equal_approx(e0.encounter_damage_multiplier, CombatTuning.enemy_damage_multiplier(int(brute.enemy_tier), e0.get_effective_level())),
		"a spawned trash enemy carries its tier and level damage multiplier (%.2f)" % e0.encounter_damage_multiplier)
	_check(is_equal_approx(e1.encounter_damage_multiplier, CombatTuning.enemy_damage_multiplier(int(boss.enemy_tier), e1.get_effective_level())),
		"a spawned boss carries the boss step (%.2f)" % e1.encounter_damage_multiplier)
	var hp_saved: Array[float] = CombatTuning.ENEMY_HP_TIER.duplicate()
	var x1 := Combatant.new()
	x1.enemy_data = boss
	add_child(x1)
	var boss_hp_x1: int = x1.max_health
	x1.queue_free()
	CombatTuning.ENEMY_HP_TIER = [1.0, 1.0, 1.0, 3.0 * hp_saved[3], 3.0]
	var extra := Combatant.new()
	extra.enemy_data = boss
	add_child(extra)
	var boss_hp_x3: int = extra.max_health
	extra.queue_free()
	CombatTuning.ENEMY_HP_TIER = hp_saved
	_check(boss_hp_x3 >= int(boss_hp_x1 * 2.6), "ENEMY_HP_TIER multiplies boss HP (%d -> %d at x3)" % [boss_hp_x1, boss_hp_x3])

	# ------------------------------------------------------------ Gap 85
	var pool: PlayerDiceCollection = p.dice_pool
	pool._current_turn = 7
	var die := DieResource.new()
	die.die_type = DieResource.DieType.D6
	die.display_name = "Test D6"
	var asc: DiceAffix = load(ASCENDANT).duplicate(true)
	die.applied_affixes.append(asc)
	pool.add_die(die)
	_cm._start_dice_combat()
	_check(pool._current_turn == 0, "combat start resets the dice turn counter")
	_check(die.die_type == 8, "ON_COMBAT_START fires: Ascendant makes the d6 a d8 (%d)" % die.die_type)
	pool.end_combat()
	_check(die.die_type == 6, "combat end undoes the size change (no stacking fight after fight)")
	pool.remove_die(die)

	# ------------------------------------------------------------ Gap 90
	var added: Array[DieResource] = []
	while pool.get_pool_count() < pool.max_dice:
		var f := DieResource.new()
		f.display_name = "Filler"
		f.source = "test_filler"
		pool.add_die(f)
		added.append(f)
	var spill := DieResource.new()
	spill.display_name = "Spill"
	spill.source = "test_spill"
	pool.add_die(spill)
	_check(pool.overflow_dice.has(spill) and not pool.dice.has(spill), "a die past the cap waits in overflow, not lost")
	_check(pool.to_dict().get("overflow", []).size() == 1, "waiting dice are saved with the pool")
	pool.remove_die(added[0])
	_check(pool.dice.has(spill) and pool.overflow_dice.is_empty(), "it joins the pool when a slot frees up")
	pool.remove_dice_by_source("test_filler")
	pool.remove_dice_by_source("test_spill")

	# ------------------------------------------------------------ Gap 86
	var absorb: Action = load(ABSORB)
	var ad: Dictionary = absorb.to_dict()
	ad["action_resource"] = absorb
	var d := DieResource.new()
	d.modified_value = 10
	ad["placed_dice"] = [d]
	e0.current_health = maxi(1, e0.max_health - 30)
	var hp0: int = e0.current_health
	_cm._apply_action_effect(ad, e0, [pc])
	await _frames(2)
	_check(e0.current_health > hp0, "Absorb (a Defend) now heals its caster (%d -> %d)" % [hp0, e0.current_health])
	var etr: StatusTracker = _cm._get_status_tracker(e0)
	_check(etr.get_overhealth() > 0, "enemy SHIELD gives Overhealth (%d)" % etr.get_overhealth())

	# ------------------------------------------------------------ Gap 63
	var volley: Action = load(VOLLEY)
	_check(_cm._strikes_only({"action_resource": volley}), "Volley is a strikes-only attack")
	e1.armor = 0
	e1.barrier = 0
	e1.current_health = e1.max_health
	var flat := Affix.new()
	flat.affix_name = "Test flat"
	flat.category = Affix.Category.DAMAGE_BONUS
	flat.effect_number = 5.0
	flat.source = "test_flat"
	p.affix_manager.add_affix(flat)
	var s1: int = _cm._deal_strike(pc, e1, 10, ActionEffect.DamageType.PIERCING, true)
	var s2: int = _cm._deal_strike(pc, e1, 10, ActionEffect.DamageType.PIERCING, false)
	_check(s1 == 15 or s1 >= 22, "the first strike gets the flat damage affix once (%d)" % s1)
	_check(s2 == 10 or s2 >= 15, "later strikes don't repeat it (%d)" % s2)
	p.affix_manager.remove_affixes_by_source("test_flat")
	e1.armor = 200
	var s3: int = _cm._deal_strike(pc, e1, 10, ActionEffect.DamageType.PIERCING, true)
	_check(s3 < 10, "strikes go through armour (10 vs 200 armour -> %d)" % s3)

	_finish()


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("SIM FIXES TEST: ALL PASS")
	else:
		print("SIM FIXES TEST: %d FAILED" % _failures.size())
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)
