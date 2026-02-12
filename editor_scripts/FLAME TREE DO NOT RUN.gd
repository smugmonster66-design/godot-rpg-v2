# res://editor_scripts/generate_flame_tree.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# WHAT THIS DOES:
#   Creates the complete 31-skill Mage Flame skill tree:
#   - 31 SkillResource .tres files
#   - ~75 backing Affix .tres files
#   - ~12 DiceAffix .tres files
#   - ~8 DiceAffixCondition .tres files
#   - 9 Action .tres + ~22 ActionEffect .tres files
#   - 1 StatusAffix (eternal_flame_mark)
#   - ~35 SkillPrerequisite sub-resources
#   - 1 SkillTree (mage_flame.tres)
#
# SAFE TO RE-RUN: Overwrites existing files at the same paths.
#
# CHUNK 2 of 4: Foundation helpers + Tiers 1–4 (14 skills)
# Tiers 5–10 and SkillTree assembly are in the next chunk and
# append to the same file.
#
@tool
extends EditorScript

# ============================================================================
# DIRECTORY STRUCTURE
# ============================================================================

const BASE_AFFIX_DIR  := "res://resources/affixes/classes/mage/flame/"
const BASE_SKILL_DIR  := "res://resources/skills/classes/mage/flame/"
const DICE_AFFIX_DIR  := "res://resources/dice_affixes/mage/flame/"
const CONDITION_DIR   := "res://resources/dice_affixes/mage/flame/conditions/"
const ACTION_DIR      := "res://resources/actions/mage/flame/"
const EFFECT_DIR      := "res://resources/actions/mage/flame/effects/"
const STATUS_DIR      := "res://resources/statuses/"
const TREE_DIR        := "res://resources/skill_trees/"

# Counters for summary
var _created_skills := 0
var _created_affixes := 0
var _created_dice_affixes := 0
var _created_conditions := 0
var _created_actions := 0
var _created_effects := 0
var _created_statuses := 0

# Skill lookup for prerequisite wiring (populated during creation)
var _skill_lookup: Dictionary = {}  # skill_id -> SkillResource

# ============================================================================
# ENTRY POINT
# ============================================================================

func _run() -> void:
	# --- DEBUG: Test class instantiation ---
	var test_affix = Affix.new()
	print("Affix.new() = %s" % test_affix)
	var test_skill = SkillResource.new()
	print("SkillResource.new() = %s" % test_skill)
	
	
	# --- DEBUG: Test enum values used by generator ---
	print("MANA_ELEMENT_UNLOCK = %d" % Affix.Category.MANA_ELEMENT_UNLOCK)
	print("MANA_SIZE_UNLOCK = %d" % Affix.Category.MANA_SIZE_UNLOCK)
	print("FIRE_DAMAGE_BONUS = %d" % Affix.Category.FIRE_DAMAGE_BONUS)
	print("MANA_DIE_AFFIX = %d" % Affix.Category.MANA_DIE_AFFIX)
	print("ELEMENTAL_DAMAGE_MULTIPLIER = %d" % Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER)
	print("PROC = %d" % Affix.Category.PROC)
	print("MISC = %d" % Affix.Category.MISC)
	print("--- enum test done ---")
	# --- END DEBUG ---
	
	
	
	
	
	# --- END DEBUG ---
	print("\n" + "═".repeat(60))
	print("  GENERATING MAGE FLAME TREE (31 SKILLS)")
	print("═".repeat(60))

	_ensure_all_dirs()

	# Phase 1: Shared DiceAffixes & Conditions
	_create_shared_dice_affixes()

	# Phase 2: Skills by tier
	_create_tier_1()
	_create_tier_2()
	_create_tier_3()
	_create_tier_4()
	_create_tier_5()
	_create_tier_6()
	_create_tier_7()
	_create_tier_8()
	_create_tier_9()
	_create_tier_10()

	# Phase 3: Wire prerequisites (all skills exist now)
	_wire_prerequisites()

	# Phase 4: Build the SkillTree resource
	_build_skill_tree()

	# Summary
	print("\n" + "═".repeat(60))
	print("  FLAME TREE GENERATION COMPLETE")
	print("═".repeat(60))
	print("  Skills:         %d" % _created_skills)
	print("  Affixes:        %d" % _created_affixes)
	print("  DiceAffixes:    %d" % _created_dice_affixes)
	print("  Conditions:     %d" % _created_conditions)
	print("  Actions:        %d" % _created_actions)
	print("  ActionEffects:  %d" % _created_effects)
	print("  Statuses:       %d" % _created_statuses)
	print("═".repeat(60))


# ============================================================================
# DIRECTORY HELPERS
# ============================================================================

func _ensure_all_dirs():
	for dir in [BASE_AFFIX_DIR, BASE_SKILL_DIR, DICE_AFFIX_DIR, CONDITION_DIR,
				ACTION_DIR, EFFECT_DIR, STATUS_DIR, TREE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)

func _ensure_sub_dir(base: String, sub: String) -> String:
	var path := base + sub + "/"
	DirAccess.make_dir_recursive_absolute(path)
	return path


# ============================================================================
# RESOURCE CREATION HELPERS
# ============================================================================

func _save(resource: Resource, path: String) -> void:
	print("    → _save: %s (%s)" % [path, resource])
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		print("  ❌ SAVE FAILED: %s (error %d)" % [path, err])
	else:
		print("  💾 %s" % path)


# --- Affix (item-level) ---

func _make_affix(p_name: String, p_desc: String, p_category: int,
		p_tags: Array, p_effect_num: float = 0.0,
		p_effect_data: Dictionary = {}) -> Affix:
	var a := Affix.new()
	a.affix_name = p_name
	a.description = p_desc
	a.category = p_category
	a.effect_number = p_effect_num
	if not p_effect_data.is_empty():
		a.effect_data = p_effect_data
	# Convert untyped Array to Array[String] for tags
	var typed_tags: Array[String] = []
	typed_tags.assign(p_tags)
	a.tags = typed_tags
	_created_affixes += 1
	return a

func _save_affix(affix: Affix, skill_folder: String, filename: String) -> Affix:
	print("    → _save_affix: %s/%s" % [skill_folder, filename])
	var dir := _ensure_sub_dir(BASE_AFFIX_DIR, skill_folder)
	print("    → dir: %s" % dir)
	_save(affix, dir + filename + ".tres")
	return affix


# --- DiceAffix ---

func _make_dice_affix(p_name: String, p_desc: String,
		p_trigger: int, p_effect_type: int, p_effect_value: float = 0.0,
		p_effect_data: Dictionary = {},
		p_condition: DiceAffixCondition = null,
		p_position: int = DiceAffix.PositionRequirement.ANY,
		p_target: int = DiceAffix.NeighborTarget.SELF,
		p_value_source: int = DiceAffix.ValueSource.STATIC) -> DiceAffix:
	var da := DiceAffix.new()
	da.affix_name = p_name
	da.description = p_desc
	da.trigger = p_trigger
	da.effect_type = p_effect_type
	da.effect_value = p_effect_value
	da.effect_data = p_effect_data
	da.condition = p_condition
	da.position_requirement = p_position
	da.neighbor_target = p_target
	da.value_source = p_value_source
	da.show_in_summary = true
	da.use_global_element_visuals = true
	da.global_element_type = ActionEffect.DamageType.FIRE
	_created_dice_affixes += 1
	return da


# --- DiceAffixCondition ---

func _make_condition(p_type: int, p_threshold: float = 0.0,
		p_invert: bool = false, p_element: String = "",
		p_status_id: String = "") -> DiceAffixCondition:
	var c := DiceAffixCondition.new()
	c.type = p_type
	c.threshold = p_threshold
	c.invert = p_invert
	c.condition_element = p_element
	c.condition_status_id = p_status_id
	_created_conditions += 1
	return c


# --- MANA_DIE_AFFIX wrapper (Affix that carries a DiceAffix in effect_data) ---

func _make_mana_die_affix_wrapper(p_name: String, p_desc: String,
		p_tags: Array, p_dice_affix: DiceAffix) -> Affix:
	"""Create an Affix with category MANA_DIE_AFFIX that wraps a DiceAffix.
	When the mana pool creates a die, it applies all MANA_DIE_AFFIX affixes' dice_affixes."""
	var a := _make_affix(p_name, p_desc, Affix.Category.MANA_DIE_AFFIX, p_tags)
	a.effect_data = {"dice_affix": p_dice_affix}
	return a


# --- Action + ActionEffect ---

func _make_action_effect(p_name: String, p_target: int, p_type: int,
		p_damage_type: int = ActionEffect.DamageType.FIRE,
		p_base_damage: int = 0, p_damage_mult: float = 1.0,
		p_dice_count: int = 1, p_base_heal: int = 0,
		p_heal_mult: float = 1.0, p_heal_uses_dice: bool = false,
		p_status: StatusAffix = null, p_stack_count: int = 1,
		p_cleanse_tags: Array[String] = []) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.target = p_target
	e.effect_type = p_type
	e.damage_type = p_damage_type
	e.base_damage = p_base_damage
	e.damage_multiplier = p_damage_mult
	e.dice_count = p_dice_count
	e.base_heal = p_base_heal
	e.heal_multiplier = p_heal_mult
	e.heal_uses_dice = p_heal_uses_dice
	if p_status:
		e.status_affix = p_status
	e.stack_count = p_stack_count
	e.cleanse_tags = p_cleanse_tags
	_created_effects += 1
	return e

func _make_action(p_id: String, p_name: String, p_desc: String,
		p_die_slots: int, p_effects: Array[ActionEffect],
		p_charge_type: int = Action.ChargeType.UNLIMITED,
		p_max_charges: int = 1) -> Action:
	var act := Action.new()
	act.action_id = p_id
	act.action_name = p_name
	act.action_description = p_desc
	act.die_slots = p_die_slots
	act.min_dice_required = p_die_slots
	act.effects.assign(p_effects)
	act.charge_type = p_charge_type
	act.max_charges = p_max_charges
	_created_actions += 1
	return act

func _save_action(action: Action, filename: String) -> Action:
	_save(action, ACTION_DIR + filename + ".tres")
	return action




# --- SkillResource ---

func _make_skill(p_id: String, p_name: String, p_desc: String,
		p_tier: int, p_col: int, p_tree_pts: int,
		p_rank_affixes: Dictionary = {},
		p_cost: int = 1) -> SkillResource:
	"""Create a SkillResource.
	p_rank_affixes: {1: [Affix, ...], 2: [...], ...}
	"""
	var s := SkillResource.new()
	s.skill_id = p_id
	s.skill_name = p_name
	s.description = p_desc
	s.tier = p_tier
	s.column = p_col
	s.tree_points_required = p_tree_pts
	s.skill_point_cost = p_cost

	if p_rank_affixes.has(1):
		s.rank_1_affixes.assign(p_rank_affixes[1])
	if p_rank_affixes.has(2):
		s.rank_2_affixes.assign(p_rank_affixes[2])
	if p_rank_affixes.has(3):
		s.rank_3_affixes.assign(p_rank_affixes[3])
	if p_rank_affixes.has(4):
		s.rank_4_affixes.assign(p_rank_affixes[4])
	if p_rank_affixes.has(5):
		s.rank_5_affixes.assign(p_rank_affixes[5])

	_created_skills += 1
	_skill_lookup[p_id] = s
	return s

func _save_skill(skill: SkillResource, filename: String) -> SkillResource:
	_save(skill, BASE_SKILL_DIR + filename + ".tres")
	return skill


# --- Tier point requirements (from design doc) ---

func _tier_pts(tier: int) -> int:
	match tier:
		1: return 0
		2: return 1
		3: return 3
		4: return 5
		5: return 8
		6: return 11
		7: return 15
		8: return 20
		9: return 25
		10: return 28
		_: return 999


# ============================================================================
# SHARED DICE AFFIXES & CONDITIONS
# ============================================================================

# These are reused across multiple skills and stored as standalone .tres files
# so multiple Affix wrappers can reference the same DiceAffix.

var _cond_max_roll: DiceAffixCondition
var _cond_neighbor_fire: DiceAffixCondition
var _cond_neighbor_fire_inverted: DiceAffixCondition
var _cond_target_burn: DiceAffixCondition
var _cond_value_below_3: DiceAffixCondition

var _da_kindling_adj_bonus: DiceAffix
var _da_max_roll_burn: DiceAffix

func _create_shared_dice_affixes():
	print("\n📎 Creating shared DiceAffixes & Conditions...")

	# --- Conditions ---
	_cond_max_roll = _make_condition(
		DiceAffixCondition.Type.SELF_VALUE_IS_MAX)
	_save(_cond_max_roll, CONDITION_DIR + "cond_max_roll.tres")

	_cond_neighbor_fire = _make_condition(
		DiceAffixCondition.Type.NEIGHBOR_HAS_ELEMENT, 0.0, false, "FIRE")
	_save(_cond_neighbor_fire, CONDITION_DIR + "cond_neighbor_fire.tres")

	_cond_neighbor_fire_inverted = _make_condition(
		DiceAffixCondition.Type.NEIGHBOR_HAS_ELEMENT, 0.0, true, "FIRE")
	_save(_cond_neighbor_fire_inverted, CONDITION_DIR + "cond_neighbor_not_fire.tres")

	_cond_target_burn = _make_condition(
		DiceAffixCondition.Type.TARGET_HAS_STATUS, 0.0, false, "", "burn")
	_save(_cond_target_burn, CONDITION_DIR + "cond_target_burn.tres")

	_cond_value_below_3 = _make_condition(
		DiceAffixCondition.Type.SELF_VALUE_BELOW, 3.0)
	_save(_cond_value_below_3, CONDITION_DIR + "cond_value_below_3.tres")

	# --- Shared DiceAffixes ---

	# Ember Dice: max roll → 1 Burn (reused by T2 Ember Dice skill)
	_da_max_roll_burn = _make_dice_affix(
		"Ember Dice: Max Roll Burn", "Max roll inflicts 1 Burn.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
		{"status_id": "burn", "stacks": 1},
		_cond_max_roll)
	_save(_da_max_roll_burn, DICE_AFFIX_DIR + "da_max_roll_burn.tres")

	# Kindling: adjacent fire dice both gain +1
	_da_kindling_adj_bonus = _make_dice_affix(
		"Kindling: Fire Neighbor Bonus", "Adjacent fire dice gain +1.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0, {},
		_cond_neighbor_fire,
		DiceAffix.PositionRequirement.ANY,
		DiceAffix.NeighborTarget.SELF)
	_save(_da_kindling_adj_bonus, DICE_AFFIX_DIR + "da_kindling_adj_bonus.tres")


# ============================================================================
# TIER 1 — Ignite (1 skill)
# ============================================================================

func _create_tier_1():
	print("\n🔥 Tier 1...")

	# Ignite: Fire element unlock. 1 rank.
	var ignite_affix := _make_affix(
		"Ignite: Fire Unlock",
		"Unlocks the Fire element for your mana die.",
		Affix.Category.MANA_ELEMENT_UNLOCK,
		["mage", "flame", "element_unlock"],
		0.0,
		{"element": "FIRE"})
		
	
	# --- DEBUG: Verify properties before save ---
	print("=== PRE-SAVE DIAGNOSTIC ===")
	print("  affix_name:    '%s'" % ignite_affix.affix_name)
	print("  description:   '%s'" % ignite_affix.description)
	print("  category:      %d (expected %d)" % [ignite_affix.category, Affix.Category.MANA_ELEMENT_UNLOCK])
	print("  effect_data:   %s" % str(ignite_affix.effect_data))
	print("  tags:          %s" % str(ignite_affix.tags))

	# Check what ResourceSaver actually sees
	print("  --- Property list (serializable) ---")
	for prop in ignite_affix.get_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE:
			var val = ignite_affix.get(prop.name)
			if val != null and str(val) != "" and str(val) != "0" and str(val) != "[]" and str(val) != "{}":
				print("    %s = %s" % [prop.name, str(val)])
	
	
	_save_affix(ignite_affix, "ignite", "ignite_r1_affix")

	var ignite := _make_skill(
		"flame_ignite", "Ignite",
		"Unlocks [color=orange]Fire[/color] element for your mana die.",
		1, 3, _tier_pts(1),
		{1: [ignite_affix]})
	_save_skill(ignite, "flame_ignite")


# ============================================================================
# TIER 2 — Ember Dice, Searing Force, Kindling (3 skills)
# ============================================================================

func _create_tier_2():
	print("\n🔥 Tier 2...")

	# --- Ember Dice (Col 1): D6 unlock + max roll → Burn. 1 rank. ---
	var ember_size_affix := _make_affix(
		"Ember Dice: D6 Unlock",
		"Unlocks D6 for your mana die.",
		Affix.Category.MANA_SIZE_UNLOCK,
		["mage", "flame", "size_unlock"],
		0.0,
		{"die_size": 6})
	_save_affix(ember_size_affix, "ember_dice", "ember_dice_r1_size_affix")

	var ember_burn_affix := _make_mana_die_affix_wrapper(
		"Ember Dice: Max Roll Burn",
		"Fire dice that roll max value inflict Burn.",
		["mage", "flame", "mana_die_affix"],
		_da_max_roll_burn)
	_save_affix(ember_burn_affix, "ember_dice", "ember_dice_r1_burn_affix")

	var ember_dice := _make_skill(
		"flame_ember_dice", "Ember Dice",
		"Unlocks [color=orange]D6[/color] mana die. Max roll inflicts [color=red]Burn[/color].",
		2, 1, _tier_pts(2),
		{1: [ember_size_affix, ember_burn_affix]})
	_save_skill(ember_dice, "flame_ember_dice")

	# --- Searing Force (Col 3): +3/+6/+9 fire damage. 3 ranks. ---
	var sf_r1 := _make_affix("Searing Force I", "+3 fire damage.",
		Affix.Category.FIRE_DAMAGE_BONUS, ["mage", "flame", "fire_damage"], 3.0)
	_save_affix(sf_r1, "searing_force", "searing_force_r1_affix")

	var sf_r2 := _make_affix("Searing Force II", "+6 fire damage.",
		Affix.Category.FIRE_DAMAGE_BONUS, ["mage", "flame", "fire_damage"], 3.0)
	_save_affix(sf_r2, "searing_force", "searing_force_r2_affix")

	var sf_r3 := _make_affix("Searing Force III", "+9 fire damage.",
		Affix.Category.FIRE_DAMAGE_BONUS, ["mage", "flame", "fire_damage"], 3.0)
	_save_affix(sf_r3, "searing_force", "searing_force_r3_affix")

	var searing_force := _make_skill(
		"flame_searing_force", "Searing Force",
		"+3/+6/+9 [color=orange]fire damage[/color].",
		2, 3, _tier_pts(2),
		{1: [sf_r1], 2: [sf_r2], 3: [sf_r3]})
	_save_skill(searing_force, "flame_searing_force")

	# --- Kindling (Col 5): Adjacent fire dice both gain +1. 1 rank. ---
	var kindling_affix := _make_mana_die_affix_wrapper(
		"Kindling: Fire Adjacency",
		"Fire dice adjacent to another fire die gain +1.",
		["mage", "flame", "mana_die_affix"],
		_da_kindling_adj_bonus)
	_save_affix(kindling_affix, "kindling", "kindling_r1_affix")

	var kindling := _make_skill(
		"flame_kindling", "Kindling",
		"Adjacent [color=orange]fire[/color] dice both gain +1.",
		2, 5, _tier_pts(2),
		{1: [kindling_affix]})
	_save_skill(kindling, "flame_kindling")


# ============================================================================
# TIER 3 — Fuel the Fire, Pyroclasm, Heat Shimmer, Flame Ward (4 skills)
# ============================================================================

func _create_tier_3():
	print("\n🔥 Tier 3...")

	# --- Fuel the Fire (Col 0): +2/+4/+6 to Burning targets. 3 ranks. ---
	# DiceAffix: EMIT_BONUS_DAMAGE with TARGET_HAS_STATUS("burn") condition
	var da_fuel := _make_dice_affix(
		"Fuel the Fire: Bonus vs Burn", "Bonus damage to burning targets.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 2.0,
		{"element": "FIRE"},
		_cond_target_burn)
	_save(da_fuel, DICE_AFFIX_DIR + "da_fuel_the_fire.tres")

	var ftf_r1 := _make_mana_die_affix_wrapper(
		"Fuel the Fire I", "+2 damage to burning targets.",
		["mage", "flame", "mana_die_affix", "vs_burn"], da_fuel)
	_save_affix(ftf_r1, "fuel_the_fire", "fuel_the_fire_r1_affix")

	# Rank 2 & 3 need separate DiceAffixes with increasing values
	var da_fuel_r2 := _make_dice_affix(
		"Fuel the Fire II: Bonus vs Burn", "+4 bonus damage to burning targets.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 2.0,
		{"element": "FIRE"},
		_cond_target_burn)
	_save(da_fuel_r2, DICE_AFFIX_DIR + "da_fuel_the_fire_r2.tres")

	var ftf_r2 := _make_mana_die_affix_wrapper(
		"Fuel the Fire II", "+4 damage to burning targets.",
		["mage", "flame", "mana_die_affix", "vs_burn"], da_fuel_r2)
	_save_affix(ftf_r2, "fuel_the_fire", "fuel_the_fire_r2_affix")

	var da_fuel_r3 := _make_dice_affix(
		"Fuel the Fire III: Bonus vs Burn", "+6 bonus damage to burning targets.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 2.0,
		{"element": "FIRE"},
		_cond_target_burn)
	_save(da_fuel_r3, DICE_AFFIX_DIR + "da_fuel_the_fire_r3.tres")

	var ftf_r3 := _make_mana_die_affix_wrapper(
		"Fuel the Fire III", "+6 damage to burning targets.",
		["mage", "flame", "mana_die_affix", "vs_burn"], da_fuel_r3)
	_save_affix(ftf_r3, "fuel_the_fire", "fuel_the_fire_r3_affix")

	var fuel_the_fire := _make_skill(
		"flame_fuel_the_fire", "Fuel the Fire",
		"+2/+4/+6 bonus damage to [color=red]Burning[/color] targets.",
		3, 0, _tier_pts(3),
		{1: [ftf_r1], 2: [ftf_r2], 3: [ftf_r3]})
	_save_skill(fuel_the_fire, "flame_fuel_the_fire")

	# --- Pyroclasm (Col 2): D8 unlock + 50% splash. 1 rank. ---
	var pyro_size := _make_affix(
		"Pyroclasm: D8 Unlock", "Unlocks D8 for your mana die.",
		Affix.Category.MANA_SIZE_UNLOCK,
		["mage", "flame", "size_unlock"],
		0.0, {"die_size": 8})
	_save_affix(pyro_size, "pyroclasm", "pyroclasm_r1_size_affix")

	var da_splash := _make_dice_affix(
		"Pyroclasm: Splash 50%", "Fire dice splash 50% damage to adjacent enemy.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_SPLASH_DAMAGE, 0.5,
		{"element": "FIRE", "percent": 0.5})
	_save(da_splash, DICE_AFFIX_DIR + "da_pyroclasm_splash.tres")

	var pyro_splash := _make_mana_die_affix_wrapper(
		"Pyroclasm: Splash", "Fire dice splash 50% damage.",
		["mage", "flame", "mana_die_affix", "splash"], da_splash)
	_save_affix(pyro_splash, "pyroclasm", "pyroclasm_r1_splash_affix")

	var pyroclasm := _make_skill(
		"flame_pyroclasm", "Pyroclasm",
		"Unlocks [color=orange]D8[/color]. Fire dice splash 50% damage.",
		3, 2, _tier_pts(3),
		{1: [pyro_size, pyro_splash]})
	_save_skill(pyroclasm, "flame_pyroclasm")

	# --- Heat Shimmer (Col 4): Auto-reroll below 1/2/3. 3 ranks. ---
	var da_reroll_r1 := _make_dice_affix(
		"Heat Shimmer I: Reroll", "Auto-reroll fire die below 2.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.AUTO_REROLL_LOW, 1.0,
		{"threshold": 1})
	_save(da_reroll_r1, DICE_AFFIX_DIR + "da_heat_shimmer_r1.tres")

	var hs_r1 := _make_mana_die_affix_wrapper(
		"Heat Shimmer I", "Auto-reroll fire dice that roll 1.",
		["mage", "flame", "mana_die_affix", "reroll"], da_reroll_r1)
	_save_affix(hs_r1, "heat_shimmer", "heat_shimmer_r1_affix")

	var da_reroll_r2 := _make_dice_affix(
		"Heat Shimmer II: Reroll", "Auto-reroll fire die below 3.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.AUTO_REROLL_LOW, 1.0,
		{"threshold": 2})
	_save(da_reroll_r2, DICE_AFFIX_DIR + "da_heat_shimmer_r2.tres")

	var hs_r2 := _make_mana_die_affix_wrapper(
		"Heat Shimmer II", "Auto-reroll fire dice that roll ≤2.",
		["mage", "flame", "mana_die_affix", "reroll"], da_reroll_r2)
	_save_affix(hs_r2, "heat_shimmer", "heat_shimmer_r2_affix")

	var da_reroll_r3 := _make_dice_affix(
		"Heat Shimmer III: Reroll", "Auto-reroll fire die below 4.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.AUTO_REROLL_LOW, 1.0,
		{"threshold": 3})
	_save(da_reroll_r3, DICE_AFFIX_DIR + "da_heat_shimmer_r3.tres")

	var hs_r3 := _make_mana_die_affix_wrapper(
		"Heat Shimmer III", "Auto-reroll fire dice that roll ≤3.",
		["mage", "flame", "mana_die_affix", "reroll"], da_reroll_r3)
	_save_affix(hs_r3, "heat_shimmer", "heat_shimmer_r3_affix")

	var heat_shimmer := _make_skill(
		"flame_heat_shimmer", "Heat Shimmer",
		"Auto-reroll fire dice below [color=yellow]2/3/4[/color].",
		3, 4, _tier_pts(3),
		{1: [hs_r1], 2: [hs_r2], 3: [hs_r3]})
	_save_skill(heat_shimmer, "flame_heat_shimmer")

	# --- Flame Ward (Col 6): +3/+6/+9 barrier per turn. 3 ranks. ---
	var fw_r1 := _make_affix("Flame Ward I", "+3 barrier at start of turn.",
		Affix.Category.PROC, ["mage", "flame", "barrier", "on_turn_start"], 3.0,
		{"proc_trigger": "ON_TURN_START", "proc_effect": "gain_barrier"})
	_save_affix(fw_r1, "flame_ward", "flame_ward_r1_affix")

	var fw_r2 := _make_affix("Flame Ward II", "+6 barrier at start of turn.",
		Affix.Category.PROC, ["mage", "flame", "barrier", "on_turn_start"], 3.0,
		{"proc_trigger": "ON_TURN_START", "proc_effect": "gain_barrier"})
	_save_affix(fw_r2, "flame_ward", "flame_ward_r2_affix")

	var fw_r3 := _make_affix("Flame Ward III", "+9 barrier at start of turn.",
		Affix.Category.PROC, ["mage", "flame", "barrier", "on_turn_start"], 3.0,
		{"proc_trigger": "ON_TURN_START", "proc_effect": "gain_barrier"})
	_save_affix(fw_r3, "flame_ward", "flame_ward_r3_affix")

	var flame_ward := _make_skill(
		"flame_flame_ward", "Flame Ward",
		"+3/+6/+9 [color=cyan]barrier[/color] at the start of each turn.",
		3, 6, _tier_pts(3),
		{1: [fw_r1], 2: [fw_r2], 3: [fw_r3]})
	_save_skill(flame_ward, "flame_flame_ward")


# ============================================================================
# TIER 4 — Accelerant, Immolate, Conflagrant Surge, Mana Flare, Hearthfire
# ============================================================================

func _create_tier_4():
	print("\n🔥 Tier 4...")

	# --- Accelerant (Col 0): Burn applications +1/+2 stacks. 2 ranks. ---
	var acc_r1 := _make_affix("Accelerant I", "Burn applications add +1 bonus stack.",
		Affix.Category.MISC, ["mage", "flame", "burn_stack_bonus"], 1.0)
	_save_affix(acc_r1, "accelerant", "accelerant_r1_affix")

	var acc_r2 := _make_affix("Accelerant II", "Burn applications add +2 bonus stacks.",
		Affix.Category.MISC, ["mage", "flame", "burn_stack_bonus"], 1.0)
	_save_affix(acc_r2, "accelerant", "accelerant_r2_affix")

	var accelerant := _make_skill(
		"flame_accelerant", "Accelerant",
		"Burn applications add +1/+2 bonus stacks.",
		4, 0, _tier_pts(4),
		{1: [acc_r1], 2: [acc_r2]})
	_save_skill(accelerant, "flame_accelerant")

	# --- Immolate (Col 1): 15%/30%/45% to apply 1 Burn on fire damage. 3 ranks. ---
	var imm_r1 := _make_affix("Immolate I", "15% chance to inflict Burn on fire damage.",
		Affix.Category.PROC, ["mage", "flame", "immolate", "on_deal_damage"], 0.15,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_effect": "apply_status",
		 "status_id": "burn", "stacks": 1, "element_filter": "fire"})
	_save_affix(imm_r1, "immolate", "immolate_r1_affix")

	var imm_r2 := _make_affix("Immolate II", "30% chance to inflict Burn on fire damage.",
		Affix.Category.PROC, ["mage", "flame", "immolate", "on_deal_damage"], 0.15,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_effect": "apply_status",
		 "status_id": "burn", "stacks": 1, "element_filter": "fire"})
	_save_affix(imm_r2, "immolate", "immolate_r2_affix")

	var imm_r3 := _make_affix("Immolate III", "45% chance to inflict Burn on fire damage.",
		Affix.Category.PROC, ["mage", "flame", "immolate", "on_deal_damage"], 0.15,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_effect": "apply_status",
		 "status_id": "burn", "stacks": 1, "element_filter": "fire"})
	_save_affix(imm_r3, "immolate", "immolate_r3_affix")

	var immolate := _make_skill(
		"flame_immolate", "Immolate",
		"15%/30%/45% chance to inflict [color=red]Burn[/color] on fire damage.",
		4, 1, _tier_pts(4),
		{1: [imm_r1], 2: [imm_r2], 3: [imm_r3]})
	_save_skill(immolate, "flame_immolate")

	# --- Conflagrant Surge (Col 3): Fire damage ×1.05/×1.10/×1.15. 3 ranks. ---
	var cs_r1 := _make_affix("Conflagrant Surge I", "Fire damage ×1.05.",
		Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
		["mage", "flame", "fire_mult"], 1.05,
		{"element": "FIRE"})
	_save_affix(cs_r1, "conflagrant_surge", "conflagrant_surge_r1_affix")

	var cs_r2 := _make_affix("Conflagrant Surge II", "Fire damage ×1.10.",
		Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
		["mage", "flame", "fire_mult"], 1.05,
		{"element": "FIRE"})
	_save_affix(cs_r2, "conflagrant_surge", "conflagrant_surge_r2_affix")

	var cs_r3 := _make_affix("Conflagrant Surge III", "Fire damage ×1.15.",
		Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
		["mage", "flame", "fire_mult"], 1.05,
		{"element": "FIRE"})
	_save_affix(cs_r3, "conflagrant_surge", "conflagrant_surge_r3_affix")

	var conflagrant_surge := _make_skill(
		"flame_conflagrant_surge", "Conflagrant Surge",
		"Fire damage ×1.05/×1.10/×1.15.",
		4, 3, _tier_pts(4),
		{1: [cs_r1], 2: [cs_r2], 3: [cs_r3]})
	_save_skill(conflagrant_surge, "flame_conflagrant_surge")

	# --- Mana Flare (Col 5): Refund 1 mana on roll ≤2. 1 rank. ---
	var da_mana_flare := _make_dice_affix(
		"Mana Flare: Low Roll Refund", "Refund 1 mana on roll ≤2.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MANA_GAIN, 1.0, {},
		_cond_value_below_3)  # SELF_VALUE_BELOW 3 → values 1 and 2
	_save(da_mana_flare, DICE_AFFIX_DIR + "da_mana_flare.tres")

	var mf_r1 := _make_mana_die_affix_wrapper(
		"Mana Flare", "Refund 1 mana when a fire die rolls ≤2.",
		["mage", "flame", "mana_die_affix", "mana_refund"], da_mana_flare)
	_save_affix(mf_r1, "mana_flare", "mana_flare_r1_affix")

	var mana_flare := _make_skill(
		"flame_mana_flare", "Mana Flare",
		"Refund [color=cyan]1 mana[/color] when a fire die rolls ≤2.",
		4, 5, _tier_pts(4),
		{1: [mf_r1]})
	_save_skill(mana_flare, "flame_mana_flare")

	# --- Hearthfire (Col 6): Fire dice adjacent to non-fire gain +1/+2. 2 ranks. ---
	var da_hearth_r1 := _make_dice_affix(
		"Hearthfire I: Non-Fire Neighbor Bonus",
		"Fire die next to a non-fire die gains +1.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0, {},
		_cond_neighbor_fire_inverted)  # inverted: triggers when neighbor is NOT fire
	_save(da_hearth_r1, DICE_AFFIX_DIR + "da_hearthfire_r1.tres")

	var hf_r1 := _make_mana_die_affix_wrapper(
		"Hearthfire I", "+1 when adjacent to a non-fire die.",
		["mage", "flame", "mana_die_affix"], da_hearth_r1)
	_save_affix(hf_r1, "hearthfire", "hearthfire_r1_affix")

	var da_hearth_r2 := _make_dice_affix(
		"Hearthfire II: Non-Fire Neighbor Bonus",
		"Fire die next to a non-fire die gains +2.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0, {},
		_cond_neighbor_fire_inverted)
	_save(da_hearth_r2, DICE_AFFIX_DIR + "da_hearthfire_r2.tres")

	var hf_r2 := _make_mana_die_affix_wrapper(
		"Hearthfire II", "+2 when adjacent to a non-fire die.",
		["mage", "flame", "mana_die_affix"], da_hearth_r2)
	_save_affix(hf_r2, "hearthfire", "hearthfire_r2_affix")

	var hearthfire := _make_skill(
		"flame_hearthfire", "Hearthfire",
		"+1/+2 to fire dice adjacent to a non-fire die.",
		4, 6, _tier_pts(4),
		{1: [hf_r1], 2: [hf_r2]})
	_save_skill(hearthfire, "flame_hearthfire")

# ============================================================================
# CHUNK 3 — TIERS 5–10
# ============================================================================
#
# INSTRUCTIONS: In the generator file from Chunk 2, REPLACE the stub functions
# (the ones that just say "pass  # CHUNK 3") with the full implementations
# below. Copy each function body over its stub.
#
# Skills in this chunk:
#   T5:  Inferno, Eruption (Action), Tempered Steel                    = 3
#   T6:  Burning Vengeance (Action), ★Flashpoint, Firestorm,
#        ★Forge Bond, Cauterize (Action)                               = 5
#   T7:  Detonate (Action), Cinder Storm (Action),
#        Radiance (Action), Ember Link                                  = 4
#   T8:  ★Pyroclastic Flow, Volcanic Core (Action), ★Crucible's Gift  = 3
#   T9:  Eternal Flame (Action), Ironfire Stance (Action)              = 2
#   T10: Conflagration                                                  = 1
#                                                                Total = 18
# ============================================================================


# ============================================================================
# TIER 5 — Inferno, Eruption, Tempered Steel (3 skills)
# ============================================================================

func _create_tier_5():
	print("\n🔥 Tier 5...")

	# --- Inferno (Col 1): D10 unlock. Burn threshold 4→3→2. 3 ranks. ---
	var inf_size := _make_affix("Inferno: D10 Unlock", "Unlocks D10 for your mana die.",
		Affix.Category.MANA_SIZE_UNLOCK,
		["mage", "flame", "size_unlock"], 0.0, {"die_size": 10})
	_save_affix(inf_size, "inferno", "inferno_r1_size_affix")

	var inf_thresh_r1 := _make_affix("Inferno I: Threshold -1",
		"Burn explodes at 4 stacks instead of 5.",
		Affix.Category.MISC,
		["mage", "flame", "burn_threshold_reduction"], 1.0)
	_save_affix(inf_thresh_r1, "inferno", "inferno_r1_thresh_affix")

	var inf_thresh_r2 := _make_affix("Inferno II: Threshold -2",
		"Burn explodes at 3 stacks instead of 5.",
		Affix.Category.MISC,
		["mage", "flame", "burn_threshold_reduction"], 1.0)
	_save_affix(inf_thresh_r2, "inferno", "inferno_r2_thresh_affix")

	var inf_thresh_r3 := _make_affix("Inferno III: Threshold -3",
		"Burn explodes at 2 stacks instead of 5.",
		Affix.Category.MISC,
		["mage", "flame", "burn_threshold_reduction"], 1.0)
	_save_affix(inf_thresh_r3, "inferno", "inferno_r3_thresh_affix")

	var inferno := _make_skill(
		"flame_inferno", "Inferno",
		"Unlocks [color=orange]D10[/color]. Burn threshold reduced to [color=red]4/3/2[/color].",
		5, 1, _tier_pts(5),
		{1: [inf_size, inf_thresh_r1], 2: [inf_thresh_r2], 3: [inf_thresh_r3]})
	_save_skill(inferno, "flame_inferno")

	# --- Eruption (Col 3): ACTION — 2 dice, ALL_ENEMIES, fire ×0.6. 1 rank. ---
	var erupt_eff := _make_action_effect("Eruption Blast",
		ActionEffect.TargetType.ALL_ENEMIES,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 0.6, 2)
	

	var erupt_act := _make_action("flame_eruption", "Eruption",
		"Hurl fire at all enemies for 60% dice damage.",
		2, [erupt_eff])
	_save_action(erupt_act, "eruption_action")

	var erupt_grant := _make_affix("Eruption: Grant Action",
		"Grants the Eruption action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action"], 0.0,
		{"action_id": "flame_eruption"})
	erupt_grant.granted_action = erupt_act
	_save_affix(erupt_grant, "eruption", "eruption_r1_affix")

	var eruption := _make_skill(
		"flame_eruption", "Eruption",
		"[color=yellow]ACTION:[/color] 2 dice → [color=orange]fire[/color] damage to ALL enemies (×0.6).",
		5, 3, _tier_pts(5),
		{1: [erupt_grant]})
	_save_skill(eruption, "flame_eruption")

	# --- Tempered Steel (Col 5): +2/+4/+6 armor per fire die used. 3 ranks. ---
	var ts_r1 := _make_affix("Tempered Steel I", "+2 armor per fire die used.",
		Affix.Category.PROC,
		["mage", "flame", "armor", "on_die_used"], 2.0,
		{"proc_trigger": "ON_DIE_USED", "proc_effect": "gain_armor",
		 "element_filter": "fire"})
	_save_affix(ts_r1, "tempered_steel", "tempered_steel_r1_affix")

	var ts_r2 := _make_affix("Tempered Steel II", "+4 armor per fire die used.",
		Affix.Category.PROC,
		["mage", "flame", "armor", "on_die_used"], 2.0,
		{"proc_trigger": "ON_DIE_USED", "proc_effect": "gain_armor",
		 "element_filter": "fire"})
	_save_affix(ts_r2, "tempered_steel", "tempered_steel_r2_affix")

	var ts_r3 := _make_affix("Tempered Steel III", "+6 armor per fire die used.",
		Affix.Category.PROC,
		["mage", "flame", "armor", "on_die_used"], 2.0,
		{"proc_trigger": "ON_DIE_USED", "proc_effect": "gain_armor",
		 "element_filter": "fire"})
	_save_affix(ts_r3, "tempered_steel", "tempered_steel_r3_affix")

	var tempered_steel := _make_skill(
		"flame_tempered_steel", "Tempered Steel",
		"+2/+4/+6 [color=gray]armor[/color] per fire die used.",
		5, 5, _tier_pts(5),
		{1: [ts_r1], 2: [ts_r2], 3: [ts_r3]})
	_save_skill(tempered_steel, "flame_tempered_steel")


# ============================================================================
# TIER 6 — Burning Vengeance, ★Flashpoint, Firestorm, ★Forge Bond, Cauterize
# ============================================================================

func _create_tier_6():
	print("\n🔥 Tier 6...")

	# --- Burning Vengeance (Col 0): ACTION — 1 die, SINGLE_ENEMY, fire ×0.5
	#     + apply Burn stacks = die value. 1 rank. ---
	var bv_dmg_eff := _make_action_effect("Burning Vengeance: Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 0.5, 1)

	# Load burn status for the ADD_STATUS effect
	var burn_status: StatusAffix = load("res://resources/statuses/burn.tres")

	var bv_burn_eff := _make_action_effect("Burning Vengeance: Apply Burn",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		burn_status, 1)  # stack_count=1 as base; design says "stacks = die value"
	# NOTE: The stack_count here is a base of 1. The design intends stacks = die_total.
	# This requires the combat_manager to resolve value_source: DICE_TOTAL at runtime.
	# For now we set stack_count to a baseline; the exact dynamic resolution depends
	# on your ActionEffect execution pipeline supporting value_source on stack_count.
	
	var bv_act := _make_action("flame_burning_vengeance", "Burning Vengeance",
		"Strike an enemy for 50% fire damage and inflict Burn stacks equal to die value.",
		1, [bv_dmg_eff, bv_burn_eff],
		Action.ChargeType.LIMITED_PER_TURN, 2)
	_save_action(bv_act, "burning_vengeance_action")

	var bv_grant := _make_affix("Burning Vengeance: Grant Action",
		"Grants Burning Vengeance action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "pyre"], 0.0,
		{"action_id": "flame_burning_vengeance"})
	bv_grant.granted_action = bv_act
	_save_affix(bv_grant, "burning_vengeance", "burning_vengeance_r1_affix")

	var burning_vengeance := _make_skill(
		"flame_burning_vengeance", "Burning Vengeance",
		"[color=yellow]ACTION:[/color] 1 die → 50% [color=orange]fire[/color] + [color=red]Burn[/color] stacks = die value.",
		6, 0, _tier_pts(6),
		{1: [bv_grant]})
	_save_skill(burning_vengeance, "flame_burning_vengeance")

	# --- ★ Flashpoint (Col 2): Burn explosion → 50% splash to others. 1 rank. ---
	# Crossover: Requires Inferno r1 + Pyroclasm
	# Implementation: tag-based proc in combat_manager (Chunk 1 Patch 7)
	var flash_affix := _make_affix("Flashpoint",
		"When Burn explodes, splash 50% burst damage to other enemies.",
		Affix.Category.PROC,
		["mage", "flame", "flashpoint", "burn_explosion_splash"], 0.5)
	_save_affix(flash_affix, "flashpoint", "flashpoint_r1_affix")

	var flashpoint := _make_skill(
		"flame_flashpoint", "★ Flashpoint",
		"Burn explosions splash [color=yellow]50%[/color] burst damage to other enemies.",
		6, 2, _tier_pts(6),
		{1: [flash_affix]})
	_save_skill(flashpoint, "flame_flashpoint")

	# --- Firestorm (Col 3): Fire dice chain 20%/35% to 2 enemies. 2 ranks. ---
	var da_chain_r1 := _make_dice_affix(
		"Firestorm I: Chain", "Fire dice chain 20% to 2 enemies.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.2,
		{"element": "FIRE", "chains": 2, "decay": 1.0})
	_save(da_chain_r1, DICE_AFFIX_DIR + "da_firestorm_r1.tres")

	var fs_r1 := _make_mana_die_affix_wrapper(
		"Firestorm I", "Fire dice chain 20% damage to 2 enemies.",
		["mage", "flame", "mana_die_affix", "chain"], da_chain_r1)
	_save_affix(fs_r1, "firestorm", "firestorm_r1_affix")

	var da_chain_r2 := _make_dice_affix(
		"Firestorm II: Chain", "Fire dice chain 35% to 2 enemies.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.35,
		{"element": "FIRE", "chains": 2, "decay": 1.0})
	_save(da_chain_r2, DICE_AFFIX_DIR + "da_firestorm_r2.tres")

	var fs_r2 := _make_mana_die_affix_wrapper(
		"Firestorm II", "Fire dice chain 35% damage to 2 enemies.",
		["mage", "flame", "mana_die_affix", "chain"], da_chain_r2)
	_save_affix(fs_r2, "firestorm", "firestorm_r2_affix")

	var firestorm := _make_skill(
		"flame_firestorm", "Firestorm",
		"Fire dice chain [color=yellow]20%/35%[/color] damage to 2 enemies.",
		6, 3, _tier_pts(6),
		{1: [fs_r1], 2: [fs_r2]})
	_save_skill(firestorm, "flame_firestorm")

	# --- ★ Forge Bond (Col 4): Fire dice in FIRST/LAST +25% damage. 1 rank. ---
	# Crossover: Requires Conflagrant Surge r2 + Kindling
	var da_forge_bond := _make_dice_affix(
		"Forge Bond: Position Bonus",
		"Fire die in first or last position deals +25% damage.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 0.25,
		{"element": "FIRE", "percent": 0.25})
	# Position: FIRST or LAST — we use two sub-effects or a compound approach.
	# Simplest: create two DiceAffixes, one per position.
	da_forge_bond.position_requirement = DiceAffix.PositionRequirement.FIRST
	_save(da_forge_bond, DICE_AFFIX_DIR + "da_forge_bond_first.tres")

	var da_forge_bond_last := _make_dice_affix(
		"Forge Bond: Last Position Bonus",
		"Fire die in last position deals +25% damage.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 0.25,
		{"element": "FIRE", "percent": 0.25})
	da_forge_bond_last.position_requirement = DiceAffix.PositionRequirement.LAST
	_save(da_forge_bond_last, DICE_AFFIX_DIR + "da_forge_bond_last.tres")

	var fb_wrap_first := _make_mana_die_affix_wrapper(
		"Forge Bond: First", "+25% damage in first slot.",
		["mage", "flame", "mana_die_affix", "forge_bond"], da_forge_bond)
	_save_affix(fb_wrap_first, "forge_bond", "forge_bond_r1_first_affix")

	var fb_wrap_last := _make_mana_die_affix_wrapper(
		"Forge Bond: Last", "+25% damage in last slot.",
		["mage", "flame", "mana_die_affix", "forge_bond"], da_forge_bond_last)
	_save_affix(fb_wrap_last, "forge_bond", "forge_bond_r1_last_affix")

	var forge_bond := _make_skill(
		"flame_forge_bond", "★ Forge Bond",
		"Fire dice in [color=yellow]first/last[/color] position deal +25% damage.",
		6, 4, _tier_pts(6),
		{1: [fb_wrap_first, fb_wrap_last]})
	_save_skill(forge_bond, "flame_forge_bond")

	# --- Cauterize (Col 6): ACTION — 1 die, SELF, heal die×1.5 + barrier = die. ---
	var caut_heal_eff := _make_action_effect("Cauterize: Heal",
		ActionEffect.TargetType.SELF,
		ActionEffect.EffectType.HEAL,
		ActionEffect.DamageType.FIRE,
		0, 1.5, 1, 0, 1.5, true)
	
	# Barrier as a separate ADD_STATUS or MISC effect.
	# Using a simple barrier affix approach:
	var caut_barrier_affix := _make_affix("Cauterize: Barrier",
		"Grants barrier equal to die value.",
		Affix.Category.BARRIER_BONUS,
		["mage", "flame", "cauterize", "barrier"], 0.0,
		{"value_source": "DICE_TOTAL"})
	_save_affix(caut_barrier_affix, "cauterize", "cauterize_barrier_affix")

	var caut_act := _make_action("flame_cauterize", "Cauterize",
		"Heal for die×1.5 and gain barrier equal to die value.",
		1, [caut_heal_eff],
		Action.ChargeType.LIMITED_PER_TURN, 1)
	_save_action(caut_act, "cauterize_action")

	var caut_grant := _make_affix("Cauterize: Grant Action",
		"Grants Cauterize action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "forge"], 0.0,
		{"action_id": "flame_cauterize"})
	caut_grant.granted_action = caut_act
	_save_affix(caut_grant, "cauterize", "cauterize_r1_affix")

	var cauterize := _make_skill(
		"flame_cauterize", "Cauterize",
		"[color=yellow]ACTION:[/color] 1 die → [color=green]heal[/color] die×1.5 + [color=cyan]barrier[/color] = die.",
		6, 6, _tier_pts(6),
		{1: [caut_grant]})
	_save_skill(cauterize, "flame_cauterize")


# ============================================================================
# TIER 7 — Detonate, Cinder Storm, Radiance, Ember Link (4 skills)
# ============================================================================

func _create_tier_7():
	print("\n🔥 Tier 7...")

	# --- Detonate (Col 1): ACTION — 1 die, consume all Burn → damage = stacks×3 + die ---
	var det_dmg_eff := _make_action_effect("Detonate: Consume Burn Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1)
	# NOTE: The ×3 per stack multiplier on consumed burn stacks requires runtime
	# resolution via value_source on base_damage. Store intent in effect_data.
	det_dmg_eff.effect_data = {"value_source": "TARGET_STATUS_STACKS",
		"status_id": "burn", "per_stack_bonus": 3}
	
	var burn_status: StatusAffix = load("res://resources/statuses/burn.tres")

	var det_remove_eff := _make_action_effect("Detonate: Remove Burn",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.REMOVE_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		burn_status, 0)  # stack_count 0 = remove all
	
	var det_act := _make_action("flame_detonate", "Detonate",
		"Consume all Burn on target. Deal die + (stacks × 3) fire damage.",
		1, [det_dmg_eff, det_remove_eff],
		Action.ChargeType.LIMITED_PER_TURN, 2)
	_save_action(det_act, "detonate_action")

	var det_grant := _make_affix("Detonate: Grant Action",
		"Grants Detonate action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "pyre"], 0.0,
		{"action_id": "flame_detonate"})
	det_grant.granted_action = det_act
	_save_affix(det_grant, "detonate", "detonate_r1_affix")

	var detonate := _make_skill(
		"flame_detonate", "Detonate",
		"[color=yellow]ACTION:[/color] 1 die → consume [color=red]Burn[/color], damage = stacks×3 + die.",
		7, 1, _tier_pts(7),
		{1: [det_grant]})
	_save_skill(detonate, "flame_detonate")

	# --- Cinder Storm (Col 2): ACTION — 3 dice, ALL_ENEMIES, fire ×0.5 + 2 Burn ---
	var cs_dmg_eff := _make_action_effect("Cinder Storm: AoE Damage",
		ActionEffect.TargetType.ALL_ENEMIES,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 0.5, 3)
	
	var cs_burn_eff := _make_action_effect("Cinder Storm: Apply Burn",
		ActionEffect.TargetType.ALL_ENEMIES,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		burn_status, 2)

	var cs_act := _make_action("flame_cinder_storm", "Cinder Storm",
		"Barrage all enemies with fire for 50% damage and apply 2 Burn.",
		3, [cs_dmg_eff, cs_burn_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(cs_act, "cinder_storm_action")

	var cs_grant := _make_affix("Cinder Storm: Grant Action",
		"Grants Cinder Storm action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "crucible"], 0.0,
		{"action_id": "flame_cinder_storm"})
	cs_grant.granted_action = cs_act
	_save_affix(cs_grant, "cinder_storm", "cinder_storm_r1_affix")

	var cinder_storm := _make_skill(
		"flame_cinder_storm", "Cinder Storm",
		"[color=yellow]ACTION:[/color] 3 dice → [color=orange]fire[/color] ×0.5 to ALL + 2 [color=red]Burn[/color]. Per combat.",
		7, 2, _tier_pts(7),
		{1: [cs_grant]})
	_save_skill(cinder_storm, "flame_cinder_storm")

	# --- Radiance (Col 4): ACTION — 1 die, SELF, armor=die×2, barrier=die,
	#     +fire damage=die for 2 turns. ---
	# This is a complex self-buff. We model it as multiple effects.
	var rad_armor_eff := _make_action_effect("Radiance: Armor Buff",
		ActionEffect.TargetType.SELF,
		ActionEffect.EffectType.HEAL,  # Using HEAL with 0 heal to trigger barrier/armor via effect_data
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false)
	rad_armor_eff.effect_data = {"grant_armor_mult": 2.0, "grant_barrier_mult": 1.0,
		"grant_fire_damage_mult": 1.0, "duration_turns": 2,
		"value_source": "DICE_TOTAL"}
	
	var rad_act := _make_action("flame_radiance", "Radiance",
		"Self-buff: armor = die×2, barrier = die, +fire damage = die for 2 turns.",
		1, [rad_armor_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(rad_act, "radiance_action")

	var rad_grant := _make_affix("Radiance: Grant Action",
		"Grants Radiance action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "forge"], 0.0,
		{"action_id": "flame_radiance"})
	rad_grant.granted_action = rad_act
	_save_affix(rad_grant, "radiance", "radiance_r1_affix")

	var radiance := _make_skill(
		"flame_radiance", "Radiance",
		"[color=yellow]ACTION:[/color] 1 die → [color=gray]armor[/color] ×2, [color=cyan]barrier[/color], +[color=orange]fire dmg[/color] for 2 turns.",
		7, 4, _tier_pts(7),
		{1: [rad_grant]})
	_save_skill(radiance, "flame_radiance")

	# --- Ember Link (Col 5): Fire dice copy 15%/25% from neighbors. 2 ranks. ---
	var da_link_r1 := _make_dice_affix(
		"Ember Link I: Copy Neighbor", "Copy 15% of neighbor's value.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.COPY_NEIGHBOR_VALUE, 0.15,
		{"percent": 0.15},
		null,
		DiceAffix.PositionRequirement.ANY,
		DiceAffix.NeighborTarget.BOTH_NEIGHBORS)
	_save(da_link_r1, DICE_AFFIX_DIR + "da_ember_link_r1.tres")

	var el_r1 := _make_mana_die_affix_wrapper(
		"Ember Link I", "Fire dice copy 15% from neighbors.",
		["mage", "flame", "mana_die_affix", "copy_value"], da_link_r1)
	_save_affix(el_r1, "ember_link", "ember_link_r1_affix")

	var da_link_r2 := _make_dice_affix(
		"Ember Link II: Copy Neighbor", "Copy 25% of neighbor's value.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.COPY_NEIGHBOR_VALUE, 0.25,
		{"percent": 0.25},
		null,
		DiceAffix.PositionRequirement.ANY,
		DiceAffix.NeighborTarget.BOTH_NEIGHBORS)
	_save(da_link_r2, DICE_AFFIX_DIR + "da_ember_link_r2.tres")

	var el_r2 := _make_mana_die_affix_wrapper(
		"Ember Link II", "Fire dice copy 25% from neighbors.",
		["mage", "flame", "mana_die_affix", "copy_value"], da_link_r2)
	_save_affix(el_r2, "ember_link", "ember_link_r2_affix")

	var ember_link := _make_skill(
		"flame_ember_link", "Ember Link",
		"Fire dice copy [color=yellow]15%/25%[/color] of neighbors' values.",
		7, 5, _tier_pts(7),
		{1: [el_r1], 2: [el_r2]})
	_save_skill(ember_link, "flame_ember_link")


# ============================================================================
# TIER 8 — ★Pyroclastic Flow, Volcanic Core, ★Crucible's Gift (3 skills)
# ============================================================================

func _create_tier_8():
	print("\n🔥 Tier 8...")

	# --- ★ Pyroclastic Flow (Col 2): Burn explosion → 3 Burn to all others ---
	# Crossover: Requires Inferno r1 + Firestorm r1
	# Implementation: tag-based proc in combat_manager (Chunk 1 Patch 7)
	var pf_affix := _make_affix("Pyroclastic Flow",
		"When Burn explodes, apply 3 Burn stacks to all other enemies.",
		Affix.Category.PROC,
		["mage", "flame", "pyroclastic_flow", "burn_explosion_spread"], 3.0)
	_save_affix(pf_affix, "pyroclastic_flow", "pyroclastic_flow_r1_affix")

	var pyroclastic_flow := _make_skill(
		"flame_pyroclastic_flow", "★ Pyroclastic Flow",
		"Burn explosions apply [color=red]3 Burn[/color] to ALL other enemies.",
		8, 2, _tier_pts(8),
		{1: [pf_affix]})
	_save_skill(pyroclastic_flow, "flame_pyroclastic_flow")

	# --- Volcanic Core (Col 3): ACTION — 3 dice, SINGLE_ENEMY, fire ×1.0,
	#     EXECUTE (×2.0 if <30% HP). ---
	var vc_dmg_eff := _make_action_effect("Volcanic Core: Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 3)
	vc_dmg_eff.effect_data = {"execute_threshold": 0.3, "execute_multiplier": 2.0}
	
	var vc_act := _make_action("flame_volcanic_core", "Volcanic Core",
		"Massive fire strike. Deals double damage if target is below 30% HP.",
		3, [vc_dmg_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(vc_act, "volcanic_core_action")

	var vc_grant := _make_affix("Volcanic Core: Grant Action",
		"Grants Volcanic Core action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "crucible"], 0.0,
		{"action_id": "flame_volcanic_core"})
	vc_grant.granted_action = vc_act
	_save_affix(vc_grant, "volcanic_core", "volcanic_core_r1_affix")

	var volcanic_core := _make_skill(
		"flame_volcanic_core", "Volcanic Core",
		"[color=yellow]ACTION:[/color] 3 dice → [color=orange]fire[/color] ×1.0. [color=red]EXECUTE:[/color] ×2 if below 30% HP.",
		8, 3, _tier_pts(8),
		{1: [vc_grant]})
	_save_skill(volcanic_core, "flame_volcanic_core")

	# --- ★ Crucible's Gift (Col 4): After hitting 2+ enemies, next pull −2 mana ---
	# Crossover: Requires Eruption + Tempered Steel r1
	# Implementation: combat_manager multi-target tracking (Chunk 1 Patch 7d)
	var cg_affix := _make_affix("Crucible's Gift",
		"After hitting 2+ enemies, next mana pull costs 2 less.",
		Affix.Category.PROC,
		["mage", "flame", "crucibles_gift", "mana_discount"], 2.0,
		{"proc_trigger": "ON_MULTI_TARGET_HIT", "proc_effect": "reduce_next_pull_cost",
		 "min_targets": 2, "cost_reduction": 2})
	_save_affix(cg_affix, "crucibles_gift", "crucibles_gift_r1_affix")

	var crucibles_gift := _make_skill(
		"flame_crucibles_gift", "★ Crucible's Gift",
		"After hitting 2+ enemies, next mana pull costs [color=cyan]2 less[/color].",
		8, 4, _tier_pts(8),
		{1: [cg_affix]})
	_save_skill(crucibles_gift, "flame_crucibles_gift")


# ============================================================================
# TIER 9 — Eternal Flame, Ironfire Stance (2 skills)
# ============================================================================

func _create_tier_9():
	print("\n🔥 Tier 9...")

	# --- Eternal Flame (Col 1): ACTION — 2 dice, SINGLE_ENEMY, fire ×1.0
	#     + Burn = die total, Burn can't expire 3 turns. ---
	var burn_status: StatusAffix = load("res://resources/statuses/burn.tres")

	var ef_dmg_eff := _make_action_effect("Eternal Flame: Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 2)
	
	var ef_burn_eff := _make_action_effect("Eternal Flame: Apply Burn",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		burn_status, 1)
	# Design: stacks = dice total. Same pattern as Burning Vengeance.
	ef_burn_eff.effect_data = {"value_source": "DICE_TOTAL"}
	
	# Create the eternal_flame_mark StatusAffix
	var ef_mark := StatusAffix.new()
	ef_mark.status_id = "eternal_flame_mark"
	ef_mark.affix_name = "Eternal Flame"
	ef_mark.description = "Burn cannot expire while this mark is active."
	ef_mark.duration_type = StatusAffix.DurationType.TURN_BASED
	ef_mark.default_duration = 3
	ef_mark.tick_timing = StatusAffix.TickTiming.END_OF_TURN
	ef_mark.category = Affix.Category.MISC
	ef_mark.tags = ["mage", "flame", "eternal_flame", "mark"]
	ef_mark.show_in_summary = true
	ef_mark.cleanse_tags = ["buff", "fire"]
	_save(ef_mark, STATUS_DIR + "eternal_flame_mark.tres")
	_created_statuses += 1

	var ef_mark_eff := _make_action_effect("Eternal Flame: Apply Mark",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 1, 0, 1.0, false,
		ef_mark, 1)
	
	var ef_act := _make_action("flame_eternal_flame", "Eternal Flame",
		"Deal fire damage and inflict massive Burn that cannot expire for 3 turns.",
		2, [ef_dmg_eff, ef_burn_eff, ef_mark_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(ef_act, "eternal_flame_action")

	var ef_grant := _make_affix("Eternal Flame: Grant Action",
		"Grants Eternal Flame action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "pyre"], 0.0,
		{"action_id": "flame_eternal_flame"})
	ef_grant.granted_action = ef_act
	_save_affix(ef_grant, "eternal_flame", "eternal_flame_r1_affix")

	var eternal_flame := _make_skill(
		"flame_eternal_flame", "Eternal Flame",
		"[color=yellow]ACTION:[/color] 2 dice → [color=orange]fire[/color] ×1.0 + [color=red]Burn[/color] = dice total. Burn can't expire 3 turns.",
		9, 1, _tier_pts(9),
		{1: [ef_grant]})
	_save_skill(eternal_flame, "flame_eternal_flame")

	# --- Ironfire Stance (Col 5): ACTION — 2 dice, SELF, 25% damage reduction
	#     + 30% fire reflect + heal = die total, 2 turns. ---
	var ifs_eff := _make_action_effect("Ironfire Stance: Buff",
		ActionEffect.TargetType.SELF,
		ActionEffect.EffectType.HEAL,
		ActionEffect.DamageType.FIRE,
		0, 1.0, 2, 0, 1.0, true)
	ifs_eff.effect_data = {"damage_reduction_percent": 0.25,
		"fire_reflect_percent": 0.30,
		"duration_turns": 2,
		"value_source": "DICE_TOTAL"}
	
	var ifs_act := _make_action("flame_ironfire_stance", "Ironfire Stance",
		"25% damage reduction, 30% fire reflect, heal = dice total. Lasts 2 turns.",
		2, [ifs_eff],
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(ifs_act, "ironfire_stance_action")

	var ifs_grant := _make_affix("Ironfire Stance: Grant Action",
		"Grants Ironfire Stance action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "granted_action", "forge"], 0.0,
		{"action_id": "flame_ironfire_stance"})
	ifs_grant.granted_action = ifs_act
	_save_affix(ifs_grant, "ironfire_stance", "ironfire_stance_r1_affix")

	var ironfire_stance := _make_skill(
		"flame_ironfire_stance", "Ironfire Stance",
		"[color=yellow]ACTION:[/color] 2 dice → 25% [color=gray]damage reduction[/color], 30% [color=orange]fire reflect[/color], [color=green]heal[/color]. 2 turns.",
		9, 5, _tier_pts(9),
		{1: [ifs_grant]})
	_save_skill(ironfire_stance, "flame_ironfire_stance")


# ============================================================================
# TIER 10 — Conflagration (1 skill, capstone)
# ============================================================================

func _create_tier_10():
	print("\n🔥 Tier 10 — CAPSTONE...")

	# Conflagration: D12 unlock. Ignore fire resist. If Burning, double die value.
	# Compound DiceAffix: IGNORE_RESISTANCE + MODIFY_VALUE_PERCENT ×2.0 conditional

	var conf_size := _make_affix("Conflagration: D12 Unlock",
		"Unlocks D12 for your mana die.",
		Affix.Category.MANA_SIZE_UNLOCK,
		["mage", "flame", "size_unlock"], 0.0,
		{"die_size": 12})
	_save_affix(conf_size, "conflagration", "conflagration_r1_size_affix")

	# DiceAffix 1: Ignore fire resistance
	var da_ignore_resist := _make_dice_affix(
		"Conflagration: Ignore Resist",
		"Fire dice ignore enemy fire resistance.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.IGNORE_RESISTANCE, 1.0,
		{"element": "FIRE"})
	_save(da_ignore_resist, DICE_AFFIX_DIR + "da_conflagration_ignore_resist.tres")

	var conf_resist := _make_mana_die_affix_wrapper(
		"Conflagration: Ignore Resist",
		"Fire dice ignore fire resistance.",
		["mage", "flame", "mana_die_affix", "capstone"], da_ignore_resist)
	_save_affix(conf_resist, "conflagration", "conflagration_r1_resist_affix")

	# DiceAffix 2: Double value if target is Burning
	var da_double_burn := _make_dice_affix(
		"Conflagration: Double vs Burn",
		"Fire dice deal double damage to burning targets.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.MODIFY_VALUE_PERCENT, 2.0, {},
		_cond_target_burn)
	_save(da_double_burn, DICE_AFFIX_DIR + "da_conflagration_double_burn.tres")

	var conf_double := _make_mana_die_affix_wrapper(
		"Conflagration: Double vs Burn",
		"Double die value against burning targets.",
		["mage", "flame", "mana_die_affix", "capstone"], da_double_burn)
	_save_affix(conf_double, "conflagration", "conflagration_r1_double_affix")

	var conflagration := _make_skill(
		"flame_conflagration", "Conflagration",
		"Unlocks [color=orange]D12[/color]. Ignore fire resist. [color=red]Double[/color] die value vs burning targets.",
		10, 3, _tier_pts(10),
		{1: [conf_size, conf_resist, conf_double]})
	_save_skill(conflagration, "flame_conflagration")


# ============================================================================
# CHUNK 4 — PREREQUISITES + SKILL TREE ASSEMBLY
# ============================================================================
#
# INSTRUCTIONS: Replace the two remaining `pass` stubs in the generator:
#   func _wire_prerequisites():  pass  # CHUNK 3
#   func _build_skill_tree():    pass  # CHUNK 3
#
# with the full implementations below.
# ============================================================================


# ============================================================================
# PREREQUISITE WIRING
# ============================================================================
#
# Design doc prerequisite map:
#
# TIER 2 (all require Ignite):
#   Ember Dice       ← Ignite
#   Searing Force    ← Ignite
#   Kindling         ← Ignite
#
# TIER 3:
#   Fuel the Fire    ← Ember Dice
#   Pyroclasm        ← Searing Force
#   Heat Shimmer     ← Searing Force
#   Flame Ward       ← Kindling
#
# TIER 4:
#   Accelerant       ← Fuel the Fire
#   Immolate         ← Ember Dice
#   Conflagrant Surge← Pyroclasm
#   Mana Flare       ← Kindling
#   Hearthfire       ← Kindling
#
# TIER 5:
#   Inferno          ← Accelerant, Immolate
#   Eruption         ← Conflagrant Surge
#   Tempered Steel   ← Mana Flare
#
# TIER 6:
#   Burning Vengeance← Inferno r1
#   ★ Flashpoint     ← Inferno r1, Pyroclasm      (crossover)
#   Firestorm        ← Eruption
#   ★ Forge Bond     ← Conflagrant Surge r2, Kindling (crossover)
#   Cauterize        ← Tempered Steel
#
# TIER 7:
#   Detonate         ← Burning Vengeance
#   Cinder Storm     ← Flashpoint OR Firestorm     (either path)
#   Radiance         ← Forge Bond
#   Ember Link       ← Tempered Steel
#
# TIER 8:
#   ★ Pyroclastic Flow ← Inferno r1, Firestorm r1  (crossover)
#   Volcanic Core      ← Cinder Storm
#   ★ Crucible's Gift  ← Eruption, Tempered Steel r1 (crossover)
#
# TIER 9:
#   Eternal Flame    ← Detonate, Pyroclastic Flow
#   Ironfire Stance  ← Radiance, Crucible's Gift
#
# TIER 10:
#   Conflagration    ← Eternal Flame, Ironfire Stance  (both deep paths converge)
#
# ============================================================================

func _wire_prerequisites():
	print("\n🔗 Wiring prerequisites...")

	# Helper to add a prereq to a skill
	# required_rank defaults to 1; pass higher for "requires rank N" prereqs
	var _add_prereq = func(skill_id: String, prereq_id: String, req_rank: int = 1):
		var skill: SkillResource = _skill_lookup.get(skill_id)
		var prereq_skill: SkillResource = _skill_lookup.get(prereq_id)
		if not skill:
			push_error("Prereq wiring: skill '%s' not found" % skill_id)
			return
		if not prereq_skill:
			push_error("Prereq wiring: prereq '%s' not found for '%s'" % [prereq_id, skill_id])
			return

		var sp := SkillPrerequisite.new()
		sp.required_skill = prereq_skill
		sp.required_rank = req_rank
		skill.prerequisites.append(sp)
		print("  🔗 %s ← %s (r%d)" % [skill.skill_name, prereq_skill.skill_name, req_rank])

	# ── TIER 2 ──
	_add_prereq.call("flame_ember_dice", "flame_ignite")
	_add_prereq.call("flame_searing_force", "flame_ignite")
	_add_prereq.call("flame_kindling", "flame_ignite")

	# ── TIER 3 ──
	_add_prereq.call("flame_fuel_the_fire", "flame_ember_dice")
	_add_prereq.call("flame_pyroclasm", "flame_searing_force")
	_add_prereq.call("flame_heat_shimmer", "flame_searing_force")
	_add_prereq.call("flame_flame_ward", "flame_kindling")

	# ── TIER 4 ──
	_add_prereq.call("flame_accelerant", "flame_fuel_the_fire")
	_add_prereq.call("flame_immolate", "flame_ember_dice")
	_add_prereq.call("flame_conflagrant_surge", "flame_pyroclasm")
	_add_prereq.call("flame_mana_flare", "flame_kindling")
	_add_prereq.call("flame_hearthfire", "flame_kindling")

	# ── TIER 5 ──
	_add_prereq.call("flame_inferno", "flame_accelerant")
	_add_prereq.call("flame_inferno", "flame_immolate")
	_add_prereq.call("flame_eruption", "flame_conflagrant_surge")
	_add_prereq.call("flame_tempered_steel", "flame_mana_flare")

	# ── TIER 6 ──
	_add_prereq.call("flame_burning_vengeance", "flame_inferno")
	_add_prereq.call("flame_flashpoint", "flame_inferno")           # ★ crossover
	_add_prereq.call("flame_flashpoint", "flame_pyroclasm")         # ★ crossover
	_add_prereq.call("flame_firestorm", "flame_eruption")
	_add_prereq.call("flame_forge_bond", "flame_conflagrant_surge", 2)  # ★ crossover, r2
	_add_prereq.call("flame_forge_bond", "flame_kindling")              # ★ crossover
	_add_prereq.call("flame_cauterize", "flame_tempered_steel")

	# ── TIER 7 ──
	_add_prereq.call("flame_detonate", "flame_burning_vengeance")
	_add_prereq.call("flame_cinder_storm", "flame_firestorm")
	_add_prereq.call("flame_radiance", "flame_forge_bond")
	_add_prereq.call("flame_ember_link", "flame_tempered_steel")

	# ── TIER 8 ──
	_add_prereq.call("flame_pyroclastic_flow", "flame_inferno")        # ★ crossover
	_add_prereq.call("flame_pyroclastic_flow", "flame_firestorm")      # ★ crossover
	_add_prereq.call("flame_volcanic_core", "flame_cinder_storm")
	_add_prereq.call("flame_crucibles_gift", "flame_eruption")         # ★ crossover
	_add_prereq.call("flame_crucibles_gift", "flame_tempered_steel")   # ★ crossover

	# ── TIER 9 ──
	_add_prereq.call("flame_eternal_flame", "flame_detonate")
	_add_prereq.call("flame_eternal_flame", "flame_pyroclastic_flow")
	_add_prereq.call("flame_ironfire_stance", "flame_radiance")
	_add_prereq.call("flame_ironfire_stance", "flame_crucibles_gift")

	# ── TIER 10 ──
	_add_prereq.call("flame_conflagration", "flame_eternal_flame")
	_add_prereq.call("flame_conflagration", "flame_ironfire_stance")

	# Re-save all skills with their prerequisites now attached
	print("\n💾 Re-saving skills with prerequisites...")
	for skill_id in _skill_lookup:
		var skill: SkillResource = _skill_lookup[skill_id]
		var filename: String = skill_id
		_save(skill, BASE_SKILL_DIR + filename + ".tres")


# ============================================================================
# SKILL TREE ASSEMBLY
# ============================================================================

func _build_skill_tree():
	print("\n🌳 Building SkillTree resource...")

	var tree := SkillTree.new()
	tree.tree_id = "mage_flame"
	tree.tree_name = "Flame"
	tree.description = "Master fire magic. Three paths: Pyre (burn & detonate), Crucible (raw power & AoE), Forge (efficiency & resilience)."

	# Populate tier arrays
	tree.tier_1_skills = _get_tier_skills(1)
	tree.tier_2_skills = _get_tier_skills(2)
	tree.tier_3_skills = _get_tier_skills(3)
	tree.tier_4_skills = _get_tier_skills(4)
	tree.tier_5_skills = _get_tier_skills(5)
	tree.tier_6_skills = _get_tier_skills(6)
	tree.tier_7_skills = _get_tier_skills(7)
	tree.tier_8_skills = _get_tier_skills(8)
	tree.tier_9_skills = _get_tier_skills(9)
	tree.tier_10_skills = _get_tier_skills(10)

	# Set tier unlock point requirements (from design doc)
	tree.tier_2_points_required = 1
	tree.tier_3_points_required = 3
	tree.tier_4_points_required = 5
	tree.tier_5_points_required = 8
	tree.tier_6_points_required = 11
	tree.tier_7_points_required = 15
	tree.tier_8_points_required = 20
	tree.tier_9_points_required = 25
	tree.tier_10_points_required = 28

	_save(tree, TREE_DIR + "mage_flame.tres")
	print("  🌳 SkillTree saved: %s (%d skills)" % [tree.tree_name, tree.get_all_skills().size()])

	# Validation
	var warnings := tree.validate()
	if warnings.size() > 0:
		print("\n⚠️  Validation warnings:")
		for w in warnings:
			print("    %s" % w)
	else:
		print("  ✅ Validation passed — no warnings!")


func _get_tier_skills(tier: int) -> Array[SkillResource]:
	"""Gather all skills for a tier from the lookup, sorted by column."""
	var result: Array[SkillResource] = []
	for skill_id in _skill_lookup:
		var skill: SkillResource = _skill_lookup[skill_id]
		if skill.tier == tier:
			result.append(skill)
	# Sort by column for consistent ordering
	result.sort_custom(func(a, b): return a.column < b.column)
	return result
