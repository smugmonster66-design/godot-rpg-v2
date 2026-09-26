# res://resources/data/companion_synergy_definition.gd
# Defines a companion synergy — a bonus that activates when specific companions
# are active together. Supports tag-based or explicit companion_id matching.
extends Resource
class_name CompanionSynergyDefinition

# ============================================================================
# IDENTITY
# ============================================================================

@export var synergy_id: StringName = &""
@export var synergy_name: String = ""
@export_multiline var description: String = ""

# ============================================================================
# MATCHING
# ============================================================================

enum MatchMode { TAGS, EXPLICIT }

## How to determine if this synergy is active.
@export var match_mode: MatchMode = MatchMode.TAGS

## TAGS mode: active companions must collectively have ALL these tags.
@export var required_tags: Array[StringName] = []

## TAGS mode: how many companions with the required tags must be active.
@export var required_count: int = 2

## EXPLICIT mode: specific companion_ids that form this synergy.
## All listed companions must be active for the synergy to trigger.
@export var required_companion_ids: Array[StringName] = []

## Optional: minimum relationship value with ANY synergy member to activate.
## -1 means no relationship requirement.
@export var min_relationship: int = -1

# ============================================================================
# BONUSES
# ============================================================================

## Stat affixes applied to the player when synergy is active.
@export var granted_affixes: Array[Affix] = []

## Dice affixes applied to all dice when synergy is active.
@export var granted_dice_affixes: Array[DiceAffix] = []

# ============================================================================
# BONUS ACTIONS
# ============================================================================

@export_group("Bonus Actions")

## Trigger type that fires the bonus action (same triggers as companion actions).
@export var bonus_trigger: CompanionData.CompanionTrigger = CompanionData.CompanionTrigger.PLAYER_TURN_START

## Effects to execute when synergy is active and trigger fires.
## Leave empty for passive-only synergies (no bonus action).
@export var bonus_action_effects: Array[ActionEffect] = []

## Optional condition gate for the bonus action.
@export var bonus_condition: AffixCondition = null

## Cooldown between fires (turns). 0 = fires every time the trigger occurs.
@export var bonus_cooldown_turns: int = 0

## Animation for the bonus action. Null = instant (no visual).
@export var bonus_animation_set: CombatAnimationSet = null

# ============================================================================
# HELPERS
# ============================================================================

func get_affix_source_name() -> String:
	return "synergy:%s" % synergy_id
