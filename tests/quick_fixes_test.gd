# res://tests/quick_fixes_test.gd
# Headless test of engine/quick-fixes: duplicate dice are turn-only copies
# (Gap 94), heavy weapons double affix values (Gap 96), events don't repeat
# (Gap 37), the Naval Greatsword grants its action (Gap 82).
#
#   godot --headless --path . res://tests/quick_fixes_test.tscn
extends Node

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + what)
	if not cond:
		_failures.append(what)


func _die(value: int) -> DieResource:
	var d := DieResource.new()
	d.die_type = DieResource.DieType.D6
	d.current_value = value
	return d


func _run() -> void:
	await get_tree().process_frame
	_test_duplicates()
	_test_heavy_values()
	_test_events()
	_test_greatsword()
	if _failures.is_empty():
		print("QUICK FIXES: ALL PASS")
		get_tree().quit(0)
	else:
		print("QUICK FIXES: %d FAILED" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _test_duplicates() -> void:
	print("Duplicate dice (Gap 94)")
	var pool := PlayerDiceCollection.new()
	add_child(pool)
	pool.add_die(_die(6))
	pool.add_die(_die(3))
	var src: DieResource = _die(6)
	pool.hand = [src]
	pool._handle_affix_results({"special_effects": [{"type": "duplicate", "die_index": 0, "source_die": src}]})
	_check(pool.dice.size() == 2, "the pool is unchanged (copy isn't permanent)")
	_check(pool.hand.size() == 2, "the copy joins the hand")
	_check(pool.hand.size() == 2 and pool.hand[1].is_duplicate, "the copy is marked as a copy")
	# A copy can't copy itself again
	var proc := DiceAffixProcessor.new()
	var res := {"special_effects": []}
	var copy: DieResource = pool.hand[1]
	if proc and proc.has_method("_apply_duplicate_on_max"):
		copy.current_value = 6
		proc._apply_duplicate_on_max(copy, 1, res)
		_check(res.special_effects.is_empty(), "a copy rolling max doesn't duplicate again")
	# Cap
	pool.hand.clear()
	for i in pool.max_dice:
		pool.hand.append(_die(1))
	pool._handle_affix_results({"special_effects": [{"type": "duplicate", "die_index": 0, "source_die": src}]})
	_check(pool.hand.size() == pool.max_dice, "no copy past the dice cap")
	pool.queue_free()


func _static_affix(cat: int, value: float) -> Affix:
	var a := Affix.new()
	a.affix_name = "Test %d" % cat
	a.category = cat
	a.effect_number = value
	return a


func _test_heavy_values() -> void:
	print("Heavy affix values (Gap 96)")
	var heavy := EquippableItem.new()
	heavy.item_name = "Test Heavy"
	heavy.equip_slot = EquippableItem.EquipSlot.HEAVY
	heavy.slot_definition = load("res://resources/slot_definitions/heavy_slot.tres")
	heavy.rarity = EquippableItem.Rarity.EPIC
	heavy.manual_first_affix = _static_affix(Affix.Category.STRENGTH_BONUS, 10)
	heavy.manual_second_affix = _static_affix(Affix.Category.DAMAGE_MULTIPLIER, 1.1)
	heavy.initialize_affixes()
	_check(heavy.inherent_affixes.size() == 2 and heavy.inherent_affixes[0].effect_number == 20.0,
		"a flat affix doubles (10 -> 20)")
	_check(heavy.inherent_affixes.size() == 2 and is_equal_approx(heavy.inherent_affixes[1].effect_number, 1.2),
		"a multiplier doubles its bonus (1.1 -> 1.2)")
	_check(heavy.rolled_affixes.size() <= 3, "an Epic heavy rolls 3 affixes, not 6 (got %d)" % heavy.rolled_affixes.size())
	var mh := EquippableItem.new()
	mh.item_name = "Test Blade"
	mh.equip_slot = EquippableItem.EquipSlot.MAIN_HAND
	mh.slot_definition = load("res://resources/slot_definitions/main_hand_slot.tres")
	mh.rarity = EquippableItem.Rarity.COMMON
	mh.manual_first_affix = _static_affix(Affix.Category.STRENGTH_BONUS, 10)
	mh.initialize_affixes()
	_check(mh.inherent_affixes.size() == 1 and mh.inherent_affixes[0].effect_number == 10.0,
		"a main-hand affix is unchanged")


func _test_events() -> void:
	print("Events don't repeat (Gap 37)")
	var def := DungeonDefinition.new()
	var e1 := DungeonEvent.new()
	var e2 := DungeonEvent.new()
	def.event_pool = [e1, e2]
	var ok := true
	for i in 20:
		if def.get_random_event(1, [e1]) != e2:
			ok = false
	_check(ok, "an unused event is always preferred")
	_check(def.get_random_event(1, [e1, e2]) != null, "falls back to a repeat when all are used")
	var late := DungeonEvent.new()
	late.min_floor = 50
	def.event_pool = [late]
	_check(def.get_random_event(1) == null, "no event outside its floor window")


func _test_greatsword() -> void:
	print("Naval Greatsword (Gap 82)")
	var gs: EquippableItem = load("res://resources/items/region_1/heavy/naval_greatsword.tres")
	_check(gs.grants_action and gs.action != null, "grants Grand Sweep")
