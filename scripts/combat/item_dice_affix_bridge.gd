# res://scripts/combat/item_dice_affix_bridge.gd
# Bridges item-level DICE-category affixes (from equipment) into DiceAffixes
# that are applied to dice in the player's pool at roll time.
#
# PROBLEM THIS SOLVES:
#   Matrix IDs 126-138 (Reroll Charges, Minimum Die Value, D4 Value Bonus,
#   Auto-Reroll Below Threshold, Duplicate on Max Roll, Lock Die, etc.)
#   are designed as item Affix resources with category = DICE, but the dice
#   system only understands DiceAffix resources. This bridge reads DICE-category
#   affixes from the player's AffixPoolManager and generates transient DiceAffixes
#   that the DiceAffixProcessor can execute.
#
# USAGE:
#   # In PlayerDiceCollection.roll_hand(), after rolling but before ON_ROLL processing:
#   var bridge = ItemDiceAffixBridge.new()
#   bridge.apply_item_dice_affixes(player.affix_manager, hand)
#
#   # Or connect to equipment changes:
#   bridge.rebuild_persistent_dice_affixes(player.affix_manager, player.dice_pool.dice)
#
# ARCHITECTURE:
#   Item Affix (DICE category, effect_data contains bridge config)
#       → ItemDiceAffixBridge reads config
#       → Generates DiceAffix with correct EffectType, condition, etc.
#       → Applies as applied_affix on matching dice
#
extends RefCounted
class_name ItemDiceAffixBridge

# ============================================================================
# CONSTANTS — effect_data keys used by DICE-category Affixes
# ============================================================================

# Common effect_data keys for dice manipulation affixes:
#   "bridge_effect":  String — maps to DiceAffix.EffectType name
#   "bridge_trigger": String — maps to DiceAffix.Trigger name (default: "ON_ROLL")
#   "die_type_filter": int — if > 0, only apply to dice of this type (e.g. 4 for D4)
#   "min_die_type":   int — if > 0, only apply to dice of this type or higher
#   "threshold":      int — for AUTO_REROLL_LOW, MINIMUM_VALUE, etc.
#   "rerolls":        int — for REROLL_CHARGES, GRANT_EXTRA_ROLL
#   "min_value":      int — for SET_MINIMUM_VALUE
#   "upgrade_steps":  int — for die upgrade effects

# ============================================================================
# SIGNALS
# ============================================================================
signal dice_affix_applied(die: DieResource, affix: DiceAffix, source_affix_name: String)
signal bridge_error(message: String, affix_name: String)

# ============================================================================
# MAIN API
# ============================================================================

func apply_item_dice_affixes(affix_manager, hand: Array[DieResource]) -> int:
	"""Read DICE-category affixes and apply generated DiceAffixes to hand dice.
	
	Call this in PlayerDiceCollection.roll_hand() AFTER dice are rolled and copied
	to the hand, but BEFORE DiceAffixProcessor.process_trigger(ON_ROLL) runs.
	This way, item-granted dice affixes participate in the normal ON_ROLL pipeline.
	
	Args:
		affix_manager: Player's AffixPoolManager (has get_pool method).
		hand: The current hand of DieResource objects.
	
	Returns:
		Number of DiceAffixes applied.
	"""
	if not affix_manager or hand.is_empty():
		return 0
	
	var dice_pool = affix_manager.get_pool(Affix.Category.DICE) if affix_manager.has_method("get_pool") else []
	if dice_pool.is_empty():
		return 0
	
	var applied_count := 0
	
	for affix in dice_pool:
		if not affix is Affix:
			continue
		
		# Skip dice-grant affixes (they add dice, not modify them)
		if affix.granted_dice.size() > 0:
			continue
		
		# Skip affixes without bridge configuration
		var bridge_effect: String = affix.effect_data.get("bridge_effect", "")
		if bridge_effect == "":
			continue
		
		# Build the DiceAffix from bridge config
		var dice_affix = _build_dice_affix(affix)
		if not dice_affix:
			bridge_error.emit("Failed to build DiceAffix", affix.affix_name)
			continue
		
		# Resolve the target dice (all, or filtered by die type)
		var die_type_filter: int = affix.effect_data.get("die_type_filter", 0)
		var min_die_type: int = affix.effect_data.get("min_die_type", 0)
		
		for die in hand:
			if die.is_consumed:
				continue
			
			# Die type filtering
			if die_type_filter > 0 and die.die_type != die_type_filter:
				continue
			if min_die_type > 0 and die.die_type < min_die_type:
				continue
			
			# Apply — duplicate so each die gets its own instance
			var instance = dice_affix.duplicate(true)
			instance.source = affix.affix_name
			instance.source_type = "item_bridge"
			die.add_affix(instance)
			applied_count += 1
			dice_affix_applied.emit(die, instance, affix.affix_name)
		
		if applied_count > 0:
			print("🌉 Bridge: %s → applied to %d dice" % [affix.affix_name, applied_count])
	
	return applied_count


func clear_bridged_affixes(hand: Array[DieResource]) -> void:
	"""Remove all bridge-applied affixes from hand dice.
	Call at the start of roll_hand() before applying fresh ones."""
	for die in hand:
		var to_remove: Array[DiceAffix] = []
		for da in die.applied_affixes:
			if da.source_type == "item_bridge":
				to_remove.append(da)
		for da in to_remove:
			die.remove_affix(da)

# ============================================================================
# DICE AFFIX BUILDER
# ============================================================================

func _build_dice_affix(source_affix: Affix) -> DiceAffix:
	"""Build a DiceAffix from an item-level Affix's bridge configuration.
	
	The source_affix.effect_data dict must contain 'bridge_effect' mapping to
	one of the supported effect type strings below.
	"""
	var edata: Dictionary = source_affix.effect_data
	var bridge_effect: String = edata.get("bridge_effect", "")
	
	var da = DiceAffix.new()
	da.affix_name = source_affix.affix_name
	da.description = source_affix.description
	da.show_in_summary = true
	da.source = source_affix.affix_name
	da.source_type = "item_bridge"
	
	# Default trigger — most item dice affixes apply at roll time
	var trigger_str: String = edata.get("bridge_trigger", "ON_ROLL")
	da.trigger = _string_to_trigger(trigger_str)
	
	# Position — most apply to any position
	da.position_requirement = DiceAffix.PositionRequirement.ANY
	da.neighbor_target = DiceAffix.NeighborTarget.SELF
	
	# Resolve value from the item affix (supports item-level scaling)
	var value: float = source_affix.resolve_value({})
	
	match bridge_effect:
		# --- Value Modifications ---
		"MODIFY_VALUE_FLAT":
			da.effect_type = DiceAffix.EffectType.MODIFY_VALUE_FLAT
			da.effect_value = value
		
		"MODIFY_VALUE_PERCENT":
			da.effect_type = DiceAffix.EffectType.MODIFY_VALUE_PERCENT
			da.effect_value = value
		
		"SET_MINIMUM_VALUE":
			da.effect_type = DiceAffix.EffectType.SET_MINIMUM_VALUE
			da.effect_value = float(edata.get("min_value", value))
		
		"SET_MAXIMUM_VALUE":
			da.effect_type = DiceAffix.EffectType.SET_MAXIMUM_VALUE
			da.effect_value = value
		
		# --- Reroll Effects ---
		"GRANT_REROLL":
			da.effect_type = DiceAffix.EffectType.GRANT_REROLL
			da.effect_value = float(edata.get("rerolls", value))
		
		"AUTO_REROLL_LOW":
			da.effect_type = DiceAffix.EffectType.AUTO_REROLL_LOW
			da.effect_data = {"threshold": edata.get("threshold", int(value))}
			da.effect_value = float(edata.get("threshold", value))
		
		"ROLL_KEEP_HIGHEST":
			da.effect_type = DiceAffix.EffectType.ROLL_KEEP_HIGHEST
			da.effect_value = float(edata.get("extra_rolls", value))
		
		"GRANT_EXTRA_ROLL":
			da.effect_type = DiceAffix.EffectType.GRANT_EXTRA_ROLL
			da.effect_value = float(edata.get("extra_rolls", value))
		
		# --- Special Effects ---
		"DUPLICATE_ON_MAX":
			da.effect_type = DiceAffix.EffectType.DUPLICATE_ON_MAX
			da.trigger = DiceAffix.Trigger.ON_ROLL
			# Only fires when die rolls max — add condition
			var cond = DiceAffixCondition.new()
			cond.type = DiceAffixCondition.Type.SELF_VALUE_IS_MAX
			da.condition = cond
		
		"LOCK_DIE":
			da.effect_type = DiceAffix.EffectType.LOCK_DIE
			da.trigger = DiceAffix.Trigger.ON_USE
		
		"COPY_NEIGHBOR_VALUE":
			da.effect_type = DiceAffix.EffectType.COPY_NEIGHBOR_VALUE
			da.trigger = DiceAffix.Trigger.ON_ROLL
			da.neighbor_target = DiceAffix.NeighborTarget.SELF
			da.effect_value = edata.get("percent", 0.25)
		
		"SET_ROLL_VALUE":
			da.effect_type = DiceAffix.EffectType.SET_ROLL_VALUE
			da.effect_value = value
			da.effect_data = edata.duplicate()
		
		# --- Element Effects ---
		"SET_ELEMENT":
			da.effect_type = DiceAffix.EffectType.SET_ELEMENT
			da.effect_data = {"element": edata.get("element", "NONE")}
		
		"RANDOMIZE_ELEMENT":
			da.effect_type = DiceAffix.EffectType.RANDOMIZE_ELEMENT
			da.effect_data = {"elements": edata.get("elements", ["FIRE", "ICE", "SHOCK", "POISON"])}
		
		# --- Tag Effects ---
		"ADD_TAG":
			da.effect_type = DiceAffix.EffectType.ADD_TAG
			da.effect_data = {"tag": edata.get("tag", "")}
		
		_:
			push_warning("ItemDiceAffixBridge: Unknown bridge_effect '%s' on '%s'" % [
				bridge_effect, source_affix.affix_name])
			return null
	
	# Apply die-type condition if filter is specified via the new condition type
	var die_type_filter: int = edata.get("die_type_filter", 0)
	if die_type_filter > 0 and da.condition == null:
		var cond = DiceAffixCondition.new()
		cond.type = DiceAffixCondition.Type.SELF_DIE_TYPE_IS
		cond.threshold = float(die_type_filter)
		da.condition = cond
	
	return da


# ============================================================================
# HELPERS
# ============================================================================

func _string_to_trigger(s: String) -> DiceAffix.Trigger:
	match s.to_upper():
		"ON_ROLL": return DiceAffix.Trigger.ON_ROLL
		"ON_USE": return DiceAffix.Trigger.ON_USE
		"PASSIVE": return DiceAffix.Trigger.PASSIVE
		"ON_REORDER": return DiceAffix.Trigger.ON_REORDER
		"ON_COMBAT_START": return DiceAffix.Trigger.ON_COMBAT_START
		"ON_COMBAT_END": return DiceAffix.Trigger.ON_COMBAT_END
	return DiceAffix.Trigger.ON_ROLL


# ============================================================================
# EXAMPLE: How to configure item Affixes for bridge support
# ============================================================================
#
# --- D4 Value Bonus (ID 128) ---
# affix.category = Affix.Category.DICE
# affix.effect_number = 1.0  (or scaled via effect_min/effect_max)
# affix.effect_data = {
#     "bridge_effect": "MODIFY_VALUE_FLAT",
#     "die_type_filter": 4,          # Only D4s
# }
#
# --- Minimum Die Value (ID 127) ---
# affix.category = Affix.Category.DICE
# affix.effect_number = 3.0
# affix.effect_data = {
#     "bridge_effect": "SET_MINIMUM_VALUE",
#     "min_value": 3,
# }
#
# --- Auto-Reroll Below Threshold (ID 135) ---
# affix.category = Affix.Category.DICE
# affix.effect_data = {
#     "bridge_effect": "AUTO_REROLL_LOW",
#     "threshold": 2,
# }
#
# --- Duplicate on Max Roll (ID 136) ---
# affix.category = Affix.Category.DICE
# affix.effect_data = {
#     "bridge_effect": "DUPLICATE_ON_MAX",
# }
#
# --- Lock Die (ID 137) ---
# affix.category = Affix.Category.DICE
# affix.effect_data = {
#     "bridge_effect": "LOCK_DIE",
# }
#
# --- Copy Neighbor Value (ID 138) ---
# affix.category = Affix.Category.DICE
# affix.effect_data = {
#     "bridge_effect": "COPY_NEIGHBOR_VALUE",
#     "percent": 0.25,
# }
#
# --- Reroll Charges (ID 126) ---
# affix.category = Affix.Category.DICE
# affix.effect_number = 2.0  # number of rerolls
# affix.effect_data = {
#     "bridge_effect": "GRANT_REROLL",
#     "rerolls": 2,
# }
