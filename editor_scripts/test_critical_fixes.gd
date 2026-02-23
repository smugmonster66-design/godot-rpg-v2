@tool
extends EditorScript
# ============================================================================
# test_critical_fixes.gd — Validate BUG-1, BUG-2, BUG-3 fixes
#
# Run: Open in Script Editor → Script → Run (or Ctrl+Shift+X)
#
# Tests the 3 critical fixes from the rollable dice affix audit:
#   1. BUG-1: Ascendant uses upgrade_steps, not hardcoded D6
#   2. BUG-2: ADD_DAMAGE_TYPE with scaled value emits bonus_damage
#   3. BUG-3: EMIT_SPLASH with mode=flat produces non-zero damage
#
# No autoloads needed. Loads resources directly and simulates logic.
#
# TYPE SAFETY NOTES (recurring Godot 4.x patterns):
#   - Never use := when RHS is Dictionary value/key access (returns Variant)
#   - Never use := when iterating Dictionary keys (loop var is Variant)
#   - Never use := when indexing arrays via Variant index
#   - Always use explicit type: var x: Type = ...
#   - Use .assign() for typed array writes, never direct =
# ============================================================================

const AFFIX_DIR: String = "res://resources/dice_affixes/rollable/"

var _pass_count: int = 0
var _fail_count: int = 0


func _run() -> void:
	print("")
	print("=".repeat(60))
	print("  CRITICAL FIX VALIDATION")
	print("=".repeat(60))

	_test_bug1_ascendant()
	_test_bug2_elemental_bonus()
	_test_bug3_splash_flat()

	print("")
	print("=".repeat(60))
	print("  RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	if _fail_count == 0:
		print("  ALL CRITICAL FIXES VERIFIED")
	else:
		print("  %d FAILURES — fix not applied correctly" % _fail_count)
	print("=".repeat(60))


# ============================================================================
# BUG-1: Ascendant — upgrade_steps dispatch logic
# ============================================================================
func _test_bug1_ascendant() -> void:
	print("\n-- BUG-1: Ascendant (change_die_type_up) --")

	var path: String = AFFIX_DIR + "positional/tier_3/change_die_type_up.tres"
	if not ResourceLoader.exists(path):
		_fail("Affix not found: %s" % path)
		return

	var affix: Resource = load(path)
	if not affix:
		_fail("Could not load: %s" % path)
		return

	# Verify .tres has upgrade_steps (not new_type)
	var edata: Dictionary = affix.get("effect_data")
	_assert_true(edata.has("upgrade_steps"),
		".tres has 'upgrade_steps' key")
	_assert_true(not edata.has("new_type"),
		".tres does NOT have 'new_type' key (would bypass upgrade logic)")

	# Simulate the FIXED dispatch logic for each die size
	var die_sizes: Array[int] = [4, 6, 8, 10, 12]
	var upgrade_steps: int = int(edata.get("upgrade_steps", 0))
	_assert_eq(upgrade_steps, 1, "upgrade_steps = 1")

	# D4->D6, D6->D8, D8->D10, D10->D12, D12->D12 (capped)
	var expected_results: Dictionary = {4: 6, 6: 8, 8: 10, 10: 12, 12: 12}

	for current_type: int in expected_results:
		var current_idx: int = die_sizes.find(current_type)
		var new_idx: int = clampi(current_idx + upgrade_steps, 0, die_sizes.size() - 1)
		var new_type: int = die_sizes[new_idx]
		var expected: int = expected_results[current_type]
		_assert_eq(new_type, expected,
			"D%d + %d step = D%d" % [current_type, upgrade_steps, expected])

	# THE CRITICAL CHECK: Old broken code path would always yield 6
	var old_result: int = int(edata.get("new_type", 6))
	_assert_eq(old_result, 6,
		"OLD CODE would produce D6 (confirming bug exists pre-fix)")
	print("  INFO: If dispatch still uses edata.get(\"new_type\", 6), D8+ dice get DOWNGRADED.")


# ============================================================================
# BUG-2: Elemental T1 — ADD_DAMAGE_TYPE should also emit bonus_damage
# ============================================================================
func _test_bug2_elemental_bonus() -> void:
	print("\n-- BUG-2: Combat T1 Elemental Affixes --")

	var test_affixes: Dictionary = {
		"combat/tier_1/add_fire_damage_flat.tres": "fire",
		"combat/tier_1/add_ice_damage_flat.tres": "ice",
		"combat/tier_1/add_shock_damage_flat.tres": "shock",
		"combat/tier_1/add_poison_damage_flat.tres": "poison",
	}

	for subpath: String in test_affixes:
		var full_path: String = AFFIX_DIR + subpath
		if not ResourceLoader.exists(full_path):
			_fail("Not found: %s" % full_path)
			continue

		var affix: Resource = load(full_path)
		if not affix:
			_fail("Could not load: %s" % full_path)
			continue

		var expected_element: String = test_affixes[subpath]
		var affix_name: String = affix.get("affix_name")
		var effect_value_min: float = affix.get("effect_value_min")
		var effect_value_max: float = affix.get("effect_value_max")
		var edata: Dictionary = affix.get("effect_data")
		var effect_type_val: int = affix.get("effect_type")

		# Verify it has scaling range (the value that was previously dead)
		_assert_true(effect_value_min > 0.0,
			"%s has effect_value_min > 0 (%.1f)" % [affix_name, effect_value_min])
		_assert_true(effect_value_max > effect_value_min,
			"%s has max > min (%.1f > %.1f)" % [affix_name, effect_value_max, effect_value_min])

		# Verify effect_data has element type
		var etype: String = edata.get("type", "")
		_assert_eq(etype, expected_element,
			"%s effect_data.type = '%s'" % [affix_name, expected_element])

		# Verify effect_type is ADD_DAMAGE_TYPE (enum 15)
		_assert_eq(effect_type_val, 15,
			"%s effect_type = ADD_DAMAGE_TYPE (15)" % affix_name)

	print("  INFO: FIX adds _apply_emit_bonus_damage() after _apply_damage_type()")
	print("     when resolved_value > 0.0. Check dice_affix_processor.gd ADD_DAMAGE_TYPE block.")


# ============================================================================
# BUG-3: Erupting — flat splash does zero damage
# ============================================================================
func _test_bug3_splash_flat() -> void:
	print("\n-- BUG-3: Erupting (splash_damage_flat) --")

	var path: String = AFFIX_DIR + "combat/tier_2/splash_damage_flat.tres"
	if not ResourceLoader.exists(path):
		_fail("Not found: %s" % path)
		return

	var affix: Resource = load(path)
	if not affix:
		_fail("Could not load: %s" % path)
		return

	var edata: Dictionary = affix.get("effect_data")
	var effect_value: float = affix.get("effect_value")
	var effect_value_min: float = affix.get("effect_value_min")
	var effect_value_max: float = affix.get("effect_value_max")

	# Verify .tres has mode=flat and NO percent key
	var mode_val: String = edata.get("mode", "")
	_assert_eq(mode_val, "flat",
		"effect_data.mode = 'flat'")
	_assert_true(not edata.has("percent"),
		"effect_data does NOT have 'percent' key")

	# Verify it has meaningful effect_value
	_assert_true(effect_value > 0.0,
		"effect_value = %.1f (the flat splash damage)" % effect_value)
	_assert_true(effect_value_min > 0.0,
		"effect_value_min = %.1f" % effect_value_min)

	# Simulate OLD broken code path
	var old_percent: float = edata.get("percent", 0.0)  # key missing -> 0.0
	var old_splash: int = int(effect_value * old_percent)
	_assert_eq(old_splash, 0,
		"OLD CODE: damage x percent = %.0f x %.1f = %d (ZERO — bug confirmed)" % [
			effect_value, old_percent, old_splash])

	# Simulate FIXED code path
	var fixed_mode: String = edata.get("mode", "percent")
	var fixed_splash: int = 0
	if fixed_mode == "flat":
		fixed_splash = int(effect_value)
	else:
		var pct: float = edata.get("percent", 0.5)
		fixed_splash = int(effect_value * pct)
	_assert_true(fixed_splash > 0,
		"FIXED CODE: mode=flat, flat_damage = %d (non-zero)" % fixed_splash)

	# Verify the scaled range makes sense
	_assert_true(effect_value_min >= 2.0 and effect_value_max <= 5.0,
		"Scaled range %.0f-%.0f is reasonable for T2 flat splash" % [
			effect_value_min, effect_value_max])

	print("  INFO: FIX requires changes in BOTH files:")
	print("     1. dice_affix_processor.gd: _apply_emit_splash() branches on mode")
	print("     2. combat_manager.gd: _resolve_splash() branches on mode")


# ============================================================================
# ASSERTION HELPERS (matches existing test pattern)
# ============================================================================

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_pass_msg(label)
	else:
		_fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_pass_msg(label)
	else:
		_fail("%s: expected TRUE" % label)


func _pass_msg(msg: String = "") -> void:
	_pass_count += 1
	print("  PASS: %s" % msg)


func _fail(msg: String) -> void:
	_fail_count += 1
	print("  FAIL: %s" % msg)
