# res://scripts/resources/status.gd
# Defines a status condition that can be applied to combatants
extends Resource
class_name Status

# ============================================================================
# BASIC INFO
# ============================================================================
@export var status_id: String = ""
@export var status_name: String = "New Status"
@export_multiline var description: String = ""
@export var icon: Texture2D = null

# ============================================================================
# STACK CONFIGURATION
# ============================================================================
@export_group("Stacking")
@export var max_stacks: int = 10
@export var default_duration: int = 3  ## Turns until expires (0 = infinite)
@export var stacks_decay_per_turn: int = 0  ## Stacks lost per turn (0 = none)

# ============================================================================
# BEHAVIOR
# ============================================================================
@export_group("Behavior")
@export var is_debuff: bool = true  ## True = harmful, False = beneficial
@export var can_be_cleansed: bool = true
@export var is_unique: bool = false  ## If true, only one instance allowed

# ============================================================================
# EFFECT
# ============================================================================
@export_group("Effect")
@export var status_effect: StatusEffect = null

# ============================================================================
# METHODS
# ============================================================================

func create_instance(initial_stacks: int = 1) -> Dictionary:
	"""Create a runtime status instance"""
	return {
		"status": self,
		"stacks": mini(initial_stacks, max_stacks),
		"duration": default_duration,
		"source": ""
	}

func _to_string() -> String:
	return "Status<%s>" % status_name
