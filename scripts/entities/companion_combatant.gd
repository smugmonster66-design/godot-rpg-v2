# res://scripts/entities/companion_combatant.gd
# A Combatant subclass for companions (NPC and Summon).
# Does NOT take turns — reactive only. Managed by CompanionManager.
extends Combatant
class_name CompanionCombatant

# ============================================================================
# COMPANION DATA
# ============================================================================
var companion_data: CompanionData = null
var companion_instance: CompanionInstance = null  # null for summons
var slot_index: int = -1  # 0-1 = NPC, 2-3 = Summon

# ============================================================================
# COMPANION FLAGS
# ============================================================================
var is_companion: bool = true
var is_summon: bool = false

# ============================================================================
# COMBAT STATE
# ============================================================================
var cooldown_remaining: int = 0
var uses_remaining: int = -1  # -1 = unlimited
var turns_active: int = 0     # for duration tracking (summons)

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize_from_data(data: CompanionData, p_slot_index: int,
		player_max_hp: int, player_level: int,
		instance: CompanionInstance = null) -> void:
	"""Set up this combatant from a CompanionData resource."""
	companion_data = data
	companion_instance = instance
	slot_index = p_slot_index
	is_summon = (data.companion_type == CompanionData.CompanionType.SUMMON)
	is_player_controlled = false  # companions are AI-driven (reactive)

	# Identity
	combatant_name = data.companion_name

	# Health
	max_health = data.calculate_max_hp(player_max_hp, player_level)
	if instance and not instance.is_dead and instance.current_hp > 0:
		# Restore persisted HP for NPC companions
		current_health = mini(instance.current_hp, max_health)
	else:
		current_health = max_health

	# Limits
	if data.uses_per_combat > 0:
		uses_remaining = data.uses_per_combat
	else:
		uses_remaining = -1

	cooldown_remaining = 0
	turns_active = 0

	

	update_display()
	print("  [Companion] CompanionCombatant initialized: %s (slot %d, HP %d/%d, %s)" % [
		combatant_name, slot_index, current_health, max_health,
		"summon" if is_summon else "NPC"])

# ============================================================================
# TAUNT
# ============================================================================

func is_taunting() -> bool:
	"""Check if this companion is currently taunting via StatusTracker."""
	if not is_alive():
		return false
	
	# Check StatusTracker for active taunt status
	if has_node("StatusTracker"):
		var tracker: StatusTracker = get_node("StatusTracker")
		return tracker.has_status("taunt")
	
	return false


# ============================================================================
# COOLDOWN & USAGE
# ============================================================================

func can_fire() -> bool:
	"""Check if this companion can fire its trigger action."""
	if not is_alive():
		return false
	if cooldown_remaining > 0:
		return false
	if uses_remaining == 0:
		return false
	return true

func on_fired() -> void:
	"""Called after the companion's action fires."""
	if companion_data.cooldown_turns > 0:
		cooldown_remaining = companion_data.cooldown_turns
	if uses_remaining > 0:
		uses_remaining -= 1

func tick_cooldown() -> void:
	"""Reduce cooldown by 1. Called once per round."""
	if cooldown_remaining > 0:
		cooldown_remaining -= 1

# ============================================================================
# DURATION (summons)
# ============================================================================

func tick_duration() -> bool:
	"""Tick summon duration. Returns true if the summon has expired."""
	if not is_summon:
		return false
	if companion_data.duration_turns <= 0:
		return false  # infinite duration
	turns_active += 1
	return turns_active >= companion_data.duration_turns

# ============================================================================
# SYNC TO INSTANCE
# ============================================================================

func sync_to_instance() -> void:
	"""Write current combat state back to the persistent CompanionInstance.
	Called at combat end for NPC companions."""
	if companion_instance:
		companion_instance.current_hp = current_health
		companion_instance.is_dead = not is_alive()
