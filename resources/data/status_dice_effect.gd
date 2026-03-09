# res://resources/data/status_dice_effect.gd
# Data-driven dice effect attached to a StatusAffix.
# Describes which dice in the combatant's hand to target and what to do to them.
extends Resource
class_name StatusDiceEffect

# ============================================================================
# ENUMS
# ============================================================================

enum TargetMode {
	ALL,         # Every die in hand that isn't already consumed/locked
	RANDOM_N,    # N random eligible dice (N = stacks if target_count_equals_stacks)
	BY_INDEX,    # Specific slot positions listed in target_indices
	BY_TAG,      # All dice carrying a specific tag
	HIGHEST_N,   # N dice with the highest current value
	LOWEST_N,    # N dice with the lowest current value
}

enum EffectType {
	LOCK,               # die.is_locked = true  (excluded from get_unconsumed_hand)
	CONSUME,            # die.is_consumed = true (treated as spent)
	MODIFY_VALUE_FLAT,  # die.apply_flat_modifier(int(effect_value))
	MODIFY_VALUE_MULT,  # die.modified_value = int(die.modified_value * effect_value)
	ADD_TAG,            # die.add_tag(effect_tag)
	REMOVE_TAG,         # die.remove_tag(effect_tag)
	CHANGE_ELEMENT,     # die.element = effect_element
	MODIFY_VALUE_CONDITIONAL, # computed flat modifier — amount derived from a formula
}

## Determines how the modifier value is computed for MODIFY_VALUE_CONDITIONAL.
enum ConditionalFormula {
	PER_STACK_OF_STATUS,        # effect_value per stack of formula_status_id
	PER_N_STACKS_OF_STATUS,     # effect_value per every formula_divisor stacks of formula_status_id (floors)
	IF_STATUS_ACTIVE,           # flat effect_value if formula_status_id is active at all
	PER_CONSUMED_DIE_THIS_TURN, # effect_value per die already consumed this turn
	PER_REMAINING_DIE,          # effect_value per die not yet consumed/locked
}

enum FireTrigger {
	ON_ROLL,       # Applied inside roll_hand() after all other modifiers
	ON_TURN_START, # Reserved — applied at process_turn_start() before roll (not yet wired)
}

# ============================================================================
# EXPORTS
# ============================================================================

## When this effect fires relative to the roll cycle.
@export var fire_trigger: FireTrigger = FireTrigger.ON_ROLL

## How to select target dice.
@export var target_mode: TargetMode = TargetMode.RANDOM_N

## Number of dice to target. Ignored when target_count_equals_stacks = true.
@export var target_count: int = 1

## If true, the number of dice targeted equals the current stack count of the parent status.
@export var target_count_equals_stacks: bool = true

## Used only when target_mode = BY_INDEX. List of hand slot indices to target.
@export var target_indices: Array[int] = []

## Used only when target_mode = BY_TAG. Tag string to match against die tags.
@export var target_tag: String = ""

## What to do to each targeted die.
@export var effect_type: EffectType = EffectType.LOCK

## Numeric operand for MODIFY_VALUE_FLAT (addend) and MODIFY_VALUE_MULT (multiplier).
@export var effect_value: float = 0.0

## Tag string for ADD_TAG / REMOVE_TAG.
@export var effect_tag: String = ""

## Element for CHANGE_ELEMENT.
@export var effect_element: DieResource.Element = DieResource.Element.NONE

## ── MODIFY_VALUE_CONDITIONAL ────────────────────────────────────────────────

## Which formula drives the computed modifier.
@export var conditional_formula: ConditionalFormula = ConditionalFormula.PER_STACK_OF_STATUS

## Status ID to query for stack-based formulas (PER_STACK, PER_N_STACKS, IF_ACTIVE).
@export var formula_status_id: String = ""

## Divisor for PER_N_STACKS_OF_STATUS. Modifier = floor(stacks / formula_divisor) * effect_value.
## Example: effect_value=-1, formula_divisor=2 → -1 per every 2 stacks.
@export var formula_divisor: int = 1

## Optional floor clamp on the computed modifier (e.g. -10 prevents the penalty exceeding 10).
## Set to 0 to disable clamping.
@export var formula_result_min: float = 0.0

## Optional ceiling clamp on the computed modifier.
## Set to 0 to disable clamping.
@export var formula_result_max: float = 0.0
