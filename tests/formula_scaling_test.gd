# res://tests/formula_scaling_test.gd
# Headless test of the 2026-09-27 formula decisions (engine/balance-sim):
#   A1 hit-relative defence (and the player's gear armour reaching it),
#   C1 heals that scale (HEALING_BONUS, potions flat + % of max HP),
#   D  status strength by the applier's level (potency).
# WRITES user://save.tres. Back up your save first.
#
#   godot --headless --path . res://tests/formula_scaling_test.tscn
extends Node

const BRUTE := "res://resources/enemies/baseline/trash/brute.tres"
const SUPPORT := "res://resources/enemies/baseline/trash/support_mage.tres"
const MEND := "res://resources/actions/enemy_base/mend.tres"

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


func _packet(amounts: Dictionary) -> DamagePacket:
	var p := DamagePacket.new()
	for t in amounts:
		p.add_damage(t, float(amounts[t]))
	return p


func _run() -> void:
	await _frames(10)
	var title: Node = _root.find_child("TitleScreen", true, false)
	if title:
		title.new_game_confirmed.emit()
	await _frames(30)
	var S := ActionEffect.DamageType.SLASHING
	var P := ActionEffect.DamageType.PIERCING
	var F := ActionEffect.DamageType.FIRE

	# ------------------------------------------------------------------ A1
	_check(CombatTuning.DEFENSE_K == 8.0 and CombatTuning.DEFENSE_CAP == 0.85, "defence knobs at K=8 (tuned), cap 85%")
	var k_default: float = CombatTuning.DEFENSE_K
	CombatTuning.DEFENSE_K = 5.0  # the formula checks below are written for K = 5
	var arm50 := {"armor": 50.0, "barrier": 0.0}
	_check(_packet({S: 10}).calculate_final_damage(arm50) == 5, "10 slashing vs 50 armour -> 5 (armour = 5x the hit halves it)")
	_check(_packet({S: 100}).calculate_final_damage({"armor": 500.0, "barrier": 0.0}) == 50, "100 vs 500 armour -> 50 (scale-free)")
	_check(_packet({S: 40}).calculate_final_damage(arm50) == 32, "a bigger hit punches through: 40 vs 50 armour -> 32")
	_check(_packet({S: 10}).calculate_final_damage({"armor": 100000.0, "barrier": 0.0}) == 2, "reduction capped at 85% (10 -> 2, never 0)")
	_check(_packet({P: 10}).calculate_final_damage(arm50) == 7, "piercing halves armour (10 vs 25 effective -> 7)")
	_check(_packet({S: 10, F: 10}).calculate_final_damage(arm50) == 15, "per-element piles: armour doesn't touch the fire pile")
	_check(_packet({F: 10}).calculate_final_damage({"armor": 0.0, "barrier": 50.0}) == 5, "barrier works the same on magical piles")
	_check(_packet({S: 10}).calculate_final_damage(arm50, 0.5) == 7, "DoT ticks: half defence (25 vs 10 -> 7)")
	_check(_packet({S: 5}).calculate_final_damage({"armor": 3.0, "barrier": 0.0}) == 4, "no flat subtraction step: 5 vs 3 armour -> 4 (11% off; the old formula gave 2)")
	CombatTuning.DEFENSE_K = k_default
	_check(_packet({S: 10}).calculate_final_damage(arm50) == 6, "at K=8: 10 vs 50 armour -> 6 (38% off)")

	# A real fight: the player's gear armour now reaches enemy hits
	var enc := CombatEncounter.new()
	enc.encounter_id = "test_formula_scaling"
	enc.encounter_name = "Formula scaling test"
	var brute: EnemyData = load(BRUTE)
	var support: EnemyData = load(SUPPORT)
	var enemies: Array[EnemyData] = [brute, support]
	enc.enemies = enemies
	enc.player_starts_first = true
	GameManager.pending_encounter = enc
	_root.start_combat(enc)
	await _frames(90)
	_cm = _root.combat_scene.find_child("CombatManager", true, false)
	if _cm == null:
		_cm = _root.combat_scene
	var p: Player = GameManager.player
	var pc: Combatant = _cm.player_combatant
	p.base_armor = 40
	var ds: Dictionary = _cm._get_defender_stats(pc)
	_check(int(ds.get("armor", -1)) == p.get_armor() and p.get_armor() >= 40, "enemy hits use the player's gear armour (%d)" % int(ds.get("armor", -1)))
	p.base_armor = 0

	# ------------------------------------------------------------------ C1
	var sup: Combatant = _cm.enemy_combatants[1]
	var mend: Action = load(MEND)
	var d6 := DieResource.new()
	d6.modified_value = 5
	var mend_data: Dictionary = mend.to_dict()
	mend_data["action_resource"] = mend
	mend_data["placed_dice"] = [d6]
	var plain: int = _cm._calculate_heal(mend_data, sup)
	var had_bonus := 0.0
	for a in sup.get_affix_manager().get_pool(Affix.Category.HEALING_BONUS):
		had_bonus += float(a.effect_number)
	var hb := Affix.new()
	hb.affix_name = "Test Healing Bonus"
	hb.category = Affix.Category.HEALING_BONUS
	hb.effect_number = 7.0
	hb.source = "test"
	sup.get_affix_manager().add_affix(hb)
	var boosted: int = _cm._calculate_heal(mend_data, sup)
	_check(boosted == plain + 7, "enemy heal = (dice + base) x mult + healer's Healing Bonus (%d -> %d)" % [plain, boosted])
	_check(plain >= 5 + int(had_bonus) - 1, "the support mage's rolled Healing Bonus adds to Mend (%d with bonus %.0f)" % [plain, had_bonus])
	var php := Affix.new()
	php.affix_name = "Test Player Healing"
	php.category = Affix.Category.HEALING_BONUS
	php.effect_number = 4.0
	php.source = "test_player"
	p.affix_manager.add_affix(php)
	_check(_cm._apply_healing_mods(10.0, pc) == 14, "player proc heals get the player's Healing Bonus (10 -> 14)")
	p.affix_manager.remove_affixes_by_source("test_player")
	var cat_ok := false
	var reg = get_tree().root.get_node_or_null("AffixTableRegistry")
	if reg:
		var t: AffixTable = reg.get_table("defense", 2)
		if t:
			for a in t.get_all_affixes():
				if a and a.category == Affix.Category.HEALING_BONUS:
					cat_ok = true
	_check(cat_ok, "Healing Bonus rolls from the defence tier-2 table")
	var tonic: ConsumableItem = load("res://resources/consumables/region_1/restoratives/sanctum_tonic.tres")
	_check(tonic.heal_amount > 0 and tonic.heal_percent > 0.0, "Sanctum Tonic heals flat + %% of max HP (%d + %.0f%%)" % [tonic.heal_amount, tonic.heal_percent * 100.0])
	p.current_hp = 1
	var expect: int = mini(p.max_hp, 1 + tonic.heal_amount + maxi(1, int(p.max_hp * tonic.heal_percent)))
	tonic.duplicate().use(p, {})
	_check(p.current_hp == expect, "the tonic heals %d HP at %d max HP" % [expect - 1, p.max_hp])
	p.current_hp = p.max_hp

	# ------------------------------------------------------------------ D
	_check(is_equal_approx(CombatTuning.status_potency(1), 1.0), "potency 1.0 at level 1")
	var pot50 := CombatTuning.status_potency(50)
	var pot100 := CombatTuning.status_potency(100)
	_check(pot50 > 15.0 and pot50 < 30.0, "potency at level 50 follows the affix curve (%.1f)" % pot50)
	_check(is_equal_approx(pot100, CombatTuning.STATUS_POTENCY_AT_CAP), "potency at level 100 = the cap (%.0f)" % pot100)
	var tr := StatusTracker.new()
	add_child(tr)
	var bleed: StatusAffix = load("res://resources/statuses/bleed.tres")
	var fortified: StatusAffix = load("res://resources/statuses/fortified.tres")
	var corrode: StatusAffix = load("res://resources/statuses/corrode.tres")
	var static_s: StatusAffix = load("res://resources/statuses/static.tres")
	var block: StatusAffix = load("res://resources/statuses/block.tres")
	var burn: StatusAffix = load("res://resources/statuses/burn.tres")
	StatusTracker.applier_level = 1
	tr.apply_status(bleed, 3, "test")
	var tick1: int = bleed.apply_tick(tr.get_instance("bleed"))["damage"]
	_check(tick1 == 3, "level-1 bleed: 3 stacks tick for 3")
	tr.clear_all()
	StatusTracker.applier_level = 50
	tr.apply_status(bleed, 3, "test")
	var tick50: int = bleed.apply_tick(tr.get_instance("bleed"))["damage"]
	_check(tick50 == roundi(3 * pot50), "level-50 bleed: 3 stacks tick for %d" % tick50)
	_check(tr.get_stacks("bleed") == 3, "stack count unchanged by potency")
	tr.apply_status(fortified, 2, "test")
	_check(is_equal_approx(tr.get_total_stat_modifier("armor"), 2.0 * pot50), "fortified armour x potency (%.1f)" % tr.get_total_stat_modifier("armor"))
	tr.apply_status(corrode, 1, "test")
	_check(is_equal_approx(tr.get_total_stat_modifier("armor"), 2.0 * pot50 - 2.0 * pot50), "corrode -2 per stack x potency")
	tr.apply_status(static_s, 2, "test")
	var shock_bonus := tr.get_total_stat_modifier("shock_damage_received_bonus")
	_check(shock_bonus > 2.0 * pot50 - 0.01, "static bonus x potency (%.1f)" % shock_bonus)
	tr.apply_status(block, 4, "test")
	_check(tr.get_block_value() == roundi(4 * pot50), "block value x potency (%d)" % tr.get_block_value())
	_check(tr.get_total_stat_modifier("damage_multiplier") == 0.0, "percentage modifiers are not scaled")
	tr.clear_all()
	var burst := [0]
	tr.status_threshold_triggered.connect(func(_sid, data): burst[0] = int(data.get("damage", 0)))
	StatusTracker.applier_level = 100
	tr.apply_status(burn, 10, "test")
	_check(burst[0] == int(15 * pot100), "burn burst at 10 stacks = 15 x potency (%d)" % burst[0])
	StatusTracker.applier_level = 1
	tr.apply_status(bleed, 1, "low")
	StatusTracker.applier_level = 75
	tr.apply_status(bleed, 1, "high")
	_check(is_equal_approx(float(tr.get_instance("bleed").get("potency", 0.0)), CombatTuning.status_potency(75)), "stronger applier's potency wins on restack")
	StatusTracker.applier_level = 0
	tr.clear_all()
	var fresh := StatusTracker.new()
	add_child(fresh)
	fresh.apply_status(bleed, 2, "no applier")
	_check(is_equal_approx(float(fresh.get_instance("bleed").get("potency", 0.0)), 1.0), "no applier set -> potency 1")

	# Enemy actions carry the enemy's level: a level-50 player makes a
	# level-42 trash brute (0.85x), whose statuses use that level.
	var e0: Combatant = _cm.enemy_combatants[0]
	_check(_cm._level_of(e0) == e0.get_effective_level(), "enemy statuses use the enemy's spawn level")
	_check(_cm._level_of(pc) == p.level, "player statuses use the player's level")

	# Fight saves keep potency
	StatusTracker.applier_level = 50
	var etr: StatusTracker = _cm._get_status_tracker(e0)
	etr.apply_status(bleed, 2, "save test")
	StatusTracker.applier_level = 0
	var saved: Array = _cm._statuses_to_list(etr)
	_cm._restore_statuses(etr, saved)
	_check(is_equal_approx(float(etr.get_instance("bleed").get("potency", 0.0)), pot50), "a saved fight restores status potency")

	_finish()


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("FORMULA SCALING TEST: ALL PASS")
	else:
		print("FORMULA SCALING TEST: %d FAILED" % _failures.size())
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)
