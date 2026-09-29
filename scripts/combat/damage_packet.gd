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
	"""Total damage after defences (A1, hit-relative; CombatTuning).

	For each element pile: element modifier (immunity / resistance /
	weakness), then reduction = D / (D + K x pile), capped, where D is the
	armour (physical) or barrier (magical) for that pile, piercing ignoring
	part of the armour, times defense_mult (0.5 for DoT ticks).

	defender_stats should contain:
	  - armor: float, barrier: float
	  - element_modifiers: Dictionary (optional, enemy only)
		Keys: DamageType name strings e.g. "FIRE", "ICE"
	    Values: float multiplier: 0.0=immune, 0.5=resistant, 1.5=weak
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
			continue  # Immune: skip defense calc
		
		# Step 2: Defense stat for this pile (armor or barrier)
		var defense: float = _get_defense_for_type(type, defender_stats) * defense_mult
		
		# Step 3: Hit-relative reduction (no flat subtraction)
		total += damage * (1.0 - CombatTuning.defense_reduction(defense, damage))
	
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
		ActionEffect.DamageType.SHADOW, \
		ActionEffect.DamageType.FAITH:
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
