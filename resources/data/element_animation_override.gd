# res://resources/data/element_animation_override.gd
# Pairs a damage type with a combat animation set for per-element overrides
extends Resource
class_name ElementAnimationOverride

@export var damage_type: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING
@export var animation_set: CombatAnimationSet
