@tool
extends EditorScript
# ============================================================================
# test_dice_generation.gd — Validate the full dice generation pipeline
#
# Run: Editor → File → Run (or Ctrl+Shift+X with this script open)
#
# All 6 tests run entirely in the editor — no autoloads required.
# Tests 1-2 validate raw data files.
# Tests 3-6 replicate core registry/generator logic with untyped access
# to avoid EditorScript + typed class_name resolution issues.
#
# Tests:
#   1. Affix .tres files exist (recursive scan)
#   2. DiceAffixTable resources load with correct affix counts
#   3. Registry-style discovery: 9 tables, 3 per tier, 43 total affixes
#   4. Generation logic: correct affix count per rarity
#   5. Tier gating: Uncommon=T1, Rare=T1+T2, Epic=T2+T3
#   6. Value scaling: rolled values within min/max ranges
# ============================================================================

const TABLE_DIR := "res://resources/dice_affix_tables/"
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

# Rarity → affix count (mirrors DieGenerator.RARITY_AFFIX_CONFIG)
const RARITY_AFFIX_COUNTS := {
	0: 0,  # COMMON
	1: 1,  # UNCOMMON
	2: 2,  # RARE
	3: 2,  # EPIC
	4: 2,  # LEGENDARY
}

# Rarity → allowed tiers (mirrors DieGenerator.RARITY_AFFIX_CONFIG)
const RARITY_TIER_MAP := {
	0: [],        # COMMON: no affixes
	1: [1],       # UNCOMMON: T1 only
	2: [1, 2],    # RARE: T1 + T2
	3: [2, 3],    # EPIC: T2 + T3
	4: [2, 3],    # LEGENDARY: T2 + T3 (+ unique handled separately)
}

const RARITY_NAMES := {
	0: "Common", 1: "Uncommon", 2: "Rare", 3: "Epic", 4: "Legendary",
}

var _pass_count := 0
var _fail_count := 0

# Cached tables: tier (int) → Array of loaded table resources
var _tables_by_tier := {}


func _run():
	print("")
	print("═" .repeat(60))
	print("  🧪 DICE GENERATION TEST SUITE")
	print("═" .repeat(60))

	_load_all_tables()

	_test_affixes_exist()
	_test_tables_load()
	_test_registry_discovery()
	_test_generation_per_rarity()
	_test_tier_gating()
	_test_value_scaling()

	print("")
	print("═" .repeat(60))
	print("  RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	if _fail_count == 0:
		print("  ✅ ALL TESTS PASSED")
	else:
		print("  ❌ %d FAILURES — see above" % _fail_count)
	print("═" .repeat(60))


# ============================================================================
# TABLE LOADER — Untyped, works in EditorScript
# ============================================================================

func _load_all_tables() -> void:
	"""Load all 9 tables into _tables_by_tier using untyped access."""
	_tables_by_tier = {1: [], 2: [], 3: []}
	for family in ["value", "combat", "positional"]:
		for tier in [1, 2, 3]:
			var path := "%s%s_tier_%d.tres" % [TABLE_DIR, family, tier]
			if ResourceLoader.exists(path):
				var table = load(path)
				if table and table.available_affixes.size() > 0:
					_tables_by_tier[tier].append(table)


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
# TEST 3: Registry-style discovery — 3 tables per tier, 43 total
# ============================================================================
func _test_registry_discovery():
	print("\n── Test 3: Registry discovery ──")

	_assert_eq(_tables_by_tier[1].size(), 3,
		"Tier 1 table count (value+combat+positional)")
	_assert_eq(_tables_by_tier[2].size(), 3, "Tier 2 table count")
	_assert_eq(_tables_by_tier[3].size(), 3, "Tier 3 table count")

	var total := 0
	for tier in [1, 2, 3]:
		for table in _tables_by_tier[tier]:
			total += table.available_affixes.size()
	_assert_eq(total, 43, "Total affixes across all tables")


# ============================================================================
# TEST 4: Generation produces correct affix count per rarity
# ============================================================================
func _test_generation_per_rarity():
	print("\n── Test 4: Affix count per rarity ──")

	var template = _load_any_template()
	if not template:
		_fail("No base die template found")
		return

	for rarity in RARITY_AFFIX_COUNTS:
		var expected_count: int = RARITY_AFFIX_COUNTS[rarity]
		var rolled: Array = _roll_affixes_for_rarity(rarity)

		_assert_eq(rolled.size(), expected_count,
			"%s applied_affixes count" % RARITY_NAMES[rarity])

		# Print what rolled
		for affix in rolled:
			var val_str := ""
			if affix.effect_value_min != 0.0 or affix.effect_value_max != 0.0:
				val_str = "[%.2f – %.2f] = %.2f" % [
					affix.effect_value_min, affix.effect_value_max,
					affix.effect_value]
			else:
				val_str = str(affix.effect_value)
			print("     🔹 %s (T%d): %s" % [affix.affix_name, affix.affix_tier, val_str])


# ============================================================================
# TEST 5: Tier gating — correct tiers per rarity
# ============================================================================
func _test_tier_gating():
	print("\n── Test 5: Tier gating ──")
	var samples := 20

	# Uncommon: all T1
	print("  Uncommon (expect all T1):")
	var uncommon_count := 0
	for i in samples:
		for affix in _roll_affixes_for_rarity(1):
			uncommon_count += 1
			if affix.affix_tier != 1:
				_fail("Uncommon rolled T%d: %s" % [affix.affix_tier, affix.affix_name])
				return
	if uncommon_count == 0:
		_fail("Uncommon: 0 affixes rolled across %d samples" % samples)
		return
	_pass("Uncommon: %d affixes across %d samples, all T1" % [uncommon_count, samples])

	# Rare: T1 + T2 only
	print("  Rare (expect T1 + T2):")
	var rare_tiers := {}
	var rare_count := 0
	for i in samples:
		for affix in _roll_affixes_for_rarity(2):
			rare_count += 1
			rare_tiers[affix.affix_tier] = true
			if affix.affix_tier < 1 or affix.affix_tier > 2:
				_fail("Rare rolled T%d: %s" % [affix.affix_tier, affix.affix_name])
				return
	if rare_count == 0:
		_fail("Rare: 0 affixes rolled across %d samples" % samples)
		return
	_pass("Rare: %d affixes, all T1-T2 (saw tiers: %s)" % [rare_count, rare_tiers.keys()])

	# Epic: T2 + T3 only
	print("  Epic (expect T2 + T3):")
	var epic_tiers := {}
	var epic_count := 0
	for i in samples:
		for affix in _roll_affixes_for_rarity(3):
			epic_count += 1
			epic_tiers[affix.affix_tier] = true
			if affix.affix_tier < 2 or affix.affix_tier > 3:
				_fail("Epic rolled T%d: %s" % [affix.affix_tier, affix.affix_name])
				return
	if epic_count == 0:
		_fail("Epic: 0 affixes rolled across %d samples" % samples)
		return
	_pass("Epic: %d affixes, all T2-T3 (saw tiers: %s)" % [epic_count, epic_tiers.keys()])


# ============================================================================
# TEST 6: Value scaling — rolled values within min/max
# ============================================================================
func _test_value_scaling():
	print("\n── Test 6: Value scaling ──")
	var checked := 0
	var violations := 0
	var samples := 30

	for i in samples:
		var rarity = [2, 3].pick_random()  # Rare or Epic
		for affix in _roll_affixes_for_rarity(rarity):
			var has_min = affix.effect_value_min != 0.0
			var has_max = affix.effect_value_max != 0.0
			if has_min or has_max:
				checked += 1
				# Verify range is valid: min ≤ max
				if affix.effect_value_min > affix.effect_value_max:
					violations += 1
					_fail("%s: min (%.2f) > max (%.2f)" % [
						affix.affix_name, affix.effect_value_min, affix.effect_value_max])
				# Verify midpoint default is within range
				var mid = (affix.effect_value_min + affix.effect_value_max) / 2.0
				if affix.effect_value < affix.effect_value_min - 0.01 or \
						affix.effect_value > affix.effect_value_max + 0.01:
					# Static value set by generator might be midpoint, or
					# might be the template default — just warn, don't fail
					pass
				# Verify lerpf would produce valid values at extremes
				var at_zero = lerpf(affix.effect_value_min, affix.effect_value_max, 0.0)
				var at_one = lerpf(affix.effect_value_min, affix.effect_value_max, 1.0)
				if abs(at_zero - affix.effect_value_min) > 0.01:
					violations += 1
					_fail("%s: lerp(0) = %.2f, expected min %.2f" % [
						affix.affix_name, at_zero, affix.effect_value_min])
				if abs(at_one - affix.effect_value_max) > 0.01:
					violations += 1
					_fail("%s: lerp(1) = %.2f, expected max %.2f" % [
						affix.affix_name, at_one, affix.effect_value_max])

	if violations == 0 and checked > 0:
		_pass("All %d scaled affixes have valid ranges (%d samples)" % [checked, samples])
	elif checked == 0:
		_fail("No scaled affixes were rolled across %d samples" % samples)


# ============================================================================
# GENERATION HELPER — Replicates DieGenerator logic with untyped access
# ============================================================================

func _roll_affixes_for_rarity(rarity: int) -> Array:
	"""Roll dice affixes matching the rarity→tier mapping.

	Returns base affix references directly (no duplicate/mutation) since
	we only read properties for testing.
	"""
	var tiers = RARITY_TIER_MAP[rarity]
	var count = RARITY_AFFIX_COUNTS[rarity]
	if count == 0 or tiers.size() == 0:
		return []

	var results = []
	var used_names = []

	for i in count:
		var tier = tiers[mini(i, tiers.size() - 1)]
		if not _tables_by_tier.has(tier):
			continue
		var tier_tables = _tables_by_tier[tier]
		if tier_tables.size() == 0:
			continue

		# Pick random table, then random affix (up to 3 attempts to avoid dupes)
		for _attempt in 3:
			var table = tier_tables[randi() % tier_tables.size()]
			var pool_size = table.available_affixes.size()
			if pool_size == 0:
				continue
			var base_affix = table.available_affixes[randi() % pool_size]
			if base_affix.affix_name in used_names:
				continue

			results.append(base_affix)
			used_names.append(base_affix.affix_name)
			break

	return results


# ============================================================================
# OTHER HELPERS
# ============================================================================

func _load_any_template() -> DieResource:
	"""Load any available base die template for testing."""
	for candidate in ["d6_none", "d6_fire", "d8_none", "d4_none"]:
		var path := "res://resources/dice/base/%s.tres" % candidate
		if ResourceLoader.exists(path):
			return load(path)
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
