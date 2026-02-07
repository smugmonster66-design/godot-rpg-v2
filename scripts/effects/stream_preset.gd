# stream_preset.gd
# Configuration for sustained directional particle flow between two points.
# Use for: ongoing drain, healing tether, energy channel, link effects.
extends CombatEffectPreset
class_name StreamPreset

@export_group("Flow")
## How long the stream persists
@export_range(0.3, 5.0) var stream_duration: float = 1.0
## Particles spawned per second during flow
@export_range(5.0, 60.0) var spawn_rate: float = 20.0
## Travel time for each particle from source to target
@export_range(0.1, 1.0) var particle_travel_time: float = 0.3
## Random spread perpendicular to travel direction (pixels)
@export_range(0.0, 50.0) var flow_spread: float = 12.0
## Arc height (0 = straight line, positive = arc upward)
@export_range(-100.0, 100.0) var arc_height: float = 0.0

@export_group("Particles")
@export var particle_size: Vector2 = Vector2(12, 12)
@export var particle_color: Color = Color(0.5, 0.9, 1.0, 0.8)
## Scale particles down as they arrive
@export_range(0.0, 1.0) var arrival_shrink: float = 0.3

@export_group("Appearance")
@export var additive_blend: bool = true

@export_group("Ramp")
## Fade-in time for the stream (particles become more frequent)
@export_range(0.0, 0.5) var ramp_up_time: float = 0.15
## Fade-out time (particles become less frequent before stopping)
@export_range(0.0, 0.5) var ramp_down_time: float = 0.2
