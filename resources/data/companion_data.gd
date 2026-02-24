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
@export var portrait: Texture2D = null

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

# ============================================================================
# DURATION (summons only)
# ============================================================================
@export_group("Summon")
## 0 = lasts entire combat. N = disappears after N turns.
@export var duration_turns: int = 0

# ============================================================================
# METHODS
# ============================================================================

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
