# res://scripts/ui/combat/dice_pool_display.gd
# Combat hand display - shows rolled dice available for actions
# Uses CombatDieObject for each die, with fallback to DieVisual
#
# IMPORTANT: This display creates visuals HIDDEN. The CombatRollAnimator is
# solely responsible for revealing each die with the projectile animation.
extends HBoxContainer
class_name DicePoolDisplay

# ============================================================================
# SIGNALS
# ============================================================================
signal die_drag_started(die_object: Control, die: DieResource)
signal die_drag_ended(die_object: Control, was_placed: bool)
signal die_clicked(die_object: Control, die: DieResource)

# ============================================================================
# EXPORTS
# ============================================================================
@export var die_visual_scene: PackedScene = null  # Fallback to old system
@export var die_spacing: int = 10

# ============================================================================
# STATE
# ============================================================================
var dice_pool: PlayerDiceCollection = null
var die_visuals: Array[Control] = []
var _refresh_pending: bool = false
## When true, newly created visuals start invisible + non-draggable.
## CombatRollAnimator sets this before refresh and clears it after animation.
var hide_for_roll_animation: bool = false


# ── Insertion gap indicator (mana die drag) ──
var _gap_spacer: Control = null
var _gap_index: int = -1
var _gap_tween: Tween = null
const GAP_WIDTH: float = 72.0  # Width of the gap (roughly one die)
const GAP_ANIM_DURATION: float = 0.12  # Snappy but smooth

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_theme_constant_override("separation", die_spacing)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(300, 80)
	add_to_group("dice_pool_display")
	print("🎲 DicePoolDisplay ready, size=%s, min=%s" % [size, custom_minimum_size])


func initialize(pool):
	"""Initialize with player's dice collection"""
	print("🎲 DicePoolDisplay.initialize()")
	dice_pool = pool
	
	if not dice_pool:
		print("  ⚠️ dice_pool is null!")
		return
	
	print("  ✅ Pool has %d dice, %d in hand" % [dice_pool.dice.size(), dice_pool.hand.size()])
	
	# Connect to hand signals
	if dice_pool.has_signal("hand_rolled"):
		if not dice_pool.hand_rolled.is_connected(_on_hand_rolled):
			dice_pool.hand_rolled.connect(_on_hand_rolled)
			print("  ✅ Connected hand_rolled")
	
	if dice_pool.has_signal("hand_changed"):
		if not dice_pool.hand_changed.is_connected(_on_hand_changed):
			dice_pool.hand_changed.connect(_on_hand_changed)
			print("  ✅ Connected hand_changed")
	
	if dice_pool.has_signal("dice_shattered"):
		if not dice_pool.dice_shattered.is_connected(_on_dice_shattered):
			dice_pool.dice_shattered.connect(_on_dice_shattered)
			print("  ✅ Connected dice_shattered")
	
	
	
	
	refresh()
	
	print("🎲 DPD after init: size=%s, global_pos=%s, visible=%s" % [size, global_position, visible])



# ============================================================================
# DISPLAY
# ============================================================================

func refresh():
	"""Refresh the display to match current hand.
	
	Visuals are created HIDDEN (alpha = 0, draggable = false).
	The CombatRollAnimator reveals each die with the projectile animation.
	For mid-turn refreshes (e.g. die consumed), hide_for_roll_animation will
	be false, so dice appear immediately.
	
	Mana dice that have been pulled into the hand are displayed normally —
	they are full combat dice at that point (rolled, affixed, element-visual'd).
	"""
	print("🎲 DicePoolDisplay.refresh()")
	
	if not dice_pool:
		print("  ⚠️ No dice_pool")
		return
	
	clear_display()
	
	# DEBUG: check for orphaned children after clear
	var remaining_children = get_child_count()
	if remaining_children > 0:
		print("  ⚠️ DEBUG: %d children remain after clear_display():" % remaining_children)
		for child in get_children():
			print("    → %s (%s) valid=%s" % [child.name, child.get_class(), is_instance_valid(child)])
	
	var hand = dice_pool.hand
	print("  📊 Creating visuals for %d dice in hand" % hand.size())
	
	for i in range(hand.size()):
		var die = hand[i]
		# Consumed dice are kept in the array for stable indexing but not shown
		if die.is_consumed:
			continue
		var visual = _create_die_visual(die, i)
		if visual:
			# Start invisible when roll animation is pending
			if hide_for_roll_animation:
				visual.modulate.a = 0.0
			add_child(visual)
			die_visuals.append(visual)
			print("    ✅ Created visual for %s (value=%d)%s%s" % [
				die.display_name,
				die.get_total_value(),
				" [HIDDEN]" if hide_for_roll_animation else "",
				" [MANA]" if die.is_mana_die else ""
			])
		else:
			print("    ❌ Failed to create visual for %s" % die.display_name)
	
	# No entrance animation here — CombatRollAnimator handles all reveal


func clear_display():
	"""Remove all children — die visuals, gap spacer, and any orphans."""
	# Clean up gap spacer state
	if _gap_spacer and is_instance_valid(_gap_spacer):
		if _gap_tween and _gap_tween.is_valid():
			_gap_tween.kill()
		_gap_spacer = null
		_gap_index = -1

	# Remove ALL children — not just tracked die_visuals.
	# The HBoxContainer should only contain die visuals and the gap spacer.
	# Removing everything prevents orphans from roll animations or other systems.
	for child in get_children():
		remove_child(child)
		child.queue_free()

	die_visuals.clear()



func _create_die_visual(die: DieResource, index: int) -> Control:
	"""Create a draggable die visual - tries new system, falls back to old"""
	
	# Try new CombatDieObject system first
	if die.has_method("instantiate_combat_visual"):
		print("      Die %d: type=%d, has_method=%s" % [index, die.die_type, die.has_method("instantiate_combat_visual")])
		var combat_obj = die.instantiate_combat_visual()
		if combat_obj:
			print("      Using CombatDieObject")
			combat_obj.slot_index = index
			combat_obj.draggable = not die.is_locked
			
			# Connect signals - signal already passes die_object, don't use .bind()
			if combat_obj.has_signal("drag_requested"):
				combat_obj.drag_requested.connect(_on_new_die_drag_requested)
			if combat_obj.has_signal("clicked"):
				combat_obj.clicked.connect(_on_new_die_clicked)
			
			# If roll animation is pending, start hidden + non-draggable
			if hide_for_roll_animation:
				combat_obj.modulate = Color(1, 1, 1, 0)
				combat_obj.draggable = false
			
			# Fire reactive event for mid-combat die creation
			if die.is_mana_die:
				var cm_node = get_tree().get_first_node_in_group("combat_manager")
				if cm_node and "event_bus" in cm_node and cm_node.event_bus:
					cm_node.event_bus.emit_die_created(combat_obj, "mana_pull")
			
			
			return combat_obj
		else:
			print("      ⚠️ instantiate_combat_visual returned null")
	
	# Fallback to old DieVisual system
	if die_visual_scene:
		print("      Using fallback DieVisual scene")
		var visual = die_visual_scene.instantiate()
		if visual.has_method("set_die"):
			visual.set_die(die)
		
		if hide_for_roll_animation:
			visual.modulate = Color(1, 1, 1, 0)
		
		return visual
	
	# Try loading DieVisual directly
	var die_visual_path = "res://scenes/ui/components/die_visual.tscn"
	if ResourceLoader.exists(die_visual_path):
		print("      Using direct DieVisual load")
		var scene = load(die_visual_path)
		var visual = scene.instantiate()
		if visual.has_method("set_die"):
			visual.set_die(die)
		
		if hide_for_roll_animation:
			visual.modulate = Color(1, 1, 1, 0)
		
		return visual
	
	print("      ❌ No visual system available!")
	return null

# ============================================================================
# NEW SYSTEM DRAG HANDLING
# ============================================================================

func _on_new_die_drag_requested(die_obj):
	"""Handle drag request from CombatDieObject - just emit our signal
	   The DieObjectBase handles the actual drag via _get_drag_data()"""
	print("🎲 DicePoolDisplay: Drag started for %s" % (die_obj.die_resource.display_name if die_obj.die_resource else "unknown"))
	die_drag_started.emit(die_obj, die_obj.die_resource if die_obj.die_resource else null)

func _on_new_die_clicked(die_obj):
	"""Handle click on CombatDieObject"""
	print("🎲 Die clicked: %s" % (die_obj.die_resource.display_name if die_obj.die_resource else "unknown"))
	die_clicked.emit(die_obj, die_obj.die_resource if die_obj.die_resource else null)





# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_hand_rolled(_hand: Array):
	print("🎲 DicePoolDisplay: hand_rolled signal")
	_request_refresh()

func _on_hand_changed():
	print("🎲 DicePoolDisplay: hand_changed signal")
	hide_for_roll_animation = false  # Mid-turn changes appear immediately
	_request_refresh()


func _on_dice_shattered(shattered_indices: Array[int]):
	"""Play shatter animation on dice that reached 0 value, then hide them."""
	for idx in shattered_indices:
		# Find the visual for this die
		var visual: Control = null
		for v in die_visuals:
			if not is_instance_valid(v):
				continue
			if "slot_index" in v and v.slot_index == idx:
				visual = v
				break
			elif v.has_method("get_die") and v.get_die() == dice_pool.hand[idx]:
				visual = v
				break
		
		if not visual:
			continue
		
		var center = visual.global_position + visual.size / 2
		
		# Get die texture/tint for fragments
		var die = dice_pool.hand[idx]
		var tex: Texture2D = die.fill_texture
		var tint: Color = die.color
		
		# Load or create shatter preset
		var preset: ShatterPreset = _get_shatter_preset()
		
		# Spawn shatter effect
		var effect = ShatterEffect.new()
		effect.configure(preset, center)
		effect.set_source_appearance(tex, tint)
		
		var overlay = get_tree().current_scene.find_child("EffectsLayer", true, false)
		if overlay:
			overlay.add_child(effect)
		else:
			get_tree().current_scene.add_child(effect)
		
		effect.play()
		
		# Hide the visual immediately
		visual.modulate.a = 0.0
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if "draggable" in visual:
			visual.draggable = false
		
		print("  💥 Shatter visual played for die [%d]" % idx)

func _get_shatter_preset() -> ShatterPreset:
	"""Load or create a default shatter preset for hand dice."""
	var path = "res://resources/effects/die_shatter_preset.tres"
	if ResourceLoader.exists(path):
		return load(path)
	
	# Fallback: create one in code
	var preset = ShatterPreset.new()
	preset.fragment_count = 8
	preset.explosion_radius = 80.0
	preset.explosion_duration = 0.4
	preset.upward_bias = 30.0
	preset.gravity = 250.0
	preset.pre_shake_enabled = true
	preset.pre_shake_duration = 0.1
	preset.total_duration = 0.6
	return preset


# ============================================================================
# DEFERRED REFRESH (prevents triple-refresh in one frame)
# ============================================================================

func _request_refresh():
	"""Request a refresh — deferred so multiple signals in one frame only trigger once"""
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_do_deferred_refresh")

func _do_deferred_refresh():
	"""Execute the actual refresh (called once per frame max)"""
	_refresh_pending = false
	refresh()

# ============================================================================
# UTILITY
# ============================================================================




func animate_dice_return(dice_info: Array[Dictionary]):
	"""Animate dice snapping back from action fields to hand positions."""
	# Restore all dice to hand first (un-consume them)
	for info in dice_info:
		var die = info["die"]
		if dice_pool and dice_pool.has_method("restore_to_hand"):
			dice_pool.restore_to_hand(die)
	
	# Wait for deferred refresh to create the visuals
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for layout
	
	# For each returning die, find its new visual and animate a temp from source
	for info in dice_info:
		var die: DieResource = info["die"]
		var from_pos: Vector2 = info["from_pos"]
		
		# Find the real visual that refresh just created
		var target_visual: Control = null
		for visual in die_visuals:
			if not is_instance_valid(visual):
				continue
			if visual.has_method("get_die") and visual.get_die() == die:
				target_visual = visual
				break
			elif "die_resource" in visual and visual.die_resource == die:
				target_visual = visual
				break
		
		if not target_visual:
			continue
		
		var target_pos = target_visual.global_position
		
		# Hide the real visual while the temp flies in
		target_visual.modulate.a = 0.0
		if "draggable" in target_visual:
			target_visual.draggable = false
		
		# Create a temp visual for the flight animation
		var temp: Control = null
		if die.has_method("instantiate_combat_visual"):
			temp = die.instantiate_combat_visual()
		
		if not temp:
			# No temp possible, just show the real one
			target_visual.modulate.a = 1.0
			if "draggable" in target_visual:
				target_visual.draggable = true
			continue
		
		# Add temp to an overlay layer so it draws on top of everything
		var overlay = get_tree().current_scene.find_child("DragOverlayLayer", true, false)
		if overlay:
			overlay.add_child(temp)
		else:
			get_tree().current_scene.add_child(temp)
		
		temp.global_position = from_pos - temp.size / 2
		if "draggable" in temp:
			temp.draggable = false
		temp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Tween from action field slot → hand position
		var tween = create_tween()
		tween.tween_property(temp, "global_position", target_pos, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Don't await here — let all dice fly simultaneously
		tween.finished.connect(func():
			if is_instance_valid(target_visual):
				target_visual.modulate.a = 1.0
				if "draggable" in target_visual:
					target_visual.draggable = true
			if is_instance_valid(temp):
				temp.queue_free()
		)




func get_die_at_position(pos: Vector2) -> Control:
	for visual in die_visuals:
		if visual.get_global_rect().has_point(pos):
			return visual
	return null


func get_die_visual_at(index: int) -> Control:
	"""Get the visual node for a die at a specific hand index.
	Uses slot_index since consumed dice are skipped in the visuals array."""
	for visual in die_visuals:
		if is_instance_valid(visual) and "slot_index" in visual and visual.slot_index == index:
			return visual
	return null


func get_insertion_index_at_position(global_pos: Vector2) -> int:
	"""Calculate where a die should be inserted based on drop position.
	Returns the hand index where the new die should go.
	
	Walks visible die visuals left-to-right (skipping the gap spacer).
	If the drop is to the left of a die's center, the new die goes
	before it. If past all dice, it appends at the end.
	For an empty hand, returns 0.
	"""
	# Walk actual children in visual order (HBoxContainer left-to-right)
	var die_idx := 0
	for child in get_children():
		if child == _gap_spacer:
			continue
		if not is_instance_valid(child) or child not in die_visuals:
			continue
		var center_x = child.global_position.x + child.size.x / 2.0
		if global_pos.x < center_x:
			return die_idx
		die_idx += 1
	
	# Past all dice — append at end
	return dice_pool.hand.size() if dice_pool else 0


func show_insertion_gap(index: int) -> void:
	"""Show or move the insertion gap indicator at the given child index.
	Inserts a spacer Control into the HBoxContainer that animates its width,
	causing the layout engine to push dice apart naturally.
	
	Called by ManaDieSelector on every mouse move during drag.
	"""
	# Clamp to valid range (0 = before first die, child_count = after last)
	var max_index = _count_die_children()
	index = clampi(index, 0, max_index)

	if index == _gap_index and _gap_spacer and is_instance_valid(_gap_spacer):
		return  # Already showing gap at this index

	# Kill any running animation
	if _gap_tween and _gap_tween.is_valid():
		_gap_tween.kill()

	# Create spacer if it doesn't exist
	if not _gap_spacer or not is_instance_valid(_gap_spacer):
		_gap_spacer = Control.new()
		_gap_spacer.name = "InsertionGapSpacer"
		_gap_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gap_spacer.custom_minimum_size = Vector2(0, 0)

	# Remove from tree if already parented (we'll re-insert at new index)
	if _gap_spacer.get_parent() == self:
		remove_child(_gap_spacer)

	# Convert die-array index to child index (account for existing spacer absence)
	var child_idx = _die_index_to_child_index(index)
	add_child(_gap_spacer)
	move_child(_gap_spacer, child_idx)
	_gap_index = index

	# Animate width open
	_gap_tween = create_tween()
	_gap_tween.tween_property(
		_gap_spacer, "custom_minimum_size",
		Vector2(GAP_WIDTH, 0), GAP_ANIM_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func hide_insertion_gap(immediate: bool = false) -> void:
	"""Collapse and remove the insertion gap spacer.
	
	Args:
		immediate: If true, remove instantly with no animation.
		           Use true when the hand is about to refresh (drop/cancel).
		           Use false (default) for cursor-driven hide during drag.
	"""
	if not _gap_spacer or not is_instance_valid(_gap_spacer):
		_gap_index = -1
		return

	# Kill any running animation
	if _gap_tween and _gap_tween.is_valid():
		_gap_tween.kill()
		_gap_tween = null

	if immediate:
		# Remove right now — no tween, no deferred callbacks
		if _gap_spacer.get_parent() == self:
			remove_child(_gap_spacer)
		_gap_spacer.queue_free()
		_gap_spacer = null
		_gap_index = -1
	else:
		# Animate closed, then remove
		_gap_tween = create_tween()
		_gap_tween.tween_property(
			_gap_spacer, "custom_minimum_size",
			Vector2(0, 0), GAP_ANIM_DURATION
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_gap_tween.tween_callback(func():
			if _gap_spacer and is_instance_valid(_gap_spacer):
				if _gap_spacer.get_parent() == self:
					remove_child(_gap_spacer)
				_gap_spacer.queue_free()
				_gap_spacer = null
			_gap_index = -1
		)


func _count_die_children() -> int:
	"""Count how many die visual children exist (excluding the gap spacer)."""
	var count := 0
	for child in get_children():
		if child != _gap_spacer and is_instance_valid(child):
			count += 1
	return count


func _die_index_to_child_index(die_index: int) -> int:
	"""Convert a die-array index to an HBoxContainer child index,
	skipping the gap spacer if it's present in the children list."""
	var child_idx := 0
	var die_count := 0
	for child in get_children():
		if child == _gap_spacer:
			child_idx += 1
			continue
		if die_count == die_index:
			return child_idx
		die_count += 1
		child_idx += 1
	return child_idx  # After all dice = append position
