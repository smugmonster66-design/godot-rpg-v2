# res://scripts/game/companion_manager.gd
# Manages all companion slots during combat.
# Child of CombatManager. Handles spawn, despawn, HP sync, and queries.
extends Node
class_name CompanionManager

# ============================================================================
# CONSTANTS
# ============================================================================
const MAX_NPC_SLOTS: int = 2
const MAX_SUMMON_SLOTS: int = 2
const TOTAL_SLOTS: int = 4  # NPC 0-1, Summon 2-3

# ============================================================================
# STATE
# ============================================================================
var _slots: Array = [null, null, null, null]  # CompanionCombatant or null
var _player: Player = null
var _combat_manager = null  # set by parent

# ============================================================================
# SIGNALS
# ============================================================================
signal companion_spawned(companion: CompanionCombatant, slot_index: int)
signal companion_died(companion: CompanionCombatant, slot_index: int)
signal companion_removed(slot_index: int)
signal taunt_state_changed()

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(player: Player, combat_manager) -> void:
	"""Called by CombatManager._finalize_combat_init() after enemies spawn."""
	_player = player
	_combat_manager = combat_manager
	_clear_all_slots()

	print("[Companion] CompanionManager initializing...")

	# Spawn NPC companions from player roster
	for i in range(mini(player.active_companions.size(), MAX_NPC_SLOTS)):
		var instance: CompanionInstance = player.active_companions[i]
		if instance and instance.companion_data and not instance.is_dead:
			_spawn_npc(instance, i)
		elif instance and instance.is_dead:
			print("  [Companion] NPC slot %d: %s is dead — skipping" % [i, instance.get_display_name()])

	# Summon slots start empty
	print("  [Companion] Summon slots empty (filled during combat)")
	print("[Companion] CompanionManager ready (%d companions active)" % get_alive_companions().size())

# ============================================================================
# SPAWNING
# ============================================================================

func _spawn_npc(instance: CompanionInstance, npc_slot: int) -> CompanionCombatant:
	"""Spawn an NPC companion into slot 0 or 1."""
	if npc_slot < 0 or npc_slot >= MAX_NPC_SLOTS:
		push_error("CompanionManager: Invalid NPC slot %d" % npc_slot)
		return null

	# Initialize HP if this is the companion's first combat
	instance.initialize_hp(_player.max_hp, _player.level)

	var companion := CompanionCombatant.new()
	companion.name = "NPCCompanion%d" % npc_slot
	add_child(companion)

	companion.initialize_from_data(
		instance.companion_data, npc_slot,
		_player.max_hp, _player.level, instance)

	# Connect death signal
	if not companion.died.is_connected(_on_companion_died.bind(companion)):
		companion.died.connect(_on_companion_died.bind(companion))

	_slots[npc_slot] = companion
	companion_spawned.emit(companion, npc_slot)
	return companion

func summon(data: CompanionData, preferred_slot: int = -1) -> CompanionCombatant:
	"""Summon a companion into a summon slot (2 or 3).
	If preferred_slot is -1, uses the first empty slot.
	Returns null if both slots are full (caller should prompt player to choose)."""
	if data.companion_type != CompanionData.CompanionType.SUMMON:
		push_warning("CompanionManager: Tried to summon a non-SUMMON CompanionData")
		return null

	var slot := -1

	if preferred_slot >= 2 and preferred_slot <= 3 and _slots[preferred_slot] == null:
		slot = preferred_slot
	else:
		# Find first empty summon slot
		for i in range(2, TOTAL_SLOTS):
			if _slots[i] == null:
				slot = i
				break

	if slot == -1:
		# Both full — caller needs to prompt player
		return null

	var companion := CompanionCombatant.new()
	companion.name = "SummonCompanion%d" % (slot - 2)
	add_child(companion)

	companion.initialize_from_data(data, slot, _player.max_hp, _player.level)

	if not companion.died.is_connected(_on_companion_died.bind(companion)):
		companion.died.connect(_on_companion_died.bind(companion))

	_slots[slot] = companion
	companion_spawned.emit(companion, slot)
	print("  [Companion] Summoned %s into slot %d" % [data.companion_name, slot])
	return companion

func replace_summon(slot_index: int, new_data: CompanionData) -> CompanionCombatant:
	"""Replace an existing summon. The old one is destroyed (no death trigger)."""
	if slot_index < 2 or slot_index > 3:
		push_error("CompanionManager: replace_summon called on non-summon slot %d" % slot_index)
		return null

	# Remove old summon
	var old = _slots[slot_index]
	if old:
		old.died.disconnect(_on_companion_died)
		_slots[slot_index] = null
		old.queue_free()
		companion_removed.emit(slot_index)
		print("  [Companion] Removed %s from slot %d (replaced)" % [old.combatant_name, slot_index])

	# Summon new one into the freed slot
	return summon(new_data, slot_index)

# ============================================================================
# CLEANUP
# ============================================================================


func remove_summon(slot_index: int) -> void:
	"""Remove an expired or dismissed summon. No death trigger."""
	if slot_index < 2 or slot_index > 3:
		return
	var old = _slots[slot_index]
	if old:
		if old.died.is_connected(_on_companion_died):
			old.died.disconnect(_on_companion_died)
		_slots[slot_index] = null
		old.queue_free()
		companion_removed.emit(slot_index)
		print("  [Companion] Removed %s from slot %d (expired)" % [old.combatant_name, slot_index])


func on_combat_end() -> void:
	"""Called by CombatManager.end_combat(). Syncs NPC HP, clears summons."""
	# Sync NPC companion state back to persistent instances
	for i in range(MAX_NPC_SLOTS):
		var companion = _slots[i] as CompanionCombatant
		if companion:
			companion.sync_to_instance()
			print("  [Companion] Synced %s: HP %d/%d, dead=%s" % [
				companion.combatant_name,
				companion.current_health, companion.max_health,
				not companion.is_alive()])

	# Clear all slots and free nodes
	_clear_all_slots()
	print("[Companion] CompanionManager combat cleanup complete")

func _clear_all_slots() -> void:
	"""Free all companion nodes and clear slot array."""
	for i in range(TOTAL_SLOTS):
		var companion = _slots[i]
		if companion and is_instance_valid(companion):
			if companion.died.is_connected(_on_companion_died):
				companion.died.disconnect(_on_companion_died)
			companion.queue_free()
		_slots[i] = null

# ============================================================================
# DEATH HANDLING
# ============================================================================

func _on_companion_died(companion: CompanionCombatant) -> void:
	"""Handle a companion reaching 0 HP."""
	var slot = companion.slot_index
	print("  [Death] Companion %s died (slot %d)" % [companion.combatant_name, slot])

	# If taunting, notify taunt state changed
	if companion.is_taunting():
		taunt_state_changed.emit()

	companion_died.emit(companion, slot)

	# Summons are removed from slot on death
	if companion.is_summon:
		_slots[slot] = null
		companion.queue_free()
		companion_removed.emit(slot)

	# NPC companions stay in slot but are non-functional (sync handles is_dead)

# ============================================================================
# QUERIES
# ============================================================================

func get_slot(index: int) -> CompanionCombatant:
	"""Get the companion in a specific slot (or null)."""
	if index < 0 or index >= TOTAL_SLOTS:
		return null
	return _slots[index]

func get_alive_companions() -> Array[CompanionCombatant]:
	"""Get all alive companions (NPC + summons)."""
	var result: Array[CompanionCombatant] = []
	for slot in _slots:
		if slot and slot.is_alive():
			result.append(slot)
	return result

func get_alive_npcs() -> Array[CompanionCombatant]:
	"""Get alive NPC companions only."""
	var result: Array[CompanionCombatant] = []
	for i in range(MAX_NPC_SLOTS):
		if _slots[i] and _slots[i].is_alive():
			result.append(_slots[i])
	return result

func get_alive_summons() -> Array[CompanionCombatant]:
	"""Get alive summons only."""
	var result: Array[CompanionCombatant] = []
	for i in range(2, TOTAL_SLOTS):
		if _slots[i] and _slots[i].is_alive():
			result.append(_slots[i])
	return result

func get_alive_taunting() -> Array[CompanionCombatant]:
	"""Get all alive companions that are currently taunting."""
	var result: Array[CompanionCombatant] = []
	for slot in _slots:
		if slot and slot.is_taunting():
			result.append(slot)
	return result

func has_empty_summon_slot() -> bool:
	"""Check if there's a free summon slot."""
	return _slots[2] == null or _slots[3] == null

func get_all_valid_targets() -> Array[CompanionCombatant]:
	"""Get all companions that can be targeted by enemies (alive, in slot)."""
	return get_alive_companions()

func get_companion_by_combatant(combatant: Combatant) -> CompanionCombatant:
	"""Find a CompanionCombatant by its Combatant reference."""
	for slot in _slots:
		if slot == combatant:
			return slot
	return null

# ============================================================================
# TICK (called once per round)
# ============================================================================

func tick_round() -> Array[int]:
	"""Tick cooldowns and durations. Returns array of expired summon slot indices."""
	var expired: Array[int] = []
	for i in range(TOTAL_SLOTS):
		var companion = _slots[i] as CompanionCombatant
		if not companion or not companion.is_alive():
			continue

		companion.tick_cooldown()
		# REMOVED: companion.tick_taunt()  # Now handled by StatusTracker

		# Summon duration
		if companion.tick_duration():
			print("  [Companion] %s duration expired (slot %d)" % [companion.combatant_name, i])
			expired.append(i)

	return expired
