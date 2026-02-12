# res://scripts/ui/combat/combat_ui.gd
# Combat UI - dynamically creates action fields in scrollable grid
extends CanvasLayer

# ============================================================================
# NODE REFERENCES - All found from scene
# ============================================================================
var action_fields_scroll: ScrollContainer = null
var action_fields_grid: GridContainer = null
var player_health_display = null
var dice_pool_display = null
var enemy_panel: EnemyPanel = null

# Action field scene for dynamic creation
var action_field_scene: PackedScene = null

# Dynamically created action fields
var action_fields: Array[ActionField] = []


# Enemy turn display nodes
var enemy_hand_container: Control = null
var enemy_action_label: Label = null
var enemy_dice_visuals: Array[Control] = []
var current_enemy_display: Combatant = null

# Temp animation visuals (for cleanup)
var temp_animation_visuals: Array[Control] = []

var roll_animator: CombatRollAnimator = null

var affix_visual_animator: AffixVisualAnimator = null

var reactive_animator: ReactiveAnimator = null

var effect_player: CombatEffectPlayer = null
# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var enemy = null  # Primary enemy (backwards compatibility)
var enemies: Array = []  # All enemies
var action_manager: ActionManager = null
var selected_action_field: ActionField = null

# Target selection
var selected_target_index: int = 0
var target_selection_active: bool = false

var temp_action_fields: Array[Dictionary] = []


# Enemy turn state
var is_enemy_turn: bool = false
var enemy_action_fields: Array[ActionField] = []

var _pending_dice_returns: Array[Dictionary] = []

var _bottom_ui: BottomUIPanel = null

# ============================================================================
# SIGNALS
# ============================================================================
signal action_confirmed(action_data: Dictionary)
signal turn_ended()
signal target_selected(enemy: Combatant, index: int)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🎮 CombatUI initializing...")
	
	# Load action field scene
	action_field_scene = load("res://scenes/ui/combat/action_field.tscn")
	if not action_field_scene:
		push_error("Failed to load action_field.tscn!")
	
	# Find all UI nodes from scene
	_discover_all_nodes()
	
	# Connect signals
	_connect_all_signals()
	
	print("🎮 CombatUI ready")

func _discover_all_nodes():
	"""Find all UI nodes from the scene tree"""
	print("  🔍 Discovering UI nodes...")
	
	# Ensure scrollable grid exists
	_ensure_scrollable_grid()
	
	# Player health display
	player_health_display = find_child("PlayerHealth", true, false)
	if not player_health_display:
		player_health_display = find_child("PlayerHealthDisplay", true, false)
	print("    PlayerHealth: %s" % ("✓" if player_health_display else "✗"))
	
	# Dice pool display
	dice_pool_display = find_child("DicePoolDisplay", true, false)
	if not dice_pool_display:
		dice_pool_display = find_child("DiceGrid", true, false)
	print("    DicePoolDisplay: %s" % ("✓" if dice_pool_display else "✗"))

	# Fix DicePoolArea — CenterContainer wrapping DicePoolDisplay
	var dice_pool_area = find_child("DicePoolArea", true, false)
	if dice_pool_area and dice_pool_area is Control:
		dice_pool_area.mouse_filter = Control.MOUSE_FILTER_PASS
		print("    🔧 DicePoolArea mouse_filter → PASS (drag-drop fix)")
	
	# Bottom UI panel — owns combat buttons
	_bottom_ui = get_tree().get_first_node_in_group("bottom_ui") as BottomUIPanel
	print("    BottomUI: %s" % ("✓" if _bottom_ui else "✗"))
	
	# Enemy panel
	enemy_panel = find_child("EnemyPanel", true, false) as EnemyPanel
	print("    EnemyPanel: %s" % ("✓" if enemy_panel else "✗"))
	
	# Enemy hand display (for enemy turns)
	enemy_hand_container = find_child("EnemyHandDisplay", true, false)
	if enemy_hand_container:
		enemy_action_label = enemy_hand_container.find_child("ActionLabel", true, false) as Label
	print("    EnemyHandDisplay: %s" % ("✓" if enemy_hand_container else "✗"))
	
	
func _ensure_scrollable_grid():
	"""Find scrollable action grid from scene"""
	var fields_area = find_child("ActionFieldsArea", true, false)
	if not fields_area:
		push_error("ActionFieldsArea not found!")
		return
	
	# Find scroll container
	action_fields_scroll = fields_area.find_child("ActionFieldsScroll", true, false) as ScrollContainer
	if not action_fields_scroll:
		push_error("ActionFieldsScroll not found!")
		return
	
	# =========================================================================
	# FIX: ScrollContainer defaults to MOUSE_FILTER_STOP which intercepts
	# drag-drop events before they reach ActionField children inside.
	# Setting to PASS lets drops fall through to the ActionFields.
	# =========================================================================
	action_fields_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	print("    🔧 ActionFieldsScroll mouse_filter → PASS (drag-drop fix)")
	
	# Check for CenterContainer between ScrollContainer and Grid
	var center = action_fields_scroll.find_child("FieldsMargin", true, false)
	if center and center is Control:
		center.mouse_filter = Control.MOUSE_FILTER_PASS
		print("    🔧 CenterContainer mouse_filter → PASS (drag-drop fix)")
	
	# Find grid (inside CenterContainer)
	action_fields_grid = action_fields_scroll.find_child("ActionFieldsGrid", true, false) as GridContainer
	if not action_fields_grid:
		push_error("ActionFieldsGrid not found!")
		return
	
	# Grid also needs PASS so it doesn't eat the drop
	action_fields_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	print("    🔧 ActionFieldsGrid mouse_filter → PASS (drag-drop fix)")
	
	# Configure scroll settings
	_configure_scroll_container()
	
	print("    ActionFieldsScroll: ✓")
	print("    ActionFieldsGrid: ✓")



func _configure_scroll_container():
	"""Configure scroll container settings"""
	if not action_fields_scroll:
		return
	
	# Hide scrollbars but allow scrolling
	action_fields_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_fields_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	# Make vertical scrollbar invisible
	var v_scrollbar = action_fields_scroll.get_v_scroll_bar()
	if v_scrollbar:
		v_scrollbar.modulate.a = 0

func _connect_all_signals():
	"""Connect signals from discovered nodes"""
	print("  🔗 Connecting signals...")
	
	# Enemy panel
	if enemy_panel:
		if not enemy_panel.enemy_selected.is_connected(_on_enemy_panel_selection):
			enemy_panel.enemy_selected.connect(_on_enemy_panel_selection)
		if not enemy_panel.selection_changed.is_connected(_on_target_selection_changed):
			enemy_panel.selection_changed.connect(_on_target_selection_changed)
	
	# Combat buttons via BottomUIPanel
	if _bottom_ui:
		if not _bottom_ui.roll_pressed.is_connected(_on_roll_pressed):
			_bottom_ui.roll_pressed.connect(_on_roll_pressed)
		if not _bottom_ui.end_turn_pressed.is_connected(_on_end_turn_pressed):
			_bottom_ui.end_turn_pressed.connect(_on_end_turn_pressed)
		if not _bottom_ui.confirm_pressed.is_connected(_on_confirm_pressed):
			_bottom_ui.confirm_pressed.connect(_on_confirm_pressed)
		if not _bottom_ui.cancel_pressed.is_connected(_on_cancel_pressed):
			_bottom_ui.cancel_pressed.connect(_on_cancel_pressed)
	
	print("  ✅ Signals connected")

# ============================================================================
# INITIALIZATION WITH PLAYER/ENEMIES
# ============================================================================


func initialize_ui(p_player: Player, p_enemies):
	"""Initialize the UI with player and enemies"""
	print("🎮 CombatUI.initialize_ui called")
	player = p_player
	
	# Handle both single enemy and array
	if p_enemies is Array:
		enemies = p_enemies
		enemy = enemies[0] if enemies.size() > 0 else null
	elif p_enemies:
		enemies = [p_enemies]
		enemy = p_enemies
	else:
		enemies = []
		enemy = null
	
	print("  Enemies: %d" % enemies.size())
	
	# Initialize enemy panel
	if enemy_panel:
		enemy_panel.initialize_enemies(enemies)
		print("  ✅ Enemy panel initialized")
	else:
		print("  ⚠️ No enemy panel found")
	
	# Create ActionManager if needed
	if not action_manager:
		action_manager = ActionManager.new()
		action_manager.name = "ActionManager"
		add_child(action_manager)
		if action_manager.has_signal("actions_changed") and not action_manager.actions_changed.is_connected(_on_actions_changed):
			action_manager.actions_changed.connect(_on_actions_changed)
	
	# Initialize ActionManager with player
	action_manager.initialize(player)
	
	# Setup displays
	_setup_health_display()
	_setup_dice_pool()
	
	# Initial field refresh
	refresh_action_fields()
	
	# Reset all charges for combat start
	reset_action_charges_for_combat()
	
	# Create and initialize roll animator
	roll_animator = CombatRollAnimator.new()
	roll_animator.name = "RollAnimator"
	add_child(roll_animator)
	
	# Initialize with hand display + optional pool grid for source positions
	var bottom_ui_grid = _find_pool_dice_grid()
	roll_animator.initialize(dice_pool_display, bottom_ui_grid)
	
	# --- Combat effect player (general purpose visual effects) ---
	effect_player = CombatEffectPlayer.new()
	effect_player.name = "CombatEffectPlayer"
	add_child(effect_player)
	effect_player.initialize(dice_pool_display, enemy_panel, player_health_display)
	print("  ✅ CombatEffectPlayer initialized")
	
	# --- v2.2: Affix visual animator (roll effects, projectiles between dice) ---
	affix_visual_animator = AffixVisualAnimator.new()
	affix_visual_animator.name = "AffixVisualAnimator"
	add_child(affix_visual_animator)
	if player and player.dice_pool and "affix_processor" in player.dice_pool and player.dice_pool.affix_processor:
		affix_visual_animator.initialize(dice_pool_display, player.dice_pool.affix_processor, roll_animator, effect_player)
		print("  ✅ AffixVisualAnimator initialized")
	else:
		push_warning("CombatUI: Could not initialize AffixVisualAnimator — no affix_processor found")
	
	
	
	# --- Reactive animation system ---
	reactive_animator = ReactiveAnimator.new()
	reactive_animator.name = "ReactiveAnimator"
	add_child(reactive_animator)
	
	# Load all reaction .tres files from the reactions directory
	var reaction_dir = "res://resources/effects/reactions/"
	var dir = DirAccess.open(reaction_dir)
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while filename != "":
			if filename.ends_with(".tres"):
				var reaction = load(reaction_dir + filename) as AnimationReaction
				if reaction:
					reactive_animator.reactions.append(reaction)
			filename = dir.get_next()
		dir.list_dir_end()
	
	# Connect to the event bus on CombatManager
	var cm = get_tree().get_first_node_in_group("combat_manager")
	if cm and "event_bus" in cm and cm.event_bus:
		var cm_anim_player = cm.find_child("CombatAnimationPlayer", true, false) as CombatAnimationPlayer
		reactive_animator.initialize(cm.event_bus, effect_player, cm_anim_player)
		print("  ✅ ReactiveAnimator initialized with %d reactions" % reactive_animator.reactions.size())
	else:
		push_warning("CombatUI: Could not find CombatEventBus for ReactiveAnimator")
	
	
	
	
	print("🎮 CombatUI initialization complete")



func _setup_health_display():
	"""Setup health display"""
	if player_health_display and player_health_display.has_method("initialize"):
		player_health_display.initialize("Player", player.current_hp, player.max_hp, Color.RED)

func _setup_dice_pool():
	"""Setup dice pool display (HAND mode for combat)"""
	if not dice_pool_display:
		return
	
	# Set to HAND mode if supported
	if "grid_mode" in dice_pool_display:
		dice_pool_display.grid_mode = 1  # HAND mode
	
	if dice_pool_display.has_method("initialize") and player and player.dice_pool:
		dice_pool_display.initialize(player.dice_pool)

# ============================================================================
# HEALTH UPDATES
# ============================================================================

func update_player_health(current: int, maximum: int):
	"""Update player health display"""
	if player_health_display and player_health_display.has_method("update_health"):
		player_health_display.update_health(current, maximum)

func update_enemy_health(enemy_index: int, current: int, maximum: int):
	"""Update an enemy's health display"""
	if enemy_panel:
		enemy_panel.update_enemy_health(enemy_index, current, maximum)

# ============================================================================
# TARGET SELECTION SYSTEM
# ============================================================================

func enable_target_selection():
	"""Enable target selection mode"""
	target_selection_active = true
	
	if enemy_panel:
		enemy_panel.set_selection_enabled(true)
	
	_update_enemy_selection_visuals()

func disable_target_selection():
	"""Disable target selection mode"""
	target_selection_active = false
	
	if enemy_panel:
		enemy_panel.set_selection_enabled(false)
	
	# Remove selection shader from all enemies
	for e in enemies:
		if e and e.has_method("set_target_selected"):
			e.set_target_selected(false)

func get_selected_target() -> Combatant:
	"""Get the currently selected target enemy"""
	if enemy_panel:
		return enemy_panel.get_selected_enemy()
	return enemy

func get_selected_target_index() -> int:
	"""Get the selected target index"""
	if enemy_panel:
		return enemy_panel.get_selected_slot_index()
	return 0

func _update_enemy_selection_visuals():
	"""Update visual selection on enemies"""
	if not target_selection_active:
		return
	
	var selected_index = get_selected_target_index()
	
	for i in range(enemies.size()):
		var e = enemies[i]
		if e and e.has_method("set_target_selected"):
			e.set_target_selected(i == selected_index)

func _on_enemy_panel_selection(enemy_combatant: Combatant, slot_index: int):
	"""Handle enemy selection from panel"""
	print("🎯 Target selected: %s (slot %d)" % [enemy_combatant.combatant_name, slot_index])
	selected_target_index = slot_index
	
	_update_enemy_selection_visuals()
	target_selected.emit(enemy_combatant, slot_index)

func _on_target_selection_changed(slot_index: int):
	"""Handle selection change"""
	selected_target_index = slot_index
	_update_enemy_selection_visuals()

# ============================================================================
# TURN MANAGEMENT
# ============================================================================

func on_turn_start():
	"""Called after roll animation completes — now handled by enter_action_phase()"""
	pass

func set_player_turn(is_player: bool):
	"""Update UI for whose turn it is"""
	is_enemy_turn = not is_player
	
	if is_player:
		if dice_pool_display:
			dice_pool_display.show()
		hide_enemy_hand()
	else:
		if dice_pool_display:
			dice_pool_display.hide()
		if _bottom_ui:
			_bottom_ui.enter_enemy_turn()
		disable_target_selection()

func refresh_dice_pool():
	"""Refresh the dice pool/hand display"""
	if dice_pool_display and dice_pool_display.has_method("refresh"):
		dice_pool_display.refresh()


# ============================================================================
# PHASE MANAGEMENT
# ============================================================================

func enter_prep_phase():
	print("🎮 CombatUI: Entering PREP phase")
	is_enemy_turn = false

	if dice_pool_display:
		dice_pool_display.hide()

	# Clear action fields
	for child in action_fields_grid.get_children():
		child.queue_free()
	action_fields.clear()

	hide_enemy_hand()

	# Delegate button visibility to BottomUIPanel
	if _bottom_ui:
		_bottom_ui.enter_prep_phase()

	disable_target_selection()
	selected_action_field = null


func enter_action_phase():
	print("🎮 CombatUI: Entering ACTION phase")

	if dice_pool_display:
		dice_pool_display.show()

	refresh_action_fields()
	reset_action_charges_for_turn()
	_apply_combat_charge_state()

	if enemy_panel:
		enemy_panel.select_first_living_enemy()

	# Delegate button visibility to BottomUIPanel
	if _bottom_ui:
		_bottom_ui.enter_action_phase()



# ============================================================================
# CHARGE MANAGEMENT
# ============================================================================

func reset_action_charges_for_combat():
	"""Reset all action charges at combat start"""
	for field in action_fields:
		if is_instance_valid(field) and field.action_resource:
			field.action_resource.reset_charges_for_combat()
			field.refresh_charge_state()

func reset_action_charges_for_turn():
	"""Reset per-turn action charges"""
	for field in action_fields:
		if is_instance_valid(field) and field.action_resource:
			field.action_resource.reset_charges_for_turn()
			field.refresh_charge_state()

func on_action_used(field: ActionField):
	"""Called when an action is confirmed - consume charge and track it"""
	if field and field.action_resource:
		field.consume_charge()
		field.refresh_charge_state()

		# Track per-combat charge usage
		var combat_manager = get_tree().get_first_node_in_group("combat_manager")
		if combat_manager and combat_manager.has_method("track_charge_used"):
			combat_manager.track_charge_used(field.action_resource)


# ============================================================================
# ACTION FIELD MANAGEMENT - PLAYER
# ============================================================================

func _on_actions_changed():
	"""Called when ActionManager rebuilds actions"""
	if not is_enemy_turn:
		refresh_action_fields()

var _refreshing_action_fields: bool = false


func refresh_action_fields():
	"""Rebuild action fields grid from player's available actions"""
	if _refreshing_action_fields:
		return  # Already refreshing, skip
	
	if not action_manager or not action_fields_grid:
		print("⚠️ Cannot refresh action fields - missing manager or grid")
		return
	
	if is_enemy_turn:
		return  # Don't overwrite enemy actions
	
	_refreshing_action_fields = true
	
	# Clear existing fields
	for child in action_fields_grid.get_children():
		child.queue_free()
	action_fields.clear()
	
	# Get all actions (unified list, no categories)
	var all_actions = action_manager.get_actions()
	
	print("🎮 Creating %d player action fields" % all_actions.size())
	
	# Wait a frame for children to be freed
	await get_tree().process_frame
	
	# Create action field for each action
	for action_data in all_actions:
		var field = _create_action_field(action_data)
		if field:
			action_fields_grid.add_child(field)
			action_fields.append(field)
			# =================================================================
			# SAFETY: Ensure player fields are STOP (not IGNORE).
			# configure_from_dict → update_disabled_state can set IGNORE
			# if has_charges() returns false before action_resource is
			# fully initialized. This forces STOP for non-disabled fields.
			# =================================================================
			if not field.is_disabled:
				field.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_refreshing_action_fields = false



func _create_action_field(action_data: Dictionary) -> ActionField:
	"""Create a single action field from data"""
	if not action_field_scene:
		push_error("ActionField scene not loaded!")
		return null
	
	var field = action_field_scene.instantiate() as ActionField
	if not field:
		push_error("Failed to instantiate ActionField!")
		return null
	
	# Configure from data
	field.configure_from_dict(action_data)
	
	# Connect signals (ONCE only)
	field.action_selected.connect(_on_action_field_selected)
	field.dice_returned.connect(_on_dice_returned)
	field.die_placed.connect(_on_die_placed)
	field.dice_return_complete.connect(_on_dice_return_complete)
	
	# =========================================================================
	# DEBUG: After the field enters the tree and _ready() runs, verify it is
	# properly configured to receive drops. Uses a weak ref to avoid lambda
	# capture errors if the field is freed before entering the tree.
	# =========================================================================
	var field_ref = weakref(field)
	field.tree_entered.connect(func():
		var f = field_ref.get_ref()
		if not f or not is_instance_valid(f):
			return
		await get_tree().process_frame
		if not is_instance_valid(f):
			return
		print("🔍 ActionField '%s' post-ready check:" % f.action_name)
		print("    mouse_filter: %s" % _mf_name(f.mouse_filter))
		print("    die_slot_panels: %d" % f.die_slot_panels.size())
		print("    die_slots_grid: %s" % ("found" if f.die_slots_grid else "NULL ⚠️"))
		print("    is_disabled: %s" % f.is_disabled)
		print("    size: %s" % f.size)
		print("    global_position: %s" % f.global_position)
		
		# Walk ancestor chain and flag any IGNORE nodes that block drops
		var node = f.get_parent()
		while node:
			if node is Control:
				var mf = _mf_name(node.mouse_filter)
				if node.mouse_filter == Control.MOUSE_FILTER_IGNORE:
					push_warning("⚠️ Ancestor '%s' has MOUSE_FILTER_IGNORE — blocks drops to ActionField!" % node.name)
				print("    ↑ %s [%s] mouse_filter=%s" % [node.name, node.get_class(), mf])
			node = node.get_parent()
	, CONNECT_ONE_SHOT)
	
	return field


func _on_die_placed(_field: ActionField, die: DieResource):
	"""When a die is dropped on an action field, consume it from the hand."""
	if player and player.dice_pool:
		player.dice_pool.consume_from_hand(die)


func _on_dice_returned(die: DieResource, _from_pos: Vector2):
	"""When cancel returns a die, restore it to the hand."""
	if player and player.dice_pool:
		player.dice_pool.restore_to_hand(die)


func _on_dice_return_complete():
	if _pending_dice_returns.size() > 0 and dice_pool_display:
		dice_pool_display.animate_dice_return(_pending_dice_returns)
		_pending_dice_returns.clear()



func _on_action_field_selected(field: ActionField):
	"""Action field was clicked or had die dropped"""
	if is_enemy_turn:
		return

	print("🎯 Action field selected: %s" % field.action_name)

	selected_action_field = field

	var action_type = field.action_type
	if action_type == ActionField.ActionType.ATTACK:
		enable_target_selection()
	else:
		disable_target_selection()

	# Show confirm/cancel via BottomUIPanel
	if _bottom_ui:
		_bottom_ui.show_action_buttons(true)

func _on_action_field_confirmed(action_data: Dictionary):
	"""Action was confirmed from field directly"""
	action_confirmed.emit(action_data)


# ============================================================================
# ENEMY TURN DISPLAY - Action Fields
# ============================================================================

func show_enemy_actions(enemy_combatant: Combatant):
	"""Display enemy's available actions in the ActionFieldsGrid"""
	is_enemy_turn = true
	
	if not action_fields_grid:
		return
	
	# Clear existing fields
	for child in action_fields_grid.get_children():
		child.queue_free()
	action_fields.clear()
	enemy_action_fields.clear()
	
	# Wait for children to be freed
	await get_tree().process_frame
	
	# Get enemy's actions
	var actions = enemy_combatant.actions
	
	print("🎮 Showing %d enemy actions" % actions.size())
	
	# Create action field for each enemy action
	for action_data in actions:
		var field = _create_enemy_action_field(action_data)
		if field:
			action_fields_grid.add_child(field)
			action_fields.append(field)
			enemy_action_fields.append(field)
	
	# Show empty message if no actions
	if actions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No actions"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		action_fields_grid.add_child(empty_label)

func _create_enemy_action_field(action_data: Dictionary) -> ActionField:
	"""Create an action field for enemy display (non-interactive)"""
	if not action_field_scene:
		push_error("ActionField scene not loaded!")
		return null
	
	var field = action_field_scene.instantiate() as ActionField
	if not field:
		push_error("Failed to instantiate ActionField!")
		return null
	
	# Configure from data
	field.configure_from_dict(action_data)
	
	# Disable player interaction
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	return field

func find_action_field_by_name(action_name: String) -> ActionField:
	"""Find an action field by its action name"""
	for field in action_fields:
		if is_instance_valid(field) and field.action_name == action_name:
			return field
	return null

func highlight_enemy_action(action_name: String):
	"""Highlight the action field the enemy is using"""
	var field = find_action_field_by_name(action_name)
	if field:
		# Visual highlight
		var tween = create_tween()
		tween.tween_property(field, "modulate", Color(1.3, 1.2, 0.8), 0.2)


func animate_die_to_action_field(die_visual: Control, action_name: String, die: DieResource = null) -> void:
	"""Animate a die moving from hand to action field by reparenting"""
	var field = find_action_field_by_name(action_name)
	if not field:
		print("  ⚠️ No action field found for: %s" % action_name)
		await get_tree().create_timer(0.3).timeout
		return
	
	var slot_index = field.placed_dice.size()
	if slot_index >= field.die_slot_panels.size():
		print("  ⚠️ No more slots available")
		await get_tree().create_timer(0.3).timeout
		return
	
	var target_slot = field.die_slot_panels[slot_index]
	
	# Debug: check what we got
	print("  🎬 animate_die_to_action_field:")
	print("    die_visual valid: %s" % (die_visual != null and is_instance_valid(die_visual)))
	print("    die: %s" % (die.display_name if die else "null"))
	
	if not die_visual or not is_instance_valid(die_visual):
		print("  ⚠️ No valid die_visual to animate")
		# Still need to place the die data even without visual
		if die:
			field.placed_dice.append(die)
		await get_tree().create_timer(0.3).timeout
		return
	
	# Track the die in placed_dice
	var die_to_place = die if die else (die_visual.get_die() if die_visual.has_method("get_die") else null)
	if die_to_place:
		field.placed_dice.append(die_to_place)
	
	# Clear any existing children in slot
	for child in target_slot.get_children():
		child.queue_free()
	
	# Store start position before reparenting
	var start_global_pos = die_visual.global_position
	
	# Reparent to the scene root temporarily for smooth animation
	var old_parent = die_visual.get_parent()
	if old_parent:
		old_parent.remove_child(die_visual)
	get_tree().root.add_child(die_visual)
	
	# Configure for animation
	die_visual.visible = true
	die_visual.global_position = start_global_pos
	die_visual.z_index = 100
	if "draggable" in die_visual:
		die_visual.draggable = false
	die_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Flash effect
	var flash_tween = create_tween()
	flash_tween.tween_property(die_visual, "modulate", Color(1.5, 1.5, 0.5), 0.1)
	flash_tween.tween_property(die_visual, "modulate", Color.WHITE, 0.1)
	await flash_tween.finished
	
	# Calculate target position (center of slot in global coords)
	var target_global = target_slot.global_position + target_slot.size / 2
	
	# Animate to target
	var move_tween = create_tween().set_parallel(true)
	move_tween.tween_property(die_visual, "global_position", target_global - die_visual.pivot_offset * field.DIE_SCALE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	move_tween.tween_property(die_visual, "scale", Vector2(field.DIE_SCALE, field.DIE_SCALE), 0.3).set_ease(Tween.EASE_OUT)
	await move_tween.finished
	
	# Now reparent to the actual slot
	get_tree().root.remove_child(die_visual)
	target_slot.add_child(die_visual)
	
	# Set final local position
	die_visual.z_index = 0
	die_visual.custom_minimum_size = Vector2.ZERO
	die_visual.position = field.SLOT_SIZE / 2 - die_visual.pivot_offset
	
	field.dice_visuals.append(die_visual)
	field.update_icon_state()




func _apply_temp_visual_affix_effects(container: Control, face: Control, tex: TextureRect, die: DieResource):
	"""Apply affix visual effects to temp animation visual"""
	if not die:
		return
	
	var face_size = Vector2(124, 124)
	
	for affix in die.get_all_affixes():
		match affix.visual_effect_type:
			DiceAffix.VisualEffectType.COLOR_TINT:
				if tex:
					tex.modulate = tex.modulate * affix.effect_color
			
			DiceAffix.VisualEffectType.SHADER:
				if tex and affix.shader_material:
					tex.material = affix.shader_material.duplicate()
			
			DiceAffix.VisualEffectType.OVERLAY_TEXTURE:
				if affix.overlay_texture:
					var overlay = TextureRect.new()
					overlay.texture = affix.overlay_texture
					overlay.custom_minimum_size = face_size
					overlay.size = face_size
					overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					overlay.modulate.a = affix.overlay_opacity
					
					if affix.overlay_blend_mode > 0:
						var mat = CanvasItemMaterial.new()
						match affix.overlay_blend_mode:
							1: mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
							2: mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
						overlay.material = mat
					
					container.add_child(overlay)
			
			DiceAffix.VisualEffectType.BORDER_GLOW:
				var glow = Panel.new()
				glow.custom_minimum_size = face_size
				glow.size = face_size
				
				var glow_style = StyleBoxFlat.new()
				glow_style.bg_color = Color.TRANSPARENT
				glow_style.border_color = affix.effect_color
				glow_style.set_border_width_all(3)
				glow_style.set_corner_radius_all(8)
				glow_style.shadow_color = affix.effect_color
				glow_style.shadow_size = 6
				glow.add_theme_stylebox_override("panel", glow_style)
				
				container.add_child(glow)
				container.move_child(glow, 0)
			
			DiceAffix.VisualEffectType.PARTICLE:
				if affix.particle_scene:
					var particles = affix.particle_scene.instantiate()
					if particles is GPUParticles2D:
						particles.position = face_size / 2
						particles.emitting = true
						container.add_child(particles)




func _add_fallback_die_visual(container: PanelContainer, die: DieResource):
	"""Add a simple fallback visual when die face scene isn't available"""
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(vbox)
	
	var value_label = Label.new()
	value_label.text = str(die.get_total_value()) if die else "?"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(value_label)





func animate_enemy_action_confirm(action_name: String) -> void:
	"""Animate the enemy confirming their action and clear dice"""
	var field = find_action_field_by_name(action_name)
	if not field:
		return
	
	# Animate each placed die being consumed
	for visual in field.dice_visuals:
		if is_instance_valid(visual):
			_animate_die_consumed(visual)
	
	# Flash confirm effect on the field
	var tween = create_tween()
	tween.tween_property(field, "modulate", Color(1.5, 1.0, 0.5), 0.15)
	tween.tween_property(field, "modulate", Color.WHITE, 0.15)
	await tween.finished
	
	# Clear the field
	if is_instance_valid(field):
		field.clear_dice()

func clear_enemy_turn_display():
	"""Clear enemy turn display and restore player actions"""
	is_enemy_turn = false
	
	# Clean up any lingering temp animation visuals
	for visual in temp_animation_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	temp_animation_visuals.clear()
	
	# Clear dice from enemy action fields before freeing them
	for field in enemy_action_fields:
		if is_instance_valid(field):
			field.clear_dice()
	
	enemy_action_fields.clear()

# ============================================================================
# ACTION BUTTONS
# ============================================================================

func _on_confirm_pressed():
	"""Confirm button pressed"""
	if not selected_action_field:
		return

	if not selected_action_field.is_ready_to_confirm():
		print("⚠️ Action not ready - need more dice")
		return

	on_action_used(selected_action_field)

	var placed_dice_copy = selected_action_field.placed_dice.duplicate()

	var action_data = {
		"name": selected_action_field.action_name,
		"action_type": selected_action_field.action_type,
		"base_damage": selected_action_field.base_damage,
		"damage_multiplier": selected_action_field.damage_multiplier,
		"placed_dice": placed_dice_copy,
		"source": selected_action_field.source,
		"action_resource": selected_action_field.action_resource,
		"target": get_selected_target(),
		"target_index": get_selected_target_index()
	}

	print("✅ Confirming action: %s with %d dice" % [action_data.name, placed_dice_copy.size()])

	_consume_placed_dice(placed_dice_copy)
	_clear_action_field_with_animation(selected_action_field)

	# Hide confirm/cancel
	if _bottom_ui:
		_bottom_ui.show_action_buttons(false)

	disable_target_selection()
	selected_action_field = null
	action_confirmed.emit(action_data)

func _consume_placed_dice(dice: Array):
	refresh_dice_pool()

func _clear_action_field_with_animation(field: ActionField):
	"""Clear action field slots with a consume animation"""
	if not field:
		return
	
	# Animate each die visual being consumed
	for i in range(field.dice_visuals.size()):
		var visual = field.dice_visuals[i]
		if is_instance_valid(visual):
			_animate_die_consumed(visual)
	
	# Clear the field data after a short delay
	var field_ref = weakref(field)
	var tween = create_tween()
	tween.tween_interval(0.25)
	tween.tween_callback(func():
		var f = field_ref.get_ref()
		if f and is_instance_valid(f):
			f.clear_dice()
	)





func _animate_die_consumed(visual: Control):
	"""Animate a die being consumed (shrink and fade centered)"""
	if not is_instance_valid(visual):
		return
	
	# Capture current scale and animate from there
	var start_scale = visual.scale
	var vis_ref = weakref(visual)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate", Color(1.5, 1.2, 0.5, 1.0), 0.1)
	tween.chain().tween_property(visual, "modulate:a", 0.0, 0.15)
	tween.tween_property(visual, "scale", start_scale * 0.3, 0.25).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		var v = vis_ref.get_ref()
		if v and is_instance_valid(v):
			v.queue_free()
	)


func _on_cancel_pressed():
	"""Cancel button pressed"""
	if selected_action_field:
		selected_action_field.cancel_action()

	selected_action_field = null

	if _bottom_ui:
		_bottom_ui.show_action_buttons(false)

	disable_target_selection()

func _on_end_turn_pressed():
	"""End turn button pressed"""
	print("🎮 End turn pressed")

	for field in action_fields:
		if is_instance_valid(field) and field.has_method("cancel_action") and field.placed_dice.size() > 0:
			field.cancel_action()

	if _bottom_ui:
		_bottom_ui.show_action_buttons(false)

	turn_ended.emit()

# ============================================================================
# ENEMY TURN DISPLAY - Hand
# ============================================================================

func show_enemy_hand(enemy_combatant: Combatant):
	"""Show enemy's dice hand and actions during their turn"""
	current_enemy_display = enemy_combatant
	
	# Show turn indicator
	if enemy_panel:
		var enemy_index = enemy_panel.get_enemy_index(enemy_combatant)
		enemy_panel.show_turn_indicator(enemy_index)
	
	
	# Show enemy actions in the action fields grid
	await show_enemy_actions(enemy_combatant)
	
	# Show dice hand in enemy panel
	if enemy_panel and enemy_panel.has_method("show_dice_hand"):
		enemy_panel.show_dice_hand(enemy_combatant)
	
	# Legacy: enemy hand container (if still used)
	if enemy_hand_container:
		enemy_hand_container.show()
		
		# Clear previous dice visuals
		for visual in enemy_dice_visuals:
			if is_instance_valid(visual):
				visual.queue_free()
		enemy_dice_visuals.clear()
		
		# Get dice grid in hand container
		var dice_grid = enemy_hand_container.find_child("DiceGrid", true, false)
		if dice_grid:
			for child in dice_grid.get_children():
				child.queue_free()
			
			# Add dice visuals
			var hand_dice = enemy_combatant.get_available_dice()
			for die in hand_dice:
				var visual: Control = null
				if die.has_method("instantiate_combat_visual"):
					visual = die.instantiate_combat_visual()
					if visual:
						visual.draggable = false
						visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
				if visual:
					dice_grid.add_child(visual)
					enemy_dice_visuals.append(visual)



func _on_roll_pressed():
	"""Roll button pressed — relay to CombatManager"""
	var combat_manager = get_tree().get_first_node_in_group("combat_manager")
	if combat_manager and combat_manager.has_method("_on_roll_pressed"):
		combat_manager._on_roll_pressed()


func _apply_combat_charge_state():
	"""Apply per-combat charge usage from the tracker to current action fields.
	Prevents charge reset exploits from re-equipping items mid-combat."""
	var combat_manager = get_tree().get_first_node_in_group("combat_manager")
	if not combat_manager:
		return

	for field in action_fields:
		if not is_instance_valid(field) or not field.action_resource:
			continue
		if field.action_resource.charge_type != Action.ChargeType.LIMITED_PER_COMBAT:
			continue

		var used = combat_manager.get_charges_used(field.action_resource)
		if used > 0:
			# Reset to max first (configure_from_dict already called reset_charges_for_combat)
			# Then burn the tracked charges
			for i in range(used):
				field.action_resource.consume_charge()
			field.refresh_charge_state()
			print("🔋 Applied %d spent charges to %s" % [used, field.action_resource.action_name])

func hide_enemy_hand():
	"""Hide enemy hand display and restore player UI"""
	current_enemy_display = null
	
	# Hide turn indicator
	if enemy_panel:
		enemy_panel.hide_all_turn_indicators()
	
	
	# Hide enemy panel dice hand
	if enemy_panel and enemy_panel.has_method("hide_dice_hand"):
		enemy_panel.hide_dice_hand()
	
	# Legacy hand container
	if enemy_hand_container:
		enemy_hand_container.hide()
	
	for visual in enemy_dice_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	enemy_dice_visuals.clear()
	
	# Clean up temp animation visuals
	for visual in temp_animation_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	temp_animation_visuals.clear()
	
	# Clear enemy turn display
	clear_enemy_turn_display()

func refresh_enemy_hand(enemy_combatant: Combatant):
	"""Refresh enemy hand after dice used"""
	if current_enemy_display == enemy_combatant:
		# Refresh dice hand in enemy panel
		if enemy_panel and enemy_panel.has_method("refresh_dice_hand"):
			enemy_panel.refresh_dice_hand()

func show_enemy_action(enemy_combatant: Combatant, action: Dictionary):
	"""Show what action enemy is using"""
	var action_name = action.get("name", "Attack")
	
	if enemy_action_label:
		enemy_action_label.text = "%s uses %s!" % [
			enemy_combatant.combatant_name,
			action_name
		]
	
	# Also show in enemy panel
	if enemy_panel and enemy_panel.has_method("show_current_action"):
		enemy_panel.show_current_action(action_name)

func animate_enemy_die_placement(_enemy_combatant: Combatant, _die: DieResource, die_index: int):
	"""Animate a die being consumed (legacy method)"""
	if die_index >= enemy_dice_visuals.size():
		await get_tree().create_timer(0.4).timeout
		return
	
	var visual = enemy_dice_visuals[die_index]
	
	if not is_instance_valid(visual):
		await get_tree().create_timer(0.4).timeout
		return
	
	# Flash
	var flash_tween = create_tween()
	flash_tween.tween_property(visual, "modulate", Color(1.5, 1.5, 0.5), 0.15)
	flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.15)
	await flash_tween.finished
	
	# Fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	tween.tween_property(visual, "scale", Vector2(0.5, 0.5), 0.3)
	
	await tween.finished


func _find_pool_dice_grid():
	"""Try to find the BottomUI's DiceGrid for pool die source positions.
	Returns null if not found (animator will use fallback bottom-center).
	"""
	# Try via group
	var bottom_ui = get_tree().get_first_node_in_group("bottom_ui")
	if bottom_ui and "dice_grid" in bottom_ui:
		return bottom_ui.dice_grid

	# Fallback: search parent's children
	var parent = get_parent()
	if parent:
		var bottom = parent.find_child("BottomUIPanel", true, false)
		if bottom and "dice_grid" in bottom:
			return bottom.dice_grid

	return null


func play_roll_animation() -> void:
	"""Play the dice roll entrance animation.
	Called by CombatManager at the start of each player turn, AFTER roll_hand()
	and DicePoolDisplay.refresh() have run.
	Awaitable — returns when the full animation sequence is complete.
	"""
	if roll_animator:
		print("🎮 CombatUI: Playing roll animation via CombatRollAnimator")
		# Set the flag so DicePoolDisplay knows dice should start hidden
		if dice_pool_display and "hide_for_roll_animation" in dice_pool_display:
			dice_pool_display.hide_for_roll_animation = true
		roll_animator.play_roll_sequence()
		await roll_animator.roll_animation_complete
	else:
		# Fallback: just make everything visible immediately
		push_warning("CombatUI: No roll_animator — showing dice immediately")
		if dice_pool_display:
			for visual in dice_pool_display.die_visuals:
				if is_instance_valid(visual):
					visual.modulate = Color.WHITE
					if "draggable" in visual:
						visual.draggable = true
			if "hide_for_roll_animation" in dice_pool_display:
				dice_pool_display.hide_for_roll_animation = false



func add_temp_action_field(action: Action, duration: int) -> void:
	var field = action_field_scene.instantiate() as ActionField
	field.configure_from_action(action)
	action_fields_grid.add_child(field)
	action_fields.append(field)
	temp_action_fields.append({"field": field, "turns_remaining": duration})
	field.action_selected.connect(_on_action_field_selected)
	field.dice_returned.connect(_on_dice_returned)
	field.die_placed.connect(_on_die_placed)
	field.dice_return_complete.connect(_on_dice_return_complete)

func tick_temp_action_fields() -> void:
	var expired: Array[Dictionary] = []
	for entry in temp_action_fields:
		entry.turns_remaining -= 1
		if entry.turns_remaining <= 0:
			expired.append(entry)
	for entry in expired:
		temp_action_fields.erase(entry)
		action_fields.erase(entry.field)
		if is_instance_valid(entry.field):
			entry.field.queue_free()


func _mf_name(mf: int) -> String:
	"""Convert mouse_filter int to readable name for debug logging"""
	match mf:
		Control.MOUSE_FILTER_STOP: return "STOP"
		Control.MOUSE_FILTER_PASS: return "PASS"
		Control.MOUSE_FILTER_IGNORE: return "IGNORE"
		_: return "UNKNOWN(%d)" % mf

func on_enemy_died(enemy_index: int):
	"""Handle enemy death"""
	if enemy_panel:
		enemy_panel.on_enemy_died(enemy_index)
