# collapsible_section.gd - Expandable/collapsible section
extends VBoxContainer

var toggle_button: Button
var content_container: VBoxContainer
var _expanded: bool = false
var _title: String = "Section"

func _ready():
	_discover_nodes()
	if toggle_button and not toggle_button.pressed.is_connected(_on_toggle):
		toggle_button.pressed.connect(_on_toggle)
	_update_button_text()

func _discover_nodes():
	for child in find_children("*", "", true, false):
		if not child.is_in_group("collapsible_ui"):
			continue
		match child.get_meta("ui_role", ""):
			"toggle_button": toggle_button = child
			"content_container": content_container = child

func set_title(title: String):
	_title = title
	_update_button_text()

func set_expanded(expanded: bool):
	_expanded = expanded
	if content_container:
		content_container.visible = _expanded
	_update_button_text()

func _on_toggle():
	set_expanded(not _expanded)

func _update_button_text():
	if toggle_button:
		var indicator = "[-]" if _expanded else "[+]"
		toggle_button.text = "%s %s" % [_title, indicator]
