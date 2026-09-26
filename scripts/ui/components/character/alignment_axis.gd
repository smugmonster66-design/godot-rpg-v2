# alignment_axis.gd - Alignment axis display (-100 to +100)
# Shows a centered bar with negative/positive labels
extends VBoxContainer

const BAR_HEIGHT := 32
const BAR_CORNER_RADIUS := 4

var neg_label: Label
var pos_label: Label
var axis_bar: ProgressBar
var center_marker: ColorRect
var value_label: Label

func _ready():
	_discover_nodes()

func _discover_nodes():
	for child in find_children("*", "", true, false):
		if not child.is_in_group("alignment_axis_ui"):
			continue
		match child.get_meta("ui_role", ""):
			"neg_label": neg_label = child
			"pos_label": pos_label = child
			"axis_bar": axis_bar = child
			"center_marker": center_marker = child
			"value_label": value_label = child

func set_axis(neg_text: String, pos_text: String, value: int):
	if neg_label:
		neg_label.text = neg_text
	if pos_label:
		pos_label.text = pos_text

	if axis_bar:
		axis_bar.min_value = -100
		axis_bar.max_value = 100
		axis_bar.value = value
		axis_bar.show_percentage = false

		# Fill color based on sign
		var fill_color: Color
		if value >= 0:
			fill_color = ThemeManager.PALETTE.success
		else:
			fill_color = ThemeManager.PALETTE.danger

		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		fill_style.set_corner_radius_all(BAR_CORNER_RADIUS)
		axis_bar.add_theme_stylebox_override("fill", fill_style)

		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = ThemeManager.PALETTE.bg_dark
		bg_style.set_corner_radius_all(BAR_CORNER_RADIUS)
		bg_style.border_color = ThemeManager.PALETTE.border_subtle
		bg_style.set_border_width_all(1)
		axis_bar.add_theme_stylebox_override("background", bg_style)

	if center_marker:
		center_marker.color = ThemeManager.PALETTE.text_secondary

	if value_label:
		value_label.text = str(value)
		if value > 0:
			value_label.add_theme_color_override("font_color", ThemeManager.PALETTE.success)
		elif value < 0:
			value_label.add_theme_color_override("font_color", ThemeManager.PALETTE.danger)
		else:
			value_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
