# res://scripts/resources/status_effect.gd
# Defines what a status effect does when applied/ticked/removed
extends Resource
class_name StatusEffect

# ============================================================================
# BASIC INFO
# ============================================================================
@export var effect_id: String = ""
@export var effect_name: String = "New Status Effect"
@export_multiline var description: String = ""

# ============================================================================
# TIMING
# ============================================================================
enum TickTiming {
	START_OF_TURN,
	END_OF_TURN,
	ON_ACTION,
	ON_DAMAGE_TAKEN,
	ON_HEAL_RECEIVED
}

@export var tick_timing: TickTiming = TickTiming.START_OF_TURN

# ============================================================================
# EFFECT VALUES (to be expanded later)
# ============================================================================
@export_group("Effect Values")
@export var damage_per_stack: int = 0
@export var heal_per_stack: int = 0
@export var stat_modifier_per_stack: Dictionary = {}  # {"strength": -2}

# ============================================================================
# PLACEHOLDER METHODS
# ============================================================================

func apply_tick(target, stacks: int) -> Dictionary:
	"""Called each tick - returns result dictionary"""
	var result = {
		"damage": damage_per_stack * stacks,
		"heal": heal_per_stack * stacks,
		"stat_changes": {}
	}
	
	for stat in stat_modifier_per_stack:
		result["stat_changes"][stat] = stat_modifier_per_stack[stat] * stacks
	
	return result

func _to_string() -> String:
	return "StatusEffect<%s>" % effect_name
