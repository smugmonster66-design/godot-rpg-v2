# res://resources/data/proc_effect_config.gd
# Inspector-friendly configuration for proc effects.
# Replaces free-form effect_data dictionaries with enum-driven dropdowns.
#
# Attach to an Affix via its "proc_config" export slot.
# The AffixProcProcessor reads this FIRST, falling back to effect_data
# for backward compatibility with legacy .tres files.
#
# USAGE (Inspector):
#   1. Set effect_type from dropdown
#   2. Fill in the relevant parameter group
#   3. Optionally set a proc_condition
#   4. The processor handles the rest
#
# USAGE (Code):
#   var config = ProcEffectConfig.new()
#   config.effect_type = ProcEffectConfig.EffectType.MANA_RESTORE
#   config.amount = 5
#
extends Resource
class_name ProcEffectConfig

# ============================================================================
# EFFECT TYPE — What happens when this proc fires
# ============================================================================
enum EffectType {
	NONE,                      ## Not configured

	# ── Healing ──
	HEAL_FLAT,                 ## Heal a flat amount. Uses: amount
	HEAL_PERCENT_DAMAGE,       ## Heal % of damage dealt. Uses: percent
	HEAL_PERCENT_MAX_HP,       ## Heal % of max HP. Uses: percent

	# ── Bonus Damage ──
	BONUS_DAMAGE_FLAT,         ## Deal flat bonus damage. Uses: amount
	BONUS_DAMAGE_PERCENT,      ## Deal % of damage dealt as bonus. Uses: percent

	# ── Defense ──
	GAIN_ARMOR,                ## Gain flat armor. Uses: amount
	GAIN_BARRIER,              ## Gain flat barrier. Uses: amount

	# ── Status Effects ──
	APPLY_STATUS,              ## Apply a status to a target. Uses: status_affix, stacks, target
	SPREAD_STATUS,             ## Spread stacks of a status to other targets. Uses: status_affix, stacks, target, threshold

	# ── Mana ──
	MANA_RESTORE,              ## Restore flat mana. Uses: amount
	MANA_RESTORE_PERCENT,      ## Restore % of max mana. Uses: percent

	# ── Buffs / Grants ──
	STACKING_BUFF,             ## Gain stacking buff per trigger. Uses: buff_category, max_stacks
	TEMP_AFFIX,                ## Grant a temporary Affix. Uses: temp_affix_resource, duration
	TEMP_DICE_AFFIX,           ## Grant a temporary DiceAffix. Uses: temp_dice_affix_resource, duration
	GRANT_ACTION,              ## Grant a temporary Action. Uses: granted_action_resource, duration

	# ── Dice ──
	RETRIGGER_DICE_AFFIXES,    ## Re-fire dice affixes. Uses: trigger_to_replay

	# ── Storm-Specific ──
	STATIC_DEATH_DISCHARGE,    ## On kill: deal remaining Static as shock + spread half. Uses: damage_per_stack, spread_fraction, target

	# ── Advanced ──
	COMPOUND,                  ## Multiple sub-effects. Uses: compound_sub_effects
	CUSTOM,                    ## Escape hatch for unique mechanics. Uses: custom_id, custom_data
}

# ============================================================================
# TARGET — Who does the effect apply to
# ============================================================================
enum TargetType {
	DEFAULT,             ## Use the effect type's natural default
	ENEMY,               ## The current combat target
	SELF,                ## The player
	RANDOM_ENEMY,        ## A random living enemy
	ALL_ENEMIES,         ## Every living enemy
	ALL_OTHER_ENEMIES,   ## Every enemy except the current target
	ALL_ALLIES,          ## All player-side combatants
}

# ============================================================================
# ELEMENT — For element-gated procs (e.g. "only on shock kill")
# ============================================================================
enum ElementFilter {
	ANY,       ## No element restriction
	FIRE,
	ICE,
	SHOCK,
	POISON,
	SHADOW,
	SLASHING,
	BLUNT,
	PIERCING,
}

# ============================================================================
# BUFF CATEGORY — For STACKING_BUFF effect type
# ============================================================================
enum BuffCategory {
	DAMAGE_BONUS,
	DAMAGE_MULTIPLIER,
	DEFENSE_BONUS,
	ARMOR_BONUS,
	BARRIER_BONUS,
	STRENGTH_BONUS,
	AGILITY_BONUS,
	INTELLECT_BONUS,
	LUCK_BONUS,
}

# ============================================================================
# DICE AFFIX TRIGGER — For RETRIGGER_DICE_AFFIXES
# ============================================================================
enum DiceAffixTrigger {
	ON_ROLL,
	ON_USE,
	ON_REORDER,
	ON_COMBAT_START,
}

# ============================================================================
# PRIMARY CONFIGURATION
# ============================================================================

@export var effect_type: EffectType = EffectType.NONE

# ============================================================================
# VALUE PARAMETERS — Used by most effect types
# ============================================================================
@export_group("Values")

## Flat amount for HEAL_FLAT, BONUS_DAMAGE_FLAT, GAIN_ARMOR, GAIN_BARRIER,
## MANA_RESTORE, STACKING_BUFF (value per stack)
@export var amount: float = 0.0

## Percentage (0.0-1.0) for HEAL_PERCENT_DAMAGE, HEAL_PERCENT_MAX_HP,
## BONUS_DAMAGE_PERCENT, MANA_RESTORE_PERCENT
@export var percent: float = 0.0

# ============================================================================
# TARGETING
# ============================================================================
@export_group("Targeting")

## Who receives the effect. DEFAULT uses the natural target for the effect type.
@export var target: TargetType = TargetType.DEFAULT

# ============================================================================
# STATUS PARAMETERS — For APPLY_STATUS, SPREAD_STATUS
# ============================================================================
@export_group("Status Effect")

## The StatusAffix resource to apply. Drag from the inspector.
@export var status_affix: Resource = null  # StatusAffix

## How many stacks to apply.
@export var stacks: int = 1

## For SPREAD_STATUS: minimum stacks on the original target before spreading.
@export var spread_threshold: int = 0

## For STATIC_DEATH_DISCHARGE: fraction of stacks to spread (0.0-1.0).
@export var spread_fraction: float = 0.5

## For STATIC_DEATH_DISCHARGE: damage dealt per stack on the dying target.
@export var damage_per_stack: float = 1.0

# ============================================================================
# BUFF PARAMETERS — For STACKING_BUFF
# ============================================================================
@export_group("Stacking Buff")

## Which stat category the stacking buff modifies.
@export var buff_category: BuffCategory = BuffCategory.DAMAGE_BONUS

## Maximum number of stacks this buff can accumulate.
@export var max_stacks: int = 99

# ============================================================================
# GRANT PARAMETERS — For TEMP_AFFIX, TEMP_DICE_AFFIX, GRANT_ACTION
# ============================================================================
@export_group("Grants")

## Temporary Affix to register. Used by TEMP_AFFIX.
@export var temp_affix_resource: Resource = null  # Affix

## Temporary DiceAffix to apply. Used by TEMP_DICE_AFFIX.
@export var temp_dice_affix_resource: Resource = null  # DiceAffix

## Action to grant temporarily. Used by GRANT_ACTION.
@export var granted_action_resource: Resource = null  # Action

## How many turns the grant lasts.
@export var duration: int = 1

# ============================================================================
# DICE PARAMETERS — For RETRIGGER_DICE_AFFIXES
# ============================================================================
@export_group("Dice")

## Which dice affix trigger to replay.
@export var trigger_to_replay: DiceAffixTrigger = DiceAffixTrigger.ON_USE

# ============================================================================
# CONDITION PARAMETERS — Optional filter for when the proc fires
# ============================================================================
@export_group("Proc Conditions")

## Element the damage/kill must be to activate. ANY = no restriction.
@export var element_filter: ElementFilter = ElementFilter.ANY

## If set, the target must have this status for the proc to fire.
@export var target_must_have_status: Resource = null  # StatusAffix

## Minimum damage threshold for damage-gated procs.
@export var damage_threshold: float = 0.0

## Health percent gate: proc only fires if player HP is below this (0 = disabled).
@export_range(0.0, 1.0) var health_below_percent: float = 0.0

## Health percent gate: proc only fires if player HP is above this (0 = disabled).
@export_range(0.0, 1.0) var health_above_percent: float = 0.0

## Turn number gate: proc only fires after this turn (0 = disabled).
@export var after_turn: int = 0

# ============================================================================
# CUSTOM ESCAPE HATCH
# ============================================================================
@export_group("Custom")

## Identifier for CUSTOM effect type. Dispatched by the proc processor.
@export var custom_id: String = ""

## Free-form data for CUSTOM effects.
@export var custom_data: Dictionary = {}

# ============================================================================
# COMPOUND SUB-EFFECTS
# ============================================================================
@export_group("Compound")

## Array of ProcEffectConfig sub-resources for COMPOUND effects.
## Each is processed independently when the proc fires.
@export var compound_sub_effects: Array[Resource] = []  # Array[ProcEffectConfig]


# ============================================================================
# HELPER — Convert enums to strings for processor / combat_manager
# ============================================================================

func get_target_string() -> String:
	"""Get the target as a string for combat resolution."""
	match target:
		TargetType.DEFAULT: return ""
		TargetType.ENEMY: return "enemy"
		TargetType.SELF: return "self"
		TargetType.RANDOM_ENEMY: return "random_enemy"
		TargetType.ALL_ENEMIES: return "all_enemies"
		TargetType.ALL_OTHER_ENEMIES: return "all_other_enemies"
		TargetType.ALL_ALLIES: return "all_allies"
		_: return "enemy"

func get_element_filter_string() -> String:
	"""Get element filter as uppercase string (matches ActionEffect.DamageType names)."""
	match element_filter:
		ElementFilter.ANY: return ""
		_: return ElementFilter.keys()[element_filter]

func get_buff_category_string() -> String:
	"""Get buff category as Affix.Category enum name."""
	return BuffCategory.keys()[buff_category]

func get_trigger_to_replay_string() -> String:
	"""Get dice affix trigger as string."""
	return DiceAffixTrigger.keys()[trigger_to_replay]

func get_effect_type_name() -> String:
	"""Human-readable effect type for tooltips/debugging."""
	return EffectType.keys()[effect_type].replace("_", " ").to_lower().capitalize()


# ============================================================================
# BACKWARD COMPAT — Generate legacy effect_data dict
# ============================================================================

func to_effect_data() -> Dictionary:
	"""Convert this config to a legacy effect_data dictionary.
	Used for backward compatibility with systems that still read effect_data."""
	var data: Dictionary = {}

	match effect_type:
		EffectType.HEAL_FLAT:
			data["proc_effect"] = "heal_flat"
		EffectType.HEAL_PERCENT_DAMAGE:
			data["proc_effect"] = "heal_percent_damage"
		EffectType.HEAL_PERCENT_MAX_HP:
			data["proc_effect"] = "heal_percent_max_hp"
		EffectType.BONUS_DAMAGE_FLAT:
			data["proc_effect"] = "bonus_damage_flat"
		EffectType.BONUS_DAMAGE_PERCENT:
			data["proc_effect"] = "bonus_damage_percent"
		EffectType.GAIN_ARMOR:
			data["proc_effect"] = "gain_armor"
		EffectType.GAIN_BARRIER:
			data["proc_effect"] = "gain_barrier"
		EffectType.APPLY_STATUS:
			data["proc_effect"] = "apply_status"
			if status_affix:
				data["status"] = status_affix
			data["status_stacks"] = stacks
			data["status_target"] = get_target_string()
		EffectType.SPREAD_STATUS:
			data["proc_effect"] = "spread_status"
			if status_affix:
				data["status"] = status_affix
			data["stacks"] = stacks
			data["threshold"] = spread_threshold
			data["target"] = get_target_string()
		EffectType.MANA_RESTORE:
			data["proc_effect"] = "mana_restore"
			data["amount"] = int(amount)
		EffectType.MANA_RESTORE_PERCENT:
			data["proc_effect"] = "mana_restore_percent"
			data["percent"] = percent
		EffectType.STACKING_BUFF:
			data["proc_effect"] = "stacking_buff"
			data["buff_category"] = get_buff_category_string()
			data["max_stacks"] = max_stacks
		EffectType.TEMP_AFFIX:
			data["proc_effect"] = "temp_affix"
			if temp_affix_resource:
				data["temp_affix"] = temp_affix_resource
			data["duration"] = duration
		EffectType.TEMP_DICE_AFFIX:
			data["proc_effect"] = "grant_temp_dice_affix"
			if temp_dice_affix_resource:
				data["dice_affix"] = temp_dice_affix_resource
			data["duration"] = duration
		EffectType.GRANT_ACTION:
			data["proc_effect"] = "grant_action"
			data["duration"] = duration
		EffectType.RETRIGGER_DICE_AFFIXES:
			data["proc_effect"] = "retrigger_dice_affixes"
			data["trigger_to_replay"] = get_trigger_to_replay_string()
		EffectType.STATIC_DEATH_DISCHARGE:
			data["proc_effect"] = "static_death_discharge"
			data["damage_per_stack"] = damage_per_stack
			data["spread_fraction"] = spread_fraction
			data["target"] = get_target_string()
		EffectType.COMPOUND:
			data["proc_effect"] = "compound"
		EffectType.CUSTOM:
			data["proc_effect"] = "custom"
			data["custom_id"] = custom_id
			data["custom_data"] = custom_data

	# Attach condition data
	var elem = get_element_filter_string()
	if elem != "":
		data["element_condition"] = elem

	return data


# ============================================================================
# VALIDATION — Catch misconfiguration in the editor
# ============================================================================

func validate() -> Array[String]:
	"""Return a list of configuration warnings. Empty = valid."""
	var warnings: Array[String] = []

	if effect_type == EffectType.NONE:
		warnings.append("Effect type is NONE — proc will do nothing.")

	match effect_type:
		EffectType.HEAL_FLAT, EffectType.BONUS_DAMAGE_FLAT, \
		EffectType.GAIN_ARMOR, EffectType.GAIN_BARRIER, \
		EffectType.MANA_RESTORE:
			if amount <= 0.0:
				warnings.append("'amount' is zero — effect will have no value.")

		EffectType.HEAL_PERCENT_DAMAGE, EffectType.HEAL_PERCENT_MAX_HP, \
		EffectType.BONUS_DAMAGE_PERCENT, EffectType.MANA_RESTORE_PERCENT:
			if percent <= 0.0:
				warnings.append("'percent' is zero — effect will have no value.")

		EffectType.APPLY_STATUS, EffectType.SPREAD_STATUS:
			if not status_affix:
				warnings.append("No status_affix set — cannot apply status.")
			if stacks <= 0:
				warnings.append("Stacks is zero — no stacks will be applied.")

		EffectType.STACKING_BUFF:
			if max_stacks <= 0:
				warnings.append("max_stacks is zero — buff will never stack.")

		EffectType.TEMP_AFFIX:
			if not temp_affix_resource:
				warnings.append("No temp_affix_resource set.")

		EffectType.TEMP_DICE_AFFIX:
			if not temp_dice_affix_resource:
				warnings.append("No temp_dice_affix_resource set.")

		EffectType.GRANT_ACTION:
			if not granted_action_resource:
				warnings.append("No granted_action_resource set.")

		EffectType.CUSTOM:
			if custom_id.is_empty():
				warnings.append("Custom effect has no custom_id.")

	return warnings


func _to_string() -> String:
	return "ProcEffectConfig<%s>" % EffectType.keys()[effect_type]
