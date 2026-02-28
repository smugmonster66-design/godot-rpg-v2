# res://scripts/resources/action_effect_slot.gd
# Inline wrapper that pairs a shared base ActionEffect template with
# per-action value overrides. The base .tres defines WHAT (effect type,
# element for damage, status for apply). The slot defines HOW MUCH
# (damage values, stack counts, durations, etc.).
#
# At execution time, build_configured_effect() duplicates the base
# template and writes all slot overrides onto the clone. The base
# resource is never mutated.
#
# _validate_property() hides all fields irrelevant to the linked
# effect's type, so the inspector only shows what matters.
extends Resource
class_name ActionEffectSlot

# ============================================================================
# BASE TEMPLATE
# ============================================================================

## The shared ActionEffect template (e.g. damage_fire.tres, apply_burn.tres).
## Defines effect_type, damage_type (for damage), status_affix (for statuses).
@export var effect: ActionEffect = null

# ============================================================================
# TARGET OVERRIDE
# ============================================================================

## If true, use this slot's target instead of the base effect's default.
@export var override_target: bool = false

## Target override — only visible when override_target is true.
@export var target: ActionEffect.TargetType = ActionEffect.TargetType.SINGLE_ENEMY

# ============================================================================
# CONDITION (optional, per-action gating)
# ============================================================================
@export_group("Condition")
@export var condition: ActionEffectCondition = null

# ============================================================================
# VALUE SOURCE
# ============================================================================
@export_group("Value Source")

## How the base value scales. Most damage effects use DICE_TOTAL.
@export var value_source: ActionEffect.ValueSource = ActionEffect.ValueSource.STATIC

## SOURCE_STAT: which primary stat to scale from.
@export_enum("strength", "agility", "intellect", "luck")
var value_source_stat: String = "strength"

## TARGET_STATUS_STACKS: which status to count stacks of.
@export var value_source_status_id: String = ""

## SOURCE_DEFENSE_STAT: which defense stat to scale from.
@export_enum("armor", "barrier")
var value_source_defense: String = "armor"

# ============================================================================
# DAMAGE SETTINGS
# ============================================================================
@export_group("Damage Settings")
@export var base_damage: int = 0
@export var damage_multiplier: float = 1.0
@export var dice_count: int = 1

# ============================================================================
# HEAL SETTINGS
# ============================================================================
@export_group("Heal Settings")
@export var base_heal: int = 0
@export var heal_multiplier: float = 1.0
@export var heal_uses_dice: bool = false

# ============================================================================
# STATUS SETTINGS
# ============================================================================
@export_group("Status Settings")
@export var stack_count: int = 1

## Override which status to target (for remove_status.tres / cleanse).
## Leave null to use the base effect's status_affix.
@export var status_override: StatusAffix = null

# ============================================================================
# CLEANSE SETTINGS
# ============================================================================
@export_group("Cleanse Settings")
@export var cleanse_tags: Array[String] = []
@export var cleanse_max_removals: int = 0

# ============================================================================
# SHIELD SETTINGS
# ============================================================================
@export_group("Shield Settings")
@export var shield_amount: int = 0
@export var shield_uses_dice: bool = true
@export var shield_multiplier: float = 1.0
@export var shield_duration: int = -1

# ============================================================================
# ARMOR BUFF SETTINGS
# ============================================================================
@export_group("Armor Buff Settings")
@export var armor_buff_amount: int = 0
@export var armor_buff_uses_dice: bool = false
@export var armor_buff_duration: int = 2

# ============================================================================
# DAMAGE REDUCTION SETTINGS
# ============================================================================
@export_group("Damage Reduction Settings")
@export var reduction_amount: float = 0.0
@export var reduction_uses_dice: bool = false
@export var reduction_is_percent: bool = false
@export var reduction_duration: int = 1
@export var reduction_single_use: bool = false

# ============================================================================
# REFLECT SETTINGS
# ============================================================================
@export_group("Reflect Settings")
@export var reflect_percent: float = 0.3
@export var reflect_duration: int = 2
@export var reflect_element: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING

# ============================================================================
# LIFESTEAL SETTINGS
# ============================================================================
@export_group("Lifesteal Settings")
@export var lifesteal_percent: float = 0.3
@export var lifesteal_deals_damage: bool = true

# ============================================================================
# EXECUTE SETTINGS
# ============================================================================
@export_group("Execute Settings")
@export var execute_threshold: float = 0.3
@export var execute_bonus: float = 1.0
@export var execute_instant_kill: bool = false

# ============================================================================
# COMBO MARK SETTINGS
# ============================================================================
@export_group("Combo Mark Settings")
@export var mark_status: StatusAffix = null
@export var mark_stacks: int = 1
@export var mark_consume_bonus: int = 5
@export var mark_deals_damage: bool = false

# ============================================================================
# ECHO SETTINGS
# ============================================================================
@export_group("Echo Settings")
@export var echo_threshold: int = 10
@export var echo_count: int = 1
@export var echo_multiplier: float = 0.5
@export var echo_effect_type: int = -1

# ============================================================================
# SPLASH SETTINGS
# ============================================================================
@export_group("Splash Settings")
@export var splash_percent: float = 0.5
@export var splash_all: bool = false

# ============================================================================
# CHAIN SETTINGS
# ============================================================================
@export_group("Chain Settings")
@export var chain_count: int = 2
@export var chain_decay: float = 0.7
@export var chain_can_repeat: bool = false

# ============================================================================
# RANDOM STRIKES SETTINGS
# ============================================================================
@export_group("Random Strikes Settings")
@export var strike_count: int = 3
@export var strike_damage: int = 0
@export var strikes_use_dice: bool = false
@export var strike_multiplier: float = 1.0

# ============================================================================
# MANA SETTINGS
# ============================================================================
@export_group("Mana Settings")
@export var mana_amount: int = 0
@export var mana_uses_dice: bool = false

# ============================================================================
# COOLDOWN SETTINGS
# ============================================================================
@export_group("Cooldown Settings")
@export var cooldown_reduction: int = 1
@export var cooldown_target_action_id: String = ""

# ============================================================================
# CHARGE REFUND SETTINGS
# ============================================================================
@export_group("Charge Refund Settings")
@export var charges_to_refund: int = 1
@export var refund_target_action_id: String = ""

# ============================================================================
# GRANT ACTION SETTINGS
# ============================================================================
@export_group("Grant Action Settings")
@export var granted_action: Action = null
@export var grant_duration: int = 1

# ============================================================================
# CHANNEL SETTINGS
# ============================================================================
@export_group("Channel Settings")
@export var channel_max_turns: int = 3
@export var channel_growth_per_turn: float = 0.5
@export var channel_release_effect: ActionEffect = null

# ============================================================================
# COUNTER SETTINGS
# ============================================================================
@export_group("Counter Settings")
@export var counter_effect: ActionEffect = null
@export var counter_charges: int = 1
@export var counter_damage_threshold: int = 0

# ============================================================================
# SUMMON SETTINGS
# ============================================================================
@export_group("Summon Settings")
@export var companion_data: CompanionData = null


# ============================================================================
# BUILD CONFIGURED EFFECT
# ============================================================================

func build_configured_effect() -> ActionEffect:
	"""Duplicate the base template and apply all slot overrides.
	Returns a fully configured ActionEffect ready for execution.
	The base resource is never mutated."""
	if not effect:
		push_warning("ActionEffectSlot: no base effect assigned")
		return null

	var clone: ActionEffect = effect.duplicate(true)

	# ── Target ──
	if override_target:
		clone.target = target

	# ── Condition ──
	if condition:
		clone.condition = condition

	# ── Value Source ──
	clone.value_source = value_source
	clone.value_source_stat = value_source_stat
	clone.value_source_status_id = value_source_status_id
	clone.value_source_defense = value_source_defense

	# ── Type-specific overrides ──
	var et := effect.effect_type

	match et:
		ActionEffect.EffectType.DAMAGE:
			clone.base_damage = base_damage
			clone.damage_multiplier = damage_multiplier
			clone.dice_count = dice_count

		ActionEffect.EffectType.HEAL:
			clone.base_heal = base_heal
			clone.heal_multiplier = heal_multiplier
			clone.heal_uses_dice = heal_uses_dice
			clone.dice_count = dice_count

		ActionEffect.EffectType.ADD_STATUS:
			clone.stack_count = stack_count
			if status_override:
				clone.status_affix = status_override

		ActionEffect.EffectType.REMOVE_STATUS:
			clone.stack_count = stack_count
			if status_override:
				clone.status_affix = status_override

		ActionEffect.EffectType.CLEANSE:
			clone.cleanse_tags.assign(cleanse_tags)
			clone.cleanse_max_removals = cleanse_max_removals
			if status_override:
				clone.status_affix = status_override

		ActionEffect.EffectType.SHIELD:
			clone.shield_amount = shield_amount
			clone.shield_uses_dice = shield_uses_dice
			clone.shield_multiplier = shield_multiplier
			clone.shield_duration = shield_duration
			clone.dice_count = dice_count

		ActionEffect.EffectType.ARMOR_BUFF:
			clone.armor_buff_amount = armor_buff_amount
			clone.armor_buff_uses_dice = armor_buff_uses_dice
			clone.armor_buff_duration = armor_buff_duration
			clone.dice_count = dice_count

		ActionEffect.EffectType.DAMAGE_REDUCTION:
			clone.reduction_amount = reduction_amount
			clone.reduction_uses_dice = reduction_uses_dice
			clone.reduction_is_percent = reduction_is_percent
			clone.reduction_duration = reduction_duration
			clone.reduction_single_use = reduction_single_use
			clone.dice_count = dice_count

		ActionEffect.EffectType.REFLECT:
			clone.reflect_percent = reflect_percent
			clone.reflect_duration = reflect_duration
			clone.reflect_element = reflect_element

		ActionEffect.EffectType.LIFESTEAL:
			clone.lifesteal_percent = lifesteal_percent
			clone.lifesteal_deals_damage = lifesteal_deals_damage
			clone.base_damage = base_damage
			clone.damage_multiplier = damage_multiplier
			clone.dice_count = dice_count

		ActionEffect.EffectType.EXECUTE:
			clone.execute_threshold = execute_threshold
			clone.execute_bonus = execute_bonus
			clone.execute_instant_kill = execute_instant_kill
			clone.base_damage = base_damage
			clone.damage_multiplier = damage_multiplier
			clone.dice_count = dice_count

		ActionEffect.EffectType.COMBO_MARK:
			clone.mark_status = mark_status
			clone.mark_stacks = mark_stacks
			clone.mark_consume_bonus = mark_consume_bonus
			clone.mark_deals_damage = mark_deals_damage
			clone.base_damage = base_damage
			clone.damage_multiplier = damage_multiplier
			clone.dice_count = dice_count

		ActionEffect.EffectType.ECHO:
			clone.echo_threshold = echo_threshold
			clone.echo_count = echo_count
			clone.echo_multiplier = echo_multiplier
			clone.echo_effect_type = echo_effect_type
			clone.base_damage = base_damage
			clone.damage_multiplier = damage_multiplier
			clone.dice_count = dice_count

		ActionEffect.EffectType.SPLASH:
			clone.splash_percent = splash_percent
			clone.splash_all = splash_all
			clone.base_damage = base_damage
			clone.damage_multiplier = damage_multiplier
			clone.dice_count = dice_count

		ActionEffect.EffectType.CHAIN:
			clone.chain_count = chain_count
			clone.chain_decay = chain_decay
			clone.chain_can_repeat = chain_can_repeat
			clone.base_damage = base_damage
			clone.damage_multiplier = damage_multiplier
			clone.dice_count = dice_count

		ActionEffect.EffectType.RANDOM_STRIKES:
			clone.strike_count = strike_count
			clone.strike_damage = strike_damage
			clone.strikes_use_dice = strikes_use_dice
			clone.strike_multiplier = strike_multiplier
			clone.dice_count = dice_count

		ActionEffect.EffectType.MANA_MANIPULATE:
			clone.mana_amount = mana_amount
			clone.mana_uses_dice = mana_uses_dice
			clone.dice_count = dice_count

		ActionEffect.EffectType.MODIFY_COOLDOWN:
			clone.cooldown_reduction = cooldown_reduction
			clone.cooldown_target_action_id = cooldown_target_action_id

		ActionEffect.EffectType.REFUND_CHARGES:
			clone.charges_to_refund = charges_to_refund
			clone.refund_target_action_id = refund_target_action_id

		ActionEffect.EffectType.GRANT_TEMP_ACTION:
			clone.granted_action = granted_action
			clone.grant_duration = grant_duration

		ActionEffect.EffectType.CHANNEL:
			clone.channel_max_turns = channel_max_turns
			clone.channel_growth_per_turn = channel_growth_per_turn
			clone.channel_release_effect = channel_release_effect

		ActionEffect.EffectType.COUNTER_SETUP:
			clone.counter_effect = counter_effect
			clone.counter_charges = counter_charges
			clone.counter_damage_threshold = counter_damage_threshold

		ActionEffect.EffectType.SUMMON_COMPANION:
			clone.companion_data = companion_data

	return clone


# ============================================================================
# DISPLAY
# ============================================================================

func get_summary() -> String:
	"""Build a human-readable summary using the configured effect."""
	if not effect:
		return "(no effect)"
	var configured := build_configured_effect()
	if configured:
		return configured.get_summary()
	return effect.get_summary()


func _to_string() -> String:
	if not effect:
		return "ActionEffectSlot<empty>"
	return "Slot<%s>" % get_summary()


# ============================================================================
# INSPECTOR PROPERTY GATING
# ============================================================================

func _validate_property(property: Dictionary) -> void:
	var pn: String = property.name

	# ── Target override gating ──
	if pn == "target":
		if not override_target:
			property.usage = 0
		return

	# ── No base effect assigned — hide everything except effect + override_target ──
	if not effect:
		if pn not in ["effect", "override_target", "target"]:
			if _is_slot_value_property(pn):
				property.usage = 0
		return

	var et := effect.effect_type

	# ── Value Source sub-field gating ──
	match pn:
		"value_source_stat":
			if value_source != ActionEffect.ValueSource.SOURCE_STAT:
				property.usage = 0
			return
		"value_source_status_id":
			if value_source != ActionEffect.ValueSource.TARGET_STATUS_STACKS:
				property.usage = 0
			return
		"value_source_defense":
			if value_source != ActionEffect.ValueSource.SOURCE_DEFENSE_STAT:
				property.usage = 0
			return

	# ── Damage fields ──
	# base_damage, damage_multiplier visible for types that deal damage
	var _damage_types := [
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.EffectType.LIFESTEAL,
		ActionEffect.EffectType.EXECUTE,
		ActionEffect.EffectType.COMBO_MARK,
		ActionEffect.EffectType.ECHO,
		ActionEffect.EffectType.SPLASH,
		ActionEffect.EffectType.CHAIN,
	]
	if pn == "base_damage":
		if et not in _damage_types and et != ActionEffect.EffectType.RANDOM_STRIKES:
			property.usage = 0
		return
	if pn == "damage_multiplier":
		if et not in _damage_types:
			property.usage = 0
		return

	# dice_count visible for types that consume dice
	var _dice_types := [
		ActionEffect.EffectType.DAMAGE,
		ActionEffect.EffectType.HEAL,
		ActionEffect.EffectType.SHIELD,
		ActionEffect.EffectType.ARMOR_BUFF,
		ActionEffect.EffectType.DAMAGE_REDUCTION,
		ActionEffect.EffectType.MANA_MANIPULATE,
		ActionEffect.EffectType.LIFESTEAL,
		ActionEffect.EffectType.EXECUTE,
		ActionEffect.EffectType.ECHO,
		ActionEffect.EffectType.SPLASH,
		ActionEffect.EffectType.CHAIN,
		ActionEffect.EffectType.RANDOM_STRIKES,
	]
	if pn == "dice_count":
		if et not in _dice_types:
			property.usage = 0
		return

	# ── Heal ──
	if pn in ["base_heal", "heal_multiplier", "heal_uses_dice"]:
		if et != ActionEffect.EffectType.HEAL:
			property.usage = 0
		return

	# ── Status ──
	if pn == "stack_count":
		if et not in [ActionEffect.EffectType.ADD_STATUS, ActionEffect.EffectType.REMOVE_STATUS]:
			property.usage = 0
		return
	if pn == "status_override":
		if et not in [ActionEffect.EffectType.ADD_STATUS, ActionEffect.EffectType.REMOVE_STATUS, ActionEffect.EffectType.CLEANSE]:
			property.usage = 0
		return

	# ── Cleanse ──
	if pn in ["cleanse_tags", "cleanse_max_removals"]:
		if et != ActionEffect.EffectType.CLEANSE:
			property.usage = 0
		return

	# ── Shield ──
	if pn in ["shield_amount", "shield_uses_dice", "shield_multiplier", "shield_duration"]:
		if et != ActionEffect.EffectType.SHIELD:
			property.usage = 0
		return

	# ── Armor Buff ──
	if pn in ["armor_buff_amount", "armor_buff_uses_dice", "armor_buff_duration"]:
		if et != ActionEffect.EffectType.ARMOR_BUFF:
			property.usage = 0
		return

	# ── Damage Reduction ──
	if pn in ["reduction_amount", "reduction_uses_dice", "reduction_is_percent",
			"reduction_duration", "reduction_single_use"]:
		if et != ActionEffect.EffectType.DAMAGE_REDUCTION:
			property.usage = 0
		return

	# ── Reflect ──
	if pn in ["reflect_percent", "reflect_duration", "reflect_element"]:
		if et != ActionEffect.EffectType.REFLECT:
			property.usage = 0
		return

	# ── Lifesteal ──
	if pn in ["lifesteal_percent", "lifesteal_deals_damage"]:
		if et != ActionEffect.EffectType.LIFESTEAL:
			property.usage = 0
		return

	# ── Execute ──
	if pn in ["execute_threshold", "execute_bonus", "execute_instant_kill"]:
		if et != ActionEffect.EffectType.EXECUTE:
			property.usage = 0
		return

	# ── Combo Mark ──
	if pn in ["mark_status", "mark_stacks", "mark_consume_bonus", "mark_deals_damage"]:
		if et != ActionEffect.EffectType.COMBO_MARK:
			property.usage = 0
		return

	# ── Echo ──
	if pn in ["echo_threshold", "echo_count", "echo_multiplier", "echo_effect_type"]:
		if et != ActionEffect.EffectType.ECHO:
			property.usage = 0
		return

	# ── Splash ──
	if pn in ["splash_percent", "splash_all"]:
		if et != ActionEffect.EffectType.SPLASH:
			property.usage = 0
		return

	# ── Chain ──
	if pn in ["chain_count", "chain_decay", "chain_can_repeat"]:
		if et != ActionEffect.EffectType.CHAIN:
			property.usage = 0
		return

	# ── Random Strikes ──
	if pn in ["strike_count", "strike_damage", "strikes_use_dice", "strike_multiplier"]:
		if et != ActionEffect.EffectType.RANDOM_STRIKES:
			property.usage = 0
		return

	# ── Mana ──
	if pn in ["mana_amount", "mana_uses_dice"]:
		if et != ActionEffect.EffectType.MANA_MANIPULATE:
			property.usage = 0
		return

	# ── Cooldown ──
	if pn in ["cooldown_reduction", "cooldown_target_action_id"]:
		if et != ActionEffect.EffectType.MODIFY_COOLDOWN:
			property.usage = 0
		return

	# ── Charge Refund ──
	if pn in ["charges_to_refund", "refund_target_action_id"]:
		if et != ActionEffect.EffectType.REFUND_CHARGES:
			property.usage = 0
		return

	# ── Grant Action ──
	if pn in ["granted_action", "grant_duration"]:
		if et != ActionEffect.EffectType.GRANT_TEMP_ACTION:
			property.usage = 0
		return

	# ── Channel ──
	if pn in ["channel_max_turns", "channel_growth_per_turn", "channel_release_effect"]:
		if et != ActionEffect.EffectType.CHANNEL:
			property.usage = 0
		return

	# ── Counter ──
	if pn in ["counter_effect", "counter_charges", "counter_damage_threshold"]:
		if et != ActionEffect.EffectType.COUNTER_SETUP:
			property.usage = 0
		return

	# ── Summon ──
	if pn == "companion_data":
		if et != ActionEffect.EffectType.SUMMON_COMPANION:
			property.usage = 0
		return


func _is_slot_value_property(pn: String) -> bool:
	"""Returns true if pn is any type-specific override field."""
	return pn in [
		# Damage
		"base_damage", "damage_multiplier", "dice_count",
		# Heal
		"base_heal", "heal_multiplier", "heal_uses_dice",
		# Status
		"stack_count", "status_override",
		# Cleanse
		"cleanse_tags", "cleanse_max_removals",
		# Shield
		"shield_amount", "shield_uses_dice", "shield_multiplier", "shield_duration",
		# Armor Buff
		"armor_buff_amount", "armor_buff_uses_dice", "armor_buff_duration",
		# Damage Reduction
		"reduction_amount", "reduction_uses_dice", "reduction_is_percent",
		"reduction_duration", "reduction_single_use",
		# Reflect
		"reflect_percent", "reflect_duration", "reflect_element",
		# Lifesteal
		"lifesteal_percent", "lifesteal_deals_damage",
		# Execute
		"execute_threshold", "execute_bonus", "execute_instant_kill",
		# Combo Mark
		"mark_status", "mark_stacks", "mark_consume_bonus", "mark_deals_damage",
		# Echo
		"echo_threshold", "echo_count", "echo_multiplier", "echo_effect_type",
		# Splash
		"splash_percent", "splash_all",
		# Chain
		"chain_count", "chain_decay", "chain_can_repeat",
		# Random Strikes
		"strike_count", "strike_damage", "strikes_use_dice", "strike_multiplier",
		# Mana
		"mana_amount", "mana_uses_dice",
		# Cooldown
		"cooldown_reduction", "cooldown_target_action_id",
		# Charge Refund
		"charges_to_refund", "refund_target_action_id",
		# Grant Action
		"granted_action", "grant_duration",
		# Channel
		"channel_max_turns", "channel_growth_per_turn", "channel_release_effect",
		# Counter
		"counter_effect", "counter_charges", "counter_damage_threshold",
		# Summon
		"companion_data",
		# Value Source
		"value_source", "value_source_stat", "value_source_status_id",
		"value_source_defense",
		# Condition
		"condition",
	]
