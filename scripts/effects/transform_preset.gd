# transform_preset.gd
# Configuration for in-place transformation effects.
# Primarily shader-driven — the effect IS the shader animation.
# Use for: element shift, reroll, value change, rarity upgrade, enchant.
extends CombatEffectPreset
class_name TransformPreset

@export_group("Transform Timing")
## Duration of the transformation
@export_range(0.1, 2.0) var transform_duration: float = 0.4
## When the actual "swap" happens (0-1 normalized within duration)
@export_range(0.0, 1.0) var swap_point: float = 0.5

@export_group("Accent Particles")
## Optional sparkle particles around the transforming object
@export_range(0, 12) var sparkle_count: int = 6
@export var sparkle_size: Vector2 = Vector2(8, 8)
@export_range(10.0, 60.0) var sparkle_radius: float = 30.0
@export var sparkle_color: Color = Color(1.0, 1.0, 0.8, 0.9)
## Sparkle duration
@export_range(0.1, 0.5) var sparkle_duration: float = 0.3

@export_group("Scale Punch")
## Brief scale squash-and-stretch at swap point
@export var scale_punch_enabled: bool = true
## Squash scale (< 1 = flatten)
@export var squash_scale: Vector2 = Vector2(1.15, 0.85)
## Squash duration (one way)
@export_range(0.03, 0.15) var squash_duration: float = 0.06
