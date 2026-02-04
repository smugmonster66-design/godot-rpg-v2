# res://resources/data/action.gd
# Combat action that executes a sequence of effects
extends Resource
class_name Action

# ============================================================================
# ENUMS
# ============================================================================
enum ChargeType {
	UNLIMITED,          # Can use as many times as you have dice
	LIMITED_PER_TURN,   # Resets at start of each turn
	LIMITED_PER_COMBAT  # Only resets at start of combat
}

# ============================================================================
# BASIC INFO
# ============================================================================
@export var action_id: String = ""
@export var action_name: String = "New Action"
@export_multiline var action_description: String = ""
@export var icon: Texture2D = null

# ============================================================================
# DICE REQUIREMENTS
# ============================================================================
@export_group("Dice Requirements")
@export var die_slots: int = 1
@export var min_dice_required: int = 0

# ============================================================================
# CHARGES
# ============================================================================
@export_group("Charges")
@export var charge_type: ChargeType = ChargeType.UNLIMITED
@export var max_charges: int = 1  # Only used when charge_type != UNLIMITED

# Runtime charge tracking (not saved)
var current_charges: int = 0

# ============================================================================
# COSTS
# ============================================================================
@export_group("Costs")
@export var mana_cost: int = 0
@export var cooldown_turns: int = 0

# ============================================================================
# EFFECTS - Executed in order
# ============================================================================
@export_group("Action Effects")
@export var effects: Array[ActionEffect] = []

@export_group("Animation")
@export var animation_set: CombatAnimationSet

# ============================================================================
# LEGACY SUPPORT (for backwards compatibility)
# ============================================================================
@export_group("Legacy (Deprecated)")
@export var action_type: int = 0  # 0=Attack, 1=Defend, 2=Heal, 3=Special
@export var action_category: int = 0 
@export var base_damage: int = 0
@export var damage_multiplier: float = 1.0

# ============================================================================
# CHARGE MANAGEMENT
# ============================================================================

func reset_charges_for_combat():
	"""Reset charges at combat start"""
	if charge_type == ChargeType.UNLIMITED:
		current_charges = -1  # -1 means unlimited
	else:
		current_charges = max_charges

func reset_charges_for_turn():
	"""Reset per-turn charges at turn start"""
	if charge_type == ChargeType.LIMITED_PER_TURN:
		current_charges = max_charges

func has_charges() -> bool:
	"""Check if action can be used"""
	if charge_type == ChargeType.UNLIMITED:
		return true
	return current_charges > 0

func consume_charge() -> bool:
	"""Use one charge, returns true if successful"""
	if charge_type == ChargeType.UNLIMITED:
		return true
	
	if current_charges > 0:
		current_charges -= 1
		return true
	return false

func get_charges_display() -> String:
	"""Get charge display string for UI"""
	match charge_type:
		ChargeType.UNLIMITED:
			return ""  # No display needed
		ChargeType.LIMITED_PER_TURN:
			return "%d/%d" % [current_charges, max_charges]
		ChargeType.LIMITED_PER_COMBAT:
			return "%d/%d" % [current_charges, max_charges]
		_:
			return ""

func get_charge_type_label() -> String:
	"""Get label describing charge type"""
	match charge_type:
		ChargeType.UNLIMITED:
			return ""
		ChargeType.LIMITED_PER_TURN:
			return "Per Turn"
		ChargeType.LIMITED_PER_COMBAT:
			return "Per Combat"
		_:
			return ""

# ============================================================================
# CONVERSION
# ============================================================================

func to_dict() -> Dictionary:
	"""Convert action to dictionary for combat system compatibility"""
	return {
		"id": action_id,
		"name": action_name,
		"description": action_description,
		"icon": icon,
		"die_slots": die_slots,
		"min_dice_required": min_dice_required,
		"mana_cost": mana_cost,
		"cooldown": cooldown_turns,
		"effects": effects,
		# Charge info
		"charge_type": charge_type,
		"max_charges": max_charges,
		"current_charges": current_charges,
		"action_resource": self,  # Include reference to self
		# Legacy fields for backward compatibility
		"action_type": action_type,
		"base_damage": base_damage,
		"damage_multiplier": damage_multiplier,
		"animation_set": animation_set,
		"source": "action"
	}

# ============================================================================
# EXECUTION
# ============================================================================

func execute(source, target_resolver: Callable, dice_values: Array = []) -> Array[Dictionary]:
	"""Execute all effects in order"""
	var all_results: Array[Dictionary] = []
	
	for effect in effects:
		if not effect:
			continue
		
		var targets = target_resolver.call(effect.target)
		var results = effect.execute(source, targets, dice_values)
		all_results.append_array(results)
	
	return all_results

func execute_simple(source, primary_target, all_enemies: Array, all_allies: Array, dice_values: Array = []) -> Array[Dictionary]:
	"""Simplified execution with pre-resolved target arrays"""
	
	var resolver = func(target_type: ActionEffect.TargetType) -> Array:
		match target_type:
			ActionEffect.TargetType.SELF:
				return [source]
			ActionEffect.TargetType.SINGLE_ENEMY:
				return [primary_target] if primary_target else []
			ActionEffect.TargetType.ALL_ENEMIES:
				return all_enemies
			ActionEffect.TargetType.SINGLE_ALLY:
				return [source]
			ActionEffect.TargetType.ALL_ALLIES:
				return all_allies
			_:
				return []
	
	return execute(source, resolver, dice_values)

# ============================================================================
# UTILITY
# ============================================================================

func get_total_dice_needed() -> int:
	"""Calculate total dice needed across all effects"""
	var total = 0
	for effect in effects:
		if effect and effect.effect_type == ActionEffect.EffectType.DAMAGE:
			total += effect.dice_count
		elif effect and effect.effect_type == ActionEffect.EffectType.HEAL and effect.heal_uses_dice:
			total += effect.dice_count
	return maxi(total, die_slots)

func get_effects_summary() -> String:
	"""Get summary of all effects"""
	var summaries: Array[String] = []
	for effect in effects:
		if effect:
			summaries.append(effect.get_summary())
	return "\n".join(summaries) if summaries.size() > 0 else "No effects"

func has_damage_effect() -> bool:
	"""Check if action has any damage effects"""
	for effect in effects:
		if effect and effect.effect_type == ActionEffect.EffectType.DAMAGE:
			return true
	return false

func has_heal_effect() -> bool:
	"""Check if action has any heal effects"""
	for effect in effects:
		if effect and effect.effect_type == ActionEffect.EffectType.HEAL:
			return true
	return false

func validate() -> Array[String]:
	"""Validate action configuration"""
	var warnings: Array[String] = []
	
	if action_id.is_empty():
		warnings.append("Action has no ID")
	
	if action_name.is_empty():
		warnings.append("Action has no name")
	
	if effects.is_empty():
		warnings.append("Action has no effects")
	
	if charge_type != ChargeType.UNLIMITED and max_charges <= 0:
		warnings.append("Limited action has no charges")
	
	return warnings

func _to_string() -> String:
	return "Action<%s: %d effects, %d dice>" % [action_name, effects.size(), die_slots]
