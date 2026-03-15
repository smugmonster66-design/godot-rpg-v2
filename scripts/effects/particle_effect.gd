# res://scripts/effects/particle_effect.gd
# Plays a particle burst as a combat effect, with optional sprite sheet overlay
# and optional BurstParticles2D layer.
#
# Scene structure:
#   ParticleEffect (Node2D) ← this script
#     ├─ GPUParticles2D (one or more) — standard GPU particle emitters (optional)
#     ├─ BurstParticles2D             — one-shot burst particle layer (optional)
#     └─ AnimatedSprite2D             — sprite sheet overlay (optional)
#
# Any combination of children is valid.
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

@onready var gpu_particles: Array[GPUParticles2D] = _find_all_gpu_particles()
@onready var burst: Node2D = _find_burst_child()
@onready var sprite: AnimatedSprite2D = _find_child_of_class("AnimatedSprite2D")

func play():
	if gpu_particles.is_empty() and not burst and not sprite:
		push_warning("ParticleEffect: No GPUParticles2D, BurstParticles2D, or AnimatedSprite2D child found")
		_on_finished()
		return

	effect_started.emit()

	# --- Start all GPUParticles2D ---
	var max_particle_duration: float = 0.0
	for p in gpu_particles:
		if use_color_override:
			p.modulate = color_override
		p.emitting = true
		var p_dur: float = p.lifetime if one_shot else duration
		max_particle_duration = maxf(max_particle_duration, p_dur)

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

	# --- Wait for the longest duration across all children ---
	var total_wait: float = maxf(max_particle_duration, burst_duration)
	if total_wait > 0.0:
		await get_tree().create_timer(total_wait).timeout

	# Stop all GPU emitters
	for p in gpu_particles:
		p.emitting = false

	# --- Wait for sprite if it's still going ---
	if sprite and not sprite_finished:
		await sprite.animation_finished

	_on_finished()


func _find_all_gpu_particles() -> Array[GPUParticles2D]:
	var result: Array[GPUParticles2D] = []
	for child in get_children():
		if child is GPUParticles2D:
			result.append(child)
	return result


func _find_child_of_class(class_name_str: String) -> Node:
	for child in get_children():
		if child.get_class() == class_name_str:
			return child
	return null

func _find_burst_child() -> Node2D:
	"""Find BurstParticles2D child. It's an addon type, so check by script class name."""
	for child in get_children():
		if child.get_class() == "BurstParticles2D":
			return child
		# BurstParticles2D may report as Node2D — check script class
		if child.get_script() and child.has_method("burst"):
			return child
	return null
