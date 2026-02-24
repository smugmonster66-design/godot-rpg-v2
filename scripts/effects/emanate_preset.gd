# emanate_preset.gd
# Configuration for radial outward expansion effects.
# Use for: buff activation, aura proc, status applied to self, shockwave.
extends CombatEffectPreset
class_name EmanatePreset

@export_group("Rings")
## Number of expanding ring pulses
@export_range(1, 5) var ring_count: int = 2
## Starting radius of each ring (pixels)
@export_range(0.0, 50.0) var ring_start_radius: float = 10.0
## Maximum expansion radius (pixels)
@export_range(50.0, 400.0) var ring_end_radius: float = 150.0
## Ring line thickness (pixels)
@export_range(1.0, 20.0) var ring_thickness: float = 4.0
## Stagger between ring spawns
@export_range(0.0, 0.3) var ring_stagger: float = 0.1
## Ring expansion duration
@export_range(0.1, 1.0) var ring_duration: float = 0.4

@export_group("Burst Particles")
## Number of radial burst particles (0 = rings only)
@export_range(0, 24) var burst_particle_count: int = 8
## Particle size
@export var particle_size: Vector2 = Vector2(16, 16)
## How far particles travel outward
@export_range(30.0, 300.0) var burst_radius: float = 100.0
## Burst travel duration
@export_range(0.1, 0.8) var burst_duration: float = 0.35

@export_group("Appearance")
## Ring and particle color
@export var emanate_color: Color = Color(1.0, 0.9, 0.5, 0.8)
## Additive blend for ethereal look
@export var additive_blend: bool = true

# In EmanatePreset:
@export_group("Custom Textures")
## Custom ring texture. Null = auto-generated ring.
@export var custom_ring_texture: Texture2D = null
## Custom burst particle texture. Null = auto-generated soft circle.
@export var custom_burst_texture: Texture2D = null


@export_group("Timing")
## Total effect duration (should be >= ring_duration + stagger * ring_count)
@export_range(0.2, 2.0) var total_duration: float = 0.6
