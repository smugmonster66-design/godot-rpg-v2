# shatter_preset.gd
# Configuration for break-apart / destruction effects.
# Use for: die consumed, die destroyed by affix, item breaking, death.
extends CombatEffectPreset
class_name ShatterPreset

@export_group("Fragments")
## Number of fragment particles
@export_range(4, 20) var fragment_count: int = 8
## Fragment size range
@export var fragment_size_min: Vector2 = Vector2(8, 8)
@export var fragment_size_max: Vector2 = Vector2(20, 16)
## Explosion radius (how far fragments travel)
@export_range(40.0, 300.0) var explosion_radius: float = 120.0
## Explosion duration
@export_range(0.2, 1.0) var explosion_duration: float = 0.5
## Upward bias (simulates gravity — fragments arc upward then fall)
@export_range(0.0, 200.0) var upward_bias: float = 40.0
## Gravity pull on fragments (pixels/s²)
@export_range(0.0, 800.0) var gravity: float = 300.0

@export_group("Appearance")
## Fragment base color (blended with source tint)
@export var fragment_color: Color = Color.WHITE
## Random rotation speed per fragment (radians/s, ±range)
@export_range(0.0, 20.0) var spin_range: float = 10.0
## Use source die texture for fragments (if available)
@export var inherit_source_texture: bool = true

@export_group("Pre-Shatter")
## Brief shake/crack before fragments fly
@export var pre_shake_enabled: bool = true
@export_range(0.05, 0.3) var pre_shake_duration: float = 0.1
## Shake intensity (pixels)
@export_range(1.0, 10.0) var shake_intensity: float = 4.0
## Number of shake oscillations
@export_range(2, 8) var shake_count: int = 4

@export_group("Timing")
@export_range(0.3, 2.0) var total_duration: float = 0.7
