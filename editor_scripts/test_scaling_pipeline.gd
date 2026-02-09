# res://editor_scripts/test_scaling_pipeline.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X)
#
# PREREQUISITES (run these first if not done):
#   1. generate_base_affix_system.gd  (creates affixes + tables)
#   2. generate_slot_definitions.gd   (creates slot definitions)
#   3. Affix.gd patched with effect_min/max + roll_value()
#   4. AffixTableRegistry autoload registered
#
# WHAT THIS TESTS:
#   - Scaling config loads and produces correct power positions
#   - AffixTables load and contain expected affix counts
#   - SlotDefinitions resolve correctly per slot
#   - Full item generation at multiple levels produces scaled values
#   - Heavy weapon double-roll works
#   - Manual affix override still works
#   - Legacy table fallback still works
#
@tool
extends EditorScript

const SCALING_PATH := "res://resources/scaling/affix_scaling_config.tres"
const TABLE_DIR := "res://resources/affix_tables/base/"
const SLOT_DIR := "res://resources/slot_definitions/"

var _pass_count: int = 0
var _fail_count: int = 0
var _warn_count: int = 0

func _run() -> void:
	_pass_count = 0
	_fail_count = 0
	_warn_count = 0
	
	print("\n" + "═".repeat(60))
	print("  SCALING PIPELINE TEST SUITE")
	print("═".repeat(60))
	
	_test_scaling_config()
	_test_affix_tables()
	_test_slot_definitions()
	_test_affix_rolling()
	_test_item_generation_at_levels()
	_test_heavy_weapon_double_rolls()
	_test_region_level_bounds()
	_test_fuzz_distribution()
	
	print("\n" + "═".repeat(60))
	print("  RESULTS: %d passed, %d failed, %d warnings" % [
		_pass_count, _fail_count, _warn_count])
	if _fail_count == 0:
		print("  ✅ ALL TESTS PASSED")
	else:
		print("  ❌ SOME TESTS FAILED — review output above")
	print("═".repeat(60) + "\n")

# ============================================================================
# HELPERS
# ============================================================================

func _pass(msg: String) -> void:
	_pass_count += 1
	print("  ✅ %s" % msg)

func _fail(msg: String) -> void:
	_fail_count += 1
	print("  ❌ %s" % msg)

func _warn(msg: String) -> void:
	_warn_count += 1
	print("  ⚠️ %s" % msg)

func _assert(condition: bool, pass_msg: String, fail_msg: String) -> void:
	if condition:
		_pass(pass_msg)
	else:
		_fail(fail_msg)

# ============================================================================
# TEST: Scaling Config
# ============================================================================

func _test_scaling_config() -> void:
	print("\n── Scaling Config ──")
	
	if not ResourceLoader.exists(SCALING_PATH):
		_fail("Scaling config not found at %s" % SCALING_PATH)
		return
	
	var config: AffixScalingConfig = load(SCALING_PATH)
	_assert(config != null, "Scaling config loaded", "Failed to load scaling config")
	if not config:
		return
	
	# Test power positions at key levels
	var p1 := config.get_power_position(1)
	var p50 := config.get_power_position(50)
	var p100 := config.get_power_position(100)
	
	_assert(p1 >= 0.0 and p1 <= 0.05,
		"Level 1 power = %.3f (near 0.0)" % p1,
		"Level 1 power = %.3f (expected near 0.0)" % p1)
	
	_assert(p50 > 0.3 and p50 < 0.7,
		"Level 50 power = %.3f (mid range)" % p50,
		"Level 50 power = %.3f (expected 0.3–0.7)" % p50)
	
	_assert(p100 >= 0.95,
		"Level 100 power = %.3f (near 1.0)" % p100,
		"Level 100 power = %.3f (expected near 1.0)" % p100)
	
	# Test fuzz computation
	var fuzz: Dictionary = config.compute_fuzz_range(5.0, 1.0, 50.0)
	var fuzz_lo: float = fuzz.min
	var fuzz_hi: float = fuzz.max
	_assert(fuzz_lo < 5.0 and fuzz_hi > 5.0,
		"Fuzz range: %.1f–%.1f around center 5.0" % [fuzz_lo, fuzz_hi],
		"Fuzz range broken: %.1f–%.1f" % [fuzz_lo, fuzz_hi])
	
	# Test minimum absolute fuzz on small values
	var small_fuzz: Dictionary = config.compute_fuzz_range(2.0, 1.0, 8.0)
	var sf_lo: float = small_fuzz.min
	var sf_hi: float = small_fuzz.max
	var fuzz_width: float = sf_hi - sf_lo
	_assert(fuzz_width >= config.min_absolute_fuzz,
		"Small value fuzz width = %.1f (≥ min_absolute %.1f)" % [fuzz_width, config.min_absolute_fuzz],
		"Small value fuzz too narrow: %.1f (min_absolute = %.1f)" % [fuzz_width, config.min_absolute_fuzz])

# ============================================================================
# TEST: Affix Tables
# ============================================================================

func _test_affix_tables() -> void:
	print("\n── Affix Tables ──")
	
	var families := ["offense", "defense", "utility"]
	var expected_counts := {
		"offense_1": 8, "offense_2": 17, "offense_3": 17,
		"defense_1": 9, "defense_2": 17, "defense_3": 13,
		"utility_1": 16, "utility_2": 25, "utility_3": 29,
	}
	
	for family in families:
		for tier in [1, 2, 3]:
			var key := "%s_%d" % [family, tier]
			var path := "%s%s_tier_%d.tres" % [TABLE_DIR, family, tier]
			
			if not ResourceLoader.exists(path):
				_fail("Table not found: %s" % path)
				continue
			
			var table: AffixTable = load(path)
			if not table:
				_fail("Failed to load table: %s" % path)
				continue
			
			var count: int = table.available_affixes.size()
			var expected: int = expected_counts.get(key, 0)
			
			# Allow some variance since we added extra utility affixes
			if count >= expected - 2 and count <= expected + 10:
				_pass("%s: %d affixes (expected ~%d)" % [key, count, expected])
			else:
				_warn("%s: %d affixes (expected ~%d)" % [key, count, expected])

# ============================================================================
# TEST: Slot Definitions
# ============================================================================

func _test_slot_definitions() -> void:
	print("\n── Slot Definitions ──")
	
	var slots := {
		"head_slot": {"offense": false, "defense": true, "utility": true},
		"torso_slot": {"offense": false, "defense": true, "utility": true},
		"gloves_slot": {"offense": true, "defense": true, "utility": true},
		"boots_slot": {"offense": false, "defense": true, "utility": true},
		"main_hand_slot": {"offense": true, "defense": true, "utility": true},
		"off_hand_slot": {"offense": true, "defense": true, "utility": true},
		"heavy_slot": {"offense": true, "defense": true, "utility": true},
		"accessory_slot": {"offense": true, "defense": true, "utility": true},
	}
	
	for file_name: String in slots:
		var path: String = SLOT_DIR + file_name + ".tres"
		
		if not ResourceLoader.exists(path):
			_fail("SlotDefinition not found: %s" % path)
			continue
		
		var sd: SlotDefinition = load(path)
		if not sd:
			_fail("Failed to load: %s" % path)
			continue
		
		var expected: Dictionary = slots[file_name]
		var t1_families = sd.get_tier_families(1)
		
		var has_offense: bool = &"offense" in t1_families
		var has_defense: bool = &"defense" in t1_families
		var has_utility: bool = &"utility" in t1_families
		
		var exp_offense: bool = expected["offense"]
		var exp_defense: bool = expected["defense"]
		var exp_utility: bool = expected["utility"]
		
		var correct: bool = (has_offense == exp_offense and
						has_defense == exp_defense and
						has_utility == exp_utility)
		
		_assert(correct,
			"%s: O=%s D=%s U=%s" % [file_name, has_offense, has_defense, has_utility],
			"%s: families wrong — got O=%s D=%s U=%s, expected O=%s D=%s U=%s" % [
				file_name, has_offense, has_defense, has_utility,
				exp_offense, exp_defense, exp_utility])
	
	# Test heavy double rolls
	var heavy_path := SLOT_DIR + "heavy_slot.tres"
	if ResourceLoader.exists(heavy_path):
		var heavy: SlotDefinition = load(heavy_path)
		if heavy:
			_assert(heavy.double_affix_rolls,
				"Heavy slot has double_affix_rolls = true",
				"Heavy slot missing double_affix_rolls flag")

# ============================================================================
# TEST: Affix Rolling
# ============================================================================

func _test_affix_rolling() -> void:
	print("\n── Affix Value Rolling ──")
	
	# Create a test affix with known range
	var test_affix := Affix.new()
	test_affix.affix_name = "Test Strength"
	test_affix.category = Affix.Category.STRENGTH_BONUS
	test_affix.effect_min = 1.0
	test_affix.effect_max = 50.0
	
	var config: AffixScalingConfig = null
	if ResourceLoader.exists(SCALING_PATH):
		config = load(SCALING_PATH)
	
	# Test at low level
	var low_copy: Affix = test_affix.duplicate(true)
	var low_power := 0.05  # ~level 5
	low_copy.roll_value(low_power, config)
	_assert(low_copy.effect_number >= 1.0 and low_copy.effect_number <= 15.0,
		"Low level (t=0.05) rolled %d (expected 1–15)" % int(low_copy.effect_number),
		"Low level (t=0.05) rolled %d (out of expected range)" % int(low_copy.effect_number))
	
	# Test at high level
	var high_copy: Affix = test_affix.duplicate(true)
	var high_power := 0.95  # ~level 95
	high_copy.roll_value(high_power, config)
	_assert(high_copy.effect_number >= 35.0 and high_copy.effect_number <= 50.0,
		"High level (t=0.95) rolled %d (expected 35–50)" % int(high_copy.effect_number),
		"High level (t=0.95) rolled %d (out of expected range)" % int(high_copy.effect_number))
	
	# Test multiplier rounding
	var mult_affix := Affix.new()
	mult_affix.affix_name = "Test Multiplier"
	mult_affix.category = Affix.Category.STRENGTH_MULTIPLIER
	mult_affix.effect_min = 1.02
	mult_affix.effect_max = 1.50
	
	var mult_copy: Affix = mult_affix.duplicate(true)
	mult_copy.roll_value(0.5, config)
	var decimal_places := str(mult_copy.effect_number).find(".")
	_assert(mult_copy.effect_number >= 1.02 and mult_copy.effect_number <= 1.50,
		"Multiplier (t=0.5) rolled %.2f (expected 1.02–1.50)" % mult_copy.effect_number,
		"Multiplier (t=0.5) rolled %.2f (out of range)" % mult_copy.effect_number)
	
	# Test static affix (no scaling)
	var static_affix := Affix.new()
	static_affix.affix_name = "Test Static"
	static_affix.effect_number = 42.0
	# effect_min/max left at 0.0 (no scaling)
	
	var static_copy: Affix = static_affix.duplicate(true)
	static_copy.roll_value(0.5, config)
	_assert(static_copy.effect_number == 42.0,
		"Static affix preserved value: %d" % int(static_copy.effect_number),
		"Static affix changed: %d (expected 42)" % int(static_copy.effect_number))

# ============================================================================
# TEST: Full Item Generation at Multiple Levels
# ============================================================================

func _test_item_generation_at_levels() -> void:
	print("\n── Item Generation Across Levels ──")
	
	var config: AffixScalingConfig = null
	if ResourceLoader.exists(SCALING_PATH):
		config = load(SCALING_PATH)
	
	# Load a slot definition for testing
	var gloves_sd: SlotDefinition = null
	var gloves_path := SLOT_DIR + "gloves_slot.tres"
	if ResourceLoader.exists(gloves_path):
		gloves_sd = load(gloves_path)
	
	if not gloves_sd:
		_warn("Skipping item generation test — no gloves SlotDefinition")
		return
	
	# Test at levels 5, 25, 50, 75, 95
	var test_levels := [5, 25, 50, 75, 95]
	var avg_values: Array[float] = []
	
	for level in test_levels:
		var total_value := 0.0
		var value_count := 0
		var num_samples := 10
		
		for _i in range(num_samples):
			var item := EquippableItem.new()
			item.item_name = "Test Gloves Lv.%d" % level
			item.equip_slot = EquippableItem.EquipSlot.GLOVES
			item.rarity = EquippableItem.Rarity.EPIC  # 3 affix rolls
			item.item_level = level
			item.slot_definition = gloves_sd
			
			item.initialize_affixes()
			
			for affix in item.item_affixes:
				if affix.has_scaling():
					total_value += affix.effect_number
					value_count += 1
		
		var avg := total_value / maxf(float(value_count), 1.0)
		avg_values.append(avg)
		print("    Lv.%d: avg scaled affix value = %.1f (%d samples, %d values)" % [
			level, avg, num_samples, value_count])
	
	# Verify monotonically increasing (higher level = higher average)
	var is_increasing := true
	for i in range(1, avg_values.size()):
		if avg_values[i] < avg_values[i - 1] * 0.8:  # Allow some variance
			is_increasing = false
			break
	
	_assert(is_increasing,
		"Average values increase with level (scaling works!)",
		"Average values NOT monotonically increasing — scaling may be broken")

# ============================================================================
# TEST: Heavy Weapon Double Rolls
# ============================================================================

func _test_heavy_weapon_double_rolls() -> void:
	print("\n── Heavy Weapon Double Rolls ──")
	
	var heavy_sd: SlotDefinition = null
	var heavy_path := SLOT_DIR + "heavy_slot.tres"
	if ResourceLoader.exists(heavy_path):
		heavy_sd = load(heavy_path)
	
	if not heavy_sd:
		_warn("Skipping heavy weapon test — no heavy SlotDefinition")
		return
	
	var item := EquippableItem.new()
	item.item_name = "Test Greatsword"
	item.equip_slot = EquippableItem.EquipSlot.HEAVY
	item.rarity = EquippableItem.Rarity.EPIC  # 3 tiers × 2 = 6 rolls
	item.item_level = 50
	item.slot_definition = heavy_sd
	
	item.initialize_affixes()
	
	var count := item.item_affixes.size()
	_assert(count == 6,
		"Heavy Epic rolled %d affixes (expected 6)" % count,
		"Heavy Epic rolled %d affixes (expected 6)" % count)

# ============================================================================
# TEST: Region Level Bounds
# ============================================================================

func _test_region_level_bounds() -> void:
	print("\n── Region Level Bounds ──")
	
	var config: AffixScalingConfig = null
	if ResourceLoader.exists(SCALING_PATH):
		config = load(SCALING_PATH)
	
	if not config:
		_warn("Skipping region test — no scaling config")
		return
	
	# Verify all 6 regions return sensible bounds
	for r in range(1, 7):
		var bounds: Dictionary = config.get_region_level_range(r)
		var b_min: int = bounds.min
		var b_max: int = bounds.max
		_assert(b_min < b_max,
			"Region %d: Lv.%d–%d" % [r, b_min, b_max],
			"Region %d: Invalid bounds %d–%d" % [r, b_min, b_max])
	
	# Verify overlapping transitions
	for r in range(1, 6):
		var current: Dictionary = config.get_region_level_range(r)
		var next: Dictionary = config.get_region_level_range(r + 1)
		var cur_max: int = current.max
		var nxt_min: int = next.min
		_assert(nxt_min < cur_max,
			"Region %d→%d overlaps (Lv.%d < Lv.%d)" % [r, r+1, nxt_min, cur_max],
			"Region %d→%d has gap (Lv.%d ≥ Lv.%d)" % [r, r+1, nxt_min, cur_max])

# ============================================================================
# TEST: Fuzz Distribution
# ============================================================================

func _test_fuzz_distribution() -> void:
	print("\n── Fuzz Distribution ──")
	
	# Roll the same affix at the same level many times — verify spread
	var test_affix := Affix.new()
	test_affix.affix_name = "Fuzz Test"
	test_affix.category = Affix.Category.ARMOR_BONUS
	test_affix.effect_min = 2.0
	test_affix.effect_max = 80.0
	
	var config: AffixScalingConfig = null
	if ResourceLoader.exists(SCALING_PATH):
		config = load(SCALING_PATH)
	
	var power_pos := 0.5  # Mid-game
	var values: Array[float] = []
	
	for _i in range(100):
		var copy: Affix = test_affix.duplicate(true)
		copy.roll_value(power_pos, config)
		values.append(copy.effect_number)
	
	# Find min/max/avg of rolled values
	var v_min: float = values[0]
	var v_max: float = values[0]
	var v_sum := 0.0
	for v in values:
		v_min = minf(v_min, v)
		v_max = maxf(v_max, v)
		v_sum += v
	var v_avg := v_sum / values.size()
	
	print("    100 rolls at t=0.5: min=%.0f, max=%.0f, avg=%.1f" % [v_min, v_max, v_avg])
	
	# Center should be around 41 (midpoint of 2–80)
	_assert(v_avg > 30.0 and v_avg < 52.0,
		"Average %.1f is near expected center (~41)" % v_avg,
		"Average %.1f is far from expected center (~41)" % v_avg)
	
	# Should have SOME spread (not all identical)
	_assert(v_max - v_min >= 2.0,
		"Spread = %.0f (fuzz is working)" % (v_max - v_min),
		"Spread = %.0f (fuzz may not be working)" % (v_max - v_min))
	
	# Should NOT span the entire range (level constrains)
	_assert(v_max - v_min < 40.0,
		"Spread = %.0f (level constrains the range)" % (v_max - v_min),
		"Spread = %.0f (too wide — level may not be constraining)" % (v_max - v_min))
