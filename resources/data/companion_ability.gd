# res://resources/data/companion_ability.gd
# One companion ability: a trigger, a target and what it does.
# A companion's Signature lives in CompanionData's own trigger/action fields
# (so older companions keep working); the Reaction and the Bond ability are
# CompanionAbility sub-resources on CompanionData.
extends Resource
class_name CompanionAbility

@export var ability_name: String = ""
@export_multiline var description: String = ""

@export_group("Trigger")
@export var trigger: CompanionData.CompanionTrigger = CompanionData.CompanionTrigger.PLAYER_TURN_START
## Extra config per trigger, e.g. { "threshold_percent": 0.25 } for
## PLAYER_DAMAGED_THRESHOLD, { "min_percent": 0.2 } for PLAYER_HIT_HARD.
@export var trigger_data: Dictionary = {}
## If false, the first time this ability's trigger matches in a fight is skipped.
@export var fires_on_first_turn: bool = true

@export_group("Action")
## Effects run through the shared pipeline (armour, elements, crit, threat).
## Effects that use dice (dice_count > 0, heal_uses_dice, shield_uses_dice)
## read the bond roll.
@export var action_effects: Array[ActionEffect] = []
## Dice-shaper effects on the player's hand (raise, reroll, set max, add a die).
@export var dice_effects: Array[CompanionDiceEffect] = []
@export var target_rule: CompanionData.CompanionTarget = CompanionData.CompanionTarget.RANDOM_ENEMY
## null = always fires when triggered.
@export var condition: AffixCondition = null

@export_group("Limits")
## 0 = fires every trigger. N = skip N rounds after firing.
@export var cooldown_turns: int = 0
## 0 = unlimited. Bond abilities default to once per fight (see CompanionData).
@export var uses_per_combat: int = 0
## Relationship tier needed (0 Acquaintance .. 3 Devoted). -1 = the slot's
## default: Reaction = CompanionBondRules.reaction_min_tier, Bond ability =
## bond_ability_min_tier. Summons ignore tiers.
@export var min_tier: int = -1

@export_group("Visuals")
## null = the companion's own animation_set.
@export var animation_set: CombatAnimationSet = null
