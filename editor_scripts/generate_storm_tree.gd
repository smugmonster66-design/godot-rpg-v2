# res://editor_scripts/generate_storm_tree.gd
# Run via: Editor -> Script -> Run (Ctrl+Shift+X) with this script open.
#
# WHAT THIS DOES:
#   Creates the complete 20-skill Mage Storm skill tree (8-tier system).
#   All cross-references use ExtResource (save-then-load pattern).
#
# SAFE TO RE-RUN: Overwrites existing files at the same paths.
#
# DESIGN:
#   Branch A (cols 0-1): Voltaic — Static application through dice use, pulls, snowball procs
#   Branch C (cols 2-4): Center — Chain mechanics, positioning, Storm Sprite companion
#   Branch B (cols 5-6): Tempest-Conduit — Per-stack damage, mana economy, kill-chain payoffs
#
@tool
extends EditorScript

# ============================================================================
# DIRECTORY STRUCTURE
# ============================================================================

const BASE_AFFIX_DIR  := "res://resources/affixes/classes/mage/storm/"
const BASE_SKILL_DIR  := "res://resources/skills/classes/mage/storm/"
const DICE_AFFIX_DIR  := "res://resources/dice_affixes/mage/storm/"
const CONDITION_DIR   := "res://resources/dice_affixes/mage/storm/conditions/"
const ACTION_DIR      := "res://resources/actions/mage/storm/"
const EFFECT_DIR      := "res://resources/actions/mage/storm/effects/"
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
var _static_status: StatusAffix

var _cond_target_has_static: DiceAffixCondition
var _cond_target_static_8plus: DiceAffixCondition
var _cond_no_adjacent_shock: DiceAffixCondition


# ============================================================================
# ENTRY POINT
# ============================================================================

func _run() -> void:
	print("\n" + "=".repeat(60))
	print("  GENERATING MAGE STORM TREE (20 SKILLS) — 8-tier system")
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
	print("  STORM TREE GENERATION COMPLETE")
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
	da.global_element_type = ActionEffect.DamageType.SHOCK
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
		p_damage_type: int = ActionEffect.DamageType.SHOCK,
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

	# Load existing Static status (do NOT recreate)
	_static_status = load(STATUS_DIR + "static.tres") as StatusAffix
	if _static_status:
		print("  Static StatusAffix loaded (path: %s)" % _static_status.resource_path)
	else:
		push_error("Could not load static.tres -- aborting")
		return

	# Shared DiceAffixConditions — save then reload into member vars
	_cond_target_has_static = _save_condition(
		_make_condition(DiceAffixCondition.Type.TARGET_HAS_STATUS, 0.0, false, "", "static"),
		"cond_target_has_static")

	_cond_target_static_8plus = _save_condition(
		_make_condition(DiceAffixCondition.Type.TARGET_STATUS_STACKS_ABOVE, 8.0, false, "", "static"),
		"cond_target_static_8plus")

	_cond_no_adjacent_shock = _save_condition(
		_make_condition(DiceAffixCondition.Type.NEIGHBOR_HAS_ELEMENT, 0.0, true, "SHOCK"),
		"cond_no_adjacent_shock")

	print("  Shared resources complete\n")


# ============================================================================
# TIER 1 — Spark (Root)
# ============================================================================

func _create_tier_1():
	print("\n-- Tier 1 -- Spark...")

	# Affix 1: Unlock SHOCK element
	var spk_elem: Affix = _save_affix(
		_make_affix("Spark: Shock Unlock", "Unlocks Shock mana element.",
			Affix.Category.MANA_ELEMENT_UNLOCK,
			["mage", "storm", "element_unlock"], 0.0, {"element": "SHOCK"}),
		"spark", "spark_element_unlock")

	# Affix 2 (R1): Chromatic Bolt shock die applies 1 Static
	var spk_static_eff_r1: ActionEffect = _save_effect(
		_make_action_effect("Spark R1: Apply Static",
			ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK,
			0, 1.0, 0, 0, 1.0, false,
			_static_status, 1),
		"spark_apply_static_r1")

	var spk_ca_r1: Affix = _save_affix(
		_make_affix("Spark R1: Chromatic Bolt Static",
			"Chromatic Bolt applies 1 Static on hit (requires shock die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "storm", "class_action_mod", "static_apply"], 0.0,
			{"action_effect": spk_static_eff_r1, "shock_die_condition": true}),
		"spark", "spark_ca_r1_affix")

	# Affix 2 (R2): Chromatic Bolt shock die applies 2 Static
	var spk_static_eff_r2: ActionEffect = _save_effect(
		_make_action_effect("Spark R2: Apply Static",
			ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK,
			0, 1.0, 0, 0, 1.0, false,
			_static_status, 2),
		"spark_apply_static_r2")

	var spk_ca_r2: Affix = _save_affix(
		_make_affix("Spark R2: Chromatic Bolt Static",
			"Chromatic Bolt applies 2 Static on hit (requires shock die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "storm", "class_action_mod", "static_apply"], 0.0,
			{"action_effect": spk_static_eff_r2, "shock_die_condition": true}),
		"spark", "spark_ca_r2_affix")

	# Affix 2 (R3): Chromatic Bolt shock die applies 3 Static
	var spk_static_eff_r3: ActionEffect = _save_effect(
		_make_action_effect("Spark R3: Apply Static",
			ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK,
			0, 1.0, 0, 0, 1.0, false,
			_static_status, 3),
		"spark_apply_static_r3")

	var spk_ca_r3: Affix = _save_affix(
		_make_affix("Spark R3: Chromatic Bolt Static",
			"Chromatic Bolt applies 3 Static on hit (requires shock die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "storm", "class_action_mod", "static_apply"], 0.0,
			{"action_effect": spk_static_eff_r3, "shock_die_condition": true}),
		"spark", "spark_ca_r3_affix")

	_save_skill(
		_make_skill("storm_spark", "Spark",
			"Unlock [color=yellow]Shock[/color] mana. Chromatic Bolt applies [color=yellow]1/2/3 Static[/color] on hit (requires shock die).",
			1, 3, _tier_pts(1),
			{1: [spk_elem, spk_ca_r1], 2: [spk_elem, spk_ca_r2], 3: [spk_elem, spk_ca_r3]}),
		"storm_spark")


# ============================================================================
# TIER 2 — Arc Pulse, Conductor, Galvanic Pulse
# ============================================================================

func _create_tier_2():
	print("\n-- Tier 2 -- 3 skills...")

	# ── Arc Pulse (Col 1, Branch A) — shock die applies Static on use ──
	var da_ap_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Pulse I: Static on Use", "Apply 1 Static on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 1}),
		"da_arc_pulse_r1")
	var ap_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Pulse I", "Shock dice apply 1 Static on use.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_ap_r1),
		"arc_pulse", "arc_pulse_r1_affix")

	var da_ap_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Pulse II: Static on Use", "Apply 2 Static on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 2}),
		"da_arc_pulse_r2")
	var ap_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Pulse II", "Shock dice apply 2 Static on use.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_ap_r2),
		"arc_pulse", "arc_pulse_r2_affix")

	var da_ap_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Pulse III: Static on Use", "Apply 3 Static on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 3}),
		"da_arc_pulse_r3")
	var ap_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Pulse III", "Shock dice apply 3 Static on use.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_ap_r3),
		"arc_pulse", "arc_pulse_r3_affix")

	_save_skill(
		_make_skill("storm_arc_pulse", "Arc Pulse",
			"Shock mana dice apply [color=yellow]1/2/3[/color] [color=yellow]Static[/color] on use.",
			2, 1, _tier_pts(2), {1: [ap_r1], 2: [ap_r2], 3: [ap_r3]}),
		"storm_arc_pulse")

	# ── Conductor (Col 3, Center) — shock dice chain damage on use ──
	var da_con_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Conductor I: Chain on Use", "Chain 30% damage to 1 enemy.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.3,
			{"chain_count": 1, "chain_damage_mult": 0.3}),
		"da_conductor_r1")
	var con_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Conductor I", "Shock dice chain 30% damage to 1 enemy on use.",
			["mage", "storm", "mana_die_affix", "chain", "center"], da_con_r1),
		"conductor", "conductor_r1_affix")

	var da_con_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Conductor II: Chain on Use", "Chain 40% damage to 1 enemy.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.4,
			{"chain_count": 1, "chain_damage_mult": 0.4}),
		"da_conductor_r2")
	var con_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Conductor II", "Shock dice chain 40% damage to 1 enemy on use.",
			["mage", "storm", "mana_die_affix", "chain", "center"], da_con_r2),
		"conductor", "conductor_r2_affix")

	var da_con_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Conductor III: Chain on Use", "Chain 50% damage to 1 enemy.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.5,
			{"chain_count": 1, "chain_damage_mult": 0.5}),
		"da_conductor_r3")
	var con_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Conductor III", "Shock dice chain 50% damage to 1 enemy on use.",
			["mage", "storm", "mana_die_affix", "chain", "center"], da_con_r3),
		"conductor", "conductor_r3_affix")

	_save_skill(
		_make_skill("storm_conductor", "Conductor",
			"Shock mana dice chain [color=yellow]30/40/50%[/color] damage to 1 additional enemy on use.",
			2, 3, _tier_pts(2), {1: [con_r1], 2: [con_r2], 3: [con_r3]}),
		"storm_conductor")

	# ── Galvanic Pulse (Col 5, Branch B) — mana restore on Static target hit ──
	var gp_r1_mem: Affix = _make_affix("Galvanic Pulse I",
		"Shock damage to Static target restores 1 mana. Max 2/turn.",
		Affix.Category.PROC, ["mage", "storm", "proc", "mana", "conduit"], 1.0,
		{"proc_trigger": "ON_DEAL_SHOCK_DAMAGE", "proc_condition_status": "static",
		"proc_effect": "mana_restore", "amount": 1, "max_per_turn": 2})
	gp_r1_mem.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	var gp_r1: Affix = _save_affix(gp_r1_mem, "galvanic_pulse", "galvanic_pulse_r1_affix")

	var gp_r2_mem: Affix = _make_affix("Galvanic Pulse II",
		"Shock damage to Static target restores 2 mana. Max 2/turn.",
		Affix.Category.PROC, ["mage", "storm", "proc", "mana", "conduit"], 2.0,
		{"proc_trigger": "ON_DEAL_SHOCK_DAMAGE", "proc_condition_status": "static",
		"proc_effect": "mana_restore", "amount": 2, "max_per_turn": 2})
	gp_r2_mem.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	var gp_r2: Affix = _save_affix(gp_r2_mem, "galvanic_pulse", "galvanic_pulse_r2_affix")

	_save_skill(
		_make_skill("storm_galvanic_pulse", "Galvanic Pulse",
			"Shock damage to [color=yellow]Static[/color] target restores [color=yellow]1/2[/color] mana. Max 2 triggers/turn.",
			2, 5, _tier_pts(2), {1: [gp_r1], 2: [gp_r2]}),
		"storm_galvanic_pulse")


# ============================================================================
# TIER 3 — Ionize, Thunderclap (Action), Storm Sprite (Companion), Polarity
# ============================================================================

func _create_tier_3():
	print("\n-- Tier 3 -- 4 skills...")

	# ── Ionize (Col 0, Branch A) — pulling shock die applies Static ──
	var da_ion_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Ionize I: Static on Pull", "Pulling shock die applies 1 Static.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 1, "target": "random_enemy", "trigger_on_pull": true}),
		"da_ionize_r1")
	var ion_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Ionize I", "Pulling shock die applies 1 Static to random enemy.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_ion_r1),
		"ionize", "ionize_r1_affix")

	var da_ion_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Ionize II: Static on Pull", "Pulling shock die applies 2 Static.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 2, "target": "random_enemy", "trigger_on_pull": true}),
		"da_ionize_r2")
	var ion_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Ionize II", "Pulling shock die applies 2 Static to random enemy.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_ion_r2),
		"ionize", "ionize_r2_affix")

	var da_ion_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Ionize III: Static on Pull", "Pulling shock die applies 3 Static.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 3, "target": "random_enemy", "trigger_on_pull": true}),
		"da_ionize_r3")
	var ion_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Ionize III", "Pulling shock die applies 3 Static to random enemy.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_ion_r3),
		"ionize", "ionize_r3_affix")

	_save_skill(
		_make_skill("storm_ionize", "Ionize",
			"Pulling shock mana die applies [color=yellow]1/2/3[/color] [color=yellow]Static[/color] to random enemy.",
			3, 0, _tier_pts(3), {1: [ion_r1], 2: [ion_r2], 3: [ion_r3]}),
		"storm_ionize")

	# ── Thunderclap (Col 1, Branch A) — ACTION: 1 die, unlimited, apply Static = value ──
	var tc_dmg: ActionEffect = _save_effect(
		_make_action_effect("Thunderclap: Damage",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 0, 1.0, 1),
		"thunderclap_damage")

	var tc_static: ActionEffect = _save_effect(
		_make_action_effect("Thunderclap: Apply Static",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK, 0, 1.0, 0, 0, 1.0, false,
			_static_status, 1),
		"thunderclap_static")
	# Stack count driven by dice total via value_source
	tc_static.stack_count = 0
	tc_static.value_source = ActionEffect.ValueSource.DICE_TOTAL
	ResourceSaver.save(tc_static, EFFECT_DIR + "thunderclap_static.tres")

	var tc_effs: Array[ActionEffect] = []
	tc_effs.assign([tc_dmg, tc_static])
	var shock_only: Array[int] = [4]  # DieResource.Element.SHOCK = 4
	var tc_act: Action = _save_action(
		_make_action_with_elements("storm_thunderclap", "Thunderclap",
			"Deal shock damage equal to die value. Apply Static stacks equal to die value.",
			1, tc_effs, shock_only, Action.ChargeType.UNLIMITED, 99),
		"thunderclap_action")

	var tc_grant_mem: Affix = _make_affix("Thunderclap: Grant Action",
		"Grants Thunderclap action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "voltaic", "granted_action"], 0.0,
		{"action_id": "storm_thunderclap"})
	tc_grant_mem.granted_action = tc_act
	var tc_grant: Affix = _save_affix(tc_grant_mem, "thunderclap", "thunderclap_r1_affix")

	_save_skill(
		_make_skill("storm_thunderclap", "Thunderclap",
			"[color=yellow]ACTION:[/color] 1 shock die -> shock damage + apply [color=yellow]Static[/color] = die value. Unlimited.",
			3, 1, _tier_pts(3), {1: [tc_grant]}),
		"storm_thunderclap")

	# ── Storm Sprite (Col 3, Center) — ACTION: summon companion ──
	var ss_dmg: ActionEffect = _save_effect(
		_make_action_effect("Storm Sprite: Zap",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 4, 1.0, 0),
		"storm_sprite_zap")

	var ss_static: ActionEffect = _save_effect(
		_make_action_effect("Storm Sprite: Static",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK, 0, 1.0, 0, 0, 1.0, false,
			_static_status, 1),
		"storm_sprite_static")

	var ss_effs: Array[ActionEffect] = []
	ss_effs.assign([ss_dmg, ss_static])
	var ss_act: Action = _save_action(
		_make_action_with_elements("storm_conjure_sprite", "Conjure Storm Sprite",
			"Summon a Storm Sprite that zaps a random enemy each turn for 4 shock damage and 1 Static. HP scales with die value.",
			1, ss_effs, shock_only, Action.ChargeType.LIMITED_PER_COMBAT, 1),
		"conjure_storm_sprite_action")
	ss_act.effect_data = {"summon": true, "companion_type": "storm_sprite",
		"hp_source": "DICE_TOTAL", "hp_multiplier": 3}
	ResourceSaver.save(ss_act, ACTION_DIR + "conjure_storm_sprite_action.tres")

	var ss_grant_mem: Affix = _make_affix("Storm Sprite: Grant Action",
		"Grants Conjure Storm Sprite action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "center", "granted_action", "companion"], 0.0,
		{"action_id": "storm_conjure_sprite"})
	ss_grant_mem.granted_action = ss_act
	var ss_grant: Affix = _save_affix(ss_grant_mem, "storm_sprite", "storm_sprite_r1_affix")

	_save_skill(
		_make_skill("storm_storm_sprite", "Storm Sprite",
			"[color=yellow]ACTION:[/color] 1 shock die, per-combat. Summon Sprite (zaps random enemy: 4 shock + 1 [color=yellow]Static[/color]/turn). HP = die value x3.",
			3, 3, _tier_pts(3), {1: [ss_grant]}),
		"storm_storm_sprite")

	# ── Polarity (Col 6, Branch B) — shock die bonus if no adjacent shock ──
	var da_pol_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Polarity I: Isolation Bonus", "Shock die +2 value if no adjacent shock.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0,
			{}, _cond_no_adjacent_shock),
		"da_polarity_r1")
	var pol_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Polarity I", "Shock die +2 value if no adjacent die is Shock.",
			["mage", "storm", "mana_die_affix", "positional", "conduit"], da_pol_r1),
		"polarity", "polarity_r1_affix")

	var da_pol_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Polarity II: Isolation Bonus", "Shock die +3 value if no adjacent shock.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 3.0,
			{}, _cond_no_adjacent_shock),
		"da_polarity_r2")
	var pol_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Polarity II", "Shock die +3 value if no adjacent die is Shock.",
			["mage", "storm", "mana_die_affix", "positional", "conduit"], da_pol_r2),
		"polarity", "polarity_r2_affix")

	var da_pol_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Polarity III: Isolation Bonus", "Shock die +4 value if no adjacent shock.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 4.0,
			{}, _cond_no_adjacent_shock),
		"da_polarity_r3")
	var pol_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Polarity III", "Shock die +4 value if no adjacent die is Shock.",
			["mage", "storm", "mana_die_affix", "positional", "conduit"], da_pol_r3),
		"polarity", "polarity_r3_affix")

	_save_skill(
		_make_skill("storm_polarity", "Polarity",
			"Shock die gains +[color=yellow]2/3/4[/color] value if no adjacent die is Shock element.",
			3, 6, _tier_pts(3), {1: [pol_r1], 2: [pol_r2], 3: [pol_r3]}),
		"storm_polarity")


# ============================================================================
# TIER 4 — Live Wire, Arc Conduit, Voltaic Surge, Mana Siphon
# ============================================================================

func _create_tier_4():
	print("\n-- Tier 4 -- 4 skills...")

	# ── Live Wire (Col 0, Branch A) — bonus Static if target already has Static ──
	var da_lw_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Live Wire I: Snowball Static", "+1 bonus Static if target has Static.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 1},
			_cond_target_has_static),
		"da_live_wire_r1")
	var lw_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Live Wire I", "Shock dice apply +1 bonus Static if target already has Static.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic", "snowball"], da_lw_r1),
		"live_wire", "live_wire_r1_affix")

	var da_lw_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Live Wire II: Snowball Static", "+2 bonus Static if target has Static.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 2},
			_cond_target_has_static),
		"da_live_wire_r2")
	var lw_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Live Wire II", "Shock dice apply +2 bonus Static if target already has Static.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic", "snowball"], da_lw_r2),
		"live_wire", "live_wire_r2_affix")

	_save_skill(
		_make_skill("storm_live_wire", "Live Wire",
			"Shock dice apply +[color=yellow]1/2[/color] bonus [color=yellow]Static[/color] on use if target already has Static.",
			4, 0, _tier_pts(4), {1: [lw_r1], 2: [lw_r2]}),
		"storm_live_wire")

	# ── Arc Conduit (Col 2, Center) — chains hit +1 target, bounces apply Static ──
	var da_ac_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Conduit I: Extra Chain", "Chains hit +1 target. Bounces apply 1 Static.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 1.0,
			{"extra_chain_targets": 1, "chain_status": "static", "chain_stacks": 1}),
		"da_arc_conduit_r1")
	var ac_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Conduit I", "Shock dice chain to +1 extra target. Bounces apply 1 Static.",
			["mage", "storm", "mana_die_affix", "chain", "center", "static_apply"], da_ac_r1),
		"arc_conduit", "arc_conduit_r1_affix")

	var da_ac_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Conduit II: Extra Chain", "Chains hit +1 target. Bounces apply 2 Static.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 1.0,
			{"extra_chain_targets": 1, "chain_status": "static", "chain_stacks": 2}),
		"da_arc_conduit_r2")
	var ac_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Conduit II", "Shock dice chain to +1 extra target. Bounces apply 2 Static.",
			["mage", "storm", "mana_die_affix", "chain", "center", "static_apply"], da_ac_r2),
		"arc_conduit", "arc_conduit_r2_affix")

	_save_skill(
		_make_skill("storm_arc_conduit", "Arc Conduit",
			"Shock dice chain to +1 extra target. Chain bounces apply [color=yellow]1/2[/color] [color=yellow]Static[/color].",
			4, 2, _tier_pts(4), {1: [ac_r1], 2: [ac_r2]}),
		"storm_arc_conduit")

	# ── Voltaic Surge (Col 4, Center) — bonus damage per Static stack on target ──
	var da_vs_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Voltaic Surge I: Per-Stack Damage", "+1 damage per Static stack.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 1.0,
			{"per_stack_of": "static"},
			_cond_target_has_static),
		"da_voltaic_surge_r1")
	var vs_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Voltaic Surge I", "Shock dice deal +1 bonus damage per Static stack on target.",
			["mage", "storm", "mana_die_affix", "damage", "center", "scaling"], da_vs_r1),
		"voltaic_surge", "voltaic_surge_r1_affix")

	var da_vs_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Voltaic Surge II: Per-Stack Damage", "+2 damage per Static stack.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 2.0,
			{"per_stack_of": "static"},
			_cond_target_has_static),
		"da_voltaic_surge_r2")
	var vs_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Voltaic Surge II", "Shock dice deal +2 bonus damage per Static stack on target.",
			["mage", "storm", "mana_die_affix", "damage", "center", "scaling"], da_vs_r2),
		"voltaic_surge", "voltaic_surge_r2_affix")

	var da_vs_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Voltaic Surge III: Per-Stack Damage", "+3 damage per Static stack.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 3.0,
			{"per_stack_of": "static"},
			_cond_target_has_static),
		"da_voltaic_surge_r3")
	var vs_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Voltaic Surge III", "Shock dice deal +3 bonus damage per Static stack on target.",
			["mage", "storm", "mana_die_affix", "damage", "center", "scaling"], da_vs_r3),
		"voltaic_surge", "voltaic_surge_r3_affix")

	_save_skill(
		_make_skill("storm_voltaic_surge", "Voltaic Surge",
			"Shock dice deal +[color=yellow]1/2/3[/color] bonus damage per [color=yellow]Static[/color] stack on target.",
			4, 4, _tier_pts(4), {1: [vs_r1], 2: [vs_r2], 3: [vs_r3]}),
		"storm_voltaic_surge")

	# ── Mana Siphon (Col 6, Branch B) — mana on shock kill ──
	var ms_r1_mem: Affix = _make_affix("Mana Siphon I",
		"On shock kill: restore 4 mana.",
		Affix.Category.PROC, ["mage", "storm", "proc", "mana", "conduit", "kill"], 4.0,
		{"proc_trigger": "ON_KILL", "proc_condition_element": "SHOCK",
		"proc_effect": "mana_restore", "amount": 4})
	ms_r1_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var ms_r1: Affix = _save_affix(ms_r1_mem, "mana_siphon", "mana_siphon_r1_affix")

	var ms_r2_mem: Affix = _make_affix("Mana Siphon II",
		"On shock kill: restore 6 mana.",
		Affix.Category.PROC, ["mage", "storm", "proc", "mana", "conduit", "kill"], 6.0,
		{"proc_trigger": "ON_KILL", "proc_condition_element": "SHOCK",
		"proc_effect": "mana_restore", "amount": 6})
	ms_r2_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var ms_r2: Affix = _save_affix(ms_r2_mem, "mana_siphon", "mana_siphon_r2_affix")

	_save_skill(
		_make_skill("storm_mana_siphon", "Mana Siphon",
			"On shock kill: restore [color=yellow]4/6[/color] mana.",
			4, 6, _tier_pts(4), {1: [ms_r1], 2: [ms_r2]}),
		"storm_mana_siphon")


# ============================================================================
# TIER 5 — Storm Charge, Charged Cascade (Weave), Lightning Bolt (Action)
# ============================================================================

func _create_tier_5():
	print("\n-- Tier 5 -- 3 skills...")

	# ── Storm Charge (Col 0, Branch A) — splash Static at 8+ stacks threshold ──
	var sc_r1_mem: Affix = _make_affix("Storm Charge I",
		"Applying Static to target with 8+ stacks: splash 1 Static to all others.",
		Affix.Category.MISC, ["mage", "storm", "voltaic", "static_apply", "spread", "threshold"], 1.0,
		{"trigger": "ON_STATUS_APPLIED", "condition_status": "static",
		"condition_threshold": 8, "proc_effect": "splash_status_to_all_others",
		"status_id": "static", "stacks": 1})
	var sc_r1: Affix = _save_affix(sc_r1_mem, "storm_charge", "storm_charge_r1_affix")

	var sc_r2_mem: Affix = _make_affix("Storm Charge II",
		"Applying Static to target with 8+ stacks: splash 2 Static to all others.",
		Affix.Category.MISC, ["mage", "storm", "voltaic", "static_apply", "spread", "threshold"], 2.0,
		{"trigger": "ON_STATUS_APPLIED", "condition_status": "static",
		"condition_threshold": 8, "proc_effect": "splash_status_to_all_others",
		"status_id": "static", "stacks": 2})
	var sc_r2: Affix = _save_affix(sc_r2_mem, "storm_charge", "storm_charge_r2_affix")

	_save_skill(
		_make_skill("storm_storm_charge", "Storm Charge",
			"Applying [color=yellow]Static[/color] to target with 8+ stacks: splash [color=yellow]1/2[/color] Static to all other enemies.",
			5, 0, _tier_pts(5), {1: [sc_r1], 2: [sc_r2]}),
		"storm_storm_charge")

	# ── Charged Cascade (Col 3, Weave) — chain bounces deal bonus per Static ──
	var da_cc: DiceAffix = _save_dice_affix(
		_make_dice_affix("Charged Cascade: Chain Static Scaling",
			"Chain bounces deal +3 damage per Static stack on bounce target.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_BONUS_DAMAGE, 3.0,
			{"applies_to": "chain_bounces", "per_stack_of": "static"}),
		"da_charged_cascade")
	var cc_affix: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Charged Cascade",
			"Chain bounces deal +3 bonus damage per Static stack on bounce target.",
			["mage", "storm", "mana_die_affix", "weave", "chain", "scaling"], da_cc),
		"charged_cascade", "charged_cascade_r1_affix")

	_save_skill(
		_make_skill("storm_charged_cascade", "Charged Cascade",
			"[color=yellow]WEAVE:[/color] Chain bounces deal +3 bonus damage per [color=yellow]Static[/color] stack on bounce target.",
			5, 3, _tier_pts(5), {1: [cc_affix]}),
		"storm_charged_cascade")

	# ── Lightning Bolt (Col 5, Branch B) — ACTION: 2 dice, per-stack bonus ──
	var lb_dmg: ActionEffect = _save_effect(
		_make_action_effect("Lightning Bolt: Damage",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 0, 1.2, 2),
		"lightning_bolt_damage")

	var lb_static_bonus: ActionEffect = _save_effect(
		_make_action_effect("Lightning Bolt: Static Bonus",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 3, 1.0, 0),
		"lightning_bolt_static_bonus")
	lb_static_bonus.effect_data = {"condition": "target_has_status", "status_id": "static",
		"damage_per_stack": 3, "value_source": "TARGET_STATUS_STACKS"}
	ResourceSaver.save(lb_static_bonus, EFFECT_DIR + "lightning_bolt_static_bonus.tres")

	var lb_chain: ActionEffect = _save_effect(
		_make_action_effect("Lightning Bolt: Chain",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.CHAIN,
			ActionEffect.DamageType.SHOCK, 0, 0.5, 0),
		"lightning_bolt_chain")
	lb_chain.effect_data = {"chain_targets": 1, "chain_percent": 0.5}
	ResourceSaver.save(lb_chain, EFFECT_DIR + "lightning_bolt_chain.tres")

	var lb_effs: Array[ActionEffect] = []
	lb_effs.assign([lb_dmg, lb_static_bonus, lb_chain])
	var shock_only: Array[int] = [4]
	var lb_act: Action = _save_action(
		_make_action_with_elements("storm_lightning_bolt", "Lightning Bolt",
			"Deal x1.2 shock damage. +3 bonus damage per Static stack on target. Chain to 1 enemy for 50%.",
			2, lb_effs, shock_only, Action.ChargeType.LIMITED_PER_TURN, 1),
		"lightning_bolt_action")

	var lb_grant_mem: Affix = _make_affix("Lightning Bolt: Grant Action",
		"Grants Lightning Bolt action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "conduit", "granted_action", "exploiter"], 0.0,
		{"action_id": "storm_lightning_bolt"})
	lb_grant_mem.granted_action = lb_act
	var lb_grant: Affix = _save_affix(lb_grant_mem, "lightning_bolt", "lightning_bolt_r1_affix")

	_save_skill(
		_make_skill("storm_lightning_bolt", "Lightning Bolt",
			"[color=yellow]ACTION:[/color] 2 shock dice -> x1.2 damage + [color=yellow]3 per Static stack[/color]. Chain to 1 at 50%. Per turn.",
			5, 5, _tier_pts(5), {1: [lb_grant]}),
		"storm_lightning_bolt")


# ============================================================================
# TIER 6 — Thunderhead, Static Discharge
# ============================================================================

func _create_tier_6():
	print("\n-- Tier 6 -- 2 skills...")

	# ── Thunderhead (Col 1, Branch A) — turn start: Static to all enemies ──
	var th_r1_mem: Affix = _make_affix("Thunderhead I",
		"Turn start: apply 2 Static to all enemies.",
		Affix.Category.PER_TURN, ["mage", "storm", "voltaic", "static_apply", "aoe", "passive"], 2.0,
		{"turn_trigger": "START_OF_TURN",
		"proc_effect": "apply_status_to_all_enemies",
		"status_id": "static", "stacks": 2})
	var th_r1: Affix = _save_affix(th_r1_mem, "thunderhead", "thunderhead_r1_affix")

	var th_r2_mem: Affix = _make_affix("Thunderhead II",
		"Turn start: apply 3 Static to all enemies.",
		Affix.Category.PER_TURN, ["mage", "storm", "voltaic", "static_apply", "aoe", "passive"], 3.0,
		{"turn_trigger": "START_OF_TURN",
		"proc_effect": "apply_status_to_all_enemies",
		"status_id": "static", "stacks": 3})
	var th_r2: Affix = _save_affix(th_r2_mem, "thunderhead", "thunderhead_r2_affix")

	_save_skill(
		_make_skill("storm_thunderhead", "Thunderhead",
			"Turn start: apply [color=yellow]2/3[/color] [color=yellow]Static[/color] to all enemies.",
			6, 1, _tier_pts(6), {1: [th_r1], 2: [th_r2]}),
		"storm_thunderhead")

	# ── Static Discharge (Col 5, Branch B) — death propagation ──
	var sd_mem: Affix = _make_affix("Static Discharge",
		"When target with Static dies: deal remaining stacks as shock AoE, apply half as Static to all.",
		Affix.Category.PROC, ["mage", "storm", "conduit", "death", "aoe", "chain", "static_apply"], 0.0,
		{"proc_trigger": "ON_ENEMY_DEATH", "proc_condition_status": "static",
		"effects": [
			{"type": "aoe_damage", "damage_type": "SHOCK", "value_source": "DEAD_TARGET_STATUS_STACKS", "status_id": "static"},
			{"type": "apply_status_to_all", "status_id": "static", "stacks_source": "DEAD_TARGET_STATUS_STACKS_HALF"}
		]})
	sd_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var sd: Affix = _save_affix(sd_mem, "static_discharge", "static_discharge_r1_affix")

	_save_skill(
		_make_skill("storm_static_discharge", "Static Discharge",
			"When [color=yellow]Static[/color] target dies: deal remaining stacks as shock AoE, apply half as [color=yellow]Static[/color] to all.",
			6, 5, _tier_pts(6), {1: [sd]}),
		"storm_static_discharge")


# ============================================================================
# TIER 7 — Galvanic Renewal, Storm Surge (Signature Action)
# ============================================================================

func _create_tier_7():
	print("\n-- Tier 7 -- 2 skills...")

	# ── Galvanic Renewal (Col 2) — on shock kill: free shock die ──
	var gr_r1_mem: Affix = _make_affix("Galvanic Renewal I",
		"On shock kill: gain 1 free shock die to hand. Max 1/turn.",
		Affix.Category.PROC, ["mage", "storm", "proc", "kill", "die_generation"], 1.0,
		{"proc_trigger": "ON_KILL", "proc_condition_element": "SHOCK",
		"proc_effect": "add_die_to_hand", "die_element": "SHOCK", "count": 1, "max_per_turn": 1})
	gr_r1_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var gr_r1: Affix = _save_affix(gr_r1_mem, "galvanic_renewal", "galvanic_renewal_r1_affix")

	var gr_r2_mem: Affix = _make_affix("Galvanic Renewal II",
		"On shock kill: gain 2 free shock dice to hand. Max 1/turn.",
		Affix.Category.PROC, ["mage", "storm", "proc", "kill", "die_generation"], 2.0,
		{"proc_trigger": "ON_KILL", "proc_condition_element": "SHOCK",
		"proc_effect": "add_die_to_hand", "die_element": "SHOCK", "count": 2, "max_per_turn": 1})
	gr_r2_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var gr_r2: Affix = _save_affix(gr_r2_mem, "galvanic_renewal", "galvanic_renewal_r2_affix")

	_save_skill(
		_make_skill("storm_galvanic_renewal", "Galvanic Renewal",
			"On shock kill: gain [color=yellow]1/2[/color] free shock die to hand. Max 1 trigger/turn.",
			7, 2, _tier_pts(7), {1: [gr_r1], 2: [gr_r2]}),
		"storm_galvanic_renewal")

	# ── Storm Surge (Col 4, Signature) — 3 dice, AoE + Static + chain return ──
	var surge_dmg: ActionEffect = _save_effect(
		_make_action_effect("Storm Surge: AoE Damage",
			ActionEffect.TargetType.ALL_ENEMIES, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 0, 0.8, 3),
		"storm_surge_damage")

	var surge_static: ActionEffect = _save_effect(
		_make_action_effect("Storm Surge: Mass Static",
			ActionEffect.TargetType.ALL_ENEMIES, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK, 0, 1.0, 0, 0, 1.0, false,
			_static_status, 3),
		"storm_surge_static")

	var surge_chain: ActionEffect = _save_effect(
		_make_action_effect("Storm Surge: Chain Return",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.CHAIN,
			ActionEffect.DamageType.SHOCK, 0, 0.6, 0),
		"storm_surge_chain_return")
	surge_chain.effect_data = {"chain_targets": 1, "chain_percent": 0.6,
		"chain_return_to_primary": true}
	ResourceSaver.save(surge_chain, EFFECT_DIR + "storm_surge_chain_return.tres")

	var surge_effs: Array[ActionEffect] = []
	surge_effs.assign([surge_dmg, surge_static, surge_chain])
	var shock_only: Array[int] = [4]
	var surge_act: Action = _save_action(
		_make_action_with_elements("storm_storm_surge", "Storm Surge",
			"Deal x0.8 shock damage to ALL enemies. Apply 3 Static to all. Chain returns to primary for an extra hit.",
			3, surge_effs, shock_only, Action.ChargeType.LIMITED_PER_COMBAT, 1),
		"storm_surge_action")

	var surge_grant_mem: Affix = _make_affix("Storm Surge: Grant Action",
		"Grants Storm Surge action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "signature", "granted_action", "aoe", "ultimate"], 0.0,
		{"action_id": "storm_storm_surge"})
	surge_grant_mem.granted_action = surge_act
	var surge_grant: Affix = _save_affix(surge_grant_mem, "storm_surge", "storm_surge_r1_affix")

	_save_skill(
		_make_skill("storm_storm_surge", "Storm Surge",
			"[color=yellow]SIGNATURE:[/color] 3 shock dice -> x0.8 AoE shock + 3 [color=yellow]Static[/color] to all. Chain returns to primary. Per combat.",
			7, 4, _tier_pts(7), {1: [surge_grant]}),
		"storm_storm_surge")


# ============================================================================
# TIER 8 — Eye of the Storm (Capstone)
# ============================================================================

func _create_tier_8():
	print("\n-- Tier 8 -- 1 skill...")

	# ── Eye of the Storm (Col 3, Capstone) — triple-effect capstone ──
	# Effect 1: Double Static max stacks (20 -> 40)
	var eye_max_stacks: Affix = _save_affix(
		_make_affix("Eye of the Storm: Doubled Max Stacks",
			"Static max stacks doubled (20 -> 40).",
			Affix.Category.MISC,
			["mage", "storm", "capstone", "static_amplify"], 0.0,
			{"modify_status_max_stacks": "static", "multiplier": 2}),
		"eye_of_the_storm", "eye_max_stacks_affix")

	# Effect 2: Chain effects hit +1 additional target
	var da_eye_chain: DiceAffix = _save_dice_affix(
		_make_dice_affix("Eye of the Storm: Chain Extension",
			"All shock chain effects hit +1 additional target.",
			DiceAffix.Trigger.PASSIVE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 1.0,
			{"extra_chain_targets": 1, "applies_to": "all_chain_effects"}),
		"da_eye_chain_extension")
	var eye_chain: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Eye of the Storm: Chains",
			"All shock chain effects hit +1 additional target.",
			["mage", "storm", "capstone", "chain"], da_eye_chain),
		"eye_of_the_storm", "eye_chain_affix")

	# Effect 3: FIRST-position shock die applies 2 Static to all enemies
	var da_eye_first: DiceAffix = _save_dice_affix(
		_make_dice_affix("Eye of the Storm: First Strike",
			"First-position shock die applies 2 Static to all enemies.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 2, "target": "ALL_ENEMIES"},
			null, DiceAffix.PositionRequirement.FIRST),
		"da_eye_first_strike")
	var eye_first: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Eye of the Storm: First Strike",
			"Shock die in FIRST position applies 2 Static to all enemies on use.",
			["mage", "storm", "capstone", "static_apply", "aoe", "positional"], da_eye_first),
		"eye_of_the_storm", "eye_first_strike_affix")

	_save_skill(
		_make_skill("storm_eye_of_the_storm", "Eye of the Storm",
			"[color=yellow]CAPSTONE:[/color] [color=yellow]Static[/color] max stacks doubled (40). Chains +1 target. FIRST-position shock die applies 2 Static to all.",
			8, 3, _tier_pts(8), {1: [eye_max_stacks, eye_chain, eye_first]}),
		"storm_eye_of_the_storm")


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

	# TIER 2: all require Spark
	_add_prereq.call("storm_arc_pulse", "storm_spark")
	_add_prereq.call("storm_conductor", "storm_spark")
	_add_prereq.call("storm_galvanic_pulse", "storm_spark")

	# TIER 3
	_add_prereq.call("storm_ionize", "storm_arc_pulse")
	_add_prereq.call("storm_thunderclap", "storm_arc_pulse")
	_add_prereq.call("storm_storm_sprite", "storm_conductor")
	_add_prereq.call("storm_polarity", "storm_galvanic_pulse")

	# TIER 4
	_add_prereq.call("storm_live_wire", "storm_ionize")
	_add_prereq.call("storm_arc_conduit", "storm_conductor")
	_add_prereq.call("storm_voltaic_surge", "storm_conductor")
	_add_prereq.call("storm_mana_siphon", "storm_polarity")

	# TIER 5
	_add_prereq.call("storm_storm_charge", "storm_live_wire")
	# Charged Cascade — WEAVE: requires BOTH center T4 skills
	_add_prereq.call("storm_charged_cascade", "storm_arc_conduit")
	_add_prereq.call("storm_charged_cascade", "storm_voltaic_surge")
	_add_prereq.call("storm_lightning_bolt", "storm_mana_siphon")

	# TIER 6
	_add_prereq.call("storm_thunderhead", "storm_storm_charge")
	_add_prereq.call("storm_static_discharge", "storm_lightning_bolt")

	# TIER 7: both require Charged Cascade (weave) + their branch
	_add_prereq.call("storm_galvanic_renewal", "storm_thunderhead")
	_add_prereq.call("storm_galvanic_renewal", "storm_charged_cascade")
	_add_prereq.call("storm_storm_surge", "storm_static_discharge")
	_add_prereq.call("storm_storm_surge", "storm_charged_cascade")

	# TIER 8: Capstone requires BOTH T7 skills
	_add_prereq.call("storm_eye_of_the_storm", "storm_galvanic_renewal")
	_add_prereq.call("storm_eye_of_the_storm", "storm_storm_surge")

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
	tree.tree_id = "mage_storm"
	tree.tree_name = "Storm"
	tree.description = "Master shock magic. Three paths: Voltaic (Static application and control), Chain (damage chains and dice interactions), Tempest-Conduit (per-stack scaling, mana economy, kill-chain payoffs). Aggressive chain damage amplified by Static stacks."

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

	var tree_path: String = TREE_DIR + "mage_storm.tres"
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
