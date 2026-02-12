# res://scripts/combat/battlefield_tracker.gd
# Manages persistent battlefield effects: channels and counters.
# Add as a child of CombatManager (or CombatScene).
#
# INTEGRATION:
#   - CombatManager calls process_turn_start() at turn start (advances channels)
#   - CombatManager calls on_damage_taken() when player takes damage (triggers counters)
#   - CombatManager calls clear_all() at combat end
extends Node
class_name BattlefieldTracker

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a channel is released (naturally or broken).
signal channel_released(channel: ChannelEffect, results: Array[Dictionary], was_broken: bool)

## Emitted when a counter-attack fires.
signal counter_triggered(counter: CounterEffect, results: Array[Dictionary])

## Emitted when any battlefield effect is added.
signal effect_added(effect_type: String, effect_name: String)

## Emitted when any battlefield effect expires/is removed.
signal effect_removed(effect_type: String, effect_name: String)

# ============================================================================
# STATE
# ============================================================================

var active_channels: Array[ChannelEffect] = []
var pending_counters: Array[CounterEffect] = []

# ============================================================================
# ADD EFFECTS
# ============================================================================

func add_channel(channel: ChannelEffect) -> void:
	active_channels.append(channel)
	effect_added.emit("channel", channel.channel_name)
	print("  📡 Channel started: %s (%d turns)" % [channel.channel_name, channel.max_turns])

func add_counter(counter: CounterEffect) -> void:
	pending_counters.append(counter)
	effect_added.emit("counter", counter.counter_name)
	print("  ⚔️ Counter ready: %s (%d charges)" % [counter.counter_name, counter.charges])

# ============================================================================
# TURN PROCESSING
# ============================================================================

func process_turn_start(all_enemies: Array, all_allies: Array) -> Array[Dictionary]:
	"""Process battlefield effects at turn start. Advances channels.
	Returns aggregated results for CombatManager to apply."""
	var all_results: Array[Dictionary] = []

	var completed_channels: Array[ChannelEffect] = []
	for channel in active_channels:
		if not channel.advance_turn():
			completed_channels.append(channel)

	for channel in completed_channels:
		var results = _release_channel(channel, all_enemies, all_allies)
		all_results.append_array(results)

	return all_results

func process_turn_end() -> void:
	"""Clean up expired counters at turn end."""
	var expired_counters: Array[CounterEffect] = []
	for counter in pending_counters:
		if counter.is_expired:
			expired_counters.append(counter)

	for counter in expired_counters:
		pending_counters.erase(counter)
		effect_removed.emit("counter", counter.counter_name)
		print("  ⚔️ Counter expired: %s" % counter.counter_name)

# ============================================================================
# EVENT HOOKS
# ============================================================================

func on_damage_taken(target, attacker, damage: int,
		all_enemies: Array, all_allies: Array) -> Array[Dictionary]:
	"""Called when target takes damage. Checks counters owned by target.
	Returns counter-attack results for CombatManager to apply to the attacker."""
	var all_results: Array[Dictionary] = []
	var expired_counters: Array[CounterEffect] = []

	for counter in pending_counters:
		if counter.owner != target:
			continue
		if counter.try_trigger(damage):
			print("  ⚔️ Counter fired: %s (%d damage triggered)" % [
				counter.counter_name, damage])
			if counter.counter_effect:
				var results = counter.counter_effect.execute(
					target, [attacker], [])
				for r in results:
					r["_counter_name"] = counter.counter_name
					r["_battlefield_source"] = "counter"
				all_results.append_array(results)
				counter_triggered.emit(counter, results)
			if counter.is_expired:
				expired_counters.append(counter)

	for counter in expired_counters:
		pending_counters.erase(counter)
		effect_removed.emit("counter", counter.counter_name)

	return all_results

# ============================================================================
# CHANNEL MANAGEMENT
# ============================================================================

func break_channel_by_owner(owner) -> Array[Dictionary]:
	"""Break all channels owned by a combatant (e.g., they took damage).
	Broken channels release at half power."""
	var results: Array[Dictionary] = []
	var broken: Array[ChannelEffect] = []
	for channel in active_channels:
		if channel.owner == owner and not channel.is_complete:
			channel.break_channel()
			broken.append(channel)
	for channel in broken:
		results.append_array(_release_channel(channel, [], []))
	return results

func _release_channel(channel: ChannelEffect,
		all_enemies: Array, all_allies: Array) -> Array[Dictionary]:
	"""Release a channel effect with accumulated multiplier."""
	var results: Array[Dictionary] = []

	if channel.release_effect:
		var multiplier = channel.get_current_multiplier()
		if channel.was_broken:
			multiplier *= 0.5

		var targets: Array = all_enemies if not all_enemies.is_empty() else [null]
		var release_results = channel.release_effect.execute(
			channel.owner, targets, [])

		for r in release_results:
			if r.has("damage"):
				r["damage"] = int(r["damage"] * multiplier)
			if r.has("heal"):
				r["heal"] = int(r["heal"] * multiplier)
			r["_channel_name"] = channel.channel_name
			r["_channel_multiplier"] = multiplier
			r["_channel_was_broken"] = channel.was_broken
			r["_battlefield_source"] = "channel"
		results.append_array(release_results)

		channel_released.emit(channel, release_results, channel.was_broken)
		print("  📡 Channel %s: %s at x%.1f" % [
			"broken" if channel.was_broken else "released",
			channel.channel_name, multiplier])

	active_channels.erase(channel)
	effect_removed.emit("channel", channel.channel_name)
	return results

# ============================================================================
# QUERIES
# ============================================================================

func has_active_channels() -> bool: return active_channels.size() > 0
func has_pending_counters() -> bool: return pending_counters.size() > 0
func has_any_effects() -> bool: return has_active_channels() or has_pending_counters()

func get_channel_count() -> int: return active_channels.size()
func get_counter_count() -> int: return pending_counters.size()

func get_channel_by_owner(owner) -> ChannelEffect:
	for channel in active_channels:
		if channel.owner == owner and not channel.is_complete:
			return channel
	return null

func get_counters_by_owner(owner) -> Array[CounterEffect]:
	var result: Array[CounterEffect] = []
	for counter in pending_counters:
		if counter.owner == owner and not counter.is_expired:
			result.append(counter)
	return result

# ============================================================================
# CLEANUP
# ============================================================================

func clear_all() -> void:
	active_channels.clear()
	pending_counters.clear()

func _to_string() -> String:
	return "BattlefieldTracker<channels=%d, counters=%d>" % [
		active_channels.size(), pending_counters.size()]
