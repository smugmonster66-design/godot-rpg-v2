# res://scripts/effects/combat_effect_player.gd
# General-purpose combat visual effect orchestrator.
# Resolves CombatEffectTargets to screen positions and plays effects
# between any combination of dice, action fields, combatants, and raw positions.
#
# Add as a child of CombatUI. Call initialize() after combat setup.
# AffixVisualAnimator and CombatAnimationPlayer can both delegate to this.
#
# Usage:
#   var from = CombatEffectTarget.action_field(my_field)
#   var to = CombatEffectTarget.enemy(0)
#   var appearance = { "tint": Color.RED, "element": Color.RED }
#   await effect_player.play_scatter_converge(preset, from, to, appearance)
#
#   # Or flash any target:
#   effect_player.flash(CombatEffectTarget.die(2), Color(1.5, 0.5, 0.5), 1.15, 0.25)
extends Node
class_name CombatEffectPlayer

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when any effect starts playing
signal effect_started(effect_id: int)
## Emitted at the peak/impact moment of any effect
signal effect_impact(effect_id: int)
## Emitted when any effect finishes
signal effect_finished(effect_id: int)
## Emitted when ALL currently active effects have finished
signal all_effects_complete()

# ============================================================================
# REFERENCES (set via initialize())
# ============================================================================

## DicePoolDisplay for resolving DIE targets
var dice_pool_display: DicePoolDisplay = null

## EnemyPanel for resolving ENEMY_SLOT targets
var enemy_panel: EnemyPanel = null

## Player health display for resolving PLAYER target
var player_health_display: Control = null

# ============================================================================
# EFFECTS LAYER
# ============================================================================

## CanvasLayer for rendering effects above all UI
var _effects_layer: CanvasLayer = null
var _effects_container: Control = null

# ============================================================================
# STATE
# ============================================================================

var _active_count: int = 0
var _next_effect_id: int = 0

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	_effects_layer = CanvasLayer.new()
	_effects_layer.name = "CombatEffectLayer"
	_effects_layer.layer = 101  # Above roll animator (100) and affix effects (99)
	add_child(_effects_layer)

	_effects_container = Control.new()
	_effects_container.name = "EffectsContainer"
	_effects_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effects_layer.add_child(_effects_container)


func initialize(
	hand_display: DicePoolDisplay = null,
	p_enemy_panel: EnemyPanel = null,
	p_player_health: Control = null
):
	"""Store UI references for target resolution.
	Call during CombatUI.initialize_ui() after UI nodes exist."""
	dice_pool_display = hand_display
	enemy_panel = p_enemy_panel
	player_health_display = p_player_health
	print("🎬 CombatEffectPlayer initialized (dice=%s, enemies=%s, player=%s)" % [
		hand_display != null, p_enemy_panel != null, p_player_health != null
	])


# ============================================================================
# TARGET RESOLUTION
# ============================================================================

func resolve_position(target: CombatEffectTarget) -> Vector2:
	"""Resolve a CombatEffectTarget to a global position.
	Returns Vector2.ZERO if the target can't be resolved."""
	match target.type:
		CombatEffectTarget.TargetType.POSITION:
			return target.global_pos

		CombatEffectTarget.TargetType.NODE:
			return _get_node_center(target.node_ref)

		CombatEffectTarget.TargetType.DIE:
			return _resolve_die_position(target.slot_index)

		CombatEffectTarget.TargetType.ACTION_FIELD:
			return _get_node_center(target.node_ref)

		CombatEffectTarget.TargetType.ENEMY_SLOT:
			return _resolve_enemy_position(target.slot_index)

		CombatEffectTarget.TargetType.PLAYER:
			return _resolve_player_position()

		_:
			push_warning("CombatEffectPlayer: Unknown target type %d" % target.type)
			return Vector2.ZERO


func resolve_node(target: CombatEffectTarget) -> CanvasItem:
	"""Resolve a CombatEffectTarget to a CanvasItem for shader targeting.
	Returns null if the target doesn't have a meaningful node."""
	match target.type:
		CombatEffectTarget.TargetType.NODE:
			if target.node_ref is CanvasItem:
				return target.node_ref as CanvasItem
			return null

		CombatEffectTarget.TargetType.DIE:
			return _resolve_die_visual(target.slot_index)

		CombatEffectTarget.TargetType.ACTION_FIELD:
			if target.node_ref is CanvasItem:
				return target.node_ref as CanvasItem
			return null

		CombatEffectTarget.TargetType.ENEMY_SLOT:
			return _resolve_enemy_node(target.slot_index)

		CombatEffectTarget.TargetType.PLAYER:
			if player_health_display is CanvasItem:
				return player_health_display as CanvasItem
			return null

		_:
			return null


# ============================================================================
# PLAY EFFECTS — SCATTER CONVERGE
# ============================================================================

func play_scatter_converge(
	preset: ScatterConvergePreset,
	from_target: CombatEffectTarget,
	to_target: CombatEffectTarget,
	appearance: Dictionary = {},
	await_impact: bool = false
) -> int:
	"""Play a scatter-converge effect between two targets.

	Args:
		preset: ScatterConvergePreset with timing/behavior config.
		from_target: Where particles scatter FROM.
		to_target: Where particles converge TO.
		appearance: Dictionary with optional keys:
			tint (Color), element (Color or int), fill_texture (Texture2D),
			fill_material (Material). Defaults to energy orbs with tint color.
		await_impact: If true, this method awaits until the impact signal.
			If false (default), awaits until fully finished.

	Returns:
		Effect ID for tracking via signals.
	"""
	var from_pos = resolve_position(from_target)
	var to_pos = resolve_position(to_target)

	if from_pos == Vector2.ZERO and to_pos == Vector2.ZERO:
		push_warning("CombatEffectPlayer: Both source and target resolved to ZERO")
		return -1

	# Fallback: if one position failed, use the other
	if from_pos == Vector2.ZERO:
		from_pos = to_pos
	if to_pos == Vector2.ZERO:
		to_pos = from_pos

	var effect_id = _next_effect_id
	_next_effect_id += 1
	_active_count += 1

	# Build die_info from appearance dict
	var die_info: Dictionary = {}
	die_info["tint"] = appearance.get("tint", Color.WHITE)
	die_info["element"] = appearance.get("element", appearance.get("tint", Color.WHITE))
	if appearance.has("fill_texture"):
		die_info["fill_texture"] = appearance.fill_texture
	if appearance.has("fill_material"):
		die_info["fill_material"] = appearance.fill_material

	# Create and configure effect
	var effect = ScatterConvergeEffect.new()
	_effects_container.add_child(effect)
	effect.configure(preset, from_pos, to_pos, die_info)

	# Wire signals
	effect.impact.connect(func(): effect_impact.emit(effect_id), CONNECT_ONE_SHOT)
	effect.finished.connect(func():
		effect_finished.emit(effect_id)
		_active_count -= 1
		if _active_count <= 0:
			_active_count = 0
			all_effects_complete.emit()
	, CONNECT_ONE_SHOT)

	# Play
	effect_started.emit(effect_id)

	if await_impact:
		await effect.impact
	else:
		await effect.finished

	return effect_id


func play_scatter_converge_fire_and_forget(
	preset: ScatterConvergePreset,
	from_target: CombatEffectTarget,
	to_target: CombatEffectTarget,
	appearance: Dictionary = {}
) -> int:
	"""Launch a scatter-converge effect without awaiting it.
	Returns the effect ID for optional signal tracking."""
	var from_pos = resolve_position(from_target)
	var to_pos = resolve_position(to_target)

	if from_pos == Vector2.ZERO and to_pos == Vector2.ZERO:
		return -1

	if from_pos == Vector2.ZERO:
		from_pos = to_pos
	if to_pos == Vector2.ZERO:
		to_pos = from_pos

	var effect_id = _next_effect_id
	_next_effect_id += 1
	_active_count += 1

	var die_info: Dictionary = {}
	die_info["tint"] = appearance.get("tint", Color.WHITE)
	die_info["element"] = appearance.get("element", appearance.get("tint", Color.WHITE))
	if appearance.has("fill_texture"):
		die_info["fill_texture"] = appearance.fill_texture
	if appearance.has("fill_material"):
		die_info["fill_material"] = appearance.fill_material

	var effect = ScatterConvergeEffect.new()
	_effects_container.add_child(effect)
	effect.configure(preset, from_pos, to_pos, die_info)

	effect.impact.connect(func(): effect_impact.emit(effect_id), CONNECT_ONE_SHOT)
	effect.finished.connect(func():
		effect_finished.emit(effect_id)
		_active_count -= 1
		if _active_count <= 0:
			_active_count = 0
			all_effects_complete.emit()
	, CONNECT_ONE_SHOT)

	effect_started.emit(effect_id)
	effect.play()
	return effect_id


# ============================================================================
# PLAY EFFECTS — COMBAT EFFECT (generic CombatEffect subclass)
# ============================================================================

func play_combat_effect(
	effect_instance: CombatEffect,
	from_target: CombatEffectTarget,
	to_target: CombatEffectTarget,
	preset: CombatEffectPreset = null
) -> int:
	"""Play any CombatEffect subclass between two targets.
	The effect must already be instantiated and configured with its
	specific preset (e.g., ShatterEffect, SummonEffect).

	This method handles:
	- Adding to the effects container
	- Resolving target/source nodes for shader tracks
	- Signal forwarding
	- Cleanup tracking

	Args:
		effect_instance: Pre-configured CombatEffect (already has its preset).
		from_target: Source target.
		to_target: Destination target.
		preset: Optional CombatEffectPreset for configure_base (if not already set).

	Returns:
		Effect ID for tracking.
	"""
	var from_pos = resolve_position(from_target)
	var to_pos = resolve_position(to_target)

	var effect_id = _next_effect_id
	_next_effect_id += 1
	_active_count += 1

	_effects_container.add_child(effect_instance)

	# Set base positioning if preset provided
	if preset:
		effect_instance.configure_base(preset, from_pos, to_pos)

	# Resolve nodes for shader tracks
	var source_node = resolve_node(from_target)
	var target_node = resolve_node(to_target)
	if source_node:
		effect_instance.set_source_node(source_node)
	if target_node:
		effect_instance.set_target_node(target_node)

	# Wire signals
	effect_instance.effect_peak.connect(func(): effect_impact.emit(effect_id), CONNECT_ONE_SHOT)
	effect_instance.effect_finished.connect(func():
		effect_finished.emit(effect_id)
		_active_count -= 1
		if _active_count <= 0:
			_active_count = 0
			all_effects_complete.emit()
	, CONNECT_ONE_SHOT)

	effect_started.emit(effect_id)
	await effect_instance.play()
	return effect_id


# ============================================================================
# UTILITY — FLASH / PULSE
# ============================================================================

func flash(
	target: CombatEffectTarget,
	color: Color = Color(1.5, 1.5, 0.5, 1.0),
	scale_pulse: float = 1.15,
	duration: float = 0.25
):
	"""Quick flash + scale pulse on any target. Fire-and-forget."""
	var node = resolve_node(target)
	if not node or not is_instance_valid(node):
		return

	# Modulate flash
	var original_modulate = node.modulate
	var tween = create_tween()
	tween.tween_property(node, "modulate", color, duration * 0.4)
	tween.tween_property(node, "modulate", original_modulate, duration * 0.6)

	# Scale pulse (only on Control nodes)
	if node is Control and scale_pulse > 1.0:
		var original_scale = node.scale
		var pulse_tween = create_tween()
		pulse_tween.tween_property(node, "scale", original_scale * scale_pulse, duration * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		pulse_tween.tween_property(node, "scale", original_scale, duration * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func flash_at_position(
	pos: Vector2,
	color: Color = Color(1.5, 1.5, 1.0, 0.8),
	size: Vector2 = Vector2(48, 48),
	duration: float = 0.2
):
	"""Spawn a quick flash sprite at a position. Self-cleaning."""
	var flash_rect = ColorRect.new()
	flash_rect.color = color
	flash_rect.size = size
	flash_rect.position = pos - size / 2.0
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects_container.add_child(flash_rect)

	var tween = create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_rect, "scale", Vector2(1.5, 1.5), duration).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash_rect.queue_free)


# ============================================================================
# STATE QUERIES
# ============================================================================

func is_playing() -> bool:
	"""True if any effects are currently active."""
	return _active_count > 0


func get_active_count() -> int:
	return _active_count


func get_effects_container() -> Control:
	"""Expose the container for systems that need to add custom effects."""
	return _effects_container


# ============================================================================
# PRIVATE — POSITION RESOLUTION
# ============================================================================

func _get_node_center(node: Node) -> Vector2:
	"""Get the global center of a Control or Node2D."""
	if not node or not is_instance_valid(node):
		return Vector2.ZERO

	if node is Control:
		var ctrl = node as Control
		return ctrl.global_position + ctrl.size / 2.0
	elif node is Node2D:
		return (node as Node2D).global_position

	return Vector2.ZERO


func _resolve_die_position(slot_index: int) -> Vector2:
	"""Resolve a hand die's center position from its slot index.
	Searches by slot_index rather than array position to handle gaps."""
	if not dice_pool_display:
		return Vector2.ZERO

	# Search by slot_index property
	if "die_visuals" in dice_pool_display:
		for v in dice_pool_display.die_visuals:
			if is_instance_valid(v) and v is Control and "slot_index" in v and v.slot_index == slot_index:
				return v.global_position + v.size / 2.0

	# Fallback: search children
	for child in dice_pool_display.get_children():
		if child is CombatDieObject and child.slot_index == slot_index:
			return child.global_position + child.size / 2.0

	return Vector2.ZERO



func _resolve_die_visual(slot_index: int) -> CanvasItem:
	"""Resolve a hand die's visual node from its slot index.
	Searches by slot_index rather than array position to handle gaps."""
	if not dice_pool_display:
		return null

	if "die_visuals" in dice_pool_display:
		for v in dice_pool_display.die_visuals:
			if is_instance_valid(v) and "slot_index" in v and v.slot_index == slot_index:
				return v

	# Fallback: search children
	for child in dice_pool_display.get_children():
		if child is CombatDieObject and child.slot_index == slot_index:
			return child

	return null



func _resolve_enemy_position(slot_index: int) -> Vector2:
	"""Resolve an enemy slot's portrait center position."""
	if not enemy_panel:
		return Vector2.ZERO

	if slot_index < 0 or slot_index >= enemy_panel.enemy_slots.size():
		return Vector2.ZERO

	var slot: EnemySlot = enemy_panel.enemy_slots[slot_index]
	if slot.portrait_rect and is_instance_valid(slot.portrait_rect):
		return slot.portrait_rect.global_position + slot.portrait_rect.size / 2.0

	# Fallback to slot center
	return slot.global_position + slot.size / 2.0


func _resolve_enemy_node(slot_index: int) -> CanvasItem:
	"""Resolve an enemy slot's portrait as a CanvasItem for shader targeting."""
	if not enemy_panel:
		return null

	if slot_index < 0 or slot_index >= enemy_panel.enemy_slots.size():
		return null

	var slot: EnemySlot = enemy_panel.enemy_slots[slot_index]
	if slot.portrait_rect and is_instance_valid(slot.portrait_rect):
		return slot.portrait_rect
	return slot


func _resolve_player_position() -> Vector2:
	"""Resolve the player's health/portrait area center position."""
	if player_health_display and is_instance_valid(player_health_display):
		return _get_node_center(player_health_display)

	# Fallback: bottom-left area of screen
	var vp = get_viewport()
	if vp:
		var vp_size = vp.get_visible_rect().size
		return Vector2(vp_size.x * 0.15, vp_size.y * 0.85)

	return Vector2(100, 500)
