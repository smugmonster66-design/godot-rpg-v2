# res://scripts/ui/combat/dice_pool_display.gd
# Combat hand display - shows rolled dice available for actions
# Uses CombatDieObject for each die, with fallback to DieVisual
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
var _is_animating_entrance: bool = false
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
	"""Refresh the display to match current hand"""
	print("🎲 DicePoolDisplay.refresh()")
	
	if not dice_pool:
		print("  ⚠️ No dice_pool")
		return
	
	# Kill any in-progress entrance animation
	_is_animating_entrance = false
	
	clear_display()
	
	var hand = dice_pool.hand
	print("  📊 Creating visuals for %d dice in hand" % hand.size())
	
	for i in range(hand.size()):
		var die = hand[i]
		var visual = _create_die_visual(die, i)
		if visual:
			visual.modulate.a = 0.0  # Start invisible for entrance animation
			add_child(visual)
			die_visuals.append(visual)
			print("    ✅ Created visual for %s (value=%d)" % [die.display_name, die.get_total_value()])
		else:
			print("    ❌ Failed to create visual for %s" % die.display_name)
	
	# Animate the hand appearing
	_animate_hand_entrance()


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
# HAND ENTRANCE ANIMATION
# ============================================================================

func _animate_hand_entrance():
	"""Animate dice appearing in the hand one by one"""
	_is_animating_entrance = true
	
	for i in range(die_visuals.size()):
		if not _is_animating_entrance:
			# Animation was cancelled (new refresh started)
			break
		
		var visual = die_visuals[i]
		if not is_instance_valid(visual):
			continue
		
		var delay = i * 0.08  # Stagger each die
		
		var tween = create_tween()
		tween.tween_interval(delay)
		
		# Scale up from small + fade in
		visual.scale = Vector2(0.3, 0.3)
		tween.tween_property(visual, "modulate:a", 1.0, 0.15)
		tween.parallel().tween_property(visual, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Play the CombatDieObject roll animation after it appears
		if visual.has_method("play_roll_animation"):
			tween.tween_callback(visual.play_roll_animation)
	
	_is_animating_entrance = false


# ============================================================================
# UTILITY
# ============================================================================

func get_die_at_position(pos: Vector2) -> Control:
	for visual in die_visuals:
		if visual.get_global_rect().has_point(pos):
			return visual
	return null
