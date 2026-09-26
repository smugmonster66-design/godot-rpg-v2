# res://scripts/effects/lightning_bolt_strike_effect.gd
# Lightning bolt that strikes FROM a position defined by angle + radius relative
# to the target, rather than from the action field.
#
# Origin point = target + polar(origin_angle, origin_radius)
# Target point = target + random scatter within (scatter_x, scatter_y)
#
# Useful for "called lightning" / "storm strike" effects where the bolt
# descends from a specific direction in the sky rather than projecting
# from the caster's UI position.
extends LightningBoltEffect
class_name LightningBoltStrikeEffect

# ============================================================================
# ORIGIN
# ============================================================================
@export_group("Strike Origin")

## Angle (degrees) from the target point where the bolt originates.
## 0 = right, 90 = down, 180 = left, 270 = up (above the target).
@export_range(0.0, 360.0) var origin_angle: float = 270.0

## Distance (pixels) from the target to the bolt's origin point.
@export var origin_radius: float = 500.0

# ============================================================================
# TARGET SCATTER
# ============================================================================
@export_group("Target Scatter")

## Max random horizontal offset applied to the target each play.
@export var scatter_x: float = 30.0

## Max random vertical offset applied to the target each play.
@export var scatter_y: float = 15.0

# ============================================================================
# STATE
# ============================================================================

var _target_base: Vector2

# ============================================================================
# SETUP
# ============================================================================

## Configure the strike target. Origin is computed at play() time from exports.
## 'from' is ignored — origin is derived from 'to' + polar(origin_angle, origin_radius).
func setup(from: Vector2, to: Vector2, p_duration: float = 0.4, _p_curve: Curve = null):
	_target_base = to
	_duration = max(p_duration, 0.15)
	global_position = Vector2.ZERO

# ============================================================================
# PLAY
# ============================================================================

func play():
	# Apply scatter to the target point
	var scattered_target := _target_base + Vector2(
		randf_range(-scatter_x, scatter_x),
		randf_range(-scatter_y, scatter_y)
	)

	# Compute origin: polar offset from the scattered target
	var angle_rad := deg_to_rad(origin_angle)
	var origin := scattered_target + Vector2(cos(angle_rad), sin(angle_rad)) * origin_radius

	# Feed into base class state before calling parent play()
	_from = origin
	_to = scattered_target

	await super.play()
