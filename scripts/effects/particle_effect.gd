# res://scripts/effects/particle_effect.gd
# Plays a particle burst as a combat effect, with optional sprite sheet overlay
# and optional BurstParticles2D layer.
#
# Scene structure:
#   ParticleEffect (Node2D) ← this script
#     ├─ GPUParticles2D          — standard GPU particle emitter (optional)
#     ├─ BurstParticles2D        — one-shot burst particle layer (optional)
#     └─ AnimatedSprite2D        — sprite sheet overlay (optional)
#
# Any combination of the three children is valid.
# Duration is whichever child takes longest to finish.
# BurstParticles2D child must have autoplay = false — this script fires it.
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

@onready var particles: GPUParticles2D = get_node_or_null("GPUParticles2D")
@onready var burst: Node2D = get_node_or_null("BurstParticles2D")
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

func play():
	if not particles and not burst and not sprite:
		push_warning("ParticleEffect: No GPUParticles2D, BurstParticles2D, or AnimatedSprite2D child found")
		_on_finished()
		return

	effect_started.emit()

	# --- Start GPUParticles2D ---
	var particle_duration: float = 0.0
	if particles:
		if use_color_override:
			particles.modulate = color_override
		particles.emitting = true
		particle_duration = particles.lifetime if one_shot else duration

	# --- Start BurstParticles2D ---
	# We read lifetime before calling burst() because the node frees itself
	# after finishing — the reference becomes invalid once finished fires.
	var burst_duration: float = 0.0
	if burst:
		if use_color_override: burst.modulate = color_override
		burst_duration = burst.get("lifetime") if "lifetime" in burst else duration
		burst.burst()

	# --- Start AnimatedSprite2D concurrently ---
	var sprite_finished: bool = false
	if sprite:
		if tint_sprite and use_color_override:
			sprite.modulate = color_override
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(sprite_animation):
			var frame_count = sprite.sprite_frames.get_frame_count(sprite_animation)
			if frame_count > 0:
				sprite.play(sprite_animation)
				sprite.animation_finished.connect(func(): sprite_finished = true, CONNECT_ONE_SHOT)
			else:
				sprite_finished = true
		else:
			push_warning("ParticleEffect: AnimatedSprite2D missing animation '%s'" % sprite_animation)
			sprite_finished = true

	# --- Wait for GPUParticles2D ---
	if particles and particle_duration > 0.0:
		await get_tree().create_timer(particle_duration).timeout
		particles.emitting = false

	# --- Wait for BurstParticles2D if still running ---
	# We use a timer fallback rather than awaiting the signal directly,
	# because the node may have already freed itself by the time we get here.
	if burst and burst_duration > 0.0:
		var burst_wait: float = burst_duration - particle_duration
		if burst_wait > 0.0:
			await get_tree().create_timer(burst_wait).timeout

	# --- Wait for sprite if it's still going ---
	if sprite and not sprite_finished:
		await sprite.animation_finished

	_on_finished()
