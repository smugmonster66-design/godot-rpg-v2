# res://scripts/ui/combat/enemy_slot.gd
# Individual enemy slot with dice pool display - uses scene nodes
extends PanelContainer
class_name EnemySlot

# ============================================================================
# SIGNALS
# ============================================================================
signal slot_clicked(slot: EnemySlot)
signal slot_hovered(slot: EnemySlot)
signal slot_unhovered(slot: EnemySlot)

# ============================================================================
# EXPORTS
# ============================================================================
@export var slot_index: int = 0
@export var default_portrait: Texture2D = null
@export var die_icon_size: Vector2 = Vector2(24, 24)

@export var portrait_size: Vector2 = Vector2(180, 180)
@export var health_overlap: float = 16.0

@export_group("Colors")
## When true, uses the exported colors below. When false, falls back to ThemeManager PALETTE.
@export var use_custom_slot_colors: bool = true
@export var empty_slot_color: Color = Color(0.2, 0.2, 0.2, 0.5)
@export var filled_slot_color: Color = Color(0.3, 0.2, 0.2, 0.9)
@export var selected_slot_color: Color = Color(0.5, 0.4, 0.2, 0.95)
@export var dead_slot_color: Color = Color(0.15, 0.1, 0.1, 0.8)
# NOTE: These are enemy-specific tints (red-shifted), intentionally different
# from generic PALETTE values. Keep as exports for designer tuning.

# ============================================================================
# NODE REFERENCES - Found from scene
# ============================================================================
@onready var dice_pool_bar: HBoxContainer = $MarginContainer/VBox/DicePoolBar
@onready var name_label: Label = $MarginContainer/VBox/PortraitSection/NameLabel
@onready var health_label: Label = $MarginContainer/VBox/HealthLabel
#@onready var turn_indicator: ColorRect = $MarginContainer/VBox/TurnIndicatorRect

@onready var portrait_rect: TextureRect = $MarginContainer/VBox/PortraitSection/Portrait
@onready var selection_indicator: Panel = $MarginContainer/VBox/PortraitSection/Portrait/SelectionIndicator
@onready var health_bar: TextureProgressBar = $MarginContainer/VBox/PortraitSection/HealthBar


# ============================================================================
# STATE
# ============================================================================
var enemy: Combatant = null
var enemy_data: EnemyData = null
var is_selected: bool = false
var is_empty: bool = true
var style_box: StyleBoxFlat = null
var dice_icons: Array[Control] = []
var turn_indicator_material: ShaderMaterial = null
var turn_indicator: Control = null
var status_display: StatusEffectDisplay = null

func _slot_color(custom: Color, palette_fallback: Color) -> Color:
	return custom if use_custom_slot_colors else palette_fallback
# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_setup_style()
	turn_indicator = find_child("TurnIndicatorRect", true, false)
	var portrait_section = $MarginContainer/VBox/PortraitSection
	portrait_section.custom_minimum_size = Vector2(portrait_size.x, portrait_size.y + health_overlap)
	portrait_rect.custom_minimum_size = portrait_size
	
	if health_bar:
		health_bar.offset_left = -portrait_size.x / 2.0
		health_bar.offset_right = portrait_size.x / 2.0
	
	_setup_turn_indicator()
	_connect_signals()
	set_empty()
	_create_status_display()


func _create_status_display():
	"""Create the status effect icon strip below the health bar."""
	var vbox = $MarginContainer/VBox
	if not vbox:
		return
	status_display = StatusEffectDisplay.new()
	status_display.name = "StatusDisplay"
	status_display.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(status_display)
	
	# Let input flow through to status icons
	$MarginContainer.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS


func _setup_style():
	style_box = ThemeManager._flat_box(
		_slot_color(empty_slot_color, ThemeManager.PALETTE.bg_panel),
		ThemeManager.PALETTE.border_subtle, 8, 2)
	#add_theme_stylebox_override("panel", style_box)

func _connect_signals():
	"""Connect input signals"""
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

# Add new function
func _setup_turn_indicator():
	# Find or create the node
	if not turn_indicator:
		turn_indicator = ColorRect.new()
		turn_indicator.name = "TurnIndicatorRect"
		turn_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		turn_indicator.visible = false
		turn_indicator.color = Color.WHITE
		
		portrait_rect.add_child(turn_indicator)
		portrait_rect.move_child(turn_indicator, 0)
		
		turn_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
		turn_indicator.offset_left = -8
		turn_indicator.offset_top = -8
		turn_indicator.offset_right = 8
		turn_indicator.offset_bottom = 8
	
	# ALWAYS apply material (even if node existed)
	var shader_path = "res://resources/materials/turn_indicator_material.tres"
	if ResourceLoader.exists(shader_path):
		var base_material = load(shader_path) as ShaderMaterial
		if base_material:
			turn_indicator_material = base_material.duplicate()
			turn_indicator.material = turn_indicator_material
			print("✅ Turn indicator material applied")
		else:
			print("❌ Failed to load as ShaderMaterial")
	else:
		print("❌ Shader path doesn't exist: ", shader_path)
	print("Turn indicator created: ", turn_indicator)
	print("  Parent: ", turn_indicator.get_parent())
	print("  Material: ", turn_indicator.material)
	print("  Visible: ", turn_indicator.visible)

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func set_enemy(p_enemy: Combatant, p_enemy_data: EnemyData = null):
	"""Set the enemy for this slot"""
	enemy = p_enemy
	enemy_data = p_enemy_data
	is_empty = false
	
	_update_display()
	_update_dice_pool_display()
	
	# Connect to enemy signals
	if enemy:
		if enemy.has_signal("health_changed") and not enemy.health_changed.is_connected(_on_enemy_health_changed):
			enemy.health_changed.connect(_on_enemy_health_changed)
		if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)

func set_empty():
	"""Set slot to empty state"""
	enemy = null
	enemy_data = null
	is_empty = true
	is_selected = false
	
	if portrait_rect:
		portrait_rect.texture = default_portrait
		portrait_rect.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	if name_label:
		name_label.text = "Empty"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	
	if health_bar:
		health_bar.hide()
	
	if health_label:
		health_label.text = ""
	
	if dice_pool_bar:
		_clear_dice_icons()
		dice_pool_bar.hide()
	
	if style_box:
		style_box.bg_color = _slot_color(empty_slot_color, ThemeManager.PALETTE.bg_panel)
		style_box.border_color = ThemeManager.PALETTE.border_subtle
	
	if selection_indicator:
		selection_indicator.hide()
		
		
		
	
	
	if status_display:
		status_display.disconnect_tracker()

func set_selected(selected: bool):
	"""Set selection state"""
	is_selected = selected
	
	if selection_indicator:
		selection_indicator.visible = selected and not is_empty and is_alive()
	
	if style_box:
		if selected and not is_empty and is_alive():
			style_box.bg_color = _slot_color(selected_slot_color, ThemeManager.PALETTE.bg_elevated)
			style_box.border_color = ThemeManager.PALETTE.maxed
		elif not is_empty and is_alive():
			style_box.bg_color = _slot_color(filled_slot_color, ThemeManager.PALETTE.bg_hover)
			style_box.border_color = ThemeManager.PALETTE.danger

func update_health(current: int, maximum: int):
	"""Update health display"""
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
	
	if health_label:
		health_label.text = "%d / %d" % [current, maximum]

func refresh_dice_display():
	"""Refresh the dice pool icons"""
	_update_dice_pool_display()

func get_enemy() -> Combatant:
	"""Get the enemy in this slot"""
	return enemy




func is_alive() -> bool:
	"""Check if enemy is alive"""
	return enemy != null and enemy.is_alive()

# Add public methods
func show_turn_indicator():
	print("show_turn_indicator called")
	print("  turn_indicator: ", turn_indicator)
	"""Show the turn indicator for this enemy's turn"""
	if turn_indicator:
		print("  material: ", turn_indicator.material)
		# Check if we have a portrait
		var has_portrait = portrait_rect and portrait_rect.texture != null
		if turn_indicator_material:
			turn_indicator_material.set_shader_parameter("is_circle", not has_portrait)
		turn_indicator.visible = true

func hide_turn_indicator():
	"""Hide the turn indicator"""
	if turn_indicator:
		turn_indicator.visible = false

func set_turn_indicator_color(color: Color):
	"""Change the turn indicator color"""
	if turn_indicator_material:
		turn_indicator_material.set_shader_parameter("glow_color", color)


# ============================================================================
# DICE POOL DISPLAY
# ============================================================================

func _update_dice_pool_display():
	"""Update the dice pool bar with enemy's dice icons"""
	if not dice_pool_bar:
		return
	
	_clear_dice_icons()
	
	if not enemy or not enemy.dice_collection:
		dice_pool_bar.hide()
		return
	
	dice_pool_bar.show()
	
	# Get all dice in pool
	var pool_dice = enemy.dice_collection.get_all_dice()
	
	for die in pool_dice:
		var icon = _create_die_icon(die)
		dice_pool_bar.add_child(icon)
		
		# Force small size AFTER adding to tree (scale only affects visuals, not layout)
		if icon.has_method("set_display_scale"):
			var scaled_size = Vector2(31, 31)  # 124 * 0.25
			icon.custom_minimum_size = scaled_size
			icon.size = scaled_size
		
		dice_icons.append(icon)


func _create_die_icon(die: DieResource) -> Control:
	"""Create a small icon for a die using the proper visual system"""
	# Use the new pool visual system
	if die.has_method("instantiate_pool_visual"):
		var visual = die.instantiate_pool_visual()
		if visual:
			visual.draggable = false
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			visual.set_display_scale(0.25)  # 1/4 size for pool icons
			
			# Hide the value label for pool icons
			var label = visual.find_child("ValueLabel", true, false)
			if label:
				label.hide()
			
			visual.tooltip_text = "%s (D%d)" % [die.display_name, die.die_type]
			return visual
	
	# Fallback to simple TextureRect
	var icon = TextureRect.new()
	icon.custom_minimum_size = die_icon_size
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if die.fill_texture:
		icon.texture = die.fill_texture
	elif die.icon:
		icon.texture = die.icon
	
	if die.color != Color.WHITE:
		icon.modulate = die.color
	else:
		icon.modulate = _get_die_size_color(die.die_type)
	
	icon.tooltip_text = "%s (D%d)" % [die.display_name, die.die_type]
	return icon


func _get_die_size_color(die_type: DieResource.DieType) -> Color:
	"""Get color based on die size"""
	match die_type:
		DieResource.DieType.D4:
			return Color(0.7, 0.7, 0.7)  # Gray
		DieResource.DieType.D6:
			return Color(0.9, 0.9, 0.9)  # White
		DieResource.DieType.D8:
			return Color(0.6, 0.8, 0.6)  # Light green
		DieResource.DieType.D10:
			return Color(0.6, 0.6, 0.9)  # Light blue
		DieResource.DieType.D12:
			return Color(0.9, 0.7, 0.5)  # Orange
		DieResource.DieType.D20:
			return Color(0.9, 0.6, 0.9)  # Pink/purple
		_:
			return Color.WHITE

func _clear_dice_icons():
	"""Clear all dice icons"""
	for icon in dice_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	dice_icons.clear()

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _update_display():
	"""Update all display elements"""
	if not enemy:
		set_empty()
		return
	
	# Portrait
	if portrait_rect:
		if enemy_data and enemy_data.portrait:
			portrait_rect.texture = enemy_data.portrait
		elif enemy.enemy_data and enemy.enemy_data.portrait:
			portrait_rect.texture = enemy.enemy_data.portrait
		elif default_portrait:
			portrait_rect.texture = default_portrait
		portrait_rect.modulate = Color.WHITE
	
	# Name
	if name_label:
		name_label.text = enemy.combatant_name
		name_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_primary)
	
	# Health
	if health_bar:
		health_bar.show()
		health_bar.max_value = enemy.max_health
		health_bar.value = enemy.current_health
	
	if health_label:
		health_label.text = "%d / %d" % [enemy.current_health, enemy.max_health]
	
	# Style
	if style_box:
		style_box.bg_color = _slot_color(filled_slot_color, ThemeManager.PALETTE.bg_hover)
		style_box.border_color = ThemeManager.PALETTE.danger
		
	
	
	# Status effects
	if status_display and enemy and enemy.has_node("StatusTracker"):
		var tracker: StatusTracker = enemy.get_node("StatusTracker")
		status_display.connect_tracker(tracker)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_gui_input(event: InputEvent):
	"""Handle input on the slot"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not is_empty and is_alive():
				slot_clicked.emit(self)

func _on_mouse_entered():
	"""Handle mouse enter"""
	if not is_empty and is_alive():
		slot_hovered.emit(self)
		if style_box and not is_selected:
			style_box.border_color = ThemeManager.PALETTE.warning

func _on_mouse_exited():
	"""Handle mouse exit"""
	if not is_empty:
		slot_unhovered.emit(self)
		if style_box and not is_selected:
			if is_alive():
				style_box.border_color = ThemeManager.PALETTE.danger
			else:
				style_box.border_color = Color(ThemeManager.PALETTE.danger.darkened(0.5))

func _on_enemy_health_changed(current: int, maximum: int):
	"""Handle enemy health change"""
	update_health(current, maximum)

func _on_enemy_died():
	"""Handle enemy death"""
	if portrait_rect:
		portrait_rect.modulate = Color(0.3, 0.3, 0.3, 0.7)
	
	if name_label:
		name_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
	
	if style_box:
		style_box.bg_color = _slot_color(dead_slot_color, ThemeManager.PALETTE.bg_darkest)
		style_box.border_color = Color(ThemeManager.PALETTE.danger.darkened(0.5))
	
	if selection_indicator:
		selection_indicator.hide()
		
	
	
	if status_display:
		status_display.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	if dice_pool_bar:
		dice_pool_bar.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	is_selected = false
