# res://scripts/effects/projectile_effect.gd
# A projectile that travels from source to target position
extends CombatEffectBase
class_name ProjectileEffect

signal reached_target()

@export_group("Movement")
@export var rotate_to_target: bool = true
@export var trail_particles: bool = true

@export_group("Visual")
@export var spin_speed: float = 0.0  # Degrees per second (0 = no spin)

@onready var sprite = $Sprite2D
@onready var trail = $GPUParticles2D
@onready var audio = $AudioStreamPlayer2D

var target_position: Vector2
var travel_curve: Curve
var travel_duration: float = 0.4
var _start_position: Vector2

func setup(from: Vector2, to: Vector2, p_duration: float = 0.4, p_curve: Curve = null):
	"""Configure projectile path"""
	_start_position = from
	global_position = from
	target_position = to
	travel_duration = p_duration
	travel_curve = p_curve
	
	if rotate_to_target:
		rotation = from.angle_to_point(to)

func play():
	effect_started.emit()
	
	# Start trail particles
	if trail_particles and trail:
		trail.emitting = true
	
	# Play sound if exists
	if audio and audio.stream:
		audio.play()
	
	var tween = create_tween()
	
	if travel_curve:
		# Curved path (arc)
		tween.tween_method(_follow_curve, 0.0, 1.0, travel_duration)
	else:
		# Straight line
		tween.tween_property(self, "global_position", target_position, travel_duration)
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Optional spin during flight
	if spin_speed != 0.0 and sprite:
		var spin_tween = create_tween()
		spin_tween.tween_property(sprite, "rotation_degrees", spin_speed * travel_duration, travel_duration)
	
	await tween.finished
	reached_target.emit()
	
	# Stop trail and wait for particles to fade
	if trail and trail_particles:
		trail.emitting = false
		await get_tree().create_timer(trail.lifetime).timeout
	
	_on_finished()

func _follow_curve(t: float):
	"""Follow a curved path using the travel_curve for height offset"""
	var linear_pos = _start_position.lerp(target_position, t)
	
	# Apply curve for arc height (Y offset)
	var height_offset = travel_curve.sample(t) * 100  # Adjust multiplier as needed
	global_position = linear_pos + Vector2(0, -height_offset)
	
	# Update rotation to face movement direction if enabled
	if rotate_to_target and t > 0:
		var prev_pos = _start_position.lerp(target_position, max(0, t - 0.05))
		var prev_height = travel_curve.sample(max(0, t - 0.05)) * 100
		var prev_full = prev_pos + Vector2(0, -prev_height)
		rotation = prev_full.angle_to_point(global_position)
