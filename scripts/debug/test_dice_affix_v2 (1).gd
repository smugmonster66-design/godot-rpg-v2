# res://scripts/editor/test_dice_affix_v2.gd
# Run from Editor: Script > Run (Ctrl+Shift+X)
# Tests all v2 systems: conditions, sub-effects, combat modifiers,
# ghost hand, value sources, new effect types.
#
# Each test creates resources from scratch (no .tres dependencies),
# runs the system, and checks expected outcomes.
@tool
extends EditorScript

var _pass_count := 0
var _fail_count := 0
var _current_test := ""

func _run():
	print("\n" + "=".repeat(70))
	print("🧪 DICE AFFIX V2 TEST SUITE")
	print("=".repeat(70))
	
	# --- Core resource classes exist ---
	test_resource_classes_exist()
	
	# --- Condition system ---
	test_condition_none_always_passes()
	test_condition_self_value_above()
	test_condition_self_value_below()
	test_condition_self_value_is_max()
	test_condition_self_value_is_min()
	test_condition_self_value_below_half_max()
	test_condition_invert()
	test_condition_per_used_die_scaling()
	test_condition_per_qualifying_neighbor()
	test_condition_neighbors_used()
	test_condition_min_dice_used()
	
	# --- Value sources ---
	test_value_source_static()
	test_value_source_self_value()
	test_value_source_self_value_fraction()
	test_value_source_neighbor_percent()
	test_value_source_context_used_count()
	
	# --- Sub-effects (compound affixes) ---
	test_sub_effects_both_fire()
	test_sub_effects_target_override()
	test_sub_effects_condition_override()
	
	# --- New effect types ---
	test_effect_remove_all_tags()
	test_effect_randomize_element()
	test_effect_set_element()
	test_effect_leech_heal()
	test_effect_destroy_self()
	test_effect_create_combat_modifier()
	
	# --- Ghost hand ---
	test_ghost_hand_consume_preserves_array()
	test_ghost_hand_on_use_sees_neighbors()
	test_ghost_hand_consumed_dice_skip_activation()
	test_ghost_hand_restore_clears_consumed()
	test_ghost_hand_unconsumed_queries()
	test_ghost_hand_available_dice_legacy()
	
	# --- Combat modifiers ---
	test_combat_modifier_flat_bonus()
	test_combat_modifier_all_except_source()
	test_combat_modifier_turn_expiry()
	
	# --- Integration: full combat flow ---
	test_full_combat_turn_flow()
	
	# --- Summary ---
	print("\n" + "=".repeat(70))
	var total = _pass_count + _fail_count
	if _fail_count == 0:
		print("✅ ALL %d TESTS PASSED" % total)
	else:
		print("❌ %d / %d PASSED — %d FAILED" % [_pass_count, total, _fail_count])
	print("=".repeat(70) + "\n")

# ============================================================================
# ASSERTION HELPERS
# ============================================================================

func begin(test_name: String):
	_current_test = test_name

func assert_true(condition: bool, msg: String = ""):
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		var label = "%s: %s" % [_current_test, msg] if msg else _current_test
		print("  ❌ FAIL: %s" % label)

func assert_eq(actual, expected, msg: String = ""):
	if actual == expected:
		_pass_count += 1
	else:
		_fail_count += 1
		var label = "%s: %s" % [_current_test, msg] if msg else _current_test
		print("  ❌ FAIL: %s — expected %s, got %s" % [label, expected, actual])

func assert_neq(actual, not_expected, msg: String = ""):
	if actual != not_expected:
		_pass_count += 1
	else:
		_fail_count += 1
		var label = "%s: %s" % [_current_test, msg] if msg else _current_test
		print("  ❌ FAIL: %s — got %s (should differ)" % [label, actual])

func assert_gt(actual: float, threshold: float, msg: String = ""):
	if actual > threshold:
		_pass_count += 1
	else:
		_fail_count += 1
		var label = "%s: %s" % [_current_test, msg] if msg else _current_test
		print("  ❌ FAIL: %s — expected > %s, got %s" % [label, threshold, actual])

# ============================================================================
# FACTORY HELPERS
# ============================================================================

func make_die(die_type: int = 6, value: int = 3) -> DieResource:
	var die = DieResource.new(die_type, "test")
	die.display_name = "TestD%d" % die_type
	die.current_value = value
	die.modified_value = value
	return die

func make_hand(values: Array) -> Array[DieResource]:
	var hand: Array[DieResource] = []
	for i in range(values.size()):
		var die = make_die(6, values[i])
		die.slot_index = i
		die.display_name = "D6_%d" % i
		hand.append(die)
	return hand

## Preload scripts to avoid @tool class_name resolution issues in EditorScript
var _affix_script = load("res://resources/data/dice_affix.gd")
var _condition_script = load("res://resources/data/dice_affix_condition.gd")
var _sub_effect_script = load("res://resources/data/dice_affix_sub_effect.gd")
var _combat_mod_script = load("res://resources/data/combat_modifier.gd")
var _processor_script = load("res://resources/data/dice_affix_processor.gd")
var _collection_script = load("res://resources/data/player_dice_collection.gd")

func make_affix(p_name: String = "TestAffix") -> DiceAffix:
	var affix = _affix_script.new()
	affix.affix_name = p_name
	return affix

func make_condition(type: int, threshold: float = 0.0, invert: bool = false) -> DiceAffixCondition:
	var cond = _condition_script.new()
	cond.type = type
	cond.threshold = threshold
	cond.invert = invert
	return cond

func make_sub_effect() -> DiceAffixSubEffect:
	return _sub_effect_script.new()

func make_combat_modifier() -> CombatModifier:
	return _combat_mod_script.new()

func make_processor() -> DiceAffixProcessor:
	return _processor_script.new()

func make_collection() -> PlayerDiceCollection:
	return _collection_script.new()

# ============================================================================
# TEST: Resource classes exist
# ============================================================================

func test_resource_classes_exist():
	begin("resource_classes_exist")
	assert_true(_affix_script != null, "DiceAffix script loaded")
	assert_true(_condition_script != null, "DiceAffixCondition script loaded")
	assert_true(_sub_effect_script != null, "DiceAffixSubEffect script loaded")
	assert_true(_combat_mod_script != null, "CombatModifier script loaded")
	assert_true(_processor_script != null, "DiceAffixProcessor script loaded")
	assert_true(_condition_script.new() is Resource, "DiceAffixCondition is Resource")
	assert_true(_sub_effect_script.new() is Resource, "DiceAffixSubEffect is Resource")
	assert_true(_combat_mod_script.new() is Resource, "CombatModifier is Resource")
	print("  ✓ resource_classes_exist")

# ============================================================================
# TESTS: Condition System
# ============================================================================

func test_condition_none_always_passes():
	begin("condition_none")
	var cond = make_condition(DiceAffixCondition.Type.NONE)
	var die = make_die(6, 3)
	var result = cond.evaluate(die, [die], 0, {})
	assert_eq(result.blocked, false, "NONE never blocks")
	assert_eq(result.multiplier, 1.0, "NONE multiplier is 1.0")
	print("  ✓ condition_none")

func test_condition_self_value_above():
	begin("condition_self_value_above")
	var cond = make_condition(DiceAffixCondition.Type.SELF_VALUE_ABOVE, 4.0)
	
	var die_low = make_die(6, 3)
	var r1 = cond.evaluate(die_low, [die_low], 0, {})
	assert_eq(r1.blocked, true, "value 3 < threshold 4 → blocked")
	
	var die_high = make_die(6, 5)
	var r2 = cond.evaluate(die_high, [die_high], 0, {})
	assert_eq(r2.blocked, false, "value 5 >= threshold 4 → passes")
	print("  ✓ condition_self_value_above")

func test_condition_self_value_below():
	begin("condition_self_value_below")
	var cond = make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW, 3.0)
	
	var die_low = make_die(6, 2)
	var r1 = cond.evaluate(die_low, [die_low], 0, {})
	assert_eq(r1.blocked, false, "value 2 <= 3 → passes")
	
	var die_high = make_die(6, 5)
	var r2 = cond.evaluate(die_high, [die_high], 0, {})
	assert_eq(r2.blocked, true, "value 5 > 3 → blocked")
	print("  ✓ condition_self_value_below")

func test_condition_self_value_is_max():
	begin("condition_self_value_is_max")
	var cond = make_condition(DiceAffixCondition.Type.SELF_VALUE_IS_MAX)
	
	var die_max = make_die(6, 6)
	var r1 = cond.evaluate(die_max, [die_max], 0, {})
	assert_eq(r1.blocked, false, "value 6 == die_type 6 → passes")
	
	var die_notmax = make_die(6, 4)
	var r2 = cond.evaluate(die_notmax, [die_notmax], 0, {})
	assert_eq(r2.blocked, true, "value 4 != die_type 6 → blocked")
	print("  ✓ condition_self_value_is_max")

func test_condition_self_value_is_min():
	begin("condition_self_value_is_min")
	var cond = make_condition(DiceAffixCondition.Type.SELF_VALUE_IS_MIN)
	
	var die_min = make_die(6, 1)
	var r1 = cond.evaluate(die_min, [die_min], 0, {})
	assert_eq(r1.blocked, false, "value 1 → passes")
	
	var die_notmin = make_die(6, 3)
	var r2 = cond.evaluate(die_notmin, [die_notmin], 0, {})
	assert_eq(r2.blocked, true, "value 3 → blocked")
	print("  ✓ condition_self_value_is_min")

func test_condition_self_value_below_half_max():
	begin("condition_self_value_below_half_max")
	var cond = make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW_HALF_MAX)
	
	# d8, half max = 4.0, value 3 < 4 → passes
	var die_low = make_die(8, 3)
	var r1 = cond.evaluate(die_low, [die_low], 0, {})
	assert_eq(r1.blocked, false, "d8 value 3 < 4 → passes")
	
	# d8, value 5 >= 4 → blocked
	var die_high = make_die(8, 5)
	var r2 = cond.evaluate(die_high, [die_high], 0, {})
	assert_eq(r2.blocked, true, "d8 value 5 >= 4 → blocked")
	print("  ✓ condition_self_value_below_half_max")

func test_condition_invert():
	begin("condition_invert")
	var cond = make_condition(DiceAffixCondition.Type.SELF_VALUE_ABOVE, 4.0, true)
	
	# Normally value 5 >= 4 would pass, but inverted → blocked
	var die = make_die(6, 5)
	var r = cond.evaluate(die, [die], 0, {})
	assert_eq(r.blocked, true, "inverted: value 5 >= 4 normally passes → now blocked")
	
	# Normally value 2 < 4 would block, but inverted → passes
	var die2 = make_die(6, 2)
	var r2 = cond.evaluate(die2, [die2], 0, {})
	assert_eq(r2.blocked, false, "inverted: value 2 < 4 normally blocks → now passes")
	print("  ✓ condition_invert")

func test_condition_per_used_die_scaling():
	begin("condition_per_used_die_scaling")
	var cond = make_condition(DiceAffixCondition.Type.PER_USED_DIE)
	var die = make_die(6, 4)
	
	var ctx0 = {"used_count": 0}
	var r0 = cond.evaluate(die, [die], 0, ctx0)
	assert_eq(r0.blocked, false, "scaling never blocks")
	assert_eq(r0.multiplier, 0.0, "0 used → multiplier 0")
	
	var ctx3 = {"used_count": 3}
	var r3 = cond.evaluate(die, [die], 0, ctx3)
	assert_eq(r3.multiplier, 3.0, "3 used → multiplier 3")
	print("  ✓ condition_per_used_die_scaling")

func test_condition_per_qualifying_neighbor():
	begin("condition_per_qualifying_neighbor")
	var cond = make_condition(DiceAffixCondition.Type.PER_QUALIFYING_NEIGHBOR, 4.0)
	
	# [5, SOURCE, 3] → left qualifies (5>=4), right doesn't (3<4) → multiplier 1
	var hand = make_hand([5, 4, 3])
	var r = cond.evaluate(hand[1], hand, 1, {})
	assert_eq(r.blocked, false, "scaling never blocks")
	assert_eq(r.multiplier, 1.0, "one neighbor >= 4 → multiplier 1")
	
	# [5, SOURCE, 6] → both qualify → multiplier 2
	var hand2 = make_hand([5, 4, 6])
	var r2 = cond.evaluate(hand2[1], hand2, 1, {})
	assert_eq(r2.multiplier, 2.0, "both neighbors >= 4 → multiplier 2")
	print("  ✓ condition_per_qualifying_neighbor")

func test_condition_neighbors_used():
	begin("condition_neighbors_used")
	var cond = make_condition(DiceAffixCondition.Type.NEIGHBORS_USED)
	
	var hand = make_hand([3, 4, 5])
	# Neither neighbor consumed
	var ctx_none = {"used_indices": []}
	var r1 = cond.evaluate(hand[1], hand, 1, ctx_none)
	assert_eq(r1.blocked, true, "no neighbors used → blocked")
	
	# Both neighbors consumed (slot_indices 0 and 2)
	var ctx_both = {"used_indices": [0, 2]}
	var r2 = cond.evaluate(hand[1], hand, 1, ctx_both)
	assert_eq(r2.blocked, false, "both neighbors used → passes")
	
	# Edge die (index 0) can never have both neighbors
	var ctx_edge = {"used_indices": [1]}
	var r3 = cond.evaluate(hand[0], hand, 0, ctx_edge)
	assert_eq(r3.blocked, true, "edge die can't have both neighbors → blocked")
	print("  ✓ condition_neighbors_used")

func test_condition_min_dice_used():
	begin("condition_min_dice_used")
	var cond = make_condition(DiceAffixCondition.Type.MIN_DICE_USED, 2.0)
	var die = make_die()
	
	var r1 = cond.evaluate(die, [die], 0, {"used_count": 1})
	assert_eq(r1.blocked, true, "1 used < threshold 2 → blocked")
	
	var r2 = cond.evaluate(die, [die], 0, {"used_count": 3})
	assert_eq(r2.blocked, false, "3 used >= threshold 2 → passes")
	print("  ✓ condition_min_dice_used")

# ============================================================================
# TESTS: Value Sources
# ============================================================================

func test_value_source_static():
	begin("value_source_static")
	var proc = make_processor()
	var hand = make_hand([3, 4, 5])
	
	var affix = make_affix("StaticBonus")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	affix.effect_value = 2.0
	affix.value_source = DiceAffix.ValueSource.STATIC
	hand[0].inherent_affixes.append(affix)
	
	var result = proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	assert_eq(hand[0].modified_value, 5, "3 + 2 static = 5")
	print("  ✓ value_source_static")

func test_value_source_self_value():
	begin("value_source_self_value")
	var proc = make_processor()
	var hand = make_hand([4])
	
	var affix = make_affix("SelfValue")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	affix.value_source = DiceAffix.ValueSource.SELF_VALUE
	hand[0].inherent_affixes.append(affix)
	
	var result = proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	# value_source SELF_VALUE → resolved = 4, so 4 + 4 = 8
	assert_eq(hand[0].modified_value, 8, "4 + self(4) = 8")
	print("  ✓ value_source_self_value")

func test_value_source_self_value_fraction():
	begin("value_source_self_value_fraction")
	var proc = make_processor()
	var hand = make_hand([6])
	
	var affix = make_affix("HalfSelf")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.neighbor_target = DiceAffix.NeighborTarget.SELF
	affix.effect_type = DiceAffix.EffectType.SET_MINIMUM_VALUE
	affix.value_source = DiceAffix.ValueSource.SELF_VALUE_FRACTION
	affix.effect_value = 0.5  # 50% of self
	hand[0].inherent_affixes.append(affix)
	
	# Value is 6, 50% = 3, SET_MINIMUM_VALUE 3 on a die already at 6 → no change
	var result = proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	assert_eq(hand[0].modified_value, 6, "min(3) on value 6 → stays 6")
	
	# Now test with low value
	var hand2 = make_hand([2])
	var affix2 = make_affix("HalfSelf2")
	affix2.trigger = DiceAffix.Trigger.ON_ROLL
	affix2.effect_type = DiceAffix.EffectType.SET_MINIMUM_VALUE
	affix2.value_source = DiceAffix.ValueSource.SELF_VALUE_FRACTION
	affix2.effect_value = 3.0  # 300% of self = 6
	hand2[0].inherent_affixes.append(affix2)
	
	proc.process_trigger(hand2, DiceAffix.Trigger.ON_ROLL, {})
	assert_eq(hand2[0].modified_value, 6, "min(6) on value 2 → raised to 6")
	print("  ✓ value_source_self_value_fraction")

func test_value_source_neighbor_percent():
	begin("value_source_neighbor_percent")
	var proc = make_processor()
	var hand = make_hand([3, 6])  # die[0] steals from die[1]
	
	var affix = make_affix("StealHalf")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.neighbor_target = DiceAffix.NeighborTarget.RIGHT
	affix.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	affix.value_source = DiceAffix.ValueSource.NEIGHBOR_PERCENT
	affix.effect_value = 0.5  # 50% of target's value
	hand[0].inherent_affixes.append(affix)
	
	var result = proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	# Target is RIGHT (die[1], value=6), 50% of 6 = 3, applied to die[1] as target
	# Wait — NEIGHBOR_PERCENT resolves as target_die.get_total_value() * effect_value
	# And the targets are get_target_indices which for RIGHT on index 0 = [1]
	# So die[1] gets +3 → 6+3=9
	assert_eq(hand[1].modified_value, 9, "die[1]: 6 + 50%(6)=3 → 9")
	print("  ✓ value_source_neighbor_percent")

func test_value_source_context_used_count():
	begin("value_source_context_used_count")
	var proc = make_processor()
	var hand = make_hand([4])
	
	var affix = make_affix("PerUsed")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	affix.value_source = DiceAffix.ValueSource.CONTEXT_USED_COUNT
	affix.effect_value = 2.0  # +2 per used die
	hand[0].inherent_affixes.append(affix)
	
	var ctx = {"used_count": 3}
	proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, ctx)
	# 3 * 2.0 = 6, so 4 + 6 = 10
	assert_eq(hand[0].modified_value, 10, "4 + (3 used × 2) = 10")
	print("  ✓ value_source_context_used_count")

# ============================================================================
# TESTS: Sub-Effects
# ============================================================================

func test_sub_effects_both_fire():
	begin("sub_effects_both_fire")
	var proc = make_processor()
	var hand = make_hand([3])
	
	var affix = make_affix("DoubleBonus")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.neighbor_target = DiceAffix.NeighborTarget.SELF
	
	var sub1 = make_sub_effect()
	sub1.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	sub1.effect_value = 2.0
	
	var sub2 = make_sub_effect()
	sub2.effect_type = DiceAffix.EffectType.ADD_TAG
	sub2.effect_data = {"tag": "boosted"}
	
	affix.sub_effects = [sub1, sub2]
	hand[0].inherent_affixes.append(affix)
	
	proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	assert_eq(hand[0].modified_value, 5, "3 + 2 from sub_effect[0]")
	assert_true(hand[0].has_tag("boosted"), "tag from sub_effect[1]")
	print("  ✓ sub_effects_both_fire")

func test_sub_effects_target_override():
	begin("sub_effects_target_override")
	var proc = make_processor()
	var hand = make_hand([3, 5, 4])
	
	# Affix on die[1]: sub[0] targets LEFT, sub[1] targets SELF
	var affix = make_affix("SplitTarget")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.neighbor_target = DiceAffix.NeighborTarget.SELF  # default
	
	var sub_left = make_sub_effect()
	sub_left.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	sub_left.effect_value = -1.0
	sub_left.override_target = true
	sub_left.target_override = DiceAffix.NeighborTarget.LEFT
	
	var sub_self = make_sub_effect()
	sub_self.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	sub_self.effect_value = 1.0
	sub_self.override_target = true
	sub_self.target_override = DiceAffix.NeighborTarget.SELF
	
	affix.sub_effects = [sub_left, sub_self]
	hand[1].inherent_affixes.append(affix)
	
	proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	assert_eq(hand[0].modified_value, 2, "left neighbor: 3 - 1 = 2")
	assert_eq(hand[1].modified_value, 6, "self: 5 + 1 = 6")
	assert_eq(hand[2].modified_value, 4, "right neighbor: unchanged")
	print("  ✓ sub_effects_target_override")

func test_sub_effects_condition_override():
	begin("sub_effects_condition_override")
	var proc = make_processor()
	var hand = make_hand([2])  # Low value
	
	var affix = make_affix("ConditionalSub")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.neighbor_target = DiceAffix.NeighborTarget.SELF
	
	# Sub[0]: always fires
	var sub_always = make_sub_effect()
	sub_always.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	sub_always.effect_value = 1.0
	
	# Sub[1]: only fires if value >= 5 (won't fire on value 2)
	var sub_gated = make_sub_effect()
	sub_gated.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	sub_gated.effect_value = 10.0
	sub_gated.condition_override = make_condition(DiceAffixCondition.Type.SELF_VALUE_ABOVE, 5.0)
	
	affix.sub_effects = [sub_always, sub_gated]
	hand[0].inherent_affixes.append(affix)
	
	proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	# sub[0] fires: 2+1=3, sub[1] blocked (3 < 5): stays 3
	assert_eq(hand[0].modified_value, 3, "only sub[0] fired: 2+1=3, sub[1] blocked")
	print("  ✓ sub_effects_condition_override")

# ============================================================================
# TESTS: New Effect Types
# ============================================================================

func test_effect_remove_all_tags():
	begin("effect_remove_all_tags")
	var proc = make_processor()
	var hand = make_hand([4])
	hand[0].add_tag("fire")
	hand[0].add_tag("cursed")
	hand[0].add_tag("holy")
	
	var affix = make_affix("Purify")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.REMOVE_ALL_TAGS
	hand[0].inherent_affixes.append(affix)
	
	proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	assert_eq(hand[0].get_tags().size(), 0, "all tags removed")
	print("  ✓ effect_remove_all_tags")

func test_effect_randomize_element():
	begin("effect_randomize_element")
	var proc = make_processor()
	var hand = make_hand([4])
	hand[0].element = DieResource.Element.NONE
	
	var affix = make_affix("Prism")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.RANDOMIZE_ELEMENT
	affix.effect_data = {"elements": ["FIRE", "ICE", "SHOCK"]}
	hand[0].inherent_affixes.append(affix)
	
	var result = proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	assert_neq(hand[0].element, DieResource.Element.NONE, "element changed from NONE")
	
	var found_effect := false
	for eff in result.special_effects:
		if eff.type == "randomize_element":
			found_effect = true
	assert_true(found_effect, "randomize_element in special_effects")
	print("  ✓ effect_randomize_element")

func test_effect_set_element():
	begin("effect_set_element")
	var proc = make_processor()
	var hand = make_hand([4])
	
	var affix = make_affix("SetFire")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.SET_ELEMENT
	affix.effect_data = {"element": "FIRE"}
	hand[0].inherent_affixes.append(affix)
	
	proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	assert_eq(hand[0].element, DieResource.Element.FIRE, "element set to FIRE")
	print("  ✓ effect_set_element")

func test_effect_leech_heal():
	begin("effect_leech_heal")
	var proc = make_processor()
	var hand = make_hand([4])
	
	var affix = make_affix("Leech")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.LEECH_HEAL
	affix.effect_data = {"percent": 0.25}
	hand[0].inherent_affixes.append(affix)
	
	var result = proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	var found := false
	for eff in result.special_effects:
		if eff.type == "leech_heal" and eff.percent == 0.25:
			found = true
	assert_true(found, "leech_heal with 0.25 in special_effects")
	print("  ✓ effect_leech_heal")

func test_effect_destroy_self():
	begin("effect_destroy_self")
	var proc = make_processor()
	var hand = make_hand([4])
	
	var affix = make_affix("SelfDestruct")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.DESTROY_SELF
	hand[0].inherent_affixes.append(affix)
	
	var result = proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	var found := false
	for eff in result.special_effects:
		if eff.type == "destroy_from_pool":
			found = true
	assert_true(found, "destroy_from_pool in special_effects")
	print("  ✓ effect_destroy_self")

func test_effect_create_combat_modifier():
	begin("effect_create_combat_modifier")
	var proc = make_processor()
	var hand = make_hand([4])
	
	var mod = make_combat_modifier()
	mod.mod_type = CombatModifier.ModType.FLAT_BONUS
	mod.value = 2.0
	mod.duration = CombatModifier.Duration.COMBAT
	mod.target_filter = CombatModifier.TargetFilter.ALL_DICE
	mod.source_name = "Vanguard"
	
	var affix = make_affix("Vanguard")
	affix.trigger = DiceAffix.Trigger.ON_ROLL
	affix.effect_type = DiceAffix.EffectType.CREATE_COMBAT_MODIFIER
	affix.combat_modifier = mod
	hand[0].inherent_affixes.append(affix)
	
	var result = proc.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, {})
	var found := false
	for eff in result.special_effects:
		if eff.type == "create_combat_modifier":
			assert_true(eff.modifier is CombatModifier, "modifier is CombatModifier")
			assert_eq(eff.modifier.value, 2.0, "modifier value is 2.0")
			found = true
	assert_true(found, "create_combat_modifier in special_effects")
	print("  ✓ effect_create_combat_modifier")

# ============================================================================
# TESTS: Ghost Hand
# ============================================================================

func test_ghost_hand_consume_preserves_array():
	begin("ghost_hand_consume_preserves_array")
	var collection = make_collection()
	collection._ready()
	
	# Add dice to pool
	for i in range(3):
		collection.add_die(make_die(6, 4))
	
	# Simulate roll
	collection.hand = make_hand([3, 5, 4])
	collection._original_hand_size = 3
	
	var die_to_consume = collection.hand[1]
	collection.consume_from_hand(die_to_consume)
	
	assert_eq(collection.hand.size(), 3, "hand array still has 3 elements")
	assert_true(die_to_consume.is_consumed, "consumed die is marked")
	assert_eq(collection.hand[1], die_to_consume, "die still at same index")
	
	collection.queue_free()
	print("  ✓ ghost_hand_consume_preserves_array")

func test_ghost_hand_on_use_sees_neighbors():
	begin("ghost_hand_on_use_sees_neighbors")
	var collection = make_collection()
	collection._ready()
	
	# Setup pool so process_trigger works
	for i in range(3):
		collection.add_die(make_die(6, 4))
	
	# Create hand with affix on middle die that buffs RIGHT on use
	var hand = make_hand([3, 5, 4])
	var affix = make_affix("Relay")
	affix.trigger = DiceAffix.Trigger.ON_USE
	affix.neighbor_target = DiceAffix.NeighborTarget.RIGHT
	affix.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	affix.effect_value = 2.0
	hand[1].inherent_affixes.append(affix)
	
	collection.hand = hand
	collection._original_hand_size = 3
	
	# Consume die[1] — its ON_USE should buff die[2]
	collection.consume_from_hand(hand[1])
	
	assert_eq(hand[2].modified_value, 6, "right neighbor: 4 + 2 = 6")
	assert_eq(hand[0].modified_value, 3, "left neighbor: unchanged")
	
	collection.queue_free()
	print("  ✓ ghost_hand_on_use_sees_neighbors")

func test_ghost_hand_consumed_dice_skip_activation():
	begin("ghost_hand_consumed_dice_skip_activation")
	var collection = make_collection()
	collection._ready()
	
	for i in range(3):
		collection.add_die(make_die(6, 4))
	
	# Both die[0] and die[1] have ON_USE affixes
	var hand = make_hand([3, 5, 4])
	
	var affix0 = make_affix("Die0Bonus")
	affix0.trigger = DiceAffix.Trigger.ON_USE
	affix0.effect_type = DiceAffix.EffectType.ADD_TAG
	affix0.effect_data = {"tag": "die0_used"}
	hand[0].inherent_affixes.append(affix0)
	
	var affix1 = make_affix("Die1Bonus")
	affix1.trigger = DiceAffix.Trigger.ON_USE
	affix1.effect_type = DiceAffix.EffectType.ADD_TAG
	affix1.effect_data = {"tag": "die1_used"}
	hand[1].inherent_affixes.append(affix1)
	
	collection.hand = hand
	collection._original_hand_size = 3
	
	# Consume die[1] — only die[1]'s ON_USE should fire
	collection.consume_from_hand(hand[1])
	
	assert_true(hand[1].has_tag("die1_used"), "die[1]'s ON_USE fired")
	assert_true(not hand[0].has_tag("die0_used"), "die[0]'s ON_USE did NOT fire")
	
	collection.queue_free()
	print("  ✓ ghost_hand_consumed_dice_skip_activation")

func test_ghost_hand_restore_clears_consumed():
	begin("ghost_hand_restore_clears_consumed")
	var collection = make_collection()
	collection._ready()
	
	for i in range(3):
		collection.add_die(make_die(6, 4))
	
	collection.hand = make_hand([3, 5, 4])
	collection._original_hand_size = 3
	
	var die = collection.hand[1]
	collection.consume_from_hand(die)
	assert_true(die.is_consumed, "consumed after consume_from_hand")
	
	collection.restore_to_hand(die)
	assert_true(not die.is_consumed, "restored: is_consumed cleared")
	assert_eq(collection.hand.size(), 3, "array size unchanged")
	
	collection.queue_free()
	print("  ✓ ghost_hand_restore_clears_consumed")

func test_ghost_hand_unconsumed_queries():
	begin("ghost_hand_unconsumed_queries")
	var collection = make_collection()
	collection._ready()
	
	for i in range(4):
		collection.add_die(make_die(6, 4))
	
	collection.hand = make_hand([3, 5, 4, 2])
	collection._original_hand_size = 4
	
	collection.consume_from_hand(collection.hand[1])
	collection.consume_from_hand(collection.hand[3])
	
	assert_eq(collection.get_unconsumed_count(), 2, "2 unconsumed")
	assert_eq(collection.get_unconsumed_hand().size(), 2, "get_unconsumed_hand returns 2")
	assert_eq(collection.get_consumed_hand().size(), 2, "get_consumed_hand returns 2")
	assert_eq(collection.get_full_hand().size(), 4, "get_full_hand returns all 4")
	
	collection.queue_free()
	print("  ✓ ghost_hand_unconsumed_queries")

func test_ghost_hand_available_dice_legacy():
	begin("ghost_hand_available_dice_legacy")
	var collection = make_collection()
	collection._ready()
	
	for i in range(3):
		collection.add_die(make_die(6, 4))
	
	collection.hand = make_hand([3, 5, 4])
	collection._original_hand_size = 3
	
	collection.consume_from_hand(collection.hand[0])
	
	# Legacy getter should return only unconsumed
	var avail = collection.available_dice
	assert_eq(avail.size(), 2, "available_dice returns 2 (legacy compat)")
	
	collection.queue_free()
	print("  ✓ ghost_hand_available_dice_legacy")

# ============================================================================
# TESTS: Combat Modifiers
# ============================================================================

func test_combat_modifier_flat_bonus():
	begin("combat_modifier_flat_bonus")
	var mod = make_combat_modifier()
	mod.mod_type = CombatModifier.ModType.FLAT_BONUS
	mod.value = 3.0
	mod.target_filter = CombatModifier.TargetFilter.ALL_DICE
	
	var die = make_die(6, 4)
	assert_true(mod.applies_to_die(die, 0), "ALL_DICE applies to any die")
	
	mod.apply_to_die(die)
	assert_eq(die.modified_value, 7, "4 + 3 = 7")
	print("  ✓ combat_modifier_flat_bonus")

func test_combat_modifier_all_except_source():
	begin("combat_modifier_all_except_source")
	var mod = make_combat_modifier()
	mod.mod_type = CombatModifier.ModType.FLAT_BONUS
	mod.value = 2.0
	mod.target_filter = CombatModifier.TargetFilter.ALL_EXCEPT_SOURCE
	mod.source_slot_index = 1
	
	var die0 = make_die(6, 3)
	die0.slot_index = 0
	var die1 = make_die(6, 3)
	die1.slot_index = 1
	var die2 = make_die(6, 3)
	die2.slot_index = 2
	
	assert_true(mod.applies_to_die(die0, 0), "die0: not source → applies")
	assert_true(not mod.applies_to_die(die1, 1), "die1: is source → skipped")
	assert_true(mod.applies_to_die(die2, 2), "die2: not source → applies")
	print("  ✓ combat_modifier_all_except_source")

func test_combat_modifier_turn_expiry():
	begin("combat_modifier_turn_expiry")
	var mod = make_combat_modifier()
	mod.duration = CombatModifier.Duration.TURNS
	mod.turns_remaining = 2
	
	assert_true(not mod.tick_turn(), "tick 1: not expired (1 remaining)")
	assert_eq(mod.turns_remaining, 1, "1 turn left")
	
	assert_true(mod.tick_turn(), "tick 2: expired (0 remaining)")
	assert_true(mod.is_expired(), "is_expired returns true")
	print("  ✓ combat_modifier_turn_expiry")

# ============================================================================
# TEST: Full Combat Turn Flow
# ============================================================================

func test_full_combat_turn_flow():
	begin("full_combat_turn_flow")
	var collection = make_collection()
	collection._ready()
	
	# Build pool: 3 dice, middle one has Relay (ON_USE → +2 to right)
	var d0 = make_die(6, 3)
	var d1 = make_die(6, 4)
	var d2 = make_die(6, 5)
	
	var relay = make_affix("Relay")
	relay.trigger = DiceAffix.Trigger.ON_USE
	relay.neighbor_target = DiceAffix.NeighborTarget.RIGHT
	relay.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
	relay.effect_value = 2.0
	d1.inherent_affixes.append(relay)
	
	collection.add_die(d0)
	collection.add_die(d1)
	collection.add_die(d2)
	
	# Simulate combat start
	collection._current_turn = 0
	collection.combat_modifiers.clear()
	
	# Manually create hand (skip actual rolling for determinism)
	collection.hand.clear()
	collection.used_pool_indices.clear()
	var h0 = d0.duplicate_die()
	h0.slot_index = 0
	h0.current_value = 3
	h0.modified_value = 3
	var h1 = d1.duplicate_die()
	h1.slot_index = 1
	h1.current_value = 4
	h1.modified_value = 4
	var h2 = d2.duplicate_die()
	h2.slot_index = 2
	h2.current_value = 5
	h2.modified_value = 5
	collection.hand = [h0, h1, h2] as Array[DieResource]
	collection._original_hand_size = 3
	collection._current_turn = 1
	
	# Use die[0] first — no ON_USE affixes, just consumed
	collection.consume_from_hand(h0)
	assert_true(h0.is_consumed, "h0 consumed")
	assert_eq(collection.hand.size(), 3, "array stable at 3")
	assert_eq(collection.get_unconsumed_count(), 2, "2 remaining")
	
	# Use die[1] — Relay should buff die[2] by +2
	collection.consume_from_hand(h1)
	assert_true(h1.is_consumed, "h1 consumed")
	assert_eq(h2.modified_value, 7, "h2: 5 + 2 (Relay) = 7")
	assert_eq(collection.get_unconsumed_count(), 1, "1 remaining")
	
	# Use die[2] — last die
	collection.consume_from_hand(h2)
	assert_eq(collection.get_unconsumed_count(), 0, "0 remaining")
	assert_eq(collection.hand.size(), 3, "array still 3")
	
	collection.queue_free()
	print("  ✓ full_combat_turn_flow")
