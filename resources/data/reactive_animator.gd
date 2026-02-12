# res://scripts/effects/reactive_animator.gd
# Listens to CombatEventBus.game_event and plays matching AnimationReactions.
# This is the core dispatcher for all reactive micro-animations in combat.
#
# Add as a child of CombatUI (alongside AffixVisualAnimator, CombatAnimationPlayer).
# Call initialize() with the CombatEventBus after combat setup.
#
# Reactions are evaluated in priority order (highest first). If a reaction
# has consume_event = true, lower-priority reactions for that event are skipped.
#
# Queue groups: reactions sharing a non-empty queue_group play sequentially.
# All other reactions play immediately (parallel).
#
# Usage:
#   var reactive_animator = ReactiveAnimator.new()
#   reactive_animator.reactions = [die_grow_reaction, damage_reaction, ...]
#   add_child(reactive_animator)
#   reactive_animator.initialize(event_bus)
extends Node
class_name ReactiveAnimator

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when any reaction starts playing
signal reaction_started(reaction: AnimationReaction, event: CombatEvent)

## Emitted when any reaction finishes playing
signal reaction_finished(reaction: AnimationReaction)

## Emitted when all queued reactions for a queue_group have finished
signal queue_group_finished(group_name: String)

# ============================================================================
# CONFIGURATION
# ============================================================================

## The list of reactions to evaluate. Drag AnimationReaction .tres files here.
## Evaluated in priority order (highest first), then array order for ties.
@export var reactions: Array[AnimationReaction] = []

## CanvasLayer index for particle and label effects. Should be above
## the main combat UI but below modal dialogs.
@export var effects_layer_index: int = 102

## Whether to log reaction matches in debug builds
@export var debug_logging: bool = false

# ============================================================================
# REFERENCES
# ============================================================================

var _event_bus: CombatEventBus = null
var _effects_layer: CanvasLayer = null
var _effects_container: Control = null

## Queue group state: { group_name: Array[Callable] }
var _queue_groups: Dictionary = {}

## Track active animations for "all done" detection
var _active_count: int = 0

## Reference to CombatEffectPlayer for playing combat effect presets
var _effect_player: CombatEffectPlayer = null

## Reference to CombatAnimationPlayer for playing full animation sets
var _animation_player: CombatAnimationPlayer = null

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	# Create effects overlay for particles and floating labels
	_effects_layer = CanvasLayer.new()
	_effects_layer.name = "ReactiveEffectsLayer"
	_effects_layer.layer = effects_layer_index
	add_child(_effects_layer)

	_effects_container = Control.new()
	_effects_container.name = "ReactiveEffectsContainer"
	_effects_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effects_layer.add_child(_effects_container)

	# Sort reactions by priority (highest first) for correct evaluation order
	_sort_reactions()


func initialize(event_bus: CombatEventBus, effect_player: CombatEffectPlayer = null, animation_player: CombatAnimationPlayer = null) -> void:
	"""Connect to the event bus. Call during CombatUI setup."""
	_event_bus = event_bus
	_effect_player = effect_player
	_animation_player = animation_player
	event_bus.game_event.connect(_on_game_event)
	print("  ✅ ReactiveAnimator initialized with %d reactions" % reactions.size())

func cleanup() -> void:
	"""Disconnect and clean up. Call on combat end."""
	if _event_bus and _event_bus.game_event.is_connected(_on_game_event):
		_event_bus.game_event.disconnect(_on_game_event)
	_event_bus = null
	_queue_groups.clear()

	# Clean up effects container children
	for child in _effects_container.get_children():
		child.queue_free()
		
	
	_effect_player = null
	_animation_player = null

# ============================================================================
# EVENT HANDLING
# ============================================================================

func _on_game_event(event: CombatEvent) -> void:
	"""Evaluate all reactions against the incoming event."""
	for reaction in reactions:
		if event.consumed:
			break

		if not reaction.matches(event):
			continue

		if debug_logging and OS.is_debug_build():
			print("  🎬 Reaction matched: %s" % reaction.describe())

		reaction.mark_fired()

		if reaction.consume_event:
			event.consumed = true

		# Dispatch based on queue group
		if reaction.queue_group != "":
			_enqueue_reaction(reaction, event)
		else:
			_play_reaction(reaction, event)

# ============================================================================
# IMMEDIATE PLAYBACK
# ============================================================================

func _play_reaction(reaction: AnimationReaction, event: CombatEvent) -> void:
	"""Play a reaction's animation preset immediately (fire-and-forget)."""
	var preset = reaction.animation_preset
	if not preset or not preset.has_any_track():
		return

	var target = event.target_node
	if not target or not is_instance_valid(target):
		# Some events (ROUND_STARTED, etc.) may not have a target.
		# Only tracks that don't need a target (sound, screen shake) can play.
		if preset.sound or preset.screen_shake_enabled:
			_play_targetless_tracks(preset, event)
		return

	reaction_started.emit(reaction, event)
	_active_count += 1

	# Start delay
	if preset.start_delay > 0:
		await get_tree().create_timer(preset.start_delay).timeout
		if not is_instance_valid(target):
			_active_count -= 1
			return

	# Fire all enabled tracks in parallel
	if preset.scale_enabled:
		_play_scale(target, preset)
	if preset.flash_enabled:
		_play_flash(target, preset, event)
	if preset.shake_enabled:
		_play_shake(target, preset)
	if preset.screen_shake_enabled:
		_play_screen_shake(preset)
	if preset.particle_scene:
		_spawn_particles(target, preset)
	if preset.sound:
		_play_sound(target, preset)
	if preset.label_enabled:
		_spawn_floating_label(target, preset, event)

	if preset.combat_effect_preset:
		_play_combat_effect(target, preset, event)
	if preset.combat_animation_set and not preset.combat_effect_preset:
		_play_combat_animation_set(target, preset, event)


	_active_count -= 1
	reaction_finished.emit(reaction)

# ============================================================================
# QUEUE GROUP PLAYBACK
# ============================================================================

func _enqueue_reaction(reaction: AnimationReaction, event: CombatEvent) -> void:
	"""Add a reaction to its queue group for sequential playback."""
	var group = reaction.queue_group

	if not _queue_groups.has(group):
		_queue_groups[group] = []

	_queue_groups[group].append({"reaction": reaction, "event": event})

	# If this is the only item, start processing immediately
	if _queue_groups[group].size() == 1:
		_process_queue_group(group)


func _process_queue_group(group: String) -> void:
	"""Process queued reactions for a group sequentially."""
	while _queue_groups.has(group) and _queue_groups[group].size() > 0:
		var entry = _queue_groups[group][0]
		var reaction: AnimationReaction = entry["reaction"]
		var event: CombatEvent = entry["event"]

		var preset = reaction.animation_preset
		if preset and preset.has_any_track():
			reaction_started.emit(reaction, event)
			await _play_reaction_and_wait(reaction, event)
			reaction_finished.emit(reaction)

		# Remove completed entry
		if _queue_groups.has(group) and _queue_groups[group].size() > 0:
			_queue_groups[group].pop_front()

	# Group complete
	_queue_groups.erase(group)
	queue_group_finished.emit(group)


func _play_reaction_and_wait(reaction: AnimationReaction, event: CombatEvent) -> void:
	"""Play a reaction and wait for its estimated duration before returning."""
	var preset = reaction.animation_preset
	if not preset:
		return

	var target = event.target_node
	if target and is_instance_valid(target):
		if preset.start_delay > 0:
			await get_tree().create_timer(preset.start_delay).timeout

		if preset.scale_enabled:
			_play_scale(target, preset)
		if preset.flash_enabled:
			_play_flash(target, preset, event)
		if preset.shake_enabled:
			_play_shake(target, preset)
		if preset.screen_shake_enabled:
			_play_screen_shake(preset)
		if preset.particle_scene:
			_spawn_particles(target, preset)
		if preset.sound:
			_play_sound(target, preset)
		if preset.label_enabled:
			_spawn_floating_label(target, preset, event)

	# Wait for the longest track to finish
	var wait = preset.get_total_duration() - preset.start_delay
	if wait > 0:
		await get_tree().create_timer(wait).timeout


func _play_targetless_tracks(preset: MicroAnimationPreset, event: CombatEvent) -> void:
	"""Play tracks that don't require a target node (sound, screen shake)."""
	if preset.screen_shake_enabled:
		_play_screen_shake(preset)
	if preset.sound:
		# Play at screen center
		var player = AudioStreamPlayer.new()
		player.stream = preset.sound
		player.volume_db = preset.sound_volume_db
		if preset.sound_pitch_variance > 0:
			player.pitch_scale = 1.0 + randf_range(-preset.sound_pitch_variance, preset.sound_pitch_variance)
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)

# ============================================================================
# TRACK IMPLEMENTATIONS
# ============================================================================

func _play_scale(target: Node, preset: MicroAnimationPreset) -> void:
	"""Scale pop animation on the target node."""
	if not "scale" in target:
		return

	var original_scale: Vector2 = target.scale
	var peak = original_scale * preset.scale_peak

	var tween = target.create_tween()
	tween.tween_property(target, "scale", peak, preset.scale_out_duration)
	tween.tween_property(target, "scale", original_scale, preset.scale_in_duration) \
		.set_ease(preset.scale_ease).set_trans(preset.scale_trans)


func _play_flash(target: Node, preset: MicroAnimationPreset, event: CombatEvent) -> void:
	"""Color flash on the target node's modulate."""
	if not "modulate" in target:
		return

	# Resolve color — dynamic from event or static from preset
	var color = preset.flash_color
	if preset.flash_color_key != "" and event.values.has(preset.flash_color_key):
		var dynamic = event.values[preset.flash_color_key]
		if dynamic is Color:
			color = dynamic

	var original_mod: Color = target.modulate

	var tween = target.create_tween()
	tween.tween_property(target, "modulate", color, preset.flash_in_duration)
	tween.tween_property(target, "modulate", original_mod, preset.flash_out_duration)


func _play_shake(target: Node, preset: MicroAnimationPreset) -> void:
	"""Rapid position jitter on the target node."""
	if not "position" in target:
		return

	var original_pos: Vector2 = target.position
	var tween = target.create_tween()

	for i in range(preset.shake_count):
		var intensity = preset.shake_intensity
		if preset.shake_decay:
			intensity *= (1.0 - float(i) / float(preset.shake_count))

		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		var step_duration = preset.shake_duration / float(preset.shake_count)
		tween.tween_property(target, "position", original_pos + offset, step_duration)

	# Return to original
	tween.tween_property(target, "position", original_pos, 0.02)


func _play_screen_shake(preset: MicroAnimationPreset) -> void:
	"""Shake the viewport/camera for impact feel."""
	var viewport = get_viewport()
	if not viewport:
		return

	# Use canvas_transform for 2D screen shake
	var original_transform = viewport.canvas_transform
	var shake_tween = create_tween()
	var steps = 8
	var step_duration = preset.screen_shake_duration / float(steps)

	for i in range(steps):
		var intensity = preset.screen_shake_intensity * (1.0 - float(i) / float(steps))
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		var t = Transform2D(0.0, offset)
		shake_tween.tween_property(viewport, "canvas_transform", original_transform * t, step_duration)

	shake_tween.tween_property(viewport, "canvas_transform", original_transform, 0.02)


func _spawn_particles(target: Node, preset: MicroAnimationPreset) -> void:
	"""Spawn a particle scene at the target's position."""
	if not preset.particle_scene:
		return

	var instance = preset.particle_scene.instantiate()
	_effects_container.add_child(instance)

	if instance is Node2D and target is CanvasItem:
		instance.global_position = _get_global_center(target) + preset.particle_offset
	elif instance is Control and target is Control:
		instance.global_position = target.global_position + preset.particle_offset

	instance.scale = preset.particle_scale

	# If the particle scene has a play() method, call it
	if instance.has_method("play"):
		instance.play()

	# Auto-free after a generous timeout if not self-freeing
	if not instance.has_signal("finished") and not instance.has_signal("effect_finished"):
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(instance):
				instance.queue_free()
		)


func _play_sound(target: Node, preset: MicroAnimationPreset) -> void:
	"""Play a sound effect at the target's position."""
	if not preset.sound:
		return

	var player = AudioStreamPlayer2D.new()
	player.stream = preset.sound
	player.volume_db = preset.sound_volume_db
	player.bus = "SFX"

	if preset.sound_pitch_variance > 0:
		player.pitch_scale = 1.0 + randf_range(-preset.sound_pitch_variance, preset.sound_pitch_variance)

	_effects_container.add_child(player)

	if target is CanvasItem:
		player.global_position = _get_global_center(target)

	player.play()
	player.finished.connect(player.queue_free)


func _spawn_floating_label(target: Node, preset: MicroAnimationPreset, event: CombatEvent) -> void:
	"""Spawn a floating text label that rises and fades out."""
	var text = _resolve_label_text(preset, event)
	if text == "":
		return

	# Resolve color
	var color = preset.label_color
	if preset.label_color_key != "" and event.values.has(preset.label_color_key):
		var dynamic = event.values[preset.label_color_key]
		if dynamic is Color:
			color = dynamic

	# Create the label
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", preset.label_font_size)
	if preset.label_bold:
		# Use default bold font if available, otherwise just size up
		label.add_theme_font_size_override("font_size", preset.label_font_size + 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Position at target center with optional scatter
	_effects_container.add_child(label)
	var center = _get_global_center(target)
	var scatter = randf_range(-preset.label_scatter_x, preset.label_scatter_x)
	label.global_position = center + Vector2(scatter, 0) - label.size / 2
	label.scale = Vector2(preset.label_start_scale, preset.label_start_scale)
	label.pivot_offset = label.size / 2

	# Animate: rise + fade + optional scale
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y",
		center.y - preset.label_rise_distance, preset.label_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, preset.label_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	if preset.label_end_scale != preset.label_start_scale:
		tween.tween_property(label, "scale",
			Vector2(preset.label_end_scale, preset.label_end_scale),
			preset.label_duration)

	tween.finished.connect(label.queue_free)



func _play_combat_effect(target: Node, preset: MicroAnimationPreset, event: CombatEvent) -> void:
	"""Play a CombatEffectPreset via CombatEffectPlayer."""
	if not preset.combat_effect_preset or not _effect_player:
		return
	
	var target_pos = _get_global_center(target)
	var source_pos = target_pos
	
	if event.source_node and is_instance_valid(event.source_node):
		source_pos = _get_global_center(event.source_node)
	
	var from_pos: Vector2
	var to_pos: Vector2
	match preset.combat_effect_direction:
		MicroAnimationPreset.EffectDirection.SOURCE_TO_TARGET:
			from_pos = source_pos
			to_pos = target_pos
		MicroAnimationPreset.EffectDirection.TARGET_TO_SOURCE:
			from_pos = target_pos
			to_pos = source_pos
	
	var appearance = preset.combat_effect_appearance.duplicate()
	if event.values.has("element_color"):
		appearance["tint"] = event.values["element_color"]
		appearance["element"] = event.values["element_color"]
	
	# Use Variant to bypass static type check for subclass detection
	var effect_res: Variant = preset.combat_effect_preset
	if effect_res is ScatterConvergePreset:
		_effect_player.play_scatter_converge(
			effect_res as ScatterConvergePreset,
			CombatEffectTarget.position(from_pos),
			CombatEffectTarget.position(to_pos),
			appearance
		)
	elif _effect_player.has_method("play_effect"):
		_effect_player.play_effect(
			preset.combat_effect_preset,
			from_pos, to_pos,
			target if target is CanvasItem else null,
			event.source_node if event.source_node is CanvasItem else null
		)

func _play_combat_animation_set(target: Node, preset: MicroAnimationPreset, event: CombatEvent) -> void:
	"""Play a full CombatAnimationSet via CombatAnimationPlayer."""
	if not preset.combat_animation_set or not _animation_player:
		return
	
	var target_pos = _get_global_center(target)
	var source_pos = target_pos
	
	if event.source_node and is_instance_valid(event.source_node):
		source_pos = _get_global_center(event.source_node)
	
	var target_positions: Array[Vector2] = [target_pos]
	var target_nodes: Array[Node2D] = []
	if target is Node2D:
		target_nodes.append(target)
	
	_animation_player.play_sequence(
		preset.combat_animation_set,
		source_pos,
		target_positions,
		target_nodes
	)


func _resolve_label_text(preset: MicroAnimationPreset, event: CombatEvent) -> String:
	"""Determine what text to show on the floating label."""
	# Explicit text override
	if preset.label_text != "":
		return preset.label_text

	# Auto-generation based on event type
	match event.type:
		CombatEvent.Type.DIE_VALUE_CHANGED:
			var delta = event.values.get("delta", 0)
			if delta > 0:
				return "+%d" % delta
			elif delta < 0:
				return "%d" % delta
			return ""

		CombatEvent.Type.DAMAGE_DEALT:
			var amount = event.values.get("amount", 0)
			return "%s%d" % [preset.label_prefix if preset.label_prefix != "" else "-", amount]

		CombatEvent.Type.HEAL_APPLIED:
			var amount = event.values.get("amount", 0)
			return "%s%d" % [preset.label_prefix if preset.label_prefix != "" else "+", amount]

		CombatEvent.Type.STATUS_APPLIED:
			return event.values.get("status_name", "")

		CombatEvent.Type.SHIELD_GAINED:
			var amount = event.values.get("amount", 0)
			return "%s%d" % [preset.label_prefix if preset.label_prefix != "" else "+", amount]

		CombatEvent.Type.MANA_CHANGED:
			var delta = event.values.get("delta", 0)
			if delta > 0:
				return "+%d" % delta
			elif delta < 0:
				return "%d" % delta
			return ""

		_:
			pass

	# Fallback: use value key
	if preset.label_value_key != "" and event.values.has(preset.label_value_key):
		return "%s%s" % [preset.label_prefix, str(event.values[preset.label_value_key])]

	return ""

# ============================================================================
# UTILITY
# ============================================================================

func _sort_reactions() -> void:
	"""Sort reactions by priority (descending). Stable sort preserves array order for ties."""
	reactions.sort_custom(func(a, b): return a.priority > b.priority)


func _get_global_center(node: Node) -> Vector2:
	"""Get the global center position of a node, handling both Node2D and Control."""
	if node is Control:
		return node.global_position + node.size / 2
	elif node is Node2D:
		return node.global_position
	return Vector2.ZERO


func add_reaction(reaction: AnimationReaction) -> void:
	"""Add a reaction at runtime and re-sort."""
	reactions.append(reaction)
	_sort_reactions()


func remove_reaction(reaction: AnimationReaction) -> void:
	"""Remove a reaction at runtime."""
	reactions.erase(reaction)
