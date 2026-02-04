# res://scripts/effects/particle_effect.gd
# Plays a particle burst as a combat effect
extends CombatEffectBase
class_name ParticleEffect

@export var one_shot: bool = true
@export var color_override: Color = Color.WHITE
@export var use_color_override: bool = false

@onready var particles: GPUParticles2D = $GPUParticles2D

func play():
	if not particles:
		push_warning("ParticleEffect: No GPUParticles2D child found")
		_on_finished()
		return
	
	effect_started.emit()
	
	# Apply color override if set
	if use_color_override:
		particles.modulate = color_override
	
	particles.emitting = true
	
	if one_shot:
		# Wait for particles to finish their lifetime
		await get_tree().create_timer(particles.lifetime).timeout
	else:
		# Use the base duration
		await get_tree().create_timer(duration).timeout
	
	particles.emitting = false
	_on_finished()
