# res://tests/stats_test.gd
# Headless test of the main-stat rules (engine/stats, 2026-09-26): Intellect
# naming, per-level class growth without a double base, mana following level
# and Intellect, stats powering dice, Agility -> crit chance, Luck -> crit damage.
# WRITES user://save.tres (autosave). Back up your save first.
#
#   godot --headless --path . res://tests/stats_test.tscn
extends Node

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
	var p = GameManager.player
	var cls: PlayerClass = p.active_class
	_check(cls != null, "player has a class (%s)" % (cls.player_class_name if cls else "none"))
	if cls == null:
		_finish()
		return

	# --- Intellect naming and class base
	_check("base_intellect" in cls and cls.get_main_stat_name() == "intellect", "the Mage's primary stat is Intellect")
	var lvl: int = cls.level
	var expect_int: int = cls.base_intellect + int(cls.intellect_per_level * (lvl - 1))
	_check(cls.get_stat_bonus("intellect") == expect_int, "class Intellect at level %d = base + growth (%d)" % [lvl, expect_int])

	# --- no double base: total = class part + affixes only
	var str_affix := 0
	for a in p.affix_manager.get_pool(Affix.Category.STRENGTH_BONUS):
		str_affix += int(a.apply_effect())
	_check(p.get_total_stat("strength") == cls.get_stat_bonus("strength") + str_affix, "Strength isn't counted twice (%d)" % p.get_total_stat("strength"))

	# --- level-up grows the primary stat and mana
	var int_before: int = p.get_total_stat("intellect")
	var mana_before: int = p.mana_pool.max_mana if p.has_mana_pool() else -1
	var need: int = cls.get_exp_for_next_level() - cls.experience
	p.add_experience(need + 1)
	_check(cls.level == lvl + 1, "levelled up to %d" % cls.level)
	var int_after: int = p.get_total_stat("intellect")
	_check(int_after >= int_before + int(cls.intellect_per_level) - 1 and int_after > int_before, "Intellect grew on level-up (%d -> %d)" % [int_before, int_after])
	if p.has_mana_pool():
		_check(p.mana_pool.max_mana > mana_before, "mana max recalculated on level-up (%d -> %d)" % [mana_before, p.mana_pool.max_mana])

	# --- stats power dice
	cls.base_intellect += 200   # +10 die value for magical dice
	cls.base_strength += 100    # +5 for physical dice
	var fire: DieResource = load("res://resources/dice/base/d6_fire.tres").duplicate_die()
	var slash: DieResource = load("res://resources/dice/base/d6_slashing.tres").duplicate_die()
	var plain: DieResource = load("res://resources/dice/base/d6_none.tres").duplicate_die()
	var ib: int = CombatTuning.die_stat_bonus(p.get_total_stat("intellect"))
	var sb: int = CombatTuning.die_stat_bonus(p.get_total_stat("strength"))
	for d in [fire, slash, plain]:
		d.roll()
	var fv: int = fire.get_total_value()
	var sv: int = slash.get_total_value()
	var pv: int = plain.get_total_value()
	p.dice_pool.apply_stat_bonus(fire)
	p.dice_pool.apply_stat_bonus(slash)
	p.dice_pool.apply_stat_bonus(plain)
	_check(fire.get_total_value() == fv + ib, "fire die gets the Intellect bonus (+%d)" % ib)
	_check(slash.get_total_value() == sv + sb, "slashing die gets the Strength bonus (+%d)" % sb)
	_check(plain.get_total_value() == pv + ib, "neutral die follows the primary stat, Intellect (+%d)" % ib)
	p.dice_pool.apply_stat_bonus(fire)
	_check(fire.get_total_value() == fv + ib, "the bonus is applied only once")
	fire.roll()
	_check(fire.get_total_value() >= 1 + ib, "a reroll keeps the bonus")

	var enemy_pool := PlayerDiceCollection.new()
	var edie: DieResource = load("res://resources/dice/base/d6_fire.tres").duplicate_die()
	edie.roll()
	var ev: int = edie.get_total_value()
	enemy_pool.apply_stat_bonus(edie)
	_check(edie.get_total_value() == ev, "enemy dice get no stat bonus")
	enemy_pool.free()

	if p.dice_pool.dice.size() > 0:
		p.dice_pool.roll_hand()
		var all_marked := true
		for d in p.dice_pool.hand:
			if not d.has_meta("stat_bonus_applied"):
				all_marked = false
		_check(all_marked, "every die rolled into the hand got its stat bonus")
	cls.base_intellect -= 200
	cls.base_strength -= 100

	# --- crit
	_check(is_equal_approx(CombatTuning.crit_chance(200), 25.0), "Agility 200 -> 25% crit chance")
	_check(CombatTuning.crit_chance(100000) < CombatTuning.CRIT_CHANCE_CAP, "crit chance never passes its cap")
	_check(is_equal_approx(CombatTuning.crit_multiplier(0), 1.5) and is_equal_approx(CombatTuning.crit_multiplier(200), 2.0), "Luck 0 -> x1.5, Luck 200 -> x2.0 crit damage")
	_finish()


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("stats_test: ALL PASSED")
		get_tree().quit(0)
	else:
		print("stats_test: %d FAILED" % _failures.size())
		for f in _failures:
			print("   - " + f)
		get_tree().quit(1)
