# res://editor_scripts/generate_storm_tree.gd
# Run via: Editor -> Script -> Run (Ctrl+Shift+X) with this script open.
#
# WHAT THIS DOES:
#   Creates the complete 35-skill Mage Storm skill tree:
#   - 35 SkillResource .tres files
#   - ~85 backing Affix .tres files
#   - ~15 DiceAffix .tres files
#   - ~10 DiceAffixCondition .tres files
#   - 6 Action .tres + ~15 ActionEffect .tres files
#   - 1 StatusAffix (static.tres)
#   - 1 CompanionData (storm_sprite.tres)
#   - ~40 SkillPrerequisite sub-resources
#   - 1 SkillTree (mage_storm.tres)
#
# SAFE TO RE-RUN: Overwrites existing files at the same paths.
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
const COMPANION_DIR   := "res://resources/companions/mage/storm/"
const TREE_DIR        := "res://resources/skill_trees/"

# Counters for summary
var _created_skills: int = 0
var _created_affixes: int = 0
var _created_dice_affixes: int = 0
var _created_conditions: int = 0
var _created_actions: int = 0
var _created_effects: int = 0
var _created_statuses: int = 0
var _created_companions: int = 0

# Skill lookup for prerequisite wiring (populated during creation)
var _skill_lookup: Dictionary = {}  # skill_id -> SkillResource

# Shared resources (created in _create_shared_resources, used across tiers)
var _static_status: StatusAffix
var _base_storm_sprite: CompanionData

var _cond_self_element_shock: DiceAffixCondition
var _cond_neighbor_shock: DiceAffixCondition
var _cond_neighbor_shock_inverted: DiceAffixCondition
var _cond_target_has_static: DiceAffixCondition

# ============================================================================
# ENTRY POINT
# ============================================================================

func _run() -> void:
	# --- DEBUG: Test class instantiation ---
	var test_affix: Affix = Affix.new()
	print("Affix.new() = %s" % test_affix)
	var test_skill: SkillResource = SkillResource.new()
	print("SkillResource.new() = %s" % test_skill)

	# --- DEBUG: Test enum values used by generator ---
	print("MANA_ELEMENT_UNLOCK = %d" % Affix.Category.MANA_ELEMENT_UNLOCK)
	print("MANA_SIZE_UNLOCK = %d" % Affix.Category.MANA_SIZE_UNLOCK)
	print("SHOCK_DAMAGE_BONUS = %d" % Affix.Category.SHOCK_DAMAGE_BONUS)
	print("MANA_DIE_AFFIX = %d" % Affix.Category.MANA_DIE_AFFIX)
	print("ELEMENTAL_DAMAGE_MULTIPLIER = %d" % Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER)
	print("STATUS_DAMAGE_MULTIPLIER = %d" % Affix.Category.STATUS_DAMAGE_MULTIPLIER)
	print("PROC = %d" % Affix.Category.PROC)
	print("MISC = %d" % Affix.Category.MISC)
	print("NEW_ACTION = %d" % Affix.Category.NEW_ACTION)
	print("CLASS_ACTION_EFFECT_ADD = %d" % Affix.Category.CLASS_ACTION_EFFECT_ADD)
	print("CLASS_ACTION_STAT_MOD = %d" % Affix.Category.CLASS_ACTION_STAT_MOD)
	print("CLASS_ACTION_CONDITIONAL = %d" % Affix.Category.CLASS_ACTION_CONDITIONAL)
	print("--- enum test done ---")

	print("\n" + "=".repeat(60))
	print("  GENERATING MAGE STORM TREE (35 SKILLS)")
	print("=".repeat(60))

	_ensure_all_dirs()

	# Phase 1: Shared resources (status, conditions, base companion)
	_create_shared_resources()

	# Phase 2: Tiers 1-4 + Conjure Storm Sprite (15 skills)
	_create_tier_1()
	_create_tier_2()
	_create_tier_3()
	_create_tier_4()

	# Phase 3: Tiers 5-7 + Sprite upgrades (13 skills)
	_create_tier_5()
	_create_tier_6()
	_create_tier_7()

	# Phase 4: Tiers 8-10 + wiring + assembly (7 skills)
	_create_tier_8()
	_create_tier_9()
	_create_tier_10()

	# Wire prerequisites (all 35 skills exist now)
	_wire_prerequisites()

	# Build the SkillTree resource
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
	print("  Statuses:       %d" % _created_statuses)
	print("  Companions:     %d" % _created_companions)
	print("=".repeat(60))


# ============================================================================
# DIRECTORY HELPERS
# ============================================================================

func _ensure_all_dirs():
	for dir in [BASE_AFFIX_DIR, BASE_SKILL_DIR, DICE_AFFIX_DIR, CONDITION_DIR,
				ACTION_DIR, EFFECT_DIR, STATUS_DIR, COMPANION_DIR, TREE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)

func _ensure_sub_dir(base: String, sub: String) -> String:
	var path: String = base + sub + "/"
	DirAccess.make_dir_recursive_absolute(path)
	return path


# ============================================================================
# RESOURCE CREATION HELPERS
# ============================================================================

func _save(resource: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(resource, path)
	if err != OK:
		print("  SAVE FAILED: %s (error %d)" % [path, err])
	else:
		print("  saved: %s" % path)


# --- Affix (item-level) ---

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
	# Convert untyped Array to Array[String] for tags
	var typed_tags: Array[String] = []
	typed_tags.assign(p_tags)
	a.tags = typed_tags
	_created_affixes += 1
	return a

func _save_affix(affix: Affix, skill_folder: String, filename: String) -> Affix:
	var dir: String = _ensure_sub_dir(BASE_AFFIX_DIR, skill_folder)
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
	_created_dice_affixes += 1
	return da


# --- DiceAffixCondition ---

func _make_condition(p_type: int, p_threshold: float = 0.0,
		p_invert: bool = false, p_element: String = "",
		p_status_id: String = "") -> DiceAffixCondition:
	var c: DiceAffixCondition = DiceAffixCondition.new()
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
	var a: Affix = _make_affix(p_name, p_desc, Affix.Category.MANA_DIE_AFFIX, p_tags)
	a.effect_data = {"dice_affix": p_dice_affix}
	return a


# --- Action + ActionEffect ---

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
	_created_effects += 1
	return e

func _make_chain_effect(p_name: String, p_target: int,
		p_chain_count: int, p_chain_decay: float,
		p_damage_type: int = ActionEffect.DamageType.SHOCK) -> ActionEffect:
	"""Convenience helper for CHAIN-type ActionEffects."""
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = p_name
	e.target = p_target
	e.effect_type = ActionEffect.EffectType.CHAIN
	e.damage_type = p_damage_type
	e.chain_count = p_chain_count
	e.chain_decay = p_chain_decay
	e.chain_can_repeat = false
	_created_effects += 1
	return e

func _make_summon_effect(p_name: String, p_companion: CompanionData) -> ActionEffect:
	"""Convenience helper for SUMMON_COMPANION-type ActionEffects."""
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = p_name
	e.target = ActionEffect.TargetType.SELF
	e.effect_type = ActionEffect.EffectType.SUMMON_COMPANION
	e.companion_data = p_companion
	_created_effects += 1
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
	_created_actions += 1
	return act

func _make_action_with_elements(p_id: String, p_name: String, p_desc: String,
		p_die_slots: int, p_effects: Array[ActionEffect],
		p_accepted_elements: Array[int],
		p_charge_type: int = Action.ChargeType.UNLIMITED,
		p_max_charges: int = 1) -> Action:
	"""Action that only accepts specific element dice."""
	var act: Action = _make_action(p_id, p_name, p_desc, p_die_slots,
		p_effects, p_charge_type, p_max_charges)
	act.accepted_elements.assign(p_accepted_elements)
	# _make_action already incremented the counter, so undo double-count
	_created_actions -= 1
	return act

func _save_action(action: Action, filename: String) -> Action:
	_save(action, ACTION_DIR + filename + ".tres")
	return action

func _save_effect(effect: ActionEffect, filename: String) -> ActionEffect:
	_save(effect, EFFECT_DIR + filename + ".tres")
	return effect


# --- SkillResource ---

func _make_skill(p_id: String, p_name: String, p_desc: String,
		p_tier: int, p_col: int, p_tree_pts: int,
		p_rank_affixes: Dictionary = {},
		p_cost: int = 1) -> SkillResource:
	"""Create a SkillResource.
	p_rank_affixes: {1: [Affix, ...], 2: [...], ...}
	"""
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
# SHARED RESOURCES: Status, Conditions, Base Companion
# ============================================================================

func _create_shared_resources():
	print("\n-- Creating shared resources (Static status, conditions, base sprite)...")

	# ── Static StatusAffix ──
	# NOTE: Static uses a custom rolling-batch system at runtime.
	# The StatusAffix .tres stores the base definition; the custom batch
	# tracking is handled by a runtime extension in StatusTracker.
	# We use STACK_BASED with DECAY_NONE because batches are managed
	# by custom code, not the standard decay pipeline.
	_static_status = StatusAffix.new()
	_static_status.status_id = "static"
	_static_status.affix_name = "Static"
	_static_status.description = "+1 shock damage received per stack. Batches expire independently after 2 turns."
	_static_status.category = Affix.Category.MISC
	_static_status.duration_type = StatusAffix.DurationType.STACK_BASED
	_static_status.max_stacks = 20
	_static_status.decay_style = StatusAffix.DecayStyle.NONE
	_static_status.tick_timing = StatusAffix.TickTiming.START_OF_TURN
	_static_status.damage_per_stack = 0  # No tick damage; bonus is +damage RECEIVED
	_static_status.is_debuff = true
	_static_status.can_be_cleansed = true
	var static_cleanse: Array[String] = []
	static_cleanse.assign(["debuff", "shock", "static"])
	_static_status.cleanse_tags = static_cleanse
	_static_status.has_elemental_identity = true
	_static_status.elemental_identity = ActionEffect.DamageType.SHOCK
	# Custom field for runtime: stat_modifier_per_stack
	_static_status.stat_modifier_per_stack = {"shock_damage_received_bonus": 1}
	_static_status.effect_data = {"batch_duration": 2, "custom_tracker": "rolling_batch"}
	_save(_static_status, STATUS_DIR + "static.tres")
	_created_statuses += 1
	print("  Static StatusAffix created")

	# ── Shared DiceAffixConditions ──
	print("  Creating shared DiceAffixConditions...")

	# Self element is Shock (used by Arc Pulse, Live Wire, Dynamo, etc.)
	_cond_self_element_shock = _make_condition(
		DiceAffixCondition.Type.SELF_ELEMENT_IS, 0.0, false, "SHOCK")
	_save(_cond_self_element_shock, CONDITION_DIR + "cond_self_element_shock.tres")

	# Neighbor has Shock element (used for clustering detection if needed)
	_cond_neighbor_shock = _make_condition(
		DiceAffixCondition.Type.NEIGHBOR_HAS_ELEMENT, 0.0, false, "SHOCK")
	_save(_cond_neighbor_shock, CONDITION_DIR + "cond_neighbor_shock.tres")

	# Neighbor does NOT have Shock element (used by Polarity - inverted)
	_cond_neighbor_shock_inverted = _make_condition(
		DiceAffixCondition.Type.NEIGHBOR_HAS_ELEMENT, 0.0, true, "SHOCK")
	_save(_cond_neighbor_shock_inverted, CONDITION_DIR + "cond_neighbor_not_shock.tres")

	# Target has Static status (used by Live Wire, Grounded Circuit, etc.)
	_cond_target_has_static = _make_condition(
		DiceAffixCondition.Type.TARGET_HAS_STATUS, 0.0, false, "", "static")
	_save(_cond_target_has_static, CONDITION_DIR + "cond_target_has_static.tres")

	print("  4 DiceAffixConditions created")

	# ── Base Storm Sprite CompanionData ──
	# This is the unmodified template. Sprite upgrade affixes modify a
	# duplicate of this at summon-time via tagged affixes.
	print("  Creating base Storm Sprite CompanionData...")
	_base_storm_sprite = CompanionData.new()
	_base_storm_sprite.companion_id = &"storm_sprite"
	_base_storm_sprite.companion_name = "Storm Sprite"
	_base_storm_sprite.description = "A crackling orb of lightning that zaps a random enemy each turn."
	_base_storm_sprite.companion_type = CompanionData.CompanionType.SUMMON
	_base_storm_sprite.base_max_hp = 15
	_base_storm_sprite.hp_scaling = CompanionData.HPScaling.PLAYER_LEVEL
	_base_storm_sprite.hp_scaling_value = 2.0
	_base_storm_sprite.trigger = CompanionData.CompanionTrigger.PLAYER_TURN_END
	_base_storm_sprite.target_rule = CompanionData.CompanionTarget.RANDOM_ENEMY
	_base_storm_sprite.cooldown_turns = 0
	_base_storm_sprite.uses_per_combat = 0  # unlimited triggers
	_base_storm_sprite.fires_on_first_turn = true
	_base_storm_sprite.has_taunt = false
	_base_storm_sprite.duration_turns = 0  # lasts entire combat

	# Base action: small shock damage to random enemy
	var sprite_zap: ActionEffect = _make_action_effect(
		"Sprite: Zap",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.SHOCK,
		4, 1.0, 0)  # 4 base damage, no dice
	_save_effect(sprite_zap, "sprite_zap_effect")

	var sprite_effects: Array[ActionEffect] = []
	sprite_effects.assign([sprite_zap])
	_base_storm_sprite.action_effects = sprite_effects

	_save(_base_storm_sprite, COMPANION_DIR + "storm_sprite.tres")
	_created_companions += 1
	print("  Base Storm Sprite CompanionData created")

	print("  Shared resources complete\n")


# ============================================================================
# TIER STUBS — Replaced by Phases 2, 3, 4
# ============================================================================

func _create_tier_1():
	print("\n-- Tier 1 -- Spark (1 skill)...")

	# ── Spark (Col 3): Unlock Shock + D4. Chromatic Bolt applies 1/2/3 Static. 3 ranks. ──
	# Each rank carries: element unlock + size unlock + class action mod (escalating stacks)
	var spark_elem := _make_affix("Spark: Shock Unlock",
		"Unlocks Shock mana element.",
		Affix.Category.MANA_ELEMENT_UNLOCK,
		["mage", "storm", "element_unlock"], 0.0,
		{"element": "SHOCK"})
	_save_affix(spark_elem, "spark", "spark_element_unlock")

	var spark_size := _make_affix("Spark: D4 Unlock",
		"Unlocks D4 shock mana die.",
		Affix.Category.MANA_SIZE_UNLOCK,
		["mage", "storm", "size_unlock"], 0.0,
		{"die_size": 4})
	_save_affix(spark_size, "spark", "spark_size_unlock")

	# CLASS_ACTION_EFFECT_ADD: append Static application to Chromatic Bolt.
	# The ActionEffect is conditional on shock die being used (runtime check via effect_data).
	var spark_static_r1: ActionEffect = _make_action_effect(
		"Spark: Apply Static I",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.SHOCK,
		0, 1.0, 0,  # no base damage, no dice
		0, 1.0, false,  # no heal
		_static_status, 1)  # 1 stack
	_save_effect(spark_static_r1, "spark_apply_static_r1")

	var spark_ca_r1 := _make_affix("Spark: Chromatic Bolt Static I",
		"Chromatic Bolt applies 1 Static (shock die).",
		Affix.Category.CLASS_ACTION_EFFECT_ADD,
		["mage", "storm", "class_action_mod", "static_apply"], 0.0,
		{"action_effect": spark_static_r1, "shock_die_condition": true})
	_save_affix(spark_ca_r1, "spark", "spark_ca_r1_affix")

	var spark_static_r2: ActionEffect = _make_action_effect(
		"Spark: Apply Static II",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.SHOCK,
		0, 1.0, 0, 0, 1.0, false,
		_static_status, 2)
	_save_effect(spark_static_r2, "spark_apply_static_r2")

	var spark_ca_r2 := _make_affix("Spark: Chromatic Bolt Static II",
		"Chromatic Bolt applies 2 Static (shock die).",
		Affix.Category.CLASS_ACTION_EFFECT_ADD,
		["mage", "storm", "class_action_mod", "static_apply"], 0.0,
		{"action_effect": spark_static_r2, "shock_die_condition": true})
	_save_affix(spark_ca_r2, "spark", "spark_ca_r2_affix")

	var spark_static_r3: ActionEffect = _make_action_effect(
		"Spark: Apply Static III",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.SHOCK,
		0, 1.0, 0, 0, 1.0, false,
		_static_status, 3)
	_save_effect(spark_static_r3, "spark_apply_static_r3")

	var spark_ca_r3 := _make_affix("Spark: Chromatic Bolt Static III",
		"Chromatic Bolt applies 3 Static (shock die).",
		Affix.Category.CLASS_ACTION_EFFECT_ADD,
		["mage", "storm", "class_action_mod", "static_apply"], 0.0,
		{"action_effect": spark_static_r3, "shock_die_condition": true})
	_save_affix(spark_ca_r3, "spark", "spark_ca_r3_affix")

	var spark := _make_skill(
		"storm_spark", "Spark",
		"Unlock [color=yellow]Shock[/color] mana. Chromatic Bolt applies [color=yellow]1/2/3[/color] [color=cyan]Static[/color] on hit (requires shock die).",
		1, 3, _tier_pts(1),
		{1: [spark_elem, spark_size, spark_ca_r1],
		 2: [spark_elem, spark_size, spark_ca_r2],
		 3: [spark_elem, spark_size, spark_ca_r3]})
	_save_skill(spark, "storm_spark")

func _create_tier_2():
	print("\n-- Tier 2 -- 3 skills (Arc Pulse, Crackling Force, Capacitance)...")

	# ── Arc Pulse (Col 1, Voltaic): Shock mana dice apply 1/2/3 Static on use. 3 ranks. ──
	var da_arc_r1: DiceAffix = _make_dice_affix(
		"Arc Pulse I: Static on Use", "Apply 1 Static on use.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
		{"status_id": "static", "stacks": 1},
		_cond_self_element_shock)
	_save(da_arc_r1, DICE_AFFIX_DIR + "da_arc_pulse_r1.tres")

	var ap_r1: Affix = _make_mana_die_affix_wrapper(
		"Arc Pulse I", "Shock dice apply 1 Static on use.",
		["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_arc_r1)
	_save_affix(ap_r1, "arc_pulse", "arc_pulse_r1_affix")

	var da_arc_r2: DiceAffix = _make_dice_affix(
		"Arc Pulse II: Static on Use", "Apply 2 Static on use.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
		{"status_id": "static", "stacks": 2},
		_cond_self_element_shock)
	_save(da_arc_r2, DICE_AFFIX_DIR + "da_arc_pulse_r2.tres")

	var ap_r2: Affix = _make_mana_die_affix_wrapper(
		"Arc Pulse II", "Shock dice apply 2 Static on use.",
		["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_arc_r2)
	_save_affix(ap_r2, "arc_pulse", "arc_pulse_r2_affix")

	var da_arc_r3: DiceAffix = _make_dice_affix(
		"Arc Pulse III: Static on Use", "Apply 3 Static on use.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
		{"status_id": "static", "stacks": 3},
		_cond_self_element_shock)
	_save(da_arc_r3, DICE_AFFIX_DIR + "da_arc_pulse_r3.tres")

	var ap_r3: Affix = _make_mana_die_affix_wrapper(
		"Arc Pulse III", "Shock dice apply 3 Static on use.",
		["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_arc_r3)
	_save_affix(ap_r3, "arc_pulse", "arc_pulse_r3_affix")

	var arc_pulse := _make_skill(
		"storm_arc_pulse", "Arc Pulse",
		"Shock mana dice apply [color=yellow]1/2/3[/color] [color=cyan]Static[/color] on use.",
		2, 1, _tier_pts(2),
		{1: [ap_r1], 2: [ap_r2], 3: [ap_r3]})
	_save_skill(arc_pulse, "storm_arc_pulse")

	# ── Crackling Force (Col 3, Tempest): Shock damage x1.05/x1.10/x1.15. 3 ranks. ──
	var cf_r1: Affix = _make_affix("Crackling Force I", "Shock damage x1.05.",
		Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
		["mage", "storm", "shock_mult", "tempest"], 1.05,
		{"element": "SHOCK"})
	_save_affix(cf_r1, "crackling_force", "crackling_force_r1_affix")

	var cf_r2: Affix = _make_affix("Crackling Force II", "Shock damage x1.10.",
		Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
		["mage", "storm", "shock_mult", "tempest"], 1.10,
		{"element": "SHOCK"})
	_save_affix(cf_r2, "crackling_force", "crackling_force_r2_affix")

	var cf_r3: Affix = _make_affix("Crackling Force III", "Shock damage x1.15.",
		Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
		["mage", "storm", "shock_mult", "tempest"], 1.15,
		{"element": "SHOCK"})
	_save_affix(cf_r3, "crackling_force", "crackling_force_r3_affix")

	var crackling_force := _make_skill(
		"storm_crackling_force", "Crackling Force",
		"Shock damage x[color=yellow]1.05/1.10/1.15[/color].",
		2, 3, _tier_pts(2),
		{1: [cf_r1], 2: [cf_r2], 3: [cf_r3]})
	_save_skill(crackling_force, "storm_crackling_force")

	# ── Capacitance (Col 5, Conduit): +2/+4/+6 Intellect. 3 ranks. ──
	var cap_r1: Affix = _make_affix("Capacitance I", "+2 Intellect.",
		Affix.Category.INTELLECT_BONUS,
		["mage", "storm", "conduit", "stat"], 2.0)
	_save_affix(cap_r1, "capacitance", "capacitance_r1_affix")

	var cap_r2: Affix = _make_affix("Capacitance II", "+4 Intellect.",
		Affix.Category.INTELLECT_BONUS,
		["mage", "storm", "conduit", "stat"], 4.0)
	_save_affix(cap_r2, "capacitance", "capacitance_r2_affix")

	var cap_r3: Affix = _make_affix("Capacitance III", "+6 Intellect.",
		Affix.Category.INTELLECT_BONUS,
		["mage", "storm", "conduit", "stat"], 6.0)
	_save_affix(cap_r3, "capacitance", "capacitance_r3_affix")

	var capacitance := _make_skill(
		"storm_capacitance", "Capacitance",
		"+[color=yellow]2/4/6[/color] Intellect.",
		2, 5, _tier_pts(2),
		{1: [cap_r1], 2: [cap_r2], 3: [cap_r3]})
	_save_skill(capacitance, "storm_capacitance")

func _create_tier_3():
	print("\n-- Tier 3 -- 5 skills (Ionize, Charged Strikes, Conjure Storm Sprite, Surge Efficiency, Polarity)...")

	# ── Ionize (Col 0, Voltaic): Pulling shock mana die applies 1/2/3 Static to random enemy. 3 ranks. ──
	# NOTE: ON_MANA_PULL proc trigger does not exist in ProcTrigger enum yet.
	# Using PROC category with effect_data describing the behavior for runtime implementation.
	var ion_r1: Affix = _make_affix("Ionize I", "Pulling shock die applies 1 Static.",
		Affix.Category.PROC,
		["mage", "storm", "voltaic", "static_apply", "on_pull"], 1.0,
		{"proc_trigger": "ON_MANA_PULL", "proc_effect": "apply_status",
		 "status_id": "static", "stacks": 1, "target": "random_enemy",
		 "element_condition": "SHOCK"})
	_save_affix(ion_r1, "ionize", "ionize_r1_affix")

	var ion_r2: Affix = _make_affix("Ionize II", "Pulling shock die applies 2 Static.",
		Affix.Category.PROC,
		["mage", "storm", "voltaic", "static_apply", "on_pull"], 1.0,
		{"proc_trigger": "ON_MANA_PULL", "proc_effect": "apply_status",
		 "status_id": "static", "stacks": 2, "target": "random_enemy",
		 "element_condition": "SHOCK"})
	_save_affix(ion_r2, "ionize", "ionize_r2_affix")

	var ion_r3: Affix = _make_affix("Ionize III", "Pulling shock die applies 3 Static.",
		Affix.Category.PROC,
		["mage", "storm", "voltaic", "static_apply", "on_pull"], 1.0,
		{"proc_trigger": "ON_MANA_PULL", "proc_effect": "apply_status",
		 "status_id": "static", "stacks": 3, "target": "random_enemy",
		 "element_condition": "SHOCK"})
	_save_affix(ion_r3, "ionize", "ionize_r3_affix")

	var ionize := _make_skill(
		"storm_ionize", "Ionize",
		"Pulling a shock mana die applies [color=yellow]1/2/3[/color] [color=cyan]Static[/color] to a random enemy.",
		3, 0, _tier_pts(3),
		{1: [ion_r1], 2: [ion_r2], 3: [ion_r3]})
	_save_skill(ionize, "storm_ionize")

	# ── Charged Strikes (Col 2, Tempest): +2/+4/+6 flat shock damage. 3 ranks. ──
	var cs_r1: Affix = _make_affix("Charged Strikes I", "+2 shock damage.",
		Affix.Category.SHOCK_DAMAGE_BONUS,
		["mage", "storm", "tempest", "shock_flat"], 2.0)
	_save_affix(cs_r1, "charged_strikes", "charged_strikes_r1_affix")

	var cs_r2: Affix = _make_affix("Charged Strikes II", "+4 shock damage.",
		Affix.Category.SHOCK_DAMAGE_BONUS,
		["mage", "storm", "tempest", "shock_flat"], 4.0)
	_save_affix(cs_r2, "charged_strikes", "charged_strikes_r2_affix")

	var cs_r3: Affix = _make_affix("Charged Strikes III", "+6 shock damage.",
		Affix.Category.SHOCK_DAMAGE_BONUS,
		["mage", "storm", "tempest", "shock_flat"], 6.0)
	_save_affix(cs_r3, "charged_strikes", "charged_strikes_r3_affix")

	var charged_strikes := _make_skill(
		"storm_charged_strikes", "Charged Strikes",
		"+[color=yellow]2/4/6[/color] flat shock damage.",
		3, 2, _tier_pts(3),
		{1: [cs_r1], 2: [cs_r2], 3: [cs_r3]})
	_save_skill(charged_strikes, "storm_charged_strikes")

	# ── Conjure Storm Sprite (Col 3, Central): ACTION — 1 shock die, summon sprite. 1 rank. ──
	# NOTE: Requires SUMMON_COMPANION ActionEffect.EffectType to be added to action_effect.gd.
	var summon_eff: ActionEffect = _make_summon_effect(
		"Conjure: Summon Storm Sprite", _base_storm_sprite)
	_save_effect(summon_eff, "conjure_storm_sprite_effect")

	# accepted_elements: SHOCK = 6 in DieResource.Element (offset +1 from DamageType.SHOCK=5)
	var shock_only: Array[int] = [6]
	var sprite_effects: Array[ActionEffect] = []
	sprite_effects.assign([summon_eff])
	var sprite_act: Action = _make_action_with_elements(
		"storm_conjure_storm_sprite", "Conjure Storm Sprite",
		"Summon a Storm Sprite that zaps enemies each turn.",
		1, sprite_effects, shock_only,
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(sprite_act, "conjure_storm_sprite_action")

	var sprite_grant: Affix = _make_affix("Conjure Storm Sprite: Grant",
		"Grants Conjure Storm Sprite action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "granted_action", "summon"], 0.0,
		{"action_id": "storm_conjure_storm_sprite"})
	sprite_grant.granted_action = sprite_act
	_save_affix(sprite_grant, "conjure_storm_sprite", "conjure_storm_sprite_r1_affix")

	var conjure_storm_sprite := _make_skill(
		"storm_conjure_storm_sprite", "Conjure Storm Sprite",
		"[color=yellow]ACTION:[/color] 1 shock die -> summon a [color=cyan]Storm Sprite[/color]. Deals small shock damage each turn.",
		3, 3, _tier_pts(3),
		{1: [sprite_grant]})
	_save_skill(conjure_storm_sprite, "storm_conjure_storm_sprite")

	# ── Surge Efficiency (Col 4, Conduit): Shock mana pull cost -1/-2/-3. 3 ranks. ──
	var se_r1: Affix = _make_affix("Surge Efficiency I", "Shock pull cost -1.",
		Affix.Category.MISC,
		["mage", "storm", "conduit", "mana_pull_cost_reduction"], 1.0,
		{"element": "SHOCK"})
	_save_affix(se_r1, "surge_efficiency", "surge_efficiency_r1_affix")

	var se_r2: Affix = _make_affix("Surge Efficiency II", "Shock pull cost -2.",
		Affix.Category.MISC,
		["mage", "storm", "conduit", "mana_pull_cost_reduction"], 2.0,
		{"element": "SHOCK"})
	_save_affix(se_r2, "surge_efficiency", "surge_efficiency_r2_affix")

	var se_r3: Affix = _make_affix("Surge Efficiency III", "Shock pull cost -3.",
		Affix.Category.MISC,
		["mage", "storm", "conduit", "mana_pull_cost_reduction"], 3.0,
		{"element": "SHOCK"})
	_save_affix(se_r3, "surge_efficiency", "surge_efficiency_r3_affix")

	var surge_efficiency := _make_skill(
		"storm_surge_efficiency", "Surge Efficiency",
		"Shock mana die pull cost -[color=yellow]1/2/3[/color].",
		3, 4, _tier_pts(3),
		{1: [se_r1], 2: [se_r2], 3: [se_r3]})
	_save_skill(surge_efficiency, "storm_surge_efficiency")

	# ── Polarity (Col 6, Conduit): Shock dice +1/+2/+3 value if no adjacent shock die. 3 ranks. ──
	# Uses _cond_neighbor_shock_inverted: passes when NO adjacent die is shock.
	var da_polar_r1: DiceAffix = _make_dice_affix(
		"Polarity I: Spacing Bonus", "+1 if no adjacent shock die.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0, {},
		_cond_neighbor_shock_inverted)
	_save(da_polar_r1, DICE_AFFIX_DIR + "da_polarity_r1.tres")

	var pol_r1: Affix = _make_mana_die_affix_wrapper(
		"Polarity I", "+1 value if no adjacent shock die.",
		["mage", "storm", "conduit", "mana_die_affix", "positional", "spacing"], da_polar_r1)
	_save_affix(pol_r1, "polarity", "polarity_r1_affix")

	var da_polar_r2: DiceAffix = _make_dice_affix(
		"Polarity II: Spacing Bonus", "+2 if no adjacent shock die.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0, {},
		_cond_neighbor_shock_inverted)
	_save(da_polar_r2, DICE_AFFIX_DIR + "da_polarity_r2.tres")

	var pol_r2: Affix = _make_mana_die_affix_wrapper(
		"Polarity II", "+2 value if no adjacent shock die.",
		["mage", "storm", "conduit", "mana_die_affix", "positional", "spacing"], da_polar_r2)
	_save_affix(pol_r2, "polarity", "polarity_r2_affix")

	var da_polar_r3: DiceAffix = _make_dice_affix(
		"Polarity III: Spacing Bonus", "+3 if no adjacent shock die.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 3.0, {},
		_cond_neighbor_shock_inverted)
	_save(da_polar_r3, DICE_AFFIX_DIR + "da_polarity_r3.tres")

	var pol_r3: Affix = _make_mana_die_affix_wrapper(
		"Polarity III", "+3 value if no adjacent shock die.",
		["mage", "storm", "conduit", "mana_die_affix", "positional", "spacing"], da_polar_r3)
	_save_affix(pol_r3, "polarity", "polarity_r3_affix")

	var polarity := _make_skill(
		"storm_polarity", "Polarity",
		"Shock dice gain +[color=yellow]1/2/3[/color] value if no adjacent die is also Shock.",
		3, 6, _tier_pts(3),
		{1: [pol_r1], 2: [pol_r2], 3: [pol_r3]})
	_save_skill(polarity, "storm_polarity")

func _create_tier_4():
	print("\n-- Tier 4 -- 5 skills (Static Cling, Live Wire, Thunderclap, Voltaic Surge, Mana Siphon)...")

	# ── Static Cling (Col 0, Voltaic): Static batch duration +1/+2/+3 turns. 3 ranks. ──
	var sc_r1: Affix = _make_affix("Static Cling I", "Static duration +1 turn.",
		Affix.Category.MISC,
		["mage", "storm", "voltaic", "static_duration"], 1.0,
		{"static_duration_bonus": 1})
	_save_affix(sc_r1, "static_cling", "static_cling_r1_affix")

	var sc_r2: Affix = _make_affix("Static Cling II", "Static duration +2 turns.",
		Affix.Category.MISC,
		["mage", "storm", "voltaic", "static_duration"], 2.0,
		{"static_duration_bonus": 2})
	_save_affix(sc_r2, "static_cling", "static_cling_r2_affix")

	var sc_r3: Affix = _make_affix("Static Cling III", "Static duration +3 turns.",
		Affix.Category.MISC,
		["mage", "storm", "voltaic", "static_duration"], 3.0,
		{"static_duration_bonus": 3})
	_save_affix(sc_r3, "static_cling", "static_cling_r3_affix")

	var static_cling := _make_skill(
		"storm_static_cling", "Static Cling",
		"Static batch duration extended to [color=yellow]3/4/5[/color] turns.",
		4, 0, _tier_pts(4),
		{1: [sc_r1], 2: [sc_r2], 3: [sc_r3]})
	_save_skill(static_cling, "storm_static_cling")

	# ── Live Wire (Col 1, Voltaic): Shock dice apply +1/+2 bonus Static if target has Static. 2 ranks. ──
	var da_lw_r1: DiceAffix = _make_dice_affix(
		"Live Wire I: Bonus Static", "+1 Static if target has Static.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
		{"status_id": "static", "stacks": 1},
		_cond_target_has_static)
	# Also needs shock element check — add as secondary validation in effect_data
	da_lw_r1.effect_data["element_condition"] = "SHOCK"
	_save(da_lw_r1, DICE_AFFIX_DIR + "da_live_wire_r1.tres")

	var lw_r1: Affix = _make_mana_die_affix_wrapper(
		"Live Wire I", "+1 bonus Static if target already has Static.",
		["mage", "storm", "voltaic", "mana_die_affix", "static_apply", "snowball"], da_lw_r1)
	_save_affix(lw_r1, "live_wire", "live_wire_r1_affix")

	var da_lw_r2: DiceAffix = _make_dice_affix(
		"Live Wire II: Bonus Static", "+2 Static if target has Static.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
		{"status_id": "static", "stacks": 2, "element_condition": "SHOCK"},
		_cond_target_has_static)
	_save(da_lw_r2, DICE_AFFIX_DIR + "da_live_wire_r2.tres")

	var lw_r2: Affix = _make_mana_die_affix_wrapper(
		"Live Wire II", "+2 bonus Static if target already has Static.",
		["mage", "storm", "voltaic", "mana_die_affix", "static_apply", "snowball"], da_lw_r2)
	_save_affix(lw_r2, "live_wire", "live_wire_r2_affix")

	var live_wire := _make_skill(
		"storm_live_wire", "Live Wire",
		"Shock mana dice apply [color=yellow]1/2[/color] bonus [color=cyan]Static[/color] on use if target already has Static.",
		4, 1, _tier_pts(4),
		{1: [lw_r1], 2: [lw_r2]})
	_save_skill(live_wire, "storm_live_wire")

	# ── Thunderclap (Col 2, Tempest): ACTION — 2 shock dice, x1.2, applies 3 Static. 1 rank. ──
	var tc_dmg: ActionEffect = _make_action_effect(
		"Thunderclap: Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.SHOCK,
		0, 1.2, 2)  # x1.2 mult, 2 dice
	_save_effect(tc_dmg, "thunderclap_damage")

	var tc_status: ActionEffect = _make_action_effect(
		"Thunderclap: Apply Static",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.SHOCK,
		0, 1.0, 0, 0, 1.0, false,
		_static_status, 3)  # 3 stacks
	_save_effect(tc_status, "thunderclap_static")

	var tc_effects: Array[ActionEffect] = []
	tc_effects.assign([tc_dmg, tc_status])
	var shock_only: Array[int] = [6]  # DieResource.Element.SHOCK
	var tc_act: Action = _make_action_with_elements(
		"storm_thunderclap", "Thunderclap",
		"Shock strike for x1.2 damage and apply 3 Static.",
		2, tc_effects, shock_only,
		Action.ChargeType.LIMITED_PER_TURN, 1)
	_save_action(tc_act, "thunderclap_action")

	var tc_grant: Affix = _make_affix("Thunderclap: Grant Action",
		"Grants Thunderclap action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "tempest", "granted_action"], 0.0,
		{"action_id": "storm_thunderclap"})
	tc_grant.granted_action = tc_act
	_save_affix(tc_grant, "thunderclap", "thunderclap_r1_affix")

	var thunderclap := _make_skill(
		"storm_thunderclap", "Thunderclap",
		"[color=yellow]ACTION:[/color] 2 dice -> [color=cyan]shock[/color] x1.2 + 3 [color=cyan]Static[/color]. Per turn.",
		4, 2, _tier_pts(4),
		{1: [tc_grant]})
	_save_skill(thunderclap, "storm_thunderclap")

	# ── Voltaic Surge (Col 3, Tempest): Shock damage x1.01/x1.02/x1.03 per Static stack. 3 ranks. ──
	var vs_r1: Affix = _make_affix("Voltaic Surge I", "Shock x1.01 per Static stack.",
		Affix.Category.STATUS_DAMAGE_MULTIPLIER,
		["mage", "storm", "tempest", "static_synergy"], 1.01,
		{"status_id": "static", "element": "SHOCK", "per_stack": true})
	_save_affix(vs_r1, "voltaic_surge", "voltaic_surge_r1_affix")

	var vs_r2: Affix = _make_affix("Voltaic Surge II", "Shock x1.02 per Static stack.",
		Affix.Category.STATUS_DAMAGE_MULTIPLIER,
		["mage", "storm", "tempest", "static_synergy"], 1.02,
		{"status_id": "static", "element": "SHOCK", "per_stack": true})
	_save_affix(vs_r2, "voltaic_surge", "voltaic_surge_r2_affix")

	var vs_r3: Affix = _make_affix("Voltaic Surge III", "Shock x1.03 per Static stack.",
		Affix.Category.STATUS_DAMAGE_MULTIPLIER,
		["mage", "storm", "tempest", "static_synergy"], 1.03,
		{"status_id": "static", "element": "SHOCK", "per_stack": true})
	_save_affix(vs_r3, "voltaic_surge", "voltaic_surge_r3_affix")

	var voltaic_surge := _make_skill(
		"storm_voltaic_surge", "Voltaic Surge",
		"Shock damage x[color=yellow]1.01/1.02/1.03[/color] per [color=cyan]Static[/color] stack on target.",
		4, 3, _tier_pts(4),
		{1: [vs_r1], 2: [vs_r2], 3: [vs_r3]})
	_save_skill(voltaic_surge, "storm_voltaic_surge")

	# ── Mana Siphon (Col 5, Conduit): On shock kill, restore 3/5/7 mana. 3 ranks. ──
	var ms_r1: Affix = _make_affix("Mana Siphon I", "On shock kill, restore 3 mana.",
		Affix.Category.PROC,
		["mage", "storm", "conduit", "mana_restore", "on_kill"], 3.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "mana_restore",
		 "amount": 3, "element_condition": "SHOCK"})
	ms_r1.proc_trigger = Affix.ProcTrigger.ON_KILL
	_save_affix(ms_r1, "mana_siphon", "mana_siphon_r1_affix")

	var ms_r2: Affix = _make_affix("Mana Siphon II", "On shock kill, restore 5 mana.",
		Affix.Category.PROC,
		["mage", "storm", "conduit", "mana_restore", "on_kill"], 5.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "mana_restore",
		 "amount": 5, "element_condition": "SHOCK"})
	ms_r2.proc_trigger = Affix.ProcTrigger.ON_KILL
	_save_affix(ms_r2, "mana_siphon", "mana_siphon_r2_affix")

	var ms_r3: Affix = _make_affix("Mana Siphon III", "On shock kill, restore 7 mana.",
		Affix.Category.PROC,
		["mage", "storm", "conduit", "mana_restore", "on_kill"], 7.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "mana_restore",
		 "amount": 7, "element_condition": "SHOCK"})
	ms_r3.proc_trigger = Affix.ProcTrigger.ON_KILL
	_save_affix(ms_r3, "mana_siphon", "mana_siphon_r3_affix")

	var mana_siphon := _make_skill(
		"storm_mana_siphon", "Mana Siphon",
		"On shock kill, restore [color=yellow]3/5/7[/color] mana.",
		4, 5, _tier_pts(4),
		{1: [ms_r1], 2: [ms_r2], 3: [ms_r3]})
	_save_skill(mana_siphon, "storm_mana_siphon")

func _create_tier_5():
	print("\n-- Tier 5 -- 6 skills (Voltaic Sprite, Storm Charge, Tempest Sprite, Lightning Bolt, Conduit Sprite, Conduit Flow)...")

	# ── Voltaic Sprite (Col 0, Voltaic): Storm Sprite applies 2/3 Static per trigger. 2 ranks. ──
	# Rank 1: append ADD_STATUS effect to sprite. Rank 2: stacks 3 + dual trigger.
	# These are MISC affixes tagged "storm_sprite_upgrade" that the sprite builder reads.

	var vs_sprite_eff_r1: ActionEffect = _make_action_effect(
		"Sprite: Apply Static (Voltaic I)",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.SHOCK,
		0, 1.0, 0, 0, 1.0, false,
		_static_status, 2)  # 2 stacks
	_save_effect(vs_sprite_eff_r1, "voltaic_sprite_static_r1")

	var vs_spr_r1: Affix = _make_affix("Voltaic Sprite I",
		"Storm Sprite applies 2 Static per trigger.",
		Affix.Category.MISC,
		["mage", "storm", "voltaic", "storm_sprite_upgrade"], 0.0,
		{"sprite_mod_type": "voltaic", "action_effect": vs_sprite_eff_r1,
		 "dual_trigger": false})
	_save_affix(vs_spr_r1, "voltaic_sprite", "voltaic_sprite_r1_affix")

	var vs_sprite_eff_r2: ActionEffect = _make_action_effect(
		"Sprite: Apply Static (Voltaic II)",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.SHOCK,
		0, 1.0, 0, 0, 1.0, false,
		_static_status, 3)  # 3 stacks
	_save_effect(vs_sprite_eff_r2, "voltaic_sprite_static_r2")

	var vs_spr_r2: Affix = _make_affix("Voltaic Sprite II",
		"Storm Sprite applies 3 Static per trigger. Also fires on turn start.",
		Affix.Category.MISC,
		["mage", "storm", "voltaic", "storm_sprite_upgrade"], 0.0,
		{"sprite_mod_type": "voltaic", "action_effect": vs_sprite_eff_r2,
		 "dual_trigger": true})
	_save_affix(vs_spr_r2, "voltaic_sprite", "voltaic_sprite_r2_affix")

	var voltaic_sprite := _make_skill(
		"storm_voltaic_sprite", "Voltaic Sprite",
		"Storm Sprite applies [color=yellow]2/3[/color] [color=cyan]Static[/color] per trigger. Rank 2: also fires on turn start.",
		5, 0, _tier_pts(5),
		{1: [vs_spr_r1], 2: [vs_spr_r2]})
	_save_skill(voltaic_sprite, "storm_voltaic_sprite")

	# ── Storm Charge (Col 1, Voltaic): Static 10+ threshold spreads 1/2/3 to others. 3 ranks. ──
	var sch_r1: Affix = _make_affix("Storm Charge I",
		"Applying Static to 10+ target spreads 1 to others.",
		Affix.Category.PROC,
		["mage", "storm", "voltaic", "static_spread"], 1.0,
		{"proc_trigger": "ON_STATUS_APPLIED", "proc_effect": "spread_static",
		 "threshold": 10, "stacks": 1, "target": "all_other_enemies",
		 "status_id": "static"})
	_save_affix(sch_r1, "storm_charge", "storm_charge_r1_affix")

	var sch_r2: Affix = _make_affix("Storm Charge II",
		"Applying Static to 10+ target spreads 2 to others.",
		Affix.Category.PROC,
		["mage", "storm", "voltaic", "static_spread"], 2.0,
		{"proc_trigger": "ON_STATUS_APPLIED", "proc_effect": "spread_static",
		 "threshold": 10, "stacks": 2, "target": "all_other_enemies",
		 "status_id": "static"})
	_save_affix(sch_r2, "storm_charge", "storm_charge_r2_affix")

	var sch_r3: Affix = _make_affix("Storm Charge III",
		"Applying Static to 10+ target spreads 3 to others.",
		Affix.Category.PROC,
		["mage", "storm", "voltaic", "static_spread"], 3.0,
		{"proc_trigger": "ON_STATUS_APPLIED", "proc_effect": "spread_static",
		 "threshold": 10, "stacks": 3, "target": "all_other_enemies",
		 "status_id": "static"})
	_save_affix(sch_r3, "storm_charge", "storm_charge_r3_affix")

	var storm_charge := _make_skill(
		"storm_storm_charge", "Storm Charge",
		"Applying Static to a target with 10+ stacks also applies [color=yellow]1/2/3[/color] Static to all other enemies.",
		5, 1, _tier_pts(5),
		{1: [sch_r1], 2: [sch_r2], 3: [sch_r3]})
	_save_skill(storm_charge, "storm_storm_charge")

	# ── Tempest Sprite (Col 2, Tempest): Sprite chains to 1/2 enemies. Rank 2: ON_DEATH AoE. 2 ranks. ──
	var ts_sprite_chain_r1: ActionEffect = _make_chain_effect(
		"Sprite: Chain Zap (Tempest I)",
		ActionEffect.TargetType.SINGLE_ENEMY,
		1, 1.0)  # chain to 1, no decay
	_save_effect(ts_sprite_chain_r1, "tempest_sprite_chain_r1")

	var ts_spr_r1: Affix = _make_affix("Tempest Sprite I",
		"Storm Sprite's damage chains to 1 enemy.",
		Affix.Category.MISC,
		["mage", "storm", "tempest", "storm_sprite_upgrade"], 0.0,
		{"sprite_mod_type": "tempest", "action_effect": ts_sprite_chain_r1,
		 "on_death_aoe": false})
	_save_affix(ts_spr_r1, "tempest_sprite", "tempest_sprite_r1_affix")

	var ts_sprite_chain_r2: ActionEffect = _make_chain_effect(
		"Sprite: Chain Zap (Tempest II)",
		ActionEffect.TargetType.SINGLE_ENEMY,
		2, 1.0)  # chain to 2, no decay
	_save_effect(ts_sprite_chain_r2, "tempest_sprite_chain_r2")

	# ON_DEATH AoE effect for rank 2
	var ts_sprite_death: ActionEffect = _make_action_effect(
		"Sprite: Death Burst",
		ActionEffect.TargetType.ALL_ENEMIES,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.SHOCK,
		12, 1.0, 0)  # 12 flat shock, no dice
	_save_effect(ts_sprite_death, "tempest_sprite_death_burst")

	var ts_spr_r2: Affix = _make_affix("Tempest Sprite II",
		"Storm Sprite chains to 2 enemies. Explodes on death for AoE shock.",
		Affix.Category.MISC,
		["mage", "storm", "tempest", "storm_sprite_upgrade"], 0.0,
		{"sprite_mod_type": "tempest", "action_effect": ts_sprite_chain_r2,
		 "on_death_aoe": true, "death_effect": ts_sprite_death})
	_save_affix(ts_spr_r2, "tempest_sprite", "tempest_sprite_r2_affix")

	var tempest_sprite := _make_skill(
		"storm_tempest_sprite", "Tempest Sprite",
		"Storm Sprite's damage chains to [color=yellow]1/2[/color] enemies. Rank 2: explodes on death for AoE shock.",
		5, 2, _tier_pts(5),
		{1: [ts_spr_r1], 2: [ts_spr_r2]})
	_save_skill(tempest_sprite, "storm_tempest_sprite")

	# ── Lightning Bolt (Col 3, Tempest): ACTION — 2 shock dice, x1.5, chain to 1 for 50%. 1 rank. ──
	var lb_dmg: ActionEffect = _make_action_effect(
		"Lightning Bolt: Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.SHOCK,
		0, 1.5, 2)  # x1.5, 2 dice
	_save_effect(lb_dmg, "lightning_bolt_damage")

	var lb_chain: ActionEffect = _make_chain_effect(
		"Lightning Bolt: Chain",
		ActionEffect.TargetType.SINGLE_ENEMY,
		1, 1.0)  # chain to 1, no decay (50% handled via damage calc)
	# Override chain damage to 50% of primary
	lb_chain.chain_decay = 0.5
	_save_effect(lb_chain, "lightning_bolt_chain")

	var lb_effects: Array[ActionEffect] = []
	lb_effects.assign([lb_dmg, lb_chain])
	var shock_only: Array[int] = [6]  # DieResource.Element.SHOCK
	var lb_act: Action = _make_action_with_elements(
		"storm_lightning_bolt", "Lightning Bolt",
		"Heavy shock strike, chains to 1 enemy for 50% damage.",
		2, lb_effects, shock_only,
		Action.ChargeType.LIMITED_PER_TURN, 1)
	_save_action(lb_act, "lightning_bolt_action")

	var lb_grant: Affix = _make_affix("Lightning Bolt: Grant Action",
		"Grants Lightning Bolt action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "tempest", "granted_action", "chain"], 0.0,
		{"action_id": "storm_lightning_bolt"})
	lb_grant.granted_action = lb_act
	_save_affix(lb_grant, "lightning_bolt", "lightning_bolt_r1_affix")

	var lightning_bolt := _make_skill(
		"storm_lightning_bolt", "Lightning Bolt",
		"[color=yellow]ACTION:[/color] 2 dice -> [color=cyan]shock[/color] x1.5, chain to 1 enemy for 50%.",
		5, 3, _tier_pts(5),
		{1: [lb_grant]})
	_save_skill(lightning_bolt, "storm_lightning_bolt")

	# ── Conduit Sprite (Col 4, Conduit): Sprite restores 2/3 mana instead of damage. 2 ranks. ──
	var cs_sprite_mana_r1: ActionEffect = _make_action_effect(
		"Sprite: Mana Pulse (Conduit I)",
		ActionEffect.TargetType.SELF,
		ActionEffect.EffectType.MANA_MANIPULATE,
		ActionEffect.DamageType.SHOCK)
	cs_sprite_mana_r1.mana_amount = 2
	cs_sprite_mana_r1.mana_uses_dice = false
	_save_effect(cs_sprite_mana_r1, "conduit_sprite_mana_r1")

	var cs_spr_r1: Affix = _make_affix("Conduit Sprite I",
		"Storm Sprite restores 2 mana per trigger instead of dealing damage.",
		Affix.Category.MISC,
		["mage", "storm", "conduit", "storm_sprite_upgrade"], 0.0,
		{"sprite_mod_type": "conduit", "action_effect": cs_sprite_mana_r1,
		 "free_die_interval": 0})
	_save_affix(cs_spr_r1, "conduit_sprite", "conduit_sprite_r1_affix")

	var cs_sprite_mana_r2: ActionEffect = _make_action_effect(
		"Sprite: Mana Pulse (Conduit II)",
		ActionEffect.TargetType.SELF,
		ActionEffect.EffectType.MANA_MANIPULATE,
		ActionEffect.DamageType.SHOCK)
	cs_sprite_mana_r2.mana_amount = 3
	cs_sprite_mana_r2.mana_uses_dice = false
	_save_effect(cs_sprite_mana_r2, "conduit_sprite_mana_r2")

	var cs_spr_r2: Affix = _make_affix("Conduit Sprite II",
		"Storm Sprite restores 3 mana per trigger. Grants free shock die every 2 turns.",
		Affix.Category.MISC,
		["mage", "storm", "conduit", "storm_sprite_upgrade"], 0.0,
		{"sprite_mod_type": "conduit", "action_effect": cs_sprite_mana_r2,
		 "free_die_interval": 2})
	_save_affix(cs_spr_r2, "conduit_sprite", "conduit_sprite_r2_affix")

	var conduit_sprite := _make_skill(
		"storm_conduit_sprite", "Conduit Sprite",
		"Storm Sprite restores [color=yellow]2/3[/color] mana per trigger instead of dealing damage. Rank 2: also grants a free shock die every 2 turns.",
		5, 4, _tier_pts(5),
		{1: [cs_spr_r1], 2: [cs_spr_r2]})
	_save_skill(conduit_sprite, "storm_conduit_sprite")

	# ── Conduit Flow (Col 5, Conduit): Unlock D6 shock + mana regen +1/+2/+3. 3 ranks. ──
	var cf_size: Affix = _make_affix("Conduit Flow: D6 Unlock",
		"Unlocks D6 shock mana die.",
		Affix.Category.MANA_SIZE_UNLOCK,
		["mage", "storm", "conduit", "size_unlock"], 0.0,
		{"die_size": 6})
	_save_affix(cf_size, "conduit_flow", "conduit_flow_size_unlock")

	var cf_regen_r1: Affix = _make_affix("Conduit Flow I", "+1 mana regen per turn.",
		Affix.Category.PER_TURN,
		["mage", "storm", "conduit", "mana_regen"], 1.0,
		{"per_turn_type": "mana_regen"})
	cf_regen_r1.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	_save_affix(cf_regen_r1, "conduit_flow", "conduit_flow_r1_regen_affix")

	var cf_regen_r2: Affix = _make_affix("Conduit Flow II", "+2 mana regen per turn.",
		Affix.Category.PER_TURN,
		["mage", "storm", "conduit", "mana_regen"], 2.0,
		{"per_turn_type": "mana_regen"})
	cf_regen_r2.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	_save_affix(cf_regen_r2, "conduit_flow", "conduit_flow_r2_regen_affix")

	var cf_regen_r3: Affix = _make_affix("Conduit Flow III", "+3 mana regen per turn.",
		Affix.Category.PER_TURN,
		["mage", "storm", "conduit", "mana_regen"], 3.0,
		{"per_turn_type": "mana_regen"})
	cf_regen_r3.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	_save_affix(cf_regen_r3, "conduit_flow", "conduit_flow_r3_regen_affix")

	var conduit_flow := _make_skill(
		"storm_conduit_flow", "Conduit Flow",
		"Unlock D6 shock mana die. +[color=yellow]1/2/3[/color] mana regen per turn.",
		5, 5, _tier_pts(5),
		{1: [cf_size, cf_regen_r1],
		 2: [cf_size, cf_regen_r2],
		 3: [cf_size, cf_regen_r3]})
	_save_skill(conduit_flow, "storm_conduit_flow")

func _create_tier_6():
	print("\n-- Tier 6 -- 5 skills (Persistent Field, Arc Conduit, Tempest Strike, Grounded Circuit, Galvanic Renewal)...")

	# ── Persistent Field (Col 0, Voltaic): Static max stacks +5/+10. 2 ranks. ──
	var pf_r1: Affix = _make_affix("Persistent Field I", "Static max stacks +5.",
		Affix.Category.MISC,
		["mage", "storm", "voltaic", "static_max_stacks"], 5.0,
		{"static_max_stacks_bonus": 5})
	_save_affix(pf_r1, "persistent_field", "persistent_field_r1_affix")

	var pf_r2: Affix = _make_affix("Persistent Field II", "Static max stacks +10.",
		Affix.Category.MISC,
		["mage", "storm", "voltaic", "static_max_stacks"], 10.0,
		{"static_max_stacks_bonus": 10})
	_save_affix(pf_r2, "persistent_field", "persistent_field_r2_affix")

	var persistent_field := _make_skill(
		"storm_persistent_field", "Persistent Field",
		"Static max stacks +[color=yellow]5/10[/color].",
		6, 0, _tier_pts(6),
		{1: [pf_r1], 2: [pf_r2]})
	_save_skill(persistent_field, "storm_persistent_field")

	# ── Arc Conduit (Col 2, Crossover): Shock mana dice chain 40%/60% on use. 2 ranks. ──
	# MANA_DIE_AFFIX wrapping a DiceAffix with EMIT_CHAIN_DAMAGE
	var da_arc_cond_r1: DiceAffix = _make_dice_affix(
		"Arc Conduit I: Chain on Use", "Shock die chains 40% on use.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.4,
		{"chains": 1, "decay": 1.0, "element": "SHOCK"},
		_cond_self_element_shock)
	_save(da_arc_cond_r1, DICE_AFFIX_DIR + "da_arc_conduit_r1.tres")

	var ac_r1: Affix = _make_mana_die_affix_wrapper(
		"Arc Conduit I", "Shock dice chain 40% damage to 1 enemy on use.",
		["mage", "storm", "crossover", "mana_die_affix", "chain"], da_arc_cond_r1)
	_save_affix(ac_r1, "arc_conduit", "arc_conduit_r1_affix")

	var da_arc_cond_r2: DiceAffix = _make_dice_affix(
		"Arc Conduit II: Chain on Use", "Shock die chains 60% on use.",
		DiceAffix.Trigger.ON_USE,
		DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.6,
		{"chains": 1, "decay": 1.0, "element": "SHOCK"},
		_cond_self_element_shock)
	_save(da_arc_cond_r2, DICE_AFFIX_DIR + "da_arc_conduit_r2.tres")

	var ac_r2: Affix = _make_mana_die_affix_wrapper(
		"Arc Conduit II", "Shock dice chain 60% damage to 1 enemy on use.",
		["mage", "storm", "crossover", "mana_die_affix", "chain"], da_arc_cond_r2)
	_save_affix(ac_r2, "arc_conduit", "arc_conduit_r2_affix")

	var arc_conduit := _make_skill(
		"storm_arc_conduit", "Arc Conduit",
		"Shock mana dice chain [color=yellow]40%/60%[/color] damage to 1 enemy on use.",
		6, 2, _tier_pts(6),
		{1: [ac_r1], 2: [ac_r2]})
	_save_skill(arc_conduit, "storm_arc_conduit")

	# ── Tempest Strike (Col 3, Tempest): Chromatic Bolt +1 die slot + chain 40%/60% on shock die. 2 ranks. ──
	# Two affixes at rank 1: CLASS_ACTION_STAT_MOD (+1 slot) + CLASS_ACTION_EFFECT_ADD (chain)
	var ts_slot: Affix = _make_affix("Tempest Strike: Die Slot",
		"Chromatic Bolt gains +1 die slot.",
		Affix.Category.CLASS_ACTION_STAT_MOD,
		["mage", "storm", "tempest", "class_action_mod"], 1.0,
		{"property": "die_slots", "operation": "add"})
	_save_affix(ts_slot, "tempest_strike", "tempest_strike_slot_affix")

	var ts_chain_eff_r1: ActionEffect = _make_chain_effect(
		"Tempest Strike: Chain I",
		ActionEffect.TargetType.SINGLE_ENEMY,
		1, 0.4)  # chain to 1, 40% damage
	ts_chain_eff_r1.effect_data = {"condition": "shock_die_used"}
	_save_effect(ts_chain_eff_r1, "tempest_strike_chain_r1")

	var ts_chain_r1: Affix = _make_affix("Tempest Strike: Chain I",
		"Chromatic Bolt chains to 1 enemy for 40% (shock die).",
		Affix.Category.CLASS_ACTION_EFFECT_ADD,
		["mage", "storm", "tempest", "class_action_mod", "chain"], 0.0,
		{"action_effect": ts_chain_eff_r1, "shock_die_condition": true})
	_save_affix(ts_chain_r1, "tempest_strike", "tempest_strike_chain_r1_affix")

	var ts_chain_eff_r2: ActionEffect = _make_chain_effect(
		"Tempest Strike: Chain II",
		ActionEffect.TargetType.SINGLE_ENEMY,
		1, 0.6)  # chain to 1, 60% damage
	ts_chain_eff_r2.effect_data = {"condition": "shock_die_used"}
	_save_effect(ts_chain_eff_r2, "tempest_strike_chain_r2")

	var ts_chain_r2: Affix = _make_affix("Tempest Strike: Chain II",
		"Chromatic Bolt chains to 1 enemy for 60% (shock die).",
		Affix.Category.CLASS_ACTION_EFFECT_ADD,
		["mage", "storm", "tempest", "class_action_mod", "chain"], 0.0,
		{"action_effect": ts_chain_eff_r2, "shock_die_condition": true})
	_save_affix(ts_chain_r2, "tempest_strike", "tempest_strike_chain_r2_affix")

	var tempest_strike := _make_skill(
		"storm_tempest_strike", "Tempest Strike",
		"Chromatic Bolt gains +1 die slot and chains to 1 enemy for [color=yellow]40%/60%[/color] when a shock die is used.",
		6, 3, _tier_pts(6),
		{1: [ts_slot, ts_chain_r1],
		 2: [ts_slot, ts_chain_r2]})
	_save_skill(tempest_strike, "storm_tempest_strike")

	# ── Grounded Circuit (Col 4, Crossover): Shock damage to Static targets restores 1/2 mana. 2 ranks. ──
	var gc_r1: Affix = _make_affix("Grounded Circuit I",
		"Shock damage to Static targets restores 1 mana.",
		Affix.Category.PROC,
		["mage", "storm", "crossover", "mana_restore", "static_synergy"], 1.0,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_effect": "mana_restore",
		 "amount": 1, "condition": "target_has_static", "element_condition": "SHOCK"})
	gc_r1.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	_save_affix(gc_r1, "grounded_circuit", "grounded_circuit_r1_affix")

	var gc_r2: Affix = _make_affix("Grounded Circuit II",
		"Shock damage to Static targets restores 2 mana.",
		Affix.Category.PROC,
		["mage", "storm", "crossover", "mana_restore", "static_synergy"], 2.0,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_effect": "mana_restore",
		 "amount": 2, "condition": "target_has_static", "element_condition": "SHOCK"})
	gc_r2.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	_save_affix(gc_r2, "grounded_circuit", "grounded_circuit_r2_affix")

	var grounded_circuit := _make_skill(
		"storm_grounded_circuit", "Grounded Circuit",
		"Shock damage to targets with Static restores [color=yellow]1/2[/color] mana per hit.",
		6, 4, _tier_pts(6),
		{1: [gc_r1], 2: [gc_r2]})
	_save_skill(grounded_circuit, "storm_grounded_circuit")

	# ── Galvanic Renewal (Col 6, Conduit): On shock kill, free shock die to hand. 1/2 per turn. 2 ranks. ──
	var gr_r1: Affix = _make_affix("Galvanic Renewal I",
		"On shock kill, gain a free shock mana die. 1/turn.",
		Affix.Category.PROC,
		["mage", "storm", "conduit", "die_grant", "on_kill"], 1.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "grant_mana_die",
		 "element": "SHOCK", "uses_per_turn": 1, "element_condition": "SHOCK"})
	gr_r1.proc_trigger = Affix.ProcTrigger.ON_KILL
	_save_affix(gr_r1, "galvanic_renewal", "galvanic_renewal_r1_affix")

	var gr_r2: Affix = _make_affix("Galvanic Renewal II",
		"On shock kill, gain a free shock mana die. 2/turn.",
		Affix.Category.PROC,
		["mage", "storm", "conduit", "die_grant", "on_kill"], 2.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "grant_mana_die",
		 "element": "SHOCK", "uses_per_turn": 2, "element_condition": "SHOCK"})
	gr_r2.proc_trigger = Affix.ProcTrigger.ON_KILL
	_save_affix(gr_r2, "galvanic_renewal", "galvanic_renewal_r2_affix")

	var galvanic_renewal := _make_skill(
		"storm_galvanic_renewal", "Galvanic Renewal",
		"On shock kill, gain a free shock mana die to hand. [color=yellow]1/2[/color] times per turn.",
		6, 6, _tier_pts(6),
		{1: [gr_r1], 2: [gr_r2]})
	_save_skill(galvanic_renewal, "storm_galvanic_renewal")

func _create_tier_7():
	print("\n-- Tier 7 -- 4 skills (Overcharge, Chain Lightning, Dynamo, Static Discharge)...")

	# ── Overcharge (Col 1, Voltaic): ACTION — 1 die, damage = target Static stacks x3. 1 rank. ──
	# Uses VALUE_SOURCE = TARGET_STATUS_STACKS. The placed die is a cost, not a damage source.
	var oc_dmg: ActionEffect = _make_action_effect(
		"Overcharge: Stack Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.SHOCK,
		0, 3.0, 0)  # base 0, multiplier 3.0 (stacks x3), 0 dice
	oc_dmg.value_source = ActionEffect.ValueSource.TARGET_STATUS_STACKS
	oc_dmg.value_source_status_id = "static"
	oc_dmg.effect_data = {"consume_stacks": false}
	_save_effect(oc_dmg, "overcharge_damage")

	var oc_effects: Array[ActionEffect] = []
	oc_effects.assign([oc_dmg])
	var shock_only: Array[int] = [6]
	var oc_act: Action = _make_action_with_elements(
		"storm_overcharge", "Overcharge",
		"Deal damage equal to target's Static stacks x3. Does not consume stacks.",
		1, oc_effects, shock_only,
		Action.ChargeType.LIMITED_PER_TURN, 1)
	_save_action(oc_act, "overcharge_action")

	var oc_grant: Affix = _make_affix("Overcharge: Grant Action",
		"Grants Overcharge action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "voltaic", "granted_action", "static_payoff"], 0.0,
		{"action_id": "storm_overcharge"})
	oc_grant.granted_action = oc_act
	_save_affix(oc_grant, "overcharge", "overcharge_r1_affix")

	var overcharge := _make_skill(
		"storm_overcharge", "Overcharge",
		"[color=yellow]ACTION:[/color] 1 die -> damage = target's [color=cyan]Static[/color] stacks x3. Does not consume stacks. Per turn.",
		7, 1, _tier_pts(7),
		{1: [oc_grant]})
	_save_skill(overcharge, "storm_overcharge")

	# ── Chain Lightning (Col 2, Tempest): ACTION — 2 shock dice, x1.0, chain to 2 for 60%. 1 rank. ──
	var cl_dmg: ActionEffect = _make_action_effect(
		"Chain Lightning: Damage",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.SHOCK,
		0, 1.0, 2)  # x1.0, 2 dice
	_save_effect(cl_dmg, "chain_lightning_damage")

	var cl_chain: ActionEffect = _make_chain_effect(
		"Chain Lightning: Chain",
		ActionEffect.TargetType.SINGLE_ENEMY,
		2, 0.6)  # chain to 2, 60% per bounce (using decay as percent)
	_save_effect(cl_chain, "chain_lightning_chain")

	var cl_effects: Array[ActionEffect] = []
	cl_effects.assign([cl_dmg, cl_chain])
	var cl_act: Action = _make_action_with_elements(
		"storm_chain_lightning", "Chain Lightning",
		"Full shock damage, chains to 2 enemies for 60%.",
		2, cl_effects, shock_only,
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(cl_act, "chain_lightning_action")

	var cl_grant: Affix = _make_affix("Chain Lightning: Grant Action",
		"Grants Chain Lightning action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "tempest", "granted_action", "chain"], 0.0,
		{"action_id": "storm_chain_lightning"})
	cl_grant.granted_action = cl_act
	_save_affix(cl_grant, "chain_lightning", "chain_lightning_r1_affix")

	var chain_lightning := _make_skill(
		"storm_chain_lightning", "Chain Lightning",
		"[color=yellow]ACTION:[/color] 2 dice -> [color=cyan]shock[/color] x1.0, chain to 2 enemies for 60%. Per combat.",
		7, 2, _tier_pts(7),
		{1: [cl_grant]})
	_save_skill(chain_lightning, "storm_chain_lightning")

	# ── Dynamo (Col 4, Conduit): Unlock D8 shock + shock mana dice +1/+2 rolled value. 2 ranks. ──
	var dyn_size: Affix = _make_affix("Dynamo: D8 Unlock",
		"Unlocks D8 shock mana die.",
		Affix.Category.MANA_SIZE_UNLOCK,
		["mage", "storm", "conduit", "size_unlock"], 0.0,
		{"die_size": 8})
	_save_affix(dyn_size, "dynamo", "dynamo_size_unlock")

	var da_dyn_r1: DiceAffix = _make_dice_affix(
		"Dynamo I: Value Bonus", "Shock dice +1 on roll.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0, {},
		_cond_self_element_shock)
	_save(da_dyn_r1, DICE_AFFIX_DIR + "da_dynamo_r1.tres")

	var dyn_val_r1: Affix = _make_mana_die_affix_wrapper(
		"Dynamo I", "Shock mana dice +1 to rolled value.",
		["mage", "storm", "conduit", "mana_die_affix", "value_bonus"], da_dyn_r1)
	_save_affix(dyn_val_r1, "dynamo", "dynamo_r1_value_affix")

	var da_dyn_r2: DiceAffix = _make_dice_affix(
		"Dynamo II: Value Bonus", "Shock dice +2 on roll.",
		DiceAffix.Trigger.ON_ROLL,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0, {},
		_cond_self_element_shock)
	_save(da_dyn_r2, DICE_AFFIX_DIR + "da_dynamo_r2.tres")

	var dyn_val_r2: Affix = _make_mana_die_affix_wrapper(
		"Dynamo II", "Shock mana dice +2 to rolled value.",
		["mage", "storm", "conduit", "mana_die_affix", "value_bonus"], da_dyn_r2)
	_save_affix(dyn_val_r2, "dynamo", "dynamo_r2_value_affix")

	var dynamo := _make_skill(
		"storm_dynamo", "Dynamo",
		"Unlock D8 shock mana die. Shock mana dice +[color=yellow]1/2[/color] to rolled value.",
		7, 4, _tier_pts(7),
		{1: [dyn_size, dyn_val_r1],
		 2: [dyn_size, dyn_val_r2]})
	_save_skill(dynamo, "storm_dynamo")

	# ── Static Discharge (Col 5, Conduit): Enemy with Static dies -> splash stacks as damage + half as Static. 1 rank. ──
	var sd_r1: Affix = _make_affix("Static Discharge",
		"When a Static target dies, deal remaining stacks as shock damage to all others and apply half as Static.",
		Affix.Category.PROC,
		["mage", "storm", "conduit", "static_synergy", "on_kill", "propagate"], 1.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "static_death_discharge",
		 "damage_per_stack": 1, "spread_fraction": 0.5,
		 "target": "all_other_enemies"})
	sd_r1.proc_trigger = Affix.ProcTrigger.ON_KILL
	_save_affix(sd_r1, "static_discharge", "static_discharge_r1_affix")

	var static_discharge := _make_skill(
		"storm_static_discharge", "Static Discharge",
		"When a [color=cyan]Static[/color] target dies, deal remaining stacks as shock damage to all enemies and apply half (rounded down) as Static.",
		7, 5, _tier_pts(7),
		{1: [sd_r1]})
	_save_skill(static_discharge, "storm_static_discharge")

func _create_tier_8():
	print("\n-- Tier 8 -- 3 skills (Tesla Coil, Storm Surge, Feedback Loop)...")

	# ── Tesla Coil (Col 1, Crossover): Chains +1 target, apply 2 Static per bounce. 1 rank. ──
	# Two MISC affixes: one for chain extension, one for chain-Static application.
	var tc_chain_ext: Affix = _make_affix("Tesla Coil: Chain Extension",
		"Chain effects chain +1 additional target.",
		Affix.Category.MISC,
		["mage", "storm", "crossover", "chain_extend"], 1.0,
		{"chain_bonus_targets": 1})
	_save_affix(tc_chain_ext, "tesla_coil", "tesla_coil_chain_ext_affix")

	var tc_chain_static: Affix = _make_affix("Tesla Coil: Chain Static",
		"Chain bounces apply 2 Static per bounce.",
		Affix.Category.MISC,
		["mage", "storm", "crossover", "chain_static", "static_apply"], 2.0,
		{"chain_apply_static": 2})
	_save_affix(tc_chain_static, "tesla_coil", "tesla_coil_chain_static_affix")

	var tesla_coil := _make_skill(
		"storm_tesla_coil", "Tesla Coil",
		"Chain effects chain +1 additional target and apply 2 [color=cyan]Static[/color] per chain bounce.",
		8, 1, _tier_pts(8),
		{1: [tc_chain_ext, tc_chain_static]})
	_save_skill(tesla_coil, "storm_tesla_coil")

	# ── Storm Surge (Col 3, Tempest): ACTION — 3 shock dice, x0.8, ALL_ENEMIES, +3 Static each. 1 rank. ──
	var ss_dmg: ActionEffect = _make_action_effect(
		"Storm Surge: AoE Damage",
		ActionEffect.TargetType.ALL_ENEMIES,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.SHOCK,
		0, 0.8, 3)  # x0.8, 3 dice
	_save_effect(ss_dmg, "storm_surge_damage")

	var ss_status: ActionEffect = _make_action_effect(
		"Storm Surge: Apply Static",
		ActionEffect.TargetType.ALL_ENEMIES,
		ActionEffect.EffectType.ADD_STATUS,
		ActionEffect.DamageType.SHOCK,
		0, 1.0, 0, 0, 1.0, false,
		_static_status, 3)  # 3 stacks to each
	_save_effect(ss_status, "storm_surge_static")

	var ss_effects: Array[ActionEffect] = []
	ss_effects.assign([ss_dmg, ss_status])
	var shock_only: Array[int] = [6]
	var ss_act: Action = _make_action_with_elements(
		"storm_storm_surge", "Storm Surge",
		"Shock barrage: x0.8 damage to all enemies and apply 3 Static to each.",
		3, ss_effects, shock_only,
		Action.ChargeType.LIMITED_PER_COMBAT, 1)
	_save_action(ss_act, "storm_surge_action")

	var ss_grant: Affix = _make_affix("Storm Surge: Grant Action",
		"Grants Storm Surge action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "tempest", "granted_action", "aoe"], 0.0,
		{"action_id": "storm_storm_surge"})
	ss_grant.granted_action = ss_act
	_save_affix(ss_grant, "storm_surge", "storm_surge_r1_affix")

	var storm_surge := _make_skill(
		"storm_storm_surge", "Storm Surge",
		"[color=yellow]ACTION:[/color] 3 dice -> [color=cyan]shock[/color] x0.8 to ALL enemies + 3 [color=cyan]Static[/color] each. Per combat.",
		8, 3, _tier_pts(8),
		{1: [ss_grant]})
	_save_skill(storm_surge, "storm_storm_surge")

	# ── Feedback Loop (Col 5, Crossover): Grounded Circuit doubled + pull shock die grants +3/+6 bonus dmg. 2 ranks. ──
	# Two affixes: one doubles Grounded Circuit, one adds temp shock damage bonus on pull.
	var fl_gc_boost: Affix = _make_affix("Feedback Loop: Grounded Circuit Boost",
		"Grounded Circuit mana restore doubled.",
		Affix.Category.MISC,
		["mage", "storm", "crossover", "grounded_circuit_boost"], 2.0,
		{"grounded_circuit_multiplier": 2})
	_save_affix(fl_gc_boost, "feedback_loop", "feedback_loop_gc_boost_affix")

	var fl_pull_r1: Affix = _make_affix("Feedback Loop I: Pull Bonus",
		"Pulling shock die grants +3 bonus shock damage this turn.",
		Affix.Category.PROC,
		["mage", "storm", "crossover", "conduit", "on_pull", "temp_buff"], 3.0,
		{"proc_trigger": "ON_MANA_PULL", "proc_effect": "temp_shock_damage_bonus",
		 "amount": 3, "duration": "this_turn", "element_condition": "SHOCK"})
	_save_affix(fl_pull_r1, "feedback_loop", "feedback_loop_pull_r1_affix")

	var fl_pull_r2: Affix = _make_affix("Feedback Loop II: Pull Bonus",
		"Pulling shock die grants +6 bonus shock damage this turn.",
		Affix.Category.PROC,
		["mage", "storm", "crossover", "conduit", "on_pull", "temp_buff"], 6.0,
		{"proc_trigger": "ON_MANA_PULL", "proc_effect": "temp_shock_damage_bonus",
		 "amount": 6, "duration": "this_turn", "element_condition": "SHOCK"})
	_save_affix(fl_pull_r2, "feedback_loop", "feedback_loop_pull_r2_affix")

	var feedback_loop := _make_skill(
		"storm_feedback_loop", "Feedback Loop",
		"Grounded Circuit mana restore doubled. Pulling shock mana die grants +[color=yellow]3/6[/color] bonus shock damage on next shock action this turn.",
		8, 5, _tier_pts(8),
		{1: [fl_gc_boost, fl_pull_r1],
		 2: [fl_gc_boost, fl_pull_r2]})
	_save_skill(feedback_loop, "storm_feedback_loop")

func _create_tier_9():
	print("\n-- Tier 9 -- 2 skills (Thunderhead, Stormcaller)...")

	# ── Thunderhead (Col 1, Voltaic): At turn start, apply 2/3 Static to all enemies. 2 ranks. ──
	var th_r1: Affix = _make_affix("Thunderhead I",
		"At start of each turn, apply 2 Static to all enemies.",
		Affix.Category.PROC,
		["mage", "storm", "voltaic", "static_apply", "passive"], 2.0,
		{"proc_trigger": "ON_TURN_START", "proc_effect": "apply_status",
		 "status_id": "static", "stacks": 2, "target": "all_enemies"})
	th_r1.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	_save_affix(th_r1, "thunderhead", "thunderhead_r1_affix")

	var th_r2: Affix = _make_affix("Thunderhead II",
		"At start of each turn, apply 3 Static to all enemies.",
		Affix.Category.PROC,
		["mage", "storm", "voltaic", "static_apply", "passive"], 3.0,
		{"proc_trigger": "ON_TURN_START", "proc_effect": "apply_status",
		 "status_id": "static", "stacks": 3, "target": "all_enemies"})
	th_r2.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	_save_affix(th_r2, "thunderhead", "thunderhead_r2_affix")

	var thunderhead := _make_skill(
		"storm_thunderhead", "Thunderhead",
		"At the start of each turn, apply [color=yellow]2/3[/color] [color=cyan]Static[/color] to all enemies.",
		9, 1, _tier_pts(9),
		{1: [th_r1], 2: [th_r2]})
	_save_skill(thunderhead, "storm_thunderhead")

	# ── Stormcaller (Col 4, Convergence): Static per-stack bonus +2/+3 + Chromatic Bolt chain ALL. 2 ranks. ──
	# Two affixes: MISC for per-stack override + CLASS_ACTION_CONDITIONAL for chain-all.
	var sc_stack_r1: Affix = _make_affix("Stormcaller I: Stack Bonus",
		"Static per-stack bonus increased to +2.",
		Affix.Category.MISC,
		["mage", "storm", "static_per_stack"], 2.0,
		{"static_per_stack_bonus_override": 2})
	_save_affix(sc_stack_r1, "stormcaller", "stormcaller_stack_r1_affix")

	var sc_chain_all: Affix = _make_affix("Stormcaller: Chain All",
		"Chromatic Bolt chain hits ALL enemies instead of 1.",
		Affix.Category.CLASS_ACTION_CONDITIONAL,
		["mage", "storm", "class_action_mod", "chain_all"], 0.0,
		{"chromatic_bolt_chain_all": true})
	_save_affix(sc_chain_all, "stormcaller", "stormcaller_chain_all_affix")

	var sc_stack_r2: Affix = _make_affix("Stormcaller II: Stack Bonus",
		"Static per-stack bonus increased to +3.",
		Affix.Category.MISC,
		["mage", "storm", "static_per_stack"], 3.0,
		{"static_per_stack_bonus_override": 3})
	_save_affix(sc_stack_r2, "stormcaller", "stormcaller_stack_r2_affix")

	var stormcaller := _make_skill(
		"storm_stormcaller", "Stormcaller",
		"Static per-stack bonus becomes +[color=yellow]2/3[/color]. Chromatic Bolt's chain hits ALL enemies.",
		9, 4, _tier_pts(9),
		{1: [sc_stack_r1, sc_chain_all],
		 2: [sc_stack_r2, sc_chain_all]})
	_save_skill(stormcaller, "storm_stormcaller")

func _create_tier_10():
	print("\n-- Tier 10 -- CAPSTONE (Eye of the Storm)...")

	# ── Eye of the Storm (Col 3, Capstone): Double max Static stacks + chains return to source. 1 rank. ──
	var eots_stacks: Affix = _make_affix("Eye of the Storm: Double Stacks",
		"Double max Static stacks.",
		Affix.Category.MISC,
		["mage", "storm", "capstone", "static_max_stacks"], 2.0,
		{"static_max_stacks_multiplier": 2})
	_save_affix(eots_stacks, "eye_of_the_storm", "eots_double_stacks_affix")

	var eots_return: Affix = _make_affix("Eye of the Storm: Chain Return",
		"Chain effects return to original target for an extra hit.",
		Affix.Category.MISC,
		["mage", "storm", "capstone", "chain_return"], 0.0,
		{"chain_return_to_source": true})
	_save_affix(eots_return, "eye_of_the_storm", "eots_chain_return_affix")

	var eye_of_the_storm := _make_skill(
		"storm_eye_of_the_storm", "Eye of the Storm",
		"Double max [color=cyan]Static[/color] stacks. Chain effects return to the original target for an extra hit.",
		10, 3, _tier_pts(10),
		{1: [eots_stacks, eots_return]})
	_save_skill(eye_of_the_storm, "storm_eye_of_the_storm")


# ============================================================================
# PREREQUISITE WIRING — Phase 4
# ============================================================================

func _wire_prerequisites():
	print("\n-- Wiring prerequisites for all 35 skills...")

	# Helper: wire a single prerequisite (required_rank defaults to 1)
	var wired: int = 0

	# TIER 2 (all require Spark)
	_wire(_skill_lookup["storm_arc_pulse"], ["storm_spark"])
	_wire(_skill_lookup["storm_crackling_force"], ["storm_spark"])
	_wire(_skill_lookup["storm_capacitance"], ["storm_spark"])
	wired += 3

	# TIER 3
	_wire(_skill_lookup["storm_ionize"], ["storm_arc_pulse"])
	_wire(_skill_lookup["storm_charged_strikes"], ["storm_crackling_force"])
	_wire(_skill_lookup["storm_conjure_storm_sprite"], ["storm_crackling_force"])
	_wire(_skill_lookup["storm_surge_efficiency"], ["storm_capacitance"])
	_wire(_skill_lookup["storm_polarity"], ["storm_capacitance"])
	wired += 5

	# TIER 4
	_wire(_skill_lookup["storm_static_cling"], ["storm_ionize"])
	_wire(_skill_lookup["storm_live_wire"], ["storm_ionize"])
	_wire(_skill_lookup["storm_thunderclap"], ["storm_charged_strikes"])
	_wire(_skill_lookup["storm_voltaic_surge"], ["storm_charged_strikes"])
	_wire(_skill_lookup["storm_mana_siphon"], ["storm_surge_efficiency"])
	wired += 5

	# TIER 5
	_wire(_skill_lookup["storm_voltaic_sprite"], ["storm_static_cling"])
	_wire(_skill_lookup["storm_storm_charge"], ["storm_live_wire"])
	_wire(_skill_lookup["storm_tempest_sprite"], ["storm_thunderclap"])
	_wire(_skill_lookup["storm_lightning_bolt"], ["storm_voltaic_surge"])
	_wire(_skill_lookup["storm_conduit_sprite"], ["storm_mana_siphon"])
	_wire(_skill_lookup["storm_conduit_flow"], ["storm_mana_siphon"])
	wired += 6

	# TIER 6
	_wire(_skill_lookup["storm_persistent_field"], ["storm_storm_charge"])
	_wire(_skill_lookup["storm_arc_conduit"], ["storm_storm_charge", "storm_lightning_bolt"])  # Crossover
	_wire(_skill_lookup["storm_tempest_strike"], ["storm_lightning_bolt"])
	_wire(_skill_lookup["storm_grounded_circuit"], ["storm_lightning_bolt", "storm_conduit_flow"])  # Crossover
	_wire(_skill_lookup["storm_galvanic_renewal"], ["storm_conduit_flow"])
	wired += 5

	# TIER 7
	_wire(_skill_lookup["storm_overcharge"], ["storm_persistent_field"])
	_wire(_skill_lookup["storm_chain_lightning"], ["storm_arc_conduit"])
	_wire(_skill_lookup["storm_dynamo"], ["storm_grounded_circuit"])
	_wire(_skill_lookup["storm_static_discharge"], ["storm_galvanic_renewal"])
	wired += 4

	# TIER 8
	_wire(_skill_lookup["storm_tesla_coil"], ["storm_overcharge", "storm_chain_lightning"])  # Crossover
	_wire(_skill_lookup["storm_storm_surge"], ["storm_chain_lightning"])
	_wire(_skill_lookup["storm_feedback_loop"], ["storm_dynamo", "storm_static_discharge"])  # Crossover
	wired += 3

	# TIER 9
	_wire(_skill_lookup["storm_thunderhead"], ["storm_tesla_coil"])
	_wire(_skill_lookup["storm_stormcaller"], ["storm_storm_surge", "storm_feedback_loop"])  # Crossover
	wired += 2

	# TIER 10
	_wire(_skill_lookup["storm_eye_of_the_storm"], ["storm_thunderhead", "storm_stormcaller"])  # Capstone
	wired += 1

	print("  Wired %d prerequisite links" % wired)

	# Re-save all skills with prerequisites now attached
	print("  Re-saving all skills with prerequisites...")
	for skill_id in _skill_lookup:
		var skill: SkillResource = _skill_lookup[skill_id]
		_save(skill, BASE_SKILL_DIR + skill_id + ".tres")
	print("  All skills re-saved")


func _wire(skill: SkillResource, prereq_ids: Array) -> void:
	"""Wire prerequisites onto a skill. Creates SkillPrerequisite sub-resources."""
	var prereqs: Array[SkillPrerequisite] = []
	for pid in prereq_ids:
		if not _skill_lookup.has(pid):
			print("  WARNING: prerequisite '%s' not found for '%s'" % [pid, skill.skill_id])
			continue
		var sp: SkillPrerequisite = SkillPrerequisite.new()
		sp.required_skill = _skill_lookup[pid]
		sp.required_rank = 1
		prereqs.append(sp)
	skill.prerequisites.assign(prereqs)


# ============================================================================
# SKILL TREE ASSEMBLY — Phase 4
# ============================================================================

func _build_skill_tree():
	print("\n-- Building SkillTree resource...")

	var tree: SkillTree = SkillTree.new()
	tree.tree_id = "mage_storm"
	tree.tree_name = "Storm"
	tree.description = "Master lightning magic. Three paths: Voltaic (Static application & control), Tempest (raw shock damage & chain attacks), Conduit (mana efficiency & die manipulation)."

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

	_save(tree, TREE_DIR + "mage_storm.tres")

	var total_skills: int = tree.get_all_skills().size()
	print("  SkillTree saved: %s (%d skills)" % [tree.tree_name, total_skills])

	# Per-tier counts
	for t in range(1, 11):
		var tier_skills: Array[SkillResource] = _get_tier_skills(t)
		print("    T%d: %d skills" % [t, tier_skills.size()])

	# Validation
	var warnings: Array[String] = tree.validate()
	if warnings.size() > 0:
		print("\n  Validation warnings:")
		for w in warnings:
			print("    %s" % w)
	else:
		print("  Validation passed -- no warnings!")


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
