# res://resources/data/affix_condition.gd
# Inspector-friendly condition resource for item-level affixes.
# Mirrors DiceAffixCondition architecture but evaluates player/equipment state
# instead of dice state.
#
# Two modes:
#   GATING  — if the check fails, the affix is skipped entirely.
#   SCALING — always fires, provides a runtime multiplier applied to the
#             resolved effect value.
#
# Attach to an Affix via its "condition" export slot.
extends Resource
class_name AffixCondition

# ============================================================================
# ENUMS
# ============================================================================

enum Type {
	NONE,                          ## Always passes (default)
	
	# ── Equipment Gates ──
	HAS_HEAVY_WEAPON,              ## Main Hand is a two-handed weapon
	HAS_DUAL_WIELD,                ## Both Main Hand and Off Hand filled
	EQUIPMENT_SLOT_FILLED,         ## A specific slot has an item (slot in effect_data)
	EQUIPMENT_SLOT_EMPTY,          ## A specific slot is empty
	MIN_EQUIPMENT_SLOTS_FILLED,    ## At least N slots filled (threshold = count)
	EQUIPMENT_RARITY_AT_LEAST,     ## Specific slot has rarity >= threshold
	ALL_SLOTS_FILLED,              ## Every equipment slot has an item
	
	# ── Health Gates ──
	HEALTH_ABOVE_PERCENT,          ## Current HP >= threshold% of max
	HEALTH_BELOW_PERCENT,          ## Current HP < threshold% of max
	HEALTH_FULL,                   ## Current HP == max HP
	
	# ── Stat Gates ──
	STAT_ABOVE,                    ## Named stat >= threshold (stat_name in effect_data)
	STAT_BELOW,                    ## Named stat < threshold
	
	# ── Combat Context ──
	IN_COMBAT,                     ## Player is in active combat
	TURN_NUMBER_ABOVE,             ## Current turn >= threshold
	TURN_NUMBER_BELOW,             ## Current turn < threshold
	
	# ── Class / Tag Gates ──
	CLASS_IS,                      ## Active class matches (class_name in effect_data)
	HAS_AFFIX_TAG,                 ## Player has at least one active affix with tag
	
	# ── Status Gates (requires StatusTracker in context) ──
	HAS_STATUS,                    ## Combatant has status_id active (status_id in condition_data)
	STATUS_STACKS_ABOVE,           ## Status has >= threshold stacks (status_id in condition_data)
	STATUS_STACKS_BELOW,           ## Status has < threshold stacks
	HAS_ANY_DEBUFF,                ## Combatant has any active debuff
	HAS_ANY_BUFF,                  ## Combatant has any active buff
	TARGET_HAS_STATUS,             ## Damage TARGET has status (status_id in condition_data)
	
	# ── Scaling (never blocked, multiply effect value) ──
	PER_EQUIPPED_ITEM,             ## multiplier = filled slot count
	PER_EQUIPMENT_RARITY,          ## multiplier = sum of equipped rarity values
	PER_STAT_POINT,                ## multiplier = stat value (stat_name in effect_data)
	PER_ACTIVE_AFFIX_IN_CATEGORY,  ## multiplier = affix count in a category
	PER_DICE_IN_POOL,              ## multiplier = player dice pool size
	PER_STATUS_STACKS,             ## multiplier = stack count of status (status_id in condition_data)
	PER_ACTIVE_DEBUFF_COUNT,       ## multiplier = number of distinct active debuffs
	PER_ACTIVE_BUFF_COUNT,         ## multiplier = number of distinct active buffs
	
	# ── v4 Mana Gates ──
	MANA_ABOVE_PERCENT,            ## Current mana >= threshold% of max (threshold 0.0–1.0)
	MANA_BELOW_PERCENT,            ## Current mana < threshold% of max
	ELEMENT_DICE_IN_HAND,          ## Hand has >= threshold dice of element (condition_data.element)
	
	# ── v4 Mana/Element Scaling ──
	PER_MANA_PERCENT,              ## multiplier = current mana / max mana (0.0–1.0)
	PER_ELEMENT_DICE_IN_HAND,      ## multiplier = count of element dice in hand (condition_data.element)
}

# ============================================================================
# INSPECTOR CONFIGURATION
# ============================================================================

@export var type: Type = Type.NONE

## Numeric threshold for comparison conditions.
## For PER_* scaling types, this is NOT used (multiplier is raw count * effect_number).
@export var threshold: float = 0.0

## If true, INVERTS gating result (pass → fail, fail → pass).
## Does not apply to scaling conditions.
@export var invert: bool = false

## Extra configuration data for conditions that need it.
## Keys vary by type:
##   EQUIPMENT_SLOT_FILLED/EMPTY: {"slot": "Main Hand"}
##   EQUIPMENT_RARITY_AT_LEAST: {"slot": "Main Hand"}
##   STAT_ABOVE/BELOW: {"stat_name": "strength"}
##   PER_STAT_POINT: {"stat_name": "strength"}
##   CLASS_IS: {"class_name": "Warrior"}
##   HAS_AFFIX_TAG: {"tag": "weapon"}
##   PER_ACTIVE_AFFIX_IN_CATEGORY: {"category": "DAMAGE_BONUS"}
##   HAS_STATUS / STATUS_STACKS_* / TARGET_HAS_STATUS / PER_STATUS_STACKS: {"status_id": "bleed"}
@export var condition_data: Dictionary = {}

# ============================================================================
# RESULT CLASS
# ============================================================================

class Result:
	var blocked: bool = false
	var multiplier: float = 1.0
	
	static func pass_result(mult: float = 1.0) -> Result:
		var r = Result.new()
		r.multiplier = mult
		return r
	
	static func fail_result() -> Result:
		var r = Result.new()
		r.blocked = true
		return r

# ============================================================================
# EVALUATION
# ============================================================================

func evaluate(context: Dictionary) -> Result:
	"""Evaluate this condition against runtime context.
	
	Args:
		context: Runtime state dictionary. Expected keys:
			- player (Player): The player resource.
			- source (Combatant): Player combatant (in combat).
			- in_combat (bool): Whether combat is active.
			- turn_number (int): Current combat turn.
			- round_number (int): Current combat round.
			- affix_manager (AffixPoolManager): Player's affix manager.
			- dice_pool (PlayerDiceCollection): Player's dice pool.
	
	Returns:
		Result with blocked flag and/or multiplier.
	"""
	if type == Type.NONE:
		return Result.pass_result()
	
	var raw_pass: bool = true
	var multiplier: float = 1.0
	var is_scaling := _is_scaling_type()
	
	var player = context.get("player", null)
	
	match type:
		# ── Equipment Gates ──
		Type.HAS_HEAVY_WEAPON:
			raw_pass = _check_has_heavy_weapon(player)
		
		Type.HAS_DUAL_WIELD:
			raw_pass = _check_has_dual_wield(player)
		
		Type.EQUIPMENT_SLOT_FILLED:
			var slot = condition_data.get("slot", "")
			raw_pass = _check_slot_filled(player, slot)
		
		Type.EQUIPMENT_SLOT_EMPTY:
			var slot = condition_data.get("slot", "")
			raw_pass = not _check_slot_filled(player, slot)
		
		Type.MIN_EQUIPMENT_SLOTS_FILLED:
			raw_pass = _count_filled_slots(player) >= int(threshold)
		
		Type.EQUIPMENT_RARITY_AT_LEAST:
			raw_pass = _check_slot_rarity(player, int(threshold))
		
		Type.ALL_SLOTS_FILLED:
			raw_pass = _check_all_slots_filled(player)
		
		# ── Health Gates ──
		Type.HEALTH_ABOVE_PERCENT:
			raw_pass = _get_health_percent(player, context) >= threshold
		
		Type.HEALTH_BELOW_PERCENT:
			raw_pass = _get_health_percent(player, context) < threshold
		
		Type.HEALTH_FULL:
			raw_pass = _check_health_full(player, context)
		
		# ── Stat Gates ──
		Type.STAT_ABOVE:
			var stat_name = condition_data.get("stat_name", "strength")
			raw_pass = _get_player_stat(player, stat_name) >= threshold
		
		Type.STAT_BELOW:
			var stat_name = condition_data.get("stat_name", "strength")
			raw_pass = _get_player_stat(player, stat_name) < threshold
		
		# ── Combat Context ──
		Type.IN_COMBAT:
			raw_pass = context.get("in_combat", false)
		
		Type.TURN_NUMBER_ABOVE:
			raw_pass = context.get("turn_number", 0) >= int(threshold)
		
		Type.TURN_NUMBER_BELOW:
			raw_pass = context.get("turn_number", 0) < int(threshold)
		
		# ── Class / Tag Gates ──
		Type.CLASS_IS:
			var required_class = condition_data.get("class_name", "")
			raw_pass = _check_class_is(player, required_class)
		
		Type.HAS_AFFIX_TAG:
			var tag = condition_data.get("tag", "")
			var affix_mgr = context.get("affix_manager", null)
			raw_pass = _check_has_affix_tag(affix_mgr, tag)
		
		# ── Status Gates ──
		Type.HAS_STATUS:
			var sid = condition_data.get("status_id", "")
			raw_pass = _check_has_status(context, sid)
		
		Type.STATUS_STACKS_ABOVE:
			var sid = condition_data.get("status_id", "")
			raw_pass = _get_status_stacks(context, sid) >= int(threshold)
		
		Type.STATUS_STACKS_BELOW:
			var sid = condition_data.get("status_id", "")
			raw_pass = _get_status_stacks(context, sid) < int(threshold)
		
		Type.HAS_ANY_DEBUFF:
			raw_pass = _check_has_any_status(context, true)
		
		Type.HAS_ANY_BUFF:
			raw_pass = _check_has_any_status(context, false)
		
		Type.TARGET_HAS_STATUS:
			var sid = condition_data.get("status_id", "")
			raw_pass = _check_target_has_status(context, sid)
		
		# ── v4 Mana Gates ──
		Type.MANA_ABOVE_PERCENT:
			raw_pass = _get_mana_percent(context) >= threshold
		
		Type.MANA_BELOW_PERCENT:
			raw_pass = _get_mana_percent(context) < threshold
		
		Type.ELEMENT_DICE_IN_HAND:
			var elem_str = condition_data.get("element", "")
			raw_pass = _count_element_dice_in_hand(context, elem_str) >= int(threshold)
		
		# ── Scaling (always pass, set multiplier) ──
		Type.PER_EQUIPPED_ITEM:
			multiplier = float(_count_filled_slots(player))
		
		Type.PER_EQUIPMENT_RARITY:
			multiplier = float(_sum_equipment_rarity(player))
		
		Type.PER_STAT_POINT:
			var stat_name = condition_data.get("stat_name", "strength")
			multiplier = float(_get_player_stat(player, stat_name))
		
		Type.PER_ACTIVE_AFFIX_IN_CATEGORY:
			var cat_name = condition_data.get("category", "NONE")
			var affix_mgr = context.get("affix_manager", null)
			multiplier = float(_count_affixes_in_category(affix_mgr, cat_name))
		
		Type.PER_DICE_IN_POOL:
			var dice_pool = context.get("dice_pool", null)
			multiplier = float(_count_dice_in_pool(dice_pool))
		
		Type.PER_STATUS_STACKS:
			var sid = condition_data.get("status_id", "")
			multiplier = float(_get_status_stacks(context, sid))
		
		Type.PER_ACTIVE_DEBUFF_COUNT:
			multiplier = float(_count_active_statuses(context, true))
		
		Type.PER_ACTIVE_BUFF_COUNT:
			multiplier = float(_count_active_statuses(context, false))
		
		# ── v4 Mana/Element Scaling ──
		Type.PER_MANA_PERCENT:
			multiplier = _get_mana_percent(context)
		
		Type.PER_ELEMENT_DICE_IN_HAND:
			var elem_str = condition_data.get("element", "")
			multiplier = float(_count_element_dice_in_hand(context, elem_str))
	
	# Scaling conditions always pass
	if is_scaling:
		return Result.pass_result(multiplier)
	
	# Apply inversion for gating conditions
	if invert:
		raw_pass = not raw_pass
	
	return Result.pass_result() if raw_pass else Result.fail_result()

# ============================================================================
# TYPE CLASSIFICATION
# ============================================================================

func _is_scaling_type() -> bool:
	return type in [
		Type.PER_EQUIPPED_ITEM,
		Type.PER_EQUIPMENT_RARITY,
		Type.PER_STAT_POINT,
		Type.PER_ACTIVE_AFFIX_IN_CATEGORY,
		Type.PER_DICE_IN_POOL,
		Type.PER_STATUS_STACKS,
		Type.PER_ACTIVE_DEBUFF_COUNT,
		Type.PER_ACTIVE_BUFF_COUNT,
		# v4
		Type.PER_MANA_PERCENT,
		Type.PER_ELEMENT_DICE_IN_HAND,
	]

func is_scaling() -> bool:
	"""Public check — used by evaluator to know if multiplier applies."""
	return _is_scaling_type()

func is_gating() -> bool:
	"""Public check — this condition can block the affix."""
	return not _is_scaling_type() and type != Type.NONE

# ============================================================================
# EQUIPMENT HELPERS
# ============================================================================

func _check_has_heavy_weapon(player) -> bool:
	if not player or not player.equipment.has("Main Hand"):
		return false
	var item: EquippableItem = player.equipment.get("Main Hand")
	return item != null and item.is_heavy_weapon()

func _check_has_dual_wield(player) -> bool:
	if not player:
		return false
	var main: EquippableItem = player.equipment.get("Main Hand")
	var off: EquippableItem = player.equipment.get("Off Hand")
	# Heavy weapons fill both slots with same item — NOT dual wield
	if main != null and off != null and main == off:
		return false
	return main != null and off != null
	
	
	
func _check_slot_filled(player, slot: String) -> bool:
	if not player or slot == "":
		return false
	return player.equipment.get(slot) != null


func _check_all_slots_filled(player) -> bool:
	if not player:
		return false
	for slot in player.equipment:
		if player.equipment[slot] == null:
			return false
	return true

func _count_filled_slots(player) -> int:
	if not player:
		return 0
	var count = 0
	for slot in player.equipment:
		if player.equipment[slot] != null:
			count += 1
	return count


func _check_slot_rarity(player, min_rarity: int) -> bool:
	var slot = condition_data.get("slot", "")
	if not player or slot == "":
		return false
	var item: EquippableItem = player.equipment.get(slot)
	if not item:
		return false
	return item.rarity >= min_rarity


func _sum_equipment_rarity(player) -> int:
	if not player:
		return 0
	var total = 0
	for slot in player.equipment:
		var item = player.equipment[slot]
		if item:
			total += item.get("rarity", 0)
	return total

# ============================================================================
# HEALTH HELPERS
# ============================================================================

func _get_health_percent(player, context: Dictionary) -> float:
	# Try combatant first (in combat)
	var source = context.get("source", null)
	if source and source.has_method("get_health_percent"):
		return source.get_health_percent()
	# Fallback to player resource
	if player:
		var max_hp = player.max_hp if player.get("max_hp") else 100
		var cur_hp = player.current_hp if player.get("current_hp") else max_hp
		if max_hp > 0:
			return float(cur_hp) / float(max_hp)
	return 1.0

func _check_health_full(player, context: Dictionary) -> bool:
	return _get_health_percent(player, context) >= 1.0

# ============================================================================
# STAT HELPERS
# ============================================================================

func _get_player_stat(player, stat_name: String) -> float:
	if not player:
		return 0.0
	if not player is Dictionary and player.has_method("get_stat"):
		return float(player.get_stat(stat_name))
	# Fallback: direct property/key access
	if player is Dictionary:
		return float(player.get(stat_name, 0))
	if stat_name in player:
		return float(player.get(stat_name))
	return 0.0

# ============================================================================
# CLASS / TAG HELPERS
# ============================================================================

func _check_class_is(player, required_class: String) -> bool:
	if not player or not player.active_class:
		return false
	return player.active_class.player_class_name == required_class

func _check_has_affix_tag(affix_manager, tag: String) -> bool:
	if not affix_manager or tag == "":
		return false
	if affix_manager.has_method("get_affixes_by_tag"):
		return affix_manager.get_affixes_by_tag(tag).size() > 0
	return false

func _count_affixes_in_category(affix_manager, category_name: String) -> int:
	if not affix_manager:
		return 0
	if category_name in Affix.Category:
		var cat = Affix.Category.get(category_name)
		return affix_manager.get_pool(cat).size()
	return 0

func _count_dice_in_pool(dice_pool) -> int:
	if not dice_pool:
		return 0
	if "dice" in dice_pool:
		return dice_pool.dice.size()
	return 0

# ============================================================================
# STATUS HELPERS
# ============================================================================

func _get_status_tracker_from_context(context: Dictionary):
	"""Get the StatusTracker from context. Checks direct ref, then player."""
	var tracker = context.get("status_tracker", null)
	if tracker:
		return tracker
	var player = context.get("player", null)
	if player and "status_tracker" in player and player.status_tracker:
		return player.status_tracker
	return null

func _get_target_status_tracker(context: Dictionary):
	"""Get the StatusTracker for the damage TARGET (for on-hit conditions)."""
	var target_tracker = context.get("target_status_tracker", null)
	if target_tracker:
		return target_tracker
	var target = context.get("target", null)
	if target and "status_tracker" in target:
		return target.status_tracker
	if target and target.has_method("get_node_or_null"):
		return target.get_node_or_null("StatusTracker")
	return null

func _check_has_status(context: Dictionary, status_id: String) -> bool:
	var tracker = _get_status_tracker_from_context(context)
	if not tracker or not tracker.has_method("has_status"):
		return false
	return tracker.has_status(status_id)

func _get_status_stacks(context: Dictionary, status_id: String) -> int:
	var tracker = _get_status_tracker_from_context(context)
	if not tracker or not tracker.has_method("get_stacks"):
		return 0
	return tracker.get_stacks(status_id)

func _check_target_has_status(context: Dictionary, status_id: String) -> bool:
	var tracker = _get_target_status_tracker(context)
	if not tracker or not tracker.has_method("has_status"):
		return false
	return tracker.has_status(status_id)

func _check_has_any_status(context: Dictionary, debuffs_only: bool) -> bool:
	var tracker = _get_status_tracker_from_context(context)
	if not tracker or not "active_statuses" in tracker:
		return false
	for sid in tracker.active_statuses:
		var instance = tracker.active_statuses[sid]
		var affix = instance.get("status_affix", null)
		if not affix:
			continue
		if debuffs_only and affix.is_debuff:
			return true
		elif not debuffs_only and not affix.is_debuff:
			return true
	return false

func _count_active_statuses(context: Dictionary, debuffs_only: bool) -> int:
	var tracker = _get_status_tracker_from_context(context)
	if not tracker or not "active_statuses" in tracker:
		return 0
	var count = 0
	for sid in tracker.active_statuses:
		var instance = tracker.active_statuses[sid]
		var affix = instance.get("status_affix", null)
		if not affix:
			continue
		if debuffs_only and affix.is_debuff:
			count += 1
		elif not debuffs_only and not affix.is_debuff:
			count += 1
	return count

# ============================================================================
# v4 — MANA / ELEMENT HELPERS
# ============================================================================

func _get_mana_percent(context: Dictionary) -> float:
	"""Get current mana as 0.0–1.0 from context. Checks player.mana_pool."""
	var player = context.get("player", null)
	if not player:
		return 0.0
	if player.has_method("has_mana_pool") and player.has_mana_pool():
		return player.mana_pool.get_mana_percent()
	return 0.0

func _count_element_dice_in_hand(context: Dictionary, element_str: String) -> int:
	"""Count dice in the player's current hand matching the given element string.
	element_str should be uppercase: "FIRE", "ICE", "SHOCK", etc."""
	var dice_pool = context.get("dice_pool", null)
	if not dice_pool or not "hand" in dice_pool:
		return 0
	
	var count: int = 0
	for die in dice_pool.hand:
		if die.is_consumed:
			continue
		# DieResource.Element enum name comparison
		var die_elem_name: String = DieResource.Element.keys()[die.element] if die.element < DieResource.Element.size() else ""
		if die_elem_name == element_str.to_upper():
			count += 1
	return count

# ============================================================================
# DESCRIPTION GENERATION
# ============================================================================


func get_description() -> String:
	"""Generate a human-readable description of this condition."""
	match type:
		Type.NONE:
			return ""
		Type.HAS_HEAVY_WEAPON:
			return "Requires two-handed weapon"
		Type.HAS_DUAL_WIELD:
			return "Requires dual-wielding"
		Type.EQUIPMENT_SLOT_FILLED:
			return "Requires %s equipped" % condition_data.get("slot", "?")
		Type.EQUIPMENT_SLOT_EMPTY:
			return "Requires %s empty" % condition_data.get("slot", "?")
		Type.MIN_EQUIPMENT_SLOTS_FILLED:
			return "Requires %d+ equipment slots filled" % int(threshold)
		Type.ALL_SLOTS_FILLED:
			return "Requires all equipment slots filled"
		Type.HEALTH_ABOVE_PERCENT:
			return "Requires HP above %d%%" % int(threshold * 100)
		Type.HEALTH_BELOW_PERCENT:
			return "Requires HP below %d%%" % int(threshold * 100)
		Type.HEALTH_FULL:
			return "Requires full HP"
		Type.STAT_ABOVE:
			return "Requires %s >= %d" % [condition_data.get("stat_name", "?"), int(threshold)]
		Type.STAT_BELOW:
			return "Requires %s < %d" % [condition_data.get("stat_name", "?"), int(threshold)]
		Type.CLASS_IS:
			return "Requires %s class" % condition_data.get("class_name", "?")
		Type.PER_EQUIPPED_ITEM:
			return "Per equipped item"
		Type.PER_EQUIPMENT_RARITY:
			return "Per equipment rarity point"
		Type.PER_STAT_POINT:
			return "Per %s point" % condition_data.get("stat_name", "?")
		Type.PER_ACTIVE_AFFIX_IN_CATEGORY:
			return "Per active %s affix" % condition_data.get("category", "?")
		Type.PER_DICE_IN_POOL:
			return "Per die in pool"
		Type.HAS_STATUS:
			return "Requires %s active" % condition_data.get("status_id", "?")
		Type.STATUS_STACKS_ABOVE:
			return "Requires %s >= %d stacks" % [condition_data.get("status_id", "?"), int(threshold)]
		Type.STATUS_STACKS_BELOW:
			return "Requires %s < %d stacks" % [condition_data.get("status_id", "?"), int(threshold)]
		Type.HAS_ANY_DEBUFF:
			return "Requires any debuff active"
		Type.HAS_ANY_BUFF:
			return "Requires any buff active"
		Type.TARGET_HAS_STATUS:
			return "Requires target has %s" % condition_data.get("status_id", "?")
		Type.PER_STATUS_STACKS:
			return "Per %s stack" % condition_data.get("status_id", "?")
		Type.PER_ACTIVE_DEBUFF_COUNT:
			return "Per active debuff"
		Type.PER_ACTIVE_BUFF_COUNT:
			return "Per active buff"
		# v4 Mana/Element
		Type.MANA_ABOVE_PERCENT:
			return "Requires mana above %d%%" % int(threshold * 100)
		Type.MANA_BELOW_PERCENT:
			return "Requires mana below %d%%" % int(threshold * 100)
		Type.ELEMENT_DICE_IN_HAND:
			return "Requires %d+ %s dice in hand" % [int(threshold), condition_data.get("element", "?")]
		Type.PER_MANA_PERCENT:
			return "Scales with mana percentage"
		Type.PER_ELEMENT_DICE_IN_HAND:
			return "Per %s die in hand" % condition_data.get("element", "?")
		_:
			return "Unknown condition"

func _to_string() -> String:
	return "AffixCondition<%s>" % Type.keys()[type]
