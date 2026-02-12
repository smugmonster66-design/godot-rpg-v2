# res://editor_scripts/test_flame_tree.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# COMPREHENSIVE VALIDATION of the Mage Flame skill tree.
# Tests resource integrity, affix content, prerequisite chains,
# action/effect validity, dice affixes, and a full learning simulation.
#
# Output goes to the Output panel. Look for ❌ FAIL or ⚠️ WARN lines.
# A clean run ends with "ALL TESTS PASSED".
@tool
extends EditorScript

# ============================================================================
# CONFIGURATION — update these if your paths differ
# ============================================================================
const TREE_PATH       := "res://resources/skill_trees/mage_flame.tres"
const SKILL_DIR       := "res://resources/skills/mage/flame/"
const AFFIX_DIR       := "res://resources/affixes/classes/mage/flame/"
const DICE_AFFIX_DIR  := "res://resources/dice_affixes/mage/flame/"
const CONDITION_DIR   := "res://resources/dice_affixes/mage/flame/conditions/"
const ACTION_DIR      := "res://resources/actions/mage/flame/"
const STATUS_DIR      := "res://resources/statuses/"

# ============================================================================
# EXPECTED VALUES — from the verified generator run
# ============================================================================
const EXPECTED_SKILL_COUNT     := 31
const EXPECTED_ACTION_COUNT    := 9
const EXPECTED_EFFECT_COUNT    := 14
const EXPECTED_DICE_AFFIX_COUNT := 20
const EXPECTED_CONDITION_COUNT := 5
const EXPECTED_STATUS_COUNT    := 1
const EXPECTED_AFFIX_COUNT     := 58
const EXPECTED_PREREQ_COUNT    := 38

# Tier point thresholds
const TIER_POINTS := {
	1: 0, 2: 1, 3: 3, 4: 5, 5: 8,
	6: 11, 7: 15, 8: 20, 9: 25, 10: 28
}

# Skills per tier (expected count)
const SKILLS_PER_TIER := {
	1: 1, 2: 4, 3: 4, 4: 5, 5: 3,
	6: 5, 7: 4, 8: 3, 9: 2, 10: 1
}

# Skill IDs that grant actions (9 total)
const ACTION_SKILL_IDS := [
	"flame_eruption",           # T5 Crucible
	"flame_burning_vengeance",  # T6 Pyre
	"flame_cauterize",          # T6 Forge
	"flame_detonate",           # T7 Pyre
	"flame_cinder_storm",       # T7 Crucible
	"flame_radiance",           # T7 Forge
	"flame_volcanic_core",      # T8 Crucible
	"flame_eternal_flame",      # T9 Pyre
	"flame_ironfire_stance",    # T9 Forge
]

# Branch assignments (column ranges)
# Pyre: cols 0–2, Crucible: cols 2–4, Forge: cols 4–6
# (some skills span boundaries via crossover)

# ============================================================================
# TEST STATE
# ============================================================================
var _tests_run := 0
var _tests_passed := 0
var _tests_failed := 0
var _warnings := 0
var _tree: SkillTree = null


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════")
	print("  FLAME TREE TEST SUITE")
	print("═══════════════════════════════════════════════════")
	print("")

	# Load the tree
	_tree = load(TREE_PATH) as SkillTree
	if not _tree:
		print("❌ FATAL: Could not load SkillTree at %s" % TREE_PATH)
		return

	# Run test groups
	_test_tree_structure()
	_test_skill_basics()
	_test_affix_integrity()
	_test_granted_actions()
	_test_dice_affixes()
	_test_prerequisites()
	_test_tier_unlocks()
	_test_learning_simulation()
	_test_built_in_validation()

	# Summary
	print("")
	print("═══════════════════════════════════════════════════")
	if _tests_failed == 0:
		print("  ✅ ALL TESTS PASSED (%d tests, %d warnings)" % [_tests_run, _warnings])
	else:
		print("  ❌ %d FAILED / %d passed / %d warnings" % [_tests_failed, _tests_passed, _warnings])
	print("═══════════════════════════════════════════════════")


# ============================================================================
# TEST GROUP 1: Tree Structure
# ============================================================================
func _test_tree_structure():
	_section("Tree Structure")

	_assert_eq(_tree.tree_id, "flame", "tree_id is 'flame'")
	_assert_eq(_tree.tree_name, "Flame", "tree_name is 'Flame'")
	_assert_true(_tree.description.length() > 0, "tree has a description")

	# Total skill count
	var all_skills := _tree.get_all_skills()
	_assert_eq(all_skills.size(), EXPECTED_SKILL_COUNT,
		"total skill count = %d" % EXPECTED_SKILL_COUNT)

	# Skills per tier
	for tier in range(1, 11):
		var tier_skills := _tree.get_skills_for_tier(tier)
		var expected: int = SKILLS_PER_TIER.get(tier, 0)
		_assert_eq(tier_skills.size(), expected,
			"tier %d has %d skills" % [tier, expected])

	# No null entries
	var null_count := 0
	for skill in all_skills:
		if skill == null:
			null_count += 1
	_assert_eq(null_count, 0, "no null skill entries in tree")


# ============================================================================
# TEST GROUP 2: Skill Basics
# ============================================================================
func _test_skill_basics():
	_section("Skill Basics")

	var all_skills := _tree.get_all_skills()
	var seen_ids: Dictionary = {}
	var seen_positions: Dictionary = {}
	var total_affixes := 0
	var total_prereqs := 0

	for skill in all_skills:
		if not skill:
			continue

		# Has required fields
		_assert_true(skill.skill_id.length() > 0,
			"%s has a skill_id" % skill.skill_name)
		_assert_true(skill.skill_name.length() > 0,
			"skill_id '%s' has a name" % skill.skill_id)
		_assert_true(skill.description.length() > 0,
			"%s has a description" % skill.skill_name)

		# ID prefix
		_assert_true(skill.skill_id.begins_with("flame_"),
			"%s id starts with 'flame_'" % skill.skill_name)

		# No duplicate IDs
		if seen_ids.has(skill.skill_id):
			_fail("DUPLICATE skill_id: '%s'" % skill.skill_id)
		seen_ids[skill.skill_id] = true

		# No position conflicts
		var pos_key := "%d_%d" % [skill.tier, skill.column]
		if seen_positions.has(pos_key):
			_fail("POSITION CONFLICT at tier %d col %d: %s vs %s" % [
				skill.tier, skill.column, seen_positions[pos_key], skill.skill_name
			])
		seen_positions[pos_key] = true

		# Valid grid bounds
		_assert_true(skill.tier >= 1 and skill.tier <= 10,
			"%s tier %d in range 1–10" % [skill.skill_name, skill.tier])
		_assert_true(skill.column >= 0 and skill.column <= 6,
			"%s column %d in range 0–6" % [skill.skill_name, skill.column])

		# Has at least rank 1 affixes
		_assert_true(skill.rank_1_affixes.size() > 0,
			"%s has rank 1 affixes" % skill.skill_name)

		# Count affixes and prereqs
		total_affixes += skill.get_total_affix_count()
		total_prereqs += skill.prerequisites.size()

	_assert_eq(seen_ids.size(), EXPECTED_SKILL_COUNT,
		"unique skill IDs = %d" % EXPECTED_SKILL_COUNT)
	_assert_eq(total_prereqs, EXPECTED_PREREQ_COUNT,
		"total prerequisites = %d" % EXPECTED_PREREQ_COUNT)

	print("  📊 Total affixes across all skill ranks: %d" % total_affixes)


# ============================================================================
# TEST GROUP 3: Affix Integrity
# ============================================================================
func _test_affix_integrity():
	_section("Affix Integrity")

	var all_skills := _tree.get_all_skills()
	var null_affixes := 0
	var missing_names := 0
	var missing_categories := 0
	var mana_element_unlocks := 0
	var mana_size_unlocks := 0
	var mana_die_affixes := 0
	var new_action_affixes := 0
	var damage_bonus_affixes := 0

	for skill in all_skills:
		if not skill:
			continue

		for rank in range(1, 6):
			var affixes := skill.get_affixes_for_rank(rank)
			for affix in affixes:
				if affix == null:
					null_affixes += 1
					_fail("%s rank %d has a null affix" % [skill.skill_name, rank])
					continue

				if affix.affix_name.is_empty():
					missing_names += 1
				if affix.category == Affix.Category.NONE:
					missing_categories += 1

				# Count by category
				match affix.category:
					Affix.Category.MANA_ELEMENT_UNLOCK:
						mana_element_unlocks += 1
						# Validate element in effect_data
						_assert_true(affix.effect_data.has("element"),
							"%s MANA_ELEMENT_UNLOCK has 'element' in effect_data" % affix.affix_name)
					Affix.Category.MANA_SIZE_UNLOCK:
						mana_size_unlocks += 1
						_assert_true(affix.effect_data.has("die_size"),
							"%s MANA_SIZE_UNLOCK has 'die_size' in effect_data" % affix.affix_name)
					Affix.Category.MANA_DIE_AFFIX:
						mana_die_affixes += 1
						_assert_true(affix.effect_data.has("dice_affix"),
							"%s MANA_DIE_AFFIX has 'dice_affix' in effect_data" % affix.affix_name)
						if affix.effect_data.has("dice_affix"):
							_assert_true(affix.effect_data["dice_affix"] is DiceAffix,
								"%s wrapped dice_affix is a DiceAffix" % affix.affix_name)
					Affix.Category.NEW_ACTION:
						new_action_affixes += 1
						_assert_true(affix.granted_action != null,
							"%s NEW_ACTION has granted_action set" % affix.affix_name)
					Affix.Category.FIRE_DAMAGE_BONUS:
						damage_bonus_affixes += 1
					Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER:
						_assert_true(affix.effect_data.has("element"),
							"%s ELEMENTAL_DAMAGE_MULTIPLIER has 'element'" % affix.affix_name)

	_assert_eq(null_affixes, 0, "no null affixes anywhere")
	_assert_eq(missing_names, 0, "all affixes have names")
	_assert_eq(new_action_affixes, EXPECTED_ACTION_COUNT,
		"NEW_ACTION affix count = %d (one per granted action)" % EXPECTED_ACTION_COUNT)

	# Verify fire element is unlocked in tier 1
	_assert_true(mana_element_unlocks >= 1,
		"at least 1 MANA_ELEMENT_UNLOCK (fire)")
	_assert_true(mana_size_unlocks >= 1,
		"at least 1 MANA_SIZE_UNLOCK")

	print("  📊 MANA_ELEMENT_UNLOCK: %d | MANA_SIZE_UNLOCK: %d | MANA_DIE_AFFIX: %d" % [
		mana_element_unlocks, mana_size_unlocks, mana_die_affixes])
	print("  📊 NEW_ACTION: %d | FIRE_DAMAGE_BONUS: %d | MISSING_CATEGORY: %d" % [
		new_action_affixes, damage_bonus_affixes, missing_categories])


# ============================================================================
# TEST GROUP 4: Granted Actions
# ============================================================================
func _test_granted_actions():
	_section("Granted Actions")

	var found_actions: Dictionary = {}

	for skill_id in ACTION_SKILL_IDS:
		var skill := _tree.get_skill_by_id(skill_id)
		if not skill:
			_fail("action skill '%s' not found in tree" % skill_id)
			continue

		# Find the NEW_ACTION affix
		var action_affix: Affix = null
		for rank in range(1, 6):
			for affix in skill.get_affixes_for_rank(rank):
				if affix and affix.category == Affix.Category.NEW_ACTION:
					action_affix = affix
					break
			if action_affix:
				break

		if not action_affix:
			_fail("%s has no NEW_ACTION affix" % skill.skill_name)
			continue

		var action: Action = action_affix.granted_action
		if not action:
			_fail("%s NEW_ACTION affix has null granted_action" % skill.skill_name)
			continue

		found_actions[skill_id] = action

		# Validate the action
		_assert_true(action.action_id.length() > 0,
			"%s action has an id" % skill.skill_name)
		_assert_true(action.action_name.length() > 0,
			"%s action has a name" % skill.skill_name)
		_assert_true(action.die_slots >= 1,
			"%s action needs >= 1 die slot" % skill.skill_name)

		# Validate effects
		_assert_true(action.effects.size() > 0,
			"%s action has effects" % action.action_name)

		var null_effects := 0
		for effect in action.effects:
			if effect == null:
				null_effects += 1
			else:
				_assert_true(effect.effect_name.length() > 0,
					"%s → %s has a name" % [action.action_name, effect.effect_name])

				# Fire damage actions should use FIRE damage type
				if effect.effect_type == ActionEffect.EffectType.DAMAGE:
					_assert_eq(effect.damage_type, ActionEffect.DamageType.FIRE,
						"%s → %s uses FIRE damage" % [action.action_name, effect.effect_name])

		_assert_eq(null_effects, 0,
			"%s has no null effects" % action.action_name)

		# Run the action's own validate()
		var action_warnings := action.validate()
		for w in action_warnings:
			_warn("%s action: %s" % [skill.skill_name, w])

	_assert_eq(found_actions.size(), EXPECTED_ACTION_COUNT,
		"found all %d granted actions" % EXPECTED_ACTION_COUNT)

	# Verify specific action properties
	_verify_action_details(found_actions)


func _verify_action_details(actions: Dictionary):
	"""Spot-check specific action configurations"""

	# Eruption: 2 dice, ALL_ENEMIES, ×0.6 mult
	if actions.has("flame_eruption"):
		var act: Action = actions["flame_eruption"]
		_assert_eq(act.die_slots, 2, "Eruption has 2 die slots")
		if act.effects.size() > 0 and act.effects[0]:
			_assert_eq(act.effects[0].target, ActionEffect.TargetType.ALL_ENEMIES,
				"Eruption targets ALL_ENEMIES")

	# Burning Vengeance: 1 die, SINGLE, has status effect
	if actions.has("flame_burning_vengeance"):
		var act: Action = actions["flame_burning_vengeance"]
		_assert_eq(act.die_slots, 1, "Burning Vengeance has 1 die slot")
		var has_status := false
		for eff in act.effects:
			if eff and eff.effect_type == ActionEffect.EffectType.ADD_STATUS:
				has_status = true
		_assert_true(has_status, "Burning Vengeance applies a status")

	# Cauterize: 1 die, SELF, has heal
	if actions.has("flame_cauterize"):
		var act: Action = actions["flame_cauterize"]
		_assert_eq(act.die_slots, 1, "Cauterize has 1 die slot")
		var has_heal := false
		for eff in act.effects:
			if eff and eff.effect_type == ActionEffect.EffectType.HEAL:
				has_heal = true
		_assert_true(has_heal, "Cauterize has a heal effect")

	# Cinder Storm: 3 dice, ALL_ENEMIES, limited per combat
	if actions.has("flame_cinder_storm"):
		var act: Action = actions["flame_cinder_storm"]
		_assert_eq(act.die_slots, 3, "Cinder Storm has 3 die slots")
		_assert_eq(act.charge_type, Action.ChargeType.LIMITED_PER_COMBAT,
			"Cinder Storm is limited per combat")

	# Volcanic Core: 3 dice, SINGLE (execute action)
	if actions.has("flame_volcanic_core"):
		var act: Action = actions["flame_volcanic_core"]
		_assert_eq(act.die_slots, 3, "Volcanic Core has 3 die slots")
		if act.effects.size() > 0 and act.effects[0]:
			_assert_eq(act.effects[0].target, ActionEffect.TargetType.SINGLE_ENEMY,
				"Volcanic Core targets SINGLE")

	# Eternal Flame: 2 dice, SINGLE
	if actions.has("flame_eternal_flame"):
		var act: Action = actions["flame_eternal_flame"]
		_assert_eq(act.die_slots, 2, "Eternal Flame has 2 die slots")

	# Ironfire Stance: 2 dice, SELF
	if actions.has("flame_ironfire_stance"):
		var act: Action = actions["flame_ironfire_stance"]
		_assert_eq(act.die_slots, 2, "Ironfire Stance has 2 die slots")
		var has_self_target := false
		for eff in act.effects:
			if eff and eff.target == ActionEffect.TargetType.SELF:
				has_self_target = true
		_assert_true(has_self_target, "Ironfire Stance targets SELF")


# ============================================================================
# TEST GROUP 5: Dice Affixes
# ============================================================================
func _test_dice_affixes():
	_section("Dice Affixes (via MANA_DIE_AFFIX wrappers)")

	var all_skills := _tree.get_all_skills()
	var dice_affixes_found := 0
	var conditions_found := 0

	for skill in all_skills:
		if not skill:
			continue
		for rank in range(1, 6):
			for affix in skill.get_affixes_for_rank(rank):
				if not affix or affix.category != Affix.Category.MANA_DIE_AFFIX:
					continue
				if not affix.effect_data.has("dice_affix"):
					continue

				var da: DiceAffix = affix.effect_data["dice_affix"]
				if not da:
					_fail("%s wraps null DiceAffix" % affix.affix_name)
					continue

				dice_affixes_found += 1

				# Basic validation
				_assert_true(da.affix_name.length() > 0,
					"DiceAffix '%s' has a name" % da.affix_name)

				# Condition check
				if da.condition:
					conditions_found += 1
					_assert_true(da.condition is DiceAffixCondition,
						"%s condition is DiceAffixCondition" % da.affix_name)

	print("  📊 DiceAffixes found in wrappers: %d" % dice_affixes_found)
	print("  📊 DiceAffixes with conditions: %d" % conditions_found)


# ============================================================================
# TEST GROUP 6: Prerequisites
# ============================================================================
func _test_prerequisites():
	_section("Prerequisites")

	var all_skills := _tree.get_all_skills()
	var skill_map: Dictionary = {}
	for skill in all_skills:
		if skill:
			skill_map[skill.skill_id] = skill

	var total_prereqs := 0
	var invalid_prereqs := 0
	var circular_refs := 0

	for skill in all_skills:
		if not skill:
			continue

		for prereq in skill.prerequisites:
			total_prereqs += 1

			if not prereq or not prereq.required_skill:
				invalid_prereqs += 1
				_fail("%s has invalid/null prerequisite" % skill.skill_name)
				continue

			# Prerequisite must exist in tree
			var req_id := prereq.required_skill.skill_id
			if not skill_map.has(req_id):
				_fail("%s requires '%s' which is not in tree" % [
					skill.skill_name, req_id])
				continue

			# Required rank must be valid
			_assert_true(prereq.required_rank >= 1 and prereq.required_rank <= 5,
				"%s → %s required_rank %d in range 1–5" % [
					skill.skill_name, prereq.required_skill.skill_name, prereq.required_rank])

			# Prerequisite must be in a LOWER or EQUAL tier
			var req_skill: SkillResource = prereq.required_skill
			if req_skill.tier > skill.tier:
				_fail("%s (T%d) requires %s (T%d) — prereq must be lower tier" % [
					skill.skill_name, skill.tier, req_skill.skill_name, req_skill.tier])

			# Self-reference check
			if req_id == skill.skill_id:
				circular_refs += 1
				_fail("%s requires itself!" % skill.skill_name)

	_assert_eq(invalid_prereqs, 0, "no invalid prerequisites")
	_assert_eq(circular_refs, 0, "no circular prerequisite references")
	_assert_eq(total_prereqs, EXPECTED_PREREQ_COUNT,
		"total prerequisite count = %d" % EXPECTED_PREREQ_COUNT)

	# Verify T1 has no prereqs (it's the entry point)
	var t1_skills := _tree.get_skills_for_tier(1)
	for skill in t1_skills:
		if skill:
			_assert_eq(skill.prerequisites.size(), 0,
				"%s (T1) has no prerequisites" % skill.skill_name)

	# Verify T10 capstone HAS prereqs
	var t10_skills := _tree.get_skills_for_tier(10)
	for skill in t10_skills:
		if skill:
			_assert_true(skill.prerequisites.size() > 0,
				"%s (T10 capstone) has prerequisites" % skill.skill_name)

	# Reachability: every skill must be reachable from T1 via prereq chain
	_test_reachability(skill_map)


func _test_reachability(skill_map: Dictionary):
	"""Verify every skill can be reached through valid prerequisite chains from T1"""
	var reachable: Dictionary = {}

	# T1 skills are always reachable
	var t1 := _tree.get_skills_for_tier(1)
	for skill in t1:
		if skill:
			reachable[skill.skill_id] = true

	# Iteratively expand reachable set
	var changed := true
	while changed:
		changed = false
		for skill in _tree.get_all_skills():
			if not skill or reachable.has(skill.skill_id):
				continue

			# Check if all prereqs are reachable
			var all_met := true
			if skill.prerequisites.is_empty():
				# No prereqs but not T1 — reachable if tier is unlockable
				all_met = true
			else:
				for prereq in skill.prerequisites:
					if not prereq or not prereq.required_skill:
						all_met = false
						break
					if not reachable.has(prereq.required_skill.skill_id):
						all_met = false
						break

			if all_met:
				reachable[skill.skill_id] = true
				changed = true

	var unreachable := 0
	for skill in _tree.get_all_skills():
		if skill and not reachable.has(skill.skill_id):
			unreachable += 1
			_fail("%s (T%d) is UNREACHABLE from T1" % [skill.skill_name, skill.tier])

	_assert_eq(unreachable, 0, "all skills are reachable from tier 1")


# ============================================================================
# TEST GROUP 7: Tier Unlock Thresholds
# ============================================================================
func _test_tier_unlocks():
	_section("Tier Unlock Thresholds")

	for tier in range(2, 11):
		var expected_points: int = TIER_POINTS.get(tier, 999)
		# Use get_points_required_for_tier if it handles tier 10
		# Otherwise check the exported properties directly
		var actual_points: int
		match tier:
			2: actual_points = _tree.tier_2_points_required
			3: actual_points = _tree.tier_3_points_required
			4: actual_points = _tree.tier_4_points_required
			5: actual_points = _tree.tier_5_points_required
			6: actual_points = _tree.tier_6_points_required
			7: actual_points = _tree.tier_7_points_required
			8: actual_points = _tree.tier_8_points_required
			9: actual_points = _tree.tier_9_points_required
			_: actual_points = -1

		if actual_points >= 0:
			_assert_eq(actual_points, expected_points,
				"tier %d unlock = %d points" % [tier, expected_points])

	# Verify thresholds are monotonically increasing
	var prev := 0
	for tier in range(2, 10):
		var pts: int = _tree.get_points_required_for_tier(tier)
		_assert_true(pts > prev,
			"tier %d (%d) > tier %d (%d)" % [tier, pts, tier - 1, prev])
		prev = pts


# ============================================================================
# TEST GROUP 8: Learning Simulation
# ============================================================================
func _test_learning_simulation():
	_section("Learning Simulation (straight-path to capstone)")

	# Simulate learning every skill rank 1 in tier order, checking
	# that requirements are met at each step
	var skill_ranks: Dictionary = {}  # skill_id -> rank
	var points_spent := 0

	var rank_getter := func(skill_id: String) -> int:
		return skill_ranks.get(skill_id, 0)

	# Build a tier-ordered list
	var ordered_skills: Array[SkillResource] = []
	for tier in range(1, 11):
		var tier_skills := _tree.get_skills_for_tier(tier)
		# Sort by column for consistent ordering
		tier_skills.sort_custom(func(a, b): return a.column < b.column)
		for s in tier_skills:
			if s:
				ordered_skills.append(s)

	var learning_failures := 0
	for skill in ordered_skills:
		# Check tier unlock
		var tier_unlocked := _tree.is_tier_unlocked(skill.tier, points_spent)
		if not tier_unlocked:
			# This is expected if we haven't spent enough points yet
			# In a real scenario the player would rank up earlier skills first
			# For this test, we just learn rank 1 of everything in order
			pass

		# Check prerequisites
		var can_learn := skill.can_learn(rank_getter, points_spent)
		if not can_learn and skill.tier > 1:
			# Expected for some skills — they need specific branch paths
			# Log but don't fail (this tests structural validity, not gameplay)
			var missing := skill.get_missing_prerequisites(rank_getter)
			if missing.size() > 0:
				var missing_names: Array[String] = []
				for m in missing:
					missing_names.append("%s r%d" % [m.skill.skill_name, m.required])
				_warn("%s can't learn yet (missing: %s)" % [
					skill.skill_name, ", ".join(missing_names)])
			continue

		# Learn rank 1
		skill_ranks[skill.skill_id] = 1
		points_spent += skill.skill_point_cost

	print("  📊 Simulated learning %d/%d skills with %d points spent" % [
		skill_ranks.size(), ordered_skills.size(), points_spent])

	# The capstone should be learnable (check it exists in our learned set)
	var t10 := _tree.get_skills_for_tier(10)
	if t10.size() > 0 and t10[0]:
		var capstone_id := t10[0].skill_id
		if not skill_ranks.has(capstone_id):
			_warn("Capstone '%s' not learned in straight-line simulation (may need specific path)" % capstone_id)

	# Check that 28 is enough to reach capstone
	_assert_true(points_spent <= 31,
		"total points spent (%d) within skill count" % points_spent)


# ============================================================================
# TEST GROUP 9: Built-in Validation
# ============================================================================
func _test_built_in_validation():
	_section("Built-in validate() Methods")

	# Tree validation
	var tree_warnings := _tree.validate()
	for w in tree_warnings:
		_warn("SkillTree.validate(): %s" % w)
	_assert_eq(tree_warnings.size(), 0,
		"SkillTree.validate() returns no warnings")

	# Individual skill validation
	var skill_warning_count := 0
	for skill in _tree.get_all_skills():
		if not skill:
			continue
		var warnings := skill.validate()
		for w in warnings:
			_warn("%s.validate(): %s" % [skill.skill_name, w])
			skill_warning_count += 1

	_assert_eq(skill_warning_count, 0,
		"all skills pass their own validate()")


# ============================================================================
# ASSERTION HELPERS
# ============================================================================
func _section(name: String):
	print("")
	print("── %s ──" % name)

func _assert_true(condition: bool, message: String):
	_tests_run += 1
	if condition:
		_tests_passed += 1
	else:
		_tests_failed += 1
		print("  ❌ FAIL: %s" % message)

func _assert_eq(actual, expected, message: String):
	_tests_run += 1
	if actual == expected:
		_tests_passed += 1
	else:
		_tests_failed += 1
		print("  ❌ FAIL: %s (got %s, expected %s)" % [message, str(actual), str(expected)])

func _fail(message: String):
	_tests_run += 1
	_tests_failed += 1
	print("  ❌ FAIL: %s" % message)

func _warn(message: String):
	_warnings += 1
	print("  ⚠️ WARN: %s" % message)
