@tool
extends EditorScript
# ============================================================================
# generate_enemy_template_system.gd
# One-shot generator: creates the entire enemy template baseline system.
#
# OUTPUT: 51 resources total
#   1  StatusAffix  (empowered.tres)
#   10 Affix        (enemy health affixes)
#   30 Action       (base enemy actions — 3 per template)
#   10 EnemyTemplate (with 5 inline RoleTierBudgets each)
#
# PREREQUISITES (must exist before running):
#   1. res://resources/data/enemy_template.gd   (class EnemyTemplate)
#   2. res://resources/data/role_tier_budget.gd  (class RoleTierBudget)
#   3. res://resources/data/status_affix.gd      (class StatusAffix)
#   4. Existing statuses: bleed.tres, burn.tres, corrode.tres, chill.tres,
#      slowed.tres in res://resources/statuses/
#   5. res://resources/affixes/global_roll_curve.tres (shared Curve)
#
# PATTERNS APPLIED (from prior generator debugging):
#   - .assign() for ALL typed array assignments (silent abort prevention)
#   - Save-then-load for cross-file references (proper ExtResource paths)
#   - DirAccess.make_dir_recursive_absolute() before any saves
#   - Counter tracking + verification per phase
#   - Explicit script loading as fallback for class_name resolution
#
# Run: Editor → File → Run (or Ctrl+Shift+X with this script open)
# SAFE TO RE-RUN: Overwrites existing files.
# ============================================================================

# ── Output directories ──
const STATUS_DIR := "res://resources/statuses"
const HEALTH_DIR := "res://resources/affixes/base_stats/enemy"
const ACTION_DIR := "res://resources/actions/enemy_base"
const TEMPLATE_DIR := "res://resources/enemy_templates"
const CURVE_PATH := "res://resources/affixes/global_roll_curve.tres"

# ── Counters ──
var _statuses := 0
var _affixes := 0
var _actions := 0
var _templates := 0
var _errors := 0

# ── Cached resources (loaded from disk after save) ──
var _status_cache: Dictionary = {}   # status_id → StatusAffix
var _health_cache: Dictionary = {}   # template_key → Affix
var _action_cache: Dictionary = {}   # file_name → Action
var _roll_curve: Curve = null

# ── Script references (fallback if class_name doesn't resolve in @tool) ──
var _affix_script: Script = null
var _action_script: Script = null
var _effect_script: Script = null
var _status_affix_script: Script = null
var _template_script: Script = null
var _budget_script: Script = null

# ── Enum shortcuts (resolved at runtime from loaded scripts) ──
# ActionEffect enums
var ET: Dictionary = {}  # EffectType
var TT: Dictionary = {}  # TargetType
var DT: Dictionary = {}  # DamageType
var VS: Dictionary = {}  # ValueSource
# DieResource enums
var DIE: Dictionary = {} # DieType
# Action enums
var CT: Dictionary = {}  # ChargeType
# EnemyData enums
var AI: Dictionary = {}  # AIStrategy
var TP: Dictionary = {}  # TargetPriority
# EnemyTemplate enums
var CR: Dictionary = {}  # CombatRole
var DP: Dictionary = {}  # DefenseProfile
var PH: Dictionary = {}  # DicePhilosophy
# EnemyTierLootConfig enums
var ARCH: Dictionary = {} # Archetype


func _run():
	print("=" .repeat(70))
	print("  ENEMY TEMPLATE SYSTEM GENERATOR")
	print("  Creating: 1 status + 10 health affixes + 30 actions + 10 templates")
	print("=" .repeat(70))

	# ── Phase 0: Validate prerequisites ──
	if not _validate_prerequisites():
		push_error("Aborting — missing prerequisites. See errors above.")
		return

	_load_scripts_and_enums()
	_ensure_directories()

	# ── Phase 1: Create "empowered" status ──
	print("\n" + "─" .repeat(50))
	print("  PHASE 1: STATUS EFFECTS")
	print("─" .repeat(50))
	_create_empowered_status()
	_load_all_statuses()
	print("  Phase 1 complete: %d statuses created, %d cached" % [_statuses, _status_cache.size()])

	# ── Phase 2: Create 10 health affixes ──
	print("\n" + "─" .repeat(50))
	print("  PHASE 2: HEALTH AFFIXES")
	print("─" .repeat(50))
	_create_all_health_affixes()
	_load_all_health_affixes()
	print("  Phase 2 complete: %d affixes created, %d cached" % [_affixes, _health_cache.size()])

	# ── Phase 3: Create 30 base actions ──
	print("\n" + "─" .repeat(50))
	print("  PHASE 3: BASE ACTIONS")
	print("─" .repeat(50))
	_create_all_actions()
	_load_all_actions()
	print("  Phase 3 complete: %d actions created, %d cached" % [_actions, _action_cache.size()])

	# ── Phase 4: Create 10 templates ──
	print("\n" + "─" .repeat(50))
	print("  PHASE 4: ENEMY TEMPLATES")
	print("─" .repeat(50))
	_create_all_templates()
	print("  Phase 4 complete: %d templates created" % _templates)

	# ── Summary ──
	print("\n" + "=" .repeat(70))
	var total := _statuses + _affixes + _actions + _templates
	if _errors == 0:
		print("  ✅ SUCCESS: %d resources created (1 + %d + %d + %d)" % [
			total, _affixes, _actions, _templates])
	else:
		print("  ⚠️ COMPLETED WITH %d ERRORS: %d resources created" % [_errors, total])
	print("=" .repeat(70))


# ============================================================================
# PHASE 0: PREREQUISITES
# ============================================================================

func _validate_prerequisites() -> bool:
	print("\n── Checking prerequisites ──")
	var ok := true

	var required_files := [
		"res://resources/data/enemy_template.gd",
		"res://resources/data/role_tier_budget.gd",
		"res://resources/data/status_affix.gd",
		"res://resources/data/affix.gd",
		"res://resources/data/action.gd",
		"res://scripts/resources/action_effect.gd",
		CURVE_PATH,
	]
	for path: String in required_files:
		if ResourceLoader.exists(path):
			print("  ✅ %s" % path)
		else:
			push_error("  ❌ MISSING: %s" % path)
			ok = false

	var required_statuses := ["bleed", "burn", "corrode", "chill", "slowed"]
	for sid: String in required_statuses:
		var path := "%s/%s.tres" % [STATUS_DIR, sid]
		if ResourceLoader.exists(path):
			print("  ✅ %s" % path)
		else:
			push_error("  ❌ MISSING STATUS: %s" % path)
			ok = false

	return ok


func _load_scripts_and_enums():
	_affix_script = load("res://resources/data/affix.gd")
	_action_script = load("res://resources/data/action.gd")
	_effect_script = load("res://scripts/resources/action_effect.gd")
	_status_affix_script = load("res://resources/data/status_affix.gd")
	_template_script = load("res://resources/data/enemy_template.gd")
	_budget_script = load("res://resources/data/role_tier_budget.gd")

	# Resolve enums at runtime to avoid parse-time class_name issues
	ET = {
		"DAMAGE": 0, "HEAL": 1, "ADD_STATUS": 2, "REMOVE_STATUS": 3, "CLEANSE": 4,
		"SHIELD": 5, "ARMOR_BUFF": 6, "DAMAGE_REDUCTION": 7, "REFLECT": 8,
		"LIFESTEAL": 9, "EXECUTE": 10, "COMBO_MARK": 11, "ECHO": 12,
		"SPLASH": 13, "CHAIN": 14, "RANDOM_STRIKES": 15,
		"MANA_MANIPULATE": 16, "MODIFY_COOLDOWN": 17, "REFUND_CHARGES": 18,
		"GRANT_TEMP_ACTION": 19, "CHANNEL": 20, "COUNTER_SETUP": 21,
	}
	TT = {"SELF": 0, "SINGLE_ENEMY": 1, "ALL_ENEMIES": 2, "SINGLE_ALLY": 3, "ALL_ALLIES": 4}
	DT = {"SLASHING": 0, "BLUNT": 1, "PIERCING": 2, "FIRE": 3, "ICE": 4, "SHOCK": 5, "POISON": 6, "SHADOW": 7}
	VS = {"STATIC": 0, "DICE_TOTAL": 1, "DICE_COUNT": 2}
	DIE = {"D4": 4, "D6": 6, "D8": 8, "D10": 10, "D12": 12, "D20": 20}
	CT = {"UNLIMITED": 0, "LIMITED_PER_TURN": 1, "LIMITED_PER_COMBAT": 2}
	AI = {"AGGRESSIVE": 0, "DEFENSIVE": 1, "BALANCED": 2, "RANDOM": 3}
	TP = {"LOWEST_HEALTH": 0, "HIGHEST_HEALTH": 1, "RANDOM": 2}
	CR = {"BRUTE": 0, "SKIRMISHER": 1, "CASTER": 2, "TANK": 3, "SUPPORT": 4}
	DP = {"ARMOR_HEAVY": 0, "BARRIER_HEAVY": 1, "HYBRID": 2, "MINIMAL": 3}
	PH = {"FEW_LARGE": 0, "MANY_SMALL": 1, "BALANCED": 2}
	ARCH = {"NONE": 0, "STR": 1, "AGI": 2, "INT": 3}


func _ensure_directories():
	for dir_path: String in [STATUS_DIR, HEALTH_DIR, ACTION_DIR, TEMPLATE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir_path)


# ============================================================================
# PHASE 1: EMPOWERED STATUS
# ============================================================================

func _create_empowered_status():
	var path := "%s/empowered.tres" % STATUS_DIR
	var s = _status_affix_script.new()
	s.status_id = "empowered"
	s.affix_name = "Empowered"
	s.description = "Increases damage dealt. Stacks up to 5 times."
	s.show_in_summary = false
	s.category = 36  # MISC — same bucket as chill/slowed
	s.duration_type = 1  # TURN_BASED
	s.default_duration = 2
	s.max_stacks = 5
	s.refresh_on_reapply = true
	s.decay_style = 0  # NONE
	s.is_debuff = false
	s.can_be_cleansed = true

	# .assign() for Array[String] cleanse_tags
	var tags: Array[String] = ["buff", "empower", "offensive_buff"]
	s.cleanse_tags.assign(tags)

	if _save_resource(s, path):
		_statuses += 1


func _load_all_statuses():
	var ids := ["bleed", "burn", "corrode", "chill", "slowed", "empowered"]
	for sid: String in ids:
		var path := "%s/%s.tres" % [STATUS_DIR, sid]
		var res = load(path)
		if res:
			_status_cache[sid] = res
			print("  ✓ Cached status: %s" % sid)
		else:
			push_error("  ❌ Failed to load status: %s" % path)
			_errors += 1


# ============================================================================
# PHASE 2: HEALTH AFFIXES
# ============================================================================

func _create_all_health_affixes():
	_roll_curve = load(CURVE_PATH)
	if not _roll_curve:
		push_error("  ❌ Missing roll curve: %s" % CURVE_PATH)
		_errors += 1
		return

	# [template_key, affix_name, effect_min, effect_max]
	var specs := [
		["str_brute",       "Enemy Health (STR Brute)",       8.0,  300.0],
		["agi_brute",       "Enemy Health (AGI Brute)",       5.0,  200.0],
		["agi_skirmisher",  "Enemy Health (AGI Skirmisher)",  4.0,  180.0],
		["int_skirmisher",  "Enemy Health (INT Skirmisher)",  4.0,  180.0],
		["int_caster",      "Enemy Health (INT Caster)",      3.0,  160.0],
		["str_tank",        "Enemy Health (STR Tank)",        12.0, 400.0],
		["int_tank",        "Enemy Health (INT Tank)",        10.0, 350.0],
		["str_support",     "Enemy Health (STR Support)",     3.0,  150.0],
		["int_support",     "Enemy Health (INT Support)",     3.0,  150.0],
		["agi_support",     "Enemy Health (AGI Support)",     3.0,  140.0],
	]

	for spec: Array in specs:
		var key: String = spec[0]
		var aname: String = spec[1]
		var emin: float = spec[2]
		var emax: float = spec[3]
		_create_health_affix(key, aname, emin, emax)


func _create_health_affix(key: String, aname: String, emin: float, emax: float):
	var affix = Affix.new()
	affix.affix_name = aname
	affix.description = "+{value} Health"
	affix.category = Affix.Category.HEALTH_BONUS
	affix.effect_min = emin
	affix.effect_max = emax
	affix.effect_curve = _roll_curve
	affix.show_in_summary = true
	affix.show_in_active_list = true

	var tag_list: Array[String] = ["defense", "inherent", "health", "enemy"]
	affix.tags.assign(tag_list)

	var path := "%s/enemy_health_%s.tres" % [HEALTH_DIR, key]
	if _save_resource(affix, path):
		_affixes += 1


func _load_all_health_affixes():
	var keys := [
		"str_brute", "agi_brute", "agi_skirmisher", "int_skirmisher",
		"int_caster", "str_tank", "int_tank", "str_support", "int_support",
		"agi_support",
	]
	for key: String in keys:
		var path := "%s/enemy_health_%s.tres" % [HEALTH_DIR, key]
		var res = load(path)
		if res:
			_health_cache[key] = res
			print("  ✓ Cached health affix: %s" % key)
		else:
			push_error("  ❌ Failed to load health affix: %s" % path)
			_errors += 1


# ============================================================================
# PHASE 3: BASE ACTIONS
# ============================================================================

func _create_all_actions():
	# ── STR Brute ──
	_create_action("smash", "Smash", "Deals 1D+2 Blunt damage.",
		0, 2, 1.2,  # action_type=ATK, base_dmg, multiplier
		[_make_damage_effect("Smash Damage", TT.SINGLE_ENEMY, DT.BLUNT, 2, 1.2)])

	_create_action("brace", "Brace", "Gain temp armor equal to half die value.",
		1, 0, 1.0,  # action_type=DEF
		[_make_armor_buff_effect("Brace Armor", true, 0, 1)])

	_create_action("crushing_blow", "Crushing Blow", "Heavy Blunt hit. Applies Corrode.",
		0, 4, 1.5,
		[_make_damage_effect("Crush Damage", TT.SINGLE_ENEMY, DT.BLUNT, 4, 1.5),
		 _make_status_effect("Crush Corrode", TT.SINGLE_ENEMY, "corrode", 1)])

	# ── AGI Brute ──
	_create_action("precision_strike", "Precision Strike", "Deals 1D+3 Piercing damage.",
		0, 3, 1.3,
		[_make_damage_effect("Precision Damage", TT.SINGLE_ENEMY, DT.PIERCING, 3, 1.3)])

	_create_action("sidestep", "Sidestep", "Reduce incoming damage by 2 for 1 turn.",
		1, 0, 1.0,
		[_make_damage_reduction_effect("Sidestep DR", 2.0, false, 1)])

	_create_action("crippling_thrust", "Crippling Thrust", "Piercing hit. Applies 2 Bleed.",
		0, 3, 1.3,
		[_make_damage_effect("Cripple Damage", TT.SINGLE_ENEMY, DT.PIERCING, 3, 1.3),
		 _make_status_effect("Cripple Bleed", TT.SINGLE_ENEMY, "bleed", 2)])

	# ── AGI Skirmisher ──
	_create_action("stab", "Stab", "Deals 1D Piercing damage.",
		0, 0, 1.0,
		[_make_damage_effect("Stab Damage", TT.SINGLE_ENEMY, DT.PIERCING, 0, 1.0)])

	_create_action("quick_slash", "Quick Slash", "Deals 1D+1 Slashing damage at 0.8×.",
		0, 1, 0.8,
		[_make_damage_effect("Slash Damage", TT.SINGLE_ENEMY, DT.SLASHING, 1, 0.8)])

	_create_action("fan_of_blades", "Fan of Blades", "2 random strikes. Applies 1 Bleed.",
		0, 0, 1.0,
		[_make_random_strikes_effect("Fan Strikes", TT.SINGLE_ENEMY, DT.PIERCING, 2),
		 _make_status_effect("Fan Bleed", TT.SINGLE_ENEMY, "bleed", 1)])

	# ── INT Skirmisher ──
	_create_action("spark", "Spark", "Deals 1D Shock damage.",
		0, 0, 1.0,
		[_make_damage_effect("Spark Damage", TT.SINGLE_ENEMY, DT.SHOCK, 0, 1.0)])

	_create_action("frost_shard", "Frost Shard", "Deals 1D+1 Ice damage at 0.8×.",
		0, 1, 0.8,
		[_make_damage_effect("Shard Damage", TT.SINGLE_ENEMY, DT.ICE, 1, 0.8)])

	_create_action("chain_spark", "Chain Spark", "Chain Shock to 2 targets. Applies 1 Chill.",
		0, 0, 1.0,
		[_make_chain_effect("Chain Damage", TT.ALL_ENEMIES, DT.SHOCK, 2),
		 _make_status_effect("Chain Chill", TT.SINGLE_ENEMY, "chill", 1)])

	# ── INT Caster ──
	_create_action("magic_bolt", "Magic Bolt", "Deals 1D+2 Fire damage at 1.1×.",
		0, 2, 1.1,
		[_make_damage_effect("Bolt Damage", TT.SINGLE_ENEMY, DT.FIRE, 2, 1.1)])

	_create_action("ward", "Ward", "Gain barrier equal to die × 0.8.",
		1, 0, 1.0,
		[_make_shield_effect("Ward Shield", true, 0, 0.8)])

	_create_action("ignite", "Ignite", "Fire hit. Applies 2 Burn.",
		0, 1, 1.0,
		[_make_damage_effect("Ignite Damage", TT.SINGLE_ENEMY, DT.FIRE, 1, 1.0),
		 _make_status_effect("Ignite Burn", TT.SINGLE_ENEMY, "burn", 2)])

	# ── STR Tank ──
	_create_action("slam", "Slam", "Deals 1D+1 Blunt damage at 0.7×.",
		0, 1, 0.7,
		[_make_damage_effect("Slam Damage", TT.SINGLE_ENEMY, DT.BLUNT, 1, 0.7)])

	_create_action("shield_wall", "Shield Wall", "Gain armor equal to die value.",
		1, 0, 1.0,
		[_make_armor_buff_effect("Wall Armor", true, 0, 1)])

	_create_action("fortify", "Fortify", "Armor × 1.2 + reduce damage by 2.",
		1, 0, 1.0,
		[_make_armor_buff_effect("Fortify Armor", true, 0, 2),
		 _make_damage_reduction_effect("Fortify DR", 2.0, false, 1)])

	# ── INT Tank ──
	_create_action("arcane_push", "Arcane Push", "Deals 1D+1 Shadow damage at 0.7×.",
		0, 1, 0.7,
		[_make_damage_effect("Push Damage", TT.SINGLE_ENEMY, DT.SHADOW, 1, 0.7)])

	_create_action("barrier_pulse", "Barrier Pulse", "Gain barrier equal to die value.",
		1, 0, 1.0,
		[_make_shield_effect("Pulse Shield", true, 0, 1.0)])

	_create_action("absorb", "Absorb", "Barrier × 1.2 + heal for die × 0.3.",
		1, 0, 1.0,
		[_make_shield_effect("Absorb Shield", true, 0, 1.2),
		 _make_heal_effect("Absorb Heal", TT.SELF, true, 0, 0.3)])

	# ── STR Support ──
	_create_action("shove", "Shove", "Weak Blunt hit at 0.5×.",
		0, 0, 0.5,
		[_make_damage_effect("Shove Damage", TT.SINGLE_ENEMY, DT.BLUNT, 0, 0.5)])

	_create_action("war_cry", "War Cry", "Empower an ally — increased damage.",
		3, 0, 1.0,  # action_type=SPECIAL
		[_make_status_effect("Empower Ally", TT.SINGLE_ALLY, "empowered", 1)])

	_create_action("rally", "Rally", "Empower all allies + minor armor.",
		3, 0, 1.0,
		[_make_status_effect("Rally Empower", TT.ALL_ALLIES, "empowered", 1),
		 _make_armor_buff_effect("Rally Armor", false, 2, 1)])

	# ── INT Support ──
	_create_action("mend", "Mend", "Heal an ally for die value.",
		2, 0, 1.0,  # action_type=HEAL
		[_make_heal_effect("Mend Heal", TT.SINGLE_ALLY, true, 0, 1.0)])

	_create_action("hex", "Hex", "Apply 1 Slowed to player.",
		3, 0, 1.0,
		[_make_status_effect("Hex Slow", TT.SINGLE_ENEMY, "slowed", 1)])

	_create_action("mass_mend", "Mass Mend", "Heal all allies for die × 0.6 + cleanse.",
		2, 0, 1.0,
		[_make_heal_effect("Mass Heal", TT.ALL_ALLIES, true, 0, 0.6),
		 _make_cleanse_effect("Mass Cleanse", TT.ALL_ALLIES)])

	# ── AGI Support ──
	_create_action("poke", "Poke", "Weak Piercing hit at 0.5×.",
		0, 0, 0.5,
		[_make_damage_effect("Poke Damage", TT.SINGLE_ENEMY, DT.PIERCING, 0, 0.5)])

	_create_action("hamstring", "Hamstring", "Apply 2 Slowed to player.",
		3, 0, 1.0,
		[_make_status_effect("Hamstring Slow", TT.SINGLE_ENEMY, "slowed", 2)])

	_create_action("sabotage", "Sabotage", "Apply 2 Slowed + 2 Corrode.",
		3, 0, 1.0,
		[_make_status_effect("Sabo Slow", TT.SINGLE_ENEMY, "slowed", 2),
		 _make_status_effect("Sabo Corrode", TT.SINGLE_ENEMY, "corrode", 2)])


# ── Action creation helper ──

func _create_action(file_name: String, aname: String, desc: String,
		action_type: int, base_dmg: int, dmg_mult: float,
		effects_array: Array):
	var act = _action_script.new()
	act.action_id = file_name
	act.action_name = aname
	act.action_description = desc
	act.die_slots = 1
	act.charge_type = CT.UNLIMITED

	# Legacy fields (still used by ActionField.configure_from_dict)
	act.action_type = action_type
	act.base_damage = base_dmg
	act.damage_multiplier = dmg_mult

	# CRITICAL: .assign() for typed Array[ActionEffect]
	act.effects.assign(effects_array)

	var path := "%s/%s.tres" % [ACTION_DIR, file_name]
	if _save_resource(act, path):
		_actions += 1


# ── ActionEffect factory helpers ──

func _make_damage_effect(ename: String, target: int, dmg_type: int,
		base_dmg: int, mult: float) -> ActionEffect:
	var e = _effect_script.new()
	e.effect_name = ename
	e.target = target
	e.effect_type = ET.DAMAGE
	e.damage_type = dmg_type
	e.base_damage = base_dmg
	e.damage_multiplier = mult
	e.value_source = VS.DICE_TOTAL
	return e


func _make_status_effect(ename: String, target: int,
		status_id: String, stacks: int) -> ActionEffect:
	var e = _effect_script.new()
	e.effect_name = ename
	e.target = target
	e.effect_type = ET.ADD_STATUS
	e.stack_count = stacks
	if _status_cache.has(status_id):
		e.status_affix = _status_cache[status_id]
	else:
		push_error("  ⚠️ Status '%s' not cached — effect will have null status_affix" % status_id)
		_errors += 1
	return e


func _make_armor_buff_effect(ename: String, uses_dice: bool,
		flat_amount: int, duration: int) -> ActionEffect:
	var e = _effect_script.new()
	e.effect_name = ename
	e.target = TT.SELF
	e.effect_type = ET.ARMOR_BUFF
	e.armor_buff_uses_dice = uses_dice
	e.armor_buff_amount = flat_amount
	e.armor_buff_duration = duration
	if uses_dice:
		e.value_source = VS.DICE_TOTAL
	return e


func _make_shield_effect(ename: String, uses_dice: bool,
		flat_amount: int, mult: float) -> ActionEffect:
	var e = _effect_script.new()
	e.effect_name = ename
	e.target = TT.SELF
	e.effect_type = ET.SHIELD
	e.shield_uses_dice = uses_dice
	e.shield_amount = flat_amount
	e.shield_multiplier = mult
	if uses_dice:
		e.value_source = VS.DICE_TOTAL
	return e


func _make_damage_reduction_effect(ename: String, amount: float,
		is_percent: bool, duration: int) -> ActionEffect:
	var e = _effect_script.new()
	e.effect_name = ename
	e.target = TT.SELF
	e.effect_type = ET.DAMAGE_REDUCTION
	e.reduction_amount = amount
	e.reduction_is_percent = is_percent
	e.reduction_duration = duration
	e.value_source = VS.STATIC
	return e


func _make_heal_effect(ename: String, target: int,
		uses_dice: bool, base_heal: int, mult: float) -> ActionEffect:
	var e = _effect_script.new()
	e.effect_name = ename
	e.target = target
	e.effect_type = ET.HEAL
	e.heal_uses_dice = uses_dice
	e.base_heal = base_heal
	e.heal_multiplier = mult
	if uses_dice:
		e.value_source = VS.DICE_TOTAL
	return e


func _make_random_strikes_effect(ename: String, target: int,
		dmg_type: int, count: int) -> ActionEffect:
	var e = _effect_script.new()
	e.effect_name = ename
	e.target = target
	e.effect_type = ET.RANDOM_STRIKES
	e.damage_type = dmg_type
	e.strike_count = count
	e.value_source = VS.DICE_TOTAL
	return e


func _make_chain_effect(ename: String, target: int,
		dmg_type: int, count: int) -> ActionEffect:
	var e = _effect_script.new()
	e.effect_name = ename
	e.target = target
	e.effect_type = ET.CHAIN
	e.damage_type = dmg_type
	e.chain_count = count
	e.chain_decay = 0.7
	e.value_source = VS.DICE_TOTAL
	return e


func _make_cleanse_effect(ename: String, target: int) -> ActionEffect:
	var e = _effect_script.new()
	e.effect_name = ename
	e.target = target
	e.effect_type = ET.CLEANSE
	# .assign() for typed Array[String]
	var tags: Array[String] = ["debuff"]
	e.cleanse_tags.assign(tags)
	return e


func _load_all_actions():
	"""Load all 30 actions from disk into _action_cache for template wiring."""
	var action_files := [
		"smash", "brace", "crushing_blow",
		"precision_strike", "sidestep", "crippling_thrust",
		"stab", "quick_slash", "fan_of_blades",
		"spark", "frost_shard", "chain_spark",
		"magic_bolt", "ward", "ignite",
		"slam", "shield_wall", "fortify",
		"arcane_push", "barrier_pulse", "absorb",
		"shove", "war_cry", "rally",
		"mend", "hex", "mass_mend",
		"poke", "hamstring", "sabotage",
	]
	for fname: String in action_files:
		var path := "%s/%s.tres" % [ACTION_DIR, fname]
		var res = load(path)
		if res:
			_action_cache[fname] = res
		else:
			push_error("  ❌ Failed to load action: %s" % path)
			_errors += 1
	print("  ✓ Cached %d actions" % _action_cache.size())


# ============================================================================
# PHASE 4: TEMPLATES
# ============================================================================

func _create_all_templates():
	_create_str_brute()
	_create_agi_brute()
	_create_agi_skirmisher()
	_create_int_skirmisher()
	_create_int_caster()
	_create_str_tank()
	_create_int_tank()
	_create_str_support()
	_create_int_support()
	_create_agi_support()


# ── Budget factory ──

func _make_budget(p: Dictionary) -> RoleTierBudget:
	"""Create a RoleTierBudget from a config dictionary.
	Keys: dice_min, dice_max, floor, ceiling, actions, multi_die, special,
	      health, defense, level, ai_override (optional), delay, drag"""
	var b = _budget_script.new()
	b.dice_count_min = p.get("dice_min", 1)
	b.dice_count_max = p.get("dice_max", 2)
	b.die_size_floor = p.get("floor", DIE.D4)
	b.die_size_ceiling = p.get("ceiling", DIE.D6)
	b.action_count = p.get("actions", 2)
	b.multi_die_action_budget = p.get("multi_die", 0)
	b.special_mechanic_budget = p.get("special", 0)
	b.health_scale = p.get("health", 1.0)
	b.defense_scale = p.get("defense", 1.0)
	b.level_scaling = p.get("level", 0.85)
	b.action_delay = p.get("delay", 0.8)
	b.dice_drag_duration = p.get("drag", 0.4)

	if p.has("ai_override"):
		b.override_ai_strategy = true
		b.ai_strategy_override = p.ai_override

	return b


# ── Template factory ──

func _save_template(t: Resource, file_name: String):
	var path := "%s/%s.tres" % [TEMPLATE_DIR, file_name]
	if _save_resource(t, path):
		_templates += 1


func _wire_actions(template: Resource, action_keys: Array):
	"""Wire cached actions into template.default_actions using .assign()."""
	var actions: Array[Action] = []
	for key: String in action_keys:
		if _action_cache.has(key):
			actions.append(_action_cache[key])
		else:
			push_error("  ⚠️ Action '%s' not cached — skipping" % key)
			_errors += 1
	template.default_actions.assign(actions)


# ── Individual template builders ──

func _create_str_brute():
	var t = _template_script.new()
	t.template_name = "STR Brute"
	t.template_description = "High single-target physical damage. Armor-heavy. Aggressive."
	t.role = CR.BRUTE
	t.archetype = ARCH.STR
	t.dice_philosophy = PH.FEW_LARGE
	t.defense_profile = DP.ARMOR_HEAVY
	t.default_ai_strategy = AI.AGGRESSIVE
	t.default_target_priority = TP.RANDOM
	t.health_weight = 1.2
	t.armor_weight = 1.3
	t.barrier_weight = 0.0
	t.damage_weight = 1.3

	var tags: PackedStringArray = ["melee", "heavy_hit", "armor_self"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("str_brute")
	_wire_actions(t, ["smash", "brace", "crushing_blow"])

	t.trash_budget = _make_budget({
		"dice_min": 1, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 2, "multi_die": 0, "special": 0,
		"health": 1.2, "defense": 1.0, "level": 0.85,
		"ai_override": AI.AGGRESSIVE, "delay": 0.7, "drag": 0.35,
	})
	t.elite_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D6, "ceiling": DIE.D10,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 1.3, "defense": 1.2, "level": 0.95,
		"delay": 0.8, "drag": 0.4,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 1.5, "defense": 1.3, "level": 1.0,
		"delay": 0.9, "drag": 0.45,
	})
	t.boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 4, "floor": DIE.D8, "ceiling": DIE.D12,
		"actions": 4, "multi_die": 1, "special": 2,
		"health": 2.0, "defense": 1.5, "level": 1.1,
		"ai_override": AI.BALANCED, "delay": 1.0, "drag": 0.5,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 4, "dice_max": 5, "floor": DIE.D10, "ceiling": DIE.D12,
		"actions": 6, "multi_die": 1, "special": 3,
		"health": 3.0, "defense": 2.0, "level": 1.2,
		"ai_override": AI.BALANCED, "delay": 1.1, "drag": 0.5,
	})

	_save_template(t, "brute_str")


func _create_agi_brute():
	var t = _template_script.new()
	t.template_name = "AGI Brute"
	t.template_description = "Precision glass cannon. High spike damage, paper-thin defense."
	t.role = CR.BRUTE
	t.archetype = ARCH.AGI
	t.dice_philosophy = PH.FEW_LARGE
	t.defense_profile = DP.MINIMAL
	t.default_ai_strategy = AI.AGGRESSIVE
	t.default_target_priority = TP.RANDOM
	t.health_weight = 0.9
	t.armor_weight = 0.3
	t.barrier_weight = 0.0
	t.damage_weight = 1.5

	var tags: PackedStringArray = ["melee", "precision", "crit"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("agi_brute")
	_wire_actions(t, ["precision_strike", "sidestep", "crippling_thrust"])

	t.trash_budget = _make_budget({
		"dice_min": 1, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 2, "multi_die": 0, "special": 0,
		"health": 0.9, "defense": 0.5, "level": 0.85,
		"ai_override": AI.AGGRESSIVE, "delay": 0.6, "drag": 0.3,
	})
	t.elite_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D6, "ceiling": DIE.D10,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 1.0, "defense": 0.6, "level": 0.95,
		"delay": 0.7, "drag": 0.35,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 1.1, "defense": 0.8, "level": 1.0,
		"delay": 0.8, "drag": 0.4,
	})
	t.boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 4, "floor": DIE.D8, "ceiling": DIE.D12,
		"actions": 4, "multi_die": 1, "special": 2,
		"health": 1.3, "defense": 1.0, "level": 1.1,
		"ai_override": AI.BALANCED, "delay": 0.9, "drag": 0.45,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 4, "dice_max": 5, "floor": DIE.D10, "ceiling": DIE.D12,
		"actions": 6, "multi_die": 1, "special": 3,
		"health": 1.6, "defense": 1.2, "level": 1.2,
		"ai_override": AI.BALANCED, "delay": 1.0, "drag": 0.5,
	})

	_save_template(t, "brute_agi")


func _create_agi_skirmisher():
	var t = _template_script.new()
	t.template_name = "AGI Skirmisher"
	t.template_description = "Many small physical hits. Fragile but annoying action economy."
	t.role = CR.SKIRMISHER
	t.archetype = ARCH.AGI
	t.dice_philosophy = PH.MANY_SMALL
	t.defense_profile = DP.MINIMAL
	t.default_ai_strategy = AI.BALANCED
	t.default_target_priority = TP.RANDOM
	t.health_weight = 0.8
	t.armor_weight = 0.2
	t.barrier_weight = 0.0
	t.damage_weight = 1.0

	var tags: PackedStringArray = ["melee", "multi_hit", "fast"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("agi_skirmisher")
	_wire_actions(t, ["stab", "quick_slash", "fan_of_blades"])

	t.trash_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 2, "multi_die": 0, "special": 0,
		"health": 0.8, "defense": 0.4, "level": 0.85,
		"delay": 0.5, "drag": 0.25,
	})
	t.elite_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 0.9, "defense": 0.5, "level": 0.95,
		"delay": 0.5, "drag": 0.3,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 4, "floor": DIE.D4, "ceiling": DIE.D8,
		"actions": 4, "multi_die": 0, "special": 1,
		"health": 1.0, "defense": 0.7, "level": 1.0,
		"delay": 0.6, "drag": 0.3,
	})
	t.boss_budget = _make_budget({
		"dice_min": 4, "dice_max": 4, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 5, "multi_die": 1, "special": 2,
		"health": 1.2, "defense": 1.0, "level": 1.1,
		"ai_override": AI.BALANCED, "delay": 0.7, "drag": 0.35,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 4, "dice_max": 5, "floor": DIE.D6, "ceiling": DIE.D10,
		"actions": 6, "multi_die": 1, "special": 3,
		"health": 1.5, "defense": 1.2, "level": 1.2,
		"delay": 0.7, "drag": 0.35,
	})

	_save_template(t, "skirmisher_agi")


func _create_int_skirmisher():
	var t = _template_script.new()
	t.template_name = "INT Skirmisher"
	t.template_description = "Many small elemental hits. Barrier defense, dual elements."
	t.role = CR.SKIRMISHER
	t.archetype = ARCH.INT
	t.dice_philosophy = PH.MANY_SMALL
	t.defense_profile = DP.BARRIER_HEAVY
	t.default_ai_strategy = AI.BALANCED
	t.default_target_priority = TP.RANDOM
	t.health_weight = 0.8
	t.armor_weight = 0.0
	t.barrier_weight = 0.8
	t.damage_weight = 1.0

	var tags: PackedStringArray = ["elemental", "multi_hit", "ranged"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("int_skirmisher")
	_wire_actions(t, ["spark", "frost_shard", "chain_spark"])

	t.trash_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 2, "multi_die": 0, "special": 0,
		"health": 0.8, "defense": 0.5, "level": 0.85,
		"delay": 0.5, "drag": 0.25,
	})
	t.elite_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D4, "ceiling": DIE.D8,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 0.9, "defense": 0.6, "level": 0.95,
		"delay": 0.6, "drag": 0.3,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 4, "floor": DIE.D4, "ceiling": DIE.D8,
		"actions": 4, "multi_die": 0, "special": 2,
		"health": 1.0, "defense": 0.8, "level": 1.0,
		"delay": 0.6, "drag": 0.3,
	})
	t.boss_budget = _make_budget({
		"dice_min": 4, "dice_max": 4, "floor": DIE.D6, "ceiling": DIE.D10,
		"actions": 5, "multi_die": 1, "special": 3,
		"health": 1.2, "defense": 1.0, "level": 1.1,
		"delay": 0.7, "drag": 0.35,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 4, "dice_max": 5, "floor": DIE.D6, "ceiling": DIE.D10,
		"actions": 6, "multi_die": 1, "special": 4,
		"health": 1.5, "defense": 1.3, "level": 1.2,
		"delay": 0.7, "drag": 0.35,
	})

	_save_template(t, "skirmisher_int")


func _create_int_caster():
	var t = _template_script.new()
	t.template_name = "INT Caster"
	t.template_description = "Glass cannon with status tricks. Barrier defense. Kill it first."
	t.role = CR.CASTER
	t.archetype = ARCH.INT
	t.dice_philosophy = PH.BALANCED
	t.defense_profile = DP.BARRIER_HEAVY
	t.default_ai_strategy = AI.BALANCED
	t.default_target_priority = TP.RANDOM
	t.health_weight = 0.7
	t.armor_weight = 0.0
	t.barrier_weight = 1.2
	t.damage_weight = 1.2

	var tags: PackedStringArray = ["elemental", "status_apply", "ranged", "barrier_self"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("int_caster")
	_wire_actions(t, ["magic_bolt", "ward", "ignite"])

	t.trash_budget = _make_budget({
		"dice_min": 1, "dice_max": 2, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 2, "multi_die": 0, "special": 0,
		"health": 0.7, "defense": 0.6, "level": 0.85,
		"ai_override": AI.RANDOM, "delay": 0.8, "drag": 0.4,
	})
	t.elite_budget = _make_budget({
		"dice_min": 2, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 0.8, "defense": 0.8, "level": 0.95,
		"delay": 0.8, "drag": 0.4,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 4, "multi_die": 0, "special": 2,
		"health": 0.9, "defense": 1.0, "level": 1.0,
		"delay": 0.9, "drag": 0.45,
	})
	t.boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 5, "multi_die": 1, "special": 3,
		"health": 1.0, "defense": 1.3, "level": 1.1,
		"ai_override": AI.DEFENSIVE, "delay": 1.0, "drag": 0.5,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 4, "floor": DIE.D8, "ceiling": DIE.D12,
		"actions": 6, "multi_die": 1, "special": 4,
		"health": 1.3, "defense": 1.5, "level": 1.2,
		"ai_override": AI.DEFENSIVE, "delay": 1.1, "drag": 0.5,
	})

	_save_template(t, "caster_int")


func _create_str_tank():
	var t = _template_script.new()
	t.template_name = "STR Tank"
	t.template_description = "Armor wall. High HP, slow grind, defensive AI."
	t.role = CR.TANK
	t.archetype = ARCH.STR
	t.dice_philosophy = PH.BALANCED
	t.defense_profile = DP.HYBRID
	t.default_ai_strategy = AI.DEFENSIVE
	t.default_target_priority = TP.RANDOM
	t.health_weight = 1.5
	t.armor_weight = 1.5
	t.barrier_weight = 0.3
	t.damage_weight = 0.6

	var tags: PackedStringArray = ["melee", "armor_self", "taunt"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("str_tank")
	_wire_actions(t, ["slam", "shield_wall", "fortify"])

	t.trash_budget = _make_budget({
		"dice_min": 1, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D6,
		"actions": 2, "multi_die": 0, "special": 0,
		"health": 1.5, "defense": 1.3, "level": 0.85,
		"ai_override": AI.DEFENSIVE, "delay": 1.0, "drag": 0.5,
	})
	t.elite_budget = _make_budget({
		"dice_min": 2, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 1.8, "defense": 1.5, "level": 0.95,
		"delay": 1.0, "drag": 0.5,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 2.0, "defense": 1.8, "level": 1.0,
		"delay": 1.1, "drag": 0.5,
	})
	t.boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 4, "multi_die": 1, "special": 2,
		"health": 2.5, "defense": 2.0, "level": 1.1,
		"delay": 1.2, "drag": 0.55,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 4, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 5, "multi_die": 1, "special": 3,
		"health": 3.0, "defense": 2.5, "level": 1.2,
		"delay": 1.2, "drag": 0.55,
	})

	_save_template(t, "tank_str")


func _create_int_tank():
	var t = _template_script.new()
	t.template_name = "INT Tank"
	t.template_description = "Barrier wall. Countered by physical, sustained by regen."
	t.role = CR.TANK
	t.archetype = ARCH.INT
	t.dice_philosophy = PH.BALANCED
	t.defense_profile = DP.BARRIER_HEAVY
	t.default_ai_strategy = AI.DEFENSIVE
	t.default_target_priority = TP.RANDOM
	t.health_weight = 1.4
	t.armor_weight = 0.2
	t.barrier_weight = 1.5
	t.damage_weight = 0.5

	var tags: PackedStringArray = ["elemental", "barrier_self", "heal_self"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("int_tank")
	_wire_actions(t, ["arcane_push", "barrier_pulse", "absorb"])

	t.trash_budget = _make_budget({
		"dice_min": 1, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D6,
		"actions": 2, "multi_die": 0, "special": 0,
		"health": 1.4, "defense": 1.2, "level": 0.85,
		"ai_override": AI.DEFENSIVE, "delay": 1.0, "drag": 0.5,
	})
	t.elite_budget = _make_budget({
		"dice_min": 2, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 1.6, "defense": 1.4, "level": 0.95,
		"delay": 1.0, "drag": 0.5,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 3, "multi_die": 0, "special": 1,
		"health": 1.8, "defense": 1.6, "level": 1.0,
		"delay": 1.1, "drag": 0.5,
	})
	t.boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 4, "multi_die": 1, "special": 2,
		"health": 2.2, "defense": 2.0, "level": 1.1,
		"delay": 1.2, "drag": 0.55,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 4, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 5, "multi_die": 1, "special": 3,
		"health": 2.8, "defense": 2.5, "level": 1.2,
		"delay": 1.2, "drag": 0.55,
	})

	_save_template(t, "tank_int")


func _create_str_support():
	var t = _template_script.new()
	t.template_name = "STR Support"
	t.template_description = "War drummer. Buffs ally damage. Kill priority target."
	t.role = CR.SUPPORT
	t.archetype = ARCH.STR
	t.dice_philosophy = PH.BALANCED
	t.defense_profile = DP.MINIMAL
	t.default_ai_strategy = AI.DEFENSIVE
	t.default_target_priority = TP.RANDOM
	t.health_weight = 0.6
	t.armor_weight = 0.3
	t.barrier_weight = 0.0
	t.damage_weight = 0.3

	var tags: PackedStringArray = ["buff_ally", "empower", "melee"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("str_support")
	_wire_actions(t, ["shove", "war_cry", "rally"])

	t.trash_budget = _make_budget({
		"dice_min": 1, "dice_max": 1, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 2, "multi_die": 0, "special": 1,
		"health": 0.6, "defense": 0.3, "level": 0.80,
		"ai_override": AI.DEFENSIVE, "delay": 0.8, "drag": 0.4,
	})
	t.elite_budget = _make_budget({
		"dice_min": 1, "dice_max": 2, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 3, "multi_die": 0, "special": 2,
		"health": 0.7, "defense": 0.4, "level": 0.90,
		"delay": 0.8, "drag": 0.4,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 2, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 4, "multi_die": 0, "special": 2,
		"health": 0.8, "defense": 0.6, "level": 0.95,
		"delay": 0.9, "drag": 0.45,
	})
	t.boss_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 5, "multi_die": 0, "special": 3,
		"health": 1.0, "defense": 0.8, "level": 1.05,
		"delay": 1.0, "drag": 0.5,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 6, "multi_die": 0, "special": 4,
		"health": 1.2, "defense": 1.0, "level": 1.15,
		"delay": 1.0, "drag": 0.5,
	})

	_save_template(t, "support_str")


func _create_int_support():
	var t = _template_script.new()
	t.template_name = "INT Support"
	t.template_description = "Healer and debuffer. Undoes player damage, applies slowed."
	t.role = CR.SUPPORT
	t.archetype = ARCH.INT
	t.dice_philosophy = PH.BALANCED
	t.defense_profile = DP.MINIMAL
	t.default_ai_strategy = AI.DEFENSIVE
	t.default_target_priority = TP.RANDOM
	t.health_weight = 0.6
	t.armor_weight = 0.0
	t.barrier_weight = 0.3
	t.damage_weight = 0.2

	var tags: PackedStringArray = ["heal_ally", "debuff_enemy", "ranged"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("int_support")
	_wire_actions(t, ["mend", "hex", "mass_mend"])

	t.trash_budget = _make_budget({
		"dice_min": 1, "dice_max": 1, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 2, "multi_die": 0, "special": 1,
		"health": 0.6, "defense": 0.3, "level": 0.80,
		"ai_override": AI.DEFENSIVE, "delay": 0.8, "drag": 0.4,
	})
	t.elite_budget = _make_budget({
		"dice_min": 1, "dice_max": 2, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 3, "multi_die": 0, "special": 2,
		"health": 0.7, "defense": 0.4, "level": 0.90,
		"delay": 0.8, "drag": 0.4,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 2, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 4, "multi_die": 0, "special": 3,
		"health": 0.8, "defense": 0.6, "level": 0.95,
		"delay": 0.9, "drag": 0.45,
	})
	t.boss_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 5, "multi_die": 0, "special": 4,
		"health": 1.0, "defense": 0.8, "level": 1.05,
		"delay": 1.0, "drag": 0.5,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 6, "multi_die": 0, "special": 5,
		"health": 1.2, "defense": 1.0, "level": 1.15,
		"delay": 1.0, "drag": 0.5,
	})

	_save_template(t, "support_int")


func _create_agi_support():
	var t = _template_script.new()
	t.template_name = "AGI Support"
	t.template_description = "Trickster. Debuffs player dice and armor. Makes everything hurt more."
	t.role = CR.SUPPORT
	t.archetype = ARCH.AGI
	t.dice_philosophy = PH.BALANCED
	t.defense_profile = DP.MINIMAL
	t.default_ai_strategy = AI.BALANCED
	t.default_target_priority = TP.RANDOM
	t.health_weight = 0.6
	t.armor_weight = 0.2
	t.barrier_weight = 0.0
	t.damage_weight = 0.2

	var tags: PackedStringArray = ["debuff_enemy", "slow", "corrode", "trickster"]
	t.action_tags = tags

	t.default_health_affix = _health_cache.get("agi_support")
	_wire_actions(t, ["poke", "hamstring", "sabotage"])

	t.trash_budget = _make_budget({
		"dice_min": 1, "dice_max": 1, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 2, "multi_die": 0, "special": 1,
		"health": 0.6, "defense": 0.3, "level": 0.80,
		"delay": 0.6, "drag": 0.3,
	})
	t.elite_budget = _make_budget({
		"dice_min": 1, "dice_max": 2, "floor": DIE.D4, "ceiling": DIE.D6,
		"actions": 3, "multi_die": 0, "special": 2,
		"health": 0.7, "defense": 0.4, "level": 0.90,
		"delay": 0.6, "drag": 0.3,
	})
	t.mini_boss_budget = _make_budget({
		"dice_min": 2, "dice_max": 2, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 4, "multi_die": 0, "special": 3,
		"health": 0.8, "defense": 0.5, "level": 0.95,
		"ai_override": AI.BALANCED, "delay": 0.7, "drag": 0.35,
	})
	t.boss_budget = _make_budget({
		"dice_min": 2, "dice_max": 3, "floor": DIE.D6, "ceiling": DIE.D8,
		"actions": 5, "multi_die": 0, "special": 4,
		"health": 1.0, "defense": 0.7, "level": 1.05,
		"delay": 0.8, "drag": 0.4,
	})
	t.world_boss_budget = _make_budget({
		"dice_min": 3, "dice_max": 3, "floor": DIE.D8, "ceiling": DIE.D10,
		"actions": 6, "multi_die": 0, "special": 5,
		"health": 1.2, "defense": 0.9, "level": 1.15,
		"delay": 0.8, "drag": 0.4,
	})

	_save_template(t, "support_agi")


# ============================================================================
# SAVE UTILITY
# ============================================================================

func _save_resource(resource: Resource, path: String) -> bool:
	var err := ResourceSaver.save(resource, path)
	if err == OK:
		print("  💾 %s" % path)
		return true
	else:
		push_error("  ❌ Save failed: %s — %s" % [path, error_string(err)])
		_errors += 1
		return false
