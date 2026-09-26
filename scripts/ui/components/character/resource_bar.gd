# resource_bar.gd - Reusable progress bar with label overlay
# Used for HP, Mana, XP, companion HP bars
extends Control

const BAR_HEIGHT := 40
const BAR_CORNER_RADIUS := 6

var bar: ProgressBar
var overlay_label: Label

var _fill_color: Color = Color.WHITE
var _low_color: Color = Color.WHITE
var _has_low_color: bool = false

func _ready():
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_discover_nodes()

func _discover_nodes():
	for child in find_children("*", "", true, false):
		if not child.is_in_group("resource_bar_ui"):
			continue
		match child.get_meta("ui_role", ""):
			"bar": bar = child
			"overlay": overlay_label = child

func set_values(bar_label: String, current: int, maximum: int, fill_color: Color, low_color = null):
	_fill_color = fill_color
	_has_low_color = low_color != null
	if _has_low_color:
		_low_color = low_color
	update_values(current, maximum, bar_label)

func update_values(current: int, maximum: int, bar_label: String = ""):
	if not bar:
		return

	bar.min_value = 0
	bar.max_value = maximum if maximum > 0 else 1
	bar.value = current
	bar.show_percentage = false

	var pct: float = float(current) / float(maximum) if maximum > 0 else 0.0
	var active_color = _fill_color
	if _has_low_color and pct < 0.25:
		active_color = _low_color

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = active_color
	fill_style.set_corner_radius_all(BAR_CORNER_RADIUS)
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = ThemeManager.PALETTE.bg_dark
	bg_style.set_corner_radius_all(BAR_CORNER_RADIUS)
	bg_style.border_color = ThemeManager.PALETTE.border_subtle
	bg_style.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg_style)

	if overlay_label:
		if bar_label != "":
			overlay_label.text = "%s: %d / %d" % [bar_label, current, maximum]
		else:
			overlay_label.text = "%d / %d" % [current, maximum]
