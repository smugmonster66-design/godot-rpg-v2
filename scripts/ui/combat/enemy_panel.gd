# res://scripts/ui/combat/enemy_panel.gd
# Enemy panel with slots and dice hand display for enemy turns
extends VBoxContainer
class_name EnemyPanel

# ============================================================================
# SIGNALS
# ============================================================================
signal enemy_selected(enemy: Combatant, slot_index: int)
signal selection_changed(slot_index: int)

# ============================================================================
# EXPORTS
# ============================================================================
@export var die_visual_scene: PackedScene = null
@export var die_move_duration: float = 0.4
@export var die_scale_duration: float = 0.15

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var slots_container: HBoxContainer = $SlotsContainer
@onready var dice_hand_container: PanelContainer = $EnemyDiceHand
@onready var dice_hand_grid: HBoxContainer = $EnemyDiceHand/MarginContainer/VBox/HandContainer/DiceHandGrid
@onready var action_label: Label = $EnemyDiceHand/MarginContainer/VBox/ActionLabel

# ============================================================================
# STATE
# ============================================================================
var enemy_slots: Array[EnemySlot] = []
var selected_slot_index: int = 0
var selection_enabled: bool = false

# Enemy turn state
var current_enemy: Combatant = null
var hand_dice_visuals: Array[Control] = []
var is_animating: bool = false
var hide_for_roll_animation: bool = false  



# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Load die visual scene if not set
	#if not die_visual_scene:
	#	die_visual_scene = load("res://scenes/ui/components/die_visual.tscn")
	
	_discover_slots()
	_connect_slot_signals()
	
	# Hide dice hand initially
	if dice_hand_container:
		dice_hand_container.hide()
	
	print("👹 EnemyPanel ready with %d slots" % enemy_slots.size())

func _discover_slots():
	"""Find all EnemySlot children"""
	enemy_slots.clear()
	
	if not slots_container:
		return
	
	for child in slots_container.get_children():
		if child is EnemySlot:
			child.slot_index = enemy_slots.size()
			enemy_slots.append(child)

func _connect_slot_signals():
	"""Connect signals from slots"""
	for slot in enemy_slots:
		if not slot.slot_clicked.is_connected(_on_slot_clicked):
			slot.slot_clicked.connect(_on_slot_clicked)
		if not slot.slot_hovered.is_connected(_on_slot_hovered):
			slot.slot_hovered.connect(_on_slot_hovered)

# ============================================================================
# ENEMY MANAGEMENT
# ============================================================================

func initialize_enemies(enemies: Array):
	"""Initialize slots with enemy combatants"""
	print("👹 Initializing %d enemies in panel" % enemies.size())
	
	for i in range(enemy_slots.size()):
		if i < enemies.size():
			var enemy = enemies[i]
			var enemy_data = enemy.enemy_data if enemy else null
			enemy_slots[i].set_enemy(enemy, enemy_data)
		else:
			enemy_slots[i].set_empty()
	
	# Select first living enemy
	select_first_living_enemy()

func update_enemy_health(enemy_index: int, current: int, maximum: int):
	"""Update health display for an enemy"""
	if enemy_index >= 0 and enemy_index < enemy_slots.size():
		enemy_slots[enemy_index].update_health(current, maximum)

func on_enemy_died(enemy_index: int):
	"""Handle enemy death visuals"""
	if enemy_index >= 0 and enemy_index < enemy_slots.size():
		var slot = enemy_slots[enemy_index]
		slot.set_selected(false)
		
		# If this was selected, move to next living enemy
		if enemy_index == selected_slot_index:
			select_first_living_enemy()

# ============================================================================
# SELECTION
# ============================================================================

func set_selection_enabled(enabled: bool):
	"""Enable or disable target selection"""
	selection_enabled = enabled
	
	for slot in enemy_slots:
		if enabled:
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			slot.mouse_default_cursor_shape = Control.CURSOR_ARROW

func select_slot(index: int):
	"""Select a specific slot"""
	if index < 0 or index >= enemy_slots.size():
		return
	
	var slot = enemy_slots[index]
	if slot.is_empty or not slot.is_alive():
		return
	
	# Deselect previous
	if selected_slot_index >= 0 and selected_slot_index < enemy_slots.size():
		enemy_slots[selected_slot_index].set_selected(false)
	
	# Select new
	selected_slot_index = index
	slot.set_selected(true)
	
	selection_changed.emit(index)

func select_first_living_enemy():
	"""Select the first living enemy"""
	for i in range(enemy_slots.size()):
		var slot = enemy_slots[i]
		if not slot.is_empty and slot.is_alive():
			select_slot(i)
			return
	
	selected_slot_index = -1

func get_selected_enemy() -> Combatant:
	"""Get currently selected enemy"""
	if selected_slot_index >= 0 and selected_slot_index < enemy_slots.size():
		return enemy_slots[selected_slot_index].get_enemy()
	return null

func get_selected_slot_index() -> int:
	"""Get selected slot index"""
	return selected_slot_index

# ============================================================================
# SLOT SIGNAL HANDLERS
# ============================================================================

func _on_slot_clicked(slot: EnemySlot):
	"""Handle slot click"""
	if not selection_enabled:
		return
	
	select_slot(slot.slot_index)
	
	var enemy = slot.get_enemy()
	if enemy:
		enemy_selected.emit(enemy, slot.slot_index)

func _on_slot_hovered(slot: EnemySlot):
	"""Handle slot hover"""
	pass  # Could show tooltip or preview

# ============================================================================
# ENEMY DICE HAND DISPLAY
# ============================================================================

func show_dice_hand(enemy_combatant: Combatant):
	"""Show enemy's rolled dice hand"""
	current_enemy = enemy_combatant
	
	if not dice_hand_container:
		return
	
	dice_hand_container.show()
	
	# Set label
	if action_label:
		action_label.text = "%s's Turn" % enemy_combatant.combatant_name
	
	# Clear previous dice
	_clear_hand_dice()
	
	# Add dice visuals for rolled hand
	var hand_dice = enemy_combatant.get_available_dice()
	
	for die in hand_dice:
		var visual = _create_die_visual(die)
		if visual:
			# Start invisible when roll animation is pending
			if hide_for_roll_animation:
				visual.modulate = Color(1, 1, 1, 0)
			dice_hand_grid.add_child(visual)
			hand_dice_visuals.append(visual)


func hide_dice_hand():
	"""Hide the dice hand display"""
	current_enemy = null
	
	if dice_hand_container:
		dice_hand_container.hide()
	
	_clear_hand_dice()

func refresh_dice_hand():
	"""Refresh dice hand after a die is used"""
	if current_enemy:
		show_dice_hand(current_enemy)

func get_hand_die_visual(index: int) -> Control:
	"""Get a die visual by index for animation"""
	if index >= 0 and index < hand_dice_visuals.size():
		return hand_dice_visuals[index]
	return null

# ============================================================================
# DICE ANIMATION
# ============================================================================

func animate_die_used(die_index: int) -> void:
	"""Animate a die being used (flash and fade)"""
	if die_index >= hand_dice_visuals.size():
		await get_tree().create_timer(0.1).timeout
		return
	
	is_animating = true
	
	var visual = hand_dice_visuals[die_index]
	if not is_instance_valid(visual):
		is_animating = false
		return
	
	# Flash effect
	var flash_tween = create_tween()
	flash_tween.tween_property(visual, "modulate", Color(1.5, 1.5, 0.5), die_scale_duration)
	flash_tween.tween_property(visual, "modulate", Color.WHITE, die_scale_duration)
	await flash_tween.finished
	
	# Fade out
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(visual, "modulate:a", 0.0, die_move_duration)
	fade_tween.tween_property(visual, "scale", Vector2(0.5, 0.5), die_move_duration)
	await fade_tween.finished
	
	is_animating = false

# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func show_turn_indicator(enemy_index: int):
	"""Show turn indicator for a specific enemy"""
	# Hide all first
	hide_all_turn_indicators()
	
	if enemy_index >= 0 and enemy_index < enemy_slots.size():
		var slot = enemy_slots[enemy_index]
		if slot.has_method("show_turn_indicator"):
			slot.show_turn_indicator()

func hide_turn_indicator(enemy_index: int):
	"""Hide turn indicator for a specific enemy"""
	if enemy_index >= 0 and enemy_index < enemy_slots.size():
		var slot = enemy_slots[enemy_index]
		if slot.has_method("hide_turn_indicator"):
			slot.hide_turn_indicator()

func hide_all_turn_indicators():
	"""Hide all turn indicators"""
	for slot in enemy_slots:
		if slot.has_method("hide_turn_indicator"):
			slot.hide_turn_indicator()

func get_enemy_index(enemy: Combatant) -> int:
	"""Get slot index for an enemy"""
	for i in range(enemy_slots.size()):
		if enemy_slots[i].enemy == enemy:
			return i
	return -1


func _create_die_visual(die: DieResource) -> Control:
	"""Create a die visual for the hand using new CombatDieObject system"""
	# Use the new system - same as player dice
	if die.has_method("instantiate_combat_visual"):
		var visual = die.instantiate_combat_visual()
		if visual:
			visual.draggable = false  # Enemy dice aren't draggable by player
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return visual
	
	# Fallback to old system if needed
	if die_visual_scene:
		var visual = die_visual_scene.instantiate()
		if visual.has_method("set_die"):
			visual.set_die(die)
		return visual
	
	return null


func _clear_hand_dice():
	"""Clear all dice visuals from hand"""
	for visual in hand_dice_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	hand_dice_visuals.clear()
