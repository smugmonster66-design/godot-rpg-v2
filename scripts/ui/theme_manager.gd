# theme_manager.gd
# AutoLoad singleton - manages consistent theming
extends Node

var theme: Theme

func _ready():
	print("🎨 Theme Manager initialized")
	create_theme()

func create_theme():
	"""Build the game's theme from scratch"""
	theme = Theme.new()
	
	setup_fonts()
	setup_colors()
	setup_buttons()
	setup_panels()
	setup_labels()
	
	print("🎨 Theme created")

# ============================================================================
# FONTS
# ============================================================================

func setup_fonts():
	"""Set default font and sizes"""
	# You can load a custom font here
	# For now, use engine default
	theme.default_font_size = 16
	
	# Different sizes for different contexts
	var sizes = {
		"small": 12,
		"normal": 16,
		"large": 20,
		"title": 24
	}
	
	# These can be accessed like:
	# label.add_theme_font_size_override("font_size", ThemeManager.theme.get_font_size("large", "Label"))

# ============================================================================
# COLORS
# ============================================================================

func setup_colors():
	"""Define color palette"""
	
	# Button colors
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color(1.0, 1.0, 0.8))
	theme.set_color("font_hover_color", "Button", Color(1.2, 1.2, 1.2))
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	
	# Label colors
	theme.set_color("font_color", "Label", Color.WHITE)
	
	# Different semantic colors
	var semantic_colors = {
		"primary": Color(0.3, 0.5, 0.8),    # Blue
		"secondary": Color(0.5, 0.5, 0.5),  # Gray
		"success": Color(0.3, 0.8, 0.3),    # Green
		"danger": Color(0.8, 0.3, 0.3),     # Red
		"warning": Color(0.8, 0.8, 0.3),    # Yellow
		"info": Color(0.3, 0.8, 0.8)        # Cyan
	}

# ============================================================================
# BUTTONS
# ============================================================================

func setup_buttons():
	"""Configure button appearance"""
	
	# Normal state
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.2, 0.2, 0.25)
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(0.4, 0.4, 0.5)
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_left = 4
	btn_normal.corner_radius_bottom_right = 4
	theme.set_stylebox("normal", "Button", btn_normal)
	
	# Pressed state
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.3, 0.3, 0.35)
	btn_pressed.border_width_left = 2
	btn_pressed.border_width_right = 2
	btn_pressed.border_width_top = 2
	btn_pressed.border_width_bottom = 2
	btn_pressed.border_color = Color(0.5, 0.5, 0.6)
	btn_pressed.corner_radius_top_left = 4
	btn_pressed.corner_radius_top_right = 4
	btn_pressed.corner_radius_bottom_left = 4
	btn_pressed.corner_radius_bottom_right = 4
	btn_pressed.content_margin_top = 2  # Offset for "pressed" look
	theme.set_stylebox("pressed", "Button", btn_pressed)
	
	# Hover state
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.25, 0.3)
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.border_color = Color(0.6, 0.6, 0.7)
	btn_hover.corner_radius_top_left = 4
	btn_hover.corner_radius_top_right = 4
	btn_hover.corner_radius_bottom_left = 4
	btn_hover.corner_radius_bottom_right = 4
	theme.set_stylebox("hover", "Button", btn_hover)
	
	# Disabled state
	var btn_disabled = StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.15, 0.15, 0.15)
	btn_disabled.border_width_left = 2
	btn_disabled.border_width_right = 2
	btn_disabled.border_width_top = 2
	btn_disabled.border_width_bottom = 2
	btn_disabled.border_color = Color(0.3, 0.3, 0.3)
	btn_disabled.corner_radius_top_left = 4
	btn_disabled.corner_radius_top_right = 4
	btn_disabled.corner_radius_bottom_left = 4
	btn_disabled.corner_radius_bottom_right = 4
	theme.set_stylebox("disabled", "Button", btn_disabled)

# ============================================================================
# PANELS
# ============================================================================

func setup_panels():
	"""Configure panel appearance"""
	
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	panel.border_width_left = 2
	panel.border_width_right = 2
	panel.border_width_top = 2
	panel.border_width_bottom = 2
	panel.border_color = Color(0.3, 0.3, 0.4)
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	theme.set_stylebox("panel", "PanelContainer", panel)

# ============================================================================
# LABELS
# ============================================================================

func setup_labels():
	"""Configure label appearance"""
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func get_semantic_color(type: String) -> Color:
	"""Get a color by semantic meaning"""
	match type:
		"primary": return Color(0.3, 0.5, 0.8)
		"secondary": return Color(0.5, 0.5, 0.5)
		"success": return Color(0.3, 0.8, 0.3)
		"danger": return Color(0.8, 0.3, 0.3)
		"warning": return Color(0.8, 0.8, 0.3)
		"info": return Color(0.3, 0.8, 0.8)
		_: return Color.WHITE

func apply_theme_to_control(control: Control):
	"""Apply the theme to a specific control"""
	control.theme = theme
