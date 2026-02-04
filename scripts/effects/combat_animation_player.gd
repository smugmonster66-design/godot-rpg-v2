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
	"""Play full animation sequence for an action"""
	
	if not animation_set:
		apply_effect_now.emit()
		return
	
	animation_sequence_started.emit()
	
	# 1. Cast animation (at source/action field)
	if animation_set.cast_effect:
		await _play_cast(animation_set, source_position)
	
	if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_CAST:
		apply_effect_now.emit()
	
	cast_finished.emit()
	
	# 2. Travel animation (projectile to each target)
	if animation_set.travel_effect and target_positions.size() > 0:
		await _play_travel(animation_set, source_position, target_positions)
	
	if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_TRAVEL_END:
		apply_effect_now.emit()
	
	travel_finished.emit()
	
	# 3. Impact animation (at each target)
	if animation_set.impact_effect and target_positions.size() > 0:
		if animation_set.impact_delay > 0:
			await get_tree().create_timer(animation_set.impact_delay).timeout
		await _play_impact(animation_set, target_positions, target_nodes)
	
	if animation_set.apply_effect_at == CombatAnimationSet.EffectTiming.ON_IMPACT:
		apply_effect_now.emit()
	
	impact_finished.emit()
	animation_sequence_finished.emit()

func _play_cast(anim_set: CombatAnimationSet, position: Vector2):
	var effect = anim_set.cast_effect.instantiate()
	_add_effect(effect, position + anim_set.cast_offset)
	effect.scale = anim_set.cast_scale
	
	if anim_set.cast_sound:
		_play_sound(anim_set.cast_sound, position)
	
	if effect.has_method("play"):
		effect.play()
		await effect.effect_finished
	else:
		await get_tree().create_timer(anim_set.cast_duration).timeout
		effect.queue_free()

func _play_travel(anim_set: CombatAnimationSet, from: Vector2, targets: Array[Vector2]):
	var projectiles: Array = []
	
	for target_pos in targets:
		var projectile = anim_set.travel_effect.instantiate()
		_add_effect(projectile, from)
		projectile.scale = anim_set.travel_scale
		
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
		var effect = anim_set.impact_effect.instantiate()
		var pos = positions[i] + anim_set.impact_offset
		_add_effect(effect, pos)
		effect.scale = anim_set.impact_scale
		
		# If shader effect, setup target node
		if effect is ShaderEffect and i < nodes.size():
			effect.setup(nodes[i])
		
		if anim_set.impact_sound:
			_play_sound(anim_set.impact_sound, pos)
		
		if effect.has_method("play"):
			effect.play()
		
		effects.append(effect)
	
	# Wait for all impacts
	for effect in effects:
		if effect.has_signal("effect_finished"):
			await effect.effect_finished

func _add_effect(effect: Node, position: Vector2):
	if effects_layer:
		effects_layer.add_child(effect)
	else:
		get_tree().root.add_child(effect)
	
	if effect is Node2D:
		effect.global_position = position

func _play_sound(stream: AudioStream, position: Vector2):
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = "SFX"
	_add_effect(player, position)
	player.play()
	player.finished.connect(player.queue_free)
