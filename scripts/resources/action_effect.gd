# res://scripts/resources/action_effect.gd
# Granular effect that an action performs
extends Resource
class_name ActionEffect

# ============================================================================
# ENUMS
# ============================================================================
enum TargetType {
	SELF,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	SINGLE_ALLY,
	ALL_ALLIES
}

enum EffectType {
	DAMAGE,
	HEAL,
	ADD_STATUS,
	REMOVE_STATUS
}

enum DamageType {
	SLASHING,
	BLUNT,
	PIERCING,
	FIRE,
	ICE,
	SHOCK,
	POISON,
	SHADOW
}

# ============================================================================
# CORE CONFIGURATION
# ============================================================================
@export var effect_name: String = "New Effect"
@export var target: TargetType = TargetType.SINGLE_ENEMY
@export var effect_type: EffectType = EffectType.DAMAGE

# ============================================================================
# DAMAGE CONFIGURATION
# ============================================================================
@export_group("Damage Settings")
@export var damage_type: DamageType = DamageType.SLASHING
## Base damage added to dice total
@export var base_damage: int = 0
## Multiplier applied to (dice + base_damage)
@export var damage_multiplier: float = 1.0
## Number of dice to use from placed dice
@export var dice_count: int = 1

# ============================================================================
# HEAL CONFIGURATION
# ============================================================================
@export_group("Heal Settings")
## Base heal amount
@export var base_heal: int = 0
## Multiplier applied to heal
@export var heal_multiplier: float = 1.0
## If true, uses dice for healing amount
@export var heal_uses_dice: bool = false

# ============================================================================
# STATUS CONFIGURATION
# ============================================================================
@export_group("Status Settings")
## Status to add or remove
@export var status: Status = null
## Number of stacks to add/remove (0 = remove all for REMOVE_STATUS)
@export var stack_count: int = 1

# ============================================================================
# EXECUTION
# ============================================================================

func execute(source, targets: Array, dice_values: Array = []) -> Array[Dictionary]:
	"""Execute this effect and return results for each target"""
	var results: Array[Dictionary] = []
	
	for target_entity in targets:
		var result = _execute_on_target(source, target_entity, dice_values)
		results.append(result)
	
	return results

func _execute_on_target(source, target_entity, dice_values: Array) -> Dictionary:
	"""Execute effect on a single target"""
	var result = {
		"effect_name": effect_name,
		"effect_type": effect_type,
		"target": target_entity,
		"success": true
	}
	
	match effect_type:
		EffectType.DAMAGE:
			result.merge(_calculate_damage(dice_values))
		EffectType.HEAL:
			result.merge(_calculate_heal(dice_values))
		EffectType.ADD_STATUS:
			result.merge(_add_status_result())
		EffectType.REMOVE_STATUS:
			result.merge(_remove_status_result())
	
	return result

func _calculate_damage(dice_values: Array) -> Dictionary:
	"""Calculate damage from dice and base values"""
	var dice_total = 0
	var dice_used = mini(dice_count, dice_values.size())
	
	for i in range(dice_used):
		dice_total += dice_values[i]
	
	var final_damage = int((dice_total + base_damage) * damage_multiplier)
	
	return {
		"damage": final_damage,
		"damage_type": damage_type,
		"dice_used": dice_used,
		"dice_total": dice_total,
		"base_damage": base_damage,
		"multiplier": damage_multiplier
	}

func _calculate_heal(dice_values: Array) -> Dictionary:
	"""Calculate healing amount"""
	var dice_total = 0
	
	if heal_uses_dice:
		var dice_used = mini(dice_count, dice_values.size())
		for i in range(dice_used):
			dice_total += dice_values[i]
	
	var final_heal = int((dice_total + base_heal) * heal_multiplier)
	
	return {
		"heal": final_heal,
		"dice_total": dice_total,
		"base_heal": base_heal,
		"multiplier": heal_multiplier
	}

func _add_status_result() -> Dictionary:
	"""Build result for adding status"""
	return {
		"status": status,
		"stacks_to_add": stack_count
	}

func _remove_status_result() -> Dictionary:
	"""Build result for removing status"""
	return {
		"status": status,
		"stacks_to_remove": stack_count,  # 0 means remove all
		"remove_all": stack_count == 0
	}

# ============================================================================
# UTILITY
# ============================================================================

func get_target_type_name() -> String:
	match target:
		TargetType.SELF: return "Self"
		TargetType.SINGLE_ENEMY: return "Single Enemy"
		TargetType.ALL_ENEMIES: return "All Enemies"
		TargetType.SINGLE_ALLY: return "Single Ally"
		TargetType.ALL_ALLIES: return "All Allies"
		_: return "Unknown"

func get_effect_type_name() -> String:
	match effect_type:
		EffectType.DAMAGE: return "Damage"
		EffectType.HEAL: return "Heal"
		EffectType.ADD_STATUS: return "Add Status"
		EffectType.REMOVE_STATUS: return "Remove Status"
		_: return "Unknown"

func get_damage_type_name() -> String:
	match damage_type:
		DamageType.SLASHING: return "Slashing"
		DamageType.BLUNT: return "Blunt"
		DamageType.PIERCING: return "Piercing"
		DamageType.FIRE: return "Fire"
		DamageType.ICE: return "Ice"
		DamageType.SHOCK: return "Shock"
		DamageType.POISON: return "Poison"
		DamageType.SHADOW: return "Shadow"
		_: return "Unknown"

func get_summary() -> String:
	"""Get a human-readable summary of this effect"""
	var parts: Array[String] = []
	
	parts.append("[%s]" % get_target_type_name())
	
	match effect_type:
		EffectType.DAMAGE:
			var damage_str = "%dD" % dice_count if dice_count > 0 else ""
			if base_damage > 0:
				damage_str += "+%d" % base_damage if damage_str else str(base_damage)
			if damage_multiplier != 1.0:
				damage_str += " x%.1f" % damage_multiplier
			parts.append("%s %s damage" % [damage_str, get_damage_type_name()])
		
		EffectType.HEAL:
			var heal_str = ""
			if heal_uses_dice:
				heal_str = "%dD" % dice_count
			if base_heal > 0:
				heal_str += "+%d" % base_heal if heal_str else str(base_heal)
			parts.append("Heal %s" % heal_str)
		
		EffectType.ADD_STATUS:
			var status_name = status.status_name if status else "None"
			parts.append("Apply %d %s" % [stack_count, status_name])
		
		EffectType.REMOVE_STATUS:
			var status_name = status.status_name if status else "None"
			if stack_count == 0:
				parts.append("Remove all %s" % status_name)
			else:
				parts.append("Remove %d %s" % [stack_count, status_name])
	
	return " ".join(parts)

func _to_string() -> String:
	return "ActionEffect<%s: %s>" % [effect_name, get_summary()]
