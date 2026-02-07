# impact_preset.gd
# Configuration for quick directional hit effects.
# Use for: weapon strikes, ability impacts, damage application.
extends CombatEffectPreset
class_name ImpactPreset

@export_group("Slash")
## Enable a directional slash line across the target
@export var slash_enabled: bool = true
## Slash line length (pixels)
@export_range(30.0, 300.0) var slash_length: float = 80.0
## Slash line thickness (pixels)
@export_range(1.0, 12.0) var slash_thickness: float = 3.0
## Slash animation duration
@export_range(0.05, 0.3) var slash_duration: float = 0.1
## Slash color
@export var slash_color: Color = Color(1.0, 1.0, 1.0, 0.9)
## Randomize slash angle (±degrees from incoming direction)
@export_range(0.0, 45.0) var slash_angle_spread: float = 15.0

@export_group("Burst Sparks")
## Number of sparks at impact point
@export_range(0, 16) var spark_count: int = 6
## Spark particle size
@export var spark_size: Vector2 = Vector2(10, 10)
## How far sparks travel from impact
@export_range(10.0, 150.0) var spark_radius: float = 50.0
## Spark duration
@export_range(0.05, 0.4) var spark_duration: float = 0.2
## Spark color
@export var spark_color: Color = Color(1.0, 0.85, 0.5, 0.9)
## Bias sparks away from incoming direction (0 = radial, 1 = full deflection)
@export_range(0.0, 1.0) var spark_deflection_bias: float = 0.4

@export_group("Timing")
## Brief delay before impact visuals (anticipation)
@export_range(0.0, 0.2) var anticipation_delay: float = 0.0
## Total duration including fade-out
@export_range(0.1, 0.8) var total_duration: float = 0.35
