# res://resources/data/enemy_data.gd
# Enemy configuration resource with drag-and-drop dice and actions
extends Resource
class_name EnemyData

# ============================================================================
# IDENTITY
# ============================================================================
@export_group("Identity")
@export var enemy_name: String = "Enemy"
@export_multiline var description: String = "A hostile creature."
@export var portrait: Texture2D = null
@export var sprite_texture: Texture2D = null

# ============================================================================
# STATS
# ============================================================================
@export_group("Stats")
@export var max_health: int = 50
@export var base_armor: int = 0
@export var base_barrier: int = 0

# ============================================================================
# DICE - Drag and drop DieResource assets here!
# ============================================================================
@export_group("Dice Pool")
## Dice this enemy starts combat with. Drag DieResource files here.
@export var starting_dice: Array[DieResource] = []

# ============================================================================
# ACTIONS - Drag and drop Action resources here!
# ============================================================================
@export_group("Combat Actions")
## Actions this enemy can perform. Drag Action resource files here.
@export var combat_actions: Array[Action] = []

# ============================================================================
# AI BEHAVIOR
# ============================================================================
@export_group("AI Settings")

enum AIStrategy {
	AGGRESSIVE,
	DEFENSIVE,
	BALANCED,
	RANDOM
}

@export var ai_strategy: AIStrategy = AIStrategy.BALANCED

enum TargetPriority {
	LOWEST_HEALTH,
	HIGHEST_HEALTH,
	RANDOM
}

@export var target_priority: TargetPriority = TargetPriority.RANDOM

@export_subgroup("Timing")
@export_range(0.3, 2.0, 0.1) var action_delay: float = 0.8
@export_range(0.2, 1.0, 0.1) var dice_drag_duration: float = 0.4



# ============================================================================
# VISUAL EVENTS
# ============================================================================
@export_group("Visual Events")

## Default attack effect (enemy → player). Used when action has no confirm_event.
@export var attack_event: CombatVisualEvent = null

## Effect when this enemy takes damage (flash/impact on self)
@export var hit_event: CombatVisualEvent = null

## Effect when this enemy dies
@export var death_event: CombatVisualEvent = null


# ============================================================================
# REWARDS
# ============================================================================
@export_group("Rewards")
@export var experience_reward: int = 10
@export var gold_reward_min: int = 5
@export var gold_reward_max: int = 15
@export var loot_table_id: String = ""

# ============================================================================
# UTILITY METHODS
# ============================================================================

func get_actions_as_dicts() -> Array[Dictionary]:
	"""Convert Action resources to dictionaries for combat system"""
	var result: Array[Dictionary] = []
	
	for action in combat_actions:
		if action:
			var dict = action.to_dict()
			dict["source"] = enemy_name
			result.append(dict)
	
	return result

func create_dice_copies() -> Array[DieResource]:
	"""Create fresh copies of starting dice for a combat instance"""
	var copies: Array[DieResource] = []
	
	for die_template in starting_dice:
		if die_template:
			var die_copy = die_template.duplicate_die()
			die_copy.source = enemy_name
			copies.append(die_copy)
	
	return copies

func get_gold_reward() -> int:
	"""Roll gold reward within range"""
	return randi_range(gold_reward_min, gold_reward_max)

func _to_string() -> String:
	return "EnemyData<%s, HP:%d, Dice:%d, Actions:%d>" % [
		enemy_name, max_health, starting_dice.size(), combat_actions.size()
	]
