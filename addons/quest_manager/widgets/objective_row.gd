@tool
extends PanelContainer

signal row_clicked(index: int)

@onready var id_label: Label = %IdLabel
@onready var type_label: Label = %TypeLabel
@onready var target_label: Label = %TargetLabel
@onready var count_label: Label = %CountLabel
@onready var opt_label: Label = %OptLabel

var _index: int = -1
var _is_selected: bool = false

const TYPE_NAMES = [
	"TALK_TO", "KILL", "COLLECT", "VISIT", "DELIVER",
	"INTERACT", "ESCORT", "SURVIVE", "CUSTOM"
]

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func set_objective_data(index: int, objective: Resource) -> void:
	_index = index
	if not objective:
		return

	if id_label:
		var oid = str(objective.get("objective_id"))
		id_label.text = oid if oid != "" else "(unnamed)"
	if type_label:
		var otype = objective.get("objective_type")
		if otype != null and otype >= 0 and otype < TYPE_NAMES.size():
			type_label.text = TYPE_NAMES[otype]
		else:
			type_label.text = "?"
	if target_label:
		var tid = str(objective.get("target_id"))
		var tag = str(objective.get("track_tag"))
		if tid != "":
			target_label.text = tid
		elif tag != "":
			target_label.text = "tag:%s" % tag
		else:
			target_label.text = ""
	if count_label:
		count_label.text = str(objective.get("required_count"))
	if opt_label:
		opt_label.text = "○" if objective.get("optional") else ""

func get_objective_index() -> int:
	return _index

func set_selected(selected: bool) -> void:
	_is_selected = selected
	if _is_selected:
		add_theme_stylebox_override("panel", _make_selected_style())
	else:
		remove_theme_stylebox_override("panel")

func _make_selected_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.8, 0.3)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		row_clicked.emit(_index)
