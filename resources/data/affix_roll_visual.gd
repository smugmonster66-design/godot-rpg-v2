# res://resources/data/affix_roll_visual.gd
# Configures visual effects that play when an affix activates.
# Attach to DiceAffix.roll_visual in the inspector.
#
# Supports four modes:
#   PROJECTILE    — tween a visual between source ↔ target die
#   ON_TARGET     — flash / pulse / particles on affected die(s)
#   ON_SOURCE     — flash / pulse / particles on the affix owner
#   ON_BOTH       — independent effects on source AND target(s)
#
# Custom scene overrides:
#   projectile_scene    — replaces entire built-in projectile with a custom scene
#   source_impact_scene — plays a full scene at source die on activation
#   target_impact_scene — plays a full scene at target die on impact
#
# When a custom scene is set, the corresponding simple exports (particle_scene,
# texture, trail) are ignored. Flash/pulse always apply alongside custom scenes.
extends Resource
class_name AffixRollVisual

# ============================================================================
# ANIMATION TYPE
# ============================================================================

enum AnimationType {
	NONE,           ## No roll visual
	PROJECTILE,     ## Tween a projectile between source ↔ target
	ON_TARGET,      ## Play effect on target die only
	ON_SOURCE,      ## Play effect on source die only
	ON_BOTH,        ## Independent effects on source AND target
}

enum ProjectileDirection {
	TARGET_TO_SOURCE,  ## e.g. Siphon — energy pulled from neighbor to self
	SOURCE_TO_TARGET,  ## e.g. Curse — sending effect outward
}

@export var animation_type: AnimationType = AnimationType.NONE

# ============================================================================
# PROJECTILE CONFIG (used when animation_type == PROJECTILE)
# ============================================================================
@export_group("Projectile")

@export var projectile_direction: ProjectileDirection = ProjectileDirection.TARGET_TO_SOURCE

## Custom scene that replaces the entire built-in projectile.
## The scene is instanced, tweened from origin → destination, then freed.
## Use for full custom projectiles (AnimatedSprite2D, complex particle combos, etc).
## When set, projectile_texture / projectile_material / trail_color are ignored.
@export var projectile_scene: PackedScene = null

## Texture for the traveling projectile (ignored when projectile_scene is set)
@export var projectile_texture: Texture2D = null

## Shader applied to the projectile texture during travel (ignored when projectile_scene is set)
@export var projectile_material: ShaderMaterial = null

## Color tint for the projectile. Applied as modulate on custom scenes too.
@export var projectile_color: Color = Color.WHITE

## Trail color gradient start — fades to transparent (ignored when projectile_scene is set)
@export var trail_color: Color = Color(1, 1, 1, 0.6)

## Size of the projectile in pixels
@export var projectile_size: Vector2 = Vector2(32, 32)

## Travel duration in seconds
@export var travel_duration: float = 0.3

## Easing: 0=Linear, 1=EaseIn, 2=EaseOut, 3=EaseInOut
@export_range(0, 3) var travel_ease: int = 3

## Particle scene attached to projectile during travel (ignored when projectile_scene is set)
@export var travel_particle_scene: PackedScene = null

# ============================================================================
# SOURCE EFFECT CONFIG (used when PROJECTILE, ON_SOURCE, or ON_BOTH)
# ============================================================================
@export_group("Source Effect")

## Custom scene instanced at source die center on activation.
## Plays its full lifetime then auto-frees. Use for animated effects
## (AnimatedSprite2D, multi-particle setups, etc).
## When set, source_particle_scene is ignored. Flash/pulse still apply on top.
@export var source_impact_scene: PackedScene = null

## Simple particle scene at source die center (ignored when source_impact_scene is set)
@export var source_particle_scene: PackedScene = null

## Flash color (modulate pulse). Color.WHITE = no flash.
@export var source_flash_color: Color = Color.WHITE

## Scale pulse magnitude (1.0 = no pulse, 1.3 = 30% scale up then back)
@export var source_scale_pulse: float = 1.0

## Duration of the source flash/pulse
@export var source_effect_duration: float = 0.2

## Shader applied temporarily to source die during effect
@export var source_shader: ShaderMaterial = null

# ============================================================================
# TARGET EFFECT CONFIG (used when PROJECTILE, ON_TARGET, or ON_BOTH)
# ============================================================================
@export_group("Target Effect")

## Custom scene instanced at target die center on impact/activation.
## Plays its full lifetime then auto-frees. Use for animated impact effects
## (AnimatedSprite2D, burst animations, complex particle combos, etc).
## When set, target_particle_scene is ignored. Flash/pulse still apply on top.
@export var target_impact_scene: PackedScene = null

## Simple particle scene at target die center (ignored when target_impact_scene is set)
@export var target_particle_scene: PackedScene = null

## Flash color (modulate pulse). Color.WHITE = no flash.
@export var target_flash_color: Color = Color(1.5, 1.5, 0.5, 1.0)

## Scale pulse magnitude
@export var target_scale_pulse: float = 1.15

## Duration of the target flash/pulse
@export var target_effect_duration: float = 0.25

## Shader applied temporarily to target die during effect
@export var target_shader: ShaderMaterial = null

# ============================================================================
# TIMING
# ============================================================================
@export_group("Timing")

## Delay before the visual plays (after affix activation)
@export var start_delay: float = 0.0

## For ON_BOTH: delay between source and target effects (0 = simultaneous)
@export var stagger: float = 0.0

# ============================================================================
# HELPERS
# ============================================================================

func has_source_effect() -> bool:
	return animation_type in [AnimationType.ON_SOURCE, AnimationType.ON_BOTH, AnimationType.PROJECTILE]

func has_target_effect() -> bool:
	return animation_type in [AnimationType.ON_TARGET, AnimationType.ON_BOTH, AnimationType.PROJECTILE]

func get_total_duration() -> float:
	"""Estimated total duration for sequencing."""
	match animation_type:
		AnimationType.PROJECTILE:
			return start_delay + source_effect_duration + travel_duration + target_effect_duration
		AnimationType.ON_BOTH:
			return start_delay + maxf(source_effect_duration, stagger + target_effect_duration)
		AnimationType.ON_SOURCE:
			return start_delay + source_effect_duration
		AnimationType.ON_TARGET:
			return start_delay + target_effect_duration
	return 0.0
