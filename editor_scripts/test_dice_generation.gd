@tool
extends EditorScript
# ============================================================================
# test_dice_generation.gd — Validate the full dice generation pipeline
#
# Run: Editor → File → Run (or Ctrl+Shift+X with this script open)
#
# Tests:
#   1. Affix .tres files exist (recursive scan of rollable/)
#   2. DiceAffixTable resources load with correct affix counts
#   3. DiceAffixTableRegistry discovers all 9 tables
#   4. DieGenerator produces correct affix counts per rarity  [*]
#   5. Tier gating works (Uncommon=T1, Rare=T1+T2, Epic=T2+T3)  [*]
#   6. Scaling produces values within min/max ranges  [*]
#
#   [*] Tests 4-6 require die_generator.gd to check for a
#       "_test_registry" meta override.  Add this to the TOP of
#       _get_registry() in die_generator.gd:
#
#           if has_meta("_test_registry"):
#               return get_meta("_test_registry")
#
#       Without that, tests 4-6 will be SKIPPED (not failed).
# ============================================================================

const TABLE_DIR := "res://resources/dice_affixes/tables/"
const AFFIX_DIR := "res://resources/dice_affixes/rollable/"

# Expected table → affix count
const EXPECTED_TABLES := {
	"value_tier_1": 5,
	"value_tier_2": 5,
	"value_tier_3": 4,
	"combat_tier_1": 5,
	"combat_tier_2": 5,
	"combat_tier_3": 4,
	"positional_tier_1": 5,
	"positional_tier_2": 5,
	"positional_tier_3": 5,
}

var _pass_count := 0
var _fail_count := 0
var _skip_count := 0

func _run():
	print("")
	print("═" .repeat(60))
	print("  🧪 DICE GENERATION TEST SUITE")
	print("═" .repeat(60))

	_test_affixes_exist()
	_test_tables_load()
	_test_registry_discovery()
	_test_generation_per_rarity()
	_test_tier_gating()
	_test_value_scaling()

	print("")
	print("═" .repeat(60))
	print("  RESULTS: %d passed, %d failed, %d skipped" % [
		_pass_count, _fail_count, _skip_count])
	if _fail_count == 0 and _skip_count == 0:
		print("  ✅ ALL TESTS PASSED")
	elif _fail_count == 0:
		print("  ⚠️ ALL RAN TESTS PASSED (%d skipped)" % _skip_count)
	else:
		print("  ❌ %d FAILURES — see above" % _fail_count)
	print("═" .repeat(60))


# ============================================================================
# TEST 1: Affix .tres files exist (recursive scan)
# ============================================================================
func _test_affixes_exist():
	print("\n── Test 1: Affix resources exist ──")
	var count := _count_tres_recursive(AFFIX_DIR)
	_assert_eq(count, 43, "Affix .tres file count (recursive)")


func _count_tres_recursive(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return 0

	var count := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			if not fname.begins_with("."):
				count += _count_tres_recursive(dir_path.path_join(fname))
		elif fname.ends_with(".tres"):
			count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	return count


# ============================================================================
# TEST 2: Tables load with correct affix counts
# ============================================================================
func _test_tables_load():
	print("\n── Test 2: Tables load correctly ──")
	for tbl_name in EXPECTED_TABLES:
		var path := "%s%s.tres" % [TABLE_DIR, tbl_name]
		if not ResourceLoader.exists(path):
			_fail("Table not found: %s" % path)
			continue

		var table = load(path)
		if not table:
			_fail("Table failed to load: %s" % path)
			continue

		var expected: int = EXPECTED_TABLES[tbl_name]
		var actual: int = table.available_affixes.size()
		_assert_eq(actual, expected, "%s affix count" % tbl_name)


# ============================================================================
# TEST 3: Registry discovers all tables
# ============================================================================
func _test_registry_discovery():
	print("\n── Test 3: Registry discovery ──")
	var registry = _make_registry()
	if not registry:
		_fail("Could not create DiceAffixTableRegistry")
		return

	# Check table count per tier
	var t1: Array = registry.get_tables_for_tier(1)
	var t2: Array = registry.get_tables_for_tier(2)
	var t3: Array = registry.get_tables_for_tier(3)

	_assert_eq(t1.size(), 3, "Tier 1 table count (value+combat+positional)")
	_assert_eq(t2.size(), 3, "Tier 2 table count")
	_assert_eq(t3.size(), 3, "Tier 3 table count")

	# Check total affix count accessible
	var total := 0
	for table in t1:
		total += table.available_affixes.size()
	for table in t2:
		total += table.available_affixes.size()
	for table in t3:
		total += table.available_affixes.size()
	_assert_eq(total, 43, "Total affixes across all tables")


# ============================================================================
# TEST 4: Generation produces correct affix count per rarity
# ============================================================================
func _test_generation_per_rarity():
	print("\n── Test 4: Affix count per rarity ──")

	var expected_counts := {
		EquippableItem.Rarity.COMMON: 0,
		EquippableItem.Rarity.UNCOMMON: 1,
		EquippableItem.Rarity.RARE: 2,
		EquippableItem.Rarity.EPIC: 2,
		EquippableItem.Rarity.LEGENDARY: 2,
	}

	var rarity_names := {
		EquippableItem.Rarity.COMMON: "Common",
		EquippableItem.Rarity.UNCOMMON: "Uncommon",
		EquippableItem.Rarity.RARE: "Rare",
		EquippableItem.Rarity.EPIC: "Epic",
		EquippableItem.Rarity.LEGENDARY: "Legendary",
	}

	# Load a base template
	var template: DieResource = _load_any_template()
	if not template:
		_fail("No base die template found — can't test generation")
		return

	var generator = _make_generator()
	if not generator:
		_skip("Could not set up generator (see note in header)")
		return

	for rarity_val in expected_counts:
		var die: DieResource = generator.generate_from_template(
			template, rarity_val, 15, "test")
		if not die:
			_fail("%s: generate_from_template returned null" % rarity_names[rarity_val])
			continue

		var applied_count: int = die.applied_affixes.size()
		_assert_eq(applied_count, expected_counts[rarity_val],
			"%s applied_affixes count" % rarity_names[rarity_val])

		# Print what rolled
		if applied_count > 0:
			for affix in die.applied_affixes:
				var val_str := ""
				if affix.has_method("has_scaling") and affix.has_scaling():
					val_str = "[%.2f – %.2f] = %.2f" % [
						affix.effect_value_min, affix.effect_value_max, affix.effect_value]
				else:
					val_str = str(affix.effect_value)
				print("     🔹 %s (T%d): %s" % [affix.affix_name, affix.affix_tier, val_str])


# ============================================================================
# TEST 5: Tier gating — correct tiers per rarity
# ============================================================================
func _test_tier_gating():
	print("\n── Test 5: Tier gating ──")

	var template: DieResource = _load_any_template()
	if not template:
		_fail("No base die template")
		return

	var generator = _make_generator()
	if not generator:
		_skip("Could not set up generator (see note in header)")
		return

	# Run multiple samples to be confident
	var samples := 10

	# Uncommon: all affixes should be T1
	print("  Uncommon (expect all T1):")
	for i in samples:
		var die: DieResource = generator.generate_from_template(
			template, EquippableItem.Rarity.UNCOMMON, 15, "test")
		for affix in die.applied_affixes:
			if affix.affix_tier != 1:
				_fail("Uncommon rolled T%d affix: %s" % [affix.affix_tier, affix.affix_name])
				return
	_pass("Uncommon: %d samples all T1" % samples)

	# Rare: should be T1 + T2
	print("  Rare (expect T1 + T2):")
	var rare_tiers_seen := {}
	for i in samples:
		var die: DieResource = generator.generate_from_template(
			template, EquippableItem.Rarity.RARE, 15, "test")
		for affix in die.applied_affixes:
			rare_tiers_seen[affix.affix_tier] = true
			if affix.affix_tier < 1 or affix.affix_tier > 2:
				_fail("Rare rolled T%d affix: %s" % [affix.affix_tier, affix.affix_name])
				return
	_pass("Rare: %d samples all T1-T2 (saw tiers: %s)" % [samples, rare_tiers_seen.keys()])

	# Epic: should be T2 + T3
	print("  Epic (expect T2 + T3):")
	var epic_tiers_seen := {}
	for i in samples:
		var die: DieResource = generator.generate_from_template(
			template, EquippableItem.Rarity.EPIC, 15, "test")
		for affix in die.applied_affixes:
			epic_tiers_seen[affix.affix_tier] = true
			if affix.affix_tier < 2 or affix.affix_tier > 3:
				_fail("Epic rolled T%d affix: %s" % [affix.affix_tier, affix.affix_name])
				return
	_pass("Epic: %d samples all T2-T3 (saw tiers: %s)" % [samples, epic_tiers_seen.keys()])


# ============================================================================
# TEST 6: Value scaling — rolled values within min/max
# ============================================================================
func _test_value_scaling():
	print("\n── Test 6: Value scaling ──")

	var template: DieResource = _load_any_template()
	if not template:
		_fail("No base die template")
		return

	var generator = _make_generator()
	if not generator:
		_skip("Could not set up generator (see note in header)")
		return

	var violations := 0
	var checked := 0
	var samples := 20

	for i in samples:
		# Test at various levels
		var level: int = randi_range(1, 100)
		var rarity: int = [EquippableItem.Rarity.RARE, EquippableItem.Rarity.EPIC].pick_random()
		var die: DieResource = generator.generate_from_template(
			template, rarity, level, "test")

		for affix in die.applied_affixes:
			if affix.has_method("has_scaling") and affix.has_scaling():
				checked += 1
				var val: float = affix.effect_value
				# Allow small float tolerance
				if val < affix.effect_value_min - 0.01 or val > affix.effect_value_max + 0.01:
					violations += 1
					_fail("  %s: value %.2f outside [%.2f, %.2f] at Lv.%d" % [
						affix.affix_name, val, affix.effect_value_min,
						affix.effect_value_max, level])

	if violations == 0:
		_pass("All %d scaled values within range (%d samples)" % [checked, samples])


# ============================================================================
# HELPERS — Build test instances without autoloads
# ============================================================================

func _make_registry():
	"""Create and populate a DiceAffixTableRegistry manually."""
	var script_path := "res://scripts/autoload/dice_affix_table_registry.gd"
	if not ResourceLoader.exists(script_path):
		push_error("DiceAffixTableRegistry script not found at %s" % script_path)
		return null

	var script = load(script_path)
	var registry = script.new()

	# Call _ready() equivalent — the registry should scan TABLE_DIR on init
	if registry.has_method("_ready"):
		registry._ready()

	return registry


func _make_generator():
	"""Create a DieGenerator wired to a fresh registry.

	Since we're in an EditorScript, autoloads aren't available.
	We set meta("_test_registry") on the generator instance.

	IMPORTANT: die_generator.gd's _get_registry() must check for this:
		if has_meta("_test_registry"):
			return get_meta("_test_registry")
	Without that line, this returns null and tests 4-6 are skipped.
	"""
	var registry = _make_registry()
	if not registry:
		return null

	var gen_script_path := "res://scripts/autoload/die_generator.gd"
	if not ResourceLoader.exists(gen_script_path):
		push_error("DieGenerator script not found at %s" % gen_script_path)
		return null

	var gen_script = load(gen_script_path)
	var generator = gen_script.new()

	# Stamp meta — generator's _get_registry() must check for this
	generator.set_meta("_test_registry", registry)

	# Quick sanity: try a trivial generate to confirm the registry link works.
	# If _get_registry() doesn't read meta, it returns null and generate fails.
	var probe_template: DieResource = _load_any_template()
	if probe_template:
		var probe = generator.generate_from_template(
			probe_template, EquippableItem.Rarity.COMMON, 1, "_probe")
		if probe == null:
			push_warning("DieGenerator could not generate — _get_registry() may not read meta. "
				+ "Add meta check to _get_registry() in die_generator.gd (see test header).")
			return null

	return generator


func _load_any_template() -> DieResource:
	"""Load any available base die template for testing."""
	# Try common ones first
	for candidate in ["d6_none", "d6_fire", "d8_none", "d4_none"]:
		var path := "res://resources/dice/base/%s.tres" % candidate
		if ResourceLoader.exists(path):
			return load(path)

	# Fallback: scan the directory
	var dir := DirAccess.open("res://resources/dice/base/")
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				return load("res://resources/dice/base/%s" % fname)
			fname = dir.get_next()
	return null


# ============================================================================
# ASSERTION HELPERS
# ============================================================================

func _assert_eq(actual, expected, label: String):
	if actual == expected:
		_pass("%s = %s" % [label, str(actual)])
	else:
		_fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _pass(msg: String = ""):
	_pass_count += 1
	if msg:
		print("  ✅ %s" % msg)


func _fail(msg: String):
	_fail_count += 1
	print("  ❌ %s" % msg)


func _skip(msg: String):
	_skip_count += 1
	print("  ⏭️ SKIP: %s" % msg)
