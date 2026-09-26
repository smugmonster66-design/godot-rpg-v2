@tool
extends EditorScript
# ============================================================================
# generate_navy_enemies.gd
# Creates ALL Sanctum Navy faction enemies: 51 actions, 17 dice affixes,
# ~6 conditions, and 85 enemy resources (17 enemies x 5 tiers).
# Run from Script Editor -> File -> Run
# ============================================================================

const TEMPLATE_DIR := "res://resources/enemy_templates"
const DICE_DIR := "res://resources/dice/base"
const STATUS_DIR := "res://resources/statuses"
const HEALTH_AFFIX_DIR := "res://resources/affixes/base_stats/enemy"
const OUTPUT_DIR := "res://resources/enemies/region1/navy"
const ACTION_DIR := "res://resources/actions/navy"
const DICE_AFFIX_DIR := "res://resources/dice_affixes/navy"
const CONDITION_DIR := "res://resources/dice_affixes/navy/conditions"

const TIER_TRASH := 0
const TIER_ELITE := 1
const TIER_MINI_BOSS := 2
const TIER_BOSS := 3
const TIER_WORLD_BOSS := 4

var _count := 0
var _action_count := 0
var _dice_affix_count := 0
var _errors := 0

var _templates: Dictionary = {}
var _dice_cache: Dictionary = {}
var _status_cache: Dictionary = {}
var _health_affix_cache: Dictionary = {}
var _stat_affix_cache: Dictionary = {}

# Tier stat budgets
const BASE_HP := [10, 15, 25, 40, 60]
const XP_REWARDS := [10, 30, 75, 150, 500]
const GOLD_MIN := [3, 10, 25, 50, 150]
const GOLD_MAX := [10, 30, 75, 150, 500]
const LEVEL_FLOORS := [1, 3, 5, 8, 12]
const LEVEL_SCALING := [0.85, 0.95, 1.0, 1.1, 1.2]

# Standard dice counts per tier [trash, elite, mini_boss, boss, world_boss]
const STANDARD_DICE_COUNTS := [2, 3, 3, 4, 4]
const SKIRMISHER_DICE_COUNTS := [3, 4, 4, 5, 5]
const SUPPORT_DICE_COUNTS := [1, 2, 2, 3, 3]

# Die sizes per tier
const BRUTE_DIE_SIZES := [8, 10, 10, 12, 12]
const STANDARD_DIE_SIZES := [6, 8, 10, 10, 12]

func _run():
	print("=" .repeat(70))
	print("  SANCTUM NAVY ENEMY GENERATOR")
	print("=" .repeat(70))

	print("\n[PHASE 0] Loading resources...")
	if not _load_resources():
		push_error("Aborting due to missing resources.")
		return

	print("\n[PHASE 1] Creating directories...")
	_ensure_directories()

	print("\n[PHASE 2] Creating actions and dice affixes...")
	var all_enemy_data: Array[Dictionary] = _build_all_enemy_specs()

	print("\n[PHASE 3] Creating enemies (5 tiers each)...")
	for spec in all_enemy_data:
		_create_enemy_tiers(spec)

	print("\n" + "=" .repeat(70))
	print("  Scanning filesystem...")
	EditorInterface.get_resource_filesystem().scan()
	if _errors == 0:
		print("  SUCCESS: %d enemies, %d actions, %d dice affixes" % [_count, _action_count, _dice_affix_count])
	else:
		print("  %d ERRORS -- %d enemies, %d actions, %d dice affixes" % [_errors, _count, _action_count, _dice_affix_count])
	print("=" .repeat(70))


# ============================================================================
# RESOURCE LOADING
# ============================================================================

func _load_resources() -> bool:
	var ok := true

	# Templates
	var template_names := [
		"brute_str", "brute_agi", "skirmisher_agi", "skirmisher_int",
		"caster_int", "tank_str", "tank_int",
		"support_str", "support_int", "support_agi",
	]
	for tname in template_names:
		var path := "%s/%s.tres" % [TEMPLATE_DIR, tname]
		if ResourceLoader.exists(path):
			_templates[tname] = load(path)
			print("  Template OK: %s" % tname)
		else:
			push_error("  MISSING template: %s" % path)
			ok = false

	# Dice
	var sizes := [4, 6, 8, 10, 12]
	var elems := ["none", "slashing", "blunt", "piercing", "fire", "ice", "shock", "shadow"]
	for sz in sizes:
		for el in elems:
			var key := "d%d_%s" % [sz, el]
			var path := "%s/%s.tres" % [DICE_DIR, key]
			if ResourceLoader.exists(path):
				_dice_cache[key] = load(path)
	print("  Loaded %d dice" % _dice_cache.size())

	# Statuses
	var status_ids := [
		"burn", "bleed", "poison", "corrode", "slowed", "chill",
		"expose", "enfeeble", "empowered", "fortified", "braced",
		"dodge", "warded", "taunt", "static", "stunned",
	]
	for sid in status_ids:
		var path := "%s/%s.tres" % [STATUS_DIR, sid]
		if ResourceLoader.exists(path):
			_status_cache[sid] = load(path)
			print("  Status OK: %s" % sid)
		else:
			push_error("  MISSING status: %s" % path)
			ok = false

	# Health affixes
	var health_names := [
		"enemy_health_str_brute", "enemy_health_agi_brute",
		"enemy_health_agi_skirmisher", "enemy_health_int_skirmisher",
		"enemy_health_int_caster", "enemy_health_str_tank",
		"enemy_health_int_tank", "enemy_health_str_support",
		"enemy_health_int_support", "enemy_health_agi_support",
	]
	for hname in health_names:
		var path := "%s/%s.tres" % [HEALTH_AFFIX_DIR, hname]
		if ResourceLoader.exists(path):
			_health_affix_cache[hname] = load(path)
		else:
			push_error("  MISSING health affix: %s" % path)
			ok = false

	# Stat affixes
	var stat_names := [
		"enemy_armor_str_brute", "enemy_armor_agi_brute",
		"enemy_armor_agi_skirmisher", "enemy_armor_str_tank",
		"enemy_armor_int_tank",
		"enemy_barrier_int_skirmisher", "enemy_barrier_int_caster",
		"enemy_barrier_int_support", "enemy_barrier_int_tank",
		"enemy_damage_blunt", "enemy_damage_slashing", "enemy_damage_piercing",
		"enemy_damage_fire", "enemy_damage_ice", "enemy_damage_shock",
		"enemy_damage_shadow",
	]
	for sname in stat_names:
		var path := "%s/%s.tres" % [HEALTH_AFFIX_DIR, sname]
		if ResourceLoader.exists(path):
			_stat_affix_cache[sname] = load(path)
		else:
			push_error("  MISSING stat affix: %s" % path)
			ok = false

	return ok


func _ensure_directories():
	var dirs := [
		OUTPUT_DIR,
		OUTPUT_DIR + "/trash",
		OUTPUT_DIR + "/elite",
		OUTPUT_DIR + "/mini_boss",
		OUTPUT_DIR + "/boss",
		OUTPUT_DIR + "/world_boss",
		ACTION_DIR,
		DICE_AFFIX_DIR,
		CONDITION_DIR,
	]
	for d in dirs:
		DirAccess.make_dir_recursive_absolute(d)
		print("  dir: %s" % d)


# ============================================================================
# HELPER: Create ActionEffect
# ============================================================================

func _make_damage_effect(p_name: String, target: int, value_source: int,
		damage_type: int, base_dmg: int, mult: float) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.effect_type = ActionEffect.EffectType.DAMAGE
	e.target = target as ActionEffect.TargetType
	e.value_source = value_source as ActionEffect.ValueSource
	e.damage_type = damage_type as ActionEffect.DamageType
	e.base_damage = base_dmg
	e.damage_multiplier = mult
	return e

func _make_status_effect(p_name: String, target: int, status_id: String, stacks: int) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.effect_type = ActionEffect.EffectType.ADD_STATUS
	e.target = target as ActionEffect.TargetType
	e.status_affix = _status_cache.get(status_id)
	e.stack_count = stacks
	return e

func _make_heal_effect(p_name: String, target: int, uses_dice: bool, mult: float) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.effect_type = ActionEffect.EffectType.HEAL
	e.target = target as ActionEffect.TargetType
	e.value_source = ActionEffect.ValueSource.DICE_TOTAL
	e.heal_uses_dice = uses_dice
	e.heal_multiplier = mult
	return e

func _make_cleanse_effect(p_name: String, target: int, tags: Array[String], max_removals: int) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.effect_type = ActionEffect.EffectType.CLEANSE
	e.target = target as ActionEffect.TargetType
	e.cleanse_tags.assign(tags)
	e.cleanse_max_removals = max_removals
	return e

func _make_chain_effect(p_name: String, target: int, damage_type: int,
		base_dmg: int, mult: float, chains: int, decay: float) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.effect_type = ActionEffect.EffectType.CHAIN
	e.target = target as ActionEffect.TargetType
	e.value_source = ActionEffect.ValueSource.DICE_TOTAL
	e.damage_type = damage_type as ActionEffect.DamageType
	e.base_damage = base_dmg
	e.damage_multiplier = mult
	e.chain_count = chains
	e.chain_decay = decay
	return e

func _make_random_strikes_effect(p_name: String, target: int, damage_type: int,
		strike_count: int, strike_mult: float, uses_dice: bool) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.effect_type = ActionEffect.EffectType.RANDOM_STRIKES
	e.target = target as ActionEffect.TargetType
	e.value_source = ActionEffect.ValueSource.DICE_TOTAL
	e.damage_type = damage_type as ActionEffect.DamageType
	e.strike_count = strike_count
	e.strike_multiplier = strike_mult
	e.strikes_use_dice = uses_dice
	return e

func _make_reflect_effect(p_name: String, target: int, pct: float, duration: int) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.effect_type = ActionEffect.EffectType.REFLECT
	e.target = target as ActionEffect.TargetType
	e.reflect_percent = pct
	e.reflect_duration = duration
	return e

func _make_dr_effect(p_name: String, target: int, amount: float, is_pct: bool, duration: int) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.effect_type = ActionEffect.EffectType.DAMAGE_REDUCTION
	e.target = target as ActionEffect.TargetType
	e.reduction_amount = amount
	e.reduction_is_percent = is_pct
	e.reduction_duration = duration
	return e

func _make_counter_effect(p_name: String, target: int, charges: int, threshold: int,
		counter_eff: ActionEffect) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_name = p_name
	e.effect_type = ActionEffect.EffectType.COUNTER_SETUP
	e.target = target as ActionEffect.TargetType
	e.counter_charges = charges
	e.counter_damage_threshold = threshold
	e.counter_effect = counter_eff
	return e

# ============================================================================
# HELPER: Create ActionAIHint
# ============================================================================

func _make_hint_bonus(cond: int, p_threshold: float, status: String, bonus: float) -> ActionAIHint:
	var h := ActionAIHint.new()
	h.condition = cond as ActionAIHint.HintCondition
	h.threshold = p_threshold
	h.status_id = status
	h.effect = ActionAIHint.HintEffect.SCORE_BONUS
	h.bonus_value = bonus
	return h

func _make_hint_mult(cond: int, p_threshold: float, status: String, mult: float) -> ActionAIHint:
	var h := ActionAIHint.new()
	h.condition = cond as ActionAIHint.HintCondition
	h.threshold = p_threshold
	h.status_id = status
	h.effect = ActionAIHint.HintEffect.SCORE_MULTIPLIER
	h.multiplier_value = mult
	return h

func _make_hint_force(cond: int, p_threshold: float, status: String) -> ActionAIHint:
	var h := ActionAIHint.new()
	h.condition = cond as ActionAIHint.HintCondition
	h.threshold = p_threshold
	h.status_id = status
	h.effect = ActionAIHint.HintEffect.FORCE_ACTION
	return h

# ============================================================================
# HELPER: Create and save Action
# ============================================================================

func _make_action(p_id: String, p_name: String, p_desc: String, cat: int,
		action_type: int, element: int, die_slots: int,
		charge_type: int, max_charges: int,
		effects: Array, hints: Array) -> Action:
	var a := Action.new()
	a.action_id = p_id
	a.action_name = p_name
	a.action_description = p_desc
	a.action_category = cat as Action.ActionCategory
	a.action_type = action_type
	a.damage_element = element as ActionEffect.DamageType
	a.die_slots = die_slots
	a.charge_type = charge_type as Action.ChargeType
	a.max_charges = max_charges

	var typed_effects: Array[ActionEffect] = []
	for e in effects:
		typed_effects.append(e)
	a.effects.assign(typed_effects)

	var typed_hints: Array[ActionAIHint] = []
	for h in hints:
		typed_hints.append(h)
	a.ai_hints.assign(typed_hints)

	var path := "%s/%s.tres" % [ACTION_DIR, p_id]
	var err := ResourceSaver.save(a, path)
	if err == OK:
		_action_count += 1
		print("    Action saved: %s" % p_id)
	else:
		push_error("    FAILED saving action: %s" % p_id)
		_errors += 1
	return a


# ============================================================================
# HELPER: Create DiceAffix and DiceAffixCondition
# ============================================================================

func _make_condition(p_type: int, p_threshold: float, p_status_id: String) -> DiceAffixCondition:
	var c := DiceAffixCondition.new()
	c.type = p_type as DiceAffixCondition.Type
	c.threshold = p_threshold
	c.condition_status_id = p_status_id

	var safe_name := "cond_%d_%s_%s" % [p_type, str(p_threshold).replace(".", "_"), p_status_id]
	var path := "%s/%s.tres" % [CONDITION_DIR, safe_name]
	var err := ResourceSaver.save(c, path)
	if err == OK:
		print("    Condition saved: %s" % safe_name)
	else:
		push_error("    FAILED saving condition: %s" % safe_name)
		_errors += 1
	return c

func _make_dice_affix(p_name: String, p_desc: String, trigger: int, position: int,
		effect_type: int, effect_value: float, effect_data: Dictionary,
		condition: DiceAffixCondition) -> DiceAffix:
	var da := DiceAffix.new()
	da.affix_name = p_name
	da.description = p_desc
	da.trigger = trigger as DiceAffix.Trigger
	da.position_requirement = position as DiceAffix.PositionRequirement
	da.effect_type = effect_type as DiceAffix.EffectType
	da.effect_value = effect_value
	da.effect_data = effect_data
	if condition:
		da.condition = condition

	var safe_name := p_name.to_lower().replace(" ", "_").replace("'", "")
	var path := "%s/da_%s.tres" % [DICE_AFFIX_DIR, safe_name]
	var err := ResourceSaver.save(da, path)
	if err == OK:
		_dice_affix_count += 1
		print("    Dice affix saved: %s" % safe_name)
	else:
		push_error("    FAILED saving dice affix: %s" % safe_name)
		_errors += 1
	return da


# ============================================================================
# HELPER: Create EnemyAIConfig
# ============================================================================

func _make_ai_config(elem_pref: float, heal_urg: float, heal_thresh: float,
		crit_thresh: float, status_aware: float, coord_pref: float) -> EnemyAIConfig:
	var c := EnemyAIConfig.new()
	c.element_preference = elem_pref
	c.heal_urgency = heal_urg
	c.heal_threshold = heal_thresh
	c.critical_threshold = crit_thresh
	c.status_awareness = status_aware
	c.coordination_preference = coord_pref
	return c


# ============================================================================
# ENEMY SPEC BUILDERS - Returns Array of spec Dictionaries
# ============================================================================

func _build_all_enemy_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []

	# 1. Navy Enforcer
	specs.append(_spec_enforcer())
	# 2. Marine Boarder
	specs.append(_spec_marine_boarder())
	# 3. Navy Fencer
	specs.append(_spec_navy_fencer())
	# 4. Griffin-Rider Lancer
	specs.append(_spec_griffin_rider())
	# 5. Rigging Runner
	specs.append(_spec_rigging_runner())
	# 6. Navy Scout
	specs.append(_spec_navy_scout())
	# 7. Wardbreaker
	specs.append(_spec_wardbreaker())
	# 8. Weather Mage
	specs.append(_spec_weather_mage())
	# 9. Naval Arcanist
	specs.append(_spec_naval_arcanist())
	# 10. Navy Shieldbearer
	specs.append(_spec_navy_shieldbearer())
	# 11. Harbour Sentinel
	specs.append(_spec_harbour_sentinel())
	# 12. Ward Officer
	specs.append(_spec_ward_officer())
	# 13. Navy Sergeant
	specs.append(_spec_navy_sergeant())
	# 14. Drum Major
	specs.append(_spec_drum_major())
	# 15. Navy Chirurgeon
	specs.append(_spec_navy_chirurgeon())
	# 16. Tide Priest
	specs.append(_spec_tide_priest())
	# 17. Signalman
	specs.append(_spec_signalman())

	return specs


# ============================================================================
# 1. NAVY ENFORCER
# ============================================================================

func _spec_enforcer() -> Dictionary:
	print("\n  -- Navy Enforcer --")

	# Dice affix: Weighted Head
	var da := _make_dice_affix("Weighted Head",
		"First die used gets +1 value.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.FIRST,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0, {}, null)

	# Actions
	var a1 := _make_action("navy_compliance_strike", "Compliance Strike",
		"A heavy blow to enforce order.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Compliance Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.BLUNT, 2, 1.2)],
		[])

	var a2 := _make_action("navy_subdue", "Subdue",
		"Weaken the target with a stunning blow.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Subdue Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.BLUNT, 0, 0.7),
		 _make_status_effect("Subdue Slow", ActionEffect.TargetType.SINGLE_ENEMY, "slowed", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "slowed", 15.0)])

	var a3 := _make_action("navy_judgment_strike", "Judgment Strike",
		"A crushing blow reserved for the condemned.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.LIMITED_PER_COMBAT, 2,
		[_make_damage_effect("Judgment Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.BLUNT, 4, 1.5),
		 _make_status_effect("Judgment Corrode", ActionEffect.TargetType.SINGLE_ENEMY, "corrode", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "slowed", 40.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.TURN_NUMBER_ABOVE, 2.0, "", 10.0)])

	return {
		"template_key": "brute_str",
		"element": "blunt",
		"ai_strategy": 0,  # AGGRESSIVE
		"ai_config": _make_ai_config(0.6, 0.3, 0.5, 0.3, 0.5, 0.5),
		"health_affix": "enemy_health_str_brute",
		"stat_affixes": ["enemy_armor_str_brute", "enemy_damage_blunt"],
		"dice_affix": da,
		"tier_names": {0: "Navy Enforcer", 1: "Enforcer Sergeant", 2: "Chief Enforcer", 3: "Enforcer Commander", 4: "Grand Enforcer"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 1,  # STR
		"combat_role": 0,  # BRUTE
		"dice_type": "brute",
		"team_aware": false,
		"action_delay": 0.7,
	}


# ============================================================================
# 2. MARINE BOARDER
# ============================================================================

func _spec_marine_boarder() -> Dictionary:
	print("\n  -- Marine Boarder --")

	var da := _make_dice_affix("Breach Protocol",
		"Last die used applies Corrode to the enemy.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.LAST,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "corrode", "stacks": 1, "target": "enemy"}, null)

	var a1 := _make_action("navy_boarding_axe", "Boarding Axe",
		"A brutal chop with a boarding axe.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Axe Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.SLASHING, 3, 1.3)],
		[])

	var a2 := _make_action("navy_breach", "Breach",
		"Hack through defenses, corroding armor.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Breach Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.SLASHING, 0, 0.8),
		 _make_status_effect("Breach Corrode", ActionEffect.TargetType.SINGLE_ENEMY, "corrode", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "corrode", 20.0)])

	# Hull Splitter uses TARGET_STATUS_STACKS value source
	var splitter_dmg := ActionEffect.new()
	splitter_dmg.effect_name = "Splitter Damage"
	splitter_dmg.effect_type = ActionEffect.EffectType.DAMAGE
	splitter_dmg.target = ActionEffect.TargetType.SINGLE_ENEMY
	splitter_dmg.value_source = ActionEffect.ValueSource.TARGET_STATUS_STACKS
	splitter_dmg.value_source_status_id = "corrode"
	splitter_dmg.damage_type = ActionEffect.DamageType.SLASHING
	splitter_dmg.base_damage = 3
	splitter_dmg.damage_multiplier = 2.0

	var a3 := _make_action("navy_hull_splitter", "Hull Splitter",
		"Devastating strike that scales with corrosion.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.LIMITED_PER_COMBAT, 2,
		[splitter_dmg,
		 _make_status_effect("Splitter Corrode", ActionEffect.TargetType.SINGLE_ENEMY, "corrode", 1)],
		[_make_hint_mult(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "corrode", 3.0),
		 _make_hint_mult(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "corrode", 0.2)])

	return {
		"template_key": "brute_str",
		"element": "slashing",
		"ai_strategy": 0,
		"ai_config": _make_ai_config(0.5, 0.2, 0.5, 0.3, 0.4, 0.5),
		"health_affix": "enemy_health_str_brute",
		"stat_affixes": ["enemy_armor_str_brute", "enemy_damage_slashing"],
		"dice_affix": da,
		"tier_names": {0: "Marine Boarder", 1: "Veteran Boarder", 2: "Boarding Chief", 3: "Breach Captain", 4: "First-Through-the-Wall"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 1,
		"combat_role": 0,
		"dice_type": "brute",
		"team_aware": false,
		"action_delay": 0.7,
	}


# ============================================================================
# 3. NAVY FENCER
# ============================================================================

func _spec_navy_fencer() -> Dictionary:
	print("\n  -- Navy Fencer --")

	var cond := _make_condition(DiceAffixCondition.Type.SELF_VALUE_ABOVE, 4.0, "")
	var da := _make_dice_affix("Precise Form",
		"Non-first dice get +15% value when value is 4+.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.NOT_FIRST,
		DiceAffix.EffectType.MODIFY_VALUE_PERCENT, 0.15, {}, cond)

	var a1 := _make_action("navy_lunge", "Lunge",
		"A quick thrusting attack.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Lunge Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.PIERCING, 3, 1.3)],
		[])

	var a2 := _make_action("navy_parry", "Parry",
		"Adopt a defensive stance.",
		Action.ActionCategory.BUFF, 1, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Parry Brace", ActionEffect.TargetType.SELF, "braced", 2),
		 _make_status_effect("Parry Dodge", ActionEffect.TargetType.SELF, "dodge", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.SELF_HP_BELOW, 0.5, "", 25.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.SELF_MISSING_STATUS, 0.0, "braced", 10.0)])

	# Riposte: counter_effect is an inline ActionEffect
	var counter_eff := _make_damage_effect("Riposte Counter Damage",
		ActionEffect.TargetType.SINGLE_ENEMY, ActionEffect.ValueSource.DICE_TOTAL,
		ActionEffect.DamageType.PIERCING, 2, 1.1)

	var a3 := _make_action("navy_riposte", "Riposte",
		"Set up a counter-attack.",
		Action.ActionCategory.BUFF, 1, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.LIMITED_PER_TURN, 1,
		[_make_counter_effect("Riposte Counter", ActionEffect.TargetType.SELF, 1, 0, counter_eff)],
		[_make_hint_bonus(ActionAIHint.HintCondition.SELF_HP_ABOVE, 0.4, "", 20.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.TURN_NUMBER_ABOVE, 1.0, "", 10.0)])

	return {
		"template_key": "brute_agi",
		"element": "piercing",
		"ai_strategy": 0,
		"ai_config": _make_ai_config(0.7, 0.4, 0.5, 0.3, 0.6, 0.5),
		"health_affix": "enemy_health_agi_brute",
		"stat_affixes": ["enemy_armor_agi_brute", "enemy_damage_piercing"],
		"dice_affix": da,
		"tier_names": {0: "Navy Fencer", 1: "Fencing Officer", 2: "Blademaster", 3: "Duelmaster-at-Arms", 4: "Grand Duelmaster"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 2,  # AGI
		"combat_role": 0,
		"dice_type": "brute",
		"team_aware": false,
		"action_delay": 0.7,
	}


# ============================================================================
# 4. GRIFFIN-RIDER LANCER
# ============================================================================

func _spec_griffin_rider() -> Dictionary:
	print("\n  -- Griffin-Rider Lancer --")

	var da := _make_dice_affix("Momentum",
		"First die used gets +2 value.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.FIRST,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 2.0, {}, null)

	var a1 := _make_action("navy_diving_strike", "Diving Strike",
		"A devastating aerial attack.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Diving Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.PIERCING, 4, 1.4)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "expose", 30.0)])

	var a2 := _make_action("navy_strafe", "Strafe",
		"A quick pass that exposes weaknesses.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Strafe Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.SLASHING, 0, 0.6),
		 _make_status_effect("Strafe Expose", ActionEffect.TargetType.SINGLE_ENEMY, "expose", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "expose", 25.0)])

	var a3 := _make_action("navy_death_from_above", "Death From Above",
		"A devastating dive that shatters defenses.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.LIMITED_PER_COMBAT, 1,
		[_make_damage_effect("DFA Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.PIERCING, 5, 1.8),
		 _make_status_effect("DFA Expose", ActionEffect.TargetType.SINGLE_ENEMY, "expose", 2)],
		[_make_hint_mult(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "expose", 2.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.NONE, 0.0, "", 20.0)])

	return {
		"template_key": "brute_agi",
		"element": "piercing",
		"ai_strategy": 0,
		"ai_config": _make_ai_config(0.5, 0.2, 0.5, 0.3, 0.7, 0.5),
		"health_affix": "enemy_health_agi_brute",
		"stat_affixes": ["enemy_armor_agi_brute", "enemy_damage_piercing"],
		"dice_affix": da,
		"tier_names": {0: "Griffin-Rider Lancer", 1: "Griffin-Rider Veteran", 2: "Wing Sergeant", 3: "Sky Captain", 4: "Highwind Marshal"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 2,
		"combat_role": 0,
		"dice_type": "brute",
		"team_aware": false,
		"action_delay": 0.7,
	}


# ============================================================================
# 5. RIGGING RUNNER
# ============================================================================

func _spec_rigging_runner() -> Dictionary:
	print("\n  -- Rigging Runner --")

	var cond := _make_condition(DiceAffixCondition.Type.SELF_VALUE_BELOW, 3.0, "")
	var da := _make_dice_affix("Serrated Edge",
		"When die value is 3 or below, apply Bleed to enemy.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.ANY,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "bleed", "stacks": 1, "target": "enemy"}, cond)

	var a1 := _make_action("navy_flurry", "Flurry",
		"A rapid series of slashes.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_random_strikes_effect("Flurry Strikes", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.DamageType.SLASHING, 2, 0.6, true),
		 _make_status_effect("Flurry Bleed", ActionEffect.TargetType.SINGLE_ENEMY, "bleed", 1)],
		[])

	var a2 := _make_action("navy_tumble", "Tumble",
		"Dodge and brace for impact.",
		Action.ActionCategory.BUFF, 1, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Tumble Dodge", ActionEffect.TargetType.SELF, "dodge", 1),
		 _make_status_effect("Tumble Brace", ActionEffect.TargetType.SELF, "braced", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.SELF_HP_BELOW, 0.5, "", 20.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.SELF_MISSING_STATUS, 0.0, "dodge", 10.0)])

	var a3 := _make_action("navy_hamstring_slash", "Hamstring Slash",
		"Cripple the target's movement.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.LIMITED_PER_TURN, 1,
		[_make_damage_effect("Hamstring Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.SLASHING, 1, 0.8),
		 _make_status_effect("Hamstring Slow", ActionEffect.TargetType.SINGLE_ENEMY, "slowed", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "slowed", 25.0)])

	return {
		"template_key": "skirmisher_agi",
		"element": "slashing",
		"ai_strategy": 0,
		"ai_config": _make_ai_config(0.4, 0.3, 0.5, 0.3, 0.3, 0.5),
		"health_affix": "enemy_health_agi_skirmisher",
		"stat_affixes": ["enemy_armor_agi_skirmisher", "enemy_damage_slashing"],
		"dice_affix": da,
		"tier_names": {0: "Rigging Runner", 1: "Topman", 2: "Rigging Master", 3: "Crow's Nest Captain", 4: "The Spider"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 2,
		"combat_role": 1,  # SKIRMISHER
		"dice_type": "skirmisher",
		"team_aware": false,
		"action_delay": 0.5,
	}


# ============================================================================
# 6. NAVY SCOUT
# ============================================================================

func _spec_navy_scout() -> Dictionary:
	print("\n  -- Navy Scout --")

	var da := _make_dice_affix("Marked Target",
		"Last die used applies Expose to enemy.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.LAST,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "expose", "stacks": 1, "target": "enemy"}, null)

	var a1 := _make_action("navy_quick_shot", "Quick Shot",
		"A fast, precise shot.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Quick Shot Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.PIERCING, 0, 0.9)],
		[])

	var a2 := _make_action("navy_smoke_pellet", "Smoke Pellet",
		"Blind and enfeeble the target.",
		Action.ActionCategory.DEBUFF, 3, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Smoke Enfeeble", ActionEffect.TargetType.SINGLE_ENEMY, "enfeeble", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "enfeeble", 20.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 10.0)])

	# Marked Shot uses ACTIVE_STATUS_COUNT
	var marked_dmg := ActionEffect.new()
	marked_dmg.effect_name = "Marked Damage"
	marked_dmg.effect_type = ActionEffect.EffectType.DAMAGE
	marked_dmg.target = ActionEffect.TargetType.SINGLE_ENEMY
	marked_dmg.value_source = ActionEffect.ValueSource.ACTIVE_STATUS_COUNT
	marked_dmg.damage_type = ActionEffect.DamageType.PIERCING
	marked_dmg.base_damage = 3
	marked_dmg.damage_multiplier = 1.0

	var a3 := _make_action("navy_marked_shot", "Marked Shot",
		"Damage scales with debuffs on target.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.LIMITED_PER_TURN, 1,
		[marked_dmg],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "enfeeble", 15.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "corrode", 15.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "expose", 15.0)])

	return {
		"template_key": "skirmisher_agi",
		"element": "piercing",
		"ai_strategy": 2,  # BALANCED
		"ai_config": _make_ai_config(0.4, 0.3, 0.5, 0.3, 0.7, 0.5),
		"health_affix": "enemy_health_agi_skirmisher",
		"stat_affixes": ["enemy_armor_agi_skirmisher", "enemy_damage_piercing"],
		"dice_affix": da,
		"tier_names": {0: "Navy Scout", 1: "Pathfinder", 2: "Chief Scout", 3: "Recon Captain", 4: "The Cartographer"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 2,
		"combat_role": 1,
		"dice_type": "skirmisher",
		"team_aware": false,
		"action_delay": 0.7,
	}


# ============================================================================
# 7. WARDBREAKER
# ============================================================================

func _spec_wardbreaker() -> Dictionary:
	print("\n  -- Wardbreaker --")

	var cond := _make_condition(DiceAffixCondition.Type.TARGET_HAS_STATUS, 0.0, "corrode")
	var da := _make_dice_affix("Disruptor Pulse",
		"First die used applies Corrode if target already has Corrode.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.FIRST,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "corrode", "stacks": 1, "target": "enemy"}, cond)

	var a1 := _make_action("navy_disruption_bolt", "Disruption Bolt",
		"A shock bolt that corrodes defenses.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SHOCK, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Disruption Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.SHOCK, 1, 0.9),
		 _make_status_effect("Disruption Corrode", ActionEffect.TargetType.SINGLE_ENEMY, "corrode", 1)],
		[])

	var a2 := _make_action("navy_strip_wards", "Strip Wards",
		"Tear down magical protections.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SHOCK, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Strip Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.SHOCK, 0, 0.5),
		 _make_status_effect("Strip Expose", ActionEffect.TargetType.SINGLE_ENEMY, "expose", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "expose", 20.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 15.0)])

	# Overload uses TARGET_STATUS_STACKS
	var overload_dmg := ActionEffect.new()
	overload_dmg.effect_name = "Overload Damage"
	overload_dmg.effect_type = ActionEffect.EffectType.DAMAGE
	overload_dmg.target = ActionEffect.TargetType.SINGLE_ENEMY
	overload_dmg.value_source = ActionEffect.ValueSource.TARGET_STATUS_STACKS
	overload_dmg.value_source_status_id = "corrode"
	overload_dmg.damage_type = ActionEffect.DamageType.SHOCK
	overload_dmg.base_damage = 4
	overload_dmg.damage_multiplier = 2.0

	var a3 := _make_action("navy_overload", "Overload",
		"Devastating attack that scales with corrosion.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SHOCK, 1,
		Action.ChargeType.LIMITED_PER_COMBAT, 2,
		[overload_dmg],
		[_make_hint_mult(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "corrode", 3.0),
		 _make_hint_mult(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "corrode", 0.1)])

	return {
		"template_key": "skirmisher_int",
		"element": "shock",
		"ai_strategy": 2,
		"ai_config": _make_ai_config(0.6, 0.3, 0.5, 0.3, 0.8, 0.5),
		"health_affix": "enemy_health_int_skirmisher",
		"stat_affixes": ["enemy_barrier_int_skirmisher", "enemy_damage_shock"],
		"dice_affix": da,
		"tier_names": {0: "Wardbreaker", 1: "Senior Wardbreaker", 2: "Wardbreaker Adept", 3: "Wardbreaker Captain", 4: "Siegebreaker"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 3,  # INT
		"combat_role": 1,
		"dice_type": "skirmisher",
		"team_aware": false,
		"action_delay": 0.6,
	}


# ============================================================================
# 8. WEATHER MAGE
# ============================================================================

func _spec_weather_mage() -> Dictionary:
	print("\n  -- Weather Mage --")

	var cond := _make_condition(DiceAffixCondition.Type.SELF_VALUE_IS_MAX, 0.0, "")
	var da := _make_dice_affix("Charged Air",
		"On max roll, gain Warded.",
		DiceAffix.Trigger.ON_ROLL, DiceAffix.PositionRequirement.ANY,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "warded", "stacks": 1, "target": "self"}, cond)

	var a1 := _make_action("navy_lightning_strike", "Lightning Strike",
		"A bolt of lightning with residual static.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SHOCK, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Lightning Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.SHOCK, 2, 1.1),
		 _make_status_effect("Lightning Static", ActionEffect.TargetType.SINGLE_ENEMY, "static", 2)],
		[])

	var a2 := _make_action("navy_storm_ward", "Storm Ward",
		"Conjure protective wards.",
		Action.ActionCategory.BUFF, 1, ActionEffect.DamageType.SHOCK, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Storm Warded", ActionEffect.TargetType.SELF, "warded", 3)],
		[_make_hint_bonus(ActionAIHint.HintCondition.SELF_HP_BELOW, 0.6, "", 25.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.SELF_MISSING_STATUS, 0.0, "warded", 15.0)])

	var a3 := _make_action("navy_chain_lightning", "Chain Lightning",
		"Lightning arcs between targets.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SHOCK, 1,
		Action.ChargeType.LIMITED_PER_TURN, 1,
		[_make_chain_effect("Chain Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.DamageType.SHOCK, 1, 1.0, 2, 0.7),
		 _make_status_effect("Chain Static", ActionEffect.TargetType.SINGLE_ENEMY, "static", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.NONE, 0.0, "", 15.0)])

	return {
		"template_key": "caster_int",
		"element": "shock",
		"ai_strategy": 2,
		"ai_config": _make_ai_config(0.8, 0.5, 0.5, 0.3, 0.6, 0.5),
		"health_affix": "enemy_health_int_caster",
		"stat_affixes": ["enemy_barrier_int_caster", "enemy_damage_shock"],
		"dice_affix": da,
		"tier_names": {0: "Weather Mage", 1: "Stormcaller", 2: "Tempest Mage", 3: "Squall Captain", 4: "Hurricane Lord"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 3,
		"combat_role": 2,  # CASTER
		"dice_type": "standard",
		"team_aware": false,
		"action_delay": 0.7,
	}


# ============================================================================
# 9. NAVAL ARCANIST
# ============================================================================

func _spec_naval_arcanist() -> Dictionary:
	print("\n  -- Naval Arcanist --")

	var da := _make_dice_affix("Lingering Flame",
		"Last die used applies Burn to enemy.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.LAST,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "burn", "stacks": 1, "target": "enemy"}, null)

	var a1 := _make_action("navy_arcane_barrage", "Arcane Barrage",
		"A barrage of arcane fire.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.FIRE, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Barrage Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.FIRE, 2, 1.1)],
		[])

	var a2 := _make_action("navy_focused_salvo", "Focused Salvo",
		"Concentrated fire that leaves a lasting burn.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.FIRE, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Salvo Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.FIRE, 0, 0.7),
		 _make_status_effect("Salvo Burn", ActionEffect.TargetType.SINGLE_ENEMY, "burn", 3)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "burn", 20.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "burn", 10.0)])

	var a3 := _make_action("navy_incendiary_salvo", "Incendiary Salvo",
		"A devastating firebomb barrage.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.FIRE, 1,
		Action.ChargeType.LIMITED_PER_COMBAT, 1,
		[_make_damage_effect("Incendiary Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.FIRE, 3, 1.3),
		 _make_status_effect("Incendiary Burn", ActionEffect.TargetType.SINGLE_ENEMY, "burn", 5)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TURN_NUMBER_ABOVE, 0.0, "", 30.0)])

	return {
		"template_key": "caster_int",
		"element": "fire",
		"ai_strategy": 2,
		"ai_config": _make_ai_config(0.8, 0.5, 0.5, 0.3, 0.5, 0.5),
		"health_affix": "enemy_health_int_caster",
		"stat_affixes": ["enemy_barrier_int_caster", "enemy_damage_fire"],
		"dice_affix": da,
		"tier_names": {0: "Naval Arcanist", 1: "Senior Arcanist", 2: "Battle Arcanist", 3: "Arcanist-Commander", 4: "Archmage-Admiral"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 3,
		"combat_role": 2,
		"dice_type": "standard",
		"team_aware": false,
		"action_delay": 0.7,
	}


# ============================================================================
# 10. NAVY SHIELDBEARER
# ============================================================================

func _spec_navy_shieldbearer() -> Dictionary:
	print("\n  -- Navy Shieldbearer --")

	var da := _make_dice_affix("Shield Brace",
		"First die rolled grants Fortified.",
		DiceAffix.Trigger.ON_ROLL, DiceAffix.PositionRequirement.FIRST,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "fortified", "stacks": 1, "target": "self"}, null)

	var a1 := _make_action("navy_shield_bash", "Shield Bash",
		"Bash with a heavy shield.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Bash Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.BLUNT, 0, 0.7),
		 _make_status_effect("Bash Slow", ActionEffect.TargetType.SINGLE_ENEMY, "slowed", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "slowed", 15.0)])

	var a2 := _make_action("navy_iron_wall", "Iron Wall",
		"Raise an impenetrable defense.",
		Action.ActionCategory.BUFF, 1, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Wall Fortify", ActionEffect.TargetType.SELF, "fortified", 4),
		 _make_status_effect("Wall Brace", ActionEffect.TargetType.SELF, "braced", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.SELF_MISSING_STATUS, 0.0, "fortified", 20.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 10.0)])

	var a3 := _make_action("navy_shield_charge", "Shield Charge",
		"Rush forward, slamming and fortifying.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.LIMITED_PER_TURN, 1,
		[_make_damage_effect("Charge Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.BLUNT, 2, 1.0),
		 _make_status_effect("Charge Slow", ActionEffect.TargetType.SINGLE_ENEMY, "slowed", 2),
		 _make_status_effect("Charge Fortify", ActionEffect.TargetType.SELF, "fortified", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.SELF_HP_ABOVE, 0.5, "", 15.0)])

	return {
		"template_key": "tank_str",
		"element": "blunt",
		"ai_strategy": 1,  # DEFENSIVE
		"ai_config": _make_ai_config(0.4, 0.6, 0.6, 0.3, 0.5, 0.5),
		"health_affix": "enemy_health_str_tank",
		"stat_affixes": ["enemy_armor_str_tank", "enemy_damage_blunt"],
		"dice_affix": da,
		"tier_names": {0: "Navy Shieldbearer", 1: "Shieldwall Veteran", 2: "Shieldwall Sergeant", 3: "Bulwark Captain", 4: "The Ironwall"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 1,
		"combat_role": 3,  # TANK
		"dice_type": "standard",
		"team_aware": false,
		"action_delay": 1.0,
	}


# ============================================================================
# 11. HARBOUR SENTINEL
# ============================================================================

func _spec_harbour_sentinel() -> Dictionary:
	print("\n  -- Harbour Sentinel --")

	var da := _make_dice_affix("Anchored",
		"All dice get +1 value on roll.",
		DiceAffix.Trigger.ON_ROLL, DiceAffix.PositionRequirement.ANY,
		DiceAffix.EffectType.MODIFY_VALUE_FLAT, 1.0, {}, null)

	var a1 := _make_action("navy_pavise_strike", "Pavise Strike",
		"A slow but solid strike.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Pavise Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.BLUNT, 0, 0.5)],
		[])

	var a2 := _make_action("navy_dig_in", "Dig In",
		"Fortify and draw enemy attention.",
		Action.ActionCategory.BUFF, 1, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Dig In Fortify", ActionEffect.TargetType.SELF, "fortified", 5),
		 _make_status_effect("Dig In Taunt", ActionEffect.TargetType.SELF, "taunt", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 40.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.SELF_MISSING_STATUS, 0.0, "taunt", 20.0),
		 _make_hint_mult(ActionAIHint.HintCondition.ALLY_COUNT_BELOW, 1.0, "", 0.3)])

	var a3 := _make_action("navy_immovable_object", "Immovable Object",
		"Become an unyielding bulwark.",
		Action.ActionCategory.BUFF, 1, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.LIMITED_PER_TURN, 1,
		[_make_reflect_effect("Immovable Reflect", ActionEffect.TargetType.SELF, 0.3, 1),
		 _make_dr_effect("Immovable DR", ActionEffect.TargetType.SELF, 0.25, true, 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.SELF_HAS_STATUS, 0.0, "taunt", 35.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.SELF_HP_BELOW, 0.5, "", 15.0)])

	return {
		"template_key": "tank_str",
		"element": "blunt",
		"ai_strategy": 1,
		"ai_config": _make_ai_config(0.3, 0.7, 0.7, 0.3, 0.4, 0.5),
		"health_affix": "enemy_health_str_tank",
		"stat_affixes": ["enemy_armor_str_tank", "enemy_damage_blunt"],
		"dice_affix": da,
		"tier_names": {0: "Harbour Sentinel", 1: "Gate Sentinel", 2: "Harbour Warden", 3: "Portmaster-at-Arms", 4: "The Anchorstone"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 1,
		"combat_role": 3,
		"dice_type": "standard",
		"team_aware": false,
		"action_delay": 1.2,
	}


# ============================================================================
# 12. WARD OFFICER
# ============================================================================

func _spec_ward_officer() -> Dictionary:
	print("\n  -- Ward Officer --")

	var da := _make_dice_affix("Passive Ward",
		"First die rolled grants Warded.",
		DiceAffix.Trigger.ON_ROLL, DiceAffix.PositionRequirement.FIRST,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "warded", "stacks": 1, "target": "self"}, null)

	var a1 := _make_action("navy_ward_bolt", "Ward Bolt",
		"Shadow bolt that reinforces self.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.SHADOW, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Ward Bolt Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.SHADOW, 0, 0.7),
		 _make_status_effect("Ward Bolt Shield", ActionEffect.TargetType.SELF, "warded", 1)],
		[])

	var a2 := _make_action("navy_project_barrier", "Project Barrier",
		"Project wards onto an ally.",
		Action.ActionCategory.BUFF, 1, ActionEffect.DamageType.SHADOW, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Project Ward", ActionEffect.TargetType.SINGLE_ALLY, "warded", 3)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 30.0),
		 _make_hint_mult(ActionAIHint.HintCondition.ALLY_COUNT_BELOW, 1.0, "", 0.2)])

	var a3 := _make_action("navy_barrier_overcharge", "Barrier Overcharge",
		"Overcharge all allies with protective wards.",
		Action.ActionCategory.BUFF, 1, ActionEffect.DamageType.SHADOW, 1,
		Action.ChargeType.LIMITED_PER_COMBAT, 2,
		[_make_status_effect("Overcharge All Wards", ActionEffect.TargetType.ALL_ALLIES, "warded", 3),
		 _make_status_effect("Overcharge Self Ward", ActionEffect.TargetType.SELF, "warded", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 2.0, "", 40.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 20.0)])

	return {
		"template_key": "tank_int",
		"element": "shadow",
		"ai_strategy": 1,
		"ai_config": _make_ai_config(0.5, 0.6, 0.6, 0.3, 0.7, 0.8),
		"health_affix": "enemy_health_int_tank",
		"stat_affixes": ["enemy_armor_int_tank", "enemy_barrier_int_tank", "enemy_damage_shadow"],
		"dice_affix": da,
		"tier_names": {0: "Ward Officer", 1: "Senior Ward Officer", 2: "Ward Commander", 3: "Barrier Captain", 4: "Aegis-Admiral"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 3,
		"combat_role": 3,
		"dice_type": "standard",
		"team_aware": false,
		"action_delay": 0.7,
	}


# ============================================================================
# 13. NAVY SERGEANT
# ============================================================================

func _spec_navy_sergeant() -> Dictionary:
	print("\n  -- Navy Sergeant --")

	# No dice affix for Sergeant

	var a1 := _make_action("navy_bark_orders", "Bark Orders",
		"Empower an ally.",
		Action.ActionCategory.BUFF, 3, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Orders Empower", ActionEffect.TargetType.SINGLE_ALLY, "empowered", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 25.0),
		 _make_hint_mult(ActionAIHint.HintCondition.ALLY_COUNT_BELOW, 1.0, "", 0.2)])

	var a2 := _make_action("navy_tactical_strike", "Tactical Strike",
		"Attack that exposes the target.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Tactical Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.BLUNT, 1, 0.9),
		 _make_status_effect("Tactical Expose", ActionEffect.TargetType.SINGLE_ENEMY, "expose", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "expose", 15.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_BELOW, 1.0, "", 20.0)])

	var a3 := _make_action("navy_coordinated_assault", "Coordinated Assault",
		"Expose the target and empower all allies.",
		Action.ActionCategory.DEBUFF, 3, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.LIMITED_PER_TURN, 1,
		[_make_status_effect("Assault Expose", ActionEffect.TargetType.SINGLE_ENEMY, "expose", 2),
		 _make_status_effect("Assault Empower Allies", ActionEffect.TargetType.ALL_ALLIES, "empowered", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 2.0, "", 50.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 25.0),
		 _make_hint_mult(ActionAIHint.HintCondition.ALLY_COUNT_BELOW, 1.0, "", 0.1)])

	return {
		"template_key": "support_str",
		"element": "blunt",
		"ai_strategy": 2,
		"ai_config": _make_ai_config(0.3, 0.3, 0.5, 0.3, 0.7, 0.8),
		"health_affix": "enemy_health_str_support",
		"stat_affixes": ["enemy_damage_blunt"],
		"dice_affix": null,
		"tier_names": {0: "Navy Sergeant", 1: "Staff Sergeant", 2: "Master Sergeant", 3: "Command Sergeant", 4: "Sergeant-Admiral"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 1,
		"combat_role": 4,  # SUPPORT
		"dice_type": "standard",
		"team_aware": true,
		"action_delay": 0.7,
	}


# ============================================================================
# 14. DRUM MAJOR
# ============================================================================

func _spec_drum_major() -> Dictionary:
	print("\n  -- Drum Major --")

	var da := _make_dice_affix("Steady Rhythm",
		"All dice have a minimum value of 3.",
		DiceAffix.Trigger.ON_ROLL, DiceAffix.PositionRequirement.ANY,
		DiceAffix.EffectType.SET_MINIMUM_VALUE, 3.0, {}, null)

	var a1 := _make_action("navy_war_beat", "War Beat",
		"Empower and fortify all allies.",
		Action.ActionCategory.BUFF, 3, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Beat Empower", ActionEffect.TargetType.ALL_ALLIES, "empowered", 1),
		 _make_status_effect("Beat Fortify", ActionEffect.TargetType.ALL_ALLIES, "fortified", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 30.0)])

	var a2 := _make_action("navy_drumstick", "Drumstick",
		"A weak melee attack.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_damage_effect("Drumstick Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.BLUNT, 0, 0.5)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_BELOW, 1.0, "", 30.0)])

	var a3 := _make_action("navy_crescendo", "Crescendo",
		"A powerful rally that empowers and fortifies all allies.",
		Action.ActionCategory.BUFF, 3, ActionEffect.DamageType.BLUNT, 1,
		Action.ChargeType.LIMITED_PER_COMBAT, 2,
		[_make_status_effect("Crescendo Empower", ActionEffect.TargetType.ALL_ALLIES, "empowered", 2),
		 _make_status_effect("Crescendo Fortify", ActionEffect.TargetType.ALL_ALLIES, "fortified", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 2.0, "", 50.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 30.0),
		 _make_hint_mult(ActionAIHint.HintCondition.ALLY_COUNT_BELOW, 1.0, "", 0.05)])

	return {
		"template_key": "support_str",
		"element": "blunt",
		"ai_strategy": 1,
		"ai_config": _make_ai_config(0.2, 0.4, 0.5, 0.3, 0.4, 0.9),
		"health_affix": "enemy_health_str_support",
		"stat_affixes": ["enemy_damage_blunt"],
		"dice_affix": da,
		"tier_names": {0: "Drum Major", 1: "Senior Drummer", 2: "Drumline Captain", 3: "Warsong Commander", 4: "The Cadence"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 1,
		"combat_role": 4,
		"dice_type": "support",  # Fewer dice
		"team_aware": true,
		"action_delay": 0.7,
	}


# ============================================================================
# 15. NAVY CHIRURGEON
# ============================================================================

func _spec_navy_chirurgeon() -> Dictionary:
	print("\n  -- Navy Chirurgeon --")

	var da := _make_dice_affix("Triage Training",
		"First die rolled has minimum value 2.",
		DiceAffix.Trigger.ON_ROLL, DiceAffix.PositionRequirement.FIRST,
		DiceAffix.EffectType.SET_MINIMUM_VALUE, 2.0, {}, null)

	var a1 := _make_action("navy_field_surgery", "Field Surgery",
		"Heal an ally using dice.",
		Action.ActionCategory.HEAL, 2, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_heal_effect("Surgery Heal", ActionEffect.TargetType.SINGLE_ALLY, true, 1.0)],
		[_make_hint_bonus(ActionAIHint.HintCondition.NONE, 0.0, "", 20.0)])

	var cleanse_tags: Array[String] = ["debuff"]
	var a2 := _make_action("navy_triage", "Triage",
		"Heal all allies and cleanse a debuff.",
		Action.ActionCategory.HEAL, 2, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_heal_effect("Triage Heal", ActionEffect.TargetType.ALL_ALLIES, true, 0.5),
		 _make_cleanse_effect("Triage Cleanse", ActionEffect.TargetType.ALL_ALLIES, cleanse_tags, 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 2.0, "", 25.0)])

	var a3 := _make_action("navy_emergency_procedure", "Emergency Procedure",
		"Powerful emergency heal with fortification.",
		Action.ActionCategory.HEAL, 2, ActionEffect.DamageType.SLASHING, 1,
		Action.ChargeType.LIMITED_PER_TURN, 1,
		[_make_heal_effect("Emergency Heal", ActionEffect.TargetType.SINGLE_ALLY, true, 1.8),
		 _make_status_effect("Emergency Fortify", ActionEffect.TargetType.SINGLE_ALLY, "fortified", 2)],
		[_make_hint_force(ActionAIHint.HintCondition.SELF_HP_BELOW, 0.4, "")])

	return {
		"template_key": "support_int",
		"element": "none",
		"ai_strategy": 1,
		"ai_config": _make_ai_config(0.2, 0.9, 0.7, 0.4, 0.6, 0.5),
		"health_affix": "enemy_health_int_support",
		"stat_affixes": ["enemy_barrier_int_support", "enemy_damage_ice"],
		"dice_affix": da,
		"tier_names": {0: "Navy Chirurgeon", 1: "Senior Chirurgeon", 2: "Chief Chirurgeon", 3: "Chirurgeon-Captain", 4: "Surgeon-Admiral"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 3,
		"combat_role": 4,
		"dice_type": "support",  # Fewer dice, element=none
		"dice_element_override": "none",
		"team_aware": true,
		"action_delay": 0.7,
	}


# ============================================================================
# 16. TIDE PRIEST
# ============================================================================

func _spec_tide_priest() -> Dictionary:
	print("\n  -- Tide Priest --")

	var cond := _make_condition(DiceAffixCondition.Type.SELF_VALUE_IS_MAX, 0.0, "")
	var da := _make_dice_affix("Tidal Surge",
		"On max roll, apply Chill to enemy.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.ANY,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "chill", "stacks": 1, "target": "enemy"}, cond)

	var a1 := _make_action("navy_tidal_blessing", "Tidal Blessing",
		"Heal an ally with the power of the tides.",
		Action.ActionCategory.HEAL, 2, ActionEffect.DamageType.ICE, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_heal_effect("Blessing Heal", ActionEffect.TargetType.SINGLE_ALLY, true, 1.2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.NONE, 0.0, "", 15.0)])

	var a2 := _make_action("navy_undertow", "Undertow",
		"Corrode and enfeeble the target.",
		Action.ActionCategory.DEBUFF, 3, ActionEffect.DamageType.ICE, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Undertow Corrode", ActionEffect.TargetType.SINGLE_ENEMY, "corrode", 2),
		 _make_status_effect("Undertow Enfeeble", ActionEffect.TargetType.SINGLE_ENEMY, "enfeeble", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "corrode", 20.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 10.0)])

	var a3 := _make_action("navy_riptide", "Riptide",
		"A chilling attack that corrodes defenses.",
		Action.ActionCategory.ATTACK, 0, ActionEffect.DamageType.ICE, 1,
		Action.ChargeType.LIMITED_PER_TURN, 1,
		[_make_damage_effect("Riptide Damage", ActionEffect.TargetType.SINGLE_ENEMY,
			ActionEffect.ValueSource.DICE_TOTAL, ActionEffect.DamageType.ICE, 1, 0.8),
		 _make_status_effect("Riptide Chill", ActionEffect.TargetType.SINGLE_ENEMY, "chill", 3),
		 _make_status_effect("Riptide Corrode", ActionEffect.TargetType.SINGLE_ENEMY, "corrode", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_HAS_STATUS, 0.0, "chill", 20.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "chill", 10.0)])

	return {
		"template_key": "support_int",
		"element": "ice",
		"ai_strategy": 1,
		"ai_config": _make_ai_config(0.6, 0.7, 0.6, 0.35, 0.7, 0.5),
		"health_affix": "enemy_health_int_support",
		"stat_affixes": ["enemy_barrier_int_support", "enemy_damage_ice"],
		"dice_affix": da,
		"tier_names": {0: "Tide Priest", 1: "Tide Chaplain", 2: "High Tide Priest", 3: "Tide Oracle", 4: "Tidecaller-Absolute"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 3,
		"combat_role": 4,
		"dice_type": "support",  # Fewer dice, element=ice
		"dice_element_override": "ice",
		"team_aware": false,
		"action_delay": 0.7,
	}


# ============================================================================
# 17. SIGNALMAN
# ============================================================================

func _spec_signalman() -> Dictionary:
	print("\n  -- Signalman --")

	var cond := _make_condition(DiceAffixCondition.Type.SELF_VALUE_IS_MAX, 0.0, "")
	var da := _make_dice_affix("Blinding Flash",
		"On max roll, first die applies Enfeeble to enemy.",
		DiceAffix.Trigger.ON_USE, DiceAffix.PositionRequirement.FIRST,
		DiceAffix.EffectType.GRANT_STATUS_EFFECT, 0.0,
		{"status_id": "enfeeble", "stacks": 1, "target": "enemy"}, cond)

	var a1 := _make_action("navy_flash_signal", "Flash Signal",
		"Blind and expose the target.",
		Action.ActionCategory.DEBUFF, 3, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Flash Enfeeble", ActionEffect.TargetType.SINGLE_ENEMY, "enfeeble", 1),
		 _make_status_effect("Flash Expose", ActionEffect.TargetType.SINGLE_ENEMY, "expose", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 20.0)])

	var a2 := _make_action("navy_mirror_trick", "Mirror Trick",
		"Disorient and slow the target.",
		Action.ActionCategory.DEBUFF, 3, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.UNLIMITED, 1,
		[_make_status_effect("Mirror Slow", ActionEffect.TargetType.SINGLE_ENEMY, "slowed", 2)],
		[_make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "slowed", 20.0)])

	var a3 := _make_action("navy_false_retreat", "False Retreat",
		"Feign retreat to disorient and dodge.",
		Action.ActionCategory.DEBUFF, 3, ActionEffect.DamageType.PIERCING, 1,
		Action.ChargeType.LIMITED_PER_COMBAT, 2,
		[_make_status_effect("Retreat Slow", ActionEffect.TargetType.SINGLE_ENEMY, "slowed", 1),
		 _make_status_effect("Retreat Expose", ActionEffect.TargetType.SINGLE_ENEMY, "expose", 2),
		 _make_status_effect("Retreat Dodge", ActionEffect.TargetType.SELF, "dodge", 1)],
		[_make_hint_bonus(ActionAIHint.HintCondition.ALLY_COUNT_ABOVE, 1.0, "", 30.0),
		 _make_hint_bonus(ActionAIHint.HintCondition.TARGET_MISSING_STATUS, 0.0, "expose", 15.0)])

	return {
		"template_key": "support_agi",
		"element": "piercing",
		"ai_strategy": 2,
		"ai_config": _make_ai_config(0.3, 0.3, 0.5, 0.3, 0.9, 0.7),
		"health_affix": "enemy_health_agi_support",
		"stat_affixes": ["enemy_damage_piercing"],
		"dice_affix": da,
		"tier_names": {0: "Signalman", 1: "Senior Signalman", 2: "Signal Officer", 3: "Signal Captain", 4: "The Semaphore"},
		"all_actions": [a1, a2],
		"elite_actions": [a1, a2, a3],
		"archetype": 2,
		"combat_role": 4,
		"dice_type": "standard",
		"team_aware": true,
		"action_delay": 0.6,
	}


# ============================================================================
# ENEMY CREATION (5 tiers per spec)
# ============================================================================

func _create_enemy_tiers(spec: Dictionary):
	var tier_names: Dictionary = spec["tier_names"]
	var folders := ["trash", "elite", "mini_boss", "boss", "world_boss"]

	for tier_idx in range(5):
		var tier_name: String = tier_names[tier_idx]
		var folder: String = folders[tier_idx]
		print("  Creating: %s (tier %d)" % [tier_name, tier_idx])

		var enemy := EnemyData.new()
		enemy.enemy_name = tier_name
		enemy.description = "Sanctum Navy %s." % tier_name
		enemy.enemy_tags = PackedStringArray(["navy", "humanoid"])

		# Template
		var tkey: String = spec["template_key"]
		if _templates.has(tkey):
			enemy.template = _templates[tkey]

		# Combat role
		enemy.combat_role = spec["combat_role"]

		# AI
		enemy.ai_strategy = spec["ai_strategy"]
		enemy.ai_config = spec["ai_config"]
		enemy.team_aware = spec.get("team_aware", false)
		enemy.action_delay = spec.get("action_delay", 0.7)
		enemy.dice_drag_duration = 0.35

		# Health affix
		var health_key: String = spec["health_affix"]
		if _health_affix_cache.has(health_key):
			enemy.health_affix = _health_affix_cache[health_key]

		# Stat affixes
		var stat_keys: Array = spec["stat_affixes"]
		var stat_affixes: Array[Affix] = []
		for sk in stat_keys:
			if _stat_affix_cache.has(sk):
				stat_affixes.append(_stat_affix_cache[sk])
		enemy.enemy_affixes.assign(stat_affixes)

		# Stats
		enemy.max_health = BASE_HP[tier_idx]
		enemy.base_armor = 0
		enemy.base_barrier = 0

		# Actions
		var actions: Array[Action] = []
		if tier_idx == TIER_TRASH:
			for a in spec["all_actions"]:
				actions.append(a)
		else:
			for a in spec["elite_actions"]:
				actions.append(a)
		enemy.combat_actions.assign(actions)

		# Dice pool
		var dice: Array[DieResource] = _build_dice_for_spec(spec, tier_idx)
		enemy.starting_dice.assign(dice)

		# Rewards
		enemy.experience_reward = XP_REWARDS[tier_idx]
		enemy.gold_reward_min = GOLD_MIN[tier_idx]
		enemy.gold_reward_max = GOLD_MAX[tier_idx]

		# Tier / Archetype / Level
		enemy.enemy_tier = tier_idx
		enemy.enemy_archetype = spec["archetype"]
		enemy.enemy_level_floor = LEVEL_FLOORS[tier_idx]
		enemy.level_scaling_multiplier = LEVEL_SCALING[tier_idx]

		# Save
		var safe_name: String = tier_name.to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
		var path := "%s/%s/%s.tres" % [OUTPUT_DIR, folder, safe_name]
		var err := ResourceSaver.save(enemy, path)
		if err == OK:
			_count += 1
			print("    SAVED: %s" % path)
		else:
			push_error("    FAILED saving: %s -- %s" % [path, error_string(err)])
			_errors += 1


func _build_dice_for_spec(spec: Dictionary, tier_idx: int) -> Array[DieResource]:
	var dice: Array[DieResource] = []
	var dice_type: String = spec.get("dice_type", "standard")
	var element: String = spec.get("dice_element_override", spec.get("element", "none"))

	# Determine dice count
	var dice_count: int
	match dice_type:
		"brute":
			dice_count = STANDARD_DICE_COUNTS[tier_idx]
		"skirmisher":
			dice_count = SKIRMISHER_DICE_COUNTS[tier_idx]
		"support":
			dice_count = SUPPORT_DICE_COUNTS[tier_idx]
		_:
			dice_count = STANDARD_DICE_COUNTS[tier_idx]

	# Determine die size
	var die_size: int
	match dice_type:
		"brute":
			die_size = BRUTE_DIE_SIZES[tier_idx]
		_:
			die_size = STANDARD_DIE_SIZES[tier_idx]

	# Build dice
	var dice_affix = spec.get("dice_affix")
	for i in range(dice_count):
		var key := "d%d_%s" % [die_size, element]
		if not _dice_cache.has(key):
			key = "d%d_none" % die_size
		if _dice_cache.has(key):
			var die_template: DieResource = _dice_cache[key]
			var die_copy: DieResource = die_template.duplicate(true)
			# Reassign typed arrays to make them writable after duplicate
			var fresh_affixes: Array[DiceAffix] = []
			for existing in die_copy.inherent_affixes:
				fresh_affixes.append(existing)
			if dice_affix:
				var affix_copy: DiceAffix = dice_affix.duplicate(true)
				fresh_affixes.append(affix_copy)
			die_copy.inherent_affixes = fresh_affixes
			dice.append(die_copy)
		else:
			push_error("    Missing die: d%d_%s" % [die_size, element])
			_errors += 1

	return dice
