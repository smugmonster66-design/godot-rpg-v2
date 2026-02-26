# res://resources/data/rarity_glow_config.gd
class_name RarityGlowConfig
extends Resource

## Space around target (in pixels) for the glow to render into. Must be >= glow_radius.
@export var padding: float = 16.0
## Max opacity of the glow
@export var alpha: float = 0.8
## Falloff curve power: lower = wide soft spread, higher = tight sharp edge
@export var softness: float = 1.5
## How far (in display pixels) the glow extends from the sprite edge
@export var glow_radius: float = 10.0
## Pulse animation speed (0 = no animation)
@export var pulse_speed: float = 1.5
## Pulse brightness oscillation amount
@export var pulse_amount: float = 0.15
