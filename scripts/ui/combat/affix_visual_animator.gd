# res://scripts/ui/combat/affix_visual_animator.gd
# Plays visual effects when dice affixes activate.
# Listens to DiceAffixProcessor.affix_activated, resolves die indices
# to visual nodes via DicePoolDisplay, and runs the configured animations.
#
# Supports deferred value display: dice initially show BASE rolled values.
# During affix visual playback, die values animate to their post-affix totals
# in sync with the visual effects (e.g. siphon projectile → drain tick down,
# arrive → gain tick up).
#
# Add as a child of CombatUI. Call initialize() after combat setup.
extends Node
class_name AffixVisualAnimator

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when all queued affix visuals have finished playing
signal all_visuals_complete

# ============================================================================
# REFERENCES (set via initialize())
# ============================================================================

## The DicePoolDisplay that holds CombatDieObject visuals
var dice_pool_display: DicePoolDisplay = null

## CanvasLayer container for projectiles (renders above dice)
var _effects_layer: CanvasLayer = null
var _effects_container: Control = null

# ============================================================================
# QUEUE — track active animations and deferred playback
# ============================================================================
var _active_animations: int = 0

## Pending activations queued when visuals don't exist yet (e.g. during roll_hand).
## Flushed after CombatRollAnimator completes or when flush_pending() is called.
var _pending_activations: Array[Dictionary] = []

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	# Create effects overlay layer
	_effects_layer = CanvasLayer.new()
	_effects_layer.name = "AffixEffectsOverlay"
	_effects_layer.layer = 99  # Below CombatRollAnimator's 100
	add_child(_effects_layer)
	
	_effects_container = Control.new()
	_effects_container.name = "EffectsContainer"
	_effects_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effects_layer.add_child(_effects_container)


func initialize(hand_display: DicePoolDisplay, processor: DiceAffixProcessor, roll_animator: CombatRollAnimator = null):
	"""Connect to the processor's signal and store display reference.
	Call during CombatUI setup, after the processor is created.
	
	If roll_animator is provided, pending visuals auto-flush after the
	roll animation completes (when die visuals are guaranteed to exist)."""
	dice_pool_display = hand_display
	
	if processor:
		if not processor.affix_activated.is_connected(_on_affix_activated):
			processor.affix_activated.connect(_on_affix_activated)
		print("🎬 AffixVisualAnimator: Connected to processor")
	
	if roll_animator:
		if not roll_animator.roll_animation_complete.is_connected(_on_roll_animation_complete):
			roll_animator.roll_animation_complete.connect(_on_roll_animation_complete)
		print("🎬 AffixVisualAnimator: Connected to roll_animator for deferred playback")


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_affix_activated(source_die: DieResource, affix: DiceAffix, targets: Array[int]):
	"""Called when any affix fires. Queue if visuals don't exist yet, play if they do."""
	if not affix.roll_visual:
		return
	if affix.roll_visual.animation_type == AffixRollVisual.AnimationType.NONE:
		return
	
	var source_visual = _get_die_visual(source_die.slot_index)
	
	if not source_visual:
		# Visuals not created yet (e.g. during roll_hand before refresh).
		# Queue for playback after roll animation reveals the dice.
		_pending_activations.append({
			"source_slot": source_die.slot_index,
			"roll_visual": affix.roll_visual,
			"targets": targets.duplicate(),
		})
		print("  🎬 AffixVisualAnimator: Queued %s (visuals pending)" % affix.affix_name)
		return
	
	# Visuals exist — play immediately
	_play_activation(affix.roll_visual, source_die.slot_index, targets)


func _on_roll_animation_complete():
	"""Called after CombatRollAnimator finishes — die visuals now exist."""
	flush_pending()


func flush_pending():
	"""Play all queued affix visuals. Call after die visuals are created."""
	if _pending_activations.is_empty():
		# Even with no affix visuals, finalize any deferred values
		_finalize_deferred_values()
		return
	
	print("🎬 AffixVisualAnimator: Flushing %d pending activations" % _pending_activations.size())
	
	var to_play = _pending_activations.duplicate()
	_pending_activations.clear()
	
	for activation in to_play:
		await _play_activation(
			activation.roll_visual,
			activation.source_slot,
			activation.targets
		)
	
	# After all affix visuals, finalize any remaining deferred value changes
	_finalize_deferred_values()


func _play_activation(rv: AffixRollVisual, source_slot: int, targets: Array):
	"""Resolve visuals from slot indices and play the animation.
	Skips playback if no actual value changes occurred for involved dice."""
	var source_visual = _get_die_visual(source_slot)
	if not source_visual:
		print("  ⚠️ AffixVisualAnimator: Still no visual for source index %d" % source_slot)
		return
	
	# Skip visual if no actual value changes occurred for any involved dice
	var has_any_change = not _get_value_change(source_slot).is_empty()
	if not has_any_change:
		for t_idx in targets:
			if not _get_value_change(t_idx).is_empty():
				has_any_change = true
				break
	if not has_any_change:
		print("  🎬 AffixVisualAnimator: Skipping visual — no value change")
		return
	
	# Collect target visuals
	var target_visuals: Array[Control] = []
	for t_idx in targets:
		var tv = _get_die_visual(t_idx)
		if tv:
			target_visuals.append(tv)
	
	# For SELF-targeting affixes, treat source as the target
	if target_visuals.is_empty():
		target_visuals.append(source_visual)
	
	# Play the visual (non-blocking fire-and-forget, tracked by counter)
	await _play_roll_visual(rv, source_visual, target_visuals)

# ============================================================================
# DEFERRED VALUE ANIMATION
# ============================================================================

func _get_value_change(die_index: int) -> Dictionary:
	"""Look up the deferred value change for a die index.
	Returns {from: int, to: int} or empty dict if no change."""
	if not dice_pool_display or not dice_pool_display.dice_pool:
		return {}
	var pool = dice_pool_display.dice_pool
	if "pending_value_animations" not in pool:
		return {}
	return pool.pending_value_animations.get(die_index, {})


func _animate_die_value(die_visual: Control, change: Dictionary, duration: float = 0.25):
	"""Animate a die's value label from change.from → change.to.
	Also updates the underlying DieResource.modified_value."""
	if change.is_empty():
		return
	
	var from_val: int = change.get("from", 0)
	var to_val: int = change.get("to", 0)
	if from_val == to_val:
		return
	
	# Animate the visual label
	if die_visual is CombatDieObject and die_visual.has_method("animate_value_to"):
		var flash_color: Color
		if to_val > from_val:
			flash_color = Color(0.5, 1.5, 0.5, 1.0)  # Green for gain
		else:
			flash_color = Color(1.5, 0.5, 0.5, 1.0)  # Red for loss
		die_visual.animate_value_to(to_val, duration, flash_color)
	elif die_visual is CombatDieObject and die_visual.value_label:
		# Fallback: just set the text
		die_visual.value_label.text = str(to_val)
	
	# Mark this change as applied so _finalize doesn't double-animate
	_mark_value_applied(die_visual)


func _mark_value_applied(die_visual: Control):
	"""Mark a die's deferred value as already animated."""
	if not die_visual is CombatDieObject:
		return
	var die_index = die_visual.slot_index
	if not dice_pool_display or not dice_pool_display.dice_pool:
		return
	var pool = dice_pool_display.dice_pool
	if "pending_value_animations" not in pool:
		return
	if pool.pending_value_animations.has(die_index):
		# Apply the final value to DieResource and remove from pending
		var change = pool.pending_value_animations[die_index]
		if die_index < pool.hand.size():
			pool.hand[die_index].modified_value = change.to
		pool.pending_value_animations.erase(die_index)


func _finalize_deferred_values():
	"""Apply any remaining deferred value changes that weren't animated
	during affix visuals (e.g. from combat modifiers or affixes without visuals)."""
	if not dice_pool_display or not dice_pool_display.dice_pool:
		return
	var pool = dice_pool_display.dice_pool
	if "pending_value_animations" not in pool:
		return
	if pool.pending_value_animations.is_empty():
		return
	
	print("🎬 AffixVisualAnimator: Finalizing %d remaining value changes" % pool.pending_value_animations.size())
	
	for die_index in pool.pending_value_animations.keys():
		var change = pool.pending_value_animations[die_index]
		
		# Apply to DieResource
		if die_index < pool.hand.size():
			pool.hand[die_index].modified_value = change.to
		
		# Animate on visual if it exists
		var visual = _get_die_visual(die_index)
		if visual and visual is CombatDieObject and visual.has_method("animate_value_to"):
			var flash_color = Color(0.5, 1.5, 0.5, 1.0) if change.to > change.from else Color(1.5, 0.5, 0.5, 1.0)
			visual.animate_value_to(change.to, 0.25, flash_color)
	
	pool.pending_value_animations.clear()


# ============================================================================
# VISUAL PLAYBACK — DISPATCHER
# ============================================================================

func _play_roll_visual(rv: AffixRollVisual, source: Control, targets: Array[Control]):
	"""Dispatch to the appropriate animation handler."""
	_active_animations += 1
	
	# Start delay
	if rv.start_delay > 0:
		await get_tree().create_timer(rv.start_delay).timeout
	
	match rv.animation_type:
		AffixRollVisual.AnimationType.PROJECTILE:
			await _play_projectile(rv, source, targets)
		AffixRollVisual.AnimationType.ON_TARGET:
			await _play_die_effect_batch(rv, targets, true)
		AffixRollVisual.AnimationType.ON_SOURCE:
			await _play_die_effect_single(rv, source, false)
		AffixRollVisual.AnimationType.ON_BOTH:
			await _play_both(rv, source, targets)
	
	_active_animations -= 1
	if _active_animations <= 0:
		_active_animations = 0
		all_visuals_complete.emit()


# ============================================================================
# PROJECTILE ANIMATION
# ============================================================================

func _play_projectile(rv: AffixRollVisual, source: Control, targets: Array[Control]):
	"""Tween a projectile between source ↔ first target, with effects and
	value animations on both ends."""
	var target = targets[0] if targets.size() > 0 else source
	var is_self_target = (source == target)
	
	# Determine direction
	var from_node: Control
	var to_node: Control
	if rv.projectile_direction == AffixRollVisual.ProjectileDirection.TARGET_TO_SOURCE:
		from_node = target
		to_node = source
	else:
		from_node = source
		to_node = target
	
	var from_center = from_node.global_position + from_node.size / 2.0
	var to_center = to_node.global_position + to_node.size / 2.0
	
	# If self-targeting, skip projectile — just play source effect + value
	if is_self_target:
		_flash_die(source, rv.source_flash_color, rv.source_scale_pulse, rv.source_effect_duration)
		_spawn_impact_or_particles_at(rv.source_impact_scene, rv.source_particle_scene, from_center)
		# Animate value change on self
		var self_change = _get_value_change_for_visual(source)
		if not self_change.is_empty():
			_animate_die_value(source, self_change, rv.source_effect_duration)
		if rv.source_effect_duration > 0:
			await get_tree().create_timer(rv.source_effect_duration).timeout
		return
	
	# === LAUNCH: Flash origin + animate origin value ===
	if rv.source_flash_color != Color.WHITE or rv.source_scale_pulse > 1.0:
		_flash_die(from_node, rv.source_flash_color, rv.source_scale_pulse, rv.source_effect_duration)
	_spawn_impact_or_particles_at(rv.source_impact_scene, rv.source_particle_scene, from_center)
	
	# Animate the "from" die's value at launch (e.g., drained die goes 5→4)
	var from_change = _get_value_change_for_visual(from_node)
	if not from_change.is_empty():
		_animate_die_value(from_node, from_change, rv.travel_duration * 0.5)
	
	# === TRAVEL: Create and tween projectile ===
	var projectile: Node
	if rv.projectile_scene:
		projectile = _create_custom_projectile(rv)
	else:
		projectile = _create_builtin_projectile(rv)
	projectile.global_position = from_center - rv.projectile_size / 2.0
	
	var ease_type: Tween.EaseType
	var trans_type: Tween.TransitionType
	match rv.travel_ease:
		0:
			ease_type = Tween.EASE_IN
			trans_type = Tween.TRANS_LINEAR
		1:
			ease_type = Tween.EASE_IN
			trans_type = Tween.TRANS_CUBIC
		2:
			ease_type = Tween.EASE_OUT
			trans_type = Tween.TRANS_CUBIC
		_:
			ease_type = Tween.EASE_IN_OUT
			trans_type = Tween.TRANS_CUBIC
	
	var tween = create_tween()
	tween.tween_property(
		projectile, "global_position",
		to_center - rv.projectile_size / 2.0,
		rv.travel_duration
	).set_ease(ease_type).set_trans(trans_type)
	
	await tween.finished
	
	# === IMPACT: Flash destination + animate destination value ===
	_flash_die(to_node, rv.target_flash_color, rv.target_scale_pulse, rv.target_effect_duration)
	_spawn_impact_or_particles_at(rv.target_impact_scene, rv.target_particle_scene, to_center)
	
	# Animate the "to" die's value on impact (e.g., siphon die goes 3→4)
	var to_change = _get_value_change_for_visual(to_node)
	if not to_change.is_empty():
		_animate_die_value(to_node, to_change, rv.target_effect_duration)
	
	# Also flash remaining targets simultaneously
	for i in range(1, targets.size()):
		var extra_target = targets[i]
		if is_instance_valid(extra_target) and extra_target != target:
			var ec = extra_target.global_position + extra_target.size / 2.0
			_flash_die(extra_target, rv.target_flash_color, rv.target_scale_pulse, rv.target_effect_duration)
			_spawn_impact_or_particles_at(rv.target_impact_scene, rv.target_particle_scene, ec)
			var et_change = _get_value_change_for_visual(extra_target)
			if not et_change.is_empty():
				_animate_die_value(extra_target, et_change, rv.target_effect_duration)
	
	# Clean up projectile
	_cleanup_projectile(projectile)
	
	# Wait for target effect to finish
	if rv.target_effect_duration > 0:
		await get_tree().create_timer(rv.target_effect_duration).timeout


# ============================================================================
# DIE EFFECT ANIMATIONS
# ============================================================================

func _play_die_effect_single(rv: AffixRollVisual, die_visual: Control, is_target: bool):
	"""Play flash/pulse/particles/impact scene on a single die, with value animation."""
	var flash_color: Color
	var scale_pulse: float
	var duration: float
	var impact_scene: PackedScene
	var particle_scene: PackedScene
	var shader: ShaderMaterial
	
	if is_target:
		flash_color = rv.target_flash_color
		scale_pulse = rv.target_scale_pulse
		duration = rv.target_effect_duration
		impact_scene = rv.target_impact_scene
		particle_scene = rv.target_particle_scene
		shader = rv.target_shader
	else:
		flash_color = rv.source_flash_color
		scale_pulse = rv.source_scale_pulse
		duration = rv.source_effect_duration
		impact_scene = rv.source_impact_scene
		particle_scene = rv.source_particle_scene
		shader = rv.source_shader
	
	var center = die_visual.global_position + die_visual.size / 2.0
	
	# Temporary shader
	var old_material: Material = null
	if shader and die_visual is DieObjectBase and die_visual.fill_texture:
		old_material = die_visual.fill_texture.material
		die_visual.fill_texture.material = shader.duplicate(true)
	
	# Flash + scale
	_flash_die(die_visual, flash_color, scale_pulse, duration)
	
	# Impact scene or particles
	_spawn_impact_or_particles_at(impact_scene, particle_scene, center)
	
	# Animate deferred value change
	var change = _get_value_change_for_visual(die_visual)
	if not change.is_empty():
		_animate_die_value(die_visual, change, duration)
	
	if duration > 0:
		await get_tree().create_timer(duration).timeout
	
	# Restore material
	if shader and die_visual is DieObjectBase and die_visual.fill_texture:
		die_visual.fill_texture.material = old_material


func _play_die_effect_batch(rv: AffixRollVisual, die_visuals: Array[Control], is_target: bool):
	"""Play effects on multiple dice simultaneously, await longest."""
	var duration: float = rv.target_effect_duration if is_target else rv.source_effect_duration
	
	for dv in die_visuals:
		if is_instance_valid(dv):
			# Fire-and-forget each (they all run in parallel)
			_play_die_effect_single(rv, dv, is_target)
	
	# Wait for the duration once (all started simultaneously)
	if duration > 0:
		await get_tree().create_timer(duration).timeout


func _play_both(rv: AffixRollVisual, source: Control, targets: Array[Control]):
	"""Play source and target effects, optionally staggered."""
	# Source effect (fire-and-forget)
	_play_die_effect_single(rv, source, false)
	
	# Stagger
	if rv.stagger > 0:
		await get_tree().create_timer(rv.stagger).timeout
	
	# Target effects (await these)
	await _play_die_effect_batch(rv, targets, true)


# ============================================================================
# VALUE CHANGE LOOKUP HELPER
# ============================================================================

func _get_value_change_for_visual(die_visual: Control) -> Dictionary:
	"""Look up the deferred value change for a die visual by its slot_index."""
	if not die_visual is CombatDieObject:
		return {}
	return _get_value_change(die_visual.slot_index)


# ============================================================================
# PRIMITIVES — FLASH / PULSE
# ============================================================================

func _flash_die(die_visual: Control, flash_color: Color, scale_pulse: float, duration: float):
	"""Apply a modulate flash and optional scale pulse to a die visual."""
	if not is_instance_valid(die_visual):
		return
	if flash_color == Color.WHITE and scale_pulse <= 1.0:
		return  # Nothing to do
	
	var half = duration / 2.0
	
	if flash_color != Color.WHITE:
		var color_tween = die_visual.create_tween()
		color_tween.tween_property(die_visual, "modulate", flash_color, half)
		color_tween.tween_property(die_visual, "modulate", Color.WHITE, half)
	
	if scale_pulse > 1.0:
		var original_scale = die_visual.scale
		var pulse_target = original_scale * scale_pulse
		var scale_tween = die_visual.create_tween()
		scale_tween.tween_property(die_visual, "scale", pulse_target, half) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		scale_tween.tween_property(die_visual, "scale", original_scale, half) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)


# ============================================================================
# PRIMITIVES — SCENE SPAWNING
# ============================================================================

func _spawn_impact_or_particles_at(impact_scene: PackedScene, particle_scene: PackedScene, global_center: Vector2):
	"""Spawn an impact scene (preferred) or particle scene (fallback) at a position."""
	if impact_scene:
		_spawn_scene_at(impact_scene, global_center)
	elif particle_scene:
		_spawn_particles_at(particle_scene, global_center)


func _spawn_scene_at(scene: PackedScene, global_center: Vector2):
	"""Instance a custom scene at a global position. Auto-frees when done."""
	if not scene:
		return
	
	var instance = scene.instantiate()
	_effects_container.add_child(instance)
	
	# Position at center
	if instance is Node2D:
		instance.global_position = global_center
	elif instance is Control:
		instance.global_position = global_center - instance.size / 2.0
	
	# Start any particles
	for child in instance.get_children():
		if child is GPUParticles2D or child is CPUParticles2D:
			child.emitting = true
	if instance is GPUParticles2D or instance is CPUParticles2D:
		instance.emitting = true
	
	# Start any AnimatedSprite2D and auto-free when it finishes
	var has_auto_free = false
	
	if instance is AnimatedSprite2D:
		instance.play()
		instance.animation_finished.connect(instance.queue_free)
		has_auto_free = true
	
	for child in instance.get_children():
		if child is AnimatedSprite2D and not has_auto_free:
			child.play()
			child.animation_finished.connect(instance.queue_free)
			has_auto_free = true
		elif child is AnimationPlayer and not has_auto_free:
			if child.has_animation("play"):
				child.play("play")
				child.animation_finished.connect(func(_anim_name): instance.queue_free())
				has_auto_free = true
			elif child.has_animation("default"):
				child.play("default")
				child.animation_finished.connect(func(_anim_name): instance.queue_free())
				has_auto_free = true
	
	if not has_auto_free:
		if instance is GPUParticles2D and instance.one_shot:
			instance.finished.connect(instance.queue_free)
			has_auto_free = true
		elif instance is CPUParticles2D and instance.one_shot:
			instance.finished.connect(instance.queue_free)
			has_auto_free = true
	
	if not has_auto_free:
		get_tree().create_timer(2.0).timeout.connect(
			func():
				if is_instance_valid(instance):
					instance.queue_free(),
			CONNECT_ONE_SHOT
		)


func _spawn_particles_at(particle_scene: PackedScene, global_center: Vector2):
	"""Instantiate a simple particle scene at a global position with auto-cleanup."""
	if not particle_scene:
		return
	
	var particles = particle_scene.instantiate()
	_effects_container.add_child(particles)
	
	if particles is Node2D:
		particles.global_position = global_center
	elif particles is Control:
		particles.global_position = global_center
	
	if particles is GPUParticles2D:
		particles.emitting = true
		particles.finished.connect(particles.queue_free)
	elif particles is CPUParticles2D:
		particles.emitting = true
		particles.finished.connect(particles.queue_free)
	else:
		get_tree().create_timer(2.0).timeout.connect(particles.queue_free)


# ============================================================================
# PRIMITIVES — PROJECTILE CREATION
# ============================================================================

func _create_custom_projectile(rv: AffixRollVisual) -> Node:
	"""Instance a custom projectile scene. Applied modulate color."""
	var instance = rv.projectile_scene.instantiate()
	_effects_container.add_child(instance)
	instance.modulate = rv.projectile_color
	
	if instance is Control:
		instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for child in instance.get_children():
		if child is GPUParticles2D or child is CPUParticles2D:
			child.emitting = true
	if instance is GPUParticles2D or instance is CPUParticles2D:
		instance.emitting = true
	
	if instance is AnimatedSprite2D:
		instance.play()
	for child in instance.get_children():
		if child is AnimatedSprite2D:
			child.play()
	
	return instance


func _create_builtin_projectile(rv: AffixRollVisual) -> Control:
	"""Build the default projectile with TextureRect + CPUParticles2D trail."""
	var container = Control.new()
	container.name = "AffixProjectile"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size = rv.projectile_size
	_effects_container.add_child(container)
	
	# Visual texture
	var tex_rect = TextureRect.new()
	tex_rect.name = "Visual"
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if rv.projectile_texture:
		tex_rect.texture = rv.projectile_texture
	if rv.projectile_material:
		tex_rect.material = rv.projectile_material.duplicate(true)
	tex_rect.modulate = rv.projectile_color
	container.add_child(tex_rect)
	
	# Built-in CPUParticles2D trail
	var trail = CPUParticles2D.new()
	trail.name = "Trail"
	trail.emitting = true
	trail.amount = 12
	trail.lifetime = 0.25
	trail.explosiveness = 0.0
	trail.randomness = 0.3
	trail.direction = Vector2.ZERO
	trail.spread = 180.0
	trail.initial_velocity_min = 3.0
	trail.initial_velocity_max = 12.0
	trail.scale_amount_min = 1.5
	trail.scale_amount_max = 4.0
	trail.gravity = Vector2.ZERO
	trail.position = rv.projectile_size / 2.0
	
	var gradient = Gradient.new()
	gradient.set_color(0, rv.trail_color)
	gradient.set_color(1, Color(rv.trail_color.r, rv.trail_color.g, rv.trail_color.b, 0.0))
	trail.color_ramp = gradient
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	trail.scale_amount_curve = scale_curve
	
	container.add_child(trail)
	
	if rv.travel_particle_scene:
		var travel_particles = rv.travel_particle_scene.instantiate()
		travel_particles.position = rv.projectile_size / 2.0
		if travel_particles is GPUParticles2D or travel_particles is CPUParticles2D:
			travel_particles.emitting = true
		container.add_child(travel_particles)
	
	return container


func _cleanup_projectile(projectile: Node):
	"""Hide projectile visual immediately, let trail/particles fade, then free."""
	if projectile.has_node("Visual"):
		projectile.get_node("Visual").visible = false
	
	if projectile is Node2D:
		if projectile.has_method("hide"):
			projectile.hide()
	elif projectile is Control:
		if not projectile.has_node("Visual"):
			projectile.modulate.a = 0.0
	
	for child in projectile.get_children():
		if child is GPUParticles2D or child is CPUParticles2D:
			child.emitting = false
	
	get_tree().create_timer(0.5).timeout.connect(
		func():
			if is_instance_valid(projectile):
				projectile.queue_free(),
		CONNECT_ONE_SHOT
	)


# ============================================================================
# VISUAL LOOKUP
# ============================================================================

func _get_die_visual(die_index: int) -> Control:
	"""Resolve a hand die index to its CombatDieObject visual node."""
	if not dice_pool_display:
		return null
	
	if die_index >= 0 and die_index < dice_pool_display.die_visuals.size():
		var visual = dice_pool_display.die_visuals[die_index]
		if is_instance_valid(visual):
			return visual
	
	return null
