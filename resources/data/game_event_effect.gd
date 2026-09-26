# res://resources/data/game_event_effect.gd
# A single side effect that fires when a game event is triggered.
# Used as a sub-resource inside GameEventDefinition.
extends Resource
class_name GameEventEffect

# ============================================================================
# EFFECT TYPES
# ============================================================================
enum EffectType {
	SET_FLAG,
	CLEAR_FLAG,
	INCREMENT_COUNTER,
	DECREMENT_COUNTER,
	SET_COUNTER,
	MODIFY_RELATIONSHIP,
	GIVE_GOLD,
	GIVE_XP,
}

# ============================================================================
# PROPERTIES
# ============================================================================
@export var effect_type: EffectType = EffectType.SET_FLAG

## Flag/counter/relationship key. Leave blank for GIVE_GOLD / GIVE_XP.
@export var key: StringName = &""

## Amount for counters/gold/xp, delta for relationships. Ignored for SET/CLEAR_FLAG.
@export var int_value: int = 1

# ============================================================================
# API
# ============================================================================

func apply() -> void:
	"""Execute this effect against current game state."""
	match effect_type:
		EffectType.SET_FLAG:
			GameState.set_flag(key, true)
		EffectType.CLEAR_FLAG:
			GameState.set_flag(key, false)
		EffectType.INCREMENT_COUNTER:
			GameState.increment_counter(key, int_value)
		EffectType.DECREMENT_COUNTER:
			GameState.increment_counter(key, -int_value)
		EffectType.SET_COUNTER:
			GameState.set_counter(key, int_value)
		EffectType.MODIFY_RELATIONSHIP:
			GameState.modify_relationship(key, int_value)
		EffectType.GIVE_GOLD:
			if GameManager and GameManager.player:
				GameManager.player.add_gold(int_value)
		EffectType.GIVE_XP:
			if GameManager and GameManager.player:
				GameManager.player.add_experience(int_value)
