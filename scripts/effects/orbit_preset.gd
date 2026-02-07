# orbit_preset.gd
# Configuration for persistent orbiting particles around a source.
# Unlike other effects, Orbit is NOT fire-and-forget — it has start/stop lifecycle.
# Use for: active buff indicator, charged state, enchant aura, readied ability.
extends CombatEffectPreset
class_name OrbitPreset

@export_group("Orbit")
## Number of orbiting motes
@export_range(1, 12) var mote_count: int = 4
## Orbit radius from center
@export_range(15.0, 150.0) var orbit_radius: float = 40.0
## Orbit speed (radians per second, positive = counter-clockwise)
@export_range(0.5, 8.0) var orbit_speed: float = 2.5
## Radius variation (motes orbit at slightly different distances)
@export_range(0.0, 30.0) var radius_variation: float = 8.0
## Speed variation per mote (±fraction of orbit_speed)
@export_range(0.0, 0.3) var speed_variation: float = 0.15

@export_group("Motes")
@export var mote_size: Vector2 = Vector2(10, 10)
@export var mote_color: Color = Color(1.0, 0.9, 0.5, 0.8)
## Subtle scale oscillation (breathing)
@export_range(0.0, 0.3) var breathe_amount: float = 0.15
@export_range(0.5, 3.0) var breathe_speed: float = 1.5

@export_group("Fade")
## Duration for motes to fade in on start
@export_range(0.1, 0.5) var fade_in_duration: float = 0.2
## Duration for motes to fade out on stop
@export_range(0.1, 0.5) var fade_out_duration: float = 0.3

@export_group("Trail")
## Leave faint trail behind each mote
@export var trail_enabled: bool = false
@export_range(0.03, 0.1) var trail_interval: float = 0.06
@export_range(0.05, 0.2) var trail_fade: float = 0.1
