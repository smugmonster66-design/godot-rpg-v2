# res://scripts/effects/particle_effect.gd
# Plays a particle burst as a combat effect, with optional sprite sheet overlay.
#
# Scene structure:
#   ParticleEffect (Node2D) ← this script
#     ├─ GPUParticles2D          — required particle emitter
#     └─ AnimatedSprite2D        — optional sprite sheet (plays concurrently)
#
# If an AnimatedSprite2D child exists, it plays alongside the particles.
# Duration is whichever finishes last (particle lifetime vs sprite animation).
# If no AnimatedSprite2D is present, behavior is identical to before.
extends CombatEffectBase
class_name ParticleEffect

@export var one_shot: bool = true
@export var color_override: Color = Color.WHITE
@export var use_color_override: bool = false

@export_group("Sprite Sheet")
## Which animation to play on the AnimatedSprite2D child (if present)
@export var sprite_animation: String = "default"
## Apply color_override to the sprite as well (via modulate)
@export var tint_sprite: bool = false

@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func play():
	if not particles and not sprite:
		push_warning("ParticleEffect: No GPUParticles2D or AnimatedSprite2D child found")
		_on_finished()
		return

	effect_started.emit()

	# --- Start particles ---
	var particle_duration: float = 0.0
	if particles:
		if use_color_override:
			particles.modulate = color_override

		particles.emitting = true

		if one_shot:
			particle_duration = particles.lifetime
		else:
			particle_duration = duration

	# --- Start sprite concurrently ---
	var sprite_finished: bool = false
	if sprite:
		if tint_sprite and use_color_override:
			sprite.modulate = color_override

		if sprite.sprite_frames and sprite.sprite_frames.has_animation(sprite_animation):
			var frame_count = sprite.sprite_frames.get_frame_count(sprite_animation)
			if frame_count > 0:
				sprite.play(sprite_animation)
				# Track when sprite finishes (don't await — runs in parallel)
				sprite.animation_finished.connect(func(): sprite_finished = true, CONNECT_ONE_SHOT)
			else:
				sprite_finished = true
		else:
			push_warning("ParticleEffect: AnimatedSprite2D missing animation '%s'" % sprite_animation)
			sprite_finished = true

	# --- Wait for particles ---
	if particles and particle_duration > 0.0:
		await get_tree().create_timer(particle_duration).timeout
		particles.emitting = false

	# --- Wait for sprite if it's still going ---
	if sprite and not sprite_finished:
		await sprite.animation_finished

	_on_finished()
