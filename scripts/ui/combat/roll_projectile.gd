# res://scripts/ui/combat/roll_projectile.gd
# Lightweight projectile visual for dice roll animations
# Spawned by CombatRollAnimator, shows die face with shader + particle trail
extends Control
class_name RollProjectile

# ============================================================================
# CHILD NODES (created in _ready)
# ============================================================================
var visual: TextureRect = null
var trail: CPUParticles2D = null

# ============================================================================
# CONFIG
# ============================================================================
var projectile_size: Vector2 = Vector2(48, 48)

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_visual()
	_create_trail()

func _create_visual():
	"""Create the TextureRect that shows the die face + shader"""
	visual = TextureRect.new()
	visual.name = "Visual"
	visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(visual)

func _create_trail():
	"""Create CPUParticles2D trail behind the projectile"""
	trail = CPUParticles2D.new()
	trail.name = "Trail"
	trail.emitting = false
	trail.amount = 16
	trail.lifetime = 0.3
	trail.speed_scale = 1.0
	trail.explosiveness = 0.0
	trail.randomness = 0.5
	trail.direction = Vector2(0, 0)
	trail.spread = 180.0
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 20.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 5.0
	trail.gravity = Vector2.ZERO
	
	# Color ramp: semi-opaque white → fully transparent
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.6))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	trail.color_ramp = gradient
	
	# Scale curve: full size → zero (particles shrink over lifetime)
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	trail.scale_amount_curve = scale_curve
	
	add_child(trail)

# ============================================================================
# CONFIGURATION
# ============================================================================

func configure(texture: Texture2D, shader_material: Material, tint: Color = Color.WHITE, proj_size: Vector2 = Vector2(48, 48)):
	"""Configure projectile appearance to match a die's fill texture + shader"""
	projectile_size = proj_size
	custom_minimum_size = proj_size
	size = proj_size
	pivot_offset = proj_size / 2
	
	if visual:
		if texture:
			visual.texture = texture
		if shader_material:
			visual.material = shader_material.duplicate()
		visual.modulate = tint
	
	if trail:
		trail.position = proj_size / 2
		# Tint trail particles to match the die color
		trail.color = tint

# ============================================================================
# EMISSION CONTROL
# ============================================================================

func start_emitting():
	"""Start the particle trail"""
	if trail:
		trail.emitting = true

func stop_emitting():
	"""Stop emitting new particles (existing ones fade naturally)"""
	if trail:
		trail.emitting = false
