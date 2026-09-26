# res://editor_scripts/generate_flame_tree.gd
# Run via: Editor -> Script -> Run (Ctrl+Shift+X) with this script open.
#
# WHAT THIS DOES:
#   Creates the complete 20-skill Mage Flame skill tree (8-tier system).
#   All cross-references use ExtResource (save-then-load pattern).
#
# SAFE TO RE-RUN: Overwrites existing files at the same paths.
#
# DESIGN:
#   Branch A (cols 0-1): Kindling — burn application, bonus vs burning, chain spread
#   Branch C (cols 2-4): Forge — positioning bonuses, rerolls, value copying, weave
#   Branch B (cols 5-6): Conflagration — explosion amplification, Detonate payoffs
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
var _created_skills: int = 0
var _created_affixes: int = 0
var _created_dice_affixes: int = 0
var _created_conditions: int = 0
var _created_actions: int = 0
var _created_effects: int = 0

# Skill lookup for prerequisite wiring (populated during creation)
var _skill_lookup: Dictionary = {}  # skill_id -> SkillResource

# Shared resources — loaded from disk
var _burn_status: StatusAffix

var _cond_target_has_burn: DiceAffixCondition
var _cond_neighbor_fire: DiceAffixCondition
var _cond_neighbor_not_fire: DiceAffixCondition
var _cond_self_value_below_2: DiceAffixCondition
var _cond_self_value_below_3: DiceAffixCondition
var _cond_self_value_below_4: DiceAffixCondition
var _cond_self_value_is_max: DiceAffixCondition
var _cond_self_value_below_half_max: DiceAffixCondition

# Saved action refs for cross-referencing (e.g., Detonate charge refund)
var _detonate_action: Action


# ============================================================================
# ENTRY POINT
# ============================================================================

func _run() -> void:
	print("\n" + "=".repeat(60))
	print("  GENERATING MAGE FLAME TREE (20 SKILLS) — 8-tier system")
	print("=".repeat(60))

	_ensure_all_dirs()

	# Phase 1: Shared resources (load statuses, create conditions)
	_create_shared_resources()

	# Phase 2: Tiers 1-8
	_create_tier_1()
	_create_tier_2()
	_create_tier_3()
	_create_tier_4()
	_create_tier_5()
	_create_tier_6()
	_create_tier_7()
	_create_tier_8()

	# Phase 3: Wire prerequisites (all 20 skills exist in _skill_lookup)
	_wire_prerequisites()

	# Phase 4: Build the SkillTree resource
	_build_skill_tree()

	# Summary
	print("\n" + "=".repeat(60))
	print("  FLAME TREE GENERATION COMPLETE")
	print("=".repeat(60))
	print("  Skills:         %d" % _created_skills)
	print("  Affixes:        %d" % _created_affixes)
	print("  DiceAffixes:    %d" % _created_dice_affixes)
	print("  Conditions:     %d" % _created_conditions)
	print("  Actions:        %d" % _created_actions)
	print("  ActionEffects:  %d" % _created_effects)
	print("=".repeat(60))


# ============================================================================
# DIRECTORY HELPERS
# ============================================================================

func _ensure_all_dirs():
	for dir in [BASE_AFFIX_DIR, BASE_SKILL_DIR, DICE_AFFIX_DIR, CONDITION_DIR,
				ACTION_DIR, EFFECT_DIR, TREE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)

func _ensure_sub_dir(base: String, sub: String) -> String:
	var path: String = base + sub + "/"
	DirAccess.make_dir_recursive_absolute(path)
	return path


# ============================================================================
# CORE SAVE-THEN-LOAD PATTERN
# ============================================================================

func _save_to_disk(resource: Resource, path: String) -> Resource:
	var err: int = ResourceSaver.save(resource, path)
	if err != OK:
		print("  [FAIL] save: %s (error %d)" % [path, err])
		return resource
	var loaded: Resource = load(path)
	if loaded == null:
		print("  [WARN] load() returned null after save: %s" % path)
		return resource
	print("  [OK] %s" % path)
	return loaded


# --- Typed save helpers (save + load + cast) ---

func _save_affix(affix: Affix, skill_folder: String, filename: String) -> Affix:
	var dir: String = _ensure_sub_dir(BASE_AFFIX_DIR, skill_folder)
	var path: String = dir + filename + ".tres"
	var loaded: Resource = _save_to_disk(affix, path)
	_created_affixes += 1
	return loaded as Affix

func _save_effect(effect: ActionEffect, filename: String) -> ActionEffect:
	var path: String = EFFECT_DIR + filename + ".tres"
	var loaded: Resource = _save_to_disk(effect, path)
	_created_effects += 1
	return loaded as ActionEffect

func _save_action(action: Action, filename: String) -> Action:
	var path: String = ACTION_DIR + filename + ".tres"
	var loaded: Resource = _save_to_disk(action, path)
	_created_actions += 1
	return loaded as Action

func _save_skill(skill: SkillResource, filename: String) -> SkillResource:
	var path: String = BASE_SKILL_DIR + filename + ".tres"
	var err: int = ResourceSaver.save(skill, path)
	if err != OK:
		print("  [FAIL] skill save: %s (error %d)" % [path, err])
	else:
		print("  [OK] %s" % path)
	_created_skills += 1
	if skill.skill_id != "":
		_skill_lookup[skill.skill_id] = skill
	return skill

func _save_dice_affix(da: DiceAffix, filename: String) -> DiceAffix:
	var path: String = DICE_AFFIX_DIR + filename + ".tres"
	var loaded: Resource = _save_to_disk(da, path)
	_created_dice_affixes += 1
	return loaded as DiceAffix

func _save_condition(cond: DiceAffixCondition, filename: String) -> DiceAffixCondition:
	var path: String = CONDITION_DIR + filename + ".tres"
	var loaded: Resource = _save_to_disk(cond, path)
	_created_conditions += 1
	return loaded as DiceAffixCondition


# ============================================================================
# RESOURCE CREATION HELPERS (in-memory only)
# ============================================================================

func _make_affix(p_name: String, p_desc: String, p_category: int,
		p_tags: Array, p_effect_num: float = 0.0,
		p_effect_data: Dictionary = {}) -> Affix:
	var a: Affix = Affix.new()
	a.affix_name = p_name
	a.description = p_desc
	a.category = p_category
	a.effect_number = p_effect_num
	if not p_effect_data.is_empty():
		a.effect_data = p_effect_data
	var typed_tags: Array[String] = []
	typed_tags.assign(p_tags)
	a.tags = typed_tags
	return a

func _make_dice_affix(p_name: String, p_desc: String,
		p_trigger: int, p_effect_type: int, p_effect_value: float = 0.0,
		p_effect_data: Dictionary = {},
		p_condition: DiceAffixCondition = null,
		p_position: int = DiceAffix.PositionRequirement.ANY,
		p_target: int = DiceAffix.NeighborTarget.SELF,
		p_value_source: int = DiceAffix.ValueSource.STATIC) -> DiceAffix:
	var da: DiceAffix = DiceAffix.new()
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
	return da

func _make_condition(p_type: int, p_threshold: float = 0.0,
		p_invert: bool = false, p_element: String = "",
		p_status_id: String = "") -> DiceAffixCondition:
	var c: DiceAffixCondition = DiceAffixCondition.new()
	c.type = p_type
	c.threshold = p_threshold
	c.invert = p_invert
	c.condition_element = p_element
	c.condition_status_id = p_status_id
	return c

func _make_mana_die_affix_wrapper(p_name: String, p_desc: String,
		p_tags: Array, p_dice_affix: DiceAffix) -> Affix:
	var a: Affix = _make_affix(p_name, p_desc, Affix.Category.MANA_DIE_AFFIX, p_tags)
	a.effect_data = {"dice_affix": p_dice_affix}
	return a

func _make_action_effect(p_name: String, p_target: int, p_type: int,
		p_damage_type: int = ActionEffect.DamageType.FIRE,
		p_base_damage: int = 0, p_damage_mult: float = 1.0,
		p_dice_count: int = 1, p_base_heal: int = 0,
		p_heal_mult: float = 1.0, p_heal_uses_dice: bool = false,
		p_status: StatusAffix = null, p_stack_count: int = 1,
		p_cleanse_tags: Array[String] = []) -> ActionEffect:
	var e: ActionEffect = ActionEffect.new()
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
	return e

func _make_action(p_id: String, p_name: String, p_desc: String,
		p_die_slots: int, p_effects: Array[ActionEffect],
		p_charge_type: int = Action.ChargeType.UNLIMITED,
		p_max_charges: int = 1) -> Action:
	var act: Action = Action.new()
	act.action_id = p_id
	act.action_name = p_name
	act.action_description = p_desc
	act.die_slots = p_die_slots
	act.min_dice_required = p_die_slots
	act.effects.assign(p_effects)
	act.charge_type = p_charge_type
	act.max_charges = p_max_charges
	return act

func _make_action_with_elements(p_id: String, p_name: String, p_desc: String,
		p_die_slots: int, p_effects: Array[ActionEffect],
		p_accepted_elements: Array[int],
		p_charge_type: int = Action.ChargeType.UNLIMITED,
		p_max_charges: int = 1) -> Action:
	var act: Action = _make_action(p_id, p_name, p_desc, p_die_slots,
		p_effects, p_charge_type, p_max_charges)
	act.accepted_elements.assign(p_accepted_elements)
	return act

func _make_skill(p_id: String, p_name: String, p_desc: String,
		p_tier: int, p_col: int, p_tree_pts: int,
		p_rank_affixes: Dictionary = {},
		p_cost: int = 1,
		p_category: SkillResource.SkillCategory = SkillResource.SkillCategory.PASSIVE) -> SkillResource:
	var s: SkillResource = SkillResource.new()
	s.skill_id = p_id
	s.skill_name = p_name
	s.description = p_desc
	s.tier = p_tier
	s.column = p_col
	s.tree_points_required = p_tree_pts
	s.skill_point_cost = p_cost
	s.skill_category = p_category
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
	return s

func _tier_pts(tier: int) -> int:
	match tier:
		1: return 0
		2: return 1
		3: return 3
		4: return 6
		5: return 9
		6: return 12
		7: return 16
		8: return 20
		_: return 999


# ============================================================================
# SHARED RESOURCES: Load statuses, create conditions
# ============================================================================

func _create_shared_resources():
	print("\n-- Loading shared resources...")

	# Load existing Burn status (do NOT recreate)
	_burn_status = load(STATUS_DIR + "burn.tres") as StatusAffix
	if _burn_status:
		print("  Burn StatusAffix loaded (path: %s)" % _burn_status.resource_path)
	else:
		push_error("Could not load burn.tres -- aborting")
		return

	# Shared DiceAffixConditions — save then reload into member vars
	_cond_target_has_burn = _save_condition(
		_make_condition(DiceAffixCondition.Type.TARGET_HAS_STATUS, 0.0, false, "", "burn"),
		"cond_target_has_burn")

	_cond_neighbor_fire = _save_condition(
		_make_condition(DiceAffixCondition.Type.NEIGHBOR_HAS_ELEMENT, 0.0, false, "FIRE"),
		"cond_neighbor_fire")

	_cond_neighbor_not_fire = _save_condition(
		_make_condition(DiceAffixCondition.Type.NEIGHBOR_ELEMENT_DIFFERS, 0.0, false, "FIRE"),
		"cond_neighbor_not_fire")

	_cond_self_value_below_2 = _save_condition(
		_make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW, 2.0),
		"cond_self_value_below_2")

	_cond_self_value_below_3 = _save_condition(
		_make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW, 3.0),
		"cond_self_value_below_3")

	_cond_self_value_below_4 = _save_condition(
		_make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW, 4.0),
		"cond_self_value_below_4")

	_cond_self_value_is_max = _save_condition(
		_make_condition(DiceAffixCondition.Type.SELF_VALUE_IS_MAX),
		"cond_self_value_is_max")

	_cond_self_value_below_half_max = _save_condition(
		_make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW_HALF_MAX),
		"cond_self_value_below_half_max")

	print("  Shared resources complete\n")


# ============================================================================
# TIER 1 — Ignite (Root)
# ============================================================================

func _create_tier_1():
	print("\n-- Tier 1 -- Ignite...")

	# Affix 1: Unlock FIRE element
	var ign_elem: Affix = _save_affix(
		_make_affix("Ignite: Fire Unlock", "Unlocks Fire mana element.",
			Affix.Category.MANA_ELEMENT_UNLOCK,
			["mage", "flame", "element_unlock"], 0.0, {"element": "FIRE"}),
		"ignite", "ignite_element_unlock")

	# Affix 2: Chromatic Bolt fire die applies 1 Burn
	var ign_burn_eff: ActionEffect = _save_effect(
		_make_action_effect("Ignite: Apply Burn",
			ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.FIRE,
			0, 1.0, 0, 0, 1.0, false,
			_burn_status, 1),
		"ignite_apply_burn")

	var ign_ca: Affix = _save_affix(
		_make_affix("Ignite: Chromatic Bolt Burn",
			"Chromatic Bolt applies 1 Burn on hit (requires fire die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "flame", "class_action_mod", "burn_apply"], 0.0,
			{"action_effect": ign_burn_eff, "fire_die_condition": true}),
		"ignite", "ignite_ca_affix")

	_save_skill(
		_make_skill("flame_ignite", "Ignite",
			"Unlock [color=orange]Fire[/color] mana. Chromatic Bolt applies [color=orange]1 Burn[/color] on hit (requires fire die).",
			1, 3, _tier_pts(1),
			{1: [ign_elem, ign_ca]}),
		"flame_ignite")


# ============================================================================
# TIER 2 — Immolate, Kindling, Accelerant
# ============================================================================

func _create_tier_2():
	print("\n-- Tier 2 -- 3 skills...")

	# ── Immolate (Col 1, Branch A) — proc: fire damage applies 1 Burn ──
	var imm_r1_mem: Affix = _make_affix("Immolate I",
		"15% chance: dealing fire damage applies 1 Burn.",
		Affix.Category.PROC, ["mage", "flame", "kindling", "burn_apply", "proc"], 0.15,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_condition_element": "FIRE",
		"proc_effect": "apply_status", "status_id": "burn", "stacks": 1,
		"proc_chance": 0.15})
	imm_r1_mem.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	var imm_r1: Affix = _save_affix(imm_r1_mem, "immolate", "immolate_r1_affix")

	var imm_r2_mem: Affix = _make_affix("Immolate II",
		"30% chance: dealing fire damage applies 1 Burn.",
		Affix.Category.PROC, ["mage", "flame", "kindling", "burn_apply", "proc"], 0.30,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_condition_element": "FIRE",
		"proc_effect": "apply_status", "status_id": "burn", "stacks": 1,
		"proc_chance": 0.30})
	imm_r2_mem.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	var imm_r2: Affix = _save_affix(imm_r2_mem, "immolate", "immolate_r2_affix")

	var imm_r3_mem: Affix = _make_affix("Immolate III",
		"45% chance: dealing fire damage applies 1 Burn.",
		Affix.Category.PROC, ["mage", "flame", "kindling", "burn_apply", "proc"], 0.45,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_condition_element": "FIRE",
		"proc_effect": "apply_status", "status_id": "burn", "stacks": 1,
		"proc_chance": 0.45})
	imm_r3_mem.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	var imm_r3: Affix = _save_affix(imm_r3_mem, "immolate", "immolate_r3_affix")

	_save_skill(
		_make_skill("flame_immolate", "Immolate",
			"[color=yellow]15/30/45%[/color] chance: dealing fire damage applies [color=orange]1 Burn[/color].",
			2, 1, _tier_pts(2), {1: [imm_r1], 2: [imm_r2], 3: [imm_r3]}, 1, SkillResource.SkillCategory.TRIGGER),
		"flame_immolate")

	# ── Kindling (Col 3, Center) — adjacent fire die +value ──
	var da_kin_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Kindling I: Adjacent Fire Bonus", "Fire die adjacent to fire: +1 value.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0,
			{}, _cond_neighbor_fire),
		"da_kindling_r1")
	var kin_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Kindling I", "Fire die adjacent to another fire die: +1 value.",
			["mage", "flame", "mana_die_affix", "positional", "forge"], da_kin_r1),
		"kindling", "kindling_r1_affix")

	var da_kin_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Kindling II: Adjacent Fire Bonus", "Fire die adjacent to fire: +2 value.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0,
			{}, _cond_neighbor_fire),
		"da_kindling_r2")
	var kin_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Kindling II", "Fire die adjacent to another fire die: +2 value.",
			["mage", "flame", "mana_die_affix", "positional", "forge"], da_kin_r2),
		"kindling", "kindling_r2_affix")

	_save_skill(
		_make_skill("flame_kindling", "Kindling",
			"Fire die adjacent to another fire die: +[color=yellow]1/2[/color] value.",
			2, 3, _tier_pts(2), {1: [kin_r1], 2: [kin_r2]}),
		"flame_kindling")

	# ── Accelerant (Col 5, Branch B) — all Burn application gains bonus stacks ──
	var acc_r1_mem: Affix = _make_affix("Accelerant I",
		"All Burn application gains +1 bonus stack.",
		Affix.Category.MISC, ["mage", "flame", "conflagration", "burn_amplify"], 1.0,
		{"modify_status_application": "burn", "bonus_stacks": 1})
	var acc_r1: Affix = _save_affix(acc_r1_mem, "accelerant", "accelerant_r1_affix")

	var acc_r2_mem: Affix = _make_affix("Accelerant II",
		"All Burn application gains +2 bonus stacks.",
		Affix.Category.MISC, ["mage", "flame", "conflagration", "burn_amplify"], 2.0,
		{"modify_status_application": "burn", "bonus_stacks": 2})
	var acc_r2: Affix = _save_affix(acc_r2_mem, "accelerant", "accelerant_r2_affix")

	_save_skill(
		_make_skill("flame_accelerant", "Accelerant",
			"All [color=orange]Burn[/color] application gains +[color=yellow]1/2[/color] bonus stacks.",
			2, 5, _tier_pts(2), {1: [acc_r1], 2: [acc_r2]}),
		"flame_accelerant")


# ============================================================================
# TIER 3 — Fuel the Fire, Sear (Action), Heat Shimmer, Flashpoint
# ============================================================================

func _create_tier_3():
	print("\n-- Tier 3 -- 4 skills...")

	# ── Fuel the Fire (Col 0, Branch A) — bonus damage vs burning targets ──
	var da_ftf_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Fuel the Fire I: Burn Bonus", "+2 damage vs burning target.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 2.0,
			{"element": "FIRE"}, _cond_target_has_burn),
		"da_fuel_the_fire_r1")
	var ftf_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Fuel the Fire I", "Fire die deals +2 bonus damage vs burning targets.",
			["mage", "flame", "mana_die_affix", "damage", "kindling", "conditional"], da_ftf_r1),
		"fuel_the_fire", "fuel_the_fire_r1_affix")

	var da_ftf_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Fuel the Fire II: Burn Bonus", "+4 damage vs burning target.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 4.0,
			{"element": "FIRE"}, _cond_target_has_burn),
		"da_fuel_the_fire_r2")
	var ftf_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Fuel the Fire II", "Fire die deals +4 bonus damage vs burning targets.",
			["mage", "flame", "mana_die_affix", "damage", "kindling", "conditional"], da_ftf_r2),
		"fuel_the_fire", "fuel_the_fire_r2_affix")

	var da_ftf_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Fuel the Fire III: Burn Bonus", "+6 damage vs burning target.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 6.0,
			{"element": "FIRE"}, _cond_target_has_burn),
		"da_fuel_the_fire_r3")
	var ftf_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Fuel the Fire III", "Fire die deals +6 bonus damage vs burning targets.",
			["mage", "flame", "mana_die_affix", "damage", "kindling", "conditional"], da_ftf_r3),
		"fuel_the_fire", "fuel_the_fire_r3_affix")

	_save_skill(
		_make_skill("flame_fuel_the_fire", "Fuel the Fire",
			"Fire die deals +[color=yellow]2/4/6[/color] bonus damage vs [color=orange]burning[/color] targets.",
			3, 0, _tier_pts(3), {1: [ftf_r1], 2: [ftf_r2], 3: [ftf_r3]}),
		"flame_fuel_the_fire")

	# ── Sear (Col 1, Branch A) — ACTION: 1 die, unlimited, apply Burn = value ──
	var sear_dmg: ActionEffect = _save_effect(
		_make_action_effect("Sear: Damage",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.FIRE, 0, 1.0, 1),
		"sear_damage")

	var sear_burn: ActionEffect = _save_effect(
		_make_action_effect("Sear: Apply Burn",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.FIRE, 0, 1.0, 0, 0, 1.0, false,
			_burn_status, 1),
		"sear_burn")
	# Stack count driven by dice total via value_source
	sear_burn.stack_count = 0
	sear_burn.value_source = ActionEffect.ValueSource.DICE_TOTAL
	ResourceSaver.save(sear_burn, EFFECT_DIR + "sear_burn.tres")

	var sear_effs: Array[ActionEffect] = []
	sear_effs.assign([sear_dmg, sear_burn])
	var fire_only: Array[int] = [4]  # DieResource.Element.FIRE = 4
	var sear_act: Action = _save_action(
		_make_action_with_elements("flame_sear", "Sear",
			"Deal fire damage equal to die value. Apply Burn stacks equal to die value.",
			1, sear_effs, fire_only, Action.ChargeType.UNLIMITED, 99),
		"sear_action")

	var sear_grant_mem: Affix = _make_affix("Sear: Grant Action",
		"Grants Sear action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "kindling", "granted_action"], 0.0,
		{"action_id": "flame_sear"})
	sear_grant_mem.granted_action = sear_act
	var sear_grant: Affix = _save_affix(sear_grant_mem, "sear", "sear_r1_affix")

	_save_skill(
		_make_skill("flame_sear", "Sear",
			"[color=yellow]ACTION:[/color] 1 fire die -> fire damage + apply [color=orange]Burn[/color] = die value. Unlimited.",
			3, 1, _tier_pts(3), {1: [sear_grant]}, 1, SkillResource.SkillCategory.ACTION),
		"flame_sear")

	# ── Heat Shimmer (Col 3, Center) — auto-reroll low values ──
	var da_hs_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Heat Shimmer I: Reroll", "Auto-reroll fire die below 2.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.AUTO_REROLL_LOW, 1.0,
			{}, _cond_self_value_below_2),
		"da_heat_shimmer_r1")
	var hs_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Heat Shimmer I", "Fire dice auto-reroll below 2.",
			["mage", "flame", "mana_die_affix", "reroll", "forge"], da_hs_r1),
		"heat_shimmer", "heat_shimmer_r1_affix")

	var da_hs_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Heat Shimmer II: Reroll", "Auto-reroll fire die below 3.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.AUTO_REROLL_LOW, 1.0,
			{}, _cond_self_value_below_3),
		"da_heat_shimmer_r2")
	var hs_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Heat Shimmer II", "Fire dice auto-reroll below 3.",
			["mage", "flame", "mana_die_affix", "reroll", "forge"], da_hs_r2),
		"heat_shimmer", "heat_shimmer_r2_affix")

	var da_hs_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Heat Shimmer III: Reroll", "Auto-reroll fire die below 4.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.AUTO_REROLL_LOW, 1.0,
			{}, _cond_self_value_below_4),
		"da_heat_shimmer_r3")
	var hs_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Heat Shimmer III", "Fire dice auto-reroll below 4.",
			["mage", "flame", "mana_die_affix", "reroll", "forge"], da_hs_r3),
		"heat_shimmer", "heat_shimmer_r3_affix")

	_save_skill(
		_make_skill("flame_heat_shimmer", "Heat Shimmer",
			"Fire dice auto-reroll if value below [color=yellow]2/3/4[/color] (once per roll).",
			3, 3, _tier_pts(3), {1: [hs_r1], 2: [hs_r2], 3: [hs_r3]}),
		"flame_heat_shimmer")

	# ── Flashpoint (Col 6, Branch B) — Burn explosion splashes damage ──
	var fp_r1_mem: Affix = _make_affix("Flashpoint I",
		"Burn explosion splashes 40% of explosion damage to all others.",
		Affix.Category.PROC, ["mage", "flame", "conflagration", "explosion", "splash"], 0.40,
		{"proc_trigger": "ON_STATUS_THRESHOLD", "condition_status": "burn",
		"proc_effect": "splash_damage_to_all_others", "splash_percent": 0.40})
	fp_r1_mem.proc_trigger = Affix.ProcTrigger.ON_STATUS_APPLIED
	var fp_r1: Affix = _save_affix(fp_r1_mem, "flashpoint", "flashpoint_r1_affix")

	var fp_r2_mem: Affix = _make_affix("Flashpoint II",
		"Burn explosion splashes 60% of explosion damage to all others.",
		Affix.Category.PROC, ["mage", "flame", "conflagration", "explosion", "splash"], 0.60,
		{"proc_trigger": "ON_STATUS_THRESHOLD", "condition_status": "burn",
		"proc_effect": "splash_damage_to_all_others", "splash_percent": 0.60})
	fp_r2_mem.proc_trigger = Affix.ProcTrigger.ON_STATUS_APPLIED
	var fp_r2: Affix = _save_affix(fp_r2_mem, "flashpoint", "flashpoint_r2_affix")

	_save_skill(
		_make_skill("flame_flashpoint", "Flashpoint",
			"[color=orange]Burn[/color] explosion splashes [color=yellow]40/60%[/color] of explosion damage to all other enemies.",
			3, 6, _tier_pts(3), {1: [fp_r1], 2: [fp_r2]}, 1, SkillResource.SkillCategory.TRIGGER),
		"flame_flashpoint")


# ============================================================================
# TIER 4 — Flashfire, Hearthfire, Pyre
# ============================================================================

func _create_tier_4():
	print("\n-- Tier 4 -- 3 skills...")

	# ── Flashfire (Col 0, Branch A) — max roll spreads Burn to random enemy ──
	var da_ff_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Flashfire I: Max Roll Burn", "Max roll: apply 2 Burn to random enemy.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "burn", "stacks": 2, "target": "random_other_enemy"},
			_cond_self_value_is_max),
		"da_flashfire_r1")
	var ff_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Flashfire I", "Fire die on max roll: apply 2 Burn to random other enemy.",
			["mage", "flame", "mana_die_affix", "burn_apply", "kindling", "spread"], da_ff_r1),
		"flashfire", "flashfire_r1_affix")

	var da_ff_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Flashfire II: Max Roll Burn", "Max roll: apply 3 Burn to random enemy.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "burn", "stacks": 3, "target": "random_other_enemy"},
			_cond_self_value_is_max),
		"da_flashfire_r2")
	var ff_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Flashfire II", "Fire die on max roll: apply 3 Burn to random other enemy.",
			["mage", "flame", "mana_die_affix", "burn_apply", "kindling", "spread"], da_ff_r2),
		"flashfire", "flashfire_r2_affix")

	_save_skill(
		_make_skill("flame_flashfire", "Flashfire",
			"Fire die on max roll: apply [color=yellow]2/3[/color] [color=orange]Burn[/color] to a random other enemy.",
			4, 0, _tier_pts(4), {1: [ff_r1], 2: [ff_r2]}, 1, SkillResource.SkillCategory.TRIGGER),
		"flame_flashfire")

	# ── Hearthfire (Col 3, Center) — fire die next to non-fire gets +value ──
	var da_hf_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Hearthfire I: Mixed Bonus", "Fire die next to non-fire: +2 value.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0,
			{}, _cond_neighbor_not_fire),
		"da_hearthfire_r1")
	var hf_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Hearthfire I", "Fire die next to non-fire die: +2 value.",
			["mage", "flame", "mana_die_affix", "positional", "forge"], da_hf_r1),
		"hearthfire", "hearthfire_r1_affix")

	var da_hf_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Hearthfire II: Mixed Bonus", "Fire die next to non-fire: +3 value.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 3.0,
			{}, _cond_neighbor_not_fire),
		"da_hearthfire_r2")
	var hf_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Hearthfire II", "Fire die next to non-fire die: +3 value.",
			["mage", "flame", "mana_die_affix", "positional", "forge"], da_hf_r2),
		"hearthfire", "hearthfire_r2_affix")

	_save_skill(
		_make_skill("flame_hearthfire", "Hearthfire",
			"Fire die next to a non-fire die: +[color=yellow]2/3[/color] value.",
			4, 3, _tier_pts(4), {1: [hf_r1], 2: [hf_r2]}),
		"flame_hearthfire")

	# ── Pyre (Col 5, Branch B) — Burn tick damage bonus per stack ──
	var pyre_r1_mem: Affix = _make_affix("Pyre I",
		"Burn tick damage deals +1 bonus fire damage per stack.",
		Affix.Category.PROC, ["mage", "flame", "conflagration", "burn_amplify", "dot"], 1.0,
		{"proc_trigger": "ON_STATUS_TICK", "condition_status": "burn",
		"proc_effect": "bonus_tick_damage_per_stack", "bonus_per_stack": 1})
	pyre_r1_mem.proc_trigger = Affix.ProcTrigger.ON_TURN_END
	var pyre_r1: Affix = _save_affix(pyre_r1_mem, "pyre", "pyre_r1_affix")

	var pyre_r2_mem: Affix = _make_affix("Pyre II",
		"Burn tick damage deals +2 bonus fire damage per stack.",
		Affix.Category.PROC, ["mage", "flame", "conflagration", "burn_amplify", "dot"], 2.0,
		{"proc_trigger": "ON_STATUS_TICK", "condition_status": "burn",
		"proc_effect": "bonus_tick_damage_per_stack", "bonus_per_stack": 2})
	pyre_r2_mem.proc_trigger = Affix.ProcTrigger.ON_TURN_END
	var pyre_r2: Affix = _save_affix(pyre_r2_mem, "pyre", "pyre_r2_affix")

	_save_skill(
		_make_skill("flame_pyre", "Pyre",
			"[color=orange]Burn[/color] tick damage deals +[color=yellow]1/2[/color] bonus fire damage per stack.",
			4, 5, _tier_pts(4), {1: [pyre_r1], 2: [pyre_r2]}),
		"flame_pyre")


# ============================================================================
# TIER 5 — Firestorm, Forge Bond (Weave), Detonate (Action)
# ============================================================================

func _create_tier_5():
	print("\n-- Tier 5 -- 3 skills...")

	# ── Firestorm (Col 0, Branch A) — fire die chains to extra enemy + Burn ──
	# NOTE: Using correct processor keys "chains"/"decay" (not "chain_count"/"chain_damage_mult")
	# Using SELF_VALUE ValueSource so resolved_value = die total (not literal 0.25)
	var da_fs_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Firestorm I: Chain", "Chain to 1 enemy for 25% damage, applying 1 Burn.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 1.0,
			{"chains": 1, "decay": 0.25, "element": "FIRE",
			"chain_status": "burn", "chain_stacks": 1},
			null, DiceAffix.PositionRequirement.ANY, DiceAffix.NeighborTarget.SELF,
			DiceAffix.ValueSource.SELF_VALUE),
		"da_firestorm_r1")
	var fs_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Firestorm I", "Fire die chains to 1 enemy for 25% damage, applying 1 Burn.",
			["mage", "flame", "mana_die_affix", "chain", "kindling", "spread"], da_fs_r1),
		"firestorm", "firestorm_r1_affix")

	var da_fs_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Firestorm II: Chain", "Chain to 1 enemy for 40% damage, applying 1 Burn.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 1.0,
			{"chains": 1, "decay": 0.40, "element": "FIRE",
			"chain_status": "burn", "chain_stacks": 1},
			null, DiceAffix.PositionRequirement.ANY, DiceAffix.NeighborTarget.SELF,
			DiceAffix.ValueSource.SELF_VALUE),
		"da_firestorm_r2")
	var fs_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Firestorm II", "Fire die chains to 1 enemy for 40% damage, applying 1 Burn.",
			["mage", "flame", "mana_die_affix", "chain", "kindling", "spread"], da_fs_r2),
		"firestorm", "firestorm_r2_affix")

	_save_skill(
		_make_skill("flame_firestorm", "Firestorm",
			"Fire die chains to 1 enemy for [color=yellow]25/40%[/color] damage, applying [color=orange]1 Burn[/color].",
			5, 0, _tier_pts(5), {1: [fs_r1], 2: [fs_r2]}, 1, SkillResource.SkillCategory.TRIGGER),
		"flame_firestorm")

	# ── Forge Bond (Col 3, Weave) — FIRST or LAST position: +25% dmg + 1 Burn ──
	var da_fb_first: DiceAffix = _save_dice_affix(
		_make_dice_affix("Forge Bond: First Position", "FIRST fire die: +25% damage.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_PERCENT, 0.25,
			{}, null, DiceAffix.PositionRequirement.FIRST),
		"da_forge_bond_first")
	var fb_first: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Forge Bond: First Damage", "Fire die in FIRST position: +25% damage.",
			["mage", "flame", "mana_die_affix", "positional", "weave"], da_fb_first),
		"forge_bond", "forge_bond_first_affix")

	var da_fb_last: DiceAffix = _save_dice_affix(
		_make_dice_affix("Forge Bond: Last Position", "LAST fire die: +25% damage.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_PERCENT, 0.25,
			{}, null, DiceAffix.PositionRequirement.LAST),
		"da_forge_bond_last")
	var fb_last: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Forge Bond: Last Damage", "Fire die in LAST position: +25% damage.",
			["mage", "flame", "mana_die_affix", "positional", "weave"], da_fb_last),
		"forge_bond", "forge_bond_last_affix")

	var da_fb_burn_first: DiceAffix = _save_dice_affix(
		_make_dice_affix("Forge Bond: First Burn", "FIRST fire die: apply 1 Burn.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "burn", "stacks": 1},
			null, DiceAffix.PositionRequirement.FIRST),
		"da_forge_bond_burn_first")
	var fb_burn_first: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Forge Bond: First Burn", "Fire die in FIRST position: apply 1 Burn.",
			["mage", "flame", "mana_die_affix", "positional", "weave", "burn_apply"], da_fb_burn_first),
		"forge_bond", "forge_bond_burn_first_affix")

	var da_fb_burn_last: DiceAffix = _save_dice_affix(
		_make_dice_affix("Forge Bond: Last Burn", "LAST fire die: apply 1 Burn.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "burn", "stacks": 1},
			null, DiceAffix.PositionRequirement.LAST),
		"da_forge_bond_burn_last")
	var fb_burn_last: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Forge Bond: Last Burn", "Fire die in LAST position: apply 1 Burn.",
			["mage", "flame", "mana_die_affix", "positional", "weave", "burn_apply"], da_fb_burn_last),
		"forge_bond", "forge_bond_burn_last_affix")

	_save_skill(
		_make_skill("flame_forge_bond", "Forge Bond",
			"[color=yellow]WEAVE:[/color] Fire die in [color=yellow]FIRST[/color] or [color=yellow]LAST[/color] position: +25% damage AND apply [color=orange]1 Burn[/color].",
			5, 3, _tier_pts(5),
			{1: [fb_first, fb_last, fb_burn_first, fb_burn_last]}, 1, SkillResource.SkillCategory.WEAVE),
		"flame_forge_bond")

	# ── Detonate (Col 5, Branch B) — ACTION: 2 dice, consume Burn, burst ──
	var det_dmg: ActionEffect = _save_effect(
		_make_action_effect("Detonate: Base Damage",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.FIRE, 0, 1.2, 2),
		"detonate_damage")

	# Bonus damage = 3 per consumed Burn stack (value_source = TARGET_STATUS_STACKS)
	var det_bonus: ActionEffect = _save_effect(
		_make_action_effect("Detonate: Stack Bonus",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.FIRE, 0, 1.0, 0),
		"detonate_stack_bonus")
	det_bonus.base_damage = 3
	det_bonus.damage_multiplier = 1.0
	det_bonus.value_source = ActionEffect.ValueSource.TARGET_STATUS_STACKS
	det_bonus.effect_data = {"status_id": "burn", "multiplier": 3}
	ResourceSaver.save(det_bonus, EFFECT_DIR + "detonate_stack_bonus.tres")

	# Consume all Burn stacks
	var det_consume: ActionEffect = _save_effect(
		_make_action_effect("Detonate: Consume Burn",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.REMOVE_STATUS,
			ActionEffect.DamageType.FIRE, 0, 1.0, 0, 0, 1.0, false,
			_burn_status, 99),
		"detonate_consume")

	var det_effs: Array[ActionEffect] = []
	det_effs.assign([det_dmg, det_bonus, det_consume])
	var fire_only: Array[int] = [4]
	_detonate_action = _save_action(
		_make_action_with_elements("flame_detonate", "Detonate",
			"Consume all Burn on target. Deal fire x1.2 + 3 per consumed Burn stack.",
			2, det_effs, fire_only, Action.ChargeType.LIMITED_PER_TURN, 1),
		"detonate_action")

	var det_grant_mem: Affix = _make_affix("Detonate: Grant Action",
		"Grants Detonate action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "conflagration", "granted_action"], 0.0,
		{"action_id": "flame_detonate"})
	det_grant_mem.granted_action = _detonate_action
	var det_grant: Affix = _save_affix(det_grant_mem, "detonate", "detonate_r1_affix")

	_save_skill(
		_make_skill("flame_detonate", "Detonate",
			"[color=yellow]ACTION:[/color] 2 fire dice -> consume all [color=orange]Burn[/color], fire ×1.2 + 3 per consumed stack. Per turn.",
			5, 5, _tier_pts(5), {1: [det_grant]}, 1, SkillResource.SkillCategory.ACTION),
		"flame_detonate")


# ============================================================================
# TIER 6 — Mana Flare, Ember Link, Pyroclastic Flow
# ============================================================================

func _create_tier_6():
	print("\n-- Tier 6 -- 3 skills...")

	# ── Mana Flare (Col 1) — low roll refunds mana ──
	var da_mf_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Mana Flare I: Low Roll Refund", "Fire die at/below half max: refund 1 mana.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MANA_REFUND, 1.0,
			{"max_per_turn": 2}, _cond_self_value_below_half_max),
		"da_mana_flare_r1")
	var mf_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Mana Flare I", "Fire die at/below half max value: refund 1 mana. Max 2/turn.",
			["mage", "flame", "mana_die_affix", "mana_economy", "forge"], da_mf_r1),
		"mana_flare", "mana_flare_r1_affix")

	var da_mf_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Mana Flare II: Low Roll Refund", "Fire die at/below half max: refund 2 mana.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MANA_REFUND, 2.0,
			{"max_per_turn": 2}, _cond_self_value_below_half_max),
		"da_mana_flare_r2")
	var mf_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Mana Flare II", "Fire die at/below half max value: refund 2 mana. Max 2/turn.",
			["mage", "flame", "mana_die_affix", "mana_economy", "forge"], da_mf_r2),
		"mana_flare", "mana_flare_r2_affix")

	_save_skill(
		_make_skill("flame_mana_flare", "Mana Flare",
			"Fire die at or below half max value: refund [color=yellow]1/2[/color] mana. Max 2/turn.",
			6, 1, _tier_pts(6), {1: [mf_r1], 2: [mf_r2]}),
		"flame_mana_flare")

	# ── Ember Link (Col 4, Center) — copy neighbor value ──
	var da_el_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Ember Link I: Copy Neighbor", "Copy 15% of higher neighbor's value.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 0.15,
			{"copy_from": "higher_neighbor", "round_up": true},
			null, DiceAffix.PositionRequirement.ANY, DiceAffix.NeighborTarget.BOTH_NEIGHBORS,
			DiceAffix.ValueSource.NEIGHBOR_PERCENT),
		"da_ember_link_r1")
	var el_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Ember Link I", "Fire die copies 15% of higher neighbor's value (round up).",
			["mage", "flame", "mana_die_affix", "positional", "forge"], da_el_r1),
		"ember_link", "ember_link_r1_affix")

	var da_el_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Ember Link II: Copy Neighbor", "Copy 25% of higher neighbor's value.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 0.25,
			{"copy_from": "higher_neighbor", "round_up": true},
			null, DiceAffix.PositionRequirement.ANY, DiceAffix.NeighborTarget.BOTH_NEIGHBORS,
			DiceAffix.ValueSource.NEIGHBOR_PERCENT),
		"da_ember_link_r2")
	var el_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Ember Link II", "Fire die copies 25% of higher neighbor's value (round up).",
			["mage", "flame", "mana_die_affix", "positional", "forge"], da_el_r2),
		"ember_link", "ember_link_r2_affix")

	_save_skill(
		_make_skill("flame_ember_link", "Ember Link",
			"Fire die copies [color=yellow]15/25%[/color] of its higher neighbor's value (round up).",
			6, 4, _tier_pts(6), {1: [el_r1], 2: [el_r2]}),
		"flame_ember_link")

	# ── Pyroclastic Flow (Col 5, Branch B) — explosion spreads Burn ──
	var pf_mem: Affix = _make_affix("Pyroclastic Flow",
		"When Burn explosion triggers: apply 2 Burn to ALL other enemies.",
		Affix.Category.PROC, ["mage", "flame", "conflagration", "explosion", "spread"], 2.0,
		{"proc_trigger": "ON_STATUS_THRESHOLD", "condition_status": "burn",
		"proc_effect": "apply_status_to_all_others",
		"status_id": "burn", "stacks": 2})
	pf_mem.proc_trigger = Affix.ProcTrigger.ON_STATUS_APPLIED
	var pf: Affix = _save_affix(pf_mem, "pyroclastic_flow", "pyroclastic_flow_r1_affix")

	_save_skill(
		_make_skill("flame_pyroclastic_flow", "Pyroclastic Flow",
			"When [color=orange]Burn[/color] explosion triggers: apply [color=orange]2 Burn[/color] to ALL other enemies.",
			6, 5, _tier_pts(6), {1: [pf]}, 1, SkillResource.SkillCategory.TRIGGER),
		"flame_pyroclastic_flow")


# ============================================================================
# TIER 7 — Conflagration (Signature Action), Crucible's Gift
# ============================================================================

func _create_tier_7():
	print("\n-- Tier 7 -- 2 skills...")

	# ── Conflagration (Col 2, Signature) — 3 dice, AoE + Burn + 2x explosions ──
	var cfg_dmg: ActionEffect = _save_effect(
		_make_action_effect("Conflagration: AoE Damage",
			ActionEffect.TargetType.ALL_ENEMIES, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.FIRE, 0, 0.8, 3),
		"conflagration_damage")

	var cfg_burn: ActionEffect = _save_effect(
		_make_action_effect("Conflagration: Apply Burn",
			ActionEffect.TargetType.ALL_ENEMIES, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.FIRE, 0, 1.0, 0, 0, 1.0, false,
			_burn_status, 3),
		"conflagration_burn")

	var cfg_effs: Array[ActionEffect] = []
	cfg_effs.assign([cfg_dmg, cfg_burn])
	var fire_only: Array[int] = [4]
	var cfg_act: Action = _save_action(
		_make_action_with_elements("flame_conflagration", "Conflagration",
			"Fire x0.8 to ALL enemies. Apply 3 Burn to all. Burn explosions from this deal double damage.",
			3, cfg_effs, fire_only, Action.ChargeType.LIMITED_PER_COMBAT, 1),
		"conflagration_action")

	var cfg_grant_mem: Affix = _make_affix("Conflagration: Grant Action",
		"Grants Conflagration action.",
		Affix.Category.NEW_ACTION,
		["mage", "flame", "signature", "granted_action"], 0.0,
		{"action_id": "flame_conflagration"})
	cfg_grant_mem.granted_action = cfg_act
	var cfg_grant: Affix = _save_affix(cfg_grant_mem, "conflagration", "conflagration_r1_affix")

	# 2x explosion damage modifier (passive while action exists)
	var cfg_explode_mem: Affix = _make_affix("Conflagration: Double Explosions",
		"Burn explosions during Conflagration deal 2x damage.",
		Affix.Category.MISC, ["mage", "flame", "signature", "explosion_amplify"], 2.0,
		{"conflagration_explosion_multiplier": 2.0,
		"applies_during_action": "flame_conflagration"})
	var cfg_explode: Affix = _save_affix(cfg_explode_mem, "conflagration", "conflagration_explode_affix")

	_save_skill(
		_make_skill("flame_conflagration", "Conflagration",
			"[color=yellow]SIGNATURE:[/color] 3 fire dice -> fire ×0.8 to ALL + [color=orange]3 Burn[/color] to all. Explosions deal [color=yellow]2×[/color] damage. Per combat.",
			7, 2, _tier_pts(7), {1: [cfg_grant, cfg_explode]}, 1, SkillResource.SkillCategory.SIGNATURE),
		"flame_conflagration")

	# ── Crucible's Gift (Col 4, Branch B) — Detonate kill refunds + buffs dice ──
	var cg_mem: Affix = _make_affix("Crucible's Gift",
		"Detonate kill: refund Detonate charge + next 2 fire dice gain +3 value.",
		Affix.Category.PROC, ["mage", "flame", "conflagration", "kill_payoff", "charge_refund"], 3.0,
		{"proc_trigger": "ON_KILL", "proc_condition_action": "flame_detonate",
		"proc_effect": "refund_charge_and_buff_dice",
		"refund_action": "flame_detonate", "refund_charges": 1,
		"buff_next_fire_dice": 2, "buff_value": 3})
	cg_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var cg: Affix = _save_affix(cg_mem, "crucibles_gift", "crucibles_gift_r1_affix")

	_save_skill(
		_make_skill("flame_crucibles_gift", "Crucible's Gift",
			"[color=orange]Detonate[/color] kill: refund charge + next 2 fire dice gain [color=yellow]+3[/color] value.",
			7, 4, _tier_pts(7), {1: [cg]}, 1, SkillResource.SkillCategory.TRIGGER),
		"flame_crucibles_gift")


# ============================================================================
# TIER 8 — Inferno Cascade (Capstone)
# ============================================================================

func _create_tier_8():
	print("\n-- Tier 8 -- 1 skill (capstone)...")

	# Effect 1: Burn threshold reduced by 1 (explodes at 4 instead of 5)
	var ic_threshold: Affix = _save_affix(
		_make_affix("Inferno Cascade: Lower Threshold",
			"Burn explosion threshold reduced to 4.",
			Affix.Category.MISC,
			["mage", "flame", "capstone", "burn_amplify"], 0.0,
			{"modify_status_threshold": "burn", "threshold_reduction": 1}),
		"inferno_cascade", "inferno_cascade_threshold_affix")

	# Effect 2: Burn explosions deal 2x damage
	var ic_double: Affix = _save_affix(
		_make_affix("Inferno Cascade: Double Explosions",
			"Burn explosions deal 2x damage.",
			Affix.Category.MISC,
			["mage", "flame", "capstone", "explosion_amplify"], 2.0,
			{"explosion_damage_multiplier": "burn", "multiplier": 2.0}),
		"inferno_cascade", "inferno_cascade_double_affix")

	# Effect 3: FIRST fire die applies 1 Burn to all enemies
	var da_ic_first: DiceAffix = _save_dice_affix(
		_make_dice_affix("Inferno Cascade: First Strike",
			"FIRST fire die applies 1 Burn to all enemies.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "burn", "stacks": 1, "target": "all_enemies"},
			null, DiceAffix.PositionRequirement.FIRST),
		"da_inferno_cascade_first")
	var ic_first: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Inferno Cascade: First Burn",
			"FIRST fire die applies 1 Burn to all enemies.",
			["mage", "flame", "capstone", "burn_apply"], da_ic_first),
		"inferno_cascade", "inferno_cascade_first_affix")

	_save_skill(
		_make_skill("flame_inferno_cascade", "Inferno Cascade",
			"[color=yellow]CAPSTONE:[/color] Burn threshold reduced to [color=yellow]4[/color]. Explosions deal [color=yellow]2×[/color] damage. FIRST fire die applies [color=orange]1 Burn[/color] to all.",
			8, 3, _tier_pts(8),
			{1: [ic_threshold, ic_double, ic_first]}, 1, SkillResource.SkillCategory.CAPSTONE),
		"flame_inferno_cascade")


# ============================================================================
# PREREQUISITE WIRING
# ============================================================================

func _wire_prerequisites():
	print("\n-- Wiring prerequisites...")

	var _add_prereq = func(skill_id: String, prereq_id: String, req_rank: int = 1):
		var skill: SkillResource = _skill_lookup.get(skill_id)
		var prereq_skill: SkillResource = _skill_lookup.get(prereq_id)
		if not skill:
			push_error("Prereq wiring: skill '%s' not found" % skill_id)
			return
		if not prereq_skill:
			push_error("Prereq wiring: prereq '%s' not found for '%s'" % [prereq_id, skill_id])
			return
		var sp: SkillPrerequisite = SkillPrerequisite.new()
		sp.required_skill = prereq_skill
		sp.required_rank = req_rank
		skill.prerequisites.append(sp)
		print("  %s <- %s (r%d)" % [skill.skill_name, prereq_skill.skill_name, req_rank])

	# TIER 2: all require Ignite
	_add_prereq.call("flame_immolate", "flame_ignite")
	_add_prereq.call("flame_kindling", "flame_ignite")
	_add_prereq.call("flame_accelerant", "flame_ignite")

	# TIER 3
	_add_prereq.call("flame_fuel_the_fire", "flame_immolate")
	_add_prereq.call("flame_sear", "flame_immolate")
	_add_prereq.call("flame_heat_shimmer", "flame_kindling")
	_add_prereq.call("flame_flashpoint", "flame_accelerant")

	# TIER 4
	_add_prereq.call("flame_flashfire", "flame_fuel_the_fire")
	_add_prereq.call("flame_hearthfire", "flame_kindling")
	_add_prereq.call("flame_pyre", "flame_accelerant")

	# TIER 5
	_add_prereq.call("flame_firestorm", "flame_flashfire")
	# Forge Bond — WEAVE: requires BOTH branches (Sear from A + Flashpoint from B)
	_add_prereq.call("flame_forge_bond", "flame_sear")
	_add_prereq.call("flame_forge_bond", "flame_flashpoint")
	_add_prereq.call("flame_detonate", "flame_pyre")

	# TIER 6
	_add_prereq.call("flame_mana_flare", "flame_firestorm")
	_add_prereq.call("flame_ember_link", "flame_hearthfire")
	_add_prereq.call("flame_pyroclastic_flow", "flame_detonate")

	# TIER 7: both require Forge Bond (weave feeds apex)
	_add_prereq.call("flame_conflagration", "flame_mana_flare")
	_add_prereq.call("flame_conflagration", "flame_forge_bond")
	_add_prereq.call("flame_crucibles_gift", "flame_pyroclastic_flow")
	_add_prereq.call("flame_crucibles_gift", "flame_forge_bond")

	# TIER 8: Capstone requires BOTH T7 skills
	_add_prereq.call("flame_inferno_cascade", "flame_conflagration")
	_add_prereq.call("flame_inferno_cascade", "flame_crucibles_gift")

	# Re-save all skills with prerequisites now attached
	print("\n  Re-saving skills with prerequisites...")
	for skill_id: String in _skill_lookup:
		var skill: SkillResource = _skill_lookup[skill_id]
		var path: String = BASE_SKILL_DIR + skill_id + ".tres"
		var err: int = ResourceSaver.save(skill, path)
		if err != OK:
			print("  [FAIL] %s (error %d)" % [path, err])
	print("  All skills re-saved")


# ============================================================================
# SKILL TREE ASSEMBLY
# ============================================================================

func _build_skill_tree():
	print("\n-- Building SkillTree resource...")

	var tree: SkillTree = SkillTree.new()
	tree.tree_id = "mage_flame"
	tree.tree_name = "Flame"
	tree.description = "Master fire magic. Three paths: Kindling (burn application and chain spread), Conflagration (explosion amplification and Detonate payoffs), Forge (positioning bonuses and weave). Build relentless burn pressure that erupts."

	tree.tier_1_skills = _get_tier_skills(1)
	tree.tier_2_skills = _get_tier_skills(2)
	tree.tier_3_skills = _get_tier_skills(3)
	tree.tier_4_skills = _get_tier_skills(4)
	tree.tier_5_skills = _get_tier_skills(5)
	tree.tier_6_skills = _get_tier_skills(6)
	tree.tier_7_skills = _get_tier_skills(7)
	tree.tier_8_skills = _get_tier_skills(8)

	tree.tier_2_points_required = 1
	tree.tier_3_points_required = 3
	tree.tier_4_points_required = 6
	tree.tier_5_points_required = 9
	tree.tier_6_points_required = 12
	tree.tier_7_points_required = 16
	tree.tier_8_points_required = 20

	var tree_path: String = TREE_DIR + "mage_flame.tres"
	_save_to_disk(tree, tree_path)

	var total_skills: int = tree.get_all_skills().size()
	print("  SkillTree saved: %s (%d skills)" % [tree.tree_name, total_skills])

	for t in range(1, 9):
		var tier_skills: Array[SkillResource] = _get_tier_skills(t)
		print("    T%d: %d skills" % [t, tier_skills.size()])

	var warnings: Array[String] = tree.validate()
	if warnings.size() > 0:
		print("\n  Validation warnings:")
		for w: String in warnings:
			print("    %s" % w)
	else:
		print("  Validation passed -- no warnings!")


func _get_tier_skills(tier: int) -> Array[SkillResource]:
	var result: Array[SkillResource] = []
	for skill_id: String in _skill_lookup:
		var skill: SkillResource = _skill_lookup[skill_id]
		if skill.tier == tier:
			result.append(skill)
	result.sort_custom(func(a: SkillResource, b: SkillResource): return a.column < b.column)
	return result
