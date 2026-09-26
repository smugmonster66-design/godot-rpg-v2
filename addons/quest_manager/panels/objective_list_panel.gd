@tool
extends PanelContainer

## Emitted when an objective row is selected.
signal objective_selected(index: int, objective: Resource)
## Emitted when the objectives list changes (add, remove, reorder).
signal table_modified()

@onready var header_label: Label = %HeaderLabel
@onready var objective_list: VBoxContainer = %ObjectiveList
@onready var add_button: Button = %AddButton
@onready var delete_button: Button = %DeleteButton
@onready var move_up_button: Button = %MoveUpButton
@onready var move_down_button: Button = %MoveDownButton

var _quest_resource: Resource = null
var _objectives: Array = []
var _selected_index: int = -1

const ObjectiveRowScene = preload("res://addons/quest_manager/widgets/objective_row.tscn")

func _ready() -> void:
	if add_button:
		add_button.pressed.connect(_on_add_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)
	if move_up_button:
		move_up_button.pressed.connect(_on_move_up_pressed)
	if move_down_button:
		move_down_button.pressed.connect(_on_move_down_pressed)

# ============================================================================
# PUBLIC API
# ============================================================================

func load_quest(quest_resource: Resource) -> void:
	_quest_resource = quest_resource
	_objectives = []
	_selected_index = -1

	if _quest_resource:
		var objs = _quest_resource.get("objectives")
		if objs != null and objs.size() > 0:
			for obj in objs:
				_objectives.append(obj)
		if header_label:
			var display = _quest_resource.get("display_name")
			header_label.text = "Objectives — %s" % str(display)
	else:
		if header_label:
			header_label.text = "Objectives"

	_rebuild_rows()

func get_selected_index() -> int:
	return _selected_index

func clear_selection() -> void:
	_selected_index = -1
	_update_row_selection()

# ============================================================================
# ROW BUILDING
# ============================================================================

func _rebuild_rows() -> void:
	if not objective_list:
		return

	# Clear existing rows
	for child in objective_list.get_children():
		objective_list.remove_child(child)
		child.queue_free()

	# Display in array order (ordering matters for objectives)
	for i in _objectives.size():
		var obj = _objectives[i]
		_create_objective_row(i, obj)

	_update_row_selection()

func _create_objective_row(index: int, objective: Resource) -> void:
	if not objective_list:
		return
	var row = ObjectiveRowScene.instantiate()
	objective_list.add_child(row)
	row.set_objective_data(index, objective)
	row.row_clicked.connect(_on_row_clicked)

func _update_row_selection() -> void:
	if not objective_list:
		return
	for child in objective_list.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child.get_objective_index() == _selected_index)

# ============================================================================
# HANDLERS
# ============================================================================

func _on_row_clicked(index: int) -> void:
	_selected_index = index
	_update_row_selection()
	if index >= 0 and index < _objectives.size():
		objective_selected.emit(index, _objectives[index])

func _on_add_pressed() -> void:
	if not _quest_resource:
		return

	var new_obj = QuestObjective.new()
	new_obj.objective_id = StringName("obj_%d" % _objectives.size())

	_objectives.append(new_obj)
	_sync_objectives_to_resource()
	_rebuild_rows()

	# Select the new objective
	_selected_index = _objectives.size() - 1
	_update_row_selection()
	objective_selected.emit(_selected_index, new_obj)
	table_modified.emit()

func _on_delete_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _objectives.size():
		return

	_objectives.remove_at(_selected_index)
	_sync_objectives_to_resource()
	_selected_index = -1
	_rebuild_rows()
	table_modified.emit()

func _on_move_up_pressed() -> void:
	if _selected_index <= 0 or _selected_index >= _objectives.size():
		return
	var temp = _objectives[_selected_index]
	_objectives[_selected_index] = _objectives[_selected_index - 1]
	_objectives[_selected_index - 1] = temp
	_selected_index -= 1
	_sync_objectives_to_resource()
	_rebuild_rows()
	table_modified.emit()

func _on_move_down_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _objectives.size() - 1:
		return
	var temp = _objectives[_selected_index]
	_objectives[_selected_index] = _objectives[_selected_index + 1]
	_objectives[_selected_index + 1] = temp
	_selected_index += 1
	_sync_objectives_to_resource()
	_rebuild_rows()
	table_modified.emit()

# ============================================================================
# SYNC
# ============================================================================

func _sync_objectives_to_resource() -> void:
	"""Write the local _objectives back to the quest resource."""
	if not _quest_resource:
		return
	# Typed arrays on resources can be read-only after duplication,
	# so we always build a fresh array and assign it.
	var new_array: Array[QuestObjective] = []
	for obj in _objectives:
		new_array.append(obj)
	_quest_resource.set("objectives", new_array)

func notify_objective_changed(index: int) -> void:
	"""Called by the detail panel when an objective's data is modified."""
	_rebuild_rows()
	_selected_index = index
	_update_row_selection()
	table_modified.emit()
