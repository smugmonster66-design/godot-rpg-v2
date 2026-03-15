# res://scripts/effects/combat_animation_player.gd
# Signal-based animation sequencer. Each effect plays to completion via its
# own finished signal — no timer-based duration fallbacks.
# Stage flow: Cast → (Fire + Travel concurrent) → Impact
extends Node
class_name CombatAnimationPlayer

signal animation_sequence_started()
signal cast_finished()
signal fire_started()
signal travel_finished()
signal impact_finished()
signal animation_sequence_finished()
signal apply_effect_now()  # Connect to this for damage timing

## Layer to spawn effects on (should be high z_index)
@export var effects_layer: CanvasLayer


func _ready():
	# Auto-find effects layer if not exported
	if not effects_layer:
		effects_layer = get_parent().find_child("EffectsLayer", false, false)
		if not effects_layer:
			push_warning("CombatAnimationPlayer: EffectsLayer not found!")


func play_action_animation(
	animation_set: CombatAnimationSet,
	source_position: Vector2,
	target_positions: Array[Vector2],
	target_nodes: Array[Node2D] = []
) -> void:
	"""Play full animation sequence for an action.
	Flow: Cast awaits completion → Fire+Travel start concurrently →
	Travel awaits completion → Impact awaits completion."""

	if not animation_set:
		apply_effect_now.emit()
		return

	var has_cast = animation_set.cast_preset or animation_set.cast_effect
	var has_fire = animation_set.fire_preset or animation_set.fire_effect
	var has_travel = animation_set.travel_effect and target_positions.size() > 0
	var has_impact = (animation_set.impact_preset or animation_set.impact_effect) and target_positions.size() > 0

	animation_sequence_started.emit()

	# 1. Cast animation (at source/action field) — always awaited
	if has_cast:
		await _play_cast(animation_set, source_position)

	if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_CAST:
		apply_effect_now.emit()

	cast_finished.emit()

	# 2. Fire animation (at source, concurrent with travel — not awaited)
	if has_fire:
		_play_fire(animation_set, source_position)
		fire_started.emit()
		if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_FIRE:
			apply_effect_now.emit()

	# 3. Travel animation (projectile to each target) — awaited
	if has_travel:
		await _play_travel(animation_set, source_position, target_positions)

	if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_TRAVEL_END:
		apply_effect_now.emit()

	travel_finished.emit()

	# 4. Impact animation (at each target) — awaited
	if has_impact:
		if animation_set.impact_delay > 0:
			await get_tree().create_timer(animation_set.impact_delay).timeout
		# Emit before awaiting — damage and status effects fire as the
		# impact visual starts, not after it finishes.
		if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_IMPACT:
			apply_effect_now.emit()
		await _play_impact(animation_set, target_positions, target_nodes)
	else:
		# No impact animation — still need to fire if ON_IMPACT was selected
		if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_IMPACT:
			apply_effect_now.emit()

	impact_finished.emit()
	animation_sequence_finished.emit()


# ============================================================================
# STAGE PLAYERS
# ============================================================================

func _play_cast(anim_set: CombatAnimationSet, position: Vector2):
	var cast_pos = position + anim_set.cast_offset

	# Path A: PackedScene cast effect (Node2D-based, e.g. ParticleEffect)
	if anim_set.cast_effect and anim_set.cast_effect is PackedScene:
		var effect = anim_set.cast_effect.instantiate()
		_add_effect(effect, cast_pos)
		effect.scale *= anim_set.cast_scale

		if anim_set.cast_sound:
			_play_sound(anim_set.cast_sound, cast_pos)

		if effect.has_method("play"):
			effect.play()
		await _await_effect_finished(effect)
		return

	# Path B: CombatEffectPreset cast (Control-based, created programmatically)
	if anim_set.cast_preset:
		var effect = CombatAnimationSet.create_effect_from_preset(anim_set.cast_preset)
		if effect:
			_add_effect(effect, cast_pos)
			_configure_effect(effect, anim_set.cast_preset, cast_pos, cast_pos)

			if anim_set.cast_sound:
				_play_sound(anim_set.cast_sound, cast_pos)

			await effect.play()
			return


func _play_fire(anim_set: CombatAnimationSet, position: Vector2):
	"""Spawn fire effect at source. Not awaited — runs concurrently with travel."""
	var fire_pos = position + anim_set.fire_offset

	# Path A: PackedScene fire effect
	if anim_set.fire_effect and anim_set.fire_effect is PackedScene:
		var effect = anim_set.fire_effect.instantiate()
		_add_effect(effect, fire_pos)
		effect.scale *= anim_set.fire_scale

		if anim_set.fire_sound:
			_play_sound(anim_set.fire_sound, fire_pos)

		if effect.has_method("play"):
			effect.play()
			# Effect self-cleans via effect_finished or free_when_finished
		else:
			# No play method — connect cleanup to whatever signal exists
			_connect_auto_cleanup(effect)
		return

	# Path B: CombatEffectPreset fire
	if anim_set.fire_preset:
		var effect = CombatAnimationSet.create_effect_from_preset(anim_set.fire_preset)
		if effect:
			_add_effect(effect, fire_pos)
			_configure_effect(effect, anim_set.fire_preset, fire_pos, fire_pos)

			if anim_set.fire_sound:
				_play_sound(anim_set.fire_sound, fire_pos)

			effect.play()  # Don't await — runs concurrently


func _play_travel(anim_set: CombatAnimationSet, from: Vector2, targets: Array[Vector2]):
	var projectiles: Array = []

	for target_pos in targets:
		var projectile = anim_set.travel_effect.instantiate()
		_add_effect(projectile, from)
		projectile.scale *= anim_set.travel_scale

		if projectile.has_method("setup"):
			projectile.setup(from, target_pos, anim_set.travel_duration, anim_set.travel_curve)

		if anim_set.travel_sound:
			_play_sound(anim_set.travel_sound, from)

		if projectile.has_method("play"):
			projectile.play()

		projectiles.append(projectile)

	# Wait for all projectiles
	for proj in projectiles:
		if proj.has_signal("reached_target"):
			await proj.reached_target


func _play_impact(anim_set: CombatAnimationSet, positions: Array[Vector2], nodes: Array[Node2D]):
	var effects: Array = []

	for i in range(positions.size()):
		var pos = positions[i] + (anim_set.impact_offset if anim_set.impact_offset else Vector2.ZERO)
		var effect: Node

		# Preset takes priority
		if anim_set.impact_preset:
			var combat_effect = CombatAnimationSet.create_effect_from_preset(anim_set.impact_preset)
			if combat_effect:
				_add_effect(combat_effect, pos)
				var source_pos = positions[0] if positions.size() > 0 else pos
				_configure_effect(combat_effect, anim_set.impact_preset, source_pos, pos)
				if i < nodes.size() and nodes[i]:
					combat_effect.set_target_node(nodes[i])
				effect = combat_effect

		# Fallback to PackedScene
		if not effect and anim_set.impact_effect:
			effect = anim_set.impact_effect.instantiate()
			_add_effect(effect, pos)
			effect.scale *= anim_set.impact_scale
			if effect is ShaderEffect and i < nodes.size():
				effect.setup(nodes[i])

		if not effect:
			continue

		# Impact effects always draw above travel/cast effects
		if effect is Node2D:
			effect.z_index = 10

		if anim_set.impact_sound:
			_play_sound(anim_set.impact_sound, pos)

		if effect.has_method("play"):
			effect.play()

		effects.append(effect)

	# Wait for all impacts
	for effect in effects:
		await _await_effect_finished(effect)


# ============================================================================
# HELPERS
# ============================================================================

func _add_effect(effect: Node, position: Vector2):
	if effects_layer:
		effects_layer.add_child(effect)
	else:
		get_tree().root.add_child(effect)

	# CombatEffect subclasses use PRESET_FULL_RECT as a fullscreen overlay
	# and position particles internally via _target_pos from configure().
	if effect is CombatEffect:
		return

	if effect is Node2D:
		effect.global_position = position
	elif effect is Control:
		effect.global_position = position


func _configure_effect(combat_effect: Variant, preset: Variant, source_pos: Vector2, target_pos: Vector2):
	"""Route configure() call based on effect subclass type."""
	if combat_effect is SummonEffect:
		combat_effect.configure(preset, target_pos)
	elif combat_effect is EmanateEffect:
		combat_effect.configure(preset, source_pos)
	elif combat_effect is ImpactEffect:
		combat_effect.configure(preset, source_pos, target_pos)
	elif combat_effect is ShatterEffect:
		combat_effect.configure(preset, target_pos)
	elif combat_effect is ScatterConvergeEffect:
		combat_effect.configure(preset, source_pos, target_pos, {})
	else:
		if combat_effect.has_method("configure_base"):
			combat_effect.configure_base(preset, source_pos, target_pos)


func _await_effect_finished(effect: Node):
	"""Await whichever completion signal the effect emits."""
	# Primary: CombatEffect and similar
	if effect.has_signal("effect_finished"):
		await effect.effect_finished
		return
	# Secondary: ScatterConvergeEffect and similar
	if effect.has_signal("finished"):
		await effect.finished
		return
	# Fallback: scan for child BurstParticles2D nodes
	var burst_children: Array = []
	for child in effect.get_children():
		if child is BurstParticles2D:
			burst_children.append(child)
	if burst_children.size() > 0:
		for bp in burst_children:
			if bp.has_signal("finished_burst"):
				await bp.finished_burst
		effect.queue_free()
		return
	# Ultimate fallback: no signals — clean up immediately
	effect.queue_free()


func _connect_auto_cleanup(effect: Node):
	"""Connect cleanup for fire-and-forget effects that lack a play() method.
	Tries BurstParticles2D children first, then uses a safety timeout."""
	var burst_children: Array = []
	for child in effect.get_children():
		if child is BurstParticles2D:
			burst_children.append(child)
	if burst_children.size() > 0:
		# Wait for the last burst particle to finish, then free the parent
		var last_bp = burst_children[-1]
		last_bp.finished_burst.connect(effect.queue_free)
		return
	# Safety timeout — free after 5 seconds if nothing else cleans up
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(effect):
			effect.queue_free()
	)


func _play_sound(stream: AudioStream, position: Vector2):
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = "SFX"
	_add_effect(player, position)
	player.play()
	player.finished.connect(player.queue_free)
