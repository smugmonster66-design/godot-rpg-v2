# res://scripts/effects/lightning_bolt_effect.gd
# A lightning bolt that strikes between source and target positions.
# Drop-in replacement for ProjectileEffect in CombatAnimationSet.travel_effect.
#
# Instead of tweening a sprite from A→B, this draws jagged Line2D bolts
# between the two points with flicker/re-randomization, optional branching
# forks, and a glow core layer. Emits reached_target after the bolt sequence
# completes, matching the interface combat_animation_player._play_travel() expects.
#
# Scene structure:
#   LightningBoltEffect (Node2D) ← this script
#     ├─ BoltLine (Line2D)       — outer bolt, wider, colored
#     ├─ CoreLine (Line2D)       — inner core, thinner, bright white
#     ├─ BranchContainer (Node2D)— holds dynamically spawned fork Line2Ds
#     ├─ Sparks (GPUParticles2D) — burst at impact (target) point
#     └─ AudioStreamPlayer2D     — optional zap/crackle sound
#
# Orbs are drawn via _draw() — no extra scene nodes required.
# A duplicate of Sparks is created at runtime for the origin point.
extends CombatEffectBase
class_name LightningBoltEffect

# ============================================================================
# SIGNALS
# ============================================================================

signal reached_target()

# ============================================================================
# BOLT SHAPE
# ============================================================================
@export_group("Bolt Shape")

## Average distance between jagged waypoints (smaller = more detail)
@export var segment_length: float = 18.0

## Max perpendicular offset per waypoint — controls how wild the bolt looks
@export var jag_amount: float = 30.0

## Number of times the bolt re-randomizes its path during the strike.
## More flickers = more chaotic, electric feel.
@export_range(1, 10) var flicker_count: int = 4

## Ratio of each flicker cycle spent visible vs invisible.
## 0.7 = bolt visible 70% of each sub-interval, dark 30%.
@export_range(0.3, 0.95) var visible_ratio: float = 0.7

# ============================================================================
# BRANCHING FORKS
# ============================================================================
@export_group("Branching")

## Probability (0–1) that any waypoint spawns a fork
@export_range(0.0, 0.5) var branch_chance: float = 0.15

## How long forks extend relative to remaining bolt distance (0.1–0.5)
@export_range(0.05, 0.5) var branch_length_ratio: float = 0.2

## Forks are thinner by this multiplier
@export_range(0.2, 0.8) var branch_width_ratio: float = 0.4

## Max forks per flicker cycle (prevents visual overload)
@export_range(1, 8) var max_branches: int = 4

## Angle range forks can deviate from the main bolt direction (degrees)
@export_range(15.0, 75.0) var branch_angle_spread: float = 40.0

# ============================================================================
# COLORS & WIDTHS
# ============================================================================
@export_group("Visual")

## Outer bolt color (the main colored stroke)
@export var bolt_color: Color = Color(0.5, 0.7, 1.0, 0.9)

## Inner core color (bright highlight down the center)
@export var core_color: Color = Color(0.9, 0.95, 1.0, 1.0)

## Width of the outer bolt stroke
@export var bolt_width: float = 7.0

## Width of the inner core stroke
@export var core_width: float = 2.5

## Glow modulate applied to outer bolt (use >1.0 channels for HDR bloom feel)
@export var glow_color: Color = Color(0.6, 0.8, 1.5, 0.5)

## If true, a faint "afterimage" bolt persists between flickers
@export var show_afterimage: bool = true

## Afterimage alpha (very faint)
@export_range(0.0, 0.3) var afterimage_alpha: float = 0.08

# ============================================================================
# ORBS
# ============================================================================
@export_group("Orbs")

## Draw a glowing orb at each end of the bolt
@export var orb_enabled: bool = true

## Radius of the solid bright core circle
@export var orb_radius: float = 14.0

## Number of concentric glow rings drawn outward from the core
@export_range(1, 6) var orb_glow_layers: int = 4

## Outermost glow ring is orb_radius * orb_glow_scale in size
@export_range(1.5, 6.0) var orb_glow_scale: float = 3.5

## Colour of the solid bright core
@export var orb_core_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## Colour of the outer glow rings
@export var orb_glow_color: Color = Color(0.5, 0.7, 1.0, 0.7)

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var bolt_line: Line2D = $BoltLine
@onready var core_line: Line2D = $CoreLine
@onready var branch_container: Node2D = $BranchContainer
@onready var sparks: GPUParticles2D = $Sparks
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

# ============================================================================
# STATE
# ============================================================================

var _from: Vector2
var _to: Vector2
var _duration: float = 0.4
var _current_points: Array[Vector2] = []
var _orb_alpha: float = 0.0
var _origin_sparks: GPUParticles2D = null

# ============================================================================
# READY
# ============================================================================

func _ready():
	# Duplicate the target Sparks node to also fire at the origin point
	if sparks:
		_origin_sparks = sparks.duplicate() as GPUParticles2D
		add_child(_origin_sparks)

# ============================================================================
# SETUP — matches ProjectileEffect.setup() signature exactly
# ============================================================================

func setup(from: Vector2, to: Vector2, p_duration: float = 0.4, _p_curve: Curve = null):
	"""Configure bolt endpoints. Curve is accepted but ignored (bolts are straight-ish)."""
	_from = from
	_to = to
	_duration = max(p_duration, 0.15)  # Minimum duration for at least one good flicker
	# Don't set global_position — we draw using global coordinates as local offsets
	global_position = Vector2.ZERO

# ============================================================================
# PLAY — the main animation sequence
# ============================================================================

func play():
	effect_started.emit()

	# Configure line appearance
	_setup_lines()

	# Position sparks at both ends
	if sparks:
		sparks.global_position = _to
	if _origin_sparks:
		_origin_sparks.global_position = _from

	# Play sound
	if audio and audio.stream:
		audio.global_position = (_from + _to) / 2.0
		audio.play()

	# Calculate timing
	var flicker_interval := _duration / float(flicker_count + 1)
	var visible_time := flicker_interval * visible_ratio
	var dark_time := flicker_interval * (1.0 - visible_ratio)

	# --- Flicker phase: bolt appears/disappears with new random paths ---
	for i in flicker_count:
		_generate_bolt_with_branches()
		_set_bolt_visible(true)

		# Start sparks at both ends on first visible frame
		if i == 0:
			if sparks:
				sparks.emitting = true
			if _origin_sparks:
				_origin_sparks.emitting = true

		await get_tree().create_timer(visible_time).timeout

		if show_afterimage:
			_set_bolt_afterimage()
		else:
			_set_bolt_visible(false)

		await get_tree().create_timer(dark_time).timeout

	# --- Final sustained flash (slightly longer, brighter) ---
	_generate_bolt_with_branches()
	_set_bolt_visible(true)

	# Brief bright pulse on the core line and orbs
	var pulse_tween = create_tween()
	pulse_tween.set_parallel(true)
	pulse_tween.tween_property(core_line, "width", core_width * 2.0, flicker_interval * 0.3)
	pulse_tween.tween_property(core_line, "width", core_width, flicker_interval * 0.7)
	if orb_enabled:
		pulse_tween.tween_method(_set_orb_alpha, 1.0, 1.6, flicker_interval * 0.3)
		pulse_tween.tween_method(_set_orb_alpha, 1.6, 1.0, flicker_interval * 0.7)

	await get_tree().create_timer(flicker_interval).timeout

	# --- Signal: bolt has "arrived" ---
	reached_target.emit()

	# --- Fade out ---
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(bolt_line, "modulate:a", 0.0, 0.12)
	fade_tween.tween_property(core_line, "modulate:a", 0.0, 0.1)

	# Fade branches
	for child in branch_container.get_children():
		if child is Line2D:
			fade_tween.tween_property(child, "modulate:a", 0.0, 0.12)

	# Fade orbs via tween_method so queue_redraw fires each frame
	if orb_enabled:
		fade_tween.tween_method(_set_orb_alpha, _orb_alpha, 0.0, 0.12)

	await fade_tween.finished

	# Let sparks finish their lifetime
	if sparks:
		sparks.emitting = false
	if _origin_sparks:
		_origin_sparks.emitting = false
	if sparks:
		await get_tree().create_timer(sparks.lifetime).timeout

	_on_finished()

# ============================================================================
# LINE SETUP
# ============================================================================

func _setup_lines():
	bolt_line.width = bolt_width
	bolt_line.default_color = bolt_color
	bolt_line.modulate = glow_color
	bolt_line.visible = false
	bolt_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bolt_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	bolt_line.joint_mode = Line2D.LINE_JOINT_ROUND

	core_line.width = core_width
	core_line.default_color = core_color
	core_line.visible = false
	core_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	core_line.joint_mode = Line2D.LINE_JOINT_ROUND

	_set_orb_alpha(0.0)

# ============================================================================
# BOLT GENERATION
# ============================================================================

func _generate_bolt_with_branches():
	"""Generate a new random bolt path and optional branching forks."""
	# Clear old branches
	for child in branch_container.get_children():
		child.queue_free()

	# Generate main bolt path
	_current_points = _build_jagged_path(_from, _to, segment_length, jag_amount)

	# Apply to lines
	_apply_points_to_line(bolt_line, _current_points)
	_apply_points_to_line(core_line, _current_points)

	# Generate branches from random waypoints
	var branch_count := 0
	var main_direction := (_to - _from).normalized()

	for i in range(1, _current_points.size() - 1):
		if branch_count >= max_branches:
			break
		if randf() > branch_chance:
			continue

		var branch_start := _current_points[i]
		var remaining_dist := branch_start.distance_to(_to)
		var fork_length := remaining_dist * branch_length_ratio

		if fork_length < 10.0:
			continue  # Too short to bother

		# Pick a fork direction: deviate from main bolt direction
		var angle_offset := deg_to_rad(randf_range(-branch_angle_spread, branch_angle_spread))
		var fork_direction := main_direction.rotated(angle_offset)
		var fork_end := branch_start + fork_direction * fork_length

		# Build a jagged path for the fork (fewer segments, smaller jag)
		var fork_points := _build_jagged_path(
			branch_start, fork_end,
			segment_length * 1.5,
			jag_amount * 0.6
		)

		# Create fork Line2D
		var fork_line := Line2D.new()
		fork_line.width = bolt_width * branch_width_ratio
		fork_line.default_color = bolt_color
		fork_line.modulate = glow_color
		fork_line.modulate.a *= 0.7  # Forks slightly dimmer
		fork_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		fork_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		fork_line.joint_mode = Line2D.LINE_JOINT_ROUND

		for p in fork_points:
			fork_line.add_point(p)

		branch_container.add_child(fork_line)
		branch_count += 1


func _build_jagged_path(from: Vector2, to: Vector2, seg_len: float, jag: float) -> Array[Vector2]:
	"""Build a jagged polyline between two points."""
	var path: Array[Vector2] = [from]
	var direction := to - from
	var distance := direction.length()

	if distance < 1.0:
		path.append(to)
		return path

	var segments := int(distance / seg_len)
	segments = max(segments, 3)
	var step := direction / float(segments)
	var perpendicular := direction.normalized().rotated(PI / 2.0)

	for i in range(1, segments):
		var base_point := from + step * float(i)
		# Offset decreases near endpoints for cleaner connections
		var edge_factor: float = 1.0 - abs(2.0 * float(i) / float(segments) - 1.0)
		edge_factor = edge_factor * edge_factor  # Quadratic falloff
		var offset: Vector2 = perpendicular * randf_range(-jag, jag) * edge_factor
		path.append(base_point + offset)

	path.append(to)
	return path


func _apply_points_to_line(line: Line2D, points: Array[Vector2]):
	line.clear_points()
	for p in points:
		line.add_point(p)

# ============================================================================
# ORB DRAWING
# ============================================================================

func _draw():
	if not orb_enabled or _orb_alpha <= 0.0:
		return
	_draw_orb(_from)
	_draw_orb(_to)


func _draw_orb(center: Vector2):
	# Glow rings: drawn outside-in so inner rings paint over outer ones.
	# Alpha ramps up quadratically toward the center.
	for i in orb_glow_layers:
		var t := float(i + 1) / float(orb_glow_layers + 1)
		var radius := lerpf(orb_radius * orb_glow_scale, orb_radius, t)
		var ring := orb_glow_color
		ring.a = lerpf(0.0, orb_glow_color.a, t * t) * _orb_alpha
		draw_circle(center, radius, ring)

	# Solid bright core on top
	var core := orb_core_color
	core.a = minf(orb_core_color.a * _orb_alpha, 1.0)
	draw_circle(center, orb_radius * 0.5, core)


func _set_orb_alpha(alpha: float):
	_orb_alpha = alpha
	queue_redraw()

# ============================================================================
# VISIBILITY HELPERS
# ============================================================================

func _set_bolt_visible(show: bool):
	bolt_line.visible = show
	core_line.visible = show
	for child in branch_container.get_children():
		if child is Line2D:
			child.visible = show
	_set_orb_alpha(1.0 if show else 0.0)


func _set_bolt_afterimage():
	"""Show a very faint ghost of the current bolt (persistence of vision)."""
	bolt_line.visible = true
	core_line.visible = false
	bolt_line.modulate.a = afterimage_alpha
	for child in branch_container.get_children():
		if child is Line2D:
			child.visible = true
			child.modulate.a = afterimage_alpha * 0.5
	_set_orb_alpha(afterimage_alpha)
	# Reset alpha for next visible frame
	await get_tree().process_frame
	bolt_line.modulate = glow_color  # Restore for next _set_bolt_visible call
	_set_orb_alpha(1.0)
