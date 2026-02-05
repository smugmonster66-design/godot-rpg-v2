# damage_packet.gd - Holds damage broken out by type
extends RefCounted
class_name DamagePacket

# Use ActionEffect's DamageType enum (don't redefine it)
const DamageType = ActionEffect.DamageType

# Physical types (reduced by armor)
const PHYSICAL_TYPES = [
	ActionEffect.DamageType.SLASHING,
	ActionEffect.DamageType.BLUNT,
	ActionEffect.DamageType.PIERCING
]

# ============================================================================
# DAMAGE VALUES BY TYPE
# ============================================================================
var damages: Dictionary = {}  # DamageType -> float

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	# Initialize all damage types to 0
	for type in ActionEffect.DamageType.values():
		damages[type] = 0.0

# ============================================================================
# ADD DAMAGE
# ============================================================================

func add_damage(type: ActionEffect.DamageType, amount: float):
	"""Add damage of a specific type"""
	damages[type] += amount

func add_damage_from_effect(effect: ActionEffect, dice_total: int):
	"""Add damage from an ActionEffect calculation"""
	var base = effect.base_damage
	var mult = effect.damage_multiplier
	var final_damage = (dice_total + base) * mult
	add_damage(effect.damage_type, final_damage)

func merge(other: DamagePacket):
	"""Merge another packet into this one"""
	for type in ActionEffect.DamageType.values():
		damages[type] += other.damages[type]

# ============================================================================
# APPLY MULTIPLIER
# ============================================================================

func apply_multiplier(multiplier: float):
	"""Apply a global damage multiplier to all types"""
	for type in damages:
		damages[type] *= multiplier

func apply_type_multiplier(type: ActionEffect.DamageType, multiplier: float):
	"""Apply multiplier to a specific damage type"""
	damages[type] *= multiplier

# ============================================================================
# CALCULATE FINAL DAMAGE
# ============================================================================

func calculate_final_damage(defender_stats: Dictionary, defense_mult: float = 1.0) -> int:
	"""
	Calculate total damage after defenses.
	
	defender_stats should contain:
	- armor: int (reduces physical)
	- fire_resist: int
	- ice_resist: int
	- shock_resist: int
	- poison_resist: int
	- shadow_resist: int
	"""
	var total: float = 0.0
	
	for type in ActionEffect.DamageType.values():
		var damage = damages[type]
		if damage <= 0:
			continue
		
		var reduction = _get_reduction_for_type(type, defender_stats) * defense_mult
		var final = max(0.0, damage - reduction)
		total += final
	
	return roundi(total)


func _get_reduction_for_type(type: ActionEffect.DamageType, stats: Dictionary) -> float:
	"""Get the appropriate resistance for a damage type.
	Piercing ignores a fraction of armor (configured in CombatCalculator).
	"""
	match type:
		ActionEffect.DamageType.SLASHING, \
		ActionEffect.DamageType.BLUNT:
			return stats.get("armor", 0)
		ActionEffect.DamageType.PIERCING:
			# Piercing ignores a fraction of armor
			var armor = stats.get("armor", 0)
			return armor * (1.0 - CombatCalculator.PIERCING_ARMOR_PENETRATION)
		ActionEffect.DamageType.FIRE:
			return stats.get("fire_resist", 0)
		ActionEffect.DamageType.ICE:
			return stats.get("ice_resist", 0)
		ActionEffect.DamageType.SHOCK:
			return stats.get("shock_resist", 0)
		ActionEffect.DamageType.POISON:
			return stats.get("poison_resist", 0)
		ActionEffect.DamageType.SHADOW:
			return stats.get("shadow_resist", 0)
		_:
			return 0.0

# ============================================================================
# DEBUG / DISPLAY
# ============================================================================

func get_breakdown() -> Dictionary:
	"""Get non-zero damage types for display"""
	var breakdown = {}
	for type in damages:
		if damages[type] > 0:
			breakdown[ActionEffect.DamageType.keys()[type]] = damages[type]
	return breakdown

func get_total_raw() -> float:
	"""Get total damage before defenses"""
	var total = 0.0
	for type in damages:
		total += damages[type]
	return total

func _to_string() -> String:
	var parts = []
	for type in damages:
		if damages[type] > 0:
			parts.append("%s: %.1f" % [ActionEffect.DamageType.keys()[type], damages[type]])
	return "DamagePacket[%s]" % ", ".join(parts)
