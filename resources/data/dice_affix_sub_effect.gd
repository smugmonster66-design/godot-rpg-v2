# res://resources/data/dice_affix_sub_effect.gd
# A single effect step within a compound (multi-effect) DiceAffix.
# Attach multiple of these to a DiceAffix's sub_effects array to create
# affixes that do two or more things (e.g., Siphon: steal value from
# neighbor AND add it to self).
#
# Each sub-effect can override the parent's target and value source.
# If a field is left at its default, the parent DiceAffix's value is used.
extends Resource
class_name DiceAffixSubEffect

# ============================================================================
# EFFECT TYPE
# ============================================================================

## Which effect to apply. Uses the same EffectType enum as DiceAffix.
@export var effect_type: DiceAffix.EffectType = DiceAffix.EffectType.MODIFY_VALUE_FLAT

# ============================================================================
# VALUE CONFIGURATION
# ============================================================================

## Static value for this sub-effect (like DiceAffix.effect_value).
@export var effect_value: float = 0.0

## Where does the magnitude come from? Uses DiceAffix.ValueSource.
@export var value_source: DiceAffix.ValueSource = DiceAffix.ValueSource.STATIC

## Complex data for effects needing multiple values.
## Same format as DiceAffix.effect_data (tag names, thresholds, etc.)
@export var effect_data: Dictionary = {}

# ============================================================================
# TARGET OVERRIDE
# ============================================================================

## If true, this sub-effect uses target_override instead of the parent's
## neighbor_target. Useful when one sub-effect hits LEFT and another hits SELF.
@export var override_target: bool = false

## Target override (only used when override_target is true).
@export var target_override: DiceAffix.NeighborTarget = DiceAffix.NeighborTarget.SELF

# ============================================================================
# CONDITION OVERRIDE
# ============================================================================

## Optional condition that gates THIS specific sub-effect.
## If null, the parent DiceAffix's condition applies.
## If set, this condition is checked INSTEAD of the parent's for this step.
@export var condition_override: Resource = null

# ============================================================================
# HELPERS
# ============================================================================

func get_effect_tag() -> String:
	return effect_data.get("tag", "")

func get_threshold() -> int:
	return int(effect_data.get("threshold", 0))

func get_percent() -> float:
	return effect_data.get("percent", 0.0)

func get_new_die_type() -> int:
	return int(effect_data.get("new_type", 6))

func get_damage_type() -> String:
	return effect_data.get("type", "physical")

func get_status_effect() -> Dictionary:
	return effect_data.get("status", {})

func get_value_modifier() -> float:
	return effect_value

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	var data := {
		"effect_type": effect_type,
		"effect_value": effect_value,
		"value_source": value_source,
		"effect_data": effect_data,
		"override_target": override_target,
		"target_override": target_override,
	}
	if condition_override:
		data["condition_override"] = condition_override.to_dict()
	return data

static func from_dict(data: Dictionary) -> DiceAffixSubEffect:
	var sub = DiceAffixSubEffect.new()
	sub.effect_type = data.get("effect_type", DiceAffix.EffectType.MODIFY_VALUE_FLAT)
	sub.effect_value = data.get("effect_value", 0.0)
	sub.value_source = data.get("value_source", DiceAffix.ValueSource.STATIC)
	sub.effect_data = data.get("effect_data", {})
	sub.override_target = data.get("override_target", false)
	sub.target_override = data.get("target_override", DiceAffix.NeighborTarget.SELF)
	if data.has("condition_override"):
		var cond_script = load("res://resources/data/dice_affix_condition.gd")
		sub.condition_override = cond_script.from_dict(data["condition_override"])
	return sub
