@tool
extends PanelContainer

## Emitted when an entry row is selected.
signal entry_selected(index: int, entry: Resource)
## Emitted when the table data changes (add, remove, reorder).
signal table_modified()

@onready var header_label: Label = %HeaderLabel
@onready var entry_list: VBoxContainer = %EntryList
@onready var add_button: Button = %AddButton
@onready var delete_button: Button = %DeleteButton

var _npc_resource: Resource = null
var _dialogue_table: Array = []
var _selected_index: int = -1

const EntryRowScene = preload("res://addons/npc_dialogue_manager/widgets/dialogue_entry_row.tscn")

func _ready() -> void:
	if add_button:
		add_button.pressed.connect(_on_add_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)

# ============================================================================
# PUBLIC API
# ============================================================================

func load_npc(npc_resource: Resource) -> void:
	_npc_resource = npc_resource
	_dialogue_table = []
	_selected_index = -1

	if _npc_resource:
		var table = _npc_resource.get("dialogue_table")
		print("[NPCDialogueManager] Loading NPC, dialogue_table = ", table, " (", typeof(table), ")")
		if table != null and table.size() > 0:
			for entry in table:
				_dialogue_table.append(entry)
			print("[NPCDialogueManager] Loaded %d dialogue entries" % _dialogue_table.size())
		else:
			print("[NPCDialogueManager] No dialogue entries found in table")
		if header_label:
			var display = _npc_resource.get("display_name")
			header_label.text = "Dialogues — %s" % str(display)
	else:
		if header_label:
			header_label.text = "Dialogues"

	print("[NPCDialogueManager] entry_list = ", entry_list, " | entries to show = ", _dialogue_table.size())
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
	if not entry_list:
		return

	# Clear existing rows — free immediately so they don't linger
	for child in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()

	# Sort by priority descending (matches runtime eval order)
	var sorted_indices: Array[int] = []
	for i in _dialogue_table.size():
		sorted_indices.append(i)
	sorted_indices.sort_custom(func(a, b):
		var pri_a = _get_entry_priority(_dialogue_table[a])
		var pri_b = _get_entry_priority(_dialogue_table[b])
		return pri_a > pri_b  # Descending
	)

	for i in sorted_indices.size():
		var actual_index = sorted_indices[i]
		var entry = _dialogue_table[actual_index]
		_create_entry_row(actual_index, entry)

	_update_row_selection()

func _get_entry_priority(entry) -> int:
	if entry == null:
		return 0
	var pri = entry.get("priority")
	return pri if pri != null else 0

func _create_entry_row(index: int, entry: Resource) -> void:
	if not entry_list:
		return

	var row = EntryRowScene.instantiate()
	entry_list.add_child(row)
	row.set_entry_data(index, entry)
	row.row_clicked.connect(_on_row_clicked)

func _update_row_selection() -> void:
	if not entry_list:
		return
	for child in entry_list.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child.get_entry_index() == _selected_index)

# ============================================================================
# HANDLERS
# ============================================================================

func _on_row_clicked(index: int) -> void:
	_selected_index = index
	_update_row_selection()
	if index >= 0 and index < _dialogue_table.size():
		entry_selected.emit(index, _dialogue_table[index])

func _on_add_pressed() -> void:
	if not _npc_resource:
		return

	# Create a new NPCDialogueEntry
	var new_entry = NPCDialogueEntry.new()
	new_entry.encounter_id = StringName("new_entry_%d" % _dialogue_table.size())
	new_entry.priority = 0

	_dialogue_table.append(new_entry)
	_sync_table_to_resource()
	_rebuild_rows()

	# Select the new entry
	_selected_index = _dialogue_table.size() - 1
	_update_row_selection()
	entry_selected.emit(_selected_index, new_entry)
	table_modified.emit()

func _on_delete_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _dialogue_table.size():
		return

	_dialogue_table.remove_at(_selected_index)
	_sync_table_to_resource()
	_selected_index = -1
	_rebuild_rows()
	table_modified.emit()

# ============================================================================
# SYNC
# ============================================================================

func _sync_table_to_resource() -> void:
	"""Write the local _dialogue_table back to the NPC resource."""
	if not _npc_resource:
		return
	# Godot typed arrays on resources can be read-only after duplication,
	# so we always build a fresh array and assign it.
	var new_array: Array[NPCDialogueEntry] = []
	for entry in _dialogue_table:
		new_array.append(entry)
	_npc_resource.set("dialogue_table", new_array)

func notify_entry_changed(index: int) -> void:
	"""Called by the detail panel when an entry's data is modified."""
	_rebuild_rows()
	_selected_index = index
	_update_row_selection()
	table_modified.emit()
