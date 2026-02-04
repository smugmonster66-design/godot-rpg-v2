# player_dice_collection.gd - Manages player's ordered dice collection
# Pool = persistent dice (templates), Hand = rolled copies for current combat turn
extends Node
class_name PlayerDiceCollection

# ============================================================================
# SIGNALS
# ============================================================================
signal dice_changed()                                    # Pool changed
signal dice_reordered(old_order: Array, new_order: Array)
signal hand_rolled(hand: Array[DieResource])             # Hand generated
signal hand_changed()                                    # Hand modified
signal die_consumed(die: DieResource)                    # Die used from hand
signal affix_triggered(die: DieResource, affix: DiceAffix)

# ============================================================================
# POOL - Persistent dice collection (templates)
# ============================================================================
## All dice in order (position matters for affixes!)
var dice: Array[DieResource] = []

## Maximum dice the player can have in pool
@export var max_dice: int = 10

# ============================================================================
# HAND - Combat turn dice (rolled copies)
# ============================================================================
## Rolled dice available this combat turn
var hand: Array[DieResource] = []

## Track which pool dice have been "used" this turn (for visual feedback)
var used_pool_indices: Array[int] = []

# ============================================================================
# LEGACY COMPATIBILITY
# ============================================================================
## For backwards compatibility with old code expecting available_dice
var available_dice: Array[DieResource]:
	get:
		return hand
	set(value):
		hand = value

# ============================================================================
# AFFIX PROCESSOR
# ============================================================================
var affix_processor: DiceAffixProcessor = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	affix_processor = DiceAffixProcessor.new()
	if affix_processor.has_signal("affix_activated"):
		affix_processor.affix_activated.connect(_on_affix_activated)
	print("🎲 PlayerDiceCollection initialized")

# ============================================================================
# POOL MANAGEMENT (Persistent)
# ============================================================================

func add_die(die: DieResource, at_index: int = -1):
	"""Add a die to the POOL at a specific position"""
	if dice.size() >= max_dice:
		push_warning("Cannot add die: pool full (%d/%d)" % [dice.size(), max_dice])
		return
	
	if at_index < 0 or at_index >= dice.size():
		dice.append(die)
	else:
		dice.insert(at_index, die)
	
	_update_slot_indices()
	print("🎲 Pool: Added %s at position %d (total: %d)" % [die.display_name, die.slot_index, dice.size()])
	print("🎲 Pool: Adding die: %s" % die.display_name)
	print("   fill_texture: %s" % die.fill_texture)
	print("   stroke_texture: %s" % die.stroke_texture)
	print("   resource_path: %s" % die.resource_path)
	dice_changed.emit()

func remove_die(die: DieResource):
	"""Remove a specific die from POOL"""
	dice.erase(die)
	_update_slot_indices()
	print("🎲 Pool: Removed %s (total: %d)" % [die.display_name, dice.size()])
	dice_changed.emit()

func remove_die_at(index: int) -> DieResource:
	"""Remove and return die at specific index from POOL"""
	if index < 0 or index >= dice.size():
		return null
	
	var die = dice[index]
	dice.remove_at(index)
	_update_slot_indices()
	dice_changed.emit()
	return die

func remove_dice_by_source(source: String):
	"""Remove all dice from a specific source from POOL"""
	var to_remove: Array[DieResource] = []
	for die in dice:
		if die.source == source:
			to_remove.append(die)
	
	for die in to_remove:
		remove_die(die)
	
	print("🎲 Pool: Removed %d dice from source: %s" % [to_remove.size(), source])

func clear_pool():
	"""Remove all dice from POOL"""
	dice.clear()
	_update_slot_indices()
	dice_changed.emit()

func add_dice_from_source(die_types: Array, source: String, tags: Array = []):
	"""Add multiple dice to POOL from a source (like equipment)"""
	for die_type in die_types:
		var die = DieResource.new(die_type, source)
		for tag in tags:
			if tag is String:
				die.add_tag(tag)
		add_die(die)

# ============================================================================
# POOL REORDERING
# ============================================================================

func reorder_dice(from_index: int, to_index: int):
	"""Move a die from one position to another in POOL"""
	if from_index < 0 or from_index >= dice.size():
		return
	if to_index < 0 or to_index >= dice.size():
		return
	if from_index == to_index:
		return
	
	var old_order = dice.duplicate()
	var die = dice[from_index]
	dice.remove_at(from_index)
	dice.insert(to_index, die)
	
	_update_slot_indices()
	_process_reorder_affixes()
	
	dice_reordered.emit(old_order, dice.duplicate())
	dice_changed.emit()

func _update_slot_indices():
	"""Update slot_index on each die to match position"""
	for i in range(dice.size()):
		dice[i].slot_index = i

func _process_reorder_affixes():
	"""Process affixes that trigger on reorder"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_REORDER)
		_handle_affix_results(result)

# ============================================================================
# HAND MANAGEMENT (Combat Turn)
# ============================================================================

func roll_hand():
	"""Roll the HAND from POOL - call at start of each combat turn
	Creates rolled copies of each pool die
	"""
	print("🎲 Rolling hand from pool (%d dice)..." % dice.size())
	
	# Clear previous hand
	hand.clear()
	used_pool_indices.clear()
	
	# Create rolled copies of each pool die
	for i in range(dice.size()):
		var pool_die = dice[i]
		var hand_die = _create_hand_die(pool_die, i)
		hand_die.roll()
		hand.append(hand_die)
		print("  [%d] %s rolled %d" % [i, hand_die.display_name, hand_die.get_total_value()])
	
	# Process ON_ROLL affixes on the hand
	if affix_processor:
		print("  Processing roll affixes...")
		var result = affix_processor.process_trigger(hand, DiceAffix.Trigger.ON_ROLL)
		_handle_affix_results(result)
	
	# Print final values
	print("🎲 Hand ready (%d dice):" % hand.size())
	for die in hand:
		var affix_mod = ""
		if die.modified_value != die.current_value:
			affix_mod = " (base %d)" % die.current_value
		print("  %s = %d%s" % [die.display_name, die.get_total_value(), affix_mod])
	
	hand_rolled.emit(hand.duplicate())
	hand_changed.emit()

func _create_hand_die(pool_die: DieResource, pool_index: int) -> DieResource:
	"""Create a hand die as a copy of a pool die"""
	var hand_die = pool_die.duplicate_die()
	hand_die.slot_index = pool_index  # Track which pool slot it came from
	# Mark the source so we know it's a hand copy
	hand_die.source = pool_die.source
	return hand_die

func consume_from_hand(die: DieResource):
	"""Remove a die from the HAND (used in combat action)"""
	var hand_index = hand.find(die)
	if hand_index == -1:
		print("⚠️ Die not found in hand: %s" % die.display_name)
		return
	
	# Track which pool index was used (for visual feedback)
	used_pool_indices.append(die.slot_index)
	
	# Process ON_USE affixes before removing
	if affix_processor:
		var single_die_array: Array[DieResource] = [die]
		var result = affix_processor.process_trigger(single_die_array, DiceAffix.Trigger.ON_USE)
		_handle_affix_results(result)
	
	hand.erase(die)
	print("🎲 Hand: Consumed %s (%d remaining)" % [die.display_name, hand.size()])
	die_consumed.emit(die)
	hand_changed.emit()

func restore_to_hand(die: DieResource):
	"""Restore a die back to the HAND (e.g., action cancelled)"""
	if die in hand:
		return  # Already in hand
	
	# Remove from used tracking
	used_pool_indices.erase(die.slot_index)
	
	# Re-add to hand at original position
	var insert_pos = 0
	for i in range(hand.size()):
		if hand[i].slot_index > die.slot_index:
			break
		insert_pos = i + 1
	
	hand.insert(insert_pos, die)
	print("🎲 Hand: Restored %s (%d total)" % [die.display_name, hand.size()])
	hand_changed.emit()

func clear_hand():
	"""Clear the HAND (end of combat or turn reset)"""
	hand.clear()
	used_pool_indices.clear()
	hand_changed.emit()

# ============================================================================
# LEGACY COMPATIBILITY - roll_all_dice maps to roll_hand
# ============================================================================

func roll_all_dice():
	"""Legacy compatibility - calls roll_hand()"""
	roll_hand()

func consume_die(die: DieResource):
	"""Remove a die from the hand (it was used in an action)"""
	var idx = hand.find(die)
	if idx >= 0:
		hand.remove_at(idx)
		hand_changed.emit()

func restore_die(die: DieResource):
	"""Legacy compatibility - calls restore_to_hand()"""
	restore_to_hand(die)

# ============================================================================
# QUERIES
# ============================================================================

func get_pool_count() -> int:
	"""Get number of dice in POOL"""
	return dice.size()

func get_hand_count() -> int:
	"""Get number of dice in HAND"""
	return hand.size()

func get_total_count() -> int:
	"""Get total dice in POOL (legacy compatibility)"""
	return dice.size()

func get_available_count() -> int:
	"""Get available dice in HAND (legacy compatibility)"""
	return hand.size()

func get_all_dice() -> Array[DieResource]:
	"""Get all POOL dice in order"""
	return dice.duplicate()

func get_available_dice() -> Array[DieResource]:
	"""Get all HAND dice (legacy compatibility)"""
	return hand.duplicate()

func get_hand_dice() -> Array[DieResource]:
	"""Get all HAND dice"""
	return hand.duplicate()

func get_die_at(index: int) -> DieResource:
	"""Get POOL die at specific position"""
	if index < 0 or index >= dice.size():
		return null
	return dice[index]

func get_hand_die_at(index: int) -> DieResource:
	"""Get HAND die at specific position"""
	if index < 0 or index >= hand.size():
		return null
	return hand[index]

func is_pool_index_used(pool_index: int) -> bool:
	"""Check if a pool slot's die has been consumed this turn"""
	return pool_index in used_pool_indices

func get_dice_with_tag(tag: String) -> Array[DieResource]:
	"""Get POOL dice with a specific tag"""
	var result: Array[DieResource] = []
	for die in dice:
		if die.has_tag(tag):
			result.append(die)
	return result

func get_hand_dice_with_tag(tag: String) -> Array[DieResource]:
	"""Get HAND dice with a specific tag"""
	var result: Array[DieResource] = []
	for die in hand:
		if die.has_tag(tag):
			result.append(die)
	return result

func get_dice_by_source(source: String) -> Array[DieResource]:
	"""Get POOL dice from a specific source"""
	var result: Array[DieResource] = []
	for die in dice:
		if die.source == source:
			result.append(die)
	return result

func get_dice_by_type(die_type: DieResource.DieType) -> Array[DieResource]:
	"""Get POOL dice of a specific type"""
	var result: Array[DieResource] = []
	for die in dice:
		if die.die_type == die_type:
			result.append(die)
	return result

func find_die_index(die: DieResource) -> int:
	"""Find index of a die in POOL"""
	return dice.find(die)

func find_hand_index(die: DieResource) -> int:
	"""Find index of a die in HAND"""
	return hand.find(die)

# ============================================================================
# AFFIX PROCESSING
# ============================================================================

func process_passive_affixes():
	"""Process PASSIVE affixes on POOL"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.PASSIVE)
		_handle_affix_results(result)

func process_combat_start_affixes():
	"""Process ON_COMBAT_START affixes"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_COMBAT_START)
		_handle_affix_results(result)

func process_combat_end_affixes():
	"""Process ON_COMBAT_END affixes"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_COMBAT_END)
		_handle_affix_results(result)

func _handle_affix_results(result: Dictionary):
	"""Handle special effects from affix processing"""
	if not result.has("special_effects"):
		return
	
	for effect in result.special_effects:
		match effect.type:
			"duplicate":
				var source_die: DieResource = effect.source_die
				var new_die = source_die.duplicate_die()
				new_die.source = "Duplicated from " + source_die.display_name
				add_die(new_die)
				print("    ✨ Created duplicate die!")
			"auto_reroll":
				pass  # Already handled in processor

func _on_affix_activated(die: DieResource, affix: DiceAffix, targets: Array[int]):
	"""Handle affix activation"""
	affix_triggered.emit(die, affix)

# ============================================================================
# AFFIX PREVIEW
# ============================================================================

func get_affix_preview_for_position(die: DieResource, target_index: int) -> String:
	"""Preview what affixes would do if die is moved to a position"""
	if affix_processor:
		return affix_processor.get_affix_description_at_position(
			die, target_index, dice.size()
		)
	return ""

# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	"""Serialize POOL (hand is transient, not saved)"""
	var dice_data: Array[Dictionary] = []
	for die in dice:
		dice_data.append(die.to_dict())
	
	return {
		"dice": dice_data,
		"max_dice": max_dice
	}

func from_dict(data: Dictionary):
	"""Load POOL from dictionary"""
	dice.clear()
	hand.clear()
	
	max_dice = data.get("max_dice", 10)
	
	for die_data in data.get("dice", []):
		var die = DieResource.from_dict(die_data)
		dice.append(die)
	
	_update_slot_indices()
	dice_changed.emit()
