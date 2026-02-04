# icon_button.gd
# Reusable icon button with touch feedback and optional label
extends TextureButton
class_name IconButton

# ============================================================================
# EXPORTS - Configure in Inspector
# ============================================================================

@export_group("Icon Textures")
@export var icon_normal: Texture2D:
	set(value):
		icon_normal = value
		if is_node_ready():
			texture_normal = value

@export var icon_pressed: Texture2D:
	set(value):
		icon_pressed = value
		if is_node_ready():
			texture_pressed = value if value else icon_normal

@export var icon_disabled: Texture2D:
	set(value):
		icon_disabled = value
		if is_node_ready():
			texture_disabled = value if value else icon_normal

@export_group("Label")
@export var label_text: String = "":
	set(value):
		label_text = value
		if label and is_node_ready():
			label.text = value

@export var show_label: bool = true:
	set(value):
		show_label = value
		if label and is_node_ready():
			label.visible = value

@export var label_position: LabelPosition = LabelPosition.BOTTOM

@export_group("Appearance")
@export var button_size: Vector2 = Vector2(64, 64):
	set(value):
		button_size = value
		custom_minimum_size = value

# ============================================================================
# LABEL POSITION ENUM
# ============================================================================

enum LabelPosition {
	BOTTOM,
	TOP,
	RIGHT,
	LEFT
}

# ============================================================================
# INTERNAL STATE
# ============================================================================

var label: Label
var is_active: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Apply textures
	texture_normal = icon_normal
	texture_pressed = icon_pressed if icon_pressed else icon_normal
	texture_disabled = icon_disabled if icon_disabled else icon_normal
	
	# Set size
	custom_minimum_size = button_size
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	
	# Create label if needed
	if show_label and label_text != "":
		create_label()
	
	# Connect signals for touch feedback
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	print("IconButton ready: %s" % label_text)

# ============================================================================
# LABEL CREATION
# ============================================================================

func create_label():
	"""Create and position label relative to button"""
	label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block button clicks
	
	# Position based on label_position
	match label_position:
		LabelPosition.BOTTOM:
			_create_label_bottom()
		LabelPosition.TOP:
			_create_label_top()
		LabelPosition.RIGHT:
			_create_label_right()
		LabelPosition.LEFT:
			_create_label_left()

func _create_label_bottom():
	"""Label below button"""
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Reparent button into vbox
	var parent = get_parent()
	var index = get_index() if parent else 0
	
	if parent:
		# SAFE reparent: remove then re-add
		parent.remove_child(self)
		parent.add_child(vbox)
		parent.move_child(vbox, index)
		vbox.add_child(self)
	
	# Add label after button
	vbox.add_child(label)

func _create_label_top():
	"""Label above button"""
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var parent = get_parent()
	var index = get_index()
	reparent(vbox)
	
	# Add label before button
	vbox.add_child(label)
	vbox.move_child(label, 0)
	
	parent.add_child(vbox)
	parent.move_child(vbox, index)

func _create_label_right():
	"""Label to the right of button"""
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var parent = get_parent()
	var index = get_index()
	reparent(hbox)
	
	hbox.add_child(label)
	
	parent.add_child(hbox)
	parent.move_child(hbox, index)

func _create_label_left():
	"""Label to the left of button"""
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var parent = get_parent()
	var index = get_index()
	reparent(hbox)
	
	hbox.add_child(label)
	hbox.move_child(label, 0)
	
	parent.add_child(hbox)
	parent.move_child(hbox, index)

# ============================================================================
# VISUAL FEEDBACK
# ============================================================================

func _on_button_down():
	"""Visual feedback when button is pressed"""
	# Scale down slightly
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)

func _on_button_up():
	"""Visual feedback when button is released"""
	# Scale back to normal
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func _on_mouse_entered():
	"""Subtle hover effect (PC only)"""
	if not ResponsiveUI.is_mobile():
		modulate = Color(1.2, 1.2, 1.2, 1.0)

func _on_mouse_exited():
	"""Remove hover effect"""
	if not is_active:
		modulate = Color.WHITE

# ============================================================================
# PUBLIC API
# ============================================================================

func set_active(active: bool):
	"""Mark this button as active/selected with visual styling"""
	is_active = active
	
	if active:
		# ACTIVE STATE - Bright and highlighted
		var active_style = StyleBoxFlat.new()
		active_style.bg_color = Color(0.35, 0.4, 0.5, 1.0)  # Bright background
		active_style.border_width_left = 3
		active_style.border_width_right = 3
		active_style.border_width_top = 3
		active_style.border_width_bottom = 3
		active_style.border_color = Color(0.6, 0.7, 0.9, 1.0)  # Bright blue border
		active_style.corner_radius_top_left = 6
		active_style.corner_radius_top_right = 6
		active_style.corner_radius_bottom_left = 6
		active_style.corner_radius_bottom_right = 6
		
		add_theme_stylebox_override("normal", active_style)
		add_theme_stylebox_override("hover", active_style)  # Stay bright on hover
		
		# Brighten the icon
		modulate = Color(1.0, 1.0, 1.0, 1.0)  # Full brightness
		
		# Brighten label
		if label:
			label.add_theme_color_override("font_color", Color.WHITE)
	else:
		# INACTIVE STATE - Dimmed/darkened
		var inactive_style = StyleBoxFlat.new()
		inactive_style.bg_color = Color(0.15, 0.15, 0.2, 0.7)  # Dark, semi-transparent
		inactive_style.border_width_left = 2
		inactive_style.border_width_right = 2
		inactive_style.border_width_top = 2
		inactive_style.border_width_bottom = 2
		inactive_style.border_color = Color(0.3, 0.3, 0.4, 1.0)  # Dim border
		inactive_style.corner_radius_top_left = 6
		inactive_style.corner_radius_top_right = 6
		inactive_style.corner_radius_bottom_left = 6
		inactive_style.corner_radius_bottom_right = 6
		
		add_theme_stylebox_override("normal", inactive_style)
		
		# Hover state for inactive buttons
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
		hover_style.border_width_left = 2
		hover_style.border_width_right = 2
		hover_style.border_width_top = 2
		hover_style.border_width_bottom = 2
		hover_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
		hover_style.corner_radius_top_left = 6
		hover_style.corner_radius_top_right = 6
		hover_style.corner_radius_bottom_left = 6
		hover_style.corner_radius_bottom_right = 6
		add_theme_stylebox_override("hover", hover_style)
		
		# Dim the icon
		modulate = Color(0.6, 0.6, 0.6, 1.0)  # 60% brightness
		
		# Dim label
		if label:
			label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func set_icon(normal: Texture2D, pressed: Texture2D = null, disabled_tex: Texture2D = null):
	"""Change the button icon at runtime"""
	icon_normal = normal
	icon_pressed = pressed if pressed else normal
	icon_disabled = disabled_tex if disabled_tex else normal
	
	texture_normal = icon_normal
	texture_pressed = icon_pressed
	texture_disabled = icon_disabled
