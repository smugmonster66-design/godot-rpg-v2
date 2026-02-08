# res://scripts/debug/test_affix_v2.gd
# Test suite for the v2 item-level affix system.
# Tests: AffixCondition, AffixSubEffect, Affix v2 features, AffixEvaluator.
#
# Run via: var test = load("res://scripts/debug/test_affix_v2.gd").new()
#          add_child(test)
extends Node

var _pass_count: int = 0
var _fail_count: int = 0
var _current_test: String = ""

# ============================================================================
# ENTRY POINT
# ============================================================================

func _ready():
	print("\n" + "=".repeat(60))
	print("  AFFIX v2 TEST SUITE")
	print("=".repeat(60))
	
	# AffixCondition tests
	test_condition_none()
	test_condition_has_heavy_weapon()
	test_condition_has_dual_wield()
	test_condition_min_equipment_slots()
	test_condition_all_slots_filled()
	test_condition_health_above()
	test_condition_health_below()
	test_condition_stat_above()
	test_condition_class_is()
	test_condition_invert()
	test_condition_scaling_per_equipped()
	test_condition_scaling_per_stat()
	test_condition_scaling_per_rarity()
	
	# ValueSource tests
	test_value_source_static()
	test_value_source_player_stat()
	test_value_source_equipped_count()
	test_value_source_rarity_sum()
	test_value_source_with_condition()
	
	# Tag tests
	test_tags_basic()
	test_tags_filtering()
	
	# Compound effect tests
	test_compound_basic()
	test_compound_condition_override()
	
	# Evaluator tests
	test_evaluator_resolve_stat()
	test_evaluator_category_sum()
	test_evaluator_category_product()
	test_evaluator_granted_actions_filtered()
	test_evaluator_tag_queries()
	test_evaluator_resolve_all()
	
	# Summary
	print("\n" + "=".repeat(60))
	print("  RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	print("=".repeat(60) + "\n")

# ============================================================================
# HELPERS
# ============================================================================

func begin(name: String):
	_current_test = name

func assert_eq(actual, expected, msg: String = ""):
	if actual == expected:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  ✗ FAIL [%s] %s: expected %s, got %s" % [_current_test, msg, expected, actual])

func assert_true(val: bool, msg: String = ""):
	assert_eq(val, true, msg)

func assert_false(val: bool, msg: String = ""):
	assert_eq(val, false, msg)

func assert_approx(actual: float, expected: float, epsilon: float = 0.01, msg: String = ""):
	if abs(actual - expected) <= epsilon:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  ✗ FAIL [%s] %s: expected ~%.3f, got %.3f" % [_current_test, msg, expected, actual])

func make_mock_player(overrides: Dictionary = {}) -> Dictionary:
	"""Create a mock player-like dictionary for testing.
	We use a Dictionary with callables to simulate Player methods."""
	var player = {
		"max_hp": overrides.get("max_hp", 100),
		"current_hp": overrides.get("current_hp", 100),
		"strength": overrides.get("strength", 10),
		"agility": overrides.get("agility", 8),
		"intellect": overrides.get("intellect", 5),
		"luck": overrides.get("luck", 3),
		"equipment": overrides.get("equipment", {
			"Head": null,
			"Torso": null,
			"Gloves": null,
			"Boots": null,
			"Main Hand": null,
			"Off Hand": null,
			"Accessory": null,
		}),
		"active_class": overrides.get("active_class", null),
		"affix_manager": null,
		"dice_pool": null,
	}
	return player

func make_mock_item(name: String, rarity: int = 0, is_heavy: bool = false) -> Dictionary:
	return {"name": name, "rarity": rarity, "is_heavy": is_heavy}

func make_condition(type: AffixCondition.Type, thresh: float = 0.0, p_invert: bool = false, data: Dictionary = {}) -> AffixCondition:
	var cond = AffixCondition.new()
	cond.type = type
	cond.threshold = thresh
	cond.invert = p_invert
	cond.condition_data = data
	return cond

func make_affix(name: String, cat: Affix.Category = Affix.Category.NONE, value: float = 0.0) -> Affix:
	var affix = Affix.new()
	affix.affix_name = name
	affix.category = cat
	affix.effect_number = value
	return affix

func make_context(player: Dictionary) -> Dictionary:
	var ctx: Dictionary = {
		"player": player,
		"in_combat": false,
		"turn_number": 0,
	}
	if player.get("affix_manager"):
		ctx["affix_manager"] = player.affix_manager
	return ctx

# ============================================================================
# CONDITION TESTS
# ============================================================================

func test_condition_none():
	begin("condition_none")
	var cond = make_condition(AffixCondition.Type.NONE)
	var ctx = make_context(make_mock_player())
	var result = cond.evaluate(ctx)
	assert_false(result.blocked, "NONE never blocks")
	assert_approx(result.multiplier, 1.0, 0.001, "NONE multiplier is 1.0")
	print("  ✓ condition_none")

func test_condition_has_heavy_weapon():
	begin("condition_has_heavy_weapon")
	var cond = make_condition(AffixCondition.Type.HAS_HEAVY_WEAPON)
	
	# No weapon
	var p1 = make_mock_player()
	assert_true(cond.evaluate(make_context(p1)).blocked, "no weapon → blocked")
	
	# Heavy weapon
	var p2 = make_mock_player()
	p2.equipment["Main Hand"] = make_mock_item("Greatsword", 0, true)
	assert_false(cond.evaluate(make_context(p2)).blocked, "heavy weapon → passes")
	
	# Light weapon
	var p3 = make_mock_player()
	p3.equipment["Main Hand"] = make_mock_item("Dagger", 0, false)
	assert_true(cond.evaluate(make_context(p3)).blocked, "light weapon → blocked")
	print("  ✓ condition_has_heavy_weapon")

func test_condition_has_dual_wield():
	begin("condition_has_dual_wield")
	var cond = make_condition(AffixCondition.Type.HAS_DUAL_WIELD)
	
	# Both slots filled with DIFFERENT items
	var p = make_mock_player()
	p.equipment["Main Hand"] = make_mock_item("Sword")
	p.equipment["Off Hand"] = make_mock_item("Dagger")
	assert_false(cond.evaluate(make_context(p)).blocked, "dual wield → passes")
	
	# Same item in both (heavy weapon) → NOT dual wield
	var p2 = make_mock_player()
	var heavy = make_mock_item("Greatsword", 0, true)
	p2.equipment["Main Hand"] = heavy
	p2.equipment["Off Hand"] = heavy
	assert_true(cond.evaluate(make_context(p2)).blocked, "heavy (same ref) → blocked")
	
	# Only main hand
	var p3 = make_mock_player()
	p3.equipment["Main Hand"] = make_mock_item("Sword")
	assert_true(cond.evaluate(make_context(p3)).blocked, "only main hand → blocked")
	print("  ✓ condition_has_dual_wield")

func test_condition_min_equipment_slots():
	begin("condition_min_equipment_slots")
	var cond = make_condition(AffixCondition.Type.MIN_EQUIPMENT_SLOTS_FILLED, 3.0)
	
	var p = make_mock_player()
	assert_true(cond.evaluate(make_context(p)).blocked, "0 slots → blocked")
	
	p.equipment["Head"] = make_mock_item("Helm")
	p.equipment["Torso"] = make_mock_item("Plate")
	assert_true(cond.evaluate(make_context(p)).blocked, "2 slots → blocked")
	
	p.equipment["Boots"] = make_mock_item("Boots")
	assert_false(cond.evaluate(make_context(p)).blocked, "3 slots → passes")
	print("  ✓ condition_min_equipment_slots")

func test_condition_all_slots_filled():
	begin("condition_all_slots_filled")
	var cond = make_condition(AffixCondition.Type.ALL_SLOTS_FILLED)
	
	var p = make_mock_player()
	assert_true(cond.evaluate(make_context(p)).blocked, "empty → blocked")
	
	for slot in p.equipment:
		p.equipment[slot] = make_mock_item(slot)
	assert_false(cond.evaluate(make_context(p)).blocked, "all filled → passes")
	print("  ✓ condition_all_slots_filled")

func test_condition_health_above():
	begin("condition_health_above")
	var cond = make_condition(AffixCondition.Type.HEALTH_ABOVE_PERCENT, 0.5)
	
	var p_full = make_mock_player({"current_hp": 100, "max_hp": 100})
	assert_false(cond.evaluate(make_context(p_full)).blocked, "100% HP → passes")
	
	var p_low = make_mock_player({"current_hp": 30, "max_hp": 100})
	assert_true(cond.evaluate(make_context(p_low)).blocked, "30% HP → blocked")
	print("  ✓ condition_health_above")

func test_condition_health_below():
	begin("condition_health_below")
	var cond = make_condition(AffixCondition.Type.HEALTH_BELOW_PERCENT, 0.5)
	
	var p_low = make_mock_player({"current_hp": 30, "max_hp": 100})
	assert_false(cond.evaluate(make_context(p_low)).blocked, "30% HP → passes")
	
	var p_full = make_mock_player({"current_hp": 100, "max_hp": 100})
	assert_true(cond.evaluate(make_context(p_full)).blocked, "100% HP → blocked")
	print("  ✓ condition_health_below")

func test_condition_stat_above():
	begin("condition_stat_above")
	var cond = make_condition(AffixCondition.Type.STAT_ABOVE, 8.0, false, {"stat_name": "strength"})
	
	var p_strong = make_mock_player({"strength": 15})
	assert_false(cond.evaluate(make_context(p_strong)).blocked, "str 15 >= 8 → passes")
	
	var p_weak = make_mock_player({"strength": 5})
	assert_true(cond.evaluate(make_context(p_weak)).blocked, "str 5 < 8 → blocked")
	print("  ✓ condition_stat_above")

func test_condition_class_is():
	begin("condition_class_is")
	var cond = make_condition(AffixCondition.Type.CLASS_IS, 0.0, false, {"class_name": "Warrior"})
	
	# No class
	var p = make_mock_player()
	assert_true(cond.evaluate(make_context(p)).blocked, "no class → blocked")
	
	# With matching class (mock)
	var mock_class = {"player_class_name": "Warrior"}
	var p2 = make_mock_player({"active_class": mock_class})
	# Note: This test uses dict mock — real test needs PlayerClass resource
	# The condition checks player.active_class.player_class_name
	print("  ✓ condition_class_is (structural)")

func test_condition_invert():
	begin("condition_invert")
	var cond = make_condition(AffixCondition.Type.HAS_HEAVY_WEAPON, 0.0, true)
	
	# No weapon → normally blocked → inverted → passes
	var p = make_mock_player()
	assert_false(cond.evaluate(make_context(p)).blocked, "inverted: no weapon → passes")
	
	# Heavy weapon → normally passes → inverted → blocked
	var p2 = make_mock_player()
	p2.equipment["Main Hand"] = make_mock_item("Greatsword", 0, true)
	assert_true(cond.evaluate(make_context(p2)).blocked, "inverted: heavy → blocked")
	print("  ✓ condition_invert")

func test_condition_scaling_per_equipped():
	begin("condition_scaling_per_equipped")
	var cond = make_condition(AffixCondition.Type.PER_EQUIPPED_ITEM)
	
	var p = make_mock_player()
	p.equipment["Head"] = make_mock_item("Helm")
	p.equipment["Torso"] = make_mock_item("Plate")
	p.equipment["Boots"] = make_mock_item("Boots")
	
	var result = cond.evaluate(make_context(p))
	assert_false(result.blocked, "scaling never blocks")
	assert_approx(result.multiplier, 3.0, 0.001, "3 items → multiplier 3")
	print("  ✓ condition_scaling_per_equipped")

func test_condition_scaling_per_stat():
	begin("condition_scaling_per_stat")
	var cond = make_condition(AffixCondition.Type.PER_STAT_POINT, 0.0, false, {"stat_name": "strength"})
	
	var p = make_mock_player({"strength": 20})
	var result = cond.evaluate(make_context(p))
	assert_false(result.blocked, "scaling never blocks")
	assert_approx(result.multiplier, 20.0, 0.001, "str 20 → multiplier 20")
	print("  ✓ condition_scaling_per_stat")

func test_condition_scaling_per_rarity():
	begin("condition_scaling_per_rarity")
	var cond = make_condition(AffixCondition.Type.PER_EQUIPMENT_RARITY)
	
	var p = make_mock_player()
	p.equipment["Head"] = make_mock_item("Common Helm", 0)       # COMMON = 0
	p.equipment["Torso"] = make_mock_item("Rare Plate", 2)       # RARE = 2
	p.equipment["Boots"] = make_mock_item("Epic Boots", 3)       # EPIC = 3
	
	var result = cond.evaluate(make_context(p))
	assert_approx(result.multiplier, 5.0, 0.001, "0+2+3 = 5 rarity sum")
	print("  ✓ condition_scaling_per_rarity")

# ============================================================================
# VALUE SOURCE TESTS
# ============================================================================

func test_value_source_static():
	begin("value_source_static")
	var affix = make_affix("Flat Bonus", Affix.Category.STRENGTH_BONUS, 5.0)
	var value = affix.resolve_value({})
	assert_approx(value, 5.0, 0.001, "STATIC returns effect_number")
	print("  ✓ value_source_static")

func test_value_source_player_stat():
	begin("value_source_player_stat")
	var affix = make_affix("Per Str", Affix.Category.DAMAGE_BONUS, 0.5)
	affix.value_source = Affix.ValueSource.PLAYER_STAT
	affix.effect_data = {"stat_name": "strength"}
	
	var p = make_mock_player({"strength": 20})
	var value = affix.resolve_value(make_context(p))
	assert_approx(value, 10.0, 0.001, "20 str × 0.5 = 10")
	print("  ✓ value_source_player_stat")

func test_value_source_equipped_count():
	begin("value_source_equipped_count")
	var affix = make_affix("Per Slot", Affix.Category.DEFENSE_BONUS, 2.0)
	affix.value_source = Affix.ValueSource.EQUIPPED_ITEM_COUNT
	
	var p = make_mock_player()
	p.equipment["Head"] = make_mock_item("Helm")
	p.equipment["Boots"] = make_mock_item("Boots")
	p.equipment["Main Hand"] = make_mock_item("Sword")
	
	var value = affix.resolve_value(make_context(p))
	assert_approx(value, 6.0, 0.001, "3 items × 2.0 = 6")
	print("  ✓ value_source_equipped_count")

func test_value_source_rarity_sum():
	begin("value_source_rarity_sum")
	var affix = make_affix("Rarity Barrier", Affix.Category.BARRIER_BONUS, 1.5)
	affix.value_source = Affix.ValueSource.EQUIPMENT_RARITY_SUM
	
	var p = make_mock_player()
	p.equipment["Head"] = make_mock_item("Epic Helm", 3)
	p.equipment["Torso"] = make_mock_item("Legendary Plate", 4)
	
	var value = affix.resolve_value(make_context(p))
	assert_approx(value, 10.5, 0.001, "(3+4) × 1.5 = 10.5")
	print("  ✓ value_source_rarity_sum")

func test_value_source_with_condition():
	begin("value_source_with_condition")
	var affix = make_affix("Gated Bonus", Affix.Category.DAMAGE_BONUS, 3.0)
	affix.value_source = Affix.ValueSource.EQUIPPED_ITEM_COUNT
	affix.condition = make_condition(AffixCondition.Type.HAS_HEAVY_WEAPON)
	
	# No heavy weapon → blocked → 0
	var p = make_mock_player()
	p.equipment["Main Hand"] = make_mock_item("Dagger")
	var val1 = affix.resolve_value(make_context(p))
	assert_approx(val1, 0.0, 0.001, "condition blocked → 0")
	
	# Heavy weapon → passes → resolves normally
	p.equipment["Main Hand"] = make_mock_item("Greatsword", 0, true)
	p.equipment["Head"] = make_mock_item("Helm")
	var val2 = affix.resolve_value(make_context(p))
	assert_approx(val2, 6.0, 0.001, "2 items × 3.0 = 6.0")
	print("  ✓ value_source_with_condition")

# ============================================================================
# TAG TESTS
# ============================================================================

func test_tags_basic():
	begin("tags_basic")
	var affix = make_affix("Tagged", Affix.Category.DAMAGE_BONUS, 5.0)
	affix.tags.assign(["weapon", "physical", "mastery"])
	
	assert_true(affix.has_tag("weapon"), "has 'weapon'")
	assert_true(affix.has_tag("mastery"), "has 'mastery'")
	assert_false(affix.has_tag("magical"), "no 'magical'")
	assert_true(affix.has_any_tag(["magical", "weapon"]), "has any: weapon")
	assert_false(affix.has_all_tags(["weapon", "magical"]), "not all: weapon+magical")
	assert_true(affix.has_all_tags(["weapon", "physical"]), "all: weapon+physical")
	print("  ✓ tags_basic")

func test_tags_filtering():
	begin("tags_filtering")
	var mgr = AffixPoolManager.new()
	
	var a1 = make_affix("Sword Bonus", Affix.Category.SLASHING_DAMAGE_BONUS, 3.0)
	a1.tags.assign(["weapon", "slashing"])
	mgr.add_affix(a1)
	
	var a2 = make_affix("Armor Up", Affix.Category.ARMOR_BONUS, 5.0)
	a2.tags.assign(["defensive", "armor"])
	mgr.add_affix(a2)
	
	var a3 = make_affix("Fire Strike", Affix.Category.FIRE_DAMAGE_BONUS, 2.0)
	a3.tags.assign(["weapon", "fire", "magical"])
	mgr.add_affix(a3)
	
	# Test pool manager tag queries
	var weapon_affixes = mgr.get_affixes_by_tag("weapon")
	assert_eq(weapon_affixes.size(), 2, "2 weapon-tagged affixes")
	
	var defensive = mgr.get_affixes_by_tag("defensive")
	assert_eq(defensive.size(), 1, "1 defensive-tagged affix")
	
	assert_true(mgr.has_affix_with_tag("fire"), "has fire tag")
	assert_false(mgr.has_affix_with_tag("ice"), "no ice tag")
	assert_eq(mgr.count_affixes_with_tag("weapon"), 2, "2 weapon tags")
	print("  ✓ tags_filtering")

# ============================================================================
# COMPOUND EFFECT TESTS
# ============================================================================

func test_compound_basic():
	begin("compound_basic")
	var affix = make_affix("Multi Effect", Affix.Category.MISC, 0.0)
	
	var sub1 = AffixSubEffect.new()
	sub1.category = Affix.Category.STRENGTH_BONUS
	sub1.effect_number = 3.0
	
	var sub2 = AffixSubEffect.new()
	sub2.category = Affix.Category.DAMAGE_BONUS
	sub2.effect_number = 5.0
	
	affix.sub_effects.assign([sub1, sub2])
	
	assert_true(affix.is_compound(), "is compound")
	assert_eq(affix.get_sub_effect_count(), 2, "2 sub-effects")
	
	# Resolve
	var evaluator = AffixEvaluator.new()
	var results = evaluator.resolve_compound_affix(affix, {})
	assert_eq(results.size(), 2, "2 results")
	assert_eq(results[0].category, Affix.Category.STRENGTH_BONUS, "sub1 category")
	assert_approx(results[0].value, 3.0, 0.001, "sub1 value")
	assert_approx(results[1].value, 5.0, 0.001, "sub2 value")
	print("  ✓ compound_basic")

func test_compound_condition_override():
	begin("compound_condition_override")
	var affix = make_affix("Gated Compound", Affix.Category.MISC, 0.0)
	
	# Sub1: always fires
	var sub1 = AffixSubEffect.new()
	sub1.category = Affix.Category.STRENGTH_BONUS
	sub1.effect_number = 2.0
	
	# Sub2: only fires if heavy weapon equipped
	var sub2 = AffixSubEffect.new()
	sub2.category = Affix.Category.DAMAGE_BONUS
	sub2.effect_number = 10.0
	sub2.override_condition = true
	sub2.condition = make_condition(AffixCondition.Type.HAS_HEAVY_WEAPON)
	
	affix.sub_effects.assign([sub1, sub2])
	
	var evaluator = AffixEvaluator.new()
	
	# No heavy weapon → sub2 blocked
	var p = make_mock_player()
	var results = evaluator.resolve_compound_affix(affix, make_context(p))
	assert_eq(results.size(), 1, "only sub1 fires")
	assert_approx(results[0].value, 2.0, 0.001, "sub1 value")
	
	# With heavy weapon → both fire
	p.equipment["Main Hand"] = make_mock_item("Greatsword", 0, true)
	var results2 = evaluator.resolve_compound_affix(affix, make_context(p))
	assert_eq(results2.size(), 2, "both fire")
	assert_approx(results2[1].value, 10.0, 0.001, "sub2 value")
	print("  ✓ compound_condition_override")

# ============================================================================
# EVALUATOR TESTS
# ============================================================================

func test_evaluator_resolve_stat():
	begin("evaluator_resolve_stat")
	var mgr = AffixPoolManager.new()
	var evaluator = AffixEvaluator.new()
	
	mgr.add_affix(make_affix("Str+3", Affix.Category.STRENGTH_BONUS, 3.0))
	mgr.add_affix(make_affix("Str+5", Affix.Category.STRENGTH_BONUS, 5.0))
	mgr.add_affix(make_affix("Str×1.2", Affix.Category.STRENGTH_MULTIPLIER, 1.2))
	
	var p = make_mock_player()
	var ctx = make_context(p)
	var result = evaluator.resolve_stat(mgr, "strength", 10.0, ctx)
	# (10 + 3 + 5) × 1.2 = 21.6
	assert_approx(result, 21.6, 0.01, "(10+3+5)×1.2 = 21.6")
	print("  ✓ evaluator_resolve_stat")

func test_evaluator_category_sum():
	begin("evaluator_category_sum")
	var mgr = AffixPoolManager.new()
	var evaluator = AffixEvaluator.new()
	
	mgr.add_affix(make_affix("Slash+2", Affix.Category.SLASHING_DAMAGE_BONUS, 2.0))
	mgr.add_affix(make_affix("Slash+3", Affix.Category.SLASHING_DAMAGE_BONUS, 3.0))
	
	var total = evaluator.resolve_category_sum(mgr, Affix.Category.SLASHING_DAMAGE_BONUS, {})
	assert_approx(total, 5.0, 0.001, "2+3 = 5")
	print("  ✓ evaluator_category_sum")

func test_evaluator_category_product():
	begin("evaluator_category_product")
	var mgr = AffixPoolManager.new()
	var evaluator = AffixEvaluator.new()
	
	mgr.add_affix(make_affix("Dmg×1.1", Affix.Category.DAMAGE_MULTIPLIER, 1.1))
	mgr.add_affix(make_affix("Dmg×1.2", Affix.Category.DAMAGE_MULTIPLIER, 1.2))
	
	var product = evaluator.resolve_category_product(mgr, Affix.Category.DAMAGE_MULTIPLIER, {})
	assert_approx(product, 1.32, 0.01, "1.1×1.2 = 1.32")
	print("  ✓ evaluator_category_product")

func test_evaluator_granted_actions_filtered():
	begin("evaluator_granted_actions_filtered")
	var mgr = AffixPoolManager.new()
	var evaluator = AffixEvaluator.new()
	
	# Action with no condition → always granted
	var a1 = make_affix("Always Action", Affix.Category.NEW_ACTION)
	a1.granted_action = Action.new()
	mgr.add_affix(a1)
	
	# Action gated by heavy weapon → blocked when no heavy
	var a2 = make_affix("Heavy Action", Affix.Category.NEW_ACTION)
	a2.granted_action = Action.new()
	a2.condition = make_condition(AffixCondition.Type.HAS_HEAVY_WEAPON)
	mgr.add_affix(a2)
	
	var p = make_mock_player()
	var ctx = make_context(p)
	
	var actions = evaluator.resolve_granted_actions(mgr, ctx)
	assert_eq(actions.size(), 1, "only unconditional action granted")
	
	# Equip heavy weapon → both granted
	p.equipment["Main Hand"] = make_mock_item("Greatsword", 0, true)
	var actions2 = evaluator.resolve_granted_actions(mgr, make_context(p))
	assert_eq(actions2.size(), 2, "both actions granted with heavy weapon")
	print("  ✓ evaluator_granted_actions_filtered")

func test_evaluator_tag_queries():
	begin("evaluator_tag_queries")
	var mgr = AffixPoolManager.new()
	var evaluator = AffixEvaluator.new()
	
	var a1 = make_affix("A", Affix.Category.DAMAGE_BONUS, 3.0)
	a1.tags.assign(["weapon"])
	mgr.add_affix(a1)
	
	var a2 = make_affix("B", Affix.Category.DAMAGE_BONUS, 7.0)
	a2.tags.assign(["weapon", "fire"])
	mgr.add_affix(a2)
	
	var a3 = make_affix("C", Affix.Category.ARMOR_BONUS, 5.0)
	a3.tags.assign(["defensive"])
	mgr.add_affix(a3)
	
	var weapon_sum = evaluator.sum_values_by_tag(mgr, "weapon", {})
	assert_approx(weapon_sum, 10.0, 0.001, "3+7 = 10 weapon value")
	
	var fire_count = evaluator.count_affixes_with_tag(mgr, "fire")
	assert_eq(fire_count, 1, "1 fire-tagged affix")
	print("  ✓ evaluator_tag_queries")

func test_evaluator_resolve_all():
	begin("evaluator_resolve_all")
	var mgr = AffixPoolManager.new()
	var evaluator = AffixEvaluator.new()
	
	mgr.add_affix(make_affix("Str+3", Affix.Category.STRENGTH_BONUS, 3.0))
	mgr.add_affix(make_affix("Dmg+5", Affix.Category.DAMAGE_BONUS, 5.0))
	mgr.add_affix(make_affix("Armor+2", Affix.Category.ARMOR_BONUS, 2.0))
	
	var snapshot = evaluator.resolve_all_effects(mgr, {})
	assert_approx(snapshot[Affix.Category.STRENGTH_BONUS], 3.0, 0.001, "str bonus = 3")
	assert_approx(snapshot[Affix.Category.DAMAGE_BONUS], 5.0, 0.001, "dmg bonus = 5")
	assert_approx(snapshot[Affix.Category.ARMOR_BONUS], 2.0, 0.001, "armor bonus = 2")
	print("  ✓ evaluator_resolve_all")
