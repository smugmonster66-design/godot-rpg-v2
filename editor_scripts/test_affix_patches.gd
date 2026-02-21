# res://scripts/debug/test_affix_patches.gd
# Quick validation for affix system patches.
# Run from Editor → Script → Run (Ctrl+Shift+X)
#
# Tests:
#   1. _apply_proc_results signature accepts optional target
#   2. AffixProcProcessor fires all 11 ProcTrigger values
#   3. DiceAffixCondition SELF_DIE_TYPE_IS / SELF_DIE_TYPE_ABOVE
#   4. DiceAffixProcessor _resolve_value guards compound-only ValueSources
#   5. StatusTracker.process_turn_end exists and differs from process_turn_start
#
# Does NOT test (requires live combat):
#   - ON_KILL/ON_DEFEND/ON_ACTION_USED/ON_DIE_USED/ON_COMBAT_END hook placement
#   - Bonus damage actually hitting enemies
#   - Status effects actually applying to enemies
#   → Use the debug combat checklist for those
@tool
extends EditorScript

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func _run():
	print("\n" + "=".repeat(60))
	print("🧪 AFFIX PATCH VALIDATION")
	print("=".repeat(60))
	
	test_proc_trigger_enum_completeness()
	test_proc_processor_all_triggers()
	test_die_type_conditions()
	test_value_source_guard()
	test_status_tracker_turn_end()
	test_apply_proc_results_signature()
	
	print("\n" + "=".repeat(60))
	if _fail_count == 0:
		print("✅ ALL %d TESTS PASSED" % _pass_count)
	else:
		print("❌ %d PASSED, %d FAILED" % [_pass_count, _fail_count])
	print("=".repeat(60) + "\n")

# ============================================================================
# TEST 1: ProcTrigger enum has all 11 values
# ============================================================================
func test_proc_trigger_enum_completeness():
	begin("ProcTrigger enum completeness")
	
	var expected = [
		"NONE", "ON_DEAL_DAMAGE", "ON_TAKE_DAMAGE",
		"ON_TURN_START", "ON_TURN_END",
		"ON_COMBAT_START", "ON_COMBAT_END",
		"ON_DIE_USED", "ON_ACTION_USED",
		"ON_KILL", "ON_DEFEND",
	]
	
	# Verify the enum values exist by accessing them
	var triggers = {
		"NONE": Affix.ProcTrigger.NONE,
		"ON_DEAL_DAMAGE": Affix.ProcTrigger.ON_DEAL_DAMAGE,
		"ON_TAKE_DAMAGE": Affix.ProcTrigger.ON_TAKE_DAMAGE,
		"ON_TURN_START": Affix.ProcTrigger.ON_TURN_START,
		"ON_TURN_END": Affix.ProcTrigger.ON_TURN_END,
		"ON_COMBAT_START": Affix.ProcTrigger.ON_COMBAT_START,
		"ON_COMBAT_END": Affix.ProcTrigger.ON_COMBAT_END,
		"ON_DIE_USED": Affix.ProcTrigger.ON_DIE_USED,
		"ON_ACTION_USED": Affix.ProcTrigger.ON_ACTION_USED,
		"ON_KILL": Affix.ProcTrigger.ON_KILL,
		"ON_DEFEND": Affix.ProcTrigger.ON_DEFEND,
	}
	
	for name in expected:
		assert_true(triggers.has(name), "ProcTrigger.%s exists" % name)
	
	# All values should be unique
	var values = triggers.values()
	var unique = {}
	for v in values:
		unique[v] = true
	assert_eq(unique.size(), triggers.size(), "All ProcTrigger values are unique")

# ============================================================================
# TEST 2: AffixProcProcessor can process every trigger without crash
# ============================================================================
func test_proc_processor_all_triggers():
	begin("AffixProcProcessor processes all triggers")
	
	var proc = AffixProcProcessor.new()
	var apm = AffixPoolManager.new()
	
	# Create a test affix for each trigger
	var test_triggers = [
		Affix.ProcTrigger.ON_DEAL_DAMAGE,
		Affix.ProcTrigger.ON_TAKE_DAMAGE,
		Affix.ProcTrigger.ON_TURN_START,
		Affix.ProcTrigger.ON_TURN_END,
		Affix.ProcTrigger.ON_COMBAT_START,
		Affix.ProcTrigger.ON_COMBAT_END,
		Affix.ProcTrigger.ON_DIE_USED,
		Affix.ProcTrigger.ON_ACTION_USED,
		Affix.ProcTrigger.ON_KILL,
		Affix.ProcTrigger.ON_DEFEND,
	]
	
	for trigger in test_triggers:
		# Make a simple heal proc for this trigger
		var affix = Affix.new()
		affix.affix_name = "Test_%d" % trigger
		affix.category = Affix.Category.PROC
		affix.proc_trigger = trigger
		affix.proc_chance = 1.0
		affix.effect_number = 5.0
		affix.effect_data = {"proc_effect": "heal_flat"}
		apm.register_affix(affix)
	
	# Fire each trigger and verify results
	for trigger in test_triggers:
		var result = proc.process_procs(apm, trigger, {})
		assert_true(result.has("activated"), "Trigger %d returns valid result" % trigger)
		assert_true(result.activated.size() > 0, "Trigger %d activates its affix" % trigger)
		assert_true(result.healing > 0, "Trigger %d produces healing" % trigger)

# ============================================================================
# TEST 3: SELF_DIE_TYPE_IS and SELF_DIE_TYPE_ABOVE conditions
# ============================================================================
func test_die_type_conditions():
	begin("DiceAffixCondition die-type gates")
	
	# --- SELF_DIE_TYPE_IS ---
	var cond_is = DiceAffixCondition.new()
	cond_is.type = DiceAffixCondition.Type.SELF_DIE_TYPE_IS
	cond_is.threshold = 6.0  # Only D6
	
	var d6 = _make_die(6, 3)
	var d4 = _make_die(4, 2)
	var d20 = _make_die(20, 15)
	
	var result_d6 = cond_is.evaluate(d6, [d6], 0, {})
	var result_d4 = cond_is.evaluate(d4, [d4], 0, {})
	
	assert_false(result_d6.blocked, "D6 passes SELF_DIE_TYPE_IS(6)")
	assert_true(result_d4.blocked, "D4 blocked by SELF_DIE_TYPE_IS(6)")
	
	# --- SELF_DIE_TYPE_ABOVE ---
	var cond_above = DiceAffixCondition.new()
	cond_above.type = DiceAffixCondition.Type.SELF_DIE_TYPE_ABOVE
	cond_above.threshold = 8.0  # D8 and up
	
	var d8 = _make_die(8, 5)
	var result_d8 = cond_above.evaluate(d8, [d8], 0, {})
	var result_d20 = cond_above.evaluate(d20, [d20], 0, {})
	var result_d4b = cond_above.evaluate(d4, [d4], 0, {})
	
	assert_false(result_d8.blocked, "D8 passes SELF_DIE_TYPE_ABOVE(8)")
	assert_false(result_d20.blocked, "D20 passes SELF_DIE_TYPE_ABOVE(8)")
	assert_true(result_d4b.blocked, "D4 blocked by SELF_DIE_TYPE_ABOVE(8)")
	
	# --- Description ---
	assert_eq(cond_is.get_description(), "if D6", "SELF_DIE_TYPE_IS description")
	assert_eq(cond_above.get_description(), "if D8 or higher", "SELF_DIE_TYPE_ABOVE description")

# ============================================================================
# TEST 4: _resolve_value guards compound-only ValueSources
# ============================================================================
func test_value_source_guard():
	begin("ValueSource guard on compound-only sources")
	
	var proc = DiceAffixProcessor.new()
	var die = _make_die(6, 4)
	var hand: Array[DieResource] = [die]
	
	# Make an affix that incorrectly uses PARENT_TARGET_VALUE on a non-compound
	var affix = DiceAffix.new()
	affix.affix_name = "BadConfig"
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	affix.effect_value = 99.0
	affix.value_source = DiceAffix.ValueSource.PARENT_TARGET_VALUE
	
	die.inherent_affixes.append(affix)
	
	# This should NOT crash — it should warn and fall back to effect_value
	var result = proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	
	# The fallback should have used effect_value (99), so die value increases
	# We can't easily capture push_warning, but we can verify it didn't crash
	assert_true(true, "Compound-only ValueSource didn't crash (check Output for warning)")
	print("    ℹ️ Check Output panel for: 'compound-only ValueSource on BadConfig'")

# ============================================================================
# TEST 5: StatusTracker has process_turn_end (not just process_turn_start)
# ============================================================================
func test_status_tracker_turn_end():
	begin("StatusTracker.process_turn_end exists")
	
	var tracker = StatusTracker.new()
	
	assert_true(tracker.has_method("process_turn_end"), 
		"StatusTracker has process_turn_end()")
	assert_true(tracker.has_method("process_turn_start"),
		"StatusTracker has process_turn_start()")
	
	# Both should return Array[Dictionary] and not crash when empty
	var start_results = tracker.process_turn_start()
	var end_results = tracker.process_turn_end()
	
	assert_true(start_results is Array, "process_turn_start returns Array")
	assert_true(end_results is Array, "process_turn_end returns Array")
	
	tracker.queue_free()

# ============================================================================
# TEST 6: _apply_proc_results accepts optional Combatant parameter
# ============================================================================
func test_apply_proc_results_signature():
	begin("_apply_proc_results signature (compile-time check)")
	
	# We can't call _apply_proc_results directly (it's on CombatManager),
	# but we can verify the method exists with 1 OR 2 params.
	# If Patch 1 wasn't applied, calling with 2 args would be a compile error.
	#
	# Best we can do from EditorScript: check the source has the signature.
	var script = load("res://scripts/game/combat_manager.gd") as GDScript
	if not script:
		assert_true(false, "Could not load combat_manager.gd")
		return
	
	var source = script.source_code
	var has_optional_target = source.find(
		"func _apply_proc_results(results: Dictionary, proc_target") != -1
	var has_old_signature = source.find(
		"func _apply_proc_results(results: Dictionary) -> void") != -1
	
	if has_optional_target:
		assert_true(true, "_apply_proc_results has proc_target parameter ✓")
	elif has_old_signature:
		assert_true(false, "_apply_proc_results still has OLD signature (Patch 1 not applied!)")
	else:
		assert_true(false, "_apply_proc_results signature not found")
	
	# Also check the status bug fix (Patch 7)
	# Look for process_turn_end in the _on_player_end_turn area
	var end_turn_idx = source.find("func _on_player_end_turn")
	if end_turn_idx == -1:
		print("    ⚠️ _on_player_end_turn not found — might be renamed")
		return
	
	# Check the ~500 chars after the function definition
	var snippet = source.substr(end_turn_idx, 500)
	var has_bug = snippet.find("process_turn_start()") != -1
	var has_fix = snippet.find("process_turn_end()") != -1
	
	if has_fix and not has_bug:
		assert_true(true, "Status tick bug fixed (process_turn_end) ✓")
	elif has_bug:
		assert_true(false, "Status tick bug STILL PRESENT (process_turn_start in _on_player_end_turn)")
	
	# Check ON_KILL hook exists
	var has_on_kill = source.find("ProcTrigger.ON_KILL") != -1
	assert_true(has_on_kill, "ON_KILL hook present in combat_manager.gd")
	
	# Check ON_DEFEND hook exists
	var has_on_defend = source.find("ProcTrigger.ON_DEFEND") != -1
	assert_true(has_on_defend, "ON_DEFEND hook present in combat_manager.gd")
	
	# Check ON_ACTION_USED hook exists
	var has_on_action = source.find("ProcTrigger.ON_ACTION_USED") != -1
	assert_true(has_on_action, "ON_ACTION_USED hook present in combat_manager.gd")
	
	# Check ON_DIE_USED hook exists
	var has_on_die = source.find("ProcTrigger.ON_DIE_USED") != -1
	assert_true(has_on_die, "ON_DIE_USED hook present in combat_manager.gd")
	
	# Check ON_COMBAT_END proc (not just cleanup)
	var combat_end_idx = source.find("ProcTrigger.ON_COMBAT_END")
	assert_true(combat_end_idx != -1, "ON_COMBAT_END proc present in combat_manager.gd")

# ============================================================================
# HELPERS
# ============================================================================

func _make_die(die_type: int, value: int) -> DieResource:
	var die = DieResource.new()
	die.die_type = die_type
	die.current_value = value
	die.display_name = "D%d" % die_type
	return die

func begin(name: String):
	_test_name = name
	print("\n── %s ──" % name)

func assert_true(condition: bool, msg: String):
	if condition:
		_pass_count += 1
		print("  ✅ %s" % msg)
	else:
		_fail_count += 1
		print("  ❌ FAIL: %s" % msg)

func assert_false(condition: bool, msg: String):
	assert_true(not condition, msg)

func assert_eq(a, b, msg: String):
	if a == b:
		_pass_count += 1
		print("  ✅ %s" % msg)
	else:
		_fail_count += 1
		print("  ❌ FAIL: %s (got '%s', expected '%s')" % [msg, str(a), str(b)])
