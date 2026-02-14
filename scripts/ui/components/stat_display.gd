# stat_display.gd - HP/Mana bar display
extends HBoxContainer

# ============================================================================
# NODE REFERENCES (created dynamically)
# ============================================================================
var name_label: Label
var bar: ProgressBar
var value_label: Label

# ============================================================================
# STATE
# ============================================================================
var current_value: int = 0
var max_value: int = 100
var display_name: String = "HP"
var bar_color: Color = Color(0.20, 0.75, 0.25)  # ThemeManager.PALETTE.health

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	create_ui()

func create_ui():
	"""Create UI elements"""
	# Name label
	name_label = Label.new()
	name_label.custom_minimum_size = Vector2(80, 0)
	add_child(name_label)
	
	# Progress bar
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 30)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(bar)
	
	# Value label
	value_label = Label.new()
	value_label.custom_minimum_size = Vector2(80, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(value_label)

func initialize(p_name: String, p_current: int, p_max: int, p_color: Color):
	"""Initialize display"""
	display_name = p_name
	current_value = p_current
	max_value = p_max
	bar_color = p_color
	
	update_display()

# ============================================================================
# PUBLIC API
# ============================================================================

func update_values(new_current: int, new_max: int):
	"""Update values"""
	current_value = new_current
	max_value = new_max
	update_display()

func update_display():
	"""Update visual display"""
	if name_label:
		name_label.text = "%s:" % display_name
	
	if bar:
		bar.max_value = max_value
		bar.value = current_value
		
		# Color based on percentage
		var percent = float(current_value) / float(max_value) if max_value > 0 else 0
		if percent > 0.5:
			bar.modulate = bar_color
		elif percent > 0.25:
			bar.modulate = ThemeManager.PALETTE.warning
		else:
			bar.modulate = ThemeManager.PALETTE.health_low
	
	if value_label:
		value_label.text = "%d / %d" % [current_value, max_value]
