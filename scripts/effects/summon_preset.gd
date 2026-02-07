# summon_preset.gd
# Configuration for materialization/summon effects.
# Particles converge inward from ambient space to a point, forming something new.
# Use for: new die appearing, conjured shield, item creation, spawn.
extends CombatEffectPreset
class_name SummonPreset

@export_group("Converge")
## Number of particles that converge to form the summoned object
@export_range(4, 24) var particle_count: int = 12
## Starting radius (how far away particles spawn)
@export_range(40.0, 300.0) var spawn_radius: float = 120.0
## Converge duration (how long it takes particles to arrive)
@export_range(0.2, 1.0) var converge_duration: float = 0.5
@export var converge_ease: Tween.EaseType = Tween.EASE_IN
@export var converge_trans: Tween.TransitionType = Tween.TRANS_QUAD

@export_group("Particles")
@export var particle_size: Vector2 = Vector2(16, 16)
@export var particle_color: Color = Color(0.8, 0.9, 1.0, 0.7)
## Stagger particle start times (0 = all start simultaneously)
@export_range(0.0, 0.3) var start_stagger: float = 0.15

@export_group("Arrival Flash")
## Flash at center when all particles arrive
@export var arrival_flash_enabled: bool = true
@export_range(1.0, 3.0) var arrival_flash_scale: float = 2.0
@export_range(0.05, 0.3) var arrival_flash_duration: float = 0.15
@export var arrival_flash_color: Color = Color(1.0, 1.0, 1.0, 0.9)

@export_group("Pre-Glow")
## Subtle glow at target point before particles arrive
@export var pre_glow_enabled: bool = true
@export_range(0.1, 0.5) var pre_glow_duration: float = 0.2
@export_range(0.1, 0.5) var pre_glow_intensity: float = 0.3
