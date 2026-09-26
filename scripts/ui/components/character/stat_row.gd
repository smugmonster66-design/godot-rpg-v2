# stat_row.gd - Single stat display row (name + value)
extends HBoxContainer

const STAT_LABEL_MIN_WIDTH := 200

var name_label: Label
var value_label: Label

func _ready():
	_discover_nodes()

func _discover_nodes():
	for child in find_children("*", "", true, false):
		if not child.is_in_group("stat_row_ui"):
			continue
		match child.get_meta("ui_role", ""):
			"name_label": name_label = child
			"value_label": value_label = child

func set_stat(stat_name: String, value_text: String, color: Color = Color.WHITE):
	if name_label:
		name_label.text = stat_name
		name_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_secondary)
	if value_label:
		value_label.text = value_text
		value_label.add_theme_color_override("font_color", color)
