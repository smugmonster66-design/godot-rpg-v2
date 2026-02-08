# res://resources/data/status_affix.gd
# Status conditions as a subset of the Affix system.
# Each status IS an Affix, so the AffixPoolManager can query it
# alongside equipment affixes for unified stat calculations.
extends Affix
class_name StatusAffix

# ============================================================================
# ENUMS
# ============================================================================

enum DurationType {
	STACK_BASED,    ## No turn timer — lives/dies by stacks (Poison, Bleed, Chill)
	TURN_BASED,     ## Has amount + turn duration (Burn, Slowed, Stunned)
	PERMANENT       ## Never expires naturally (removed only by cleanse/ability)
}

enum DecayStyle {
	NONE,           ## Stacks don't decay on their own
	FLAT,           ## Lose decay_amount stacks per tick
	HALVING,        ## Stacks halve each tick, clearing at 1
}

enum TickTiming {
	START_OF_TURN,
	END_OF_TURN,
	ON_HIT,         ## When the afflicted combatant lands a hit
	ON_DAMAGED,     ## When the afflicted combatant takes damage
	ON_HEAL,        ## When the afflicted combatant receives healing
}

enum StatusDamageType {
	NONE,
	PHYSICAL,
	MAGICAL,
}

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Status Identity")
## Unique key used for lookups and save/load (e.g. "poison", "burn")
@export var status_id: String = ""

# ============================================================================
# DURATION & STACKING
# ============================================================================
@export_group("Duration & Stacking")
@export var duration_type: DurationType = DurationType.STACK_BASED
## Default turn duration when applied (only relevant for TURN_BASED)
@export var default_duration: int = 3
## Maximum stacks allowed
@export var max_stacks: int = 99
## Whether reapplying refreshes the turn duration
@export var refresh_on_reapply: bool = true

# ============================================================================
# DECAY
# ============================================================================
@export_group("Decay")
@export var decay_style: DecayStyle = DecayStyle.NONE
## Stacks lost per tick when decay_style is FLAT
@export var decay_amount: int = 1
## If true, status is fully removed at the start of each turn (Block/Dodge)
@export var falls_off_between_turns: bool = false

# ============================================================================
# TIMING
# ============================================================================
@export_group("Timing")
## When the status ticks (deals damage, applies stat mods, etc.)
@export var tick_timing: TickTiming = TickTiming.START_OF_TURN
## When remaining_turns decrements and expiry is checked
@export var expire_timing: TickTiming = TickTiming.END_OF_TURN

# ============================================================================
# CLASSIFICATION & CLEANSE
# ============================================================================
@export_group("Classification")
## True = harmful to the target, False = beneficial
@export var is_debuff: bool = true
## Whether cleanse effects can remove this status
@export var can_be_cleansed: bool = true
## Tags that cleanse effects can match against.
## Convention: always include "debuff" or "buff" plus specifics.
## Examples: ["debuff", "dot", "poison", "physical_dot"]
##           ["buff", "block", "defensive"]
@export var cleanse_tags: Array[String] = []

# ============================================================================
# TICK EFFECT — DAMAGE / HEAL
# ============================================================================
@export_group("Tick Effect")
## Damage dealt per stack each tick (0 = no tick damage)
@export var damage_per_stack: int = 0
## Whether tick damage is physical or magical
@export var tick_damage_type: StatusDamageType = StatusDamageType.NONE
## Healing per stack each tick (0 = no tick healing)
@export var heal_per_stack: int = 0

# ============================================================================
# TICK EFFECT — STAT MODIFIERS
# ============================================================================
@export_group("Stat Modifiers")
## Per-stack stat modifications applied while active.
## Keys should match stat keys used by the combat calculator.
## Example: {"armor": -2} means -2 armor per stack
@export var stat_modifier_per_stack: Dictionary = {}

# ============================================================================
# INSTANCE FACTORY
# ============================================================================

func create_instance(initial_stacks: int = 1, p_source: String = "") -> Dictionary:
	"""Create a runtime status instance dictionary.
	
	Args:
		initial_stacks: Starting stack count.
		p_source: Name of the combatant/item/ability that applied this.
	
	Returns:
		Dictionary representing an active status on a combatant.
	"""
	return {
		"status_affix": self,
		"current_stacks": mini(initial_stacks, max_stacks),
		"remaining_turns": default_duration if duration_type == DurationType.TURN_BASED else -1,
		"source_name": p_source,
	}

# ============================================================================
# STACK MANAGEMENT
# ============================================================================

func add_stacks(instance: Dictionary, amount: int) -> void:
	"""Add stacks to an existing instance (additive). Refreshes duration if configured."""
	instance["current_stacks"] = mini(
		instance["current_stacks"] + amount,
		max_stacks
	)
	if refresh_on_reapply and duration_type == DurationType.TURN_BASED:
		instance["remaining_turns"] = default_duration

func remove_stacks(instance: Dictionary, amount: int) -> void:
	"""Remove stacks from an instance. Passing 0 removes all."""
	if amount <= 0:
		instance["current_stacks"] = 0
	else:
		instance["current_stacks"] = maxi(instance["current_stacks"] - amount, 0)

# ============================================================================
# TICK LOGIC
# ============================================================================

func apply_tick(instance: Dictionary) -> Dictionary:
	"""Process one tick of this status. Returns a result dictionary.
	
	Called by StatusTracker at the appropriate TickTiming.
	Does NOT handle decay or expiry — that's StatusTracker's job.
	"""
	var stacks: int = instance["current_stacks"]
	var result: Dictionary = {
		"status_id": status_id,
		"status_name": affix_name,
		"stacks": stacks,
		"damage": damage_per_stack * stacks,
		"damage_is_magical": tick_damage_type == StatusDamageType.MAGICAL,
		"heal": heal_per_stack * stacks,
		"stat_changes": {},
	}
	
	for stat_key in stat_modifier_per_stack:
		result["stat_changes"][stat_key] = stat_modifier_per_stack[stat_key] * stacks
	
	return result

func apply_decay(instance: Dictionary) -> void:
	"""Apply stack decay based on decay_style. Called after tick."""
	match decay_style:
		DecayStyle.FLAT:
			instance["current_stacks"] = maxi(
				instance["current_stacks"] - decay_amount, 0
			)
		DecayStyle.HALVING:
			var before: int = instance["current_stacks"]
			if before <= 1:
				instance["current_stacks"] = 0
			else:
				instance["current_stacks"] = ceili(before / 2.0)
		DecayStyle.NONE:
			pass

func decrement_duration(instance: Dictionary) -> void:
	"""Reduce remaining turns by 1 for TURN_BASED statuses."""
	if duration_type == DurationType.TURN_BASED and instance["remaining_turns"] > 0:
		instance["remaining_turns"] -= 1

func is_expired(instance: Dictionary) -> bool:
	"""Check if this instance should be removed."""
	if instance["current_stacks"] <= 0:
		return true
	if duration_type == DurationType.TURN_BASED and instance["remaining_turns"] <= 0:
		return true
	return false

# ============================================================================
# CLEANSE MATCHING
# ============================================================================

func matches_any_cleanse_tag(tags: Array[String]) -> bool:
	"""Check if any of the provided cleanse tags match this status."""
	if not can_be_cleansed:
		return false
	for tag in tags:
		if tag in cleanse_tags:
			return true
	return false

# ============================================================================
# QUERY HELPERS (for combat calculator integration)
# ============================================================================

func get_stat_modifier_total(instance: Dictionary, stat_key: String) -> float:
	"""Get the total modifier for a specific stat from this instance."""
	if stat_key in stat_modifier_per_stack:
		return stat_modifier_per_stack[stat_key] * instance["current_stacks"]
	return 0.0

func get_total_tick_damage(instance: Dictionary) -> int:
	"""Get total tick damage for current stacks."""
	return damage_per_stack * instance["current_stacks"]

func get_total_tick_heal(instance: Dictionary) -> int:
	"""Get total tick healing for current stacks."""
	return heal_per_stack * instance["current_stacks"]

# ============================================================================
# DISPLAY
# ============================================================================

func get_instance_tooltip(instance: Dictionary) -> String:
	"""Generate tooltip text for a status instance."""
	var parts: Array[String] = []
	parts.append(affix_name)
	parts.append("Stacks: %d / %d" % [instance["current_stacks"], max_stacks])
	
	if duration_type == DurationType.TURN_BASED:
		parts.append("Turns remaining: %d" % instance["remaining_turns"])
	
	if damage_per_stack > 0:
		var dmg_type_str: String = "magical" if tick_damage_type == StatusDamageType.MAGICAL else "physical"
		parts.append("%d %s damage per tick" % [
			damage_per_stack * instance["current_stacks"], dmg_type_str
		])
	
	if heal_per_stack > 0:
		parts.append("%d healing per tick" % [heal_per_stack * instance["current_stacks"]])
	
	for stat_key in stat_modifier_per_stack:
		var total: float = stat_modifier_per_stack[stat_key] * instance["current_stacks"]
		var sign_str: String = "+" if total >= 0 else ""
		parts.append("%s%d %s" % [sign_str, int(total), stat_key])
	
	if description:
		parts.append(description)
	
	return "\n".join(parts)

# ============================================================================
# UTILITY
# ============================================================================

func _to_string() -> String:
	var type_str: String
	match duration_type:
		DurationType.STACK_BASED: type_str = "Stack"
		DurationType.TURN_BASED: type_str = "Turn"
		DurationType.PERMANENT: type_str = "Perm"
		_: type_str = "?"
	return "StatusAffix<%s [%s] %s>" % [affix_name, status_id, type_str]
