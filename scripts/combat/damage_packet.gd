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

## Tuning constant for percentage defense formula.
## Higher = defense less effective. Lower = defense more effective.
## At 100: 50 def = 33% reduction, 100 def = 50%, 200 def = 67%.
const DEFENSE_CONSTANT: float = 100.0


func calculate_final_damage(defender_stats: Dictionary, defense_mult: float = 1.0) -> int:
	"""Calculate total damage after percentage-based defenses.
	
	defender_stats should contain:
	  - armor: float (physical defense for percentage reduction)
	  - barrier: float (magical defense for percentage reduction)
	  - element_modifiers: Dictionary (optional, enemy only)
	    Keys: DamageType name strings e.g. "FIRE", "ICE"
	    Values: float multiplier — 0.0=immune, 0.5=resistant, 1.5=weak
	"""
	var element_mods: Dictionary = defender_stats.get("element_modifiers", {})
	var total: float = 0.0
	
	for type in ActionEffect.DamageType.values():
		var damage: float = damages[type]
		if damage <= 0.0:
			continue
		
		# Step 1: Element modifier (immunity / resistance / weakness)
		var type_key: String = ActionEffect.DamageType.keys()[type]
		var elem_mod: float = element_mods.get(type_key, 1.0)
		damage *= elem_mod
		
		if damage <= 0.0:
			continue  # Immune — skip defense calc
		
		# Step 2: Get defense stat (armor for physical, barrier for magical)
		var defense: float = _get_defense_for_type(type, defender_stats) * defense_mult
		
		# Step 3: Percentage reduction with diminishing returns
		var reduction_pct: float = defense / (DEFENSE_CONSTANT + defense) if defense > 0.0 else 0.0
		total += damage * (1.0 - reduction_pct)
	
	return roundi(total)




func _get_defense_for_type(type: ActionEffect.DamageType, stats: Dictionary) -> float:
	"""Get the defense value for a damage type.
	Physical types (Slashing, Blunt, Piercing) use armor.
	Magical types (Fire, Ice, Shock, Poison, Shadow) use barrier.
	Piercing ignores a fraction of armor.
	"""
	match type:
		ActionEffect.DamageType.SLASHING, \
		ActionEffect.DamageType.BLUNT:
			return maxf(0.0, stats.get("armor", 0))
		ActionEffect.DamageType.PIERCING:
			var armor: float = stats.get("armor", 0)
			return maxf(0.0, armor * (1.0 - CombatCalculator.PIERCING_ARMOR_PENETRATION))
		ActionEffect.DamageType.FIRE, \
		ActionEffect.DamageType.ICE, \
		ActionEffect.DamageType.SHOCK, \
		ActionEffect.DamageType.POISON, \
		ActionEffect.DamageType.SHADOW:
			return maxf(0.0, stats.get("barrier", 0))
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
