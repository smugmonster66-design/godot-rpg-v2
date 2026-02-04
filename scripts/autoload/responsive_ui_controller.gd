# responsive_ui_controller.gd
# AutoLoad singleton - manages responsive layout across entire game
extends Node

# Screen size categories
enum ScreenSize {
	PHONE_PORTRAIT,   # < 600px width
	PHONE_LANDSCAPE,  # < 600px height, > 600px width  
	TABLET_PORTRAIT,  # 600-900px width
	TABLET_LANDSCAPE, # 600-900px height, > 900px width
	DESKTOP           # > 900px width
}

# Current detected screen size
var current_size: ScreenSize = ScreenSize.PHONE_PORTRAIT

# Emitted whenever screen size category changes
signal screen_size_changed(new_size: ScreenSize)

# Configuration
var debug_mode: bool = true

func _ready():
	print("📱 Responsive UI Controller initialized")
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Do initial detection
	_on_viewport_size_changed()

func _on_viewport_size_changed():
	"""Called whenever the window/screen size changes"""
	var viewport_size = get_viewport().get_visible_rect().size
	var min_dimension = min(viewport_size.x, viewport_size.y)
	var max_dimension = max(viewport_size.x, viewport_size.y)
	var old_size = current_size
	
	# Determine screen size category
	if max_dimension < 600:
		# Phone
		current_size = ScreenSize.PHONE_PORTRAIT if viewport_size.x < viewport_size.y else ScreenSize.PHONE_LANDSCAPE
	elif min_dimension < 900:
		# Tablet
		current_size = ScreenSize.TABLET_PORTRAIT if viewport_size.x < viewport_size.y else ScreenSize.TABLET_LANDSCAPE
	else:
		# Desktop
		current_size = ScreenSize.DESKTOP
	
	# Log if changed
	if old_size != current_size and debug_mode:
		print("📱 Screen size changed: %s → %s (viewport: %v)" % [
			get_size_name(old_size),
			get_size_name(current_size),
			viewport_size
		])
	
	# Emit signal for other systems to react
	if old_size != current_size:
		screen_size_changed.emit(current_size)

func get_size_name(size: ScreenSize) -> String:
	"""Get human-readable name for screen size"""
	match size:
		ScreenSize.PHONE_PORTRAIT: return "Phone Portrait"
		ScreenSize.PHONE_LANDSCAPE: return "Phone Landscape"
		ScreenSize.TABLET_PORTRAIT: return "Tablet Portrait"
		ScreenSize.TABLET_LANDSCAPE: return "Tablet Landscape"
		ScreenSize.DESKTOP: return "Desktop"
		_: return "Unknown"

func is_mobile() -> bool:
	"""Quick check if on phone or tablet"""
	return current_size < ScreenSize.DESKTOP

func is_phone() -> bool:
	"""Quick check if on phone"""
	return current_size == ScreenSize.PHONE_PORTRAIT or current_size == ScreenSize.PHONE_LANDSCAPE

func is_tablet() -> bool:
	"""Quick check if on tablet"""
	return current_size == ScreenSize.TABLET_PORTRAIT or current_size == ScreenSize.TABLET_LANDSCAPE

func get_recommended_grid_columns() -> int:
	"""Get recommended number of grid columns for current screen"""
	match current_size:
		ScreenSize.PHONE_PORTRAIT: return 3
		ScreenSize.PHONE_LANDSCAPE: return 5
		ScreenSize.TABLET_PORTRAIT: return 4
		ScreenSize.TABLET_LANDSCAPE: return 6
		ScreenSize.DESKTOP: return 8
		_: return 4

func get_recommended_touch_size() -> float:
	"""Get recommended minimum touch target size (in pixels)"""
	# iOS/Android recommend 44dp minimum
	# At 3x scale (common for phones), that's 132px
	return 132.0 if is_mobile() else 100.0

# For testing in editor
func _input(event):
	if OS.is_debug_build() and event is InputEventKey:
		if event.pressed and event.keycode == KEY_F11:
			# Toggle debug info
			debug_mode = !debug_mode
			print("📱 Debug mode: %s" % ("ON" if debug_mode else "OFF"))
