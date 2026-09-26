@tool
extends VBoxContainer

signal events_modified()

@onready var on_accept_list: VBoxContainer = %OnAcceptList
@onready var add_on_accept_button: Button = %AddOnAcceptButton
@onready var on_complete_list: VBoxContainer = %OnCompleteList
@onready var add_on_complete_button: Button = %AddOnCompleteButton
@onready var on_fail_list: VBoxContainer = %OnFailList
@onready var add_on_fail_button: Button = %AddOnFailButton

var _suppress_signals: bool = false

func _ready() -> void:
	if add_on_accept_button:
		add_on_accept_button.pressed.connect(func(): _add_event_row(on_accept_list); _emit_modified())
	if add_on_complete_button:
		add_on_complete_button.pressed.connect(func(): _add_event_row(on_complete_list); _emit_modified())
	if add_on_fail_button:
		add_on_fail_button.pressed.connect(func(): _add_event_row(on_fail_list); _emit_modified())

# ============================================================================
# PUBLIC API
# ============================================================================

func load_events(on_accept, on_complete, on_fail) -> void:
	_suppress_signals = true
	_clear_list(on_accept_list)
	_clear_list(on_complete_list)
	_clear_list(on_fail_list)

	if on_accept:
		for e in on_accept:
			_add_event_row(on_accept_list, str(e))
	if on_complete:
		for e in on_complete:
			_add_event_row(on_complete_list, str(e))
	if on_fail:
		for e in on_fail:
			_add_event_row(on_fail_list, str(e))

	_suppress_signals = false

func get_on_accept_events() -> Array[StringName]:
	return _build_event_array(on_accept_list)

func get_on_complete_events() -> Array[StringName]:
	return _build_event_array(on_complete_list)

func get_on_fail_events() -> Array[StringName]:
	return _build_event_array(on_fail_list)

# ============================================================================
# HELPERS
# ============================================================================

func _add_event_row(container: VBoxContainer, value: String = "") -> void:
	var row = HBoxContainer.new()
	var edit = LineEdit.new()
	edit.text = value
	edit.placeholder_text = "event_tag"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(_t): _emit_modified())
	row.add_child(edit)

	var remove_btn = Button.new()
	remove_btn.text = "×"
	remove_btn.pressed.connect(func(): row.queue_free(); _emit_modified())
	row.add_child(remove_btn)

	container.add_child(row)

func _build_event_array(container: VBoxContainer) -> Array[StringName]:
	var result: Array[StringName] = []
	if not container:
		return result
	for child in container.get_children():
		if child is HBoxContainer and child.get_child_count() >= 1:
			var edit = child.get_child(0) as LineEdit
			if edit and edit.text.strip_edges() != "":
				result.append(StringName(edit.text.strip_edges()))
	return result

func _clear_list(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _emit_modified() -> void:
	if not _suppress_signals:
		events_modified.emit()
