# currency_row.gd - Currency/component display row
extends HBoxContainer

var icon_rect: TextureRect
var icon_label: Label
var name_label: Label
var amount_label: Label

func _ready():
	_discover_nodes()

func _discover_nodes():
	for child in find_children("*", "", true, false):
		if not child.is_in_group("currency_row_ui"):
			continue
		match child.get_meta("ui_role", ""):
			"icon_rect": icon_rect = child
			"icon_label": icon_label = child
			"currency_name": name_label = child
			"amount": amount_label = child

func set_currency(icon: Texture2D, display_name: String, amount: int, color: Color = Color.WHITE, fallback_icon: String = ""):
	if icon_rect:
		if icon:
			icon_rect.texture = icon
			icon_rect.visible = true
		else:
			icon_rect.visible = false

	if icon_label:
		if icon:
			icon_label.visible = false
		else:
			icon_label.text = fallback_icon
			icon_label.visible = fallback_icon != ""

	if name_label:
		name_label.text = display_name

	if amount_label:
		amount_label.text = str(amount)
		amount_label.add_theme_color_override("font_color", color)
