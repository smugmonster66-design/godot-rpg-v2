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
	GRANT_ITEM,      ## Give `item` (EquippableItem/ConsumableItem) x int_value
	REMOVE_ITEM,     ## Take int_value items named `key` from the player
	HEAL_PLAYER,     ## Heal int_value HP plus heal_percent of max HP
}

# ============================================================================
# PROPERTIES
# ============================================================================
@export var effect_type: EffectType = EffectType.SET_FLAG

## Flag/counter/relationship key. Leave blank for GIVE_GOLD / GIVE_XP.
@export var key: StringName = &""

## Amount for counters/gold/xp, delta for relationships. Ignored for SET/CLEAR_FLAG.
## GRANT_ITEM / REMOVE_ITEM: quantity. HEAL_PLAYER: flat HP.
@export var int_value: int = 1

## GRANT_ITEM: the item template to give.
@export var item: Resource = null

## HEAL_PLAYER: fraction of max HP to restore (0.0-1.0), added to int_value.
@export_range(0.0, 1.0) var heal_percent: float = 0.0

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
		EffectType.GRANT_ITEM:
			ItemGrant.grant(item, max(1, int_value))
		EffectType.REMOVE_ITEM:
			ItemGrant.remove_by_name(String(key), max(1, int_value))
		EffectType.HEAL_PLAYER:
			ItemGrant.heal_player(int_value, heal_percent)
