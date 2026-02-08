# res://resources/data/affix_sub_effect.gd
# Individual sub-effect within a compound Affix.
# When an Affix has sub_effects, the evaluator iterates these INSTEAD of
# the top-level effect. Each sub-effect has its own category, value,
# value source, and optional condition override.
#
# Mirrors DiceAffixSubEffect architecture for item-level affixes.
extends Resource
class_name AffixSubEffect

# ============================================================================
# EFFECT CONFIGURATION
# ============================================================================

## What category of effect this sub-effect produces.
## Determines which pool / calculation it feeds into.
@export var category: Affix.Category = Affix.Category.NONE

## Static effect value (used when value_source is STATIC).
@export var effect_number: float = 0.0

## Where does the effect magnitude come from?
@export var value_source: Affix.ValueSource = Affix.ValueSource.STATIC

## Complex effect data for effects needing extra config.
## Same keys as Affix.effect_data — proc_effect, condition data, etc.
@export var effect_data: Dictionary = {}

# ============================================================================
# GRANTED RESOURCES
# ============================================================================

@export_group("Granted Resources")

## Action granted by this sub-effect (for NEW_ACTION category).
@export var granted_action: Action = null

## Dice granted by this sub-effect (for DICE category).
@export var granted_dice: Array[DieResource] = []

# ============================================================================
# CONDITION OVERRIDE
# ============================================================================

@export_group("Condition Override")

## If true, use this sub-effect's own condition instead of the parent's.
@export var override_condition: bool = false

## Condition for THIS sub-effect only (checked when override_condition is true).
## If null while override_condition is true, this sub-effect always fires.
@export var condition: AffixCondition = null

# ============================================================================
# EVALUATION
# ============================================================================

func resolve_value(context: Dictionary) -> float:
	"""Resolve the effect value using the configured value source.
	
	Args:
		context: Runtime context with player, equipment, combat state.
	
	Returns:
		The resolved numeric value for this sub-effect.
	"""
	var player = context.get("player", null)
	
	match value_source:
		Affix.ValueSource.STATIC:
			return effect_number
		
		Affix.ValueSource.PLAYER_STAT:
			var stat_name = effect_data.get("stat_name", "strength")
			var stat_val = _get_stat(player, stat_name)
			return stat_val * effect_number
		
		Affix.ValueSource.PLAYER_HEALTH_PERCENT:
			var hp_pct = _get_health_percent(player, context)
			return hp_pct * effect_number
		
		Affix.ValueSource.EQUIPPED_ITEM_COUNT:
			return float(_count_equipped(player)) * effect_number
		
		Affix.ValueSource.ACTIVE_AFFIX_COUNT:
			var cat_name = effect_data.get("count_category", "NONE")
			var mgr = context.get("affix_manager", null)
			return float(_count_in_category(mgr, cat_name)) * effect_number
		
		Affix.ValueSource.EQUIPMENT_RARITY_SUM:
			return float(_sum_rarity(player)) * effect_number
		
		Affix.ValueSource.DICE_POOL_SIZE:
			var pool = context.get("dice_pool", null)
			var count = pool.dice.size() if pool and "dice" in pool else 0
			return float(count) * effect_number
		
		Affix.ValueSource.COMBAT_TURN_NUMBER:
			return float(context.get("turn_number", 0)) * effect_number
		
		_:
			return effect_number

func check_condition(context: Dictionary) -> bool:
	"""Check this sub-effect's condition override (if any).
	Returns true if the sub-effect should fire."""
	if not override_condition:
		return true  # No override — parent decides
	if condition == null:
		return true  # Override with no condition = always fire
	var result = condition.evaluate(context)
	return not result.blocked

func get_condition_multiplier(context: Dictionary) -> float:
	"""Get the scaling multiplier from this sub-effect's condition.
	Returns 1.0 if no condition or condition isn't scaling."""
	if not override_condition or condition == null:
		return 1.0
	var result = condition.evaluate(context)
	return result.multiplier

# ============================================================================
# HELPERS
# ============================================================================

func _get_stat(player, stat_name: String) -> float:
	if not player:
		return 0.0
	if not player is Dictionary and player.has_method("get_stat"):
		return float(player.get_stat(stat_name))
	if player is Dictionary:
		return float(player.get(stat_name, 0))
	if stat_name in player:
		return float(player.get(stat_name))
	return 0.0

func _get_health_percent(player, context: Dictionary) -> float:
	var source = context.get("source", null)
	if source and source.has_method("get_health_percent"):
		return source.get_health_percent()
	if player and player.get("max_hp") and player.max_hp > 0:
		return float(player.current_hp) / float(player.max_hp)
	return 1.0

func _count_equipped(player) -> int:
	if not player:
		return 0
	var count = 0
	for slot in player.equipment:
		if player.equipment[slot] != null:
			count += 1
	return count

func _sum_rarity(player) -> int:
	if not player:
		return 0
	var total = 0
	for slot in player.equipment:
		var item = player.equipment[slot]
		if item:
			total += item.get("rarity", 0)
	return total

func _count_in_category(affix_manager, category_name: String) -> int:
	if not affix_manager:
		return 0
	if category_name in Affix.Category:
		return affix_manager.get_pool(Affix.Category.get(category_name)).size()
	return 0

# ============================================================================
# DISPLAY
# ============================================================================

func get_description() -> String:
	"""Generate a summary for UI/debug."""
	var cat_name = Affix.Category.keys()[category] if category < Affix.Category.size() else "?"
	var val_text = str(effect_number)
	if value_source != Affix.ValueSource.STATIC:
		val_text += " × %s" % Affix.ValueSource.keys()[value_source]
	return "%s: %s" % [cat_name, val_text]

func _to_string() -> String:
	return "AffixSubEffect<%s>" % get_description()
