# res://scripts/combat/threat_tracker.gd
# Per-enemy threat tracking for intelligent target selection.
# Each enemy maintains their own threat table of player + companions.
#
# USAGE:
#   var tracker = ThreatTracker.new()
#   tracker.initialize([player, companion1, companion2])
#   tracker.add_damage_threat(player, 50)  # Player dealt 50 damage
#   tracker.apply_decay()  # Call at round end
#   var target = tracker.get_highest_threat_target()
extends RefCounted
class_name ThreatTracker

# ============================================================================
# THREAT TABLE
# ============================================================================

## Threat values by combatant: {Combatant: float}
var threat_table: Dictionary = {}

# ============================================================================
# THREAT WEIGHTS
# ============================================================================

## Direct damage threat multiplier
const DAMAGE_WEIGHT: float = 1.0

## Healing threat multiplier
const HEALING_WEIGHT: float = 0.75

## Status application base threat values
const STATUS_BASE: Dictionary = {
	"dot": 15.0,      # Burn, Bleed, Poison per stack
	"control": 30.0,  # Stun, Freeze, Root per stack
	"debuff": 20.0,   # Weakness, Vulnerable, Armor Break per stack
	"buff": 10.0,     # Strength, Barrier, Regen per stack (on allies)
}

## Proc bonus damage threat multiplier
const PROC_WEIGHT: float = 0.5

## Granted action threat value
const GRANTED_ACTION_THREAT: float = 25.0

## Temp affix threat value
const TEMP_AFFIX_THREAT: float = 15.0

## Per-round threat decay multiplier (90% retention)
const DECAY_RATE: float = 0.9

## Base threat for player (default priority)
const BASE_PLAYER_THREAT: float = 10.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(allies: Array[Combatant]) -> void:
	"""Initialize threat table with all current allies.
	Player starts with base threat, companions start at 0."""
	threat_table.clear()
	
	for ally in allies:
		if not ally or not ally.is_alive():
			continue
		
		# Player gets base threat (default priority)
		if ally.combatant_name == "Player":
			threat_table[ally] = BASE_PLAYER_THREAT
		else:
			threat_table[ally] = 0.0

# ============================================================================
# THREAT MODIFICATION
# ============================================================================

func add_damage_threat(source: Combatant, damage: int) -> void:
	"""Add threat from dealing damage."""
	if not source or source not in threat_table:
		return
	
	var threat = damage * DAMAGE_WEIGHT
	threat_table[source] += threat
	print("  [Threat] %s +%.1f (damage)" % [source.combatant_name, threat])


func add_healing_threat(source: Combatant, healing: int) -> void:
	"""Add threat from healing."""
	if not source or source not in threat_table:
		return
	
	var threat = healing * HEALING_WEIGHT
	threat_table[source] += threat
	print("  [Threat] %s +%.1f (healing)" % [source.combatant_name, threat])


func add_status_threat(source: Combatant, status_type: String, stacks: int) -> void:
	"""Add threat from applying status effects.
	
	Args:
		source: Who applied the status.
		status_type: One of 'dot', 'control', 'debuff', 'buff'
		stacks: Number of stacks applied.
	"""
	if not source or source not in threat_table:
		return
	
	if status_type not in STATUS_BASE:
		return
	
	var threat = STATUS_BASE[status_type] * stacks
	threat_table[source] += threat
	print("  [Threat] %s +%.1f (%s x%d)" % [source.combatant_name, threat, status_type, stacks])


func add_proc_threat(source: Combatant, bonus_damage: int) -> void:
	"""Add threat from proc bonus damage."""
	if not source or source not in threat_table:
		return
	
	var threat = bonus_damage * PROC_WEIGHT
	threat_table[source] += threat
	print("  [Threat] %s +%.1f (proc)" % [source.combatant_name, threat])


func add_granted_action_threat(source: Combatant) -> void:
	"""Add threat from granting a temporary action."""
	if not source or source not in threat_table:
		return
	
	threat_table[source] += GRANTED_ACTION_THREAT
	print("  [Threat] %s +%.1f (granted action)" % [source.combatant_name, GRANTED_ACTION_THREAT])


func add_temp_affix_threat(source: Combatant) -> void:
	"""Add threat from applying a temporary affix."""
	if not source or source not in threat_table:
		return
	
	threat_table[source] += TEMP_AFFIX_THREAT
	print("  [Threat] %s +%.1f (temp affix)" % [source.combatant_name, TEMP_AFFIX_THREAT])

# ============================================================================
# THREAT DECAY
# ============================================================================

func apply_decay() -> void:
	"""Decay all threat by 10% per round. Called at round end."""
	for combatant in threat_table:
		var old_threat = threat_table[combatant]
		threat_table[combatant] *= DECAY_RATE
		
		if old_threat > 0.1:  # Only log significant changes
			print("  [Threat] %s: %.1f → %.1f (decay)" % [
				combatant.combatant_name, old_threat, threat_table[combatant]])

# ============================================================================
# COMBATANT MANAGEMENT
# ============================================================================

func add_combatant(combatant: Combatant, initial_threat: float = 0.0) -> void:
	"""Add a new combatant to the threat table (e.g., summon spawned mid-combat)."""
	if combatant and combatant not in threat_table:
		threat_table[combatant] = initial_threat
		print("  [Threat] Added %s with %.1f threat" % [combatant.combatant_name, initial_threat])


func remove_combatant(combatant: Combatant) -> void:
	"""Remove a dead/expired combatant from the threat table."""
	if combatant in threat_table:
		threat_table.erase(combatant)
		print("  [Threat] Removed %s from threat table" % combatant.combatant_name)

# ============================================================================
# THREAT QUERIES
# ============================================================================

func get_threat(combatant: Combatant) -> float:
	"""Get current threat value for a combatant."""
	return threat_table.get(combatant, 0.0)


func get_highest_threat_target() -> Combatant:
	"""Get the alive combatant with the highest threat.
	Returns null if no valid targets."""
	var highest: Combatant = null
	var highest_threat: float = -1.0
	
	for combatant in threat_table:
		if not combatant or not is_instance_valid(combatant) or not combatant.is_alive():
			continue
		
		var threat = threat_table[combatant]
		if threat > highest_threat:
			highest_threat = threat
			highest = combatant
	
	return highest


func get_all_targets_sorted() -> Array[Combatant]:
	"""Get all alive targets sorted by threat (highest first)."""
	var alive: Array[Combatant] = []
	
	for combatant in threat_table:
		if combatant and is_instance_valid(combatant) and combatant.is_alive():
			alive.append(combatant)
	
	alive.sort_custom(func(a, b): return get_threat(a) > get_threat(b))
	return alive

# ============================================================================
# DEBUG
# ============================================================================

func print_threat_table() -> void:
	"""Debug print of current threat values."""
	print("  [Threat Table]")
	for combatant in threat_table:
		print("    %s: %.1f%s" % [
			combatant.combatant_name,
			threat_table[combatant],
			" (DEAD)" if not combatant.is_alive() else ""
		])
