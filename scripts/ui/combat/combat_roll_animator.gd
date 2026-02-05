# res://scripts/ui/combat/combat_roll_animator.gd
# Orchestrates dice roll animations at the start of each player turn
# Sequence: Pool die flash → Projectile travels → Hand die revealed with pop
# Add as a child node of CombatUI (or CombatUILayer)
extends Node
class_name CombatRollAnimator

# ============================================================================
# EXPORTS - Tune timing in Inspector
# ============================================================================
@export_group("Timing")
## Delay between each die's animation start (staggered, not sequential)
@export var stagger_delay: float = 0.12
## Duration of the pool die flash effect
@export var flash_duration: float = 0.15
## Duration of projectile travel from pool to hand
@export var travel_duration: float = 0.35
## Duration of the hand die scale pop on reveal
@export var pop_duration: float = 0.15

@export_group("Visuals")
## Scale multiplier for the hand die pop effect (1.3 = 30% larger)
@export var pop_scale: float = 1.3
## Size of the traveling projectile in pixels
@export var projectile_size: Vector2 = Vector2(48, 48)

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
	"""Call during CombatUI.initialize_ui() to set references
	
	Args:
		hand_display: The DicePoolDisplay node showing combat hand dice
		pool_grid: (Optional) The DiceGrid from BottomUI showing pool dice.
		           If null, projectiles originate from bottom-center of screen.
	"""
	dice_pool_display = hand_display
	pool_dice_grid = pool_grid
	print_debug("🎬 CombatRollAnimator initialized (pool_grid: %s)" % (pool_grid != null))

func is_animating() -> bool:
	return _is_animating

# ============================================================================
# MAIN SEQUENCE
# ============================================================================

func play_roll_sequence() -> void:
	"""Play the full roll animation for all hand dice.
	Non-blocking — fires staggered animations and emits roll_animation_complete when done.
	Call after roll_hand() and DicePoolDisplay.refresh().
	"""
	if not dice_pool_display:
		push_warning("CombatRollAnimator: No dice_pool_display — skipping animation")
		roll_animation_complete.emit()
		return
	
	var hand_visuals: Array = _get_hand_visuals()
	if hand_visuals.is_empty():
		roll_animation_complete.emit()
		return
	
	_is_animating = true
	
	# Hide all hand visuals and disable dragging until revealed
	for visual in hand_visuals:
		if is_instance_valid(visual):
			visual.modulate = Color(1, 1, 1, 0)
			if "draggable" in visual:
				visual.draggable = false
	
	# Fire staggered animations (non-blocking per die)
	var total = hand_visuals.size()
	for i in range(total):
		_animate_single_die_delayed(i, hand_visuals[i], i * stagger_delay)
	
	# Wait for the last die to finish all phases
	var total_wait = (total - 1) * stagger_delay + flash_duration + travel_duration + pop_duration + 0.05
	await get_tree().create_timer(total_wait).timeout
	
	# Clear the hide flag on the display
	if dice_pool_display and "hide_for_roll_animation" in dice_pool_display:
		dice_pool_display.hide_for_roll_animation = false
	
	_is_animating = false
	roll_animation_complete.emit()

# ============================================================================
# PER-DIE ANIMATION
# ============================================================================

func _animate_single_die_delayed(index: int, hand_visual: Control, delay: float):
	"""Start a single die's animation after a delay (non-blocking)"""
	if delay > 0:
		get_tree().create_timer(delay).timeout.connect(
			func(): _do_animate_die(index, hand_visual),
			CONNECT_ONE_SHOT
		)
	else:
		_do_animate_die(index, hand_visual)

func _do_animate_die(index: int, hand_visual: Control):
	"""Execute the three-phase animation for one die"""
	if not is_instance_valid(hand_visual):
		return
	
	var source_info = _get_source_info(index)
	var source_center = source_info.get("global_center", Vector2.ZERO)
	var target_center = hand_visual.global_position + hand_visual.size / 2
	
	# ── Phase 1: Flash pool die ──
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
	
	# ── Phase 3: Reveal hand die with pop ──
	projectile.stop_emitting()
	# Brief delay so trail particles fade before freeing
	get_tree().create_timer(0.3).timeout.connect(
		func():
			if is_instance_valid(projectile):
				projectile.queue_free(),
		CONNECT_ONE_SHOT
	)
	# Hide projectile visual immediately so it doesn't linger
	if projectile.visual:
		projectile.visual.visible = false
	
	_reveal_hand_die(hand_visual)

# ============================================================================
# PHASE 1: POOL DIE FLASH
# ============================================================================

func _flash_pool_die(source_info: Dictionary):
	"""Flash the pool die to indicate it's being rolled"""
	var visual = source_info.get("visual", null)
	if visual and is_instance_valid(visual):
		if visual.has_method("play_roll_source_animation"):
			visual.play_roll_source_animation()
		else:
			# Fallback: simple modulate flash
			var tween = visual.create_tween()
			tween.tween_property(visual, "modulate", Color(1.8, 1.8, 1.8), flash_duration * 0.5)
			tween.tween_property(visual, "modulate", Color.WHITE, flash_duration * 0.5)

# ============================================================================
# PHASE 2: PROJECTILE
# ============================================================================

func _spawn_projectile(source_info: Dictionary) -> RollProjectile:
	"""Create and configure a projectile matching the source die's appearance"""
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
	"""Make the hand die visible with a scale pop animation"""
	# Snap to fully visible
	hand_visual.modulate = Color.WHITE
	
	# Re-enable dragging
	if "draggable" in hand_visual:
		hand_visual.draggable = true
	
	# Scale pop: start larger, bounce down to normal
	var base_scale = Vector2.ONE
	hand_visual.scale = base_scale * pop_scale
	
	var tween = create_tween()
	tween.tween_property(
		hand_visual, "scale", base_scale, pop_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# ============================================================================
# DATA GATHERING HELPERS
# ============================================================================

func _get_hand_visuals() -> Array:
	"""Get the list of CombatDieObject visuals from the hand display"""
	if dice_pool_display and "die_visuals" in dice_pool_display:
		return dice_pool_display.die_visuals
	
	# Fallback: find DieObjectBase children
	var visuals: Array = []
	if dice_pool_display:
		for child in dice_pool_display.get_children():
			if child is DieObjectBase:
				visuals.append(child)
	return visuals

func _get_source_info(die_index: int) -> Dictionary:
	"""Get position, texture, material, and visual ref for a pool die slot.
	Falls back to bottom-center of viewport if pool grid unavailable.
	"""
	var info: Dictionary = {}
	
	# Try getting info from the pool DiceGrid
	if pool_dice_grid and is_instance_valid(pool_dice_grid) and pool_dice_grid.visible:
		if pool_dice_grid.has_method("get_slot_info"):
			info = pool_dice_grid.get_slot_info(die_index)
	
	# Fallback source position: bottom center of screen
	if not info.has("global_center"):
		var viewport_size = get_viewport().get_visible_rect().size
		info["global_center"] = Vector2(viewport_size.x / 2, viewport_size.y)
	
	# If we still don't have texture info, try getting from hand visual's die_resource
	if not info.has("fill_texture") and dice_pool_display:
		var hand_visuals = _get_hand_visuals()
		if die_index < hand_visuals.size():
			var hv = hand_visuals[die_index]
			if hv is DieObjectBase and hv.die_resource:
				info["fill_texture"] = hv.die_resource.fill_texture
			if hv is DieObjectBase and hv.fill_texture:
				info["fill_material"] = hv.fill_texture.material
	
	return info
