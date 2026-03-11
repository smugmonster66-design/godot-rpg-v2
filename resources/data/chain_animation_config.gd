# res://resources/data/chain_animation_config.gd
# Animation configuration for chain hop visuals.
# Referenced by ActionEffect.chain_animation and DiceAffix effect_data["chain_animation"].
# A single ChainAnimationConfig can be shared across multiple actions/affixes.
extends Resource
class_name ChainAnimationConfig

## Projectile scene that travels from the previous target to the next.
## Must have a play() method and emit reached_target when it arrives.
## Use the same projectile convention as CombatAnimationSet.travel_effect.
@export var travel_effect: PackedScene = null

## BurstParticles2D scene spawned at each hop's landing point.
## Must have a play() method. Fire-and-forget (does not block hop sequence).
@export var impact_effect: PackedScene = null

## How long the travel projectile takes per hop (seconds).
@export var travel_duration: float = 0.25

## Optional pause between hops. 0 = next hop starts immediately after impact.
@export var hop_delay: float = 0.0
