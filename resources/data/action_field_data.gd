# action_field_data.gd - Data for an action field
extends Resource
class_name ActionFieldData

# ============================================================================
# ENUMS
# ============================================================================
enum ActionType {
	ATTACK_ENEMY,
	ATTACK_SELF,
	DEFEND_SELF,
	HEAL_SELF,
	BUFF_SELF,
	DEBUFF_ENEMY
}

enum DamageType {
	PHYSICAL,
	MAGICAL,
	TRUE
}

# ============================================================================
# PROPERTIES
# ============================================================================
var field_name: String = "Attack"
var action_type: ActionType = ActionType.ATTACK_ENEMY
var damage_type: DamageType = DamageType.PHYSICAL

# Damage formula
var base_value: int = 0
var die_multiplier: float = 1.0

# Die restrictions
var required_tags: Array[String] = []
var restricted_tags: Array[String] = []
var allowed_die_types: Array[DieResource.DieType] = []

# Source
var source: String = ""

# Visual
var icon: Texture2D = null
var color: Color = Color.WHITE

# ============================================================================
# FACTORY METHODS
# ============================================================================

static func create_basic_attack(source_name: String = "Basic Attack") -> ActionFieldData:
	"""Create a basic attack action"""
	var action = ActionFieldData.new()
	action.field_name = "Attack"
	action.action_type = ActionType.ATTACK_ENEMY
	action.damage_type = DamageType.PHYSICAL
	action.base_value = 0
	action.die_multiplier = 1.0
	action.source = source_name
	action.color = Color(0.8, 0.2, 0.2)
	return action

static func create_weapon_attack(weapon_name: String, base_damage: int, multiplier: float = 1.0) -> ActionFieldData:
	"""Create a weapon attack action"""
	var action = ActionFieldData.new()
	action.field_name = weapon_name
	action.action_type = ActionType.ATTACK_ENEMY
	action.damage_type = DamageType.PHYSICAL
	action.base_value = base_damage
	action.die_multiplier = multiplier
	action.source = weapon_name
	action.color = Color(0.9, 0.3, 0.1)
	return action

static func create_defend(source_name: String = "Defend") -> ActionFieldData:
	"""Create a defend action"""
	var action = ActionFieldData.new()
	action.field_name = "Defend"
	action.action_type = ActionType.DEFEND_SELF
	action.base_value = 0
	action.die_multiplier = 1.0
	action.source = source_name
	action.color = Color(0.2, 0.4, 0.8)
	return action

static func create_heal(source_name: String = "Heal") -> ActionFieldData:
	"""Create a heal action"""
	var action = ActionFieldData.new()
	action.field_name = "Heal"
	action.action_type = ActionType.HEAL_SELF
	action.base_value = 0
	action.die_multiplier = 1.0
	action.source = source_name
	action.color = Color(0.2, 0.8, 0.3)
	return action

# ============================================================================
# UTILITY
# ============================================================================

func can_accept_die(die: DieResource) -> bool:
	"""Check if this action can accept a die"""
	# Check allowed types
	if allowed_die_types.size() > 0:
		if die.die_type not in allowed_die_types:
			return false
	
	# Check required tags
	if required_tags.size() > 0:
		var has_required = false
		for tag in required_tags:
			if die.has_tag(tag):
				has_required = true
				break
		if not has_required:
			return false
	
	# Check restricted tags
	for tag in restricted_tags:
		if die.has_tag(tag):
			return false
	
	return true

func calculate_value(die_value: int) -> int:
	"""Calculate the action value given a die value"""
	return base_value + int(die_value * die_multiplier)

func get_formula_text() -> String:
	"""Get human-readable formula"""
	if base_value == 0 and die_multiplier == 1.0:
		return "D"
	elif base_value > 0 and die_multiplier == 1.0:
		return "D+%d" % base_value
	elif base_value == 0:
		return "%.1fD" % die_multiplier
	else:
		return "%.1fD+%d" % [die_multiplier, base_value]
