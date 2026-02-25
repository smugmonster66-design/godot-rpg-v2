# res://editor_scripts/generate_storm_tree.gd
# Run via: Editor -> Script -> Run (Ctrl+Shift+X) with this script open.
#
# WHAT THIS DOES:
#   Creates the complete 35-skill Mage Storm skill tree.
#   All cross-references use ExtResource (save-then-load pattern).
#
# SAFE TO RE-RUN: Overwrites existing files at the same paths.
#
# FIX LOG (v2):
#   - Every _save_* helper now saves to disk then load()s back, returning
#     the disk-loaded reference. This guarantees all parent resources write
#     ExtResource refs instead of embedded SubResource snapshots.
#   - Shared resources (_static_status, _base_storm_sprite, conditions)
#     are reloaded from disk before any tier function references them.
#   - No emoji in print(). All typed arrays use .assign().
#     All Dict/Array iteration uses explicit typing.
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
var _skill_lookup: Dictionary = {}  # skill_id -> SkillResource (loaded from disk)

# Shared resources — ALL are loaded from disk after initial save
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
	print("\n" + "=".repeat(60))
	print("  GENERATING MAGE STORM TREE (35 SKILLS) — v2 ExtResource fix")
	print("=".repeat(60))

	_ensure_all_dirs()

	# Phase 1: Shared resources (status, conditions, base companion)
	_create_shared_resources()

	# Phase 2: Tiers 1-10
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

	# Phase 3: Wire prerequisites (all 35 skills exist in _skill_lookup)
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
# CORE SAVE-THEN-LOAD PATTERN
# ============================================================================
# Every save helper: save to disk, then load() back, return the loaded ref.
# This guarantees all cross-references serialize as ExtResource, not SubResource.

func _save_to_disk(resource: Resource, path: String) -> Resource:
	"""Save resource then reload from disk. Returns the disk-loaded reference."""
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
	# After save, resource_path is set on the in-memory object.
	# Store it in lookup so prereq wiring can find it with a valid path.
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
# RESOURCE CREATION HELPERS (in-memory only — no saving here)
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
	da.condition = p_condition  # must be disk-loaded ref
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
	"""p_dice_affix MUST be a disk-loaded reference (from _save_dice_affix)."""
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
		e.status_affix = p_status  # must be disk-loaded ref
	e.stack_count = p_stack_count
	e.cleanse_tags = p_cleanse_tags
	return e

func _make_chain_effect(p_name: String, p_target: int,
		p_chain_count: int, p_chain_decay: float,
		p_damage_type: int = ActionEffect.DamageType.SHOCK) -> ActionEffect:
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = p_name
	e.target = p_target
	e.effect_type = ActionEffect.EffectType.CHAIN
	e.damage_type = p_damage_type
	e.chain_count = p_chain_count
	e.chain_decay = p_chain_decay
	e.chain_can_repeat = false
	return e

func _make_summon_effect(p_name: String, p_companion: CompanionData) -> ActionEffect:
	"""p_companion MUST be a disk-loaded reference."""
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = p_name
	e.target = ActionEffect.TargetType.SELF
	e.effect_type = ActionEffect.EffectType.SUMMON_COMPANION
	e.companion_data = p_companion
	return e

func _make_action(p_id: String, p_name: String, p_desc: String,
		p_die_slots: int, p_effects: Array[ActionEffect],
		p_charge_type: int = Action.ChargeType.UNLIMITED,
		p_max_charges: int = 1) -> Action:
	"""p_effects entries MUST be disk-loaded references."""
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
	"""p_rank_affixes values MUST contain disk-loaded Affix references."""
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
	print("\n-- Creating shared resources...")

	# ── Static StatusAffix ──
	var static_res: StatusAffix = StatusAffix.new()
	static_res.status_id = "static"
	static_res.affix_name = "Static"
	static_res.description = "+1 shock damage received per stack. Batches expire independently after 2 turns."
	static_res.category = Affix.Category.MISC
	static_res.duration_type = StatusAffix.DurationType.STACK_BASED
	static_res.max_stacks = 20
	static_res.decay_style = StatusAffix.DecayStyle.NONE
	static_res.tick_timing = StatusAffix.TickTiming.START_OF_TURN
	static_res.damage_per_stack = 0
	static_res.is_debuff = true
	static_res.can_be_cleansed = true
	var static_cleanse: Array[String] = []
	static_cleanse.assign(["debuff", "shock", "static"])
	static_res.cleanse_tags = static_cleanse
	static_res.has_elemental_identity = true
	static_res.elemental_identity = ActionEffect.DamageType.SHOCK
	static_res.stat_modifier_per_stack = {"shock_damage_received_bonus": 1}
	static_res.effect_data = {"batch_duration": 2, "custom_tracker": "rolling_batch"}
	# Save then reload
	var static_path: String = STATUS_DIR + "static.tres"
	_save_to_disk(static_res, static_path)
	_static_status = load(static_path) as StatusAffix
	_created_statuses += 1
	print("  Static StatusAffix -> disk-loaded (path: %s)" % _static_status.resource_path)

	# ── Shared DiceAffixConditions — save then reload into member vars ──
	var cond_shock: DiceAffixCondition = _make_condition(
		DiceAffixCondition.Type.SELF_ELEMENT_IS, 0.0, false, "SHOCK")
	_cond_self_element_shock = _save_condition(cond_shock, "cond_self_element_shock")

	var cond_neigh: DiceAffixCondition = _make_condition(
		DiceAffixCondition.Type.NEIGHBOR_HAS_ELEMENT, 0.0, false, "SHOCK")
	_cond_neighbor_shock = _save_condition(cond_neigh, "cond_neighbor_shock")

	var cond_neigh_inv: DiceAffixCondition = _make_condition(
		DiceAffixCondition.Type.NEIGHBOR_HAS_ELEMENT, 0.0, true, "SHOCK")
	_cond_neighbor_shock_inverted = _save_condition(cond_neigh_inv, "cond_neighbor_not_shock")

	var cond_static: DiceAffixCondition = _make_condition(
		DiceAffixCondition.Type.TARGET_HAS_STATUS, 0.0, false, "", "static")
	_cond_target_has_static = _save_condition(cond_static, "cond_target_has_static")

	print("  4 DiceAffixConditions disk-loaded")

	# ── Base Storm Sprite CompanionData ──
	var sprite: CompanionData = CompanionData.new()
	sprite.companion_id = &"storm_sprite"
	sprite.companion_name = "Storm Sprite"
	sprite.description = "A crackling orb of lightning that zaps a random enemy each turn."
	sprite.companion_type = CompanionData.CompanionType.SUMMON
	sprite.base_max_hp = 15
	sprite.hp_scaling = CompanionData.HPScaling.PLAYER_LEVEL
	sprite.hp_scaling_value = 2.0
	sprite.trigger = CompanionData.CompanionTrigger.PLAYER_TURN_END
	sprite.target_rule = CompanionData.CompanionTarget.RANDOM_ENEMY
	sprite.cooldown_turns = 0
	sprite.uses_per_combat = 0
	sprite.fires_on_first_turn = true
	sprite.has_taunt = false
	sprite.duration_turns = 0

	# Base zap effect — save to disk FIRST
	var sprite_zap: ActionEffect = _make_action_effect(
		"Sprite: Zap",
		ActionEffect.TargetType.SINGLE_ENEMY,
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.SHOCK,
		4, 1.0, 0)
	var loaded_zap: ActionEffect = _save_effect(sprite_zap, "sprite_zap_effect")

	# Assign the LOADED zap to sprite, then save sprite
	var sprite_effs: Array[ActionEffect] = []
	sprite_effs.assign([loaded_zap])
	sprite.action_effects = sprite_effs

	var sprite_path: String = COMPANION_DIR + "storm_sprite.tres"
	_save_to_disk(sprite, sprite_path)
	_base_storm_sprite = load(sprite_path) as CompanionData
	_created_companions += 1
	print("  Storm Sprite disk-loaded (path: %s)" % _base_storm_sprite.resource_path)

	print("  Shared resources complete\n")


# ============================================================================
# TIER 1 — Spark
# ============================================================================

func _create_tier_1():
	print("\n-- Tier 1 -- Spark...")

	var spark_elem: Affix = _save_affix(
		_make_affix("Spark: Shock Unlock", "Unlocks Shock mana element.",
			Affix.Category.MANA_ELEMENT_UNLOCK,
			["mage", "storm", "element_unlock"], 0.0, {"element": "SHOCK"}),
		"spark", "spark_element_unlock")

	var spark_size: Affix = _save_affix(
		_make_affix("Spark: D4 Unlock", "Unlocks D4 shock mana die.",
			Affix.Category.MANA_SIZE_UNLOCK,
			["mage", "storm", "size_unlock"], 0.0, {"die_size": 4}),
		"spark", "spark_size_unlock")

	# Rank 1: 1 Static
	var spark_eff_r1: ActionEffect = _save_effect(
		_make_action_effect("Spark: Apply Static I",
			ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK,
			0, 1.0, 0, 0, 1.0, false,
			_static_status, 1),
		"spark_apply_static_r1")

	var spark_ca_r1: Affix = _save_affix(
		_make_affix("Spark: Chromatic Bolt Static I",
			"Chromatic Bolt applies 1 Static (shock die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "storm", "class_action_mod", "static_apply"], 0.0,
			{"action_effect": spark_eff_r1, "shock_die_condition": true}),
		"spark", "spark_ca_r1_affix")

	# Rank 2: 2 Static
	var spark_eff_r2: ActionEffect = _save_effect(
		_make_action_effect("Spark: Apply Static II",
			ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK,
			0, 1.0, 0, 0, 1.0, false,
			_static_status, 2),
		"spark_apply_static_r2")

	var spark_ca_r2: Affix = _save_affix(
		_make_affix("Spark: Chromatic Bolt Static II",
			"Chromatic Bolt applies 2 Static (shock die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "storm", "class_action_mod", "static_apply"], 0.0,
			{"action_effect": spark_eff_r2, "shock_die_condition": true}),
		"spark", "spark_ca_r2_affix")

	# Rank 3: 3 Static
	var spark_eff_r3: ActionEffect = _save_effect(
		_make_action_effect("Spark: Apply Static III",
			ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK,
			0, 1.0, 0, 0, 1.0, false,
			_static_status, 3),
		"spark_apply_static_r3")

	var spark_ca_r3: Affix = _save_affix(
		_make_affix("Spark: Chromatic Bolt Static III",
			"Chromatic Bolt applies 3 Static (shock die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "storm", "class_action_mod", "static_apply"], 0.0,
			{"action_effect": spark_eff_r3, "shock_die_condition": true}),
		"spark", "spark_ca_r3_affix")

	_save_skill(
		_make_skill("storm_spark", "Spark",
			"Unlock [color=yellow]Shock[/color] mana. Chromatic Bolt applies [color=yellow]1/2/3[/color] [color=cyan]Static[/color] on hit (requires shock die).",
			1, 3, _tier_pts(1),
			{1: [spark_elem, spark_size, spark_ca_r1],
			2: [spark_elem, spark_size, spark_ca_r2],
			3: [spark_elem, spark_size, spark_ca_r3]}),
		"storm_spark")


# ============================================================================
# TIER 2 — Arc Pulse, Crackling Force, Capacitance
# ============================================================================

func _create_tier_2():
	print("\n-- Tier 2 -- 3 skills...")

	# ── Arc Pulse (Col 1, Voltaic) ──
	var da_arc_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Pulse I: Static on Use", "Apply 1 Static on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 1}, _cond_self_element_shock),
		"da_arc_pulse_r1")
	var ap_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Pulse I", "Shock dice apply 1 Static on use.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_arc_r1),
		"arc_pulse", "arc_pulse_r1_affix")

	var da_arc_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Pulse II: Static on Use", "Apply 2 Static on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 2}, _cond_self_element_shock),
		"da_arc_pulse_r2")
	var ap_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Pulse II", "Shock dice apply 2 Static on use.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_arc_r2),
		"arc_pulse", "arc_pulse_r2_affix")

	var da_arc_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Pulse III: Static on Use", "Apply 3 Static on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 3}, _cond_self_element_shock),
		"da_arc_pulse_r3")
	var ap_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Pulse III", "Shock dice apply 3 Static on use.",
			["mage", "storm", "mana_die_affix", "static_apply", "voltaic"], da_arc_r3),
		"arc_pulse", "arc_pulse_r3_affix")

	_save_skill(
		_make_skill("storm_arc_pulse", "Arc Pulse",
			"Shock mana dice apply [color=yellow]1/2/3[/color] [color=cyan]Static[/color] on use.",
			2, 1, _tier_pts(2), {1: [ap_r1], 2: [ap_r2], 3: [ap_r3]}),
		"storm_arc_pulse")

	# ── Crackling Force (Col 3, Tempest) ──
	var cf_r1: Affix = _save_affix(
		_make_affix("Crackling Force I", "Shock damage x1.05.",
			Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
			["mage", "storm", "shock_mult", "tempest"], 1.05, {"element": "SHOCK"}),
		"crackling_force", "crackling_force_r1_affix")
	var cf_r2: Affix = _save_affix(
		_make_affix("Crackling Force II", "Shock damage x1.10.",
			Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
			["mage", "storm", "shock_mult", "tempest"], 1.10, {"element": "SHOCK"}),
		"crackling_force", "crackling_force_r2_affix")
	var cf_r3: Affix = _save_affix(
		_make_affix("Crackling Force III", "Shock damage x1.15.",
			Affix.Category.ELEMENTAL_DAMAGE_MULTIPLIER,
			["mage", "storm", "shock_mult", "tempest"], 1.15, {"element": "SHOCK"}),
		"crackling_force", "crackling_force_r3_affix")

	_save_skill(
		_make_skill("storm_crackling_force", "Crackling Force",
			"Shock damage x[color=yellow]1.05/1.10/1.15[/color].",
			2, 3, _tier_pts(2), {1: [cf_r1], 2: [cf_r2], 3: [cf_r3]}),
		"storm_crackling_force")

	# ── Capacitance (Col 5, Conduit) ──
	var cap_r1: Affix = _save_affix(
		_make_affix("Capacitance I", "+2 Intellect.",
			Affix.Category.INTELLECT_BONUS, ["mage", "storm", "conduit", "stat"], 2.0),
		"capacitance", "capacitance_r1_affix")
	var cap_r2: Affix = _save_affix(
		_make_affix("Capacitance II", "+4 Intellect.",
			Affix.Category.INTELLECT_BONUS, ["mage", "storm", "conduit", "stat"], 4.0),
		"capacitance", "capacitance_r2_affix")
	var cap_r3: Affix = _save_affix(
		_make_affix("Capacitance III", "+6 Intellect.",
			Affix.Category.INTELLECT_BONUS, ["mage", "storm", "conduit", "stat"], 6.0),
		"capacitance", "capacitance_r3_affix")

	_save_skill(
		_make_skill("storm_capacitance", "Capacitance",
			"+[color=yellow]2/4/6[/color] Intellect.",
			2, 5, _tier_pts(2), {1: [cap_r1], 2: [cap_r2], 3: [cap_r3]}),
		"storm_capacitance")


# ============================================================================
# TIER 3 — Ionize, Charged Strikes, Conjure Storm Sprite, Surge Efficiency, Polarity
# ============================================================================

func _create_tier_3():
	print("\n-- Tier 3 -- 5 skills...")

	# ── Ionize (Col 0, Voltaic) ──
	var ion_r1: Affix = _save_affix(
		_make_affix("Ionize I", "Pulling shock die applies 1 Static.",
			Affix.Category.PROC, ["mage", "storm", "voltaic", "static_apply", "on_pull"], 1.0,
			{"proc_trigger": "ON_MANA_PULL", "proc_effect": "apply_status",
			"status_id": "static", "stacks": 1, "target": "random_enemy", "element_condition": "SHOCK"}),
		"ionize", "ionize_r1_affix")
	var ion_r2: Affix = _save_affix(
		_make_affix("Ionize II", "Pulling shock die applies 2 Static.",
			Affix.Category.PROC, ["mage", "storm", "voltaic", "static_apply", "on_pull"], 1.0,
			{"proc_trigger": "ON_MANA_PULL", "proc_effect": "apply_status",
			"status_id": "static", "stacks": 2, "target": "random_enemy", "element_condition": "SHOCK"}),
		"ionize", "ionize_r2_affix")
	var ion_r3: Affix = _save_affix(
		_make_affix("Ionize III", "Pulling shock die applies 3 Static.",
			Affix.Category.PROC, ["mage", "storm", "voltaic", "static_apply", "on_pull"], 1.0,
			{"proc_trigger": "ON_MANA_PULL", "proc_effect": "apply_status",
			"status_id": "static", "stacks": 3, "target": "random_enemy", "element_condition": "SHOCK"}),
		"ionize", "ionize_r3_affix")

	_save_skill(
		_make_skill("storm_ionize", "Ionize",
			"Pulling a shock mana die applies [color=yellow]1/2/3[/color] [color=cyan]Static[/color] to a random enemy.",
			3, 0, _tier_pts(3), {1: [ion_r1], 2: [ion_r2], 3: [ion_r3]}),
		"storm_ionize")

	# ── Charged Strikes (Col 2, Tempest) ──
	var cs_r1: Affix = _save_affix(
		_make_affix("Charged Strikes I", "+2 shock damage.",
			Affix.Category.SHOCK_DAMAGE_BONUS, ["mage", "storm", "tempest", "shock_flat"], 2.0),
		"charged_strikes", "charged_strikes_r1_affix")
	var cs_r2: Affix = _save_affix(
		_make_affix("Charged Strikes II", "+4 shock damage.",
			Affix.Category.SHOCK_DAMAGE_BONUS, ["mage", "storm", "tempest", "shock_flat"], 4.0),
		"charged_strikes", "charged_strikes_r2_affix")
	var cs_r3: Affix = _save_affix(
		_make_affix("Charged Strikes III", "+6 shock damage.",
			Affix.Category.SHOCK_DAMAGE_BONUS, ["mage", "storm", "tempest", "shock_flat"], 6.0),
		"charged_strikes", "charged_strikes_r3_affix")

	_save_skill(
		_make_skill("storm_charged_strikes", "Charged Strikes",
			"+[color=yellow]2/4/6[/color] flat shock damage.",
			3, 2, _tier_pts(3), {1: [cs_r1], 2: [cs_r2], 3: [cs_r3]}),
		"storm_charged_strikes")

	# ── Conjure Storm Sprite (Col 3) ──
	# CRITICAL: _base_storm_sprite is already disk-loaded from _create_shared_resources
	var summon_eff: ActionEffect = _save_effect(
		_make_summon_effect("Conjure: Summon Storm Sprite", _base_storm_sprite),
		"conjure_storm_sprite_effect")

	var shock_only: Array[int] = [6]
	var sprite_effs: Array[ActionEffect] = []
	sprite_effs.assign([summon_eff])
	var sprite_act: Action = _save_action(
		_make_action_with_elements(
			"storm_conjure_storm_sprite", "Conjure Storm Sprite",
			"Summon a Storm Sprite that zaps enemies each turn.",
			1, sprite_effs, shock_only,
			Action.ChargeType.LIMITED_PER_COMBAT, 1),
		"conjure_storm_sprite_action")

	# Create grant affix with loaded action reference
	var grant_affix_mem: Affix = _make_affix("Conjure Storm Sprite: Grant",
		"Grants Conjure Storm Sprite action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "granted_action", "summon"], 0.0,
		{"action_id": "storm_conjure_storm_sprite"})
	grant_affix_mem.granted_action = sprite_act  # disk-loaded Action
	var sprite_grant: Affix = _save_affix(grant_affix_mem,
		"conjure_storm_sprite", "conjure_storm_sprite_r1_affix")

	_save_skill(
		_make_skill("storm_conjure_storm_sprite", "Conjure Storm Sprite",
			"[color=yellow]ACTION:[/color] 1 shock die -> summon a [color=cyan]Storm Sprite[/color].",
			3, 3, _tier_pts(3), {1: [sprite_grant]}),
		"storm_conjure_storm_sprite")

	# ── Surge Efficiency (Col 4, Conduit) ──
	var se_r1: Affix = _save_affix(
		_make_affix("Surge Efficiency I", "Shock pull cost -1.",
			Affix.Category.MISC, ["mage", "storm", "conduit", "mana_pull_cost_reduction"], 1.0,
			{"element": "SHOCK"}),
		"surge_efficiency", "surge_efficiency_r1_affix")
	var se_r2: Affix = _save_affix(
		_make_affix("Surge Efficiency II", "Shock pull cost -2.",
			Affix.Category.MISC, ["mage", "storm", "conduit", "mana_pull_cost_reduction"], 2.0,
			{"element": "SHOCK"}),
		"surge_efficiency", "surge_efficiency_r2_affix")
	var se_r3: Affix = _save_affix(
		_make_affix("Surge Efficiency III", "Shock pull cost -3.",
			Affix.Category.MISC, ["mage", "storm", "conduit", "mana_pull_cost_reduction"], 3.0,
			{"element": "SHOCK"}),
		"surge_efficiency", "surge_efficiency_r3_affix")

	_save_skill(
		_make_skill("storm_surge_efficiency", "Surge Efficiency",
			"Shock mana die pull cost -[color=yellow]1/2/3[/color].",
			3, 4, _tier_pts(3), {1: [se_r1], 2: [se_r2], 3: [se_r3]}),
		"storm_surge_efficiency")

	# ── Polarity (Col 6, Conduit) ──
	var da_pol_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Polarity I: Spacing Bonus", "+1 if no adjacent shock die.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0, {},
			_cond_neighbor_shock_inverted),
		"da_polarity_r1")
	var pol_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Polarity I", "+1 value if no adjacent shock die.",
			["mage", "storm", "conduit", "mana_die_affix", "positional", "spacing"], da_pol_r1),
		"polarity", "polarity_r1_affix")

	var da_pol_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Polarity II: Spacing Bonus", "+2 if no adjacent shock die.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0, {},
			_cond_neighbor_shock_inverted),
		"da_polarity_r2")
	var pol_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Polarity II", "+2 value if no adjacent shock die.",
			["mage", "storm", "conduit", "mana_die_affix", "positional", "spacing"], da_pol_r2),
		"polarity", "polarity_r2_affix")

	var da_pol_r3: DiceAffix = _save_dice_affix(
		_make_dice_affix("Polarity III: Spacing Bonus", "+3 if no adjacent shock die.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 3.0, {},
			_cond_neighbor_shock_inverted),
		"da_polarity_r3")
	var pol_r3: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Polarity III", "+3 value if no adjacent shock die.",
			["mage", "storm", "conduit", "mana_die_affix", "positional", "spacing"], da_pol_r3),
		"polarity", "polarity_r3_affix")

	_save_skill(
		_make_skill("storm_polarity", "Polarity",
			"Shock dice gain +[color=yellow]1/2/3[/color] value if no adjacent die is also Shock.",
			3, 6, _tier_pts(3), {1: [pol_r1], 2: [pol_r2], 3: [pol_r3]}),
		"storm_polarity")


# ============================================================================
# TIER 4 — Static Cling, Live Wire, Thunderclap, Voltaic Surge, Mana Siphon
# ============================================================================

func _create_tier_4():
	print("\n-- Tier 4 -- 5 skills...")

	# ── Static Cling (Col 0, Voltaic) ──
	var sc_r1: Affix = _save_affix(
		_make_affix("Static Cling I", "Static duration +1 turn.",
			Affix.Category.MISC, ["mage", "storm", "voltaic", "static_duration"], 1.0,
			{"static_duration_bonus": 1}),
		"static_cling", "static_cling_r1_affix")
	var sc_r2: Affix = _save_affix(
		_make_affix("Static Cling II", "Static duration +2 turns.",
			Affix.Category.MISC, ["mage", "storm", "voltaic", "static_duration"], 2.0,
			{"static_duration_bonus": 2}),
		"static_cling", "static_cling_r2_affix")
	var sc_r3: Affix = _save_affix(
		_make_affix("Static Cling III", "Static duration +3 turns.",
			Affix.Category.MISC, ["mage", "storm", "voltaic", "static_duration"], 3.0,
			{"static_duration_bonus": 3}),
		"static_cling", "static_cling_r3_affix")

	_save_skill(
		_make_skill("storm_static_cling", "Static Cling",
			"Static batch duration extended to [color=yellow]3/4/5[/color] turns.",
			4, 0, _tier_pts(4), {1: [sc_r1], 2: [sc_r2], 3: [sc_r3]}),
		"storm_static_cling")

	# ── Live Wire (Col 1, Voltaic) ──
	var da_lw_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Live Wire I: Bonus Static", "+1 Static if target has Static.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 1, "element_condition": "SHOCK"},
			_cond_target_has_static),
		"da_live_wire_r1")
	var lw_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Live Wire I", "+1 bonus Static if target already has Static.",
			["mage", "storm", "voltaic", "mana_die_affix", "static_apply", "snowball"], da_lw_r1),
		"live_wire", "live_wire_r1_affix")

	var da_lw_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Live Wire II: Bonus Static", "+2 Static if target has Static.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.GRANT_STATUS_EFFECT, 1.0,
			{"status_id": "static", "stacks": 2, "element_condition": "SHOCK"},
			_cond_target_has_static),
		"da_live_wire_r2")
	var lw_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Live Wire II", "+2 bonus Static if target already has Static.",
			["mage", "storm", "voltaic", "mana_die_affix", "static_apply", "snowball"], da_lw_r2),
		"live_wire", "live_wire_r2_affix")

	_save_skill(
		_make_skill("storm_live_wire", "Live Wire",
			"Shock mana dice apply [color=yellow]1/2[/color] bonus [color=cyan]Static[/color] on use if target already has Static.",
			4, 1, _tier_pts(4), {1: [lw_r1], 2: [lw_r2]}),
		"storm_live_wire")

	# ── Thunderclap (Col 2, Tempest) ──
	var tc_dmg: ActionEffect = _save_effect(
		_make_action_effect("Thunderclap: Damage",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 0, 1.2, 2),
		"thunderclap_damage")
	var tc_status: ActionEffect = _save_effect(
		_make_action_effect("Thunderclap: Apply Static",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK, 0, 1.0, 0, 0, 1.0, false,
			_static_status, 3),
		"thunderclap_static")

	var tc_effs: Array[ActionEffect] = []
	tc_effs.assign([tc_dmg, tc_status])
	var shock_only: Array[int] = [6]
	var tc_act: Action = _save_action(
		_make_action_with_elements("storm_thunderclap", "Thunderclap",
			"Shock strike for x1.2 damage and apply 3 Static.",
			2, tc_effs, shock_only, Action.ChargeType.LIMITED_PER_TURN, 1),
		"thunderclap_action")

	var tc_grant_mem: Affix = _make_affix("Thunderclap: Grant Action",
		"Grants Thunderclap action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "tempest", "granted_action"], 0.0,
		{"action_id": "storm_thunderclap"})
	tc_grant_mem.granted_action = tc_act
	var tc_grant: Affix = _save_affix(tc_grant_mem, "thunderclap", "thunderclap_r1_affix")

	_save_skill(
		_make_skill("storm_thunderclap", "Thunderclap",
			"[color=yellow]ACTION:[/color] 2 dice -> [color=cyan]shock[/color] x1.2 + 3 [color=cyan]Static[/color]. Per turn.",
			4, 2, _tier_pts(4), {1: [tc_grant]}),
		"storm_thunderclap")

	# ── Voltaic Surge (Col 3, Tempest) ──
	var vs_r1: Affix = _save_affix(
		_make_affix("Voltaic Surge I", "Shock x1.01 per Static stack.",
			Affix.Category.STATUS_DAMAGE_MULTIPLIER,
			["mage", "storm", "tempest", "static_synergy"], 1.01,
			{"status_id": "static", "element": "SHOCK", "per_stack": true}),
		"voltaic_surge", "voltaic_surge_r1_affix")
	var vs_r2: Affix = _save_affix(
		_make_affix("Voltaic Surge II", "Shock x1.02 per Static stack.",
			Affix.Category.STATUS_DAMAGE_MULTIPLIER,
			["mage", "storm", "tempest", "static_synergy"], 1.02,
			{"status_id": "static", "element": "SHOCK", "per_stack": true}),
		"voltaic_surge", "voltaic_surge_r2_affix")
	var vs_r3: Affix = _save_affix(
		_make_affix("Voltaic Surge III", "Shock x1.03 per Static stack.",
			Affix.Category.STATUS_DAMAGE_MULTIPLIER,
			["mage", "storm", "tempest", "static_synergy"], 1.03,
			{"status_id": "static", "element": "SHOCK", "per_stack": true}),
		"voltaic_surge", "voltaic_surge_r3_affix")

	_save_skill(
		_make_skill("storm_voltaic_surge", "Voltaic Surge",
			"Shock damage x[color=yellow]1.01/1.02/1.03[/color] per [color=cyan]Static[/color] stack on target.",
			4, 3, _tier_pts(4), {1: [vs_r1], 2: [vs_r2], 3: [vs_r3]}),
		"storm_voltaic_surge")

	# ── Mana Siphon (Col 5, Conduit) ──
	var ms_r1_mem: Affix = _make_affix("Mana Siphon I", "On shock kill, restore 3 mana.",
		Affix.Category.PROC, ["mage", "storm", "conduit", "mana_restore", "on_kill"], 3.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "mana_restore", "amount": 3, "element_condition": "SHOCK"})
	ms_r1_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var ms_r1: Affix = _save_affix(ms_r1_mem, "mana_siphon", "mana_siphon_r1_affix")

	var ms_r2_mem: Affix = _make_affix("Mana Siphon II", "On shock kill, restore 5 mana.",
		Affix.Category.PROC, ["mage", "storm", "conduit", "mana_restore", "on_kill"], 5.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "mana_restore", "amount": 5, "element_condition": "SHOCK"})
	ms_r2_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var ms_r2: Affix = _save_affix(ms_r2_mem, "mana_siphon", "mana_siphon_r2_affix")

	var ms_r3_mem: Affix = _make_affix("Mana Siphon III", "On shock kill, restore 7 mana.",
		Affix.Category.PROC, ["mage", "storm", "conduit", "mana_restore", "on_kill"], 7.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "mana_restore", "amount": 7, "element_condition": "SHOCK"})
	ms_r3_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var ms_r3: Affix = _save_affix(ms_r3_mem, "mana_siphon", "mana_siphon_r3_affix")

	_save_skill(
		_make_skill("storm_mana_siphon", "Mana Siphon",
			"On shock kill, restore [color=yellow]3/5/7[/color] mana.",
			4, 5, _tier_pts(4), {1: [ms_r1], 2: [ms_r2], 3: [ms_r3]}),
		"storm_mana_siphon")


# ============================================================================
# TIER 5 — Voltaic Sprite, Storm Charge, Tempest Sprite, Lightning Bolt, Conduit Sprite, Conduit Flow
# ============================================================================

func _create_tier_5():
	print("\n-- Tier 5 -- 6 skills...")

	# ── Voltaic Sprite (Col 0) ──
	var vs_eff_r1: ActionEffect = _save_effect(
		_make_action_effect("Sprite: Apply Static (Voltaic I)",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK, 0, 1.0, 0, 0, 1.0, false, _static_status, 2),
		"voltaic_sprite_static_r1")
	var vs_spr_r1: Affix = _save_affix(
		_make_affix("Voltaic Sprite I", "Storm Sprite applies 2 Static per trigger.",
			Affix.Category.MISC, ["mage", "storm", "voltaic", "storm_sprite_upgrade"], 0.0,
			{"sprite_mod_type": "voltaic", "action_effect": vs_eff_r1, "dual_trigger": false}),
		"voltaic_sprite", "voltaic_sprite_r1_affix")

	var vs_eff_r2: ActionEffect = _save_effect(
		_make_action_effect("Sprite: Apply Static (Voltaic II)",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK, 0, 1.0, 0, 0, 1.0, false, _static_status, 3),
		"voltaic_sprite_static_r2")
	var vs_spr_r2: Affix = _save_affix(
		_make_affix("Voltaic Sprite II", "Storm Sprite applies 3 Static per trigger. Also fires on turn start.",
			Affix.Category.MISC, ["mage", "storm", "voltaic", "storm_sprite_upgrade"], 0.0,
			{"sprite_mod_type": "voltaic", "action_effect": vs_eff_r2, "dual_trigger": true}),
		"voltaic_sprite", "voltaic_sprite_r2_affix")

	_save_skill(
		_make_skill("storm_voltaic_sprite", "Voltaic Sprite",
			"Storm Sprite applies [color=yellow]2/3[/color] [color=cyan]Static[/color] per trigger. Rank 2: also fires on turn start.",
			5, 0, _tier_pts(5), {1: [vs_spr_r1], 2: [vs_spr_r2]}),
		"storm_voltaic_sprite")

	# ── Storm Charge (Col 1, Voltaic) ──
	var sch_r1: Affix = _save_affix(
		_make_affix("Storm Charge I", "Applying Static to 10+ target spreads 1 to others.",
			Affix.Category.PROC, ["mage", "storm", "voltaic", "static_spread"], 1.0,
			{"proc_trigger": "ON_STATUS_APPLIED", "proc_effect": "spread_static",
			"threshold": 10, "stacks": 1, "target": "all_other_enemies", "status_id": "static"}),
		"storm_charge", "storm_charge_r1_affix")
	var sch_r2: Affix = _save_affix(
		_make_affix("Storm Charge II", "Applying Static to 10+ target spreads 2 to others.",
			Affix.Category.PROC, ["mage", "storm", "voltaic", "static_spread"], 2.0,
			{"proc_trigger": "ON_STATUS_APPLIED", "proc_effect": "spread_static",
			"threshold": 10, "stacks": 2, "target": "all_other_enemies", "status_id": "static"}),
		"storm_charge", "storm_charge_r2_affix")
	var sch_r3: Affix = _save_affix(
		_make_affix("Storm Charge III", "Applying Static to 10+ target spreads 3 to others.",
			Affix.Category.PROC, ["mage", "storm", "voltaic", "static_spread"], 3.0,
			{"proc_trigger": "ON_STATUS_APPLIED", "proc_effect": "spread_static",
			"threshold": 10, "stacks": 3, "target": "all_other_enemies", "status_id": "static"}),
		"storm_charge", "storm_charge_r3_affix")

	_save_skill(
		_make_skill("storm_storm_charge", "Storm Charge",
			"Applying Static to a target with 10+ stacks also applies [color=yellow]1/2/3[/color] Static to all other enemies.",
			5, 1, _tier_pts(5), {1: [sch_r1], 2: [sch_r2], 3: [sch_r3]}),
		"storm_storm_charge")

	# ── Tempest Sprite (Col 2) ──
	var ts_chain_r1: ActionEffect = _save_effect(
		_make_chain_effect("Sprite: Chain Zap (Tempest I)",
			ActionEffect.TargetType.SINGLE_ENEMY, 1, 1.0),
		"tempest_sprite_chain_r1")
	var ts_spr_r1: Affix = _save_affix(
		_make_affix("Tempest Sprite I", "Storm Sprite's damage chains to 1 enemy.",
			Affix.Category.MISC, ["mage", "storm", "tempest", "storm_sprite_upgrade"], 0.0,
			{"sprite_mod_type": "tempest", "action_effect": ts_chain_r1, "on_death_aoe": false}),
		"tempest_sprite", "tempest_sprite_r1_affix")

	var ts_chain_r2: ActionEffect = _save_effect(
		_make_chain_effect("Sprite: Chain Zap (Tempest II)",
			ActionEffect.TargetType.SINGLE_ENEMY, 2, 1.0),
		"tempest_sprite_chain_r2")
	var ts_death: ActionEffect = _save_effect(
		_make_action_effect("Sprite: Death Burst",
			ActionEffect.TargetType.ALL_ENEMIES, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 12, 1.0, 0),
		"tempest_sprite_death_burst")
	var ts_spr_r2: Affix = _save_affix(
		_make_affix("Tempest Sprite II", "Storm Sprite chains to 2 enemies. Explodes on death for AoE shock.",
			Affix.Category.MISC, ["mage", "storm", "tempest", "storm_sprite_upgrade"], 0.0,
			{"sprite_mod_type": "tempest", "action_effect": ts_chain_r2,
			"on_death_aoe": true, "death_effect": ts_death}),
		"tempest_sprite", "tempest_sprite_r2_affix")

	_save_skill(
		_make_skill("storm_tempest_sprite", "Tempest Sprite",
			"Storm Sprite's damage chains to [color=yellow]1/2[/color] enemies. Rank 2: explodes on death for AoE shock.",
			5, 2, _tier_pts(5), {1: [ts_spr_r1], 2: [ts_spr_r2]}),
		"storm_tempest_sprite")

	# ── Lightning Bolt (Col 3) ──
	var lb_dmg: ActionEffect = _save_effect(
		_make_action_effect("Lightning Bolt: Damage",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 0, 1.5, 2),
		"lightning_bolt_damage")
	var lb_chain_mem: ActionEffect = _make_chain_effect("Lightning Bolt: Chain",
		ActionEffect.TargetType.SINGLE_ENEMY, 1, 0.5)
	var lb_chain: ActionEffect = _save_effect(lb_chain_mem, "lightning_bolt_chain")

	var shock_only: Array[int] = [6]
	var lb_effs: Array[ActionEffect] = []
	lb_effs.assign([lb_dmg, lb_chain])
	var lb_act: Action = _save_action(
		_make_action_with_elements("storm_lightning_bolt", "Lightning Bolt",
			"Heavy shock strike, chains to 1 enemy for 50% damage.",
			2, lb_effs, shock_only, Action.ChargeType.LIMITED_PER_TURN, 1),
		"lightning_bolt_action")

	var lb_grant_mem: Affix = _make_affix("Lightning Bolt: Grant Action",
		"Grants Lightning Bolt action.",
		Affix.Category.NEW_ACTION,
		["mage", "storm", "tempest", "granted_action", "chain"], 0.0,
		{"action_id": "storm_lightning_bolt"})
	lb_grant_mem.granted_action = lb_act
	var lb_grant: Affix = _save_affix(lb_grant_mem, "lightning_bolt", "lightning_bolt_r1_affix")

	_save_skill(
		_make_skill("storm_lightning_bolt", "Lightning Bolt",
			"[color=yellow]ACTION:[/color] 2 dice -> [color=cyan]shock[/color] x1.5, chain to 1 enemy for 50%.",
			5, 3, _tier_pts(5), {1: [lb_grant]}),
		"storm_lightning_bolt")

	# ── Conduit Sprite (Col 4) ──
	var cs_mana_r1_mem: ActionEffect = _make_action_effect("Sprite: Mana Pulse (Conduit I)",
		ActionEffect.TargetType.SELF, ActionEffect.EffectType.MANA_MANIPULATE,
		ActionEffect.DamageType.SHOCK)
	cs_mana_r1_mem.mana_amount = 2
	cs_mana_r1_mem.mana_uses_dice = false
	var cs_mana_r1: ActionEffect = _save_effect(cs_mana_r1_mem, "conduit_sprite_mana_r1")
	var cs_spr_r1: Affix = _save_affix(
		_make_affix("Conduit Sprite I", "Storm Sprite restores 2 mana per trigger instead of dealing damage.",
			Affix.Category.MISC, ["mage", "storm", "conduit", "storm_sprite_upgrade"], 0.0,
			{"sprite_mod_type": "conduit", "action_effect": cs_mana_r1, "free_die_interval": 0}),
		"conduit_sprite", "conduit_sprite_r1_affix")

	var cs_mana_r2_mem: ActionEffect = _make_action_effect("Sprite: Mana Pulse (Conduit II)",
		ActionEffect.TargetType.SELF, ActionEffect.EffectType.MANA_MANIPULATE,
		ActionEffect.DamageType.SHOCK)
	cs_mana_r2_mem.mana_amount = 3
	cs_mana_r2_mem.mana_uses_dice = false
	var cs_mana_r2: ActionEffect = _save_effect(cs_mana_r2_mem, "conduit_sprite_mana_r2")
	var cs_spr_r2: Affix = _save_affix(
		_make_affix("Conduit Sprite II", "Storm Sprite restores 3 mana per trigger. Grants free shock die every 2 turns.",
			Affix.Category.MISC, ["mage", "storm", "conduit", "storm_sprite_upgrade"], 0.0,
			{"sprite_mod_type": "conduit", "action_effect": cs_mana_r2, "free_die_interval": 2}),
		"conduit_sprite", "conduit_sprite_r2_affix")

	_save_skill(
		_make_skill("storm_conduit_sprite", "Conduit Sprite",
			"Storm Sprite restores [color=yellow]2/3[/color] mana per trigger instead of dealing damage. Rank 2: also grants a free shock die every 2 turns.",
			5, 4, _tier_pts(5), {1: [cs_spr_r1], 2: [cs_spr_r2]}),
		"storm_conduit_sprite")

	# ── Conduit Flow (Col 5) ──
	var cf_size: Affix = _save_affix(
		_make_affix("Conduit Flow: D6 Unlock", "Unlocks D6 shock mana die.",
			Affix.Category.MANA_SIZE_UNLOCK,
			["mage", "storm", "conduit", "size_unlock"], 0.0, {"die_size": 6}),
		"conduit_flow", "conduit_flow_size_unlock")

	var cf_r1_mem: Affix = _make_affix("Conduit Flow I", "+1 mana regen per turn.",
		Affix.Category.PER_TURN, ["mage", "storm", "conduit", "mana_regen"], 1.0,
		{"per_turn_type": "mana_regen"})
	cf_r1_mem.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	var cf_r1: Affix = _save_affix(cf_r1_mem, "conduit_flow", "conduit_flow_r1_regen_affix")

	var cf_r2_mem: Affix = _make_affix("Conduit Flow II", "+2 mana regen per turn.",
		Affix.Category.PER_TURN, ["mage", "storm", "conduit", "mana_regen"], 2.0,
		{"per_turn_type": "mana_regen"})
	cf_r2_mem.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	var cf_r2: Affix = _save_affix(cf_r2_mem, "conduit_flow", "conduit_flow_r2_regen_affix")

	var cf_r3_mem: Affix = _make_affix("Conduit Flow III", "+3 mana regen per turn.",
		Affix.Category.PER_TURN, ["mage", "storm", "conduit", "mana_regen"], 3.0,
		{"per_turn_type": "mana_regen"})
	cf_r3_mem.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	var cf_r3: Affix = _save_affix(cf_r3_mem, "conduit_flow", "conduit_flow_r3_regen_affix")

	_save_skill(
		_make_skill("storm_conduit_flow", "Conduit Flow",
			"Unlock D6 shock mana die. +[color=yellow]1/2/3[/color] mana regen per turn.",
			5, 5, _tier_pts(5),
			{1: [cf_size, cf_r1], 2: [cf_size, cf_r2], 3: [cf_size, cf_r3]}),
		"storm_conduit_flow")


# ============================================================================
# TIER 6 — Persistent Field, Arc Conduit, Tempest Strike, Grounded Circuit, Galvanic Renewal
# ============================================================================

func _create_tier_6():
	print("\n-- Tier 6 -- 5 skills...")

	# ── Persistent Field (Col 0) ──
	var pf_r1: Affix = _save_affix(
		_make_affix("Persistent Field I", "Static max stacks +5.",
			Affix.Category.MISC, ["mage", "storm", "voltaic", "static_max_stacks"], 5.0,
			{"static_max_stacks_bonus": 5}),
		"persistent_field", "persistent_field_r1_affix")
	var pf_r2: Affix = _save_affix(
		_make_affix("Persistent Field II", "Static max stacks +10.",
			Affix.Category.MISC, ["mage", "storm", "voltaic", "static_max_stacks"], 10.0,
			{"static_max_stacks_bonus": 10}),
		"persistent_field", "persistent_field_r2_affix")

	_save_skill(
		_make_skill("storm_persistent_field", "Persistent Field",
			"Static max stacks +[color=yellow]5/10[/color].",
			6, 0, _tier_pts(6), {1: [pf_r1], 2: [pf_r2]}),
		"storm_persistent_field")

	# ── Arc Conduit (Col 2, Crossover) ──
	var da_ac_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Conduit I: Chain on Use", "Shock die chains 40% on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.4,
			{"chains": 1, "decay": 1.0, "element": "SHOCK"}, _cond_self_element_shock),
		"da_arc_conduit_r1")
	var ac_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Conduit I", "Shock dice chain 40% damage to 1 enemy on use.",
			["mage", "storm", "crossover", "mana_die_affix", "chain"], da_ac_r1),
		"arc_conduit", "arc_conduit_r1_affix")

	var da_ac_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Arc Conduit II: Chain on Use", "Shock die chains 60% on use.",
			DiceAffix.Trigger.ON_USE, DiceAffix.EffectType.EMIT_CHAIN_DAMAGE, 0.6,
			{"chains": 1, "decay": 1.0, "element": "SHOCK"}, _cond_self_element_shock),
		"da_arc_conduit_r2")
	var ac_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Arc Conduit II", "Shock dice chain 60% damage to 1 enemy on use.",
			["mage", "storm", "crossover", "mana_die_affix", "chain"], da_ac_r2),
		"arc_conduit", "arc_conduit_r2_affix")

	_save_skill(
		_make_skill("storm_arc_conduit", "Arc Conduit",
			"Shock mana dice chain [color=yellow]40%/60%[/color] damage to 1 enemy on use.",
			6, 2, _tier_pts(6), {1: [ac_r1], 2: [ac_r2]}),
		"storm_arc_conduit")

	# ── Tempest Strike (Col 3) ──
	var ts_slot: Affix = _save_affix(
		_make_affix("Tempest Strike: Die Slot", "Chromatic Bolt gains +1 die slot.",
			Affix.Category.CLASS_ACTION_STAT_MOD,
			["mage", "storm", "tempest", "class_action_mod"], 1.0,
			{"property": "die_slots", "operation": "add"}),
		"tempest_strike", "tempest_strike_slot_affix")

	var ts_chain_eff_r1_mem: ActionEffect = _make_chain_effect(
		"Tempest Strike: Chain I", ActionEffect.TargetType.SINGLE_ENEMY, 1, 0.4)
	ts_chain_eff_r1_mem.effect_data = {"condition": "shock_die_used"}
	var ts_chain_eff_r1: ActionEffect = _save_effect(ts_chain_eff_r1_mem, "tempest_strike_chain_r1")
	var ts_chain_r1: Affix = _save_affix(
		_make_affix("Tempest Strike: Chain I", "Chromatic Bolt chains to 1 enemy for 40% (shock die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "storm", "tempest", "class_action_mod", "chain"], 0.0,
			{"action_effect": ts_chain_eff_r1, "shock_die_condition": true}),
		"tempest_strike", "tempest_strike_chain_r1_affix")

	var ts_chain_eff_r2_mem: ActionEffect = _make_chain_effect(
		"Tempest Strike: Chain II", ActionEffect.TargetType.SINGLE_ENEMY, 1, 0.6)
	ts_chain_eff_r2_mem.effect_data = {"condition": "shock_die_used"}
	var ts_chain_eff_r2: ActionEffect = _save_effect(ts_chain_eff_r2_mem, "tempest_strike_chain_r2")
	var ts_chain_r2: Affix = _save_affix(
		_make_affix("Tempest Strike: Chain II", "Chromatic Bolt chains to 1 enemy for 60% (shock die).",
			Affix.Category.CLASS_ACTION_EFFECT_ADD,
			["mage", "storm", "tempest", "class_action_mod", "chain"], 0.0,
			{"action_effect": ts_chain_eff_r2, "shock_die_condition": true}),
		"tempest_strike", "tempest_strike_chain_r2_affix")

	_save_skill(
		_make_skill("storm_tempest_strike", "Tempest Strike",
			"Chromatic Bolt gains +1 die slot and chains to 1 enemy for [color=yellow]40%/60%[/color] when a shock die is used.",
			6, 3, _tier_pts(6), {1: [ts_slot, ts_chain_r1], 2: [ts_slot, ts_chain_r2]}),
		"storm_tempest_strike")

	# ── Grounded Circuit (Col 4, Crossover) ──
	var gc_r1_mem: Affix = _make_affix("Grounded Circuit I",
		"Shock damage to Static targets restores 1 mana.",
		Affix.Category.PROC, ["mage", "storm", "crossover", "mana_restore", "static_synergy"], 1.0,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_effect": "mana_restore",
		"amount": 1, "condition": "target_has_static", "element_condition": "SHOCK"})
	gc_r1_mem.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	var gc_r1: Affix = _save_affix(gc_r1_mem, "grounded_circuit", "grounded_circuit_r1_affix")

	var gc_r2_mem: Affix = _make_affix("Grounded Circuit II",
		"Shock damage to Static targets restores 2 mana.",
		Affix.Category.PROC, ["mage", "storm", "crossover", "mana_restore", "static_synergy"], 2.0,
		{"proc_trigger": "ON_DEAL_DAMAGE", "proc_effect": "mana_restore",
		"amount": 2, "condition": "target_has_static", "element_condition": "SHOCK"})
	gc_r2_mem.proc_trigger = Affix.ProcTrigger.ON_DEAL_DAMAGE
	var gc_r2: Affix = _save_affix(gc_r2_mem, "grounded_circuit", "grounded_circuit_r2_affix")

	_save_skill(
		_make_skill("storm_grounded_circuit", "Grounded Circuit",
			"Shock damage to targets with Static restores [color=yellow]1/2[/color] mana per hit.",
			6, 4, _tier_pts(6), {1: [gc_r1], 2: [gc_r2]}),
		"storm_grounded_circuit")

	# ── Galvanic Renewal (Col 6) ──
	var gr_r1_mem: Affix = _make_affix("Galvanic Renewal I",
		"On shock kill, gain a free shock mana die. 1/turn.",
		Affix.Category.PROC, ["mage", "storm", "conduit", "die_grant", "on_kill"], 1.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "grant_mana_die",
		"element": "SHOCK", "uses_per_turn": 1, "element_condition": "SHOCK"})
	gr_r1_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var gr_r1: Affix = _save_affix(gr_r1_mem, "galvanic_renewal", "galvanic_renewal_r1_affix")

	var gr_r2_mem: Affix = _make_affix("Galvanic Renewal II",
		"On shock kill, gain a free shock mana die. 2/turn.",
		Affix.Category.PROC, ["mage", "storm", "conduit", "die_grant", "on_kill"], 2.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "grant_mana_die",
		"element": "SHOCK", "uses_per_turn": 2, "element_condition": "SHOCK"})
	gr_r2_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var gr_r2: Affix = _save_affix(gr_r2_mem, "galvanic_renewal", "galvanic_renewal_r2_affix")

	_save_skill(
		_make_skill("storm_galvanic_renewal", "Galvanic Renewal",
			"On shock kill, gain a free shock mana die to hand. [color=yellow]1/2[/color] times per turn.",
			6, 6, _tier_pts(6), {1: [gr_r1], 2: [gr_r2]}),
		"storm_galvanic_renewal")


# ============================================================================
# TIER 7 — Overcharge, Chain Lightning, Dynamo, Static Discharge
# ============================================================================

func _create_tier_7():
	print("\n-- Tier 7 -- 4 skills...")

	var shock_only: Array[int] = [6]

	# ── Overcharge (Col 1) ──
	var oc_dmg_mem: ActionEffect = _make_action_effect("Overcharge: Stack Damage",
		ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
		ActionEffect.DamageType.SHOCK, 0, 3.0, 0)
	oc_dmg_mem.value_source = ActionEffect.ValueSource.TARGET_STATUS_STACKS
	oc_dmg_mem.value_source_status_id = "static"
	oc_dmg_mem.effect_data = {"consume_stacks": false}
	var oc_dmg: ActionEffect = _save_effect(oc_dmg_mem, "overcharge_damage")

	var oc_effs: Array[ActionEffect] = []
	oc_effs.assign([oc_dmg])
	var oc_act: Action = _save_action(
		_make_action_with_elements("storm_overcharge", "Overcharge",
			"Deal damage equal to target's Static stacks x3. Does not consume stacks.",
			1, oc_effs, shock_only, Action.ChargeType.LIMITED_PER_TURN, 1),
		"overcharge_action")

	var oc_grant_mem: Affix = _make_affix("Overcharge: Grant Action", "Grants Overcharge action.",
		Affix.Category.NEW_ACTION, ["mage", "storm", "voltaic", "granted_action", "static_payoff"], 0.0,
		{"action_id": "storm_overcharge"})
	oc_grant_mem.granted_action = oc_act
	var oc_grant: Affix = _save_affix(oc_grant_mem, "overcharge", "overcharge_r1_affix")

	_save_skill(
		_make_skill("storm_overcharge", "Overcharge",
			"[color=yellow]ACTION:[/color] 1 die -> damage = target's [color=cyan]Static[/color] stacks x3. Does not consume stacks. Per turn.",
			7, 1, _tier_pts(7), {1: [oc_grant]}),
		"storm_overcharge")

	# ── Chain Lightning (Col 2) ──
	var cl_dmg: ActionEffect = _save_effect(
		_make_action_effect("Chain Lightning: Damage",
			ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 0, 1.0, 2),
		"chain_lightning_damage")
	var cl_chain: ActionEffect = _save_effect(
		_make_chain_effect("Chain Lightning: Chain",
			ActionEffect.TargetType.SINGLE_ENEMY, 2, 0.6),
		"chain_lightning_chain")

	var cl_effs: Array[ActionEffect] = []
	cl_effs.assign([cl_dmg, cl_chain])
	var cl_act: Action = _save_action(
		_make_action_with_elements("storm_chain_lightning", "Chain Lightning",
			"Full shock damage, chains to 2 enemies for 60%.",
			2, cl_effs, shock_only, Action.ChargeType.LIMITED_PER_COMBAT, 1),
		"chain_lightning_action")

	var cl_grant_mem: Affix = _make_affix("Chain Lightning: Grant Action",
		"Grants Chain Lightning action.",
		Affix.Category.NEW_ACTION, ["mage", "storm", "tempest", "granted_action", "chain"], 0.0,
		{"action_id": "storm_chain_lightning"})
	cl_grant_mem.granted_action = cl_act
	var cl_grant: Affix = _save_affix(cl_grant_mem, "chain_lightning", "chain_lightning_r1_affix")

	_save_skill(
		_make_skill("storm_chain_lightning", "Chain Lightning",
			"[color=yellow]ACTION:[/color] 2 dice -> [color=cyan]shock[/color] x1.0, chain to 2 enemies for 60%. Per combat.",
			7, 2, _tier_pts(7), {1: [cl_grant]}),
		"storm_chain_lightning")

	# ── Dynamo (Col 4) ──
	var dyn_size: Affix = _save_affix(
		_make_affix("Dynamo: D8 Unlock", "Unlocks D8 shock mana die.",
			Affix.Category.MANA_SIZE_UNLOCK,
			["mage", "storm", "conduit", "size_unlock"], 0.0, {"die_size": 8}),
		"dynamo", "dynamo_size_unlock")

	var da_dyn_r1: DiceAffix = _save_dice_affix(
		_make_dice_affix("Dynamo I: Value Bonus", "Shock dice +1 on roll.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0, {},
			_cond_self_element_shock),
		"da_dynamo_r1")
	var dyn_r1: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Dynamo I", "Shock mana dice +1 to rolled value.",
			["mage", "storm", "conduit", "mana_die_affix", "value_bonus"], da_dyn_r1),
		"dynamo", "dynamo_r1_value_affix")

	var da_dyn_r2: DiceAffix = _save_dice_affix(
		_make_dice_affix("Dynamo II: Value Bonus", "Shock dice +2 on roll.",
			DiceAffix.Trigger.ON_ROLL, DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0, {},
			_cond_self_element_shock),
		"da_dynamo_r2")
	var dyn_r2: Affix = _save_affix(
		_make_mana_die_affix_wrapper("Dynamo II", "Shock mana dice +2 to rolled value.",
			["mage", "storm", "conduit", "mana_die_affix", "value_bonus"], da_dyn_r2),
		"dynamo", "dynamo_r2_value_affix")

	_save_skill(
		_make_skill("storm_dynamo", "Dynamo",
			"Unlock D8 shock mana die. Shock mana dice +[color=yellow]1/2[/color] to rolled value.",
			7, 4, _tier_pts(7), {1: [dyn_size, dyn_r1], 2: [dyn_size, dyn_r2]}),
		"storm_dynamo")

	# ── Static Discharge (Col 5) ──
	var sd_r1_mem: Affix = _make_affix("Static Discharge",
		"When a Static target dies, deal remaining stacks as shock damage to all others and apply half as Static.",
		Affix.Category.PROC, ["mage", "storm", "conduit", "static_synergy", "on_kill", "propagate"], 1.0,
		{"proc_trigger": "ON_KILL", "proc_effect": "static_death_discharge",
		"damage_per_stack": 1, "spread_fraction": 0.5, "target": "all_other_enemies"})
	sd_r1_mem.proc_trigger = Affix.ProcTrigger.ON_KILL
	var sd_r1: Affix = _save_affix(sd_r1_mem, "static_discharge", "static_discharge_r1_affix")

	_save_skill(
		_make_skill("storm_static_discharge", "Static Discharge",
			"When a [color=cyan]Static[/color] target dies, deal remaining stacks as shock damage to all enemies and apply half (rounded down) as Static.",
			7, 5, _tier_pts(7), {1: [sd_r1]}),
		"storm_static_discharge")


# ============================================================================
# TIER 8 — Tesla Coil, Storm Surge, Feedback Loop
# ============================================================================

func _create_tier_8():
	print("\n-- Tier 8 -- 3 skills...")

	var shock_only: Array[int] = [6]

	# ── Tesla Coil (Col 1, Crossover) ──
	var tc_ext: Affix = _save_affix(
		_make_affix("Tesla Coil: Chain Extension", "Chain effects chain +1 additional target.",
			Affix.Category.MISC, ["mage", "storm", "crossover", "chain_extend"], 1.0,
			{"chain_bonus_targets": 1}),
		"tesla_coil", "tesla_coil_chain_ext_affix")
	var tc_static: Affix = _save_affix(
		_make_affix("Tesla Coil: Chain Static", "Chain bounces apply 2 Static per bounce.",
			Affix.Category.MISC, ["mage", "storm", "crossover", "chain_static", "static_apply"], 2.0,
			{"chain_apply_static": 2}),
		"tesla_coil", "tesla_coil_chain_static_affix")

	_save_skill(
		_make_skill("storm_tesla_coil", "Tesla Coil",
			"Chain effects chain +1 additional target and apply 2 [color=cyan]Static[/color] per chain bounce.",
			8, 1, _tier_pts(8), {1: [tc_ext, tc_static]}),
		"storm_tesla_coil")

	# ── Storm Surge (Col 3) ──
	var ss_dmg: ActionEffect = _save_effect(
		_make_action_effect("Storm Surge: AoE Damage",
			ActionEffect.TargetType.ALL_ENEMIES, ActionEffect.EffectType.DAMAGE,
			ActionEffect.DamageType.SHOCK, 0, 0.8, 3),
		"storm_surge_damage")
	var ss_status: ActionEffect = _save_effect(
		_make_action_effect("Storm Surge: Apply Static",
			ActionEffect.TargetType.ALL_ENEMIES, ActionEffect.EffectType.ADD_STATUS,
			ActionEffect.DamageType.SHOCK, 0, 1.0, 0, 0, 1.0, false, _static_status, 3),
		"storm_surge_static")

	var ss_effs: Array[ActionEffect] = []
	ss_effs.assign([ss_dmg, ss_status])
	var ss_act: Action = _save_action(
		_make_action_with_elements("storm_storm_surge", "Storm Surge",
			"Shock barrage: x0.8 damage to all enemies and apply 3 Static to each.",
			3, ss_effs, shock_only, Action.ChargeType.LIMITED_PER_COMBAT, 1),
		"storm_surge_action")

	var ss_grant_mem: Affix = _make_affix("Storm Surge: Grant Action", "Grants Storm Surge action.",
		Affix.Category.NEW_ACTION, ["mage", "storm", "tempest", "granted_action", "aoe"], 0.0,
		{"action_id": "storm_storm_surge"})
	ss_grant_mem.granted_action = ss_act
	var ss_grant: Affix = _save_affix(ss_grant_mem, "storm_surge", "storm_surge_r1_affix")

	_save_skill(
		_make_skill("storm_storm_surge", "Storm Surge",
			"[color=yellow]ACTION:[/color] 3 dice -> [color=cyan]shock[/color] x0.8 to ALL enemies + 3 [color=cyan]Static[/color] each. Per combat.",
			8, 3, _tier_pts(8), {1: [ss_grant]}),
		"storm_storm_surge")

	# ── Feedback Loop (Col 5, Crossover) ──
	var fl_gc: Affix = _save_affix(
		_make_affix("Feedback Loop: Grounded Circuit Boost", "Grounded Circuit mana restore doubled.",
			Affix.Category.MISC, ["mage", "storm", "crossover", "grounded_circuit_boost"], 2.0,
			{"grounded_circuit_multiplier": 2}),
		"feedback_loop", "feedback_loop_gc_boost_affix")
	var fl_r1: Affix = _save_affix(
		_make_affix("Feedback Loop I: Pull Bonus", "Pulling shock die grants +3 bonus shock damage this turn.",
			Affix.Category.PROC, ["mage", "storm", "crossover", "conduit", "on_pull", "temp_buff"], 3.0,
			{"proc_trigger": "ON_MANA_PULL", "proc_effect": "temp_shock_damage_bonus",
			"amount": 3, "duration": "this_turn", "element_condition": "SHOCK"}),
		"feedback_loop", "feedback_loop_pull_r1_affix")
	var fl_r2: Affix = _save_affix(
		_make_affix("Feedback Loop II: Pull Bonus", "Pulling shock die grants +6 bonus shock damage this turn.",
			Affix.Category.PROC, ["mage", "storm", "crossover", "conduit", "on_pull", "temp_buff"], 6.0,
			{"proc_trigger": "ON_MANA_PULL", "proc_effect": "temp_shock_damage_bonus",
			"amount": 6, "duration": "this_turn", "element_condition": "SHOCK"}),
		"feedback_loop", "feedback_loop_pull_r2_affix")

	_save_skill(
		_make_skill("storm_feedback_loop", "Feedback Loop",
			"Grounded Circuit mana restore doubled. Pulling shock mana die grants +[color=yellow]3/6[/color] bonus shock damage on next shock action this turn.",
			8, 5, _tier_pts(8), {1: [fl_gc, fl_r1], 2: [fl_gc, fl_r2]}),
		"storm_feedback_loop")


# ============================================================================
# TIER 9 — Thunderhead, Stormcaller
# ============================================================================

func _create_tier_9():
	print("\n-- Tier 9 -- 2 skills...")

	# ── Thunderhead (Col 1) ──
	var th_r1_mem: Affix = _make_affix("Thunderhead I", "At start of each turn, apply 2 Static to all enemies.",
		Affix.Category.PROC, ["mage", "storm", "voltaic", "static_apply", "passive"], 2.0,
		{"proc_trigger": "ON_TURN_START", "proc_effect": "apply_status",
		"status_id": "static", "stacks": 2, "target": "all_enemies"})
	th_r1_mem.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	var th_r1: Affix = _save_affix(th_r1_mem, "thunderhead", "thunderhead_r1_affix")

	var th_r2_mem: Affix = _make_affix("Thunderhead II", "At start of each turn, apply 3 Static to all enemies.",
		Affix.Category.PROC, ["mage", "storm", "voltaic", "static_apply", "passive"], 3.0,
		{"proc_trigger": "ON_TURN_START", "proc_effect": "apply_status",
		"status_id": "static", "stacks": 3, "target": "all_enemies"})
	th_r2_mem.proc_trigger = Affix.ProcTrigger.ON_TURN_START
	var th_r2: Affix = _save_affix(th_r2_mem, "thunderhead", "thunderhead_r2_affix")

	_save_skill(
		_make_skill("storm_thunderhead", "Thunderhead",
			"At the start of each turn, apply [color=yellow]2/3[/color] [color=cyan]Static[/color] to all enemies.",
			9, 1, _tier_pts(9), {1: [th_r1], 2: [th_r2]}),
		"storm_thunderhead")

	# ── Stormcaller (Col 4) ──
	var sc_r1: Affix = _save_affix(
		_make_affix("Stormcaller I: Stack Bonus", "Static per-stack bonus increased to +2.",
			Affix.Category.MISC, ["mage", "storm", "static_per_stack"], 2.0,
			{"static_per_stack_bonus_override": 2}),
		"stormcaller", "stormcaller_stack_r1_affix")
	var sc_chain: Affix = _save_affix(
		_make_affix("Stormcaller: Chain All", "Chromatic Bolt chain hits ALL enemies instead of 1.",
			Affix.Category.CLASS_ACTION_CONDITIONAL,
			["mage", "storm", "class_action_mod", "chain_all"], 0.0,
			{"chromatic_bolt_chain_all": true}),
		"stormcaller", "stormcaller_chain_all_affix")
	var sc_r2: Affix = _save_affix(
		_make_affix("Stormcaller II: Stack Bonus", "Static per-stack bonus increased to +3.",
			Affix.Category.MISC, ["mage", "storm", "static_per_stack"], 3.0,
			{"static_per_stack_bonus_override": 3}),
		"stormcaller", "stormcaller_stack_r2_affix")

	_save_skill(
		_make_skill("storm_stormcaller", "Stormcaller",
			"Static per-stack bonus becomes +[color=yellow]2/3[/color]. Chromatic Bolt's chain hits ALL enemies.",
			9, 4, _tier_pts(9), {1: [sc_r1, sc_chain], 2: [sc_r2, sc_chain]}),
		"storm_stormcaller")


# ============================================================================
# TIER 10 — CAPSTONE: Eye of the Storm
# ============================================================================

func _create_tier_10():
	print("\n-- Tier 10 -- CAPSTONE...")

	var eots_stacks: Affix = _save_affix(
		_make_affix("Eye of the Storm: Double Stacks", "Double max Static stacks.",
			Affix.Category.MISC, ["mage", "storm", "capstone", "static_max_stacks"], 2.0,
			{"static_max_stacks_multiplier": 2}),
		"eye_of_the_storm", "eots_double_stacks_affix")
	var eots_return: Affix = _save_affix(
		_make_affix("Eye of the Storm: Chain Return", "Chain effects return to original target for an extra hit.",
			Affix.Category.MISC, ["mage", "storm", "capstone", "chain_return"], 0.0,
			{"chain_return_to_source": true}),
		"eye_of_the_storm", "eots_chain_return_affix")

	_save_skill(
		_make_skill("storm_eye_of_the_storm", "Eye of the Storm",
			"Double max [color=cyan]Static[/color] stacks. Chain effects return to the original target for an extra hit.",
			10, 3, _tier_pts(10), {1: [eots_stacks, eots_return]}),
		"storm_eye_of_the_storm")


# ============================================================================
# PREREQUISITE WIRING — All skills already in _skill_lookup as disk-loaded refs
# ============================================================================

func _wire_prerequisites():
	print("\n-- Wiring prerequisites...")

	# Helper lambda — matches flame tree pattern exactly.
	# Skills were already saved to disk in tier functions, so they have
	# resource_path set. SkillPrerequisite.required_skill will serialize
	# as ExtResource on re-save.
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

	# TIER 2
	_add_prereq.call("storm_arc_pulse", "storm_spark")
	_add_prereq.call("storm_crackling_force", "storm_spark")
	_add_prereq.call("storm_capacitance", "storm_spark")

	# TIER 3
	_add_prereq.call("storm_ionize", "storm_arc_pulse")
	_add_prereq.call("storm_charged_strikes", "storm_crackling_force")
	_add_prereq.call("storm_conjure_storm_sprite", "storm_crackling_force")
	_add_prereq.call("storm_surge_efficiency", "storm_capacitance")
	_add_prereq.call("storm_polarity", "storm_capacitance")

	# TIER 4
	_add_prereq.call("storm_static_cling", "storm_ionize")
	_add_prereq.call("storm_live_wire", "storm_ionize")
	_add_prereq.call("storm_thunderclap", "storm_charged_strikes")
	_add_prereq.call("storm_voltaic_surge", "storm_charged_strikes")
	_add_prereq.call("storm_mana_siphon", "storm_surge_efficiency")

	# TIER 5
	_add_prereq.call("storm_voltaic_sprite", "storm_static_cling")
	_add_prereq.call("storm_storm_charge", "storm_live_wire")
	_add_prereq.call("storm_tempest_sprite", "storm_thunderclap")
	_add_prereq.call("storm_lightning_bolt", "storm_voltaic_surge")
	_add_prereq.call("storm_conduit_sprite", "storm_mana_siphon")
	_add_prereq.call("storm_conduit_flow", "storm_mana_siphon")

	# TIER 6
	_add_prereq.call("storm_persistent_field", "storm_storm_charge")
	_add_prereq.call("storm_arc_conduit", "storm_storm_charge")
	_add_prereq.call("storm_arc_conduit", "storm_lightning_bolt")  # crossover
	_add_prereq.call("storm_tempest_strike", "storm_lightning_bolt")
	_add_prereq.call("storm_grounded_circuit", "storm_lightning_bolt")
	_add_prereq.call("storm_grounded_circuit", "storm_conduit_flow")  # crossover
	_add_prereq.call("storm_galvanic_renewal", "storm_conduit_flow")

	# TIER 7
	_add_prereq.call("storm_overcharge", "storm_persistent_field")
	_add_prereq.call("storm_chain_lightning", "storm_arc_conduit")
	_add_prereq.call("storm_dynamo", "storm_grounded_circuit")
	_add_prereq.call("storm_static_discharge", "storm_galvanic_renewal")

	# TIER 8
	_add_prereq.call("storm_tesla_coil", "storm_overcharge")
	_add_prereq.call("storm_tesla_coil", "storm_chain_lightning")  # crossover
	_add_prereq.call("storm_storm_surge", "storm_chain_lightning")
	_add_prereq.call("storm_feedback_loop", "storm_dynamo")
	_add_prereq.call("storm_feedback_loop", "storm_static_discharge")  # crossover

	# TIER 9
	_add_prereq.call("storm_thunderhead", "storm_tesla_coil")
	_add_prereq.call("storm_stormcaller", "storm_storm_surge")
	_add_prereq.call("storm_stormcaller", "storm_feedback_loop")  # crossover

	# TIER 10
	_add_prereq.call("storm_eye_of_the_storm", "storm_thunderhead")
	_add_prereq.call("storm_eye_of_the_storm", "storm_stormcaller")

	# Re-save all skills with prerequisites now attached (single pass)
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
	tree.description = "Master lightning magic. Three paths: Voltaic (Static application & control), Tempest (raw shock damage & chain attacks), Conduit (mana efficiency & die manipulation)."

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

	tree.tier_2_points_required = 1
	tree.tier_3_points_required = 3
	tree.tier_4_points_required = 5
	tree.tier_5_points_required = 8
	tree.tier_6_points_required = 11
	tree.tier_7_points_required = 15
	tree.tier_8_points_required = 20
	tree.tier_9_points_required = 25
	tree.tier_10_points_required = 28

	var tree_path: String = TREE_DIR + "mage_storm.tres"
	_save_to_disk(tree, tree_path)

	var total_skills: int = tree.get_all_skills().size()
	print("  SkillTree saved: %s (%d skills)" % [tree.tree_name, total_skills])

	for t in range(1, 11):
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
