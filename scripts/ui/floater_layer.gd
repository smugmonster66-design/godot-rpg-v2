# res://scripts/ui/floater_layer.gd
# Spawns floating text labels on portraits in response to GameEventBus events.
# Reuses MicroAnimationPreset for label visual configuration.
# Add as child of PersistentUILayer in game_root.tscn.
#
# Mirrors ReactiveAnimator's label spawning logic but for out-of-combat events.
extends Node
class_name FloaterLayer

# ============================================================================
# CONFIGURATION
# ============================================================================

## The list of reactions to evaluate. Drag FloaterReaction .tres files here.
@export var reactions: Array[FloaterReaction] = []

## CanvasLayer index for floating labels (above all UI, layer 300)
@export var effects_layer_index: int = 300

## Whether to log matches in debug builds
@export var debug_logging: bool = false

# ============================================================================
# INTERNAL STATE
# ============================================================================

var _effects_layer: CanvasLayer = null
var _effects_container: Control = null
var _label_last_spawn: Dictionary = {}
const _LABEL_STAGGER_MS: float = 300.0

## Active floating labels — used for overlap avoidance
var _active_labels: Array[Label] = []

# ============================================================================
# SETUP
# ============================================================================

## Directory to auto-load FloaterReaction .tres files from (if reactions array is empty)
@export var reactions_dir: String = "res://resources/floater_reactions/"

func _ready():
	_effects_layer = CanvasLayer.new()
	_effects_layer.name = "FloaterEffectsLayer"
	_effects_layer.layer = effects_layer_index
	add_child(_effects_layer)

	_effects_container = Control.new()
	_effects_container.name = "FloaterEffectsContainer"
	_effects_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_container.set_anchors_preset(Control.PRESET_FULL_RECT)

	if ThemeManager and ThemeManager.theme:
		_effects_container.theme = ThemeManager.theme
	_effects_layer.add_child(_effects_container)

	if reactions.is_empty():
		_auto_load_reactions()
	_sort_reactions()
	GameEventBus.game_event.connect(_on_game_event)


func _auto_load_reactions() -> void:
	var dir = DirAccess.open(reactions_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res = load(reactions_dir + file_name)
			if res is FloaterReaction:
				reactions.append(res)
		file_name = dir.get_next()


func _sort_reactions() -> void:
	reactions.sort_custom(func(a, b): return a.priority > b.priority)

# ============================================================================
# EVENT HANDLING
# ============================================================================

func _on_game_event(event: GameEvent) -> void:
	for reaction in reactions:
		if reaction.matches(event):
			_play_reaction(reaction, event)
			reaction.mark_fired()
			if reaction.consume_event:
				break


func _play_reaction(reaction: FloaterReaction, event: GameEvent) -> void:
	var preset = reaction.animation_preset
	if not preset or not preset.label_enabled:
		return

	var target = event.target_node
	if not target or not is_instance_valid(target):
		target = _get_player_portrait()
	if not target or not is_instance_valid(target):
		return

	if debug_logging and OS.is_debug_build():
		var type_name = GameEvent.Type.keys()[event.type]
		print("  🏷️ FloaterLayer: %s → spawning label" % type_name)

	_spawn_floating_label(target, preset, reaction, event)

# ============================================================================
# FLOATING LABEL SPAWNING (mirrors ReactiveAnimator pattern)
# ============================================================================

func _spawn_floating_label(target: Node, preset: MicroAnimationPreset,
		reaction: FloaterReaction, event: GameEvent) -> void:
	var target_id: int = target.get_instance_id()

	# Source tag labels skip stagger
	if preset.label_use_source_tag_prefix and event.source_tag != "":
		_label_last_spawn[target_id] = Time.get_ticks_msec()
		var src_theme: StringName = preset.label_theme_type if preset.label_theme_type != &"" else &"sourcefloater"
		_spawn_label_raw(target, event.source_tag, src_theme, preset.label_color, preset)
		return

	# Stagger check
	var now: float = Time.get_ticks_msec()
	var last: float = _label_last_spawn.get(target_id, -_LABEL_STAGGER_MS)
	var elapsed: float = now - last
	if elapsed < _LABEL_STAGGER_MS:
		await get_tree().create_timer((_LABEL_STAGGER_MS - elapsed) / 1000.0).timeout
		if not is_instance_valid(target):
			return

	_label_last_spawn[target_id] = Time.get_ticks_msec()

	# Resolve text
	var text = reaction.resolve_text(event)
	if text == "" and preset.label_text != "":
		text = preset.label_text
	if text == "":
		return

	# Create label
	var label = Label.new()
	label.text = text
	label.theme_type_variation = preset.label_theme_type if preset.label_theme_type != &"" else &"FloaterLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Resolve color
	var color = preset.label_color
	if preset.label_color_key != "" and event.values.has(preset.label_color_key):
		var dynamic = event.values[preset.label_color_key]
		if dynamic is Color:
			color = dynamic
	label.add_theme_color_override("font_color", color)

	_effects_container.add_child(label)

	var duration: float = preset.label_duration
	var rise_distance: float = preset.label_rise_distance
	var scatter_x: float = preset.label_scatter_x
	var tv: StringName = label.theme_type_variation
	if tv != &"" and label.has_theme_constant("duration_ms", tv):
		duration = label.get_theme_constant("duration_ms", tv) / 1000.0
	if tv != &"" and label.has_theme_constant("rise_distance", tv):
		rise_distance = float(label.get_theme_constant("rise_distance", tv))
	if tv != &"" and label.has_theme_constant("scatter_x", tv):
		scatter_x = float(label.get_theme_constant("scatter_x", tv))

	var center = _get_global_center(target)
	var scatter = randf_range(-scatter_x, scatter_x)
	label.global_position = center + Vector2(scatter, 0) - label.size / 2
	label.scale = Vector2(preset.label_start_scale, preset.label_start_scale)
	label.pivot_offset = label.size / 2
	_clamp_to_viewport(label)
	_avoid_overlap(label)

	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y",
		center.y - rise_distance, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	if preset.label_end_scale != preset.label_start_scale:
		tween.tween_property(label, "scale",
			Vector2(preset.label_end_scale, preset.label_end_scale),
			duration)

	tween.finished.connect(_untrack_label.bind(label))
	tween.finished.connect(label.queue_free)


func _spawn_label_raw(target: Node, text: String, theme_type: StringName,
		fallback_color: Color, preset: MicroAnimationPreset) -> void:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = theme_type if theme_type != &"" else &"normal"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_container.add_child(label)

	var color := fallback_color
	if theme_type != &"" and label.has_theme_color(text, theme_type):
		color = label.get_theme_color(text, theme_type)
	label.add_theme_color_override("font_color", color)

	var duration: float = preset.label_duration
	var rise_distance: float = preset.label_rise_distance
	var scatter_x: float = preset.label_scatter_x
	var tv: StringName = label.theme_type_variation
	if tv != &"" and label.has_theme_constant("duration_ms", tv):
		duration = label.get_theme_constant("duration_ms", tv) / 1000.0
	if tv != &"" and label.has_theme_constant("rise_distance", tv):
		rise_distance = float(label.get_theme_constant("rise_distance", tv))
	if tv != &"" and label.has_theme_constant("scatter_x", tv):
		scatter_x = float(label.get_theme_constant("scatter_x", tv))

	var center = _get_global_center(target)
	var scatter = randf_range(-scatter_x, scatter_x)
	label.global_position = center + Vector2(scatter, 0) - label.size / 2
	label.scale = Vector2(preset.label_start_scale, preset.label_start_scale)
	label.pivot_offset = label.size / 2
	_clamp_to_viewport(label)
	_avoid_overlap(label)

	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y",
		center.y - rise_distance, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	if preset.label_end_scale != preset.label_start_scale:
		tween.tween_property(label, "scale",
			Vector2(preset.label_end_scale, preset.label_end_scale), duration)

	tween.finished.connect(_untrack_label.bind(label))
	tween.finished.connect(label.queue_free)

# ============================================================================
# POSITION HELPERS
# ============================================================================

func _get_global_center(target: Node) -> Vector2:
	if target is Control:
		return target.global_position + Vector2(target.size.x / 2, target.size.y * 0.25)
	elif target is Node2D:
		return target.global_position
	return Vector2.ZERO


func _get_player_portrait() -> Control:
	if GameManager and GameManager.game_root:
		return GameManager.game_root.get_node_or_null(
			"PersistentUILayer/PortraitVBox/PortraitContainer/PortraitTexture")
	return null


# ============================================================================
# FLOATER POSITIONING — VIEWPORT CLAMPING & OVERLAP AVOIDANCE
# ============================================================================

func _clamp_to_viewport(label: Label) -> void:
	"""Clamp label position so no part extends beyond the viewport edges."""
	var vp_size = get_viewport().get_visible_rect().size
	var pos = label.global_position
	var label_size = label.size * label.scale
	pos.x = clampf(pos.x, 0.0, vp_size.x - label_size.x)
	pos.y = clampf(pos.y, 0.0, vp_size.y - label_size.y)
	label.global_position = pos


func _avoid_overlap(label: Label) -> void:
	"""Shunt label vertically if it overlaps any active floater, then re-clamp."""
	# Purge freed labels
	_active_labels = _active_labels.filter(func(l): return is_instance_valid(l))

	var label_rect = Rect2(label.global_position, label.size * label.scale)
	for existing in _active_labels:
		var existing_rect = Rect2(existing.global_position, existing.size * existing.scale)
		if label_rect.intersects(existing_rect):
			# Place above the existing label (floaters rise, so this separates naturally)
			label.global_position.y = existing.global_position.y - label.size.y * label.scale.y - 2.0
			label_rect.position = label.global_position

	# Re-clamp after shunting
	_clamp_to_viewport(label)
	_active_labels.append(label)


func _untrack_label(label: Label) -> void:
	"""Remove a label from active tracking (call on tween finish)."""
	_active_labels.erase(label)
