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
## v4 — Emitted when a status reaches its stack threshold
signal status_threshold_triggered(status_id: String, event_data: Dictionary)


# ============================================================================
# STATE
# ============================================================================

## Active status instances keyed by status_id
var active_statuses: Dictionary = {}

## v5: Reference to the source combatant's AffixPoolManager.
## Used for threshold reduction queries. Set by combat_manager at combat start.
var _source_affix_manager: AffixPoolManager = null

func set_source_affix_manager(manager: AffixPoolManager) -> void:
	_source_affix_manager = manager

# ============================================================================
# APPLY / REMOVE
# ============================================================================

func apply_status(status_affix: StatusAffix, stacks: int = 1,
		source_name: String = "", duration_bonus: int = 0,
		damage_mult: float = 1.0, source_combatant: Combatant = null) -> void:
	"""Apply a status to this combatant. Stacks additively if already present.
	
	Args:
		status_affix: The StatusAffix resource defining this status.
		stacks: Number of stacks to apply.
		source_name: Who/what applied it (for combat log).
		duration_bonus: Extra turns added to base duration (from skills/affixes).
		damage_mult: Multiplier on tick damage (from skills/affixes).
		source_combatant: The combatant who applied this status (for taunt tracking).
	"""
	if not status_affix:
		push_warning("StatusTracker: Attempted to apply null StatusAffix")
		return
	
	var sid: String = status_affix.status_id
	
	if active_statuses.has(sid):
		# Already active — add stacks
		var instance: Dictionary = active_statuses[sid]
		status_affix.add_stacks(instance, stacks)
		# Update damage_mult if the new application has a stronger one
		var existing_mult: float = instance.get("damage_mult", 1.0)
		if damage_mult > existing_mult:
			instance["damage_mult"] = damage_mult
		status_stacks_changed.emit(sid, instance)
		print("  🔄 %s: +%d stacks → %d" % [
			status_affix.affix_name, stacks, instance["current_stacks"]
		])
	else:
		# New application — pass through duration_bonus and damage_mult
		var instance: Dictionary = status_affix.create_instance(
			stacks, source_name, duration_bonus, damage_mult)
		instance["source_combatant"] = source_combatant  # Track who applied it (for taunt)
		active_statuses[sid] = instance
		status_applied.emit(sid, instance)
		print("  ✨ Applied %s (%d stacks, +%d turns, ×%.1f dmg) from %s" % [
			status_affix.affix_name, stacks, duration_bonus,
			damage_mult, source_name
		])
	
	# v4 — Check stack threshold (v5: supports threshold reduction from skills)
	if status_affix.stack_threshold > 0 and active_statuses.has(sid):
		var instance: Dictionary = active_statuses[sid]
		var effective_threshold: int = _get_effective_threshold(status_affix)
		if instance["current_stacks"] >= effective_threshold:
			_trigger_threshold_v5(sid, instance, status_affix, effective_threshold)

func remove_status(status_id: String) -> void:
	"""Fully remove a status by ID."""
	if status_id == "taunt":
		print("  [DEBUG TAUNT] remove_status() called! Stack trace:")
		print(get_stack())
	
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
		
		# ADD THIS:
		if sid == "taunt":
			print("  [DEBUG TAUNT] _process_timing: Processing taunt! tick_timing=%s, timing=%s, stacks=%s" % [
				affix.tick_timing, timing, instance.get("current_stacks", -1)
			])
		
		# Tick the status (damage, heal, stat mods)
		var tick_result: Dictionary = affix.apply_tick(instance)
		results.append(tick_result)
		status_ticked.emit(sid, tick_result)
		
		# Apply decay after tick (v5: skip decay if eternal_flame_mark is active)
		if sid == "burn" and active_statuses.has("eternal_flame_mark"):
			pass  # Burn cannot decay while Eternal Flame is active
		else:
			affix.apply_decay(instance)
		
		# Check if expired from decay
		if affix.is_expired(instance):
			# ADD THIS:
			if sid == "taunt":
				print("  [DEBUG TAUNT] _process_timing: Taunt expired! stacks=%s" % instance.get("current_stacks", -1))
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
		
		if sid == "taunt":
			print("  [DEBUG TAUNT] _decrement_and_expire: timing=%s, expire_timing=%s, duration_type=%s, remaining_turns=%s" % [
				timing, affix.expire_timing, affix.duration_type, instance.get("remaining_turns", -1)
			])
		
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
		if sid == "taunt":
			print("  [DEBUG TAUNT] falls_off_between_turns=%s" % affix.falls_off_between_turns)
		if affix.falls_off_between_turns:
			to_remove.append(sid)
	
	for sid in to_remove:
		remove_status(sid)


# ============================================================================
# v4 — STACK THRESHOLD
# ============================================================================


func _get_effective_threshold(affix: StatusAffix) -> int:
	"""Get the effective stack threshold after skill-based reductions.
	
	Queries _source_affix_manager for affixes tagged with
	'{status_id}_threshold_reduction' (e.g. 'burn_threshold_reduction').
	"""
	var base: int = affix.stack_threshold
	if not _source_affix_manager:
		return base
	
	var reduction_tag: String = affix.status_id + "_threshold_reduction"
	var reduction: int = 0
	for a in _source_affix_manager.get_affixes_by_tag(reduction_tag):
		reduction += int(a.effect_number)
	
	return maxi(1, base - reduction)  # Never reduce below 1

func _trigger_threshold_v5(sid: String, instance: Dictionary,
		affix: StatusAffix, effective_threshold: int) -> void:
	"""v5 wrapper for _trigger_threshold that uses the effective threshold
	for stack consumption instead of the base threshold."""
	# Temporarily override for consumption calculation
	var original_threshold: int = affix.stack_threshold
	affix.stack_threshold = effective_threshold
	_trigger_threshold(sid, instance, affix)
	affix.stack_threshold = original_threshold

func _trigger_threshold(sid: String, instance: Dictionary, affix: StatusAffix):
	"""Handle stack threshold being reached. Fires the threshold effect,
	consumes threshold stacks, and removes the status if depleted."""
	var threshold: int = affix.stack_threshold
	print("  💥 %s threshold reached (%d stacks)!" % [affix.affix_name, threshold])
	
	match affix.threshold_effect:
		StatusAffix.ThresholdEffect.BURST_DAMAGE:
			var damage: int = int(affix.damage_per_stack * threshold * affix.threshold_value)
			var is_magical: bool = affix.tick_damage_type == StatusAffix.StatusDamageType.MAGICAL
			var event_data: Dictionary = {
				"effect": "burst_damage",
				"damage": damage,
				"damage_is_magical": is_magical,
				"status_name": affix.affix_name,
				"stacks_consumed": threshold,
			}
			status_threshold_triggered.emit(sid, event_data)
		
		StatusAffix.ThresholdEffect.APPLY_OTHER_STATUS:
			if affix.threshold_status:
				var new_stacks: int = affix.threshold_stacks if affix.threshold_stacks > 0 else 1
				apply_status(affix.threshold_status, new_stacks, affix.affix_name)
				print("  ❄️ %s → applied %s (%d stacks)" % [
					affix.affix_name, affix.threshold_status.affix_name, new_stacks])
			else:
				push_warning("StatusTracker: %s has APPLY_OTHER_STATUS but no threshold_status set" % sid)
		
		StatusAffix.ThresholdEffect.CUSTOM_SIGNAL:
			var event_data: Dictionary = {
				"effect": "custom",
				"value": affix.threshold_value,
				"status_name": affix.affix_name,
				"stacks_consumed": threshold,
			}
			status_threshold_triggered.emit(sid, event_data)
	
	# Consume threshold stacks
	affix.remove_stacks(instance, threshold)
	
	# Remove if depleted
	if affix.is_expired(instance):
		remove_status(sid)
	else:
		status_stacks_changed.emit(sid, instance)

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

func get_taunting_combatant() -> Combatant:
	"""Get the combatant who applied taunt to this target.
	Returns null if no taunt active or taunter is dead."""
	if not has_status("taunt"):
		return null
	
	var taunt_instance = active_statuses.get("taunt")
	if not taunt_instance:
		return null
	
	var taunter = taunt_instance.get("source_combatant")
	
	# ADD THIS DEBUG:
	print("  [DEBUG TAUNT] get_taunting_combatant:")
	print("    taunter exists: %s" % (taunter != null))
	print("    taunter type: %s" % (taunter.get_class() if taunter else "null"))
	print("    is Combatant: %s" % (taunter is Combatant if taunter else "N/A"))
	print("    is_alive: %s" % (taunter.is_alive() if taunter and taunter.has_method("is_alive") else "N/A"))
	
	if taunter and taunter is Combatant and taunter.is_alive():
		return taunter
	
	# Taunter died - clear the taunt
	remove_status("taunt")
	return null

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
