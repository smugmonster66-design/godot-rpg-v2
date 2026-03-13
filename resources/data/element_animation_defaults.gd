class_name ElementAnimationDefaults
extends Resource

@export_group("Physical")
@export var slashing: CombatAnimationSet
@export var blunt: CombatAnimationSet
@export var piercing: CombatAnimationSet

@export_group("Elemental")
@export var fire: CombatAnimationSet
@export var ice: CombatAnimationSet
@export var shock: CombatAnimationSet
@export var poison: CombatAnimationSet
@export var shadow: CombatAnimationSet

func get_for_element(damage_type: int) -> CombatAnimationSet:
	match damage_type:
		ActionEffect.DamageType.SLASHING: return slashing
		ActionEffect.DamageType.BLUNT: return blunt
		ActionEffect.DamageType.PIERCING: return piercing
		ActionEffect.DamageType.FIRE: return fire
		ActionEffect.DamageType.ICE: return ice
		ActionEffect.DamageType.SHOCK: return shock
		ActionEffect.DamageType.POISON: return poison
		ActionEffect.DamageType.SHADOW: return shadow
	return null
