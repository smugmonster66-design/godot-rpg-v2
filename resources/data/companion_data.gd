# res://resources/data/companion_data.gd
# Template resource defining a companion's stats, trigger, action, and behavior.
# Used by both NPC companions and summons.
extends Resource
class_name CompanionData

# ============================================================================
# IDENTITY
# ============================================================================
@export var companion_name: String = "Companion"
@export var companion_id: StringName = &""
@export_multiline var description: String = ""
@export var action_name: String = ""
@export_multiline var action_description: String = ""
@export var portrait: Texture2D = null

## Tags for synergy matching (e.g., &"frost", &"healer", &"undead")
@export var synergy_tags: Array[StringName] = []

enum CompanionType { NPC, SUMMON }
@export var companion_type: CompanionType = CompanionType.NPC

# ============================================================================
# HEALTH
# ============================================================================
@export_group("Health")
@export var base_max_hp: int = 50

enum HPScaling { FLAT, PLAYER_PERCENT, PLAYER_LEVEL }
@export var hp_scaling: HPScaling = HPScaling.FLAT
## For PLAYER_PERCENT: max_hp = player.max_hp * hp_scaling_value
## For PLAYER_LEVEL: max_hp = base_max_hp + (player.level * hp_scaling_value)
## For FLAT: ignored (base_max_hp is the total)
@export var hp_scaling_value: float = 0.0

# ============================================================================
# TRIGGER
# ============================================================================
@export_group("Trigger")

enum CompanionTrigger {
	PLAYER_TURN_START,
	PLAYER_TURN_END,
	ENEMY_TURN_START,
	PLAYER_DAMAGED,
	PLAYER_DAMAGED_THRESHOLD,
	ALLY_DAMAGED,
	COMPANION_DAMAGED,
	OTHER_COMPANION_DAMAGED,
	ENEMY_KILLED,
	COMPANION_KILLED,
	ROUND_START,
	ON_SUMMON,
	ON_DEATH,
	PLAYER_HIT_HARD,   ## one hit took >= trigger_data.min_percent (default 0.2) of the player's max HP
	HAND_ROLLED,       ## the player's hand was just rolled (Dice-shaper hook)
}
@export var trigger: CompanionTrigger = CompanionTrigger.PLAYER_TURN_START

## Extra config per trigger type.
## e.g. { "threshold_percent": 0.25 } for PLAYER_DAMAGED_THRESHOLD
@export var trigger_data: Dictionary = {}

# ============================================================================
# ACTION
# ============================================================================
@export_group("Action")
## Reuses the existing ActionEffect system -- all 21 effect types work.
@export var action_effects: Array[ActionEffect] = []
## Dice-shaper effects on the player's hand (Signature).
@export var dice_effects: Array[CompanionDiceEffect] = []

# ============================================================================
# TARGETING
# ============================================================================
enum CompanionTarget {
	RANDOM_ENEMY,
	ALL_ENEMIES,
	LOWEST_HP_ENEMY,
	PLAYER,
	SELF,
	OTHER_COMPANION,
	LOWEST_HP_ALLY,
	ALL_ALLIES,
	TRIGGERING_SOURCE,
	DAMAGED_ALLY,
	DOWNED_COMPANION,  ## a downed (0 HP) NPC companion; a HEAL revives them (Wounded)
}
@export var target_rule: CompanionTarget = CompanionTarget.RANDOM_ENEMY

# ============================================================================
# CONDITION (optional gating)
# ============================================================================
@export_group("Condition")
## Reuses existing AffixCondition. null = always fires when triggered.
@export var condition: AffixCondition = null

# ============================================================================
# LIMITS
# ============================================================================
@export_group("Limits")
## 0 = fires every trigger. N = skip N turns after firing.
@export var cooldown_turns: int = 0
## 0 = unlimited uses per combat.
@export var uses_per_combat: int = 0
## If false, skip the first trigger occurrence.
@export var fires_on_first_turn: bool = true

# ============================================================================
# TAUNT
# ============================================================================
@export_group("Taunt")
@export var has_taunt: bool = false
## 0 = permanent while alive. N = taunt lasts N turns.
@export var taunt_duration: int = 0

# ============================================================================
# VISUALS
# ============================================================================
@export_group("Visuals")
## Full cast -> travel -> impact animation sequence.
## Uses the same CombatAnimationSet system as player/enemy actions.
## If null, companion fires with just the slot flash (legacy behavior).
@export var animation_set: CombatAnimationSet = null
## Idle sprite for overworld/persistent display.
@export var idle_animation: SpriteFrames = null
@export var summon_enter_preset: SummonPreset = null
@export var entry_emanate_preset: EmanatePreset = null
# ============================================================================
# BARKS
# ============================================================================
@export_group("Barks")
## This companion's personality bark reactions (speech bubble exclamations).
## Evaluated by BarkManager when GameEventBus events fire.
@export var bark_set: BarkSet = null

# ============================================================================
# DURATION (summons only)
# ============================================================================
@export_group("Summon")
## 0 = lasts entire combat. N = disappears after N turns.
@export var duration_turns: int = 0

# ============================================================================
# REACTION AND BOND ABILITY (Companion System, approved 2026-09-26)
# ============================================================================
@export_group("Reaction")
## Second trigger, unlocked at Trusted (CompanionBondRules.reaction_min_tier).
@export var reaction: CompanionAbility = null
@export_group("Bond Ability")
## Unlocked at Devoted. Once per fight unless the ability says otherwise
## (uses_per_combat 0 here means 1).
@export var bond_ability: CompanionAbility = null

# ============================================================================
# BOND (scaling, temperament)
# ============================================================================
@export_group("Bond")
## Roll the bond die (d4..d12 by relationship tier) plus the player's
## primary-stat bonus and hand it to effects as their die value.
@export var uses_bond_die: bool = true
## If > 0, always roll this die instead of the tier's (summons, which have no
## relationship, roll nothing unless this is set).
@export var fixed_die_sides: int = 0

enum Temperament { NONE, PROUD, STEADFAST, LOYAL, WARY, BONDED }
## How relationship reacts to falls (numbers in CompanionBondRules).
@export var temperament: Temperament = Temperament.NONE
## BONDED: the companion_id whose fall this companion reacts to.
@export var bonded_to: StringName = &""
## Per-companion override of the temperament table: { event: delta }.
@export var temperament_overrides: Dictionary = {}

# ============================================================================
# TRAIL PERK (out of combat)
# ============================================================================
@export_group("Trail Perk")
enum TrailPerk {
	NONE,
	GOLD_FIND,      ## +value (0.1 = +10%) gold from fights
	REST_HEALING,   ## +value (0.1 = +10%) healing from rests
}
@export var trail_perk: TrailPerk = TrailPerk.NONE
@export var trail_perk_value: float = 0.0
## Tier needed for the perk to work (0 = from recruitment).
@export var trail_perk_min_tier: int = 0
@export var trail_perk_description: String = ""

# ============================================================================
# METHODS
# ============================================================================

var _signature_cache: CompanionAbility = null

func get_signature() -> CompanionAbility:
	"""The Signature as a CompanionAbility, built from this resource's own
	trigger/action fields."""
	if _signature_cache == null:
		var a := CompanionAbility.new()
		a.ability_name = action_name
		a.description = action_description
		a.trigger = trigger
		a.trigger_data = trigger_data
		a.fires_on_first_turn = fires_on_first_turn
		a.action_effects = action_effects
		a.dice_effects = dice_effects
		a.target_rule = target_rule
		a.condition = condition
		a.cooldown_turns = cooldown_turns
		a.uses_per_combat = uses_per_combat
		a.min_tier = 0
		a.animation_set = animation_set
		_signature_cache = a
	return _signature_cache


func get_abilities() -> Array[Dictionary]:
	"""[{slot, ability}] for signature, reaction and bond (those that exist)."""
	var out: Array[Dictionary] = [{"slot": &"signature", "ability": get_signature()}]
	if reaction:
		out.append({"slot": &"reaction", "ability": reaction})
	if bond_ability:
		out.append({"slot": &"bond", "ability": bond_ability})
	return out


func get_temperament_key() -> String:
	return String(Temperament.keys()[temperament]).to_lower()


func calculate_max_hp(player_max_hp: int, player_level: int) -> int:
	"""Calculate this companion's max HP based on scaling mode."""
	match hp_scaling:
		HPScaling.FLAT:
			return base_max_hp
		HPScaling.PLAYER_PERCENT:
			return maxi(1, roundi(player_max_hp * hp_scaling_value))
		HPScaling.PLAYER_LEVEL:
			return maxi(1, base_max_hp + roundi(player_level * hp_scaling_value))
	return base_max_hp
