# res://editor_scripts/generate_frost_tree.gd
# Run via: Editor -> Script -> Run (Ctrl+Shift+X) with this script open.
#
# WHAT THIS DOES:
#   Creates the complete 20-skill Mage Frost skill tree (8-tier system).
#   All cross-references use ExtResource (save-then-load pattern).
#
# SAFE TO RE-RUN: Overwrites existing files at the same paths.
#
# DESIGN:
#   Branch A (cols 0-1): Chill Applier — creative Chill application
#   Branch C (cols 2-4): Center/Weave — feedback loops, utility
#   Branch B (cols 5-6): Freeze Exploiter — shatter, execute, burst
#
@tool
extends EditorScript

# ============================================================================
# DIRECTORY STRUCTURE
# ============================================================================

const BASE_AFFIX_DIR  := "res://resources/affixes/classes/mage/frost/"
const BASE_SKILL_DIR  := "res://resources/skills/classes/mage/frost/"
const DICE_AFFIX_DIR  := "res://resources/dice_affixes/mage/frost/"
const CONDITION_DIR   := "res://resources/dice_affixes/mage/frost/conditions/"
const ACTION_DIR      := "res://resources/actions/mage/frost/"
const EFFECT_DIR      := "res://resources/actions/mage/frost/effects/"
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
var _chill_status: StatusAffix
var _freeze_status: StatusAffix

var _cond_target_has_chill: DiceAffixCondition
var _cond_target_chill_8plus: DiceAffixCondition
var _cond_target_chill_10plus: DiceAffixCondition
var _cond_neighbor_ice: DiceAffixCondition
var _cond_self_value_below_2: DiceAffixCondition
var _cond_self_value_below_3: DiceAffixCondition
var _cond_self_value_below_4: DiceAffixCondition
var _cond_target_has_freeze: DiceAffixCondition

# Saved action refs for cross-referencing (e.g., Shatter charge reset)
var _shatter_action: Action


# ============================================================================
# ENTRY POINT
# ============================================================================

func _run() -> void:
	print("\n" + "=".repeat(60))
	print("  GENERATING MAGE FROST TREE (20 SKILLS) — 8-tier system")
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
	print("  FROST TREE GENERATION COMPLETE")
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
	da.global_element_type = ActionEffect.DamageType.ICE
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
		p_damage_type: int = ActionEffect.DamageType.ICE,
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
		p_cost: int = 1) -> SkillResource:
	var s: SkillResource = SkillResource.new()
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

	# Load existing Chill and Freeze statuses (do NOT recreate)
	_chill_status = load(STATUS_DIR + "chill.tres") as StatusAffix
	if _chill_status:
		print("  Chill StatusAffix loaded (path: %s)" % _chill_status.resource_path)
	else:
		push_error("Could not load chill.tres -- aborting")
		return

	_freeze_status = load(STATUS_DIR + "freeze.tres") as StatusAffix
	if _freeze_status:
		print("  Freeze StatusAffix loaded (path: %s)" % _freeze_status.resource_path)
	else:
		push_error("Could not load freeze.tres -- aborting")
		return

	# Shared DiceAffixConditions — save then reload into member vars
	_cond_target_has_chill = _save_condition(
		_make_condition(DiceAffixCondition.Type.TARGET_HAS_STATUS, 0.0, false, "", "chill"),
		"cond_target_has_chill")

	_cond_target_chill_8plus = _save_condition(
		_make_condition(DiceAffixCondition.Type.TARGET_STATUS_STACKS_ABOVE, 8.0, false, "", "chill"),
		"cond_target_chill_8plus")

	_cond_target_chill_10plus = _save_condition(
		_make_condition(DiceAffixCondition.Type.TARGET_STATUS_STACKS_ABOVE, 10.0, false, "", "chill"),
		"cond_target_chill_10plus")

	_cond_neighbor_ice = _save_condition(
		_make_condition(DiceAffixCondition.Type.NEIGHBOR_HAS_ELEMENT, 0.0, false, "ICE"),
		"cond_neighbor_ice")

	_cond_self_value_below_2 = _save_condition(
		_make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW, 2.0),
		"cond_self_value_below_2")

	_cond_self_value_below_3 = _save_condition(
		_make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW, 3.0),
		"cond_self_value_below_3")

	_cond_self_value_below_4 = _save_condition(
		_make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW, 4.0),
		"cond_self_value_below_4")

	_cond_target_has_freeze = _save_condition(
		_make_condition(DiceAffixCondition.Type.TARGET_HAS_STATUS, 0.0, false, "", "freeze"),
		"cond_target_has_freeze")

	print("  Shared resources complete\n")


# ============================================================================
# TIER 1 — Glaciate (Root)
# ============================================================================

func _create_tier_1():
	print("\n-- Tier 1 -- Glaciate...")

	# Affix 1: Unlock ICE element
	var glc_elem: Affix = _save_affix(
		_make_affix("Glaciate: Ice Unlock", "Unlocks Ice mana element.",
			Affix.Category.MANA_ELEMENT_UNLOCK,
			["mage", "frost", "element_unlock"], 0.0, {"element": "ICE"}),
		"glaciate", "glaciate_element_unlock")

	# Affix 2: Chromatic Bolt ice die applies 2 Chill
	var glc_chill_eff: ActionEffect = _save_effect(
		_make_action_effect("Glaciate: Apply Chill",
			ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.ICE,
			0, 1.0, 0, 0, 1.0, false,
			_chill_status, 2),
		"glaciate_apply_chill")

	var glc_ca: Affix = _save_affix(
		_make_affix("Glaciate: Chromatic Bolt Chill",
			"Chromatic Bolt applies 2 Chill on hit (requires ice die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "frost", "class_action_mod", "chill_apply"], 0.0,
			{"action_effect": glc_chill_eff, "ice_die_condition": true}),
		"glaciate", "glaciate_ca_affix")

	_save_skill(
		_make_skill("frost_glaciate", "Glaciate",
			"Unlock [color=cyan]Ice[/color] mana. Chromatic Bolt applies [color=cyan]2 Chill[/color] on hit (requires ice die).",
			1, 3, _tier_pts(1),
			{1: [glc_elem, glc_ca]}),
		"frost_glaciate")


# ============================================================================
# TIER 2 — Creeping Frost, Rime Dice, Brittle
# ============================================================================

func _create_tier_2():
	print("\n-- Tier 2 -- 3 skills...")

	# ── Creeping Frost (Col 1, Branch A) — ice die applies Chill on use ──
	var da_cf_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Creeping Frost I: Chill on Use", "Apply 1 Chill on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "chill", "stacks": 1}),
		"da_creeping_frost_r1")
	var cf_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Creeping Frost I", "Ice dice apply 1 Chill on use.",
			["mage", "frost", "mana_die_affix", "chill_apply", "applier"], da_cf_r1),
		"creeping_frost", "creeping_frost_r1_affix")

	var da_cf_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Creeping Frost II: Chill on Use", "Apply 2 Chill on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "chill", "stacks": 2}),
		"da_creeping_frost_r2")
	var cf_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Creeping Frost II", "Ice dice apply 2 Chill on use.",
			["mage", "frost", "mana_die_affix", "chill_apply", "applier"], da_cf_r2),
		"creeping_frost", "creeping_frost_r2_affix")

	var da_cf_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Creeping Frost III: Chill on Use", "Apply 3 Chill on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "chill", "stacks": 3}),
		"da_creeping_frost_r3")
	var cf_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Creeping Frost III", "Ice dice apply 3 Chill on use.",
			["mage", "frost", "mana_die_affix", "chill_apply", "applier"], da_cf_r3),
		"creeping_frost", "creeping_frost_r3_affix")

	_save_skill(
		_make_skill("frost_creeping_frost", "Creeping Frost",
			"Ice mana dice apply [color=yellow]1/2/3[/color] [color=cyan]Chill[/color] on use.",
			2, 1, _tier_pts(2), {1: [cf_r1], 2: [cf_r2], 3: [cf_r3]}),
		"frost_creeping_frost")

	# ── Rime Dice (Col 3, Center) — positional bonuses ──
	# Each rank has 2 dice affixes: FIRST position +value, LAST position +Chill
	var da_rime_first_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Rime Dice I: First Bonus", "First-position ice die +2 value.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0,
			{}, null, DiceAffix.PositionRequirement.FIRST),
		"da_rime_first_r1")
	var rime_first_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Rime Dice I: First", "Ice die in first position: +2 value.",
			["mage", "frost", "mana_die_affix", "positional"], da_rime_first_r1),
		"rime_dice", "rime_dice_first_r1_affix")

	var da_rime_last_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Rime Dice I: Last Chill", "Last-position ice die applies 2 Chill.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "chill", "stacks": 2}, null, DiceAffix.PositionRequirement.LAST),
		"da_rime_last_r1")
	var rime_last_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Rime Dice I: Last", "Ice die in last position: apply 2 Chill.",
			["mage", "frost", "mana_die_affix", "positional", "chill_apply"], da_rime_last_r1),
		"rime_dice", "rime_dice_last_r1_affix")

	var da_rime_first_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Rime Dice II: First Bonus", "First-position ice die +3 value.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 3.0,
			{}, null, DiceAffix.PositionRequirement.FIRST),
		"da_rime_first_r2")
	var rime_first_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Rime Dice II: First", "Ice die in first position: +3 value.",
			["mage", "frost", "mana_die_affix", "positional"], da_rime_first_r2),
		"rime_dice", "rime_dice_first_r2_affix")

	var da_rime_last_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Rime Dice II: Last Chill", "Last-position ice die applies 3 Chill.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "chill", "stacks": 3}, null, DiceAffix.PositionRequirement.LAST),
		"da_rime_last_r2")
	var rime_last_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Rime Dice II: Last", "Ice die in last position: apply 3 Chill.",
			["mage", "frost", "mana_die_affix", "positional", "chill_apply"], da_rime_last_r2),
		"rime_dice", "rime_dice_last_r2_affix")

	_save_skill(
		_make_skill("frost_rime_dice", "Rime Dice",
			"Ice die in [color=yellow]FIRST[/color] position: +[color=yellow]2/3[/color] value. In [color=yellow]LAST[/color]: apply [color=cyan]2/3 Chill[/color].",
			2, 3, _tier_pts(2),
			{1: [rime_first_r1, rime_last_r1],
			2: [rime_first_r2, rime_last_r2]}),
		"frost_rime_dice")

	# ── Brittle (Col 5, Branch B) — bonus damage per Chill stacks ──
	var da_brit_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Brittle I: Chill Damage", "+1 damage per 4 Chill on target.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 1.0,
			{"per_n_stacks": 4, "status_id": "chill"},
			_cond_target_has_chill),
		"da_brittle_r1")
	var brit_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Brittle I", "Ice die: +1 damage per 4 Chill stacks on target.",
			["mage", "frost", "mana_die_affix", "exploiter", "damage"], da_brit_r1),
		"brittle", "brittle_r1_affix")

	var da_brit_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Brittle II: Chill Damage", "+2 damage per 4 Chill on target.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 2.0,
			{"per_n_stacks": 4, "status_id": "chill"},
			_cond_target_has_chill),
		"da_brittle_r2")
	var brit_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Brittle II", "Ice die: +2 damage per 4 Chill stacks on target.",
			["mage", "frost", "mana_die_affix", "exploiter", "damage"], da_brit_r2),
		"brittle", "brittle_r2_affix")

	var da_brit_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Brittle III: Chill Damage", "+3 damage per 4 Chill on target.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 3.0,
			{"per_n_stacks": 4, "status_id": "chill"},
			_cond_target_has_chill),
		"da_brittle_r3")
	var brit_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Brittle III", "Ice die: +3 damage per 4 Chill stacks on target.",
			["mage", "frost", "mana_die_affix", "exploiter", "damage"], da_brit_r3),
		"brittle", "brittle_r3_affix")

	_save_skill(
		_make_skill("frost_brittle", "Brittle",
			"Ice die deals +[color=yellow]1/2/3[/color] bonus damage per 4 [color=cyan]Chill[/color] stacks on target.",
			2, 5, _tier_pts(2), {1: [brit_r1], 2: [brit_r2], 3: [brit_r3]}),
		"frost_brittle")


# ============================================================================
# TIER 3 — Hoarfrost, Permafrost Rune, Frostbite
# ============================================================================

func _create_tier_3():
	print("\n-- Tier 3 -- 3 skills...")

	# ── Hoarfrost (Col 0, Branch A) — end-of-turn Chill per unused die ──
	var hf_r1_mem: Affix = _make_affix("Hoarfrost I", "End of turn: 1 Chill per unused die.",
		Affix.Category.PROC, ["mage", "frost", "applier", "chill_apply", "end_turn"], 1.0,
		{"proc_trigger": "ON_TURN_END", "proc_effect": "apply_status_per_unused_die",
		"status_id": "chill", "stacks_per_unused_die": 1})
	hf_r1_mem.proc_trigger = Affix.ProcTrigger.ON_TURN_END
	var hf_r1: Affix = _save_affix(hf_r1_mem, "hoarfrost", "hoarfrost_r1_affix")

	var hf_r2_mem: Affix = _make_affix("Hoarfrost II", "End of turn: 2 Chill per unused die.",
		Affix.Category.PROC, ["mage", "frost", "applier", "chill_apply", "end_turn"], 2.0,
		{"proc_trigger": "ON_TURN_END", "proc_effect": "apply_status_per_unused_die",
		"status_id": "chill", "stacks_per_unused_die": 2})
	hf_r2_mem.proc_trigger = Affix.ProcTrigger.ON_TURN_END
	var hf_r2: Affix = _save_affix(hf_r2_mem, "hoarfrost", "hoarfrost_r2_affix")

	_save_skill(
		_make_skill("frost_hoarfrost", "Hoarfrost",
			"End of turn: apply [color=yellow]1/2[/color] [color=cyan]Chill[/color] to target per unused die in hand.",
			3, 0, _tier_pts(3), {1: [hf_r1], 2: [hf_r2]}),
		"frost_hoarfrost")

	# ── Permafrost Rune (Col 3, Center) — ice neighbors boost each other ──
	var da_pm_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Permafrost Rune I: Ice Neighbor Bonus",
			"Adjacent ice dice: +1 value each.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0,
			{}, _cond_neighbor_ice,
			DiceAffix.PositionRequirement.ANY, DiceAffix.NeighborTarget.BOTH_NEIGHBORS),
		"da_permafrost_rune_r1")
	var pm_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Permafrost Rune I",
			"Ice die next to another ice die: both get +1 value.",
			["mage", "frost", "mana_die_affix", "positional", "ice_synergy"], da_pm_r1),
		"permafrost_rune", "permafrost_rune_r1_affix")

	var da_pm_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Permafrost Rune II: Ice Neighbor Bonus",
			"Adjacent ice dice: +2 value each.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0,
			{}, _cond_neighbor_ice,
			DiceAffix.PositionRequirement.ANY, DiceAffix.NeighborTarget.BOTH_NEIGHBORS),
		"da_permafrost_rune_r2")
	var pm_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Permafrost Rune II",
			"Ice die next to another ice die: both get +2 value.",
			["mage", "frost", "mana_die_affix", "positional", "ice_synergy"], da_pm_r2),
		"permafrost_rune", "permafrost_rune_r2_affix")

	_save_skill(
		_make_skill("frost_permafrost_rune", "Permafrost Rune",
			"Ice die adjacent to another ice die: both gain +[color=yellow]1/2[/color] value.",
			3, 3, _tier_pts(3), {1: [pm_r1], 2: [pm_r2]}),
		"frost_permafrost_rune")

	# ── Frostbite (Col 6, Branch B) — lower Freeze threshold ──
	var fb_r1: Affix = _save_affix(
		_make_affix("Frostbite I", "Chill Freeze threshold reduced by 2.",
			Affix.Category.MISC,
			["mage", "frost", "freeze", "threshold"], 0.0,
			{"modify_status_threshold": "chill", "threshold_reduction": 2}),
		"frostbite", "frostbite_r1_affix")

	var fb_r2: Affix = _save_affix(
		_make_affix("Frostbite II", "Chill Freeze threshold reduced by 4.",
			Affix.Category.MISC,
			["mage", "frost", "freeze", "threshold"], 0.0,
			{"modify_status_threshold": "chill", "threshold_reduction": 4}),
		"frostbite", "frostbite_r2_affix")

	_save_skill(
		_make_skill("frost_frostbite", "Frostbite",
			"[color=cyan]Chill[/color] Freeze threshold reduced by [color=yellow]2/4[/color] (freezes at 13/11).",
			3, 6, _tier_pts(3), {1: [fb_r1], 2: [fb_r2]}),
		"frost_frostbite")


# ============================================================================
# TIER 4 — Frost Spike (Action), Glacial Clarity, Black Ice
# ============================================================================

func _create_tier_4():
	print("\n-- Tier 4 -- 3 skills...")

	# ── Frost Spike (Col 1, Branch A) — ACTION: 1 ice die, apply Chill = value ──
	var fs_dmg: ActionEffect = _save_effect(
		_make_action_effect("Frost Spike: Damage",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.ICE, 0, 1.0, 1),
		"frost_spike_damage")

	var fs_chill: ActionEffect = _save_effect(
		_make_action_effect("Frost Spike: Apply Chill",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.ICE, 0, 1.0, 0, 0, 1.0, false,
			_chill_status, 1),
		"frost_spike_chill")
	# Stack count driven by dice total via value_source
	fs_chill.stack_count = 0
	fs_chill.value_source = ActionEffect.ValueSource.DICE_TOTAL
	ResourceSaver.save(fs_chill, EFFECT_DIR + "frost_spike_chill.tres")

	var fs_effs: Array[ActionEffect] = []
	fs_effs.assign([fs_dmg, fs_chill])
	var ice_only: Array[int] = [5]  # DieResource.Element.ICE = 5
	var fs_act: Action = _save_action(
		_make_action_with_elements("frost_frost_spike", "Frost Spike",
			"Deal ice damage equal to die value. Apply Chill stacks equal to die value.",
			1, fs_effs, ice_only, Action.ChargeType.UNLIMITED, 99),
		"frost_spike_action")

	var fs_grant_mem: Affix = _make_affix("Frost Spike: Grant Action",
		"Grants Frost Spike action.",
		Affix.Category.NEW_ACTION,
		["mage", "frost", "applier", "granted_action"], 0.0,
		{"action_id": "frost_frost_spike"})
	fs_grant_mem.granted_action = fs_act
	var fs_grant: Affix = _save_affix(fs_grant_mem, "frost_spike", "frost_spike_r1_affix")

	_save_skill(
		_make_skill("frost_frost_spike", "Frost Spike",
			"[color=yellow]ACTION:[/color] 1 ice die -> ice damage + apply [color=cyan]Chill[/color] = die value. Unlimited.",
			4, 1, _tier_pts(4), {1: [fs_grant]}),
		"frost_frost_spike")

	# ── Glacial Clarity (Col 3, Center) — ice dice auto-reroll low values ──
	var da_gc_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Glacial Clarity I: Reroll", "Auto-reroll ice die below 2.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.AUTO_REROLL_LOW, 1.0,
			{}, _cond_self_value_below_2),
		"da_glacial_clarity_r1")
	var gc_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Glacial Clarity I", "Ice dice auto-reroll below 2.",
			["mage", "frost", "mana_die_affix", "reroll", "consistency"], da_gc_r1),
		"glacial_clarity", "glacial_clarity_r1_affix")

	var da_gc_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Glacial Clarity II: Reroll", "Auto-reroll ice die below 3.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.AUTO_REROLL_LOW, 1.0,
			{}, _cond_self_value_below_3),
		"da_glacial_clarity_r2")
	var gc_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Glacial Clarity II", "Ice dice auto-reroll below 3.",
			["mage", "frost", "mana_die_affix", "reroll", "consistency"], da_gc_r2),
		"glacial_clarity", "glacial_clarity_r2_affix")

	var da_gc_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Glacial Clarity III: Reroll", "Auto-reroll ice die below 4.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.AUTO_REROLL_LOW, 1.0,
			{}, _cond_self_value_below_4),
		"da_glacial_clarity_r3")
	var gc_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Glacial Clarity III", "Ice dice auto-reroll below 4.",
			["mage", "frost", "mana_die_affix", "reroll", "consistency"], da_gc_r3),
		"glacial_clarity", "glacial_clarity_r3_affix")

	_save_skill(
		_make_skill("frost_glacial_clarity", "Glacial Clarity",
			"Ice dice auto-reroll if value below [color=yellow]2/3/4[/color] (once per roll).",
			4, 3, _tier_pts(4), {1: [gc_r1], 2: [gc_r2], 3: [gc_r3]}),
		"frost_glacial_clarity")

	# ── Black Ice (Col 5, Branch B) — at 8+ Chill, bypass resist + bonus ──
	var da_bi_resist_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Black Ice I: Resist Bypass", "Ignore ice resistance at 8+ Chill.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.IGNORE_RESISTANCE, 1.0,
			{}, _cond_target_chill_8plus),
		"da_black_ice_resist_r1")
	var bi_resist_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Black Ice I: Bypass", "At 8+ Chill: ignore ice resistance.",
			["mage", "frost", "mana_die_affix", "exploiter", "penetration"], da_bi_resist_r1),
		"black_ice", "black_ice_resist_r1_affix")

	var da_bi_dmg_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Black Ice I: Bonus Damage", "+3 flat damage at 8+ Chill.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 3.0,
			{}, _cond_target_chill_8plus),
		"da_black_ice_dmg_r1")
	var bi_dmg_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Black Ice I: Damage", "At 8+ Chill: +3 bonus damage.",
			["mage", "frost", "mana_die_affix", "exploiter", "damage"], da_bi_dmg_r1),
		"black_ice", "black_ice_dmg_r1_affix")

	var da_bi_resist_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Black Ice II: Resist Bypass", "Ignore ice resistance at 8+ Chill.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.IGNORE_RESISTANCE, 1.0,
			{}, _cond_target_chill_8plus),
		"da_black_ice_resist_r2")
	var bi_resist_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Black Ice II: Bypass", "At 8+ Chill: ignore ice resistance.",
			["mage", "frost", "mana_die_affix", "exploiter", "penetration"], da_bi_resist_r2),
		"black_ice", "black_ice_resist_r2_affix")

	var da_bi_dmg_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Black Ice II: Bonus Damage", "+5 flat damage at 8+ Chill.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 5.0,
			{}, _cond_target_chill_8plus),
		"da_black_ice_dmg_r2")
	var bi_dmg_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Black Ice II: Damage", "At 8+ Chill: +5 bonus damage.",
			["mage", "frost", "mana_die_affix", "exploiter", "damage"], da_bi_dmg_r2),
		"black_ice", "black_ice_dmg_r2_affix")

	_save_skill(
		_make_skill("frost_black_ice", "Black Ice",
			"At 8+ [color=cyan]Chill[/color]: ice die ignores resistance and deals +[color=yellow]3/5[/color] bonus damage.",
			4, 5, _tier_pts(4),
			{1: [bi_resist_r1, bi_dmg_r1],
			2: [bi_resist_r2, bi_dmg_r2]}),
		"frost_black_ice")


# ============================================================================
# TIER 5 — Spreading Cold, Frozen Conduit (Weave), Shatter (Action)
# ============================================================================

func _create_tier_5():
	print("\n-- Tier 5 -- 3 skills...")

	# ── Spreading Cold (Col 0, Branch A) — splash Chill to other enemies ──
	var da_sc_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Spreading Cold I: Chill Splash",
			"Splash 30% of applied Chill to all other enemies.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "chill", "splash_percent": 0.3, "splash_target": "ALL_OTHER_ENEMIES"}),
		"da_spreading_cold_r1")
	var sc_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Spreading Cold I",
			"Ice die splashes 30% of Chill applied to all other enemies.",
			["mage", "frost", "mana_die_affix", "chill_apply", "aoe", "spread"], da_sc_r1),
		"spreading_cold", "spreading_cold_r1_affix")

	var da_sc_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Spreading Cold II: Chill Splash",
			"Splash 50% of applied Chill to all other enemies.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "chill", "splash_percent": 0.5, "splash_target": "ALL_OTHER_ENEMIES"}),
		"da_spreading_cold_r2")
	var sc_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Spreading Cold II",
			"Ice die splashes 50% of Chill applied to all other enemies.",
			["mage", "frost", "mana_die_affix", "chill_apply", "aoe", "spread"], da_sc_r2),
		"spreading_cold", "spreading_cold_r2_affix")

	_save_skill(
		_make_skill("frost_spreading_cold", "Spreading Cold",
			"Ice die splashes [color=yellow]30/50%[/color] of [color=cyan]Chill[/color] to all other enemies.",
			5, 0, _tier_pts(5), {1: [sc_r1], 2: [sc_r2]}),
		"frost_spreading_cold")

	# ── Frozen Conduit (Col 3, Weave) — ice die +1 value per 3 Chill stacks ──
	var da_fc: DiceAffix = _save_dice_affix(
		_make_dice_affix("Frozen Conduit: Chill Scaling",
			"Ice die +1 value per 3 Chill stacks on target.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0,
			{"value_per_n_stacks": 1, "n_stacks": 3, "status_id": "chill"},
			_cond_target_has_chill),
		"da_frozen_conduit")
	var fc_affix: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Frozen Conduit",
			"Ice die value +1 per 3 Chill stacks on target.",
			["mage", "frost", "mana_die_affix", "weave", "scaling"], da_fc),
		"frozen_conduit", "frozen_conduit_r1_affix")

	_save_skill(
		_make_skill("frost_frozen_conduit", "Frozen Conduit",
			"[color=yellow]WEAVE:[/color] Ice die value +1 per 3 [color=cyan]Chill[/color] stacks on target.",
			5, 3, _tier_pts(5), {1: [fc_affix]}),
		"frost_frozen_conduit")

	# ── Shatter (Col 6, Branch B) — ACTION: 2 ice dice, x1.5 / x4.5 if Frozen ──
	var sht_dmg: ActionEffect = _save_effect(
		_make_action_effect("Shatter: Damage",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.ICE, 0, 1.5, 2),
		"shatter_damage")

	var sht_frozen_dmg: ActionEffect = _save_effect(
		_make_action_effect("Shatter: Frozen Bonus",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.ICE, 0, 3.0, 2),
		"shatter_frozen_bonus")
	# Conditional: only fires if target has Freeze
	sht_frozen_dmg.effect_data = {"condition": "target_has_status", "status_id": "freeze",
		"replaces_base_damage": true}
	ResourceSaver.save(sht_frozen_dmg, EFFECT_DIR + "shatter_frozen_bonus.tres")

	var sht_remove_freeze: ActionEffect = _save_effect(
		_make_action_effect("Shatter: Consume Freeze",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.REMOVE_STATUS,
			ActionEffect.DamageType.ICE, 0, 1.0, 0, 0, 1.0, false,
			_freeze_status, 1),
		"shatter_remove_freeze")

	var sht_effs: Array[ActionEffect] = []
	sht_effs.assign([sht_dmg, sht_frozen_dmg, sht_remove_freeze])
	var ice_elements: Array[int] = [5]
	_shatter_action = _save_action(
		_make_action_with_elements("frost_shatter", "Shatter",
			"Deal x1.5 ice damage. If Frozen: x4.5 instead and consume Freeze.",
			2, sht_effs, ice_elements, Action.ChargeType.LIMITED_PER_TURN, 1),
		"shatter_action")

	var sht_grant_mem: Affix = _make_affix("Shatter: Grant Action",
		"Grants Shatter action.",
		Affix.Category.NEW_ACTION,
		["mage", "frost", "exploiter", "granted_action"], 0.0,
		{"action_id": "frost_shatter"})
	sht_grant_mem.granted_action = _shatter_action
	var sht_grant: Affix = _save_affix(sht_grant_mem, "shatter", "shatter_r1_affix")

	_save_skill(
		_make_skill("frost_shatter", "Shatter",
			"[color=yellow]ACTION:[/color] 2 ice dice -> x1.5 ice damage. [color=cyan]Frozen[/color]: x4.5 + consume. Per turn.",
			5, 6, _tier_pts(5), {1: [sht_grant]}),
		"frost_shatter")


# ============================================================================
# TIER 6 — Avalanche, Entropy (Weave), Glacial Execution
# ============================================================================

func _create_tier_6():
	print("\n-- Tier 6 -- 3 skills...")

	# ── Avalanche (Col 1, Branch A) — on Freeze trigger, Chill all others ──
	var avl_r1_mem: Affix = _make_affix("Avalanche I",
		"When Freeze triggers: apply 3 Chill to all other enemies.",
		Affix.Category.PROC, ["mage", "frost", "applier", "chill_apply", "aoe", "chain"], 3.0,
		{"proc_trigger": "ON_STATUS_APPLIED", "proc_condition_status": "freeze",
		"proc_effect": "apply_status_to_all_others",
		"status_id": "chill", "stacks": 3})
	avl_r1_mem.proc_trigger = Affix.ProcTrigger.ON_STATUS_APPLIED
	var avl_r1: Affix = _save_affix(avl_r1_mem, "avalanche", "avalanche_r1_affix")

	var avl_r2_mem: Affix = _make_affix("Avalanche II",
		"When Freeze triggers: apply 5 Chill to all other enemies.",
		Affix.Category.PROC, ["mage", "frost", "applier", "chill_apply", "aoe", "chain"], 5.0,
		{"proc_trigger": "ON_STATUS_APPLIED", "proc_condition_status": "freeze",
		"proc_effect": "apply_status_to_all_others",
		"status_id": "chill", "stacks": 5})
	avl_r2_mem.proc_trigger = Affix.ProcTrigger.ON_STATUS_APPLIED
	var avl_r2: Affix = _save_affix(avl_r2_mem, "avalanche", "avalanche_r2_affix")

	_save_skill(
		_make_skill("frost_avalanche", "Avalanche",
			"When [color=cyan]Freeze[/color] triggers: apply [color=yellow]3/5[/color] [color=cyan]Chill[/color] to all other enemies.",
			6, 1, _tier_pts(6), {1: [avl_r1], 2: [avl_r2]}),
		"frost_avalanche")

	# ── Entropy (Col 3, Weave) — start of turn: if 10+ Chill, restore mana + buff ──
	var ent_mem: Affix = _make_affix("Entropy",
		"Start of turn: if any enemy has 10+ Chill, restore 2 mana and next ice die +3.",
		Affix.Category.PER_TURN, ["mage", "frost", "weave", "mana", "sustain"], 0.0,
		{"turn_trigger": "START_OF_TURN",
		"condition": "any_enemy_status_stacks_above",
		"condition_status": "chill", "condition_threshold": 10,
		"effects": [
			{"type": "mana_restore", "amount": 2},
			{"type": "temp_mana_die_affix", "element": "ICE", "effect": "MODIFY_VALUE_FLAT", "value": 3, "uses": 1}
		]})
	var ent: Affix = _save_affix(ent_mem, "entropy", "entropy_r1_affix")

	_save_skill(
		_make_skill("frost_entropy", "Entropy",
			"[color=yellow]WEAVE:[/color] Turn start: if 10+ [color=cyan]Chill[/color] on any enemy, restore 2 mana + next ice die +3 value.",
			6, 3, _tier_pts(6), {1: [ent]}),
		"frost_entropy")

	# ── Glacial Execution (Col 5, Branch B) — Shatter execute upgrade ──
	var gex_r1: Affix = _save_affix(
		_make_affix("Glacial Execution I", "Shatter: x2 damage if target below 30% HP.",
			Affix.Category.ACTION_EFFECT_UPGRADE,
			["mage", "frost", "exploiter", "execute", "shatter_upgrade"], 0.0,
			{"action_id": "frost_shatter", "execute_threshold": 0.3, "execute_multiplier": 2.0}),
		"glacial_execution", "glacial_execution_r1_affix")

	var gex_r2: Affix = _save_affix(
		_make_affix("Glacial Execution II", "Shatter: x2 damage if target below 40% HP.",
			Affix.Category.ACTION_EFFECT_UPGRADE,
			["mage", "frost", "exploiter", "execute", "shatter_upgrade"], 0.0,
			{"action_id": "frost_shatter", "execute_threshold": 0.4, "execute_multiplier": 2.0}),
		"glacial_execution", "glacial_execution_r2_affix")

	_save_skill(
		_make_skill("frost_glacial_execution", "Glacial Execution",
			"Shatter deals x2 damage if target is below [color=yellow]30/40%[/color] HP.",
			6, 5, _tier_pts(6), {1: [gex_r1], 2: [gex_r2]}),
		"frost_glacial_execution")


# ============================================================================
# TIER 7 — Rimestorm, Crystallize
# ============================================================================

func _create_tier_7():
	print("\n-- Tier 7 -- 2 skills...")

	# ── Rimestorm (Col 2, Center) — ice die chains to 1 extra enemy ──
	var da_rs: DiceAffix = _save_dice_affix(
		_make_dice_affix("Rimestorm: Chain",
			"Ice die chains to 1 additional enemy for 60% damage, applying 2 Chill.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.6,
			{"chain_count": 1, "chain_damage_mult": 0.6,
			"chain_status": "chill", "chain_stacks": 2}),
		"da_rimestorm")
	var rs_affix: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Rimestorm",
			"Ice die chains to 1 extra enemy (60% damage, 2 Chill).",
			["mage", "frost", "mana_die_affix", "chain", "aoe"], da_rs),
		"rimestorm", "rimestorm_r1_affix")

	_save_skill(
		_make_skill("frost_rimestorm", "Rimestorm",
			"Ice die chains to 1 additional enemy for [color=yellow]60%[/color] damage, applying [color=cyan]2 Chill[/color].",
			7, 2, _tier_pts(7), {1: [rs_affix]}),
		"frost_rimestorm")

	# ── Crystallize (Col 5, Branch B) — on damage to Frozen: barrier + resist shred ──
	var cry_mem: Affix = _make_affix("Crystallize",
		"Damage to Frozen target: gain 4 Barrier, target loses 2 ice resistance permanently.",
		Affix.Category.PROC, ["mage", "frost", "exploiter", "defense", "resistance_shred"], 0.0,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_condition_status": "freeze",
		"effects": [
			{"type": "barrier_gain", "amount": 4},
			{"type": "target_resist_reduction", "element": "ICE", "amount": 2, "permanent": true}
		]})
	cry_mem.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	var cry: Affix = _save_affix(cry_mem, "crystallize", "crystallize_r1_affix")

	_save_skill(
		_make_skill("frost_crystallize", "Crystallize",
			"Damage to [color=cyan]Frozen[/color] target: gain [color=yellow]4 Barrier[/color], target loses [color=yellow]2 ice resistance[/color] permanently.",
			7, 5, _tier_pts(7), {1: [cry]}),
		"frost_crystallize")


# ============================================================================
# TIER 8 — Absolute Zero (Signature Action), Entropic Cascade (Capstone)
# ============================================================================

func _create_tier_8():
	print("\n-- Tier 8 -- 2 skills...")

	# ── Absolute Zero (Col 3, Signature) — 3 ice dice, AoE damage + Chill = total ──
	var az_dmg: ActionEffect = _save_effect(
		_make_action_effect("Absolute Zero: AoE Damage",
			ActionEffect.TargetType.ALL_ENEMIES, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.ICE, 0, 1.0, 3),
		"absolute_zero_damage")

	var az_chill: ActionEffect = _save_effect(
		_make_action_effect("Absolute Zero: Mass Chill",
			ActionEffect.TargetType.ALL_ENEMIES, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.ICE, 0, 1.0, 0, 0, 1.0, false,
			_chill_status, 1),
		"absolute_zero_chill")
	az_chill.stack_count = 0
	az_chill.value_source = ActionEffect.ValueSource.DICE_TOTAL
	ResourceSaver.save(az_chill, EFFECT_DIR + "absolute_zero_chill.tres")

	var az_refund: ActionEffect = _save_effect(
		_make_action_effect("Absolute Zero: Reset Shatter",
			ActionEffect.TargetType.SELF, ActionEffect.EffectType.REFUND_CHARGES,
			ActionEffect.DamageType.ICE, 0, 1.0, 0, 0, 1.0, false,
			null, 1),
		"absolute_zero_refund")
	az_refund.effect_data = {"condition": "any_freeze_triggered",
		"target_action_id": "frost_shatter", "charges": 1}
	ResourceSaver.save(az_refund, EFFECT_DIR + "absolute_zero_refund.tres")

	var az_effs: Array[ActionEffect] = []
	az_effs.assign([az_dmg, az_chill, az_refund])
	var ice_elements: Array[int] = [5]
	var az_act: Action = _save_action(
		_make_action_with_elements("frost_absolute_zero", "Absolute Zero",
			"Deal ice damage to ALL enemies equal to dice total. Apply Chill = dice total to all. If any Freeze triggers, reset Shatter charge.",
			3, az_effs, ice_elements, Action.ChargeType.LIMITED_PER_COMBAT, 1),
		"absolute_zero_action")

	var az_grant_mem: Affix = _make_affix("Absolute Zero: Grant Action",
		"Grants Absolute Zero action.",
		Affix.Category.NEW_ACTION,
		["mage", "frost", "signature", "granted_action", "aoe", "ultimate"], 0.0,
		{"action_id": "frost_absolute_zero"})
	az_grant_mem.granted_action = az_act
	var az_grant: Affix = _save_affix(az_grant_mem, "absolute_zero", "absolute_zero_r1_affix")

	_save_skill(
		_make_skill("frost_absolute_zero", "Absolute Zero",
			"[color=yellow]SIGNATURE:[/color] 3 ice dice -> AoE ice damage + [color=cyan]Chill[/color] = dice total to all. Freeze resets Shatter. Per combat.",
			8, 3, _tier_pts(8), {1: [az_grant]}),
		"frost_absolute_zero")

	# ── Entropic Cascade (Col 4, Capstone) — Freeze amplifies all Chill ──
	var ec_spread_mem: Affix = _make_affix("Entropic Cascade: Chill Spread",
		"When Freeze triggers: all Chill on all enemies +3.",
		Affix.Category.PROC, ["mage", "frost", "capstone", "chill_amplify", "aoe"], 0.0,
		{"proc_trigger": "ON_STATUS_APPLIED", "proc_condition_status": "freeze",
		"proc_effect": "increase_status_stacks_on_all",
		"status_id": "chill", "stacks": 3})
	ec_spread_mem.proc_trigger = Affix.ProcTrigger.ON_STATUS_APPLIED
	var ec_spread: Affix = _save_affix(ec_spread_mem, "entropic_cascade", "entropic_cascade_spread_affix")

	var ec_penalty: Affix = _save_affix(
		_make_affix("Entropic Cascade: Enhanced Penalty",
			"Chill die-value penalty improved: -2 per 2 stacks (instead of -1).",
			Affix.Category.MISC,
			["mage", "frost", "capstone", "chill_amplify"], 0.0,
			{"modify_status_effect": "chill", "dice_penalty_per_interval": -2}),
		"entropic_cascade", "entropic_cascade_penalty_affix")

	_save_skill(
		_make_skill("frost_entropic_cascade", "Entropic Cascade",
			"[color=yellow]CAPSTONE:[/color] [color=cyan]Freeze[/color] triggers: +3 [color=cyan]Chill[/color] on ALL enemies. Chill penalty improved to -2 per 2 stacks.",
			8, 4, _tier_pts(8), {1: [ec_spread, ec_penalty]}),
		"frost_entropic_cascade")


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

	# TIER 2: all require Glaciate
	_add_prereq.call("frost_creeping_frost", "frost_glaciate")
	_add_prereq.call("frost_rime_dice", "frost_glaciate")
	_add_prereq.call("frost_brittle", "frost_glaciate")

	# TIER 3
	_add_prereq.call("frost_hoarfrost", "frost_creeping_frost")
	_add_prereq.call("frost_permafrost_rune", "frost_rime_dice")
	_add_prereq.call("frost_frostbite", "frost_brittle")

	# TIER 4
	_add_prereq.call("frost_frost_spike", "frost_creeping_frost")
	_add_prereq.call("frost_glacial_clarity", "frost_permafrost_rune")
	_add_prereq.call("frost_black_ice", "frost_brittle")

	# TIER 5
	_add_prereq.call("frost_spreading_cold", "frost_hoarfrost")
	# Frozen Conduit — WEAVE: requires BOTH branches
	_add_prereq.call("frost_frozen_conduit", "frost_frost_spike")
	_add_prereq.call("frost_frozen_conduit", "frost_frostbite")
	_add_prereq.call("frost_shatter", "frost_black_ice")

	# TIER 6
	_add_prereq.call("frost_avalanche", "frost_spreading_cold")
	_add_prereq.call("frost_entropy", "frost_frozen_conduit")
	_add_prereq.call("frost_glacial_execution", "frost_shatter")

	# TIER 7
	_add_prereq.call("frost_rimestorm", "frost_entropy")
	_add_prereq.call("frost_crystallize", "frost_glacial_execution")

	# TIER 8: Absolute Zero requires BOTH T7 skills (crossover)
	_add_prereq.call("frost_absolute_zero", "frost_rimestorm")
	_add_prereq.call("frost_absolute_zero", "frost_crystallize")
	# Entropic Cascade requires Entropy
	_add_prereq.call("frost_entropic_cascade", "frost_entropy")

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
	tree.tree_id = "mage_frost"
	tree.tree_name = "Frost"
	tree.description = "Master ice magic. Three paths: Chill Applier (creative frost application), Freeze Exploiter (shatter and execute), Weave (feedback loops bridging both). Control through attrition — degrade enemy dice, freeze their turns."

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

	var tree_path: String = TREE_DIR + "mage_frost.tres"
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
