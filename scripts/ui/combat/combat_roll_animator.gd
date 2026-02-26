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



@export_group("Entry Emanate")
## Emanate preset to play when a die appears in hand. Null = no emanate.
@export var entry_emanate_preset: EmanatePreset = null


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
var _emanate_container: Control = null
var _effects_layer: CanvasLayer = null

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when the entire roll animation sequence completes
signal roll_animation_complete

# ============================================================================
# SETUP
# ============================================================================

func _ready():
	# Emanate layer — renders BELOW CombatUILayer(5) so emanates appear behind dice
	var emanate_layer = CanvasLayer.new()
	emanate_layer.name = "EmanateLayer"
	emanate_layer.layer = 4
	add_child(emanate_layer)
	
	_emanate_container = Control.new()
	_emanate_container.name = "EmanateContainer"
	_emanate_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emanate_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	emanate_layer.add_child(_emanate_container)
	
	# Projectile overlay — renders above all UI
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ProjectileOverlay"
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	_projectile_container = Control.new()
	_projectile_container.name = "ProjectileContainer"
	_projectile_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_projectile_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(_projectile_container)

func initialize(hand_display: Control, pool_grid = null):
	dice_pool_display = hand_display
	pool_dice_grid = pool_grid
	
	# EffectsLayer is a sibling of CombatUILayer, not a child — search from scene root
	_effects_layer = get_tree().root.find_child("EffectsLayer", true, false)
	
	print("🎬 CombatRollAnimator initialized (hand_display: %s, pool_grid: %s, effects_layer: %s)" % [
		hand_display != null, pool_grid != null, _effects_layer != null
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
	
	dice_pool_display.modulate.a = 1.0
	
	
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

	# ── Phase 2: Projectile travel ──
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

	# ── Phase 3: Reveal ──
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

func _reveal_hand_die(hand_visual: Control):
	print("REVEAL: frame=%d visual=%s" % [Engine.get_process_frames(), hand_visual.name])
	hand_visual.modulate = Color.WHITE

	if "draggable" in hand_visual:
		hand_visual.draggable = true

	# Capture center BEFORE scale changes global_position
	var center = hand_visual.global_position + hand_visual.get_combined_minimum_size() / 2.0

	var base_scale = Vector2.ONE
	hand_visual.scale = base_scale * pop_scale

	var tween = create_tween()
	tween.tween_property(
		hand_visual, "scale", base_scale, pop_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_play_entry_emanate(hand_visual, center)


# In scripts/ui/combat/combat_roll_animator.gd
# Replace the _play_entry_emanate method with this debug version:

func _play_entry_emanate(hand_visual: Control, center: Vector2):
	print("🎆 _play_entry_emanate called:")
	print("  preset: %s" % ("SET" if entry_emanate_preset else "NULL"))
	print("  container: %s" % ("EXISTS" if _emanate_container else "NULL"))
	print("  center: %s" % center)
	
	if not entry_emanate_preset:
		print("  ❌ No entry_emanate_preset - exiting")
		return
	
	if not _emanate_container:
		print("  ❌ No _emanate_container - exiting")
		return

	var element: int = DieResource.Element.NONE
	if hand_visual is DieObjectBase and hand_visual.die_resource:
		element = hand_visual.die_resource.element
		print("  element: %d" % element)
	else:
		print("  ⚠️ Could not get element from visual")

	var preset = entry_emanate_preset.duplicate() as EmanatePreset
	if not preset:
		print("  ❌ Failed to duplicate preset")
		return
	
	var emanate_color = _get_emanate_color_for_element(element)
	print("  emanate_color: %s" % emanate_color)
	preset.emanate_color = emanate_color

	print("  ✅ Creating EmanateEffect...")
	var effect = EmanateEffect.new()
	_emanate_container.add_child(effect)
	print("  ✅ Effect added to container, configuring...")
	effect.configure(preset, center)
	print("  ✅ Effect configured, playing...")
	effect.play()
	print("  ✅ Effect.play() called")


func play_single_die_entry(die_index: int) -> void:
	"""Play entry animation for a single die (for mana dice added mid-turn).
	Skips projectile phase - just reveals with pop + emanate.
	
	Args:
		die_index: Index in die_visuals array (NOT hand array - already resolved by caller)
	"""
	if not dice_pool_display:
		print("⚠️ CombatRollAnimator: No dice_pool_display")
		return
	
	var hand_visuals = _get_hand_visuals()
	if die_index < 0 or die_index >= hand_visuals.size():
		print("⚠️ CombatRollAnimator: Invalid visual index %d (size: %d)" % [die_index, hand_visuals.size()])
		return
	
	var visual = hand_visuals[die_index]
	if not is_instance_valid(visual):
		print("⚠️ CombatRollAnimator: Invalid visual")
		return
	
	print("🎬 CombatRollAnimator: Animating mana die at visual index %d" % die_index)
	
	# Wait one frame for layout
	await get_tree().process_frame
	
	# Already visible from refresh - hide it momentarily
	visual.modulate = Color(1, 1, 1, 0)
	if "draggable" in visual:
		visual.draggable = false
	
	# Small delay to match the feel of the projectile arrival
	await get_tree().create_timer(0.1).timeout
	
	# Reveal with pop + emanate (no projectile phase)
	print("  🎬 Revealing mana die")
	_reveal_hand_die(visual)
	
	print("  ✅ Mana die animation complete")



func _get_emanate_color_for_element(die_element: int) -> Color:
	"""Pull element color from global config, with hardcoded fallback."""
	if GameManager and GameManager.ELEMENT_VISUALS:
		var damage_type = _die_element_to_damage_type(die_element)
		if damage_type >= 0:
			var tint = GameManager.ELEMENT_VISUALS.get_tint_color(damage_type)
			# Config returns white when tint_color was never set — use fallback
			if tint != Color.WHITE:
				tint.a = 0.8
				return tint

	# Fallback palette when config has no tint
	match die_element:
		DieResource.Element.FIRE:     return Color(1.0, 0.4, 0.1, 0.8)
		DieResource.Element.ICE:      return Color(0.3, 0.8, 1.0, 0.8)
		DieResource.Element.SHOCK:    return Color(0.4, 0.7, 1.0, 0.8)
		DieResource.Element.POISON:   return Color(0.3, 0.9, 0.2, 0.8)
		DieResource.Element.SHADOW:   return Color(0.5, 0.2, 0.8, 0.8)
		DieResource.Element.SLASHING: return Color(0.9, 0.9, 0.9, 0.6)
		DieResource.Element.BLUNT:    return Color(0.7, 0.5, 0.3, 0.6)
		DieResource.Element.PIERCING: return Color(0.8, 0.8, 0.6, 0.6)
		_:                            return Color(0.8, 0.8, 0.8, 0.5)


static func _die_element_to_damage_type(die_element: int) -> int:
	"""Convert DieResource.Element → ActionEffect.DamageType. Returns -1 for NONE."""
	match die_element:
		DieResource.Element.SLASHING: return ActionEffect.DamageType.SLASHING
		DieResource.Element.BLUNT: return ActionEffect.DamageType.BLUNT
		DieResource.Element.PIERCING: return ActionEffect.DamageType.PIERCING
		DieResource.Element.FIRE: return ActionEffect.DamageType.FIRE
		DieResource.Element.ICE: return ActionEffect.DamageType.ICE
		DieResource.Element.SHOCK: return ActionEffect.DamageType.SHOCK
		DieResource.Element.POISON: return ActionEffect.DamageType.POISON
		DieResource.Element.SHADOW: return ActionEffect.DamageType.SHADOW
		_: return -1

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
	
	# ── DIAGNOSTIC ──
	print("  🔍 Generic roll: target_display=%s, visible=%s, pos=%s, size=%s" % [
		target_display.name if target_display else "null",
		target_display.visible if target_display else "N/A",
		target_display.global_position if target_display else "N/A",
		target_display.size if target_display else "N/A",
	])
	for i in range(visuals.size()):
		var v = visuals[i]
		if is_instance_valid(v):
			print("  🔍 Visual[%d]: gpos=%s, size=%s, in_tree=%s, parent=%s" % [
				i, v.global_position, v.size, v.is_inside_tree(),
				v.get_parent().name if v.get_parent() else "null"
			])
	print("  🔍 Captured targets: %s" % [captured_targets])
	print("  🔍 Source position: %s" % source_center)
	# ── END DIAGNOSTIC ──
	
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
