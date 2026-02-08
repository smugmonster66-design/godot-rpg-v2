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

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_theme_constant_override("separation", die_spacing)
	alignment = BoxContainer.ALIGNMENT_CENTER
	print("🎲 DicePoolDisplay ready")

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
	
	refresh()

# ============================================================================
# DISPLAY
# ============================================================================

func refresh():
	"""Refresh the display to match current hand.
	
	Visuals are created HIDDEN (alpha = 0, draggable = false).
	The CombatRollAnimator reveals each die with the projectile animation.
	For mid-turn refreshes (e.g. die consumed), hide_for_roll_animation will
	be false, so dice appear immediately.
	"""
	print("🎲 DicePoolDisplay.refresh()")
	
	if not dice_pool:
		print("  ⚠️ No dice_pool")
		return
	
	clear_display()
	
	var hand = dice_pool.hand
	print("  📊 Creating visuals for %d dice in hand" % hand.size())
	
	for i in range(hand.size()):
		var die = hand[i]
		if die.is_consumed:
			continue  # Fully hidden from hand
		var visual = _create_die_visual(die, i)
		if visual:
			# Start invisible when roll animation is pending
			if hide_for_roll_animation:
				visual.modulate.a = 0.0
			add_child(visual)
			die_visuals.append(visual)
			print("    ✅ Created visual for %s (value=%d)%s" % [
				die.display_name,
				die.get_total_value(),
				" [HIDDEN]" if hide_for_roll_animation else ""
			])
		else:
			print("    ❌ Failed to create visual for %s" % die.display_name)
	
	# No entrance animation here — CombatRollAnimator handles all reveal


func clear_display():
	"""Remove all die visuals immediately so they don't corrupt layout"""
	for visual in die_visuals:
		if is_instance_valid(visual):
			remove_child(visual)
			visual.queue_free()
	die_visuals.clear()
	
	# Clear any stragglers not tracked in die_visuals
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _create_die_visual(die: DieResource, index: int) -> Control:
	"""Create a draggable die visual - tries new system, falls back to old"""
	
	# Try new CombatDieObject system first
	if die.has_method("instantiate_combat_visual"):
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
	_request_refresh()

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
