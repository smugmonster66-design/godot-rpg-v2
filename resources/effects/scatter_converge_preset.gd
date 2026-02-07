# scatter_converge_preset.gd - Configurable preset for scatter-converge effects
# Create instances in res://resources/effects/ for different contexts:
#   - roll_reveal_preset.tres
#   - action_confirm_preset.tres
#   - placement_preset.tres
extends Resource
class_name ScatterConvergePreset

# ============================================================================
# PARTICLE COUNT
# ============================================================================
@export_group("Particles")
## Number of particles to spawn per effect
@export_range(3, 24) var particle_count: int = 10
## Size of each particle in pixels
@export var particle_size: Vector2 = Vector2(28, 28)

# ============================================================================
# SCATTER PHASE
# ============================================================================
@export_group("Scatter")
## Duration of the scatter burst
@export_range(0.05, 0.6) var scatter_duration: float = 0.2
## Minimum scatter radius from source
@export_range(10.0, 200.0) var scatter_radius_min: float = 30.0
## Maximum scatter radius from source
@export_range(20.0, 400.0) var scatter_radius_max: float = 80.0
## Bias scatter direction toward the target (0 = radial, 1 = fully aimed)
@export_range(0.0, 1.0) var directional_bias: float = 0.2
## Scatter spread angle in degrees when using directional bias
@export_range(30.0, 360.0) var scatter_spread_deg: float = 180.0
## Easing for scatter movement
@export var scatter_ease: Tween.EaseType = Tween.EASE_OUT
@export var scatter_trans: Tween.TransitionType = Tween.TRANS_CUBIC

# ============================================================================
# HANG PHASE
# ============================================================================
@export_group("Hang")
## Duration particles hang in place
@export_range(0.0, 0.5) var hang_duration: float = 0.2
## Random drift amount during hang (pixels)
@export_range(0.0, 10.0) var hang_drift: float = 3.0
## Subtle scale oscillation during hang (±percent)
@export_range(0.0, 0.2) var hang_breathe: float = 0.08

# ============================================================================
# CONVERGE PHASE
# ============================================================================
@export_group("Converge")
## Base duration of convergence travel
@export_range(0.05, 0.6) var converge_duration: float = 0.25
## Random stagger per particle for cascading arrival (0 = simultaneous)
@export_range(0.0, 0.1) var converge_stagger: float = 0.03
## Easing for converge movement
@export var converge_ease: Tween.EaseType = Tween.EASE_IN
@export var converge_trans: Tween.TransitionType = Tween.TRANS_QUAD
## Shrink particles as they approach target (0 = no shrink, 1 = shrink to 0)
@export_range(0.0, 1.0) var converge_shrink: float = 0.3

# ============================================================================
# ROTATION
# ============================================================================
@export_group("Rotation")
## Random initial rotation range (radians, ±value)
@export_range(0.0, 3.15) var initial_rotation_range: float = PI
## Spin speed during flight (radians over full lifetime, ±value)
@export_range(0.0, 6.28) var spin_amount: float = PI
## Accelerate spin during converge phase (multiplier)
@export_range(1.0, 3.0) var converge_spin_accel: float = 1.5

# ============================================================================
# SCALE CURVE
# ============================================================================
@export_group("Scale")
## Pop-in scale at start of scatter (0 = start invisible, 1 = start full size)
@export_range(0.0, 1.0) var scatter_start_scale: float = 0.0
## Duration of the pop-in to full size
@export_range(0.02, 0.2) var scale_pop_duration: float = 0.08

# ============================================================================
# TRAILS
# ============================================================================
@export_group("Trails")
## Enable afterimage trails during converge phase
@export var trails_enabled: bool = false
## Number of afterimages per particle during converge
@export_range(1, 5) var trail_count: int = 3
## Interval between afterimage spawns (seconds)
@export_range(0.02, 0.1) var trail_interval: float = 0.04
## Afterimage fade duration
@export_range(0.05, 0.3) var trail_fade_duration: float = 0.15

# ============================================================================
# IMPACT FLASH
# ============================================================================
@export_group("Impact")
## Enable flash at target on convergence complete
@export var impact_flash_enabled: bool = true
## Scale of the impact flash relative to particle size
@export_range(1.0, 3.0) var impact_flash_scale: float = 1.5
## Duration of the impact flash
@export_range(0.05, 0.3) var impact_flash_duration: float = 0.12

# ============================================================================
# BLEND MODE
# ============================================================================
@export_group("Rendering")
## Additive blend for the die face layer (true = energy/ethereal, false = solid)
@export var additive_blend: bool = true
## Base shape opacity
@export_range(0.0, 1.0) var base_shape_opacity: float = 0.7
## Die face opacity on top of base shape
@export_range(0.0, 1.0) var die_face_opacity: float = 0.9

# ============================================================================
# COMPUTED HELPERS
# ============================================================================

func get_total_duration() -> float:
	"""Total worst-case duration including stagger."""
	return scatter_duration + hang_duration + converge_duration + (converge_stagger * particle_count) + impact_flash_duration

func get_scatter_spread_rad() -> float:
	return deg_to_rad(scatter_spread_deg)
