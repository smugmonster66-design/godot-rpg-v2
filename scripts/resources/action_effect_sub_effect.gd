# res://scripts/resources/action_effect_sub_effect.gd
# A single sub-effect within a compound ActionEffect.
# Allows one ActionEffect to trigger multiple different effect types.
extends Resource
class_name ActionEffectSubEffect

# ============================================================================
# CORE
# ============================================================================

## Which effect type this sub-effect performs (uses ActionEffect.EffectType enum).
@export var effect_type: ActionEffect.EffectType = ActionEffect.EffectType.DAMAGE

## Base value for this sub-effect (damage amount, heal amount, shield amount, etc.).
@export var effect_value: float = 0.0

## Multiplier applied to the resolved value.
@export var effect_multiplier: float = 1.0

## How the value scales (uses ActionEffect.ValueSource enum).
@export var value_source: ActionEffect.ValueSource = ActionEffect.ValueSource.STATIC

## SOURCE_STAT: which primary stat to scale from (dropdown).
@export_enum("strength", "agility", "intellect", "luck")
var value_source_stat: String = "strength"

## TARGET_STATUS_STACKS: which status to count stacks of.
@export var value_source_status_id: String = ""

## SOURCE_DEFENSE_STAT: which defense stat to scale from (dropdown).
@export_enum("armor", "barrier")
var value_source_defense: String = "armor"

## Optional condition that gates this sub-effect independently.
@export var condition: ActionEffectCondition = null

## Extra configuration data. Keys depend on effect_type:
##   DAMAGE:         { "damage_type": int, "dice_count": int }
##   HEAL:           { "uses_dice": bool, "dice_count": int }
##   ADD_STATUS:     { "status_affix": StatusAffix, "stack_count": int }
##   REMOVE_STATUS:  { "status_affix": StatusAffix, "stack_count": int }
##   CLEANSE:        { "cleanse_tags": Array[String], "max_removals": int }
##   SHIELD:         { "duration": int }
##   ARMOR_BUFF:     { "duration": int }
##   DAMAGE_REDUCTION: { "is_percent": bool, "duration": int, "single_use": bool }
##   REFLECT:        { "duration": int, "element": int }
##   LIFESTEAL:      { "deals_damage": bool, "dice_count": int }
##   EXECUTE:        { "threshold": float, "bonus": float, "instant_kill": bool, "dice_count": int }
##   COMBO_MARK:     { "mark_status": StatusAffix, "mark_stacks": int, "consume_bonus": int, "deals_damage": bool }
##   ECHO:           { "threshold": int, "count": int, "multiplier": float }
##   SPLASH:         { "splash_all": bool, "dice_count": int }
##   CHAIN:          { "chain_count": int, "chain_decay": float, "chain_can_repeat": bool, "dice_count": int }
##   RANDOM_STRIKES: { "strike_count": int, "strike_damage": int, "strikes_use_dice": bool, "strike_multiplier": float }
##   MANA_MANIPULATE: { "mana_uses_dice": bool }
##   MODIFY_COOLDOWN: { "cooldown_reduction": int, "target_action_id": String }
##   REFUND_CHARGES: { "charges_to_refund": int, "target_action_id": String }
##   GRANT_TEMP_ACTION: { "granted_action": Action, "grant_duration": int }
##   CHANNEL:        { "channel_max_turns": int, "channel_growth_per_turn": float, "channel_release_effect": ActionEffect }
##   COUNTER_SETUP:  { "counter_effect": ActionEffect, "counter_charges": int, "counter_damage_threshold": int }
@export var effect_data: Dictionary = {}

# ============================================================================
# HELPERS
# ============================================================================

func has_condition() -> bool:
	return condition != null and condition.condition_type != ActionEffectCondition.ConditionType.NONE

# ============================================================================
# DISPLAY
# ============================================================================

## Returns a human-readable summary of this sub-effect.
func get_summary() -> String:
	var type_names := [
		"Damage", "Heal", "Add Status", "Remove Status", "Cleanse",
		"Shield", "Armor Buff", "Damage Reduction", "Reflect",
		"Lifesteal", "Execute", "Combo Mark", "Echo",
		"Splash", "Chain", "Random Strikes",
		"Mana Manipulate", "Modify Cooldown", "Refund Charges", "Grant Temp Action",
		"Create Zone", "Deploy Trap", "Channel", "Counter Setup", "Summon Companion",
	]
	var tn: String = type_names[effect_type] if effect_type < type_names.size() else "Unknown"

	var parts: Array[String] = []
	if has_condition():
		parts.append("{%s}" % condition.get_description())

	# Value display
	if effect_value != 0.0:
		if effect_multiplier != 1.0:
			parts.append("%s %.0f x%.1f" % [tn, effect_value, effect_multiplier])
		else:
			parts.append("%s %.0f" % [tn, effect_value])
	else:
		parts.append(tn)

	# Value source annotation
	if value_source != ActionEffect.ValueSource.STATIC:
		parts.append("(scales: %s)" % ActionEffect.ValueSource.keys()[value_source])

	return " ".join(parts)


func _to_string() -> String:
	return "SubEffect<%s>" % get_summary()


# ============================================================================
# INSPECTOR PROPERTY GATING
# ============================================================================

func _validate_property(property: Dictionary) -> void:
	var pn: String = property.name
	match pn:
		"value_source_stat":
			if value_source != ActionEffect.ValueSource.SOURCE_STAT:
				property.usage = 0
		"value_source_status_id":
			if value_source != ActionEffect.ValueSource.TARGET_STATUS_STACKS:
				property.usage = 0
		"value_source_defense":
			if value_source != ActionEffect.ValueSource.SOURCE_DEFENSE_STAT:
				property.usage = 0
