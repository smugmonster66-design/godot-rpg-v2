# res://scripts/game/enemy_ai.gd
# Simple AI decision making for enemy turns
extends RefCounted
class_name EnemyAI

# AI Strategy constants (match combatant.gd export enum)
const AGGRESSIVE = 0
const DEFENSIVE = 1
const BALANCED = 2
const RANDOM = 3

# ============================================================================
# DECISION RESULT
# ============================================================================

class Decision:
	var action: Dictionary = {}
	var dice: Array[DieResource] = []
	var score: float = 0.0

# ============================================================================
# MAIN DECISION FUNCTION
# ============================================================================

static func decide(actions: Array, available_dice: Array[DieResource], strategy: int) -> Decision:
	"""Decide what action to take with available dice"""
	
	if available_dice.size() == 0 or actions.size() == 0:
		return null
	
	var candidates: Array[Decision] = []
	
	for action in actions:
		var required = action.get("die_slots", 1)
		
		# Can we afford this action?
		if available_dice.size() < required:
			continue
		
		# Select dice for this action
		var selected_dice = _select_dice(available_dice, required, strategy)
		
		if selected_dice.size() < required:
			continue
		
		# Create decision
		var decision = Decision.new()
		decision.action = action
		decision.dice = selected_dice
		decision.score = _score_action(action, selected_dice, strategy)
		
		candidates.append(decision)
	
	if candidates.size() == 0:
		return null
	
	# Pick best (or random)
	if strategy == RANDOM:
		return candidates[randi() % candidates.size()]
	
	# Sort by score descending
	candidates.sort_custom(func(a, b): return a.score > b.score)
	return candidates[0]

# ============================================================================
# DICE SELECTION
# ============================================================================

static func _select_dice(available: Array[DieResource], count: int, strategy: int) -> Array[DieResource]:
	"""Select dice for an action based on strategy"""
	
	var sorted = available.duplicate()
	
	match strategy:
		AGGRESSIVE:
			# Use highest dice
			sorted.sort_custom(func(a, b): return a.get_total_value() > b.get_total_value())
		DEFENSIVE:
			# Use lowest dice (save high ones)
			sorted.sort_custom(func(a, b): return a.get_total_value() < b.get_total_value())
		BALANCED:
			# Use medium dice
			var avg = 0.0
			for die in sorted:
				avg += die.get_total_value()
			avg /= sorted.size() if sorted.size() > 0 else 1
			sorted.sort_custom(func(a, b): 
				return abs(a.get_total_value() - avg) < abs(b.get_total_value() - avg)
			)
		RANDOM:
			sorted.shuffle()
	
	var result: Array[DieResource] = []
	for i in range(min(count, sorted.size())):
		result.append(sorted[i])
	return result

# ============================================================================
# ACTION SCORING
# ============================================================================

static func _score_action(action: Dictionary, dice: Array[DieResource], strategy: int) -> float:
	"""Score how good this action choice is"""
	
	var base = action.get("base_damage", 0)
	var mult = action.get("damage_multiplier", 1.0)
	var action_type = action.get("action_type", 0)
	
	var dice_total = 0
	for die in dice:
		dice_total += die.get_total_value()
	
	var value = base + int(dice_total * mult)
	
	match strategy:
		AGGRESSIVE:
			# Prefer attacks
			if action_type == 0:  # ATTACK
				return value * 1.5
			return value * 0.5
		
		DEFENSIVE:
			# Prefer defense/heals
			if action_type == 1:  # DEFEND
				return value * 1.5
			if action_type == 2:  # HEAL
				return value * 1.3
			return value * 0.7
		
		BALANCED:
			return value
		
		RANDOM:
			return randf() * 100.0
	
	return value
