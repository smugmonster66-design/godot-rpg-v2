# res://scripts/ui/combat/combat_roll_animator.gd
# Orchestrates dice roll animations at the start of each player turn
# Sequence per die: Pool die flash → Projectile travels to hand slot → Pop reveal
# Add as a child node of CombatUI (or CombatUILayer)
extends Node
class_name CombatRollAnimator

# ============================================================================
# EXPORTS - Tune timing in Inspector
# ============================================================================
@export_group("Timing")
## Delay between each die's animation start (staggered, not sequential)
@export var stagger_delay: float = 0.15
## Duration of the pool die flash/glow effect
@export var flash_duration: float = 0.2
## Duration of projectile travel from pool to hand
@export var travel_duration: float = 0.4
## Duration of the hand die scale pop on reveal
@export var pop_duration: float = 0.2

@export_group("Visuals")
## Scale multiplier for the hand die pop effect (1.3 = 30% larger)
@export var pop_scale: float = 1.3
## Size of the traveling projectile in pixels
@export var projectile_size: Vector2 = Vector2(48, 48)


@export_group("Scatter Converge")
## Preset for the scatter-converge burst during roll reveals
@export var roll_scatter_preset: ScatterConvergePreset = null
## Optional base particle texture (soft circle). Null = auto-generated.
@export var scatter_base_texture: Texture2D = null
## Enable scatter-converge instead of plain projectile
@export var use_scatter_converge: bool = true


# ============================================================================
# ROLL SETTLE SHADER
# ============================================================================

## Preloaded roll shaders — set in inspector or hardcode paths
@export_group("Roll Settle")
@export var roll_fill_shader: Shader = preload("res://shaders/die_roll_fill.gdshader")
@export var roll_stroke_shader: Shader = preload("res://shaders/die_roll_stroke.gdshader")
@export var roll_settle_duration: float = 0.8
@export var roll_oscillations: float = 3.0
@export var roll_amplitude: float = 1.5
@export var roll_decay: float = 3.0
@export var roll_tilt_strength: float = 0.8
# ============================================================================
# REFERENCES (set via initialize())
# ============================================================================
## The DicePoolDisplay showing the combat hand
var dice_pool_display: Control = null
## The DiceGrid from BottomUI showing pool dice (optional, for source position)
var pool_dice_grid = null  # DiceGrid

# ============================================================================
# INTERNAL STATE
# ============================================================================
var _projectile_container: Control = null
var _is_animating: bool = false

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when the entire roll animation sequence completes
signal roll_animation_complete

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	# Create an overlay CanvasLayer so projectiles render above all UI
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ProjectileOverlay"
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	# Container for projectile instances
	_projectile_container = Control.new()
	_projectile_container.name = "ProjectileContainer"
	_projectile_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_projectile_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(_projectile_container)

func initialize(hand_display: Control, pool_grid = null):
	"""Call during CombatUI.initialize_ui() to set references.
	
	Args:
		hand_display: The DicePoolDisplay node showing combat hand dice.
		pool_grid: (Optional) The DiceGrid from BottomUI showing pool dice.
			If null, projectiles originate from bottom-center of screen.
	"""
	dice_pool_display = hand_display
	pool_dice_grid = pool_grid
	print("🎬 CombatRollAnimator initialized (hand_display: %s, pool_grid: %s)" % [
		hand_display != null, pool_grid != null
	])

func is_animating() -> bool:
	return _is_animating

# ============================================================================
# POSITION COMPUTATION - Bypass layout system entirely
# ============================================================================

func _compute_hand_target_positions(hand_visuals: Array) -> Array[Vector2]:
	"""Compute center positions for each die in the HBoxContainer manually.
	
	This avoids relying on Godot's layout propagation timing by calculating
	where each die SHOULD be based on container properties + die minimum sizes.
	"""
	var positions: Array[Vector2] = []
	
	if not dice_pool_display or hand_visuals.is_empty():
		return positions
	
	# Get each visual's expected size from minimum size
	var sizes: Array[Vector2] = []
	var total_width: float = 0.0
	var max_height: float = 0.0
	for visual in hand_visuals:
		var s: Vector2
		if is_instance_valid(visual):
			s = visual.get_combined_minimum_size()
			if s == Vector2.ZERO:
				s = visual.custom_minimum_size
			if s == Vector2.ZERO:
				s = visual.size
		else:
			s = Vector2.ZERO
		sizes.append(s)
		total_width += s.x
		max_height = max(max_height, s.y)
	
	# Get HBoxContainer separation
	var separation: float = 0.0
	if dice_pool_display is HBoxContainer:
		separation = dice_pool_display.get_theme_constant("separation")
	if hand_visuals.size() > 1:
		total_width += separation * (hand_visuals.size() - 1)
	
	# Container global rect
	var container_pos: Vector2 = dice_pool_display.global_position
	var container_size: Vector2 = dice_pool_display.size
	
	# Determine starting X based on alignment
	var start_x: float
	var alignment_val: int = 0  # LEFT default
	if dice_pool_display is HBoxContainer:
		alignment_val = dice_pool_display.alignment
	
	match alignment_val:
		BoxContainer.ALIGNMENT_CENTER:
			start_x = container_pos.x + (container_size.x - total_width) / 2.0
		BoxContainer.ALIGNMENT_END:
			start_x = container_pos.x + container_size.x - total_width
		_:  # ALIGNMENT_BEGIN
			start_x = container_pos.x
	
	# Compute each die's center position
	var current_x: float = start_x
	for i in range(hand_visuals.size()):
		var center_x: float = current_x + sizes[i].x / 2.0
		var center_y: float = container_pos.y + container_size.y / 2.0
		positions.append(Vector2(center_x, center_y))
		current_x += sizes[i].x + separation
	
	return positions


func _validate_positions(positions: Array[Vector2], count: int) -> bool:
	"""Check if layout positions look valid (not all stacked at the same point)."""
	if positions.size() < 2:
		return positions.size() == count  # Single die is always "valid"
	
	# Check if all positions are identical or nearly identical
	var first = positions[0]
	var all_same = true
	for i in range(1, positions.size()):
		if positions[i].distance_to(first) > 5.0:  # 5px tolerance
			all_same = false
			break
	
	if all_same:
		return false  # All stacked = layout hasn't propagated
	
	# Check if any position is at origin (0,0) which suggests no layout
	for pos in positions:
		if pos.length() < 1.0:
			return false
	
	return true

# ============================================================================
# MAIN SEQUENCE
# ============================================================================

func play_roll_sequence() -> void:
	"""Play the full roll animation for all hand dice.
	
	IMPORTANT: Call AFTER roll_hand() and DicePoolDisplay.refresh() have completed.
	The DicePoolDisplay must have its die_visuals populated but they should be hidden.
	
	Fires staggered animations per die, then emits roll_animation_complete when done.
	"""
	if not dice_pool_display:
		push_warning("CombatRollAnimator: No dice_pool_display — skipping animation")
		roll_animation_complete.emit()
		return
	
	# Force container visible BEFORE frame waits.
	# The dice are already modulate alpha 0 so nothing shows prematurely,
	# but the container must be visible for layout to propagate AND for
	# the projectile → reveal animation to actually be seen by the player.
	if not dice_pool_display.visible:
		print("🎬 DicePoolDisplay was hidden — forcing visible for roll animation")
		dice_pool_display.visible = true
	
	# Wait two frames for layout propagation (needs visible container)
	await get_tree().process_frame
	await get_tree().process_frame
	
	var hand_visuals: Array = _get_hand_visuals()
	if hand_visuals.is_empty():
		print("🎬 CombatRollAnimator: No hand visuals found — skipping")
		roll_animation_complete.emit()
		return
	
	_is_animating = true
	print("🎬 CombatRollAnimator: Starting roll sequence for %d dice" % hand_visuals.size())
	
	# ── Step 1: Hide ALL hand visuals and disable dragging ──
	for visual in hand_visuals:
		if is_instance_valid(visual):
			visual.modulate = Color(1, 1, 1, 0)  # Fully transparent
			if "draggable" in visual:
				visual.draggable = false
	
	# ── Step 1b: Compute target positions ──
	# Try reading from layout first
	var layout_positions: Array[Vector2] = []
	for visual in hand_visuals:
		if is_instance_valid(visual):
			layout_positions.append(visual.global_position + visual.size / 2.0)
		else:
			layout_positions.append(Vector2.ZERO)
	
	# Compute manual positions as fallback
	var manual_positions: Array[Vector2] = _compute_hand_target_positions(hand_visuals)
	
	# Validate layout positions — if all stacked at same point, use manual
	var layout_looks_valid: bool = _validate_positions(layout_positions, hand_visuals.size())
	
	# ── DIAGNOSTIC LOGGING ──
	print("  🔍 DicePoolDisplay ref valid: %s" % is_instance_valid(dice_pool_display))
	print("  🔍 DicePoolDisplay: pos=%s, size=%s, visible=%s" % [
		dice_pool_display.global_position,
		dice_pool_display.size,
		dice_pool_display.visible
	])
	if dice_pool_display is HBoxContainer:
		print("  🔍 HBoxContainer alignment=%d, separation=%d" % [
			dice_pool_display.alignment,
			dice_pool_display.get_theme_constant("separation")
		])
	for i in range(hand_visuals.size()):
		var v = hand_visuals[i]
		if is_instance_valid(v):
			print("  🔍 Die[%d]: gpos=%s, size=%s, min_size=%s, combined_min=%s, in_tree=%s" % [
				i, v.global_position, v.size, v.custom_minimum_size,
				v.get_combined_minimum_size(), v.is_inside_tree()
			])
	print("  🔍 Layout positions: %s (valid=%s)" % [layout_positions, layout_looks_valid])
	print("  🔍 Manual positions: %s" % [manual_positions])
	# ── END DIAGNOSTIC ──
	
	var target_positions: Array[Vector2] = []
	if layout_looks_valid:
		target_positions = layout_positions
		print("  ✅ Using layout positions")
	elif manual_positions.size() == hand_visuals.size():
		target_positions = manual_positions
		print("  ⚠️ Layout positions invalid — using manually computed positions")
	else:
		target_positions = layout_positions
		print("  ❌ Both position methods failed — using layout positions as-is")
	
	# ── Step 2: Fire staggered per-die animations ──
	var total = hand_visuals.size()
	for i in range(total):
		_animate_single_die_delayed(i, hand_visuals[i], target_positions[i], i * stagger_delay)
	
	# ── Step 3: Wait for the LAST die to finish all 3 phases ──
	var total_wait = (total - 1) * stagger_delay + flash_duration + travel_duration + pop_duration + 0.1
	await get_tree().create_timer(total_wait).timeout
	
	# ── Step 4: Cleanup ──
	for visual in hand_visuals:
		if is_instance_valid(visual):
			visual.modulate = Color.WHITE
			if "draggable" in visual:
				visual.draggable = true
	
	# Clear the hide flag on the display
	if dice_pool_display and "hide_for_roll_animation" in dice_pool_display:
		dice_pool_display.hide_for_roll_animation = false
	
	_is_animating = false
	print("🎬 CombatRollAnimator: Roll sequence complete")
	roll_animation_complete.emit()

# ============================================================================
# PER-DIE ANIMATION (3 phases: Flash → Travel → Reveal)
# ============================================================================

func _animate_single_die_delayed(index: int, hand_visual: Control, target_center: Vector2, delay: float):
	"""Start a single die's animation after a delay (non-blocking)."""
	if delay > 0:
		get_tree().create_timer(delay).timeout.connect(
			func(): _do_animate_die(index, hand_visual, target_center),
			CONNECT_ONE_SHOT
		)
	else:
		_do_animate_die(index, hand_visual, target_center)

func _do_animate_die(index: int, hand_visual: Control, target_center: Vector2):
	if not is_instance_valid(hand_visual):
		return

	var source_info = _get_source_info(index)
	var source_center = source_info.get("global_center", Vector2.ZERO)

	# ── Phase 1: Flash the pool die ──
	_flash_pool_die(source_info)
	await get_tree().create_timer(flash_duration).timeout

	# ── Phase 2: Travel (scatter-converge or plain projectile) ──
	if use_scatter_converge and roll_scatter_preset:
		# Build die_info dict with element data
		var die_info = {
			"fill_texture": source_info.get("fill_texture", null),
			"fill_material": source_info.get("fill_material", null),
			"tint": source_info.get("tint", Color.WHITE),
			"element": source_info.get("element", 0),
		}

		var effect = ScatterConvergeEffect.new()
		_projectile_container.add_child(effect)
		effect.configure(roll_scatter_preset, source_center, target_center, die_info, scatter_base_texture)

		var visual_ref = weakref(hand_visual)
		effect.impact.connect(func():
			var v = visual_ref.get_ref()
			if v and is_instance_valid(v):
				_reveal_hand_die(v)
		, CONNECT_ONE_SHOT)

		await effect.finished
	else:
		# Original projectile path
		var projectile = _spawn_projectile(source_info)
		projectile.global_position = source_center - projectile_size / 2
		projectile.start_emitting()

		var travel_tween = create_tween()
		travel_tween.tween_property(
			projectile, "global_position",
			target_center - projectile_size / 2,
			travel_duration
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		await travel_tween.finished

		projectile.stop_emitting()
		if projectile.visual:
			projectile.visual.visible = false

		var proj_ref = weakref(projectile)
		get_tree().create_timer(0.3).timeout.connect(
			func():
				var p = proj_ref.get_ref()
				if p and is_instance_valid(p):
					p.queue_free(),
			CONNECT_ONE_SHOT
		)

		if is_instance_valid(hand_visual):
			_reveal_hand_die(hand_visual)

# ============================================================================
# PHASE 1: POOL DIE FLASH
# ============================================================================

func _flash_pool_die(source_info: Dictionary):
	"""Flash/glow the pool die to indicate it's being rolled."""
	var visual = source_info.get("visual", null)
	if visual and is_instance_valid(visual):
		if visual.has_method("play_roll_source_animation"):
			visual.play_roll_source_animation()
		else:
			var tween = visual.create_tween()
			tween.tween_property(visual, "modulate", Color(2.0, 2.0, 2.0), flash_duration * 0.4)
			tween.tween_property(visual, "modulate", Color.WHITE, flash_duration * 0.6)
	else:
		pass

# ============================================================================
# PHASE 2: PROJECTILE
# ============================================================================

func _spawn_projectile(source_info: Dictionary) -> RollProjectile:
	"""Create and configure a projectile matching the source die's appearance."""
	var projectile = RollProjectile.new()
	_projectile_container.add_child(projectile)
	
	var texture = source_info.get("fill_texture", null) as Texture2D
	var material = source_info.get("fill_material", null) as Material
	var tint = source_info.get("tint", Color.WHITE) as Color
	
	projectile.configure(texture, material, tint, projectile_size)
	return projectile

# ============================================================================
# PHASE 3: REVEAL
# ============================================================================

# In _reveal_hand_die() — only the additions, existing pop is untouched:

func _reveal_hand_die(hand_visual: Control):
	hand_visual.modulate = Color.WHITE
	if "draggable" in hand_visual:
		hand_visual.draggable = true

	var base_scale = Vector2.ONE
	hand_visual.scale = base_scale * pop_scale
	var tween = create_tween()
	tween.tween_property(
		hand_visual, "scale", base_scale, pop_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _apply_roll_settle(die_visual: DieObjectBase):
	var fill_rect: TextureRect = die_visual.fill_texture
	var stroke_rect: TextureRect = die_visual.stroke_texture
	if not fill_rect or not stroke_rect:
		return

	var original_fill_mat: Material = fill_rect.material
	var original_stroke_mat: Material = stroke_rect.material
	var original_fill_modulate: Color = fill_rect.modulate

	var fill_mat := ShaderMaterial.new()
	fill_mat.shader = roll_fill_shader
	fill_mat.set_shader_parameter("color_tint", original_fill_modulate)
	fill_mat.set_shader_parameter("rotation_angle", Vector2(roll_amplitude, roll_amplitude * 0.8))
	fill_mat.set_shader_parameter("tilt_strength", roll_tilt_strength)

	var stroke_mat := ShaderMaterial.new()
	stroke_mat.shader = roll_stroke_shader
	stroke_mat.set_shader_parameter("rotation_angle", Vector2(roll_amplitude, roll_amplitude * 0.8))
	stroke_mat.set_shader_parameter("tilt_strength", roll_tilt_strength)

	fill_rect.material = fill_mat
	fill_rect.modulate = Color.WHITE
	stroke_rect.material = stroke_mat

	var phase_offset := randf() * TAU
	var amp := roll_amplitude
	var osc := roll_oscillations
	var dec := roll_decay
	var _fill_ref = weakref(fill_rect)
	var _stroke_ref = weakref(stroke_rect)

	var tween = create_tween()
	tween.tween_method(func(t: float):
		var decay_val = exp(-dec * t)
		var rot = Vector2(
			sin(t * TAU * osc + phase_offset) * amp * decay_val,
			cos(t * TAU * (osc * 0.85) + phase_offset) * amp * 0.8 * decay_val
		)
		fill_mat.set_shader_parameter("rotation_angle", rot)
		stroke_mat.set_shader_parameter("rotation_angle", rot)
	, 0.0, 1.0, roll_settle_duration)

	tween.finished.connect(func():
		var fr = _fill_ref.get_ref()
		var sr = _stroke_ref.get_ref()
		if fr and is_instance_valid(fr):
			fr.material = original_fill_mat
			fr.modulate = original_fill_modulate
		if sr and is_instance_valid(sr):
			sr.material = original_stroke_mat
	, CONNECT_ONE_SHOT)



func _compute_roll_rotation(t: float, fill_mat: ShaderMaterial, stroke_mat: ShaderMaterial, phase_offset: float):
	var decay = exp(-roll_decay * t)
	var rot = Vector2(
		sin(t * TAU * roll_oscillations + phase_offset) * roll_amplitude * decay,
		cos(t * TAU * (roll_oscillations * 0.85) + phase_offset) * roll_amplitude * 0.75 * decay
	)
	if t < 0.05 or t > 0.95:
		print("🎲 roll_rotation t=%.3f rot=%s" % [t, rot])
	fill_mat.set_shader_parameter("rotation_angle", rot)
	stroke_mat.set_shader_parameter("rotation_angle", rot)


# ============================================================================
# DATA GATHERING HELPERS
# ============================================================================

func _get_hand_visuals() -> Array:
	"""Get the list of CombatDieObject visuals from the hand display."""
	if dice_pool_display and "die_visuals" in dice_pool_display:
		return dice_pool_display.die_visuals
	
	var visuals: Array = []
	if dice_pool_display:
		for child in dice_pool_display.get_children():
			if child is DieObjectBase:
				visuals.append(child)
	return visuals

func _get_source_info(die_index: int) -> Dictionary:
	"""Get position, texture, material, element, and visual ref for a pool die slot.
	Falls back to bottom-center of viewport if pool grid unavailable.
	Used by both RollProjectile and ScatterConvergeEffect.
	"""
	var info: Dictionary = {}
	
	if pool_dice_grid and is_instance_valid(pool_dice_grid) and pool_dice_grid.visible:
		if pool_dice_grid.has_method("get_slot_info"):
			info = pool_dice_grid.get_slot_info(die_index)
	
	if not info.has("global_center"):
		var viewport_size = get_viewport().get_visible_rect().size
		info["global_center"] = Vector2(viewport_size.x / 2, viewport_size.y)
	
	if not info.has("fill_texture") and dice_pool_display:
		var hand_visuals = _get_hand_visuals()
		if die_index < hand_visuals.size():
			var hv = hand_visuals[die_index]
			if hv is DieObjectBase and hv.die_resource:
				info["fill_texture"] = hv.die_resource.fill_texture
			if hv is DieObjectBase and hv.fill_texture:
				info["fill_material"] = hv.fill_texture.material
	
	# Element data for scatter-converge particle coloring
	if not info.has("element") and dice_pool_display:
		var hand_visuals = _get_hand_visuals()
		if die_index < hand_visuals.size():
			var hv = hand_visuals[die_index]
			if hv is DieObjectBase and hv.die_resource:
				info["element"] = hv.die_resource.element
	
	return info

# ============================================================================
# GENERIC ROLL SEQUENCE (works for player or enemy)
# ============================================================================

func play_roll_sequence_for(target_display: Control, visuals: Array, source_position: Vector2 = Vector2.ZERO) -> void:
	"""Play the roll animation for any set of die visuals.
	
	Args:
		target_display: The container that holds the visuals (for clearing hide flag).
		visuals: Array of die visual Controls (must already be children, hidden at alpha 0).
		source_position: Global position projectiles originate from.
			If Vector2.ZERO, uses bottom-center of viewport.
	"""
	if visuals.is_empty():
		roll_animation_complete.emit()
		return
	
	# Force container visible for layout propagation and visible animation
	if target_display and not target_display.visible:
		print("🎬 Target display was hidden — forcing visible for roll animation")
		target_display.visible = true
	
	# Wait two frames for layout propagation
	await get_tree().process_frame
	await get_tree().process_frame
	
	var source_center: Vector2
	if source_position != Vector2.ZERO:
		source_center = source_position
	else:
		var viewport_size = get_viewport().get_visible_rect().size
		source_center = Vector2(viewport_size.x / 2, viewport_size.y)
	
	_is_animating = true
	print("🎬 CombatRollAnimator: Starting roll sequence for %d dice (generic)" % visuals.size())
	
	# ── Step 1: Ensure all visuals hidden ──
	for visual in visuals:
		if is_instance_valid(visual):
			visual.modulate = Color(1, 1, 1, 0)
	
	# ── Step 1b: Pre-capture target positions ──
	var captured_targets: Array[Vector2] = []
	for visual in visuals:
		if is_instance_valid(visual):
			captured_targets.append(visual.global_position + visual.size / 2.0)
		else:
			captured_targets.append(Vector2.ZERO)
	
	# ── Step 2: Fire staggered per-die animations ──
	var total = visuals.size()
	for i in range(total):
		_animate_generic_die_delayed(i, visuals[i], source_center, captured_targets[i], i * stagger_delay)
	
	# ── Step 3: Wait for last die to finish ──
	var total_wait = (total - 1) * stagger_delay + flash_duration + travel_duration + pop_duration + 0.1
	await get_tree().create_timer(total_wait).timeout
	
	# ── Step 4: Cleanup - ensure all visible ──
	for visual in visuals:
		if is_instance_valid(visual):
			visual.modulate = Color.WHITE
	
	if target_display and "hide_for_roll_animation" in target_display:
		target_display.hide_for_roll_animation = false
	
	_is_animating = false
	print("🎬 CombatRollAnimator: Generic roll sequence complete")
	roll_animation_complete.emit()


func _animate_generic_die_delayed(index: int, hand_visual: Control, source_center: Vector2, target_center: Vector2, delay: float):
	"""Start a single generic die animation after a delay."""
	if delay > 0:
		get_tree().create_timer(delay).timeout.connect(
			func(): _do_animate_generic_die(index, hand_visual, source_center, target_center),
			CONNECT_ONE_SHOT
		)
	else:
		_do_animate_generic_die(index, hand_visual, source_center, target_center)


func _do_animate_generic_die(_index: int, hand_visual: Control, source_center: Vector2, target_center: Vector2):
	"""Execute three-phase animation for one die with explicit source position."""
	if not is_instance_valid(hand_visual):
		return
	
	# target_center is pre-captured — do NOT read from hand_visual here
	
	await get_tree().create_timer(flash_duration).timeout
	
	var source_info: Dictionary = {}
	source_info["global_center"] = source_center
	
	if hand_visual is DieObjectBase and hand_visual.die_resource:
		source_info["fill_texture"] = hand_visual.die_resource.fill_texture
	
	var projectile = _spawn_projectile(source_info)
	projectile.global_position = source_center - projectile_size / 2
	projectile.start_emitting()
	
	var travel_tween = create_tween()
	travel_tween.tween_property(
		projectile, "global_position",
		target_center - projectile_size / 2,
		travel_duration
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	
	await travel_tween.finished
	
	projectile.stop_emitting()
	if projectile.visual:
		projectile.visual.visible = false
	
	var proj_ref = weakref(projectile)
	get_tree().create_timer(0.3).timeout.connect(
		func():
			var p = proj_ref.get_ref()
			if p and is_instance_valid(p):
				p.queue_free(),
		CONNECT_ONE_SHOT
	)
	if is_instance_valid(hand_visual):
		_reveal_hand_die(hand_visual)
