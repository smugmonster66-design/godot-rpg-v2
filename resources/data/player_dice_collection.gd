# res://resources/data/player_dice_collection.gd
# Manages player's ordered dice collection
# Pool = persistent dice (templates), Hand = rolled copies for current combat turn
#
# v2.1 CHANGELOG — Ghost Hand:
#   - consume_from_hand() no longer removes dice from the hand array.
#     Instead it marks die.is_consumed = true and passes the FULL stable
#     hand to the processor with context["triggering_die"] so ON_USE
#     affixes can resolve neighbors correctly.
#   - Added get_unconsumed_hand() for UI/gameplay that needs only available dice.
#   - Added get_consumed_hand() for iterating over used dice.
#   - restore_to_hand() now clears is_consumed instead of re-inserting.
#   - roll_hand() resets is_consumed on all hand dice.
#   - All existing methods, signals, serialization preserved.
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
signal combat_modifier_added(modifier: CombatModifier)   # v2
signal die_destroyed(die: DieResource)                   # v2 — permanent pool removal

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
## Rolled dice available this combat turn.
## IMPORTANT (v2.1): Consumed dice remain in this array with is_consumed = true.
## The array never shrinks during a turn — positions are stable for affix resolution.
## Use get_unconsumed_hand() for dice that can still be placed.
var hand: Array[DieResource] = []

## Track which pool dice have been "used" this turn (for visual feedback)
var used_pool_indices: Array[int] = []

# ============================================================================
# COMBAT STATE (v2)
# ============================================================================

## Persistent modifiers that last across turns within one combat.
## Populated by ON_COMBAT_START affixes and special effects (e.g., Sacrifice).
## Cleared on combat end.
var combat_modifiers: Array[CombatModifier] = []

## Original hand size at start of current turn (set in roll_hand).
var _original_hand_size: int = 0

## Current combat turn number (0 = not in combat, 1+ = active).
var _current_turn: int = 0

## Dice queued for permanent destruction at end of turn.
## We defer destruction to avoid modifying the pool mid-iteration.
var _pending_destructions: Array[int] = []  # pool slot indices

# ============================================================================
# LEGACY COMPATIBILITY
# ============================================================================
## For backwards compatibility with old code expecting available_dice.
## Returns only UNCONSUMED dice so existing gameplay logic still works.
var available_dice: Array[DieResource]:
	get:
		return get_unconsumed_hand()
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
# CONTEXT BUILDING (v2)
# ============================================================================

func _build_context() -> Dictionary:
	"""Build the runtime context dictionary passed to the affix processor.
	Contains all turn/combat state that conditions and effects may need."""
	return {
		"used_count": used_pool_indices.size(),
		"used_indices": used_pool_indices.duplicate(),
		"original_hand_size": _original_hand_size,
		"turn_number": _current_turn,
		"combat_modifiers": combat_modifiers,
	}

func _build_use_context(die: DieResource) -> Dictionary:
	"""Build context specifically for ON_USE processing.
	Includes the triggering die and its index so the processor knows
	which die is being used (and only fires that die's affixes)."""
	var ctx = _build_context()
	ctx["triggering_die"] = die
	ctx["triggering_index"] = hand.find(die)
	return ctx

# ============================================================================
# COMBAT LIFECYCLE (v2)
# ============================================================================

func start_combat():
	"""Call at the start of a new combat encounter.
	Clears combat state and processes ON_COMBAT_START affixes."""
	_current_turn = 0
	combat_modifiers.clear()
	_pending_destructions.clear()
	used_pool_indices.clear()
	hand.clear()
	
	print("⚔️ Combat started — processing ON_COMBAT_START affixes")
	process_combat_start_affixes()

func end_combat():
	"""Call when combat ends. Clears all combat state."""
	_current_turn = 0
	combat_modifiers.clear()
	_pending_destructions.clear()
	used_pool_indices.clear()
	hand.clear()
	
	print("⚔️ Combat ended — processing ON_COMBAT_END affixes")
	process_combat_end_affixes()
	
	hand_changed.emit()

func end_turn():
	"""Call at end of player's turn. Ticks combat modifiers and processes
	any pending die destructions."""
	_process_pending_destructions()
	tick_combat_modifiers()

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
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_REORDER, _build_context())
		_handle_affix_results(result)

# ============================================================================
# HAND MANAGEMENT (Combat Turn)
# ============================================================================

func roll_hand():
	"""Roll the HAND from POOL - call at start of each combat turn.
	Creates rolled copies of each pool die. Resets all consumed state."""
	_current_turn += 1
	print("🎲 Rolling hand from pool (%d dice)... [Turn %d]" % [dice.size(), _current_turn])
	
	# Clear previous hand
	hand.clear()
	used_pool_indices.clear()
	_pending_destructions.clear()
	
	# Create rolled copies of each pool die
	for i in range(dice.size()):
		var pool_die = dice[i]
		var hand_die = _create_hand_die(pool_die, i)
		hand_die.roll()
		hand_die.is_consumed = false  # Explicitly reset consumed state
		hand.append(hand_die)
		print("  [%d] %s rolled %d" % [i, hand_die.display_name, hand_die.get_total_value()])
	
	_original_hand_size = hand.size()
	
	# Process ON_ROLL affixes on the hand
	if affix_processor:
		print("  Processing roll affixes...")
		var ctx = _build_context()
		var result = affix_processor.process_trigger(hand, DiceAffix.Trigger.ON_ROLL, ctx)
		_handle_affix_results(result)
	
	# --- v2: Apply persistent combat modifiers ---
	_apply_combat_modifiers()
	
	# Print final values
	print("🎲 Hand ready (%d dice):" % hand.size())
	for die in hand:
		var affix_mod = ""
		if die.modified_value != die.current_value:
			affix_mod = " (base %d)" % die.current_value
		print("  %s = %d%s" % [die.display_name, die.get_total_value(), affix_mod])
	
	# FIX: Only emit hand_rolled — both signals route to _request_refresh()
	# in DicePoolDisplay, so emitting hand_changed too risks a second
	# deferred refresh that restarts the entrance animation.
	hand_rolled.emit(hand.duplicate())

func _create_hand_die(pool_die: DieResource, pool_index: int) -> DieResource:
	"""Create a hand die as a copy of a pool die"""
	var hand_die = pool_die.duplicate_die()
	hand_die.slot_index = pool_index  # Track which pool slot it came from
	hand_die.source = pool_die.source
	return hand_die

func consume_from_hand(die: DieResource):
	"""Mark a die as consumed from the HAND (used in combat action).
	
	v2.1: The die is NOT removed from the hand array. Instead it is marked
	is_consumed = true so the array stays structurally stable for neighbor-
	targeting affixes. ON_USE affixes are processed against the full hand
	with this die identified as the triggering die in context.
	
	UI should read die.is_consumed to hide/grey/disable the visual."""
	var hand_index = hand.find(die)
	if hand_index == -1:
		print("⚠️ Die not found in hand: %s" % die.display_name)
		return
	
	if die.is_consumed:
		print("⚠️ Die already consumed: %s" % die.display_name)
		return
	
	# Track which pool index was used (for visual feedback + context)
	used_pool_indices.append(die.slot_index)
	
	# Process ON_USE affixes against the FULL STABLE HAND
	if affix_processor:
		var ctx = _build_use_context(die)
		var result = affix_processor.process_trigger(hand, DiceAffix.Trigger.ON_USE, ctx)
		_handle_affix_results(result)
	
	# Mark consumed AFTER affix processing so the triggering die's value
	# is still readable during its own ON_USE effects
	die.is_consumed = true
	
	print("🎲 Hand: Consumed %s at index %d (%d remaining)" % [
		die.display_name, hand_index, get_unconsumed_count()])
	die_consumed.emit(die)
	hand_changed.emit()

func restore_to_hand(die: DieResource):
	"""Restore a consumed die back to usable state (e.g., action cancelled).
	v2.1: Clears is_consumed instead of re-inserting into the array."""
	if die not in hand:
		# Fallback for legacy callers that removed the die — re-add it
		var insert_pos = 0
		for i in range(hand.size()):
			if hand[i].slot_index > die.slot_index:
				break
			insert_pos = i + 1
		hand.insert(insert_pos, die)
	
	if not die.is_consumed:
		return  # Already available
	
	# Remove from used tracking
	used_pool_indices.erase(die.slot_index)
	
	die.is_consumed = false
	
	print("🎲 Hand: Restored %s (%d available)" % [die.display_name, get_unconsumed_count()])
	hand_changed.emit()

func clear_hand():
	"""Clear the HAND (end of combat or turn reset)"""
	hand.clear()
	used_pool_indices.clear()
	hand_changed.emit()

# ============================================================================
# HAND QUERIES (v2.1 — Ghost Hand)
# ============================================================================

func get_unconsumed_hand() -> Array[DieResource]:
	"""Get hand dice that have NOT been consumed this turn.
	Use this for UI display of available dice and for gameplay logic
	that needs to know what the player can still use."""
	var result: Array[DieResource] = []
	for die in hand:
		if not die.is_consumed:
			result.append(die)
	return result

func get_consumed_hand() -> Array[DieResource]:
	"""Get hand dice that HAVE been consumed this turn."""
	var result: Array[DieResource] = []
	for die in hand:
		if die.is_consumed:
			result.append(die)
	return result

func get_unconsumed_count() -> int:
	"""Get count of dice that can still be used this turn."""
	var count := 0
	for die in hand:
		if not die.is_consumed:
			count += 1
	return count

func get_full_hand() -> Array[DieResource]:
	"""Get the complete hand array including consumed dice.
	Useful for position-aware operations that need the stable layout."""
	return hand.duplicate()

# ============================================================================
# LEGACY COMPATIBILITY - roll_all_dice maps to roll_hand
# ============================================================================

func roll_all_dice():
	"""Legacy compatibility - calls roll_hand()"""
	roll_hand()

func consume_die(die: DieResource):
	"""Legacy compatibility — routes to consume_from_hand()."""
	consume_from_hand(die)

func restore_die(die: DieResource):
	"""Legacy compatibility - calls restore_to_hand()"""
	restore_to_hand(die)

# ============================================================================
# COMBAT MODIFIERS (v2)
# ============================================================================

func _apply_combat_modifiers():
	"""Apply all persistent combat modifiers to the current hand.
	Called after roll_hand() creates fresh copies and processes ON_ROLL affixes."""
	if combat_modifiers.size() == 0:
		return
	
	print("  🛡️ Applying %d combat modifier(s)..." % combat_modifiers.size())
	for modifier in combat_modifiers:
		for i in range(hand.size()):
			var die = hand[i]
			if modifier.applies_to_die(die, i):
				modifier.apply_to_die(die)
				print("    %s → %s (now %d)" % [modifier.source_name, die.display_name, die.get_total_value()])

func add_combat_modifier(modifier: CombatModifier):
	"""Add a persistent combat modifier (can be called externally too)."""
	combat_modifiers.append(modifier)
	combat_modifier_added.emit(modifier)
	print("  🛡️ Added combat modifier: %s" % modifier)

func tick_combat_modifiers():
	"""Called at end of turn. Decrements turn-based modifiers and removes expired ones."""
	var to_remove: Array[CombatModifier] = []
	for modifier in combat_modifiers:
		if modifier.tick_turn():
			to_remove.append(modifier)
	
	for modifier in to_remove:
		combat_modifiers.erase(modifier)
		print("  🛡️ Combat modifier expired: %s" % modifier)

# ============================================================================
# PENDING DESTRUCTIONS (v2)
# ============================================================================

func _process_pending_destructions():
	"""Process any dice queued for permanent pool destruction.
	Called at end of turn to avoid modifying pool mid-iteration."""
	if _pending_destructions.size() == 0:
		return
	
	# Sort descending so removing from back doesn't shift earlier indices
	_pending_destructions.sort()
	_pending_destructions.reverse()
	
	for pool_idx in _pending_destructions:
		if pool_idx >= 0 and pool_idx < dice.size():
			var destroyed_die = dice[pool_idx]
			print("💀 Permanently destroying %s from pool slot %d" % [destroyed_die.display_name, pool_idx])
			dice.remove_at(pool_idx)
			die_destroyed.emit(destroyed_die)
	
	_pending_destructions.clear()
	_update_slot_indices()
	dice_changed.emit()

# ============================================================================
# QUERIES
# ============================================================================

func get_pool_count() -> int:
	"""Get number of dice in POOL"""
	return dice.size()

func get_hand_count() -> int:
	"""Get number of dice in HAND (total including consumed)"""
	return hand.size()

func get_total_count() -> int:
	"""Get total dice in POOL (legacy compatibility)"""
	return dice.size()

func get_available_count() -> int:
	"""Get available (unconsumed) dice in HAND"""
	return get_unconsumed_count()

func get_all_dice() -> Array[DieResource]:
	"""Get all POOL dice in order"""
	return dice.duplicate()

func get_available_dice() -> Array[DieResource]:
	"""Get unconsumed HAND dice (legacy compatibility)"""
	return get_unconsumed_hand()

func get_hand_dice() -> Array[DieResource]:
	"""Get all HAND dice (including consumed — use get_unconsumed_hand() for available only)"""
	return hand.duplicate()

func get_die_at(index: int) -> DieResource:
	"""Get POOL die at specific position"""
	if index < 0 or index >= dice.size():
		return null
	return dice[index]

func get_hand_die_at(index: int) -> DieResource:
	"""Get HAND die at specific position (may be consumed)"""
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
	"""Get HAND dice with a specific tag (including consumed)"""
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
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.PASSIVE, _build_context())
		_handle_affix_results(result)

func process_combat_start_affixes():
	"""Process ON_COMBAT_START affixes"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_COMBAT_START, _build_context())
		_handle_affix_results(result)

func process_combat_end_affixes():
	"""Process ON_COMBAT_END affixes"""
	if affix_processor:
		var result = affix_processor.process_trigger(dice, DiceAffix.Trigger.ON_COMBAT_END, _build_context())
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
			
			# --- v2 special effects ---
			"destroy_from_pool":
				var pool_idx: int = effect.pool_slot_index
				_pending_destructions.append(pool_idx)
				print("    💀 Queued %s (pool slot %d) for destruction" % [
					effect.get("die_name", "?"), pool_idx])
			
			"create_combat_modifier":
				var modifier: CombatModifier = effect.modifier
				add_combat_modifier(modifier)

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
