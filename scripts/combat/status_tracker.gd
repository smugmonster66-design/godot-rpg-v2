# res://scripts/combat/status_tracker.gd
# Manages active status instances on a single combatant.
# Attach as a child node of any combatant (player or enemy).
# Emits signals for UI updates and integrates with AffixPoolManager.
extends Node
class_name StatusTracker

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a status is first applied
signal status_applied(status_id: String, instance: Dictionary)
## Emitted when stacks are added to an existing status
signal status_stacks_changed(status_id: String, instance: Dictionary)
## Emitted when a status expires or is removed
signal status_removed(status_id: String)
## Emitted when a status ticks (damage/heal/stat change)
signal status_ticked(status_id: String, tick_result: Dictionary)
## Emitted when one or more statuses are cleansed
signal statuses_cleansed(removed_ids: Array[String])
## Emitted when all statuses of a given timing have been processed
signal tick_phase_complete(timing: StatusAffix.TickTiming, results: Array[Dictionary])

# ============================================================================
# STATE
# ============================================================================

## Active status instances keyed by status_id
var active_statuses: Dictionary = {}

# ============================================================================
# APPLY / REMOVE
# ============================================================================

func apply_status(status_affix: StatusAffix, stacks: int = 1, source_name: String = "") -> void:
	"""Apply a status to this combatant. Stacks additively if already present."""
	if not status_affix:
		push_warning("StatusTracker: Attempted to apply null StatusAffix")
		return
	
	var sid: String = status_affix.status_id
	
	if active_statuses.has(sid):
		# Already active — add stacks
		var instance: Dictionary = active_statuses[sid]
		status_affix.add_stacks(instance, stacks)
		status_stacks_changed.emit(sid, instance)
		print("  🔄 %s: +%d stacks → %d" % [
			status_affix.affix_name, stacks, instance["current_stacks"]
		])
	else:
		# New application
		var instance: Dictionary = status_affix.create_instance(stacks, source_name)
		active_statuses[sid] = instance
		status_applied.emit(sid, instance)
		print("  ✨ Applied %s (%d stacks) from %s" % [
			status_affix.affix_name, stacks, source_name
		])

func remove_status(status_id: String) -> void:
	"""Fully remove a status by ID."""
	if active_statuses.has(status_id):
		var instance: Dictionary = active_statuses[status_id]
		var affix: StatusAffix = instance["status_affix"]
		active_statuses.erase(status_id)
		status_removed.emit(status_id)
		print("  ❌ Removed %s" % affix.affix_name)

func remove_stacks(status_id: String, amount: int) -> void:
	"""Remove stacks from a status. Passing 0 removes all stacks (full removal)."""
	if not active_statuses.has(status_id):
		return
	
	var instance: Dictionary = active_statuses[status_id]
	var affix: StatusAffix = instance["status_affix"]
	affix.remove_stacks(instance, amount)
	
	if affix.is_expired(instance):
		remove_status(status_id)
	else:
		status_stacks_changed.emit(status_id, instance)

# ============================================================================
# CLEANSE
# ============================================================================

func cleanse(tags: Array[String], max_removals: int = 0) -> Array[String]:
	"""Remove statuses matching any of the provided cleanse tags.
	
	Args:
		tags: Cleanse tags to match (e.g. ["debuff"], ["dot", "fire"], ["poison"])
		max_removals: Max statuses to remove. 0 = no limit.
	
	Returns:
		Array of status_ids that were removed.
	"""
	var removed_ids: Array[String] = []
	var to_remove: Array[String] = []
	
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		
		if affix.matches_any_cleanse_tag(tags):
			to_remove.append(sid)
			if max_removals > 0 and to_remove.size() >= max_removals:
				break
	
	for sid in to_remove:
		remove_status(sid)
		removed_ids.append(sid)
	
	if removed_ids.size() > 0:
		statuses_cleansed.emit(removed_ids)
		print("  🧹 Cleansed %d statuses with tags %s" % [removed_ids.size(), str(tags)])
	
	return removed_ids

func cleanse_all_debuffs(max_removals: int = 0) -> Array[String]:
	"""Convenience: cleanse all debuffs."""
	return cleanse(["debuff"], max_removals)

func cleanse_all_buffs(max_removals: int = 0) -> Array[String]:
	"""Convenience: cleanse all buffs (for enemy dispel abilities)."""
	return cleanse(["buff"], max_removals)

# ============================================================================
# TURN PROCESSING
# ============================================================================

func process_turn_start() -> Array[Dictionary]:
	"""Process all start-of-turn effects. Call at the beginning of this combatant's turn.
	
	Returns:
		Array of tick results for the combat log / animation system.
	"""
	var results: Array[Dictionary] = []
	
	# 1. Remove falls_off_between_turns statuses (Block, Dodge)
	_remove_falling_off_statuses()
	
	# 2. Tick all START_OF_TURN statuses
	results = _process_timing(StatusAffix.TickTiming.START_OF_TURN)
	
	# 3. Decrement duration for statuses that expire at START_OF_TURN
	_decrement_and_expire(StatusAffix.TickTiming.START_OF_TURN)
	
	tick_phase_complete.emit(StatusAffix.TickTiming.START_OF_TURN, results)
	return results

func process_turn_end() -> Array[Dictionary]:
	"""Process all end-of-turn effects. Call at the end of this combatant's turn.
	
	Returns:
		Array of tick results for the combat log / animation system.
	"""
	var results: Array[Dictionary] = []
	
	# 1. Tick all END_OF_TURN statuses
	results = _process_timing(StatusAffix.TickTiming.END_OF_TURN)
	
	# 2. Decrement duration for statuses that expire at END_OF_TURN
	_decrement_and_expire(StatusAffix.TickTiming.END_OF_TURN)
	
	tick_phase_complete.emit(StatusAffix.TickTiming.END_OF_TURN, results)
	return results

func process_on_event(timing: StatusAffix.TickTiming) -> Array[Dictionary]:
	"""Process statuses triggered by a specific event (ON_HIT, ON_DAMAGED, ON_HEAL).
	
	Call this from combat when the relevant event happens.
	"""
	return _process_timing(timing)

# ============================================================================
# INTERNAL TICK PROCESSING
# ============================================================================

func _process_timing(timing: StatusAffix.TickTiming) -> Array[Dictionary]:
	"""Tick all statuses matching the given timing, then apply decay."""
	var results: Array[Dictionary] = []
	var to_remove: Array[String] = []
	
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		
		if affix.tick_timing != timing:
			continue
		
		# Tick the status (damage, heal, stat mods)
		var tick_result: Dictionary = affix.apply_tick(instance)
		results.append(tick_result)
		status_ticked.emit(sid, tick_result)
		
		# Apply decay after tick
		affix.apply_decay(instance)
		
		# Check if expired from decay
		if affix.is_expired(instance):
			to_remove.append(sid)
		else:
			# Stacks may have changed from decay
			status_stacks_changed.emit(sid, instance)
	
	# Clean up expired statuses
	for sid in to_remove:
		remove_status(sid)
	
	return results

func _decrement_and_expire(timing: StatusAffix.TickTiming) -> void:
	"""Decrement turn durations and remove expired TURN_BASED statuses."""
	var to_remove: Array[String] = []
	
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		
		if affix.expire_timing != timing:
			continue
		
		affix.decrement_duration(instance)
		
		if affix.is_expired(instance):
			to_remove.append(sid)
		else:
			status_stacks_changed.emit(sid, instance)
	
	for sid in to_remove:
		remove_status(sid)

func _remove_falling_off_statuses() -> void:
	"""Remove statuses flagged as falls_off_between_turns (Block, Dodge)."""
	var to_remove: Array[String] = []
	
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		if affix.falls_off_between_turns:
			to_remove.append(sid)
	
	for sid in to_remove:
		remove_status(sid)

# ============================================================================
# QUERY — STAT MODIFIERS (for AffixPoolManager integration)
# ============================================================================

func get_total_stat_modifier(stat_key: String) -> float:
	"""Get the combined modifier for a stat across ALL active statuses.
	
	This is how the combat calculator asks:
	'What's the total armor modifier from status effects?'
	"""
	var total: float = 0.0
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		total += affix.get_stat_modifier_total(instance, stat_key)
	return total

func get_active_stat_modifiers() -> Dictionary:
	"""Get a dictionary of ALL stat modifiers from active statuses.
	
	Returns: {"armor": -4, "damage_multiplier": -0.2, ...}
	"""
	var combined: Dictionary = {}
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		for stat_key in affix.stat_modifier_per_stack:
			var value: float = affix.stat_modifier_per_stack[stat_key] * instance["current_stacks"]
			if combined.has(stat_key):
				combined[stat_key] += value
			else:
				combined[stat_key] = value
	return combined

# ============================================================================
# QUERY — STATUS CHECKS
# ============================================================================

func has_status(status_id: String) -> bool:
	"""Check if a status is currently active."""
	return active_statuses.has(status_id)

func get_stacks(status_id: String) -> int:
	"""Get current stack count for a status. Returns 0 if not active."""
	if active_statuses.has(status_id):
		return active_statuses[status_id]["current_stacks"]
	return 0

func get_remaining_turns(status_id: String) -> int:
	"""Get remaining turns for a status. Returns -1 if not active or not turn-based."""
	if active_statuses.has(status_id):
		return active_statuses[status_id]["remaining_turns"]
	return -1

func get_instance(status_id: String) -> Dictionary:
	"""Get the full instance dictionary for a status. Returns empty dict if not active."""
	return active_statuses.get(status_id, {})

func get_all_active() -> Array[Dictionary]:
	"""Get all active status instances (for UI display)."""
	var result: Array[Dictionary] = []
	for sid in active_statuses:
		result.append(active_statuses[sid])
	return result

func get_active_debuffs() -> Array[Dictionary]:
	"""Get all active debuffs."""
	var result: Array[Dictionary] = []
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		if affix.is_debuff:
			result.append(instance)
	return result

func get_active_buffs() -> Array[Dictionary]:
	"""Get all active buffs."""
	var result: Array[Dictionary] = []
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		if not affix.is_debuff:
			result.append(instance)
	return result

func get_statuses_with_tag(tag: String) -> Array[Dictionary]:
	"""Get all active statuses that have a specific cleanse tag."""
	var result: Array[Dictionary] = []
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		if tag in affix.cleanse_tags:
			result.append(instance)
	return result

# ============================================================================
# SPECIAL QUERIES (for combat mechanics)
# ============================================================================

func get_die_penalty() -> int:
	"""Calculate total die value penalty from Slowed + Chill."""
	var penalty: int = 0
	penalty += get_stacks("slowed")
	penalty += floori(get_stacks("chill") / 2.0)
	return penalty

func get_stunned_dice_count() -> int:
	"""Get number of dice to stun (= Stunned stacks)."""
	return get_stacks("stunned")

func get_crit_bonus() -> float:
	"""Get bonus crit chance from Expose."""
	return get_stacks("expose") * 2.0

func get_block_value() -> int:
	"""Get current Block value for damage reduction."""
	return get_stacks("block")

func check_dodge() -> bool:
	"""Roll a dodge check. Each stack = 10% chance."""
	var dodge_stacks: int = get_stacks("dodge")
	if dodge_stacks <= 0:
		return false
	return randf() * 100.0 < (dodge_stacks * 10.0)

func get_overhealth() -> int:
	"""Get current Overhealth amount."""
	return get_stacks("overhealth")

func consume_overhealth(damage: int) -> int:
	"""Consume overhealth to absorb damage. Returns remaining damage after absorption."""
	var oh: int = get_stacks("overhealth")
	if oh <= 0:
		return damage
	
	var absorbed: int = mini(damage, oh)
	remove_stacks("overhealth", absorbed)
	return damage - absorbed

# ============================================================================
# COMBAT RESET
# ============================================================================

func clear_all() -> void:
	"""Remove all statuses. Call between combats."""
	var all_ids: Array[String] = []
	for sid in active_statuses:
		all_ids.append(sid)
	
	for sid in all_ids:
		remove_status(sid)
	
	print("  🧹 StatusTracker cleared all statuses")

func clear_combat_only() -> void:
	"""Remove statuses that shouldn't persist between combats.
	Keeps PERMANENT statuses if you ever want persistent buffs.
	"""
	var to_remove: Array[String] = []
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		if affix.duration_type != StatusAffix.DurationType.PERMANENT:
			to_remove.append(sid)
	
	for sid in to_remove:
		remove_status(sid)

# ============================================================================
# DEBUG
# ============================================================================

func debug_print() -> void:
	"""Print all active statuses for debugging."""
	print("--- StatusTracker: %d active ---" % active_statuses.size())
	for sid in active_statuses:
		var instance: Dictionary = active_statuses[sid]
		var affix: StatusAffix = instance["status_affix"]
		var info: String = "  %s: %d stacks" % [affix.affix_name, instance["current_stacks"]]
		if instance["remaining_turns"] >= 0:
			info += ", %d turns" % instance["remaining_turns"]
		print(info)
	print("------")
