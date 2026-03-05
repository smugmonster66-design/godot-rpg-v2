@tool
extends EditorScript

# ============================================================================
# Region 1 Weapon Action Generator
#
# Creates ActionEffect and Action .tres files for all 17 Region 1 weapons.
#
# Output:
#   res://resources/actions/items/region_1/          <- Action files
#   res://resources/actions/items/region_1/effects/  <- ActionEffect files
#
# Run via: Godot editor > Script > Run (with this file open)
# ============================================================================

const ACTION_DIR  := "res://resources/actions/items/region_1/"
const EFFECT_DIR  := "res://resources/actions/items/region_1/effects/"

# Status resource paths (all confirmed .tres files in repo)
const S_BLEED   := "res://resources/statuses/bleed.tres"
const S_BURN    := "res://resources/statuses/burn.tres"
const S_CHILL   := "res://resources/statuses/chill.tres"
const S_STATIC  := "res://resources/statuses/static.tres"
const S_POISON  := "res://resources/statuses/poison.tres"
const S_SHADOW  := "res://resources/statuses/shadow.tres"
const S_CORRODE := "res://resources/statuses/corrode.tres"
const S_EXPOSE  := "res://resources/statuses/expose.tres"
const S_STUNNED := "res://resources/statuses/stunned.tres"

# DieResource.Element int values kept here for reference if accepted_elements
# restrictions are ever needed on specific actions in future.
# NONE=0, SLASHING=1, BLUNT=2, PIERCING=3, FIRE=4, ICE=5, SHOCK=6, POISON=7, SHADOW=8

var _effects_count := 0
var _actions_count := 0


# ============================================================================
# ENTRY POINT
# ============================================================================

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ACTION_DIR)
	DirAccess.make_dir_recursive_absolute(EFFECT_DIR)

	print("== Region 1 Weapon Action Generator ==")

	_gen_naval_cutlass()
	_gen_officers_rapier()
	_gen_iron_mace()
	_gen_sanctum_stiletto()
	_gen_cinder_wand()
	_gen_frost_wand()
	_gen_spark_wand()
	_gen_parrying_blade()
	_gen_naval_greatsword()
	_gen_iron_warhammer()
	_gen_marine_halberd()
	_gen_longbow()
	_gen_ember_staff()
	_gen_frost_staff()
	_gen_storm_staff()
	_gen_venom_staff()
	_gen_shadow_staff()

	print("== Done: %d effects, %d actions ==" % [_effects_count, _actions_count])


# ============================================================================
# SAVE HELPERS
# Save resource to disk, reload from disk, return the reloaded copy.
# Reload via CACHE_MODE_IGNORE ensures we get a fresh ExtResource reference,
# not a stale cached copy.
# ============================================================================

func _save_effect(effect: ActionEffect, filename: String) -> ActionEffect:
	var path: String = EFFECT_DIR + filename
	ResourceSaver.save(effect, path)
	_effects_count += 1
	print("  [effect] %s" % filename)
	var loaded: ActionEffect = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return loaded


func _save_action(action: Action, filename: String) -> void:
	var path: String = ACTION_DIR + filename
	ResourceSaver.save(action, path)
	_actions_count += 1
	print("  [action] %s" % filename)


# ============================================================================
# FACTORY HELPERS
# All typed array assignments use .assign() to prevent silent abort.
# Never use := on Variant sources (dict values, array indexes, duplicate()).
# ============================================================================

func _make_damage(fname: String, dtype: int, dcount: int) -> ActionEffect:
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = fname
	e.effect_type = ActionEffect.EffectType.DAMAGE
	e.target = ActionEffect.TargetType.SINGLE_ENEMY
	e.damage_type = dtype
	e.base_damage = 0
	e.dice_count = dcount
	return e


func _make_add_status(fname: String, status_path: String, stacks: int) -> ActionEffect:
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = fname
	e.effect_type = ActionEffect.EffectType.ADD_STATUS
	e.target = ActionEffect.TargetType.SINGLE_ENEMY
	var status: StatusAffix = ResourceLoader.load(status_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	e.status_affix = status
	e.stack_count = stacks
	return e


func _make_mana(fname: String, amount: int) -> ActionEffect:
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = fname
	e.effect_type = ActionEffect.EffectType.MANA_MANIPULATE
	e.target = ActionEffect.TargetType.SELF
	e.mana_amount = amount
	return e


func _make_action(
		id: String,
		name: String,
		desc: String,
		slots: int,
		loaded_effects: Array[ActionEffect],
		cooldown: int = 0) -> Action:
	var a: Action = Action.new()
	a.action_id = id
	a.action_name = name
	a.action_description = desc
	a.die_slots = slots
	a.min_dice_required = 1
	a.cooldown_turns = cooldown
	a.charge_type = Action.ChargeType.UNLIMITED
	# Empty = accept all elements. Restriction is an exception case, not the rule.
	a.accepted_elements.assign([])
	# effects is Array[ActionEffect] — must use .assign()
	a.effects.assign(loaded_effects)
	return a


# ============================================================================
# WEAPON GENERATORS
# Per-weapon execution order:
#   1. Create each ActionEffect, save to EFFECT_DIR, reload from disk
#   2. Build loaded_effects array (typed), .assign() all entries
#   3. Create Action referencing loaded effects, save to ACTION_DIR
# ============================================================================


# --- 37. Naval Cutlass: Cutlass Sweep ---
# SPLASH is self-contained: handles primary damage AND adjacent splash.
# No separate DAMAGE effect needed.
func _gen_naval_cutlass() -> void:
	print("- Naval Cutlass")
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = "Cutlass Sweep: Slash and Splash"
	e.effect_type = ActionEffect.EffectType.SPLASH
	e.target = ActionEffect.TargetType.SINGLE_ENEMY
	e.damage_type = ActionEffect.DamageType.SLASHING
	e.base_damage = 0
	e.dice_count = 1
	e.splash_percent = 0.5
	e.splash_all = false
	var splash: ActionEffect = _save_effect(e, "naval_cutlass_sweep_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([splash])
	var a: Action = _make_action(
		"weapon_naval_cutlass_sweep",
		"Cutlass Sweep",
		"A wide naval slash. Deals 50% splash damage to adjacent enemies.",
		1, efx)
	_save_action(a, "naval_cutlass_sweep_action.tres")


# --- 38. Officer's Rapier: Lunge ---
# DAMAGE + COMBO_MARK. Mark applies bleed stacks; consuming marks on
# follow-up hits grants bonus damage.
func _gen_officers_rapier() -> void:
	print("- Officers Rapier")
	var dmg: ActionEffect = _make_damage("Lunge: Damage", ActionEffect.DamageType.PIERCING, 1)
	var dmg_saved: ActionEffect = _save_effect(dmg, "officers_rapier_damage_effect.tres")

	var mark: ActionEffect = ActionEffect.new()
	mark.effect_name = "Lunge: Combo Mark"
	mark.effect_type = ActionEffect.EffectType.COMBO_MARK
	mark.target = ActionEffect.TargetType.SINGLE_ENEMY
	var bleed: StatusAffix = ResourceLoader.load(S_BLEED, "", ResourceLoader.CACHE_MODE_IGNORE)
	mark.mark_status = bleed
	mark.mark_stacks = 2
	mark.mark_consume_bonus = 8
	mark.mark_deals_damage = false
	var mark_saved: ActionEffect = _save_effect(mark, "officers_rapier_combo_mark_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, mark_saved])
	var a: Action = _make_action(
		"weapon_officers_rapier_lunge",
		"Lunge",
		"A precise thrust. Applies 2 Bleed marks. Follow-up hits consume marks for +8 bonus damage.",
		1, efx)
	_save_action(a, "officers_rapier_lunge_action.tres")


# --- 39. Iron Mace: Bludgeon ---
# DAMAGE + ADD_STATUS (stunned). 1 stack locks out one of the enemy's dice.
func _gen_iron_mace() -> void:
	print("- Iron Mace")
	var dmg: ActionEffect = _make_damage("Bludgeon: Damage", ActionEffect.DamageType.BLUNT, 1)
	var dmg_saved: ActionEffect = _save_effect(dmg, "iron_mace_damage_effect.tres")

	var stun: ActionEffect = _make_add_status("Bludgeon: Stunned", S_STUNNED, 1)
	var stun_saved: ActionEffect = _save_effect(stun, "iron_mace_stunned_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, stun_saved])
	var a: Action = _make_action(
		"weapon_iron_mace_bludgeon",
		"Bludgeon",
		"A heavy blow that deals damage and locks out one of the enemy's dice.",
		1, efx)
	_save_action(a, "iron_mace_bludgeon_action.tres")


# --- 40. Sanctum Stiletto: Puncture ---
# DAMAGE + ADD_STATUS (bleed x2). Bleed opener; pairs with Rapier's Lunge.
func _gen_sanctum_stiletto() -> void:
	print("- Sanctum Stiletto")
	var dmg: ActionEffect = _make_damage("Puncture: Damage", ActionEffect.DamageType.PIERCING, 1)
	var dmg_saved: ActionEffect = _save_effect(dmg, "sanctum_stiletto_damage_effect.tres")

	var bleed: ActionEffect = _make_add_status("Puncture: Bleed", S_BLEED, 2)
	var bleed_saved: ActionEffect = _save_effect(bleed, "sanctum_stiletto_bleed_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, bleed_saved])
	var a: Action = _make_action(
		"weapon_sanctum_stiletto_puncture",
		"Puncture",
		"A quick pierce that applies 2 Bleed. Reliable opener for bleed builds.",
		1, efx)
	_save_action(a, "sanctum_stiletto_puncture_action.tres")


# --- 41. Cinder Wand: Ember Shot ---
# DAMAGE + ADD_STATUS (burn x1) + MANA_MANIPULATE (+1 mana).
# Mana return reinforces INT wand fantasy (Mana secondary stat).
func _gen_cinder_wand() -> void:
	print("- Cinder Wand")
	var dmg: ActionEffect = _make_damage("Ember Shot: Damage", ActionEffect.DamageType.FIRE, 1)
	var dmg_saved: ActionEffect = _save_effect(dmg, "cinder_wand_damage_effect.tres")

	var burn: ActionEffect = _make_add_status("Ember Shot: Burn", S_BURN, 1)
	var burn_saved: ActionEffect = _save_effect(burn, "cinder_wand_burn_effect.tres")

	var mana: ActionEffect = _make_mana("Ember Shot: Mana Restore", 1)
	var mana_saved: ActionEffect = _save_effect(mana, "cinder_wand_mana_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, burn_saved, mana_saved])
	var a: Action = _make_action(
		"weapon_cinder_wand_ember_shot",
		"Ember Shot",
		"Fires a smouldering bolt. Applies 1 Burn. Restores 1 mana on use.",
		1, efx)
	_save_action(a, "cinder_wand_ember_shot_action.tres")


# --- 42. Frost Wand: Ice Shard ---
# DAMAGE + ADD_STATUS (chill x2) + MANA_MANIPULATE (+1 mana).
# 2 Chill per cast; 3 casts approach Freeze threshold unassisted.
func _gen_frost_wand() -> void:
	print("- Frost Wand")
	var dmg: ActionEffect = _make_damage("Ice Shard: Damage", ActionEffect.DamageType.ICE, 1)
	var dmg_saved: ActionEffect = _save_effect(dmg, "frost_wand_damage_effect.tres")

	var chill: ActionEffect = _make_add_status("Ice Shard: Chill", S_CHILL, 2)
	var chill_saved: ActionEffect = _save_effect(chill, "frost_wand_chill_effect.tres")

	var mana: ActionEffect = _make_mana("Ice Shard: Mana Restore", 1)
	var mana_saved: ActionEffect = _save_effect(mana, "frost_wand_mana_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, chill_saved, mana_saved])
	var a: Action = _make_action(
		"weapon_frost_wand_ice_shard",
		"Ice Shard",
		"Fires a cold shard. Applies 2 Chill. Restores 1 mana on use.",
		1, efx)
	_save_action(a, "frost_wand_ice_shard_action.tres")


# --- 43. Spark Wand: Zap ---
# DAMAGE + ADD_STATUS (static x2) + MANA_MANIPULATE (+1 mana).
# Static stacks amplify incoming shock damage.
func _gen_spark_wand() -> void:
	print("- Spark Wand")
	var dmg: ActionEffect = _make_damage("Zap: Damage", ActionEffect.DamageType.SHOCK, 1)
	var dmg_saved: ActionEffect = _save_effect(dmg, "spark_wand_damage_effect.tres")

	var stat: ActionEffect = _make_add_status("Zap: Static", S_STATIC, 2)
	var stat_saved: ActionEffect = _save_effect(stat, "spark_wand_static_effect.tres")

	var mana: ActionEffect = _make_mana("Zap: Mana Restore", 1)
	var mana_saved: ActionEffect = _save_effect(mana, "spark_wand_mana_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, stat_saved, mana_saved])
	var a: Action = _make_action(
		"weapon_spark_wand_zap",
		"Zap",
		"A quick shock that applies 2 Static. Restores 1 mana on use.",
		1, efx)
	_save_action(a, "spark_wand_zap_action.tres")


# --- 53. Parrying Blade: Parry ---
# DAMAGE_REDUCTION (50%, single-use) + COUNTER_SETUP.
# The COUNTER_SETUP references a nested DAMAGE effect (saved first per rule #3).
# Cooldown 2 to prevent spamming.
func _gen_parrying_blade() -> void:
	print("- Parrying Blade")

	# Step 1: counter DAMAGE effect — save first, load for reference
	var cdmg: ActionEffect = ActionEffect.new()
	cdmg.effect_name = "Parry: Counter Strike"
	cdmg.effect_type = ActionEffect.EffectType.DAMAGE
	cdmg.target = ActionEffect.TargetType.SINGLE_ENEMY
	cdmg.damage_type = ActionEffect.DamageType.PIERCING
	cdmg.base_damage = 0
	cdmg.dice_count = 1
	var cdmg_saved: ActionEffect = _save_effect(cdmg, "parrying_blade_counter_damage_effect.tres")

	# Step 2: DAMAGE_REDUCTION effect
	var dr: ActionEffect = ActionEffect.new()
	dr.effect_name = "Parry: Damage Reduction"
	dr.effect_type = ActionEffect.EffectType.DAMAGE_REDUCTION
	dr.target = ActionEffect.TargetType.SELF
	dr.reduction_amount = 0.5
	dr.reduction_is_percent = true
	dr.reduction_duration = 1
	dr.reduction_single_use = true
	var dr_saved: ActionEffect = _save_effect(dr, "parrying_blade_dmg_reduction_effect.tres")

	# Step 3: COUNTER_SETUP references saved counter damage — save-before-reference
	var cs: ActionEffect = ActionEffect.new()
	cs.effect_name = "Parry: Counter Setup"
	cs.effect_type = ActionEffect.EffectType.COUNTER_SETUP
	cs.target = ActionEffect.TargetType.SELF
	cs.counter_effect = cdmg_saved
	cs.counter_charges = 1
	cs.counter_damage_threshold = 0
	var cs_saved: ActionEffect = _save_effect(cs, "parrying_blade_counter_setup_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dr_saved, cs_saved])
	var a: Action = _make_action(
		"weapon_parrying_blade_parry",
		"Parry",
		"50% damage reduction on the next hit taken. Counters immediately with a piercing strike.",
		1, efx, 2)
	_save_action(a, "parrying_blade_parry_action.tres")


# --- 54. Naval Greatsword: Grand Sweep ---
# SPLASH only (self-contained, 75% to adjacent). Upgrade path from Cutlass.
func _gen_naval_greatsword() -> void:
	print("- Naval Greatsword")
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = "Grand Sweep: Slash and Splash"
	e.effect_type = ActionEffect.EffectType.SPLASH
	e.target = ActionEffect.TargetType.SINGLE_ENEMY
	e.damage_type = ActionEffect.DamageType.SLASHING
	e.base_damage = 0
	e.dice_count = 1
	e.splash_percent = 0.75
	e.splash_all = false
	var splash: ActionEffect = _save_effect(e, "naval_greatsword_sweep_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([splash])
	var a: Action = _make_action(
		"weapon_naval_greatsword_grand_sweep",
		"Grand Sweep",
		"A massive cleave. Deals 75% splash damage to adjacent enemies.",
		1, efx)
	_save_action(a, "naval_greatsword_grand_sweep_action.tres")


# --- 55. Iron Warhammer: Pulverize ---
# DAMAGE + ADD_STATUS (corrode x3). Each stack = -2 armor.
func _gen_iron_warhammer() -> void:
	print("- Iron Warhammer")
	var dmg: ActionEffect = _make_damage("Pulverize: Damage", ActionEffect.DamageType.BLUNT, 1)
	var dmg_saved: ActionEffect = _save_effect(dmg, "iron_warhammer_damage_effect.tres")

	var corrode: ActionEffect = _make_add_status("Pulverize: Corrode", S_CORRODE, 3)
	var corrode_saved: ActionEffect = _save_effect(corrode, "iron_warhammer_corrode_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, corrode_saved])
	var a: Action = _make_action(
		"weapon_iron_warhammer_pulverize",
		"Pulverize",
		"A crushing blow that applies 3 Corrode, reducing enemy armor by 6.",
		1, efx)
	_save_action(a, "iron_warhammer_pulverize_action.tres")


# --- 56. Marine Halberd: Formation Thrust ---
# DAMAGE + ADD_STATUS (expose x2). +2% crit per stack against the target.
func _gen_marine_halberd() -> void:
	print("- Marine Halberd")
	var dmg: ActionEffect = _make_damage("Formation Thrust: Damage", ActionEffect.DamageType.PIERCING, 1)
	var dmg_saved: ActionEffect = _save_effect(dmg, "marine_halberd_damage_effect.tres")

	var expose: ActionEffect = _make_add_status("Formation Thrust: Expose", S_EXPOSE, 2)
	var expose_saved: ActionEffect = _save_effect(expose, "marine_halberd_expose_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, expose_saved])
	var a: Action = _make_action(
		"weapon_marine_halberd_formation_thrust",
		"Formation Thrust",
		"A disciplined strike. Applies 2 Expose, increasing crit chance against this target.",
		1, efx)
	_save_action(a, "marine_halberd_formation_thrust_action.tres")


# --- 57. Longbow: Volley ---
# RANDOM_STRIKES (2 shots, distributes to random enemies).
# die_slots=2 (both dice required). dice_count=1 per strike (each shot uses 1 die).
func _gen_longbow() -> void:
	print("- Longbow")
	var e: ActionEffect = ActionEffect.new()
	e.effect_name = "Volley: Random Strikes"
	e.effect_type = ActionEffect.EffectType.RANDOM_STRIKES
	e.target = ActionEffect.TargetType.ALL_ENEMIES
	e.damage_type = ActionEffect.DamageType.PIERCING
	e.strike_count = 2
	e.strike_damage = 0
	e.strikes_use_dice = true
	e.dice_count = 1
	e.strike_multiplier = 1.0
	var volley: ActionEffect = _save_effect(e, "longbow_volley_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([volley])
	var a: Action = _make_action(
		"weapon_longbow_volley",
		"Volley",
		"Fire two arrows, each seeking a random target.",
		2, efx)
	_save_action(a, "longbow_volley_action.tres")


# --- 58. Ember Staff: Flame Burst ---
# DAMAGE + ADD_STATUS (burn x3) + ECHO (fires at 40% if dice total >= 10).
# ECHO is a bonus repeat hit, not a second DAMAGE — both coexist correctly.
func _gen_ember_staff() -> void:
	print("- Ember Staff")
	var dmg: ActionEffect = _make_damage("Flame Burst: Damage", ActionEffect.DamageType.FIRE, 2)
	var dmg_saved: ActionEffect = _save_effect(dmg, "ember_staff_damage_effect.tres")

	var burn: ActionEffect = _make_add_status("Flame Burst: Burn", S_BURN, 3)
	var burn_saved: ActionEffect = _save_effect(burn, "ember_staff_burn_effect.tres")

	var echo: ActionEffect = ActionEffect.new()
	echo.effect_name = "Flame Burst: Echo"
	echo.effect_type = ActionEffect.EffectType.ECHO
	echo.target = ActionEffect.TargetType.SINGLE_ENEMY
	echo.damage_type = ActionEffect.DamageType.FIRE
	echo.echo_threshold = 10
	echo.echo_count = 1
	echo.echo_multiplier = 0.4
	var echo_saved: ActionEffect = _save_effect(echo, "ember_staff_echo_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, burn_saved, echo_saved])
	var a: Action = _make_action(
		"weapon_ember_staff_flame_burst",
		"Flame Burst",
		"A powerful fire blast. Applies 3 Burn. Echoes at 40% if dice total is 10 or more.",
		2, efx)
	_save_action(a, "ember_staff_flame_burst_action.tres")


# --- 59. Frost Staff: Frost Bolt ---
# DAMAGE + ADD_STATUS (chill x5). No secondary effect — Freeze is the payoff.
func _gen_frost_staff() -> void:
	print("- Frost Staff")
	var dmg: ActionEffect = _make_damage("Frost Bolt: Damage", ActionEffect.DamageType.ICE, 2)
	var dmg_saved: ActionEffect = _save_effect(dmg, "frost_staff_damage_effect.tres")

	var chill: ActionEffect = _make_add_status("Frost Bolt: Chill", S_CHILL, 5)
	var chill_saved: ActionEffect = _save_effect(chill, "frost_staff_chill_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, chill_saved])
	var a: Action = _make_action(
		"weapon_frost_staff_frost_bolt",
		"Frost Bolt",
		"A chilling blast. Applies 5 Chill per cast. Three casts reach the Freeze threshold.",
		2, efx)
	_save_action(a, "frost_staff_frost_bolt_action.tres")


# --- 60. Storm Staff: Thunderstrike ---
# ADD_STATUS (static x3) + CHAIN (primary shock damage + chains to second enemy).
# CHAIN is self-contained (handles primary damage), so no separate DAMAGE effect.
func _gen_storm_staff() -> void:
	print("- Storm Staff")
	var stat: ActionEffect = _make_add_status("Thunderstrike: Static", S_STATIC, 3)
	var stat_saved: ActionEffect = _save_effect(stat, "storm_staff_static_effect.tres")

	var chain: ActionEffect = ActionEffect.new()
	chain.effect_name = "Thunderstrike: Chain"
	chain.effect_type = ActionEffect.EffectType.CHAIN
	chain.target = ActionEffect.TargetType.SINGLE_ENEMY
	chain.damage_type = ActionEffect.DamageType.SHOCK
	chain.base_damage = 0
	chain.dice_count = 2
	chain.chain_count = 1
	chain.chain_decay = 0.5
	chain.chain_can_repeat = false
	var chain_saved: ActionEffect = _save_effect(chain, "storm_staff_chain_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([stat_saved, chain_saved])
	var a: Action = _make_action(
		"weapon_storm_staff_thunderstrike",
		"Thunderstrike",
		"Applies 3 Static, then strikes for shock damage that chains to a second enemy at 50%.",
		2, efx)
	_save_action(a, "storm_staff_thunderstrike_action.tres")


# --- 61. Venom Staff: Venom Lance ---
# DAMAGE + ADD_STATUS (poison x4). Patient DoT weapon; strong vs high-HP targets.
func _gen_venom_staff() -> void:
	print("- Venom Staff")
	var dmg: ActionEffect = _make_damage("Venom Lance: Damage", ActionEffect.DamageType.POISON, 2)
	var dmg_saved: ActionEffect = _save_effect(dmg, "venom_staff_damage_effect.tres")

	var poison: ActionEffect = _make_add_status("Venom Lance: Poison", S_POISON, 4)
	var poison_saved: ActionEffect = _save_effect(poison, "venom_staff_poison_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, poison_saved])
	var a: Action = _make_action(
		"weapon_venom_staff_venom_lance",
		"Venom Lance",
		"A pressurised toxin bolt. Applies 4 Poison.",
		2, efx)
	_save_action(a, "venom_staff_venom_lance_action.tres")


# --- 62. Shadow Staff: Shadow Bolt ---
# DAMAGE + LIFESTEAL (25%, no bonus damage) + EXECUTE (+50% below 20% HP).
# execute_bonus = 0.5 means total multiplier = 1.0 + 0.5 = 1.5x damage.
func _gen_shadow_staff() -> void:
	print("- Shadow Staff")
	var dmg: ActionEffect = _make_damage("Shadow Bolt: Damage", ActionEffect.DamageType.SHADOW, 2)
	var dmg_saved: ActionEffect = _save_effect(dmg, "shadow_staff_damage_effect.tres")

	var ls: ActionEffect = ActionEffect.new()
	ls.effect_name = "Shadow Bolt: Lifesteal"
	ls.effect_type = ActionEffect.EffectType.LIFESTEAL
	ls.target = ActionEffect.TargetType.SELF
	ls.lifesteal_percent = 0.25
	ls.lifesteal_deals_damage = false
	var ls_saved: ActionEffect = _save_effect(ls, "shadow_staff_lifesteal_effect.tres")

	var ex: ActionEffect = ActionEffect.new()
	ex.effect_name = "Shadow Bolt: Execute"
	ex.effect_type = ActionEffect.EffectType.EXECUTE
	ex.target = ActionEffect.TargetType.SINGLE_ENEMY
	ex.damage_type = ActionEffect.DamageType.SHADOW
	ex.base_damage = 0
	ex.dice_count = 2
	ex.execute_threshold = 0.2
	ex.execute_bonus = 0.5
	ex.execute_instant_kill = false
	var ex_saved: ActionEffect = _save_effect(ex, "shadow_staff_execute_effect.tres")

	var efx: Array[ActionEffect] = []
	efx.assign([dmg_saved, ls_saved, ex_saved])
	var a: Action = _make_action(
		"weapon_shadow_staff_shadow_bolt",
		"Shadow Bolt",
		"Dark magic that heals 25% of damage dealt. Deals 1.5x damage to targets below 20% HP.",
		2, efx)
	_save_action(a, "shadow_staff_shadow_bolt_action.tres")
