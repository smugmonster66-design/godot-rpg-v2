# res://scripts/resources/action_effect.gd
# Granular effect that an action performs.
#
# v3.1 FINAL — 21 EffectTypes across 6 categories.
#
# Core:            DAMAGE, HEAL, ADD_STATUS, REMOVE_STATUS, CLEANSE
# Defensive:       SHIELD, ARMOR_BUFF, DAMAGE_REDUCTION, REFLECT
# Combat Modifier: LIFESTEAL, EXECUTE, COMBO_MARK, ECHO
# Multi-Target:    SPLASH, CHAIN, RANDOM_STRIKES
# Economy:         MANA_MANIPULATE, MODIFY_COOLDOWN, REFUND_CHARGES, GRANT_TEMP_ACTION
# Battlefield:     CHANNEL, COUNTER_SETUP
extends Resource
class_name ActionEffect

# ============================================================================
# ENUMS
# ============================================================================
enum TargetType { SELF, SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES }

enum EffectType {
	DAMAGE, HEAL, ADD_STATUS, REMOVE_STATUS, CLEANSE,
	SHIELD, ARMOR_BUFF, DAMAGE_REDUCTION, REFLECT,
	LIFESTEAL, EXECUTE, COMBO_MARK, ECHO,
	SPLASH, CHAIN, RANDOM_STRIKES,
	MANA_MANIPULATE, MODIFY_COOLDOWN, REFUND_CHARGES, GRANT_TEMP_ACTION,
	CHANNEL, COUNTER_SETUP, SUMMON_COMPANION,
}

enum DamageType { SLASHING, BLUNT, PIERCING, FIRE, ICE, SHOCK, POISON, SHADOW }

enum ValueSource {
	# --- Original 12 (unchanged integer values 0–11) ---
	STATIC,                 ##  0
	DICE_TOTAL,             ##  1
	DICE_COUNT,             ##  2
	SOURCE_STAT,            ##  3
	SOURCE_HP_PERCENT,      ##  4
	SOURCE_MISSING_HP,      ##  5
	TARGET_HP_PERCENT,      ##  6
	TARGET_MISSING_HP,      ##  7
	TARGET_STATUS_STACKS,   ##  8
	TURN_NUMBER,            ##  9
	ACTIVE_STATUS_COUNT,    ## 10
	MANA_PERCENT,           ## 11
	# --- New (appended, 12–19) ---
	SOURCE_CURRENT_HP,      ## 12  current_hp × (base_value / 100)
	SOURCE_MAX_HP,          ## 13  max_hp × (base_value / 100)
	SOURCE_DEFENSE_STAT,    ## 14  armor or barrier × base_value
	TARGET_CURRENT_HP,      ## 15  current_hp × (base_value / 100)
	TARGET_MAX_HP,          ## 16  max_hp × (base_value / 100)
	ALIVE_ENEMY_COUNT,      ## 17  living enemies × base_value
	ALIVE_COMPANION_COUNT,  ## 18  living companions × base_value
	TRIGGER_DAMAGE_AMOUNT,  ## 19  trigger damage × (base_value / 100)
}




# ============================================================================
# CORE
# ============================================================================
@export var effect_name: String = "New Effect"
@export var target: TargetType = TargetType.SINGLE_ENEMY
@export var effect_type: EffectType = EffectType.DAMAGE

@export_group("Condition")
@export var condition: ActionEffectCondition = null

@export_group("Value Source")
@export var value_source: ValueSource = ValueSource.STATIC

## SOURCE_STAT: which primary stat to scale from (dropdown).
@export_enum("strength", "agility", "intellect", "luck")
var value_source_stat: String = "strength"

## TARGET_STATUS_STACKS: which status to count stacks of.
@export var value_source_status_id: String = ""

## SOURCE_DEFENSE_STAT: which defense stat to scale from (dropdown).
@export_enum("armor", "barrier")
var value_source_defense: String = "armor"

## DEPRECATED — use the typed fields above. Kept for old .tres compatibility.
@export var value_source_data: Dictionary = {}

@export var effect_data: Dictionary = {}

# ============================================================================
# DAMAGE / HEAL / STATUS / CLEANSE
# ============================================================================
@export_group("Damage Settings")
@export var damage_type: DamageType = DamageType.SLASHING
@export var base_damage: int = 0
@export var damage_multiplier: float = 1.0
@export var dice_count: int = 1

@export_group("Heal Settings")
@export var base_heal: int = 0
@export var heal_multiplier: float = 1.0
@export var heal_uses_dice: bool = false

@export_group("Status Settings")
@export var status_affix: StatusAffix = null
@export var stack_count: int = 1

@export_group("Cleanse Settings")
@export var cleanse_tags: Array[String] = []
@export var cleanse_max_removals: int = 0

# ============================================================================
# DEFENSIVE
# ============================================================================
@export_group("Shield Settings")
@export var shield_amount: int = 0
@export var shield_uses_dice: bool = true
@export var shield_multiplier: float = 1.0
@export var shield_duration: int = -1

@export_group("Armor Buff Settings")
@export var armor_buff_amount: int = 0
@export var armor_buff_uses_dice: bool = false
@export var armor_buff_duration: int = 2

@export_group("Damage Reduction Settings")
@export var reduction_amount: float = 0.0
@export var reduction_uses_dice: bool = false
@export var reduction_is_percent: bool = false
@export var reduction_duration: int = 1
@export var reduction_single_use: bool = false

@export_group("Reflect Settings")
@export var reflect_percent: float = 0.3
@export var reflect_duration: int = 2
@export var reflect_element: DamageType = DamageType.SLASHING

# ============================================================================
# COMBAT MODIFIERS
# ============================================================================
@export_group("Lifesteal Settings")
@export var lifesteal_percent: float = 0.3
@export var lifesteal_deals_damage: bool = true

@export_group("Execute Settings")
@export var execute_threshold: float = 0.3
@export var execute_bonus: float = 1.0
@export var execute_instant_kill: bool = false

@export_group("Combo Mark Settings")
@export var mark_status: StatusAffix = null
@export var mark_stacks: int = 1
@export var mark_consume_bonus: int = 5
@export var mark_deals_damage: bool = false

@export_group("Echo Settings")
@export var echo_threshold: int = 10
@export var echo_count: int = 1
@export var echo_multiplier: float = 0.5
@export var echo_effect_type: int = -1

# ============================================================================
# MULTI-TARGET
# ============================================================================
@export_group("Splash Settings")
## Percentage of primary damage dealt to adjacent enemies.
@export var splash_percent: float = 0.5
## If true, splash hits ALL enemies instead of just adjacent.
@export var splash_all: bool = false

@export_group("Chain Settings")
## Number of bounces after the primary hit.
@export var chain_count: int = 2
## Multiplicative decay per bounce (0.7 = 70% of previous).
@export var chain_decay: float = 0.7
## If true, chain can bounce back to already-hit targets.
@export var chain_can_repeat: bool = false

@export_group("Random Strikes Settings")
## Number of independent strikes distributed randomly.
@export var strike_count: int = 3
## Per-strike damage (0 = use base_damage).
@export var strike_damage: int = 0
## If true, adds dice total to each strike.
@export var strikes_use_dice: bool = false
@export var strike_multiplier: float = 1.0

# ============================================================================
# ECONOMY
# ============================================================================
@export_group("Mana Settings")
## Positive = gain, negative = drain.
@export var mana_amount: int = 0
## If true, adds dice total to mana_amount.
@export var mana_uses_dice: bool = false

@export_group("Cooldown Settings")
## Turns to reduce cooldown by (positive = reduce).
@export var cooldown_reduction: int = 1
## Target action ID. Empty = all actions with active cooldowns.
@export var cooldown_target_action_id: String = ""

@export_group("Charge Refund Settings")
## Number of charges to restore.
@export var charges_to_refund: int = 1
## Target action ID. Empty = all limited actions.
@export var refund_target_action_id: String = ""

@export_group("Grant Action Settings")
## The Action resource to grant temporarily.
@export var granted_action: Action = null
## Number of turns the action persists (0 = current turn only).
@export var grant_duration: int = 1

# ============================================================================
# CHANNEL
# ============================================================================
@export_group("Channel Settings")
## Maximum turns the channel can be maintained.
@export var channel_max_turns: int = 3
## Additive growth per turn (0.5 = +50% per turn maintained).
@export var channel_growth_per_turn: float = 0.5
## The ActionEffect that fires on release/break.
@export var channel_release_effect: ActionEffect = null

# ============================================================================
# COUNTER
# ============================================================================
@export_group("Counter Settings")
## The ActionEffect that fires when counter triggers.
@export var counter_effect: ActionEffect = null
## Times the counter can fire.
@export var counter_charges: int = 1
## Minimum damage to trigger (0 = any).
@export var counter_damage_threshold: int = 0


# ============================================================================
# SUMMON COMPANION
# ============================================================================
@export_group("Summon Settings")
## CompanionData resource to summon. Required when effect_type == SUMMON_COMPANION.
@export var companion_data: CompanionData = null


# ============================================================================
# SUB-EFFECTS
# ============================================================================
@export_group("Sub-Effects (Compound)")
@export var sub_effects: Array[ActionEffectSubEffect] = []

# ============================================================================
# EXECUTION
# ============================================================================

func execute(source, targets: Array, dice_values: Array = [], context: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for target_entity in targets:
		var ctx = _ensure_context(context, source, target_entity, dice_values)
		var condition_mult := 1.0
		if has_condition():
			var cond_result = condition.evaluate(ctx)
			if cond_result.blocked:
				results.append({"effect_name": effect_name, "effect_type": effect_type, "target": target_entity, "success": false, "skipped": true, "skip_reason": "condition_failed"})
				continue
			condition_mult = cond_result.multiplier
		if is_compound():
			results.append_array(_execute_compound(source, target_entity, dice_values, ctx, condition_mult))
		else:
			results.append(_execute_on_target(source, target_entity, dice_values, ctx, condition_mult))
	return results

func _execute_on_target(source, target_entity, dice_values: Array, context: Dictionary = {}, condition_mult: float = 1.0) -> Dictionary:
	var result = {"effect_name": effect_name, "effect_type": effect_type, "target": target_entity, "source": source, "success": true}
	var rbd = _resolve_value(base_damage, context, condition_mult)
	var rbh = _resolve_value(base_heal, context, condition_mult)
	match effect_type:
		EffectType.DAMAGE: result.merge(_calculate_damage(dice_values, rbd))
		EffectType.HEAL: result.merge(_calculate_heal(dice_values, rbh))
		EffectType.ADD_STATUS: result.merge(_add_status_result())
		EffectType.REMOVE_STATUS: result.merge(_remove_status_result())
		EffectType.CLEANSE: result.merge(_cleanse_result())
		EffectType.SHIELD: result.merge(_calculate_shield(dice_values, context, condition_mult))
		EffectType.ARMOR_BUFF: result.merge(_calculate_armor_buff(dice_values, context, condition_mult))
		EffectType.DAMAGE_REDUCTION: result.merge(_calculate_damage_reduction(dice_values, context, condition_mult))
		EffectType.REFLECT: result.merge(_calculate_reflect(context, condition_mult))
		EffectType.LIFESTEAL: result.merge(_calculate_lifesteal(dice_values, context, condition_mult))
		EffectType.EXECUTE: result.merge(_calculate_execute(dice_values, context, condition_mult))
		EffectType.COMBO_MARK: result.merge(_calculate_combo_mark(dice_values, context, condition_mult))
		EffectType.ECHO: result.merge(_calculate_echo(dice_values, context, condition_mult))
		EffectType.SPLASH: result.merge(_calculate_splash(dice_values, context, condition_mult))
		EffectType.CHAIN: result.merge(_calculate_chain(dice_values, context, condition_mult))
		EffectType.RANDOM_STRIKES: result.merge(_calculate_random_strikes(dice_values, context, condition_mult))
		EffectType.MANA_MANIPULATE: result.merge(_calculate_mana(dice_values, context, condition_mult))
		EffectType.MODIFY_COOLDOWN: result.merge(_calculate_cooldown(context, condition_mult))
		EffectType.REFUND_CHARGES: result.merge(_calculate_refund(context, condition_mult))
		EffectType.GRANT_TEMP_ACTION: result.merge(_calculate_grant_action(context, condition_mult))
		EffectType.CHANNEL: result.merge(_calculate_channel())
		EffectType.COUNTER_SETUP: result.merge(_calculate_counter())
		EffectType.SUMMON_COMPANION:
			result["companion_data"] = companion_data
	return result

# ============================================================================
# COMPOUND EXECUTION
# ============================================================================

func _execute_compound(source, target_entity, dice_values: Array, context: Dictionary, pcm: float) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for sub in sub_effects:
		if not sub: continue
		var sm := pcm
		if sub.has_condition():
			var sr = sub.condition.evaluate(context)
			if sr.blocked: continue
			sm = sr.multiplier
		var sv = _resolve_sub_value(sub, sub.effect_value, context, sm)
		var result = {"effect_name": "%s (sub)" % effect_name, "effect_type": sub.effect_type, "target": target_entity, "source": source, "success": true, "is_sub_effect": true}
		match sub.effect_type:
			EffectType.DAMAGE:
				result.merge(_calculate_damage_custom(dice_values, int(sv), sub.effect_multiplier if sub.effect_multiplier != 1.0 else damage_multiplier, sub.effect_data.get("dice_count", dice_count)))
				result["damage_type"] = sub.effect_data.get("damage_type", damage_type)
			EffectType.HEAL:
				result.merge(_calculate_heal_custom(dice_values, int(sv), sub.effect_multiplier if sub.effect_multiplier != 1.0 else heal_multiplier, sub.effect_data.get("uses_dice", heal_uses_dice), sub.effect_data.get("dice_count", dice_count)))
			EffectType.ADD_STATUS:
				result.merge({"status_affix": sub.effect_data.get("status_affix", status_affix), "stacks_to_add": sub.effect_data.get("stack_count", stack_count)})
			EffectType.REMOVE_STATUS:
				var sc = sub.effect_data.get("stack_count", stack_count)
				result.merge({"status_affix": sub.effect_data.get("status_affix", status_affix), "stacks_to_remove": sc, "remove_all": sc == 0})
			EffectType.CLEANSE:
				result.merge({"cleanse_tags": sub.effect_data.get("cleanse_tags", cleanse_tags), "cleanse_max_removals": sub.effect_data.get("max_removals", cleanse_max_removals)})
			EffectType.SHIELD:
				result.merge({"shield_amount": int(sv) if sv > 0 else shield_amount, "shield_duration": sub.effect_data.get("duration", shield_duration)})
			EffectType.ARMOR_BUFF:
				result.merge({"armor_amount": int(sv) if sv > 0 else armor_buff_amount, "armor_duration": sub.effect_data.get("duration", armor_buff_duration)})
			EffectType.DAMAGE_REDUCTION:
				result.merge({"reduction_amount": sv if sv > 0 else reduction_amount, "reduction_is_percent": sub.effect_data.get("is_percent", reduction_is_percent), "reduction_duration": sub.effect_data.get("duration", reduction_duration), "reduction_single_use": sub.effect_data.get("single_use", reduction_single_use)})
			EffectType.REFLECT:
				result.merge({"reflect_percent": sv if sv > 0 else reflect_percent, "reflect_duration": sub.effect_data.get("duration", reflect_duration), "reflect_element": sub.effect_data.get("element", reflect_element)})
			EffectType.LIFESTEAL:
				var dd = sub.effect_data.get("deals_damage", lifesteal_deals_damage)
				result.merge({"lifesteal_percent": sv if sv > 0 else lifesteal_percent, "lifesteal_deals_damage": dd})
				if dd: result.merge(_calculate_damage_custom(dice_values, int(sv), sub.effect_multiplier if sub.effect_multiplier != 1.0 else damage_multiplier, sub.effect_data.get("dice_count", dice_count)))
			EffectType.EXECUTE:
				result.merge({"execute_threshold": sub.effect_data.get("threshold", execute_threshold), "execute_bonus": sub.effect_data.get("bonus", execute_bonus), "execute_instant_kill": sub.effect_data.get("instant_kill", execute_instant_kill)})
				result.merge(_calculate_damage_custom(dice_values, int(sv) if int(sv) > 0 else base_damage, sub.effect_multiplier if sub.effect_multiplier != 1.0 else damage_multiplier, sub.effect_data.get("dice_count", dice_count)))
			EffectType.COMBO_MARK:
				result.merge({"mark_status": sub.effect_data.get("mark_status", mark_status), "mark_stacks": sub.effect_data.get("mark_stacks", mark_stacks), "mark_consume_bonus": sub.effect_data.get("consume_bonus", mark_consume_bonus), "mark_deals_damage": sub.effect_data.get("deals_damage", mark_deals_damage)})
			EffectType.ECHO:
				result.merge({"echo_threshold": sub.effect_data.get("threshold", echo_threshold), "echo_count": sub.effect_data.get("count", echo_count), "echo_multiplier": sub.effect_data.get("multiplier", echo_multiplier)})
			EffectType.SPLASH:
				result.merge({"splash_percent": sv if sv > 0 else splash_percent, "splash_all": sub.effect_data.get("splash_all", splash_all)})
				result.merge(_calculate_damage_custom(dice_values, int(sv) if int(sv) > 0 else base_damage, sub.effect_multiplier if sub.effect_multiplier != 1.0 else damage_multiplier, sub.effect_data.get("dice_count", dice_count)))
			EffectType.CHAIN:
				result.merge({"chain_count": sub.effect_data.get("chain_count", chain_count), "chain_decay": sub.effect_data.get("chain_decay", chain_decay), "chain_can_repeat": sub.effect_data.get("chain_can_repeat", chain_can_repeat)})
				result.merge(_calculate_damage_custom(dice_values, int(sv) if int(sv) > 0 else base_damage, sub.effect_multiplier if sub.effect_multiplier != 1.0 else damage_multiplier, sub.effect_data.get("dice_count", dice_count)))
			EffectType.RANDOM_STRIKES:
				result.merge({"strike_count": sub.effect_data.get("strike_count", strike_count), "strike_damage": sub.effect_data.get("strike_damage", strike_damage), "strikes_use_dice": sub.effect_data.get("strikes_use_dice", strikes_use_dice), "strike_multiplier": sub.effect_data.get("strike_multiplier", strike_multiplier)})
			EffectType.MANA_MANIPULATE:
				result.merge({"mana_amount": int(sv) if int(sv) != 0 else mana_amount, "mana_uses_dice": sub.effect_data.get("mana_uses_dice", mana_uses_dice)})
			EffectType.MODIFY_COOLDOWN:
				result.merge({"cooldown_reduction": sub.effect_data.get("cooldown_reduction", cooldown_reduction), "cooldown_target_action_id": sub.effect_data.get("target_action_id", cooldown_target_action_id)})
			EffectType.REFUND_CHARGES:
				result.merge({"charges_to_refund": sub.effect_data.get("charges_to_refund", charges_to_refund), "refund_target_action_id": sub.effect_data.get("target_action_id", refund_target_action_id)})
			EffectType.GRANT_TEMP_ACTION:
				result.merge({"granted_action": sub.effect_data.get("granted_action", granted_action), "grant_duration": sub.effect_data.get("grant_duration", grant_duration)})
			EffectType.CHANNEL:
				result.merge({"channel_max_turns": sub.effect_data.get("channel_max_turns", channel_max_turns), "channel_growth_per_turn": sub.effect_data.get("channel_growth_per_turn", channel_growth_per_turn), "channel_release_effect": sub.effect_data.get("channel_release_effect", channel_release_effect)})
			EffectType.COUNTER_SETUP:
				result.merge({"counter_effect": sub.effect_data.get("counter_effect", counter_effect), "counter_charges": sub.effect_data.get("counter_charges", counter_charges), "counter_damage_threshold": sub.effect_data.get("counter_damage_threshold", counter_damage_threshold)})
		results.append(result)
	return results

# ============================================================================
# BATTLEFIELD CALCULATIONS
# ============================================================================

func _calculate_channel() -> Dictionary:
	return {"channel_max_turns": channel_max_turns, "channel_growth_per_turn": channel_growth_per_turn, "channel_release_effect": channel_release_effect}

func _calculate_counter() -> Dictionary:
	return {"counter_effect": counter_effect, "counter_charges": counter_charges, "counter_damage_threshold": counter_damage_threshold}

# ============================================================================
# ECONOMY CALCULATIONS
# ============================================================================

func _calculate_mana(dice_values: Array, context: Dictionary, cm: float) -> Dictionary:
	var rv = _resolve_value(mana_amount, context, cm)
	var dt = 0
	if mana_uses_dice:
		var du = mini(dice_count, dice_values.size())
		for i in range(du): dt += dice_values[i]
	return {"mana_amount": rv + dt, "mana_uses_dice": mana_uses_dice, "dice_total": dt}

func _calculate_cooldown(context: Dictionary, cm: float) -> Dictionary:
	return {"cooldown_reduction": int(cooldown_reduction * cm), "cooldown_target_action_id": cooldown_target_action_id}

func _calculate_refund(context: Dictionary, cm: float) -> Dictionary:
	return {"charges_to_refund": int(charges_to_refund * cm), "refund_target_action_id": refund_target_action_id}

func _calculate_grant_action(context: Dictionary, _cm: float) -> Dictionary:
	return {"granted_action": granted_action, "grant_duration": grant_duration}

# ============================================================================
# MULTI-TARGET CALCULATIONS
# ============================================================================

func _calculate_splash(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var d = _calculate_damage_custom(dv, _resolve_value(base_damage, ctx, cm), damage_multiplier, dice_count)
	var pd: int = d.get("damage", 0)
	d.merge({"splash_percent": splash_percent, "splash_damage": int(pd * splash_percent), "splash_all": splash_all, "primary_damage": pd})
	return d

func _calculate_chain(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var d = _calculate_damage_custom(dv, _resolve_value(base_damage, ctx, cm), damage_multiplier, dice_count)
	var pd: int = d.get("damage", 0)
	var cds: Array[int] = []; var cd = float(pd)
	for i in range(chain_count):
		cd *= chain_decay
		if int(cd) <= 0: break
		cds.append(int(cd))
	d.merge({"chain_count": chain_count, "chain_decay": chain_decay, "chain_can_repeat": chain_can_repeat, "chain_damages": cds, "primary_damage": pd})
	return d

func _calculate_random_strikes(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var psb = strike_damage if strike_damage > 0 else base_damage
	var rv = _resolve_value(psb, ctx, cm); var dt = 0
	if strikes_use_dice:
		var du = mini(dice_count, dv.size())
		for i in range(du): dt += dv[i]
	var psd = int((dt + rv) * strike_multiplier)
	var sd: Array[int] = []
	for i in range(strike_count): sd.append(psd)
	return {"strike_count": strike_count, "strike_damage": psd, "strike_damages": sd, "strikes_use_dice": strikes_use_dice, "strike_multiplier": strike_multiplier, "dice_total": dt, "damage_type": damage_type}

# ============================================================================
# COMBAT MODIFIER CALCULATIONS
# ============================================================================

func _calculate_lifesteal(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var r: Dictionary = {"lifesteal_percent": lifesteal_percent * cm, "lifesteal_deals_damage": lifesteal_deals_damage}
	if lifesteal_deals_damage: r.merge(_calculate_damage_custom(dv, _resolve_value(base_damage, ctx, 1.0), damage_multiplier, dice_count))
	return r

func _calculate_execute(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var d = _calculate_damage_custom(dv, _resolve_value(base_damage, ctx, cm), damage_multiplier, dice_count)
	var thp = ctx.get("target_hp_percent", 1.0); var ex = thp >= 0 and thp < execute_threshold
	if ex and not execute_instant_kill: d["damage"] = int(d["damage"] * (1.0 + execute_bonus))
	d.merge({"execute_threshold": execute_threshold, "execute_bonus": execute_bonus, "execute_triggered": ex, "execute_instant_kill": execute_instant_kill and ex})
	return d

func _calculate_combo_mark(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var r: Dictionary = {"mark_status": mark_status, "mark_stacks": mark_stacks, "mark_consume_bonus": int(mark_consume_bonus * cm), "mark_deals_damage": mark_deals_damage}
	if mark_deals_damage: r.merge(_calculate_damage_custom(dv, _resolve_value(base_damage, ctx, cm), damage_multiplier, dice_count))
	return r

func _calculate_echo(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var dt = ctx.get("dice_total", 0); var trig = dt >= echo_threshold
	var eet = echo_effect_type if echo_effect_type >= 0 else EffectType.DAMAGE
	var r: Dictionary = {"echo_triggered": trig, "echo_threshold": echo_threshold, "echo_count": echo_count if trig else 0, "echo_multiplier": echo_multiplier, "echo_effect_type": eet, "dice_total": dt}
	if trig and eet == EffectType.DAMAGE:
		var ed = _calculate_damage_custom(dv, _resolve_value(base_damage, ctx, cm), damage_multiplier, dice_count)
		r["echo_base_damage"] = ed.get("damage", 0)
		var eds: Array[int] = []; var emult = echo_multiplier
		for i in range(echo_count): eds.append(int(ed.get("damage", 0) * emult)); emult *= echo_multiplier
		r["echo_damages"] = eds
	return r

# ============================================================================
# DEFENSIVE CALCULATIONS
# ============================================================================

func _calculate_shield(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var dt = 0
	if shield_uses_dice:
		var du = mini(dice_count, dv.size())
		for i in range(du): dt += dv[i]
	var rb = _resolve_value(shield_amount, ctx, cm)
	return {"shield_amount": int((dt + rb) * shield_multiplier), "shield_duration": shield_duration, "dice_total": dt, "base_shield": rb, "multiplier": shield_multiplier}

func _calculate_armor_buff(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var dt = 0
	if armor_buff_uses_dice:
		var du = mini(dice_count, dv.size())
		for i in range(du): dt += dv[i]
	var rb = _resolve_value(armor_buff_amount, ctx, cm)
	return {"armor_amount": dt + rb, "armor_duration": armor_buff_duration, "dice_total": dt, "base_armor": rb}

func _calculate_damage_reduction(dv: Array, ctx: Dictionary, cm: float) -> Dictionary:
	var dt = 0
	if reduction_uses_dice and not reduction_is_percent:
		var du = mini(dice_count, dv.size())
		for i in range(du): dt += dv[i]
	var rb: float = reduction_amount * cm if reduction_is_percent else float(_resolve_value(int(reduction_amount), ctx, cm))
	return {"reduction_amount": dt + rb, "reduction_is_percent": reduction_is_percent, "reduction_duration": reduction_duration, "reduction_single_use": reduction_single_use, "dice_total": dt}

func _calculate_reflect(ctx: Dictionary, cm: float) -> Dictionary:
	return {"reflect_percent": reflect_percent * cm, "reflect_duration": reflect_duration, "reflect_element": reflect_element}

# ============================================================================
# VALUE RESOLUTION
# ============================================================================

func _resolve_value(sv: int, ctx: Dictionary, cm: float = 1.0) -> int:
	if value_source == ValueSource.STATIC: return int(float(sv) * cm)
	var dv := float(sv)
	match value_source:
		# --- Dice ---
		ValueSource.DICE_TOTAL: dv = float(ctx.get("dice_total", 0))
		ValueSource.DICE_COUNT: dv = float(ctx.get("dice_count", 0)) * float(sv)
		# --- Source / Caster ---
		ValueSource.SOURCE_STAT:
			var s = ctx.get("source")
			var sn = value_source_stat if value_source_stat != "" \
				else value_source_data.get("stat_name", "strength")
			if s and s.has_method("get_stat"): dv = float(s.get_stat(sn)) * float(sv)
			elif s and "stats" in s: dv = float(s.stats.get(sn, 0)) * float(sv)
		ValueSource.SOURCE_HP_PERCENT: dv = ctx.get("source_hp_percent", 1.0) * float(sv)
		ValueSource.SOURCE_MISSING_HP: dv = (1.0 - ctx.get("source_hp_percent", 1.0)) * float(sv)
		ValueSource.SOURCE_CURRENT_HP:
			dv = float(ctx.get("source_current_hp", 0)) * float(sv) / 100.0
		ValueSource.SOURCE_MAX_HP:
			dv = float(ctx.get("source_max_hp", 0)) * float(sv) / 100.0
		ValueSource.SOURCE_DEFENSE_STAT:
			var s = ctx.get("source")
			var stat = value_source_defense if value_source_defense != "" else "armor"
			if s and s.has_method("get_stat"): dv = float(s.get_stat(stat)) * float(sv)
			elif s and stat in s: dv = float(s.get(stat)) * float(sv)
			else: dv = 0.0
		# --- Target ---
		ValueSource.TARGET_HP_PERCENT: dv = ctx.get("target_hp_percent", 1.0) * float(sv)
		ValueSource.TARGET_MISSING_HP: dv = (1.0 - ctx.get("target_hp_percent", 1.0)) * float(sv)
		ValueSource.TARGET_CURRENT_HP:
			dv = float(ctx.get("target_current_hp", 0)) * float(sv) / 100.0
		ValueSource.TARGET_MAX_HP:
			dv = float(ctx.get("target_max_hp", 0)) * float(sv) / 100.0
		ValueSource.TARGET_STATUS_STACKS:
			var t = ctx.get("target_tracker")
			var sid = value_source_status_id if value_source_status_id != "" \
				else value_source_data.get("status_id", "")
			dv = float(t.get_stacks(sid) if t else 0) * float(sv)
		ValueSource.ACTIVE_STATUS_COUNT:
			var t = ctx.get("target_tracker")
			dv = float(t.get_all_active().size() if t else 0) * float(sv)
		# --- Combat State ---
		ValueSource.TURN_NUMBER: dv = float(ctx.get("turn_number", 1)) * float(sv)
		ValueSource.MANA_PERCENT:
			dv = (float(ctx.get("current_mana", 0)) / maxf(float(ctx.get("max_mana", 1)), 1.0)) * float(sv)
		ValueSource.ALIVE_ENEMY_COUNT:
			dv = float(ctx.get("alive_enemies", 0)) * float(sv)
		ValueSource.ALIVE_COMPANION_COUNT:
			dv = float(ctx.get("alive_companions", 0)) * float(sv)
		ValueSource.TRIGGER_DAMAGE_AMOUNT:
			dv = float(ctx.get("trigger_damage", 0)) * float(sv) / 100.0
	# Enforce minimum 1 for percent-of-HP sources when sv > 0 and target has HP
	var final := int(dv * cm)
	match value_source:
		ValueSource.SOURCE_CURRENT_HP, ValueSource.SOURCE_MAX_HP, \
		ValueSource.TARGET_CURRENT_HP, ValueSource.TARGET_MAX_HP, \
		ValueSource.TRIGGER_DAMAGE_AMOUNT:
			if final == 0 and sv > 0:
				final = 1
	return maxi(final, 0)

func _resolve_sub_value(sub: ActionEffectSubEffect, bv: float, ctx: Dictionary, cm: float) -> float:
	if sub.value_source == ValueSource.STATIC: return bv * cm
	# Save parent state
	var os = value_source; var od = value_source_data
	var o_stat = value_source_stat; var o_sid = value_source_status_id; var o_def = value_source_defense
	# Swap to sub-effect's config
	value_source = sub.value_source as ValueSource
	value_source_data = sub.effect_data
	# Prefer sub-effect's typed exports, fall back to effect_data dict
	value_source_stat = sub.value_source_stat if sub.value_source_stat != "" \
		else sub.effect_data.get("value_source_stat", "strength")
	value_source_status_id = sub.value_source_status_id if sub.value_source_status_id != "" \
		else sub.effect_data.get("value_source_status_id", "")
	value_source_defense = sub.value_source_defense if sub.value_source_defense != "" \
		else sub.effect_data.get("value_source_defense", "armor")
	var r = _resolve_value(int(bv), ctx, cm)
	# Restore parent state
	value_source = os; value_source_data = od
	value_source_stat = o_stat; value_source_status_id = o_sid; value_source_defense = o_def
	return float(r)


# ============================================================================
# CONTEXT
# ============================================================================

func _ensure_context(p: Dictionary, source, te, dv: Array) -> Dictionary:
	var c = p.duplicate()
	if not c.has("source"): c["source"] = source
	if not c.has("target"): c["target"] = te
	if not c.has("dice_values"): c["dice_values"] = dv
	if not c.has("dice_total"):
		var t = 0
		for v in dv: t += int(v)
		c["dice_total"] = t
	if not c.has("dice_count"): c["dice_count"] = dv.size()
	# --- Source HP (percent + raw) ---
	if source:
		if not c.has("source_hp_percent"):
			if source.has_method("get_hp_percent"): c["source_hp_percent"] = source.get_hp_percent()
			elif "current_health" in source and "max_health" in source: c["source_hp_percent"] = float(source.current_health) / maxf(float(source.max_health), 1.0)
			else: c["source_hp_percent"] = 1.0
		if not c.has("source_current_hp"):
			c["source_current_hp"] = source.current_health if "current_health" in source else 0
		if not c.has("source_max_hp"):
			c["source_max_hp"] = source.max_health if "max_health" in source else 0
	# --- Target HP (percent + raw) ---
	if te:
		if not c.has("target_hp_percent"):
			if te.has_method("get_hp_percent"): c["target_hp_percent"] = te.get_hp_percent()
			elif "current_health" in te and "max_health" in te: c["target_hp_percent"] = float(te.current_health) / maxf(float(te.max_health), 1.0)
			else: c["target_hp_percent"] = 1.0
		if not c.has("target_current_hp"):
			c["target_current_hp"] = te.current_health if "current_health" in te else 0
		if not c.has("target_max_hp"):
			c["target_max_hp"] = te.max_health if "max_health" in te else 0
	elif not c.has("target_hp_percent"): c["target_hp_percent"] = -1.0
	# --- Status trackers ---
	if not c.has("source_tracker") and source: c["source_tracker"] = source.get_node("StatusTracker") if source.has_node("StatusTracker") else null
	if not c.has("target_tracker") and te: c["target_tracker"] = te.get_node("StatusTracker") if te.has_node("StatusTracker") else null
	elif not c.has("target_tracker"): c["target_tracker"] = null
	# --- Combat state ---
	if not c.has("turn_number"): c["turn_number"] = 1
	if not c.has("current_mana"): c["current_mana"] = 0
	if not c.has("max_mana"): c["max_mana"] = 0
	# Defaults for new combat-state sources (callers inject real values)
	if not c.has("alive_enemies"): c["alive_enemies"] = 0
	if not c.has("alive_companions"): c["alive_companions"] = 0
	# trigger_damage is only injected by companion trigger processor
	return c


func has_condition() -> bool: return condition != null and condition.condition_type != ActionEffectCondition.ConditionType.NONE
func is_compound() -> bool: return sub_effects.size() > 0

# ============================================================================
# DAMAGE / HEAL CORE
# ============================================================================

func _calculate_damage(dv: Array, rb: int = -1) -> Dictionary:
	return _calculate_damage_custom(dv, rb if rb >= 0 else base_damage, damage_multiplier, dice_count)

func _calculate_damage_custom(dv: Array, base: int, mult: float, dc: int) -> Dictionary:
	var dt = 0; var du = mini(dc, dv.size())
	for i in range(du): dt += dv[i]
	return {"damage": int((dt + base) * mult), "damage_type": damage_type, "dice_used": du, "dice_total": dt, "base_damage": base, "multiplier": mult}

func _calculate_heal(dv: Array, rb: int = -1) -> Dictionary:
	return _calculate_heal_custom(dv, rb if rb >= 0 else base_heal, heal_multiplier, heal_uses_dice, dice_count)

func _calculate_heal_custom(dv: Array, base: int, mult: float, ud: bool, dc: int) -> Dictionary:
	var dt = 0
	if ud:
		var du = mini(dc, dv.size())
		for i in range(du): dt += dv[i]
	return {"heal": int((dt + base) * mult), "dice_total": dt, "base_heal": base, "multiplier": mult}

func _add_status_result() -> Dictionary: return {"status_affix": status_affix, "stacks_to_add": stack_count}
func _remove_status_result() -> Dictionary: return {"status_affix": status_affix, "stacks_to_remove": stack_count, "remove_all": stack_count == 0}
func _cleanse_result() -> Dictionary: return {"cleanse_tags": cleanse_tags, "cleanse_max_removals": cleanse_max_removals}

# ============================================================================
# DISPLAY
# ============================================================================

func get_target_type_name() -> String:
	return ["Self", "Single Enemy", "All Enemies", "Single Ally", "All Allies"][target] if target < 5 else "Unknown"

func get_effect_type_name() -> String:
	var names = ["Damage", "Heal", "Add Status", "Remove Status", "Cleanse",
		"Shield", "Armor Buff", "Damage Reduction", "Reflect",
		"Lifesteal", "Execute", "Combo Mark", "Echo",
		"Splash", "Chain", "Random Strikes",
		"Mana Manipulate", "Modify Cooldown", "Refund Charges", "Grant Temp Action",
		"Channel", "Counter Setup", "Summon Companion"]
	return names[effect_type] if effect_type < names.size() else "Unknown"

func get_damage_type_name() -> String:
	return ["Slashing", "Blunt", "Piercing", "Fire", "Ice", "Shock", "Poison", "Shadow"][damage_type] if damage_type < 8 else "Unknown"

func get_summary() -> String:
	var parts: Array[String] = []
	if has_condition(): parts.append("{%s}" % condition.get_description())
	parts.append("[%s]" % get_target_type_name())
	var vsn = " (scales: %s)" % ValueSource.keys()[value_source] if value_source != ValueSource.STATIC else ""
	if is_compound():
		var sn: Array[String] = []
		for sub in sub_effects:
			if sub: sn.append(sub.get_summary())
		parts.append("Compound: %s" % ", ".join(sn))
	else:
		match effect_type:
			EffectType.DAMAGE:
				var ds = "%dD" % dice_count if dice_count > 0 else ""
				if base_damage > 0: ds += "+%d" % base_damage if ds else str(base_damage)
				if damage_multiplier != 1.0: ds += " x%.1f" % damage_multiplier
				parts.append("%s %s damage%s" % [ds, get_damage_type_name(), vsn])
			EffectType.HEAL:
				var hs = "%dD" % dice_count if heal_uses_dice else ""
				if base_heal > 0: hs += "+%d" % base_heal if hs else str(base_heal)
				parts.append("Heal %s%s" % [hs, vsn])
			EffectType.ADD_STATUS: parts.append("Apply %d %s" % [stack_count, status_affix.affix_name if status_affix else "None"])
			EffectType.REMOVE_STATUS: parts.append("Remove %s %s" % ["all" if stack_count == 0 else str(stack_count), status_affix.affix_name if status_affix else "None"])
			EffectType.CLEANSE: parts.append("Cleanse [%s]" % (", ".join(cleanse_tags) if cleanse_tags.size() > 0 else "none"))
			EffectType.SHIELD: parts.append("Shield %s%s" % ["%dD+%d" % [dice_count, shield_amount] if shield_uses_dice else str(shield_amount), vsn])
			EffectType.ARMOR_BUFF: parts.append("+%d armor %dt%s" % [armor_buff_amount, armor_buff_duration, vsn])
			EffectType.DAMAGE_REDUCTION: parts.append("-%d%% dmg %dt" % [int(reduction_amount * 100), reduction_duration] if reduction_is_percent else "Block %d %dt" % [int(reduction_amount), reduction_duration])
			EffectType.REFLECT: parts.append("Reflect %d%% %dt" % [int(reflect_percent * 100), reflect_duration])
			EffectType.LIFESTEAL: parts.append("Lifesteal %d%%%s" % [int(lifesteal_percent * 100), " (+dmg)" if lifesteal_deals_damage else ""])
			EffectType.EXECUTE: parts.append("Execute <%d%%: +%d%%%s" % [int(execute_threshold * 100), int(execute_bonus * 100), " (kill)" if execute_instant_kill else ""])
			EffectType.COMBO_MARK: parts.append("Mark x%d (+%d/stack)" % [mark_stacks, mark_consume_bonus])
			EffectType.ECHO: parts.append("Echo x%d @%d (%.0f%%)" % [echo_count, echo_threshold, echo_multiplier * 100])
			EffectType.SPLASH: parts.append("Splash %d%%%s%s" % [int(splash_percent * 100), " (all)" if splash_all else " (adj)", vsn])
			EffectType.CHAIN: parts.append("Chain x%d (%.0f%%)%s" % [chain_count, chain_decay * 100, " (repeat)" if chain_can_repeat else ""])
			EffectType.RANDOM_STRIKES: parts.append("%dx%d strikes" % [strike_count, strike_damage if strike_damage > 0 else base_damage])
			EffectType.MANA_MANIPULATE: parts.append("Mana %s%d%s%s" % ["+" if mana_amount >= 0 else "", mana_amount, "+D" if mana_uses_dice else "", vsn])
			EffectType.MODIFY_COOLDOWN: parts.append("CD -%d (%s)" % [cooldown_reduction, cooldown_target_action_id if cooldown_target_action_id else "all"])
			EffectType.REFUND_CHARGES: parts.append("Refund +%d (%s)" % [charges_to_refund, refund_target_action_id if refund_target_action_id else "all"])
			EffectType.GRANT_TEMP_ACTION: parts.append("Grant '%s' %dt" % [granted_action.action_name if granted_action else "None", grant_duration])
			EffectType.CHANNEL: parts.append("Channel %dt (+%.0f%%/t) → %s" % [channel_max_turns, channel_growth_per_turn * 100, channel_release_effect.get_summary() if channel_release_effect else "none"])
			EffectType.COUNTER_SETUP: parts.append("Counter (x%d, >%d) → %s" % [counter_charges, counter_damage_threshold, counter_effect.get_summary() if counter_effect else "none"])
			EffectType.SUMMON_COMPANION:
				parts.append("Summon %s" % (companion_data.companion_name if companion_data else "None"))
	return " ".join(parts)


func _to_string() -> String:
	return "ActionEffect<%s: %s>" % [effect_name, get_summary()]


# ============================================================================
# INSPECTOR PROPERTY GATING
# ============================================================================
# Hides export groups irrelevant to the current effect_type,
# collapses value_source sub-fields when their parent enum doesn't match,
# and suppresses single-effect fields when the effect is compound.
# ============================================================================

func _validate_property(property: Dictionary) -> void:
	var pn: String = property.name

	# ── 1. VALUE SOURCE SUB-FIELD GATING ──────────────────────────────
	match pn:
		"value_source_stat":
			if value_source != ValueSource.SOURCE_STAT:
				property.usage = 0
			return
		"value_source_status_id":
			if value_source != ValueSource.TARGET_STATUS_STACKS:
				property.usage = 0
			return
		"value_source_defense":
			if value_source != ValueSource.SOURCE_DEFENSE_STAT:
				property.usage = 0
			return
		"value_source_data":
			# Deprecated dict — always hide
			property.usage = 0
			return

	# ── 2. COMPOUND MODE ─────────────────────────────────────────────
	# When sub_effects is populated, execution routes through them.
	# Keep shared fields visible; hide single-effect config.
	var _compound_always_show := [
		"effect_name", "target", "effect_type", "condition",
		"value_source", "value_source_stat", "value_source_status_id",
		"value_source_defense", "sub_effects", "effect_data",
		"dice_count", "damage_type", "damage_multiplier",
	]
	if sub_effects.size() > 0 and pn not in _compound_always_show:
		if _is_type_specific_property(pn):
			property.usage = 0
			return

	# ── 3. EFFECT-TYPE GATING ────────────────────────────────────────
	var et := effect_type

	# --- Damage group ---
	if pn == "base_damage":
		if et not in [
			EffectType.DAMAGE, EffectType.SPLASH, EffectType.CHAIN,
			EffectType.LIFESTEAL, EffectType.EXECUTE,
			EffectType.COMBO_MARK, EffectType.ECHO,
			EffectType.RANDOM_STRIKES,
		]:
			property.usage = 0
		return
	if pn == "damage_type":
		if et not in [
			EffectType.DAMAGE, EffectType.SPLASH, EffectType.CHAIN,
			EffectType.RANDOM_STRIKES, EffectType.LIFESTEAL,
			EffectType.EXECUTE, EffectType.ECHO,
		]:
			property.usage = 0
		return
	if pn == "damage_multiplier":
		if et not in [
			EffectType.DAMAGE, EffectType.SPLASH, EffectType.CHAIN,
			EffectType.LIFESTEAL, EffectType.EXECUTE, EffectType.ECHO,
		]:
			property.usage = 0
		return
	if pn == "dice_count":
		if et not in [
			EffectType.DAMAGE, EffectType.HEAL, EffectType.SHIELD,
			EffectType.ARMOR_BUFF, EffectType.SPLASH, EffectType.CHAIN,
			EffectType.RANDOM_STRIKES, EffectType.MANA_MANIPULATE,
			EffectType.LIFESTEAL, EffectType.EXECUTE, EffectType.ECHO,
			EffectType.DAMAGE_REDUCTION,
		]:
			property.usage = 0
		return

	# --- Heal group ---
	if pn in ["base_heal", "heal_multiplier", "heal_uses_dice"]:
		if et != EffectType.HEAL:
			property.usage = 0
		return

	# --- Status group ---
	if pn in ["status_affix", "stack_count"]:
		if et not in [EffectType.ADD_STATUS, EffectType.REMOVE_STATUS]:
			property.usage = 0
		return

	# --- Cleanse group ---
	if pn in ["cleanse_tags", "cleanse_max_removals"]:
		if et != EffectType.CLEANSE:
			property.usage = 0
		return

	# --- Shield group ---
	if pn in ["shield_amount", "shield_uses_dice", "shield_multiplier", "shield_duration"]:
		if et != EffectType.SHIELD:
			property.usage = 0
		return

	# --- Armor Buff group ---
	if pn in ["armor_buff_amount", "armor_buff_uses_dice", "armor_buff_duration"]:
		if et != EffectType.ARMOR_BUFF:
			property.usage = 0
		return

	# --- Damage Reduction group ---
	if pn in ["reduction_amount", "reduction_uses_dice", "reduction_is_percent",
			"reduction_duration", "reduction_single_use"]:
		if et != EffectType.DAMAGE_REDUCTION:
			property.usage = 0
		return

	# --- Reflect group ---
	if pn in ["reflect_percent", "reflect_duration", "reflect_element"]:
		if et != EffectType.REFLECT:
			property.usage = 0
		return

	# --- Lifesteal group ---
	if pn in ["lifesteal_percent", "lifesteal_deals_damage"]:
		if et != EffectType.LIFESTEAL:
			property.usage = 0
		return

	# --- Execute group ---
	if pn in ["execute_threshold", "execute_bonus", "execute_instant_kill"]:
		if et != EffectType.EXECUTE:
			property.usage = 0
		return

	# --- Combo Mark group ---
	if pn in ["mark_status", "mark_stacks", "mark_consume_bonus", "mark_deals_damage"]:
		if et != EffectType.COMBO_MARK:
			property.usage = 0
		return

	# --- Echo group ---
	if pn in ["echo_threshold", "echo_count", "echo_multiplier", "echo_effect_type"]:
		if et != EffectType.ECHO:
			property.usage = 0
		return

	# --- Splash group ---
	if pn in ["splash_percent", "splash_all"]:
		if et != EffectType.SPLASH:
			property.usage = 0
		return

	# --- Chain group ---
	if pn in ["chain_count", "chain_decay", "chain_can_repeat"]:
		if et != EffectType.CHAIN:
			property.usage = 0
		return

	# --- Random Strikes group ---
	if pn in ["strike_count", "strike_damage", "strikes_use_dice", "strike_multiplier"]:
		if et != EffectType.RANDOM_STRIKES:
			property.usage = 0
		return

	# --- Mana group ---
	if pn in ["mana_amount", "mana_uses_dice"]:
		if et != EffectType.MANA_MANIPULATE:
			property.usage = 0
		return

	# --- Cooldown group ---
	if pn in ["cooldown_reduction", "cooldown_target_action_id"]:
		if et != EffectType.MODIFY_COOLDOWN:
			property.usage = 0
		return

	# --- Charge Refund group ---
	if pn in ["charges_to_refund", "refund_target_action_id"]:
		if et != EffectType.REFUND_CHARGES:
			property.usage = 0
		return

	# --- Grant Action group ---
	if pn in ["granted_action", "grant_duration"]:
		if et != EffectType.GRANT_TEMP_ACTION:
			property.usage = 0
		return

	# --- Channel group ---
	if pn in ["channel_max_turns", "channel_growth_per_turn", "channel_release_effect"]:
		if et != EffectType.CHANNEL:
			property.usage = 0
		return

	# --- Counter group ---
	if pn in ["counter_effect", "counter_charges", "counter_damage_threshold"]:
		if et != EffectType.COUNTER_SETUP:
			property.usage = 0
		return

	# --- Summon group ---
	if pn == "companion_data":
		if et != EffectType.SUMMON_COMPANION:
			property.usage = 0
		return


func _is_type_specific_property(pn: String) -> bool:
	return pn in [
		"base_damage", "damage_multiplier",
		"base_heal", "heal_multiplier", "heal_uses_dice",
		"status_affix", "stack_count",
		"cleanse_tags", "cleanse_max_removals",
		"shield_amount", "shield_uses_dice", "shield_multiplier", "shield_duration",
		"armor_buff_amount", "armor_buff_uses_dice", "armor_buff_duration",
		"reduction_amount", "reduction_uses_dice", "reduction_is_percent",
		"reduction_duration", "reduction_single_use",
		"reflect_percent", "reflect_duration", "reflect_element",
		"lifesteal_percent", "lifesteal_deals_damage",
		"execute_threshold", "execute_bonus", "execute_instant_kill",
		"mark_status", "mark_stacks", "mark_consume_bonus", "mark_deals_damage",
		"echo_threshold", "echo_count", "echo_multiplier", "echo_effect_type",
		"splash_percent", "splash_all",
		"chain_count", "chain_decay", "chain_can_repeat",
		"strike_count", "strike_damage", "strikes_use_dice", "strike_multiplier",
		"mana_amount", "mana_uses_dice",
		"cooldown_reduction", "cooldown_target_action_id",
		"charges_to_refund", "refund_target_action_id",
		"granted_action", "grant_duration",
		"channel_max_turns", "channel_growth_per_turn", "channel_release_effect",
		"counter_effect", "counter_charges", "counter_damage_threshold",
		"companion_data",
	]
