# res://scripts/effects/combat_animation_player.gd
extends Node
class_name CombatAnimationPlayer

signal animation_sequence_started()
signal cast_finished()
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
		if effects_layer:
			print("🎬 CombatAnimationPlayer: Found EffectsLayer")
		else:
			push_warning("CombatAnimationPlayer: EffectsLayer not found!")

func play_action_animation(
	animation_set: CombatAnimationSet,
	source_position: Vector2,
	target_positions: Array[Vector2],
	target_nodes: Array[Node2D] = []
) -> void:
	"""Play full animation sequence for an action.
	Stages can overlap using cast_travel_overlap and travel_impact_overlap."""
	
	if not animation_set:
		print("  🎬 CAP: No animation_set — emitting apply_effect_now")
		apply_effect_now.emit()
		return
	
	var has_cast = animation_set.cast_preset or animation_set.cast_effect
	var has_travel = animation_set.travel_effect and target_positions.size() > 0
	var has_impact = (animation_set.impact_preset or animation_set.impact_effect) and target_positions.size() > 0
	
	print("  🎬 CAP: START (cast=%s, travel=%s, impact=%s, targets=%d, effect_at=%s)" % [
		has_cast, has_travel, has_impact, target_positions.size(),
		CombatAnimationSet.EffectTiming.keys()[animation_set.apply_effect_at]])
	
	animation_sequence_started.emit()
	
	# 1. Cast animation (at source/action field)
	if has_cast:
		print("  🎬 CAP: Playing CAST...")
		if has_travel and animation_set.cast_travel_overlap > 0.0:
			_play_cast(animation_set, source_position)
			var wait = max(animation_set.cast_duration - animation_set.cast_travel_overlap, 0.02)
			await get_tree().create_timer(wait).timeout
		else:
			await _play_cast(animation_set, source_position)
		print("  🎬 CAP: CAST done")
	
	if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_CAST:
		apply_effect_now.emit()
	
	cast_finished.emit()
	
	# 2. Travel animation (projectile to each target)
	if has_travel:
		print("  🎬 CAP: Playing TRAVEL...")
		if has_impact and animation_set.travel_impact_overlap > 0.0:
			_play_travel(animation_set, source_position, target_positions)
			var wait = max(animation_set.travel_duration - animation_set.travel_impact_overlap, 0.02)
			await get_tree().create_timer(wait).timeout
		else:
			await _play_travel(animation_set, source_position, target_positions)
		print("  🎬 CAP: TRAVEL done")
	
	if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_TRAVEL_END:
		apply_effect_now.emit()
	
	travel_finished.emit()
	
	# 3. Impact animation (at each target)
	if has_impact:
		print("  🎬 CAP: Playing IMPACT...")
		if animation_set.impact_delay > 0:
			await get_tree().create_timer(animation_set.impact_delay).timeout
		await _play_impact(animation_set, target_positions, target_nodes)
		print("  🎬 CAP: IMPACT done")
	
	if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_IMPACT:
		apply_effect_now.emit()
	
	impact_finished.emit()
	animation_sequence_finished.emit()
	print("  🎬 CAP: FINISHED")



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
			await effect.effect_finished
		else:
			await get_tree().create_timer(anim_set.cast_duration).timeout
			effect.queue_free()
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
	
	# Path C: Neither valid, just wait cast_duration
	await get_tree().create_timer(anim_set.cast_duration).timeout


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
				# CombatEffect presets use absolute positioning — don't scale the container
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
		
		if anim_set.impact_sound:
			_play_sound(anim_set.impact_sound, pos)
		
		if effect.has_method("play"):
			effect.play()
		
		effects.append(effect)
	
	# Wait for all impacts
	for effect in effects:
		await _await_effect_finished(effect)


func _add_effect(effect: Node, position: Vector2):
	if effects_layer:
		effects_layer.add_child(effect)
	else:
		get_tree().root.add_child(effect)
	
	# CombatEffect subclasses use PRESET_FULL_RECT as a fullscreen overlay
	# and position particles internally via _target_pos from configure().
	# Setting their global_position shifts the overlay and breaks child coords.
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
		# Future effect types — try generic configure_base
		if combat_effect.has_method("configure_base"):
			combat_effect.configure_base(preset, source_pos, target_pos)


func _await_effect_finished(effect: Node):
	"""Await whichever completion signal the effect emits."""
	if effect.has_signal("effect_finished"):
		await effect.effect_finished
	elif effect.has_signal("finished"):
		await effect.finished
	else:
		return

func _play_sound(stream: AudioStream, position: Vector2):
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = "SFX"
	_add_effect(player, position)
	player.play()
	player.finished.connect(player.queue_free)
