@tool
extends PanelContainer

## Emitted when a quest is selected in the browser tree.
signal quest_selected(quest_resource: Resource, file_path: String)
## Emitted when a new quest is created so the dock can select it.
signal quest_created(quest_resource: Resource, file_path: String)

const QUEST_ROOT := "res://resources/definitions/quests/"

const QUEST_TYPE_NAMES = ["MAIN", "SIDE", "COMPANION", "BOUNTY", "COLLECTION", "EXPLORATION", "HIDDEN"]

@onready var filter_edit: LineEdit = %FilterEdit
@onready var quest_tree: Tree = %QuestTree
@onready var create_quest_button: Button = %CreateQuestButton
@onready var delete_quest_button: Button = %DeleteQuestButton
@onready var refresh_button: Button = %RefreshButton

var _quest_entries: Array[Dictionary] = []  # [{display, quest_id, path, folder, quest_type}]

func _ready() -> void:
	if filter_edit:
		filter_edit.text_changed.connect(_on_filter_changed)
	if quest_tree:
		quest_tree.item_selected.connect(_on_tree_item_selected)
		quest_tree.hide_root = true
		quest_tree.columns = 1
	if create_quest_button:
		create_quest_button.pressed.connect(_on_create_quest_pressed)
	if delete_quest_button:
		delete_quest_button.pressed.connect(_on_delete_quest_pressed)
	if refresh_button:
		refresh_button.pressed.connect(refresh)
	call_deferred("refresh")

# ============================================================================
# PUBLIC API
# ============================================================================

func refresh() -> void:
	_quest_entries.clear()
	_scan_quest_dir(QUEST_ROOT, "")
	_quest_entries.sort_custom(func(a, b):
		if a.folder != b.folder:
			return a.folder < b.folder
		return a.display < b.display
	)
	_rebuild_tree(filter_edit.text if filter_edit else "")

# ============================================================================
# SCANNING
# ============================================================================

func _scan_quest_dir(path: String, folder: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_folder = file_name if folder == "" else "%s/%s" % [folder, file_name]
			_scan_quest_dir(full_path, sub_folder)
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res and _is_quest_definition(res):
				var quest_id = str(res.get("quest_id"))
				var display = str(res.get("display_name"))
				if display == "":
					display = quest_id
				var qtype = res.get("quest_type")
				var type_str = ""
				if qtype != null and qtype >= 0 and qtype < QUEST_TYPE_NAMES.size():
					type_str = QUEST_TYPE_NAMES[qtype]
				var entry_folder = folder if folder != "" else "(root)"
				_quest_entries.append({
					"display": display,
					"quest_id": quest_id,
					"path": full_path,
					"folder": entry_folder,
					"quest_type": type_str,
				})
		file_name = dir.get_next()
	dir.list_dir_end()

func _is_quest_definition(res: Resource) -> bool:
	var script = res.get_script()
	if script == null:
		return false
	if script.get_global_name() == "QuestDefinition":
		return true
	var p = script.resource_path as String
	return p.ends_with("quest_definition.gd")

# ============================================================================
# TREE BUILDING
# ============================================================================

func _rebuild_tree(filter_text: String) -> void:
	if not quest_tree:
		return
	quest_tree.clear()
	var root = quest_tree.create_item()

	var filter_lower = filter_text.to_lower()
	var folder_items: Dictionary = {}

	for entry in _quest_entries:
		# Apply filter
		if filter_lower != "":
			if entry.display.to_lower().find(filter_lower) == -1 and entry.quest_id.to_lower().find(filter_lower) == -1:
				continue

		# Get or create folder item
		var folder_key = entry.folder
		if not folder_items.has(folder_key):
			var folder_item = quest_tree.create_item(root)
			folder_item.set_text(0, folder_key)
			folder_item.set_selectable(0, false)
			folder_items[folder_key] = folder_item

		# Add quest entry
		var quest_item = quest_tree.create_item(folder_items[folder_key])
		var label = entry.display
		if entry.quest_type != "":
			label = "%s [%s]" % [entry.display, entry.quest_type]
		quest_item.set_text(0, label)
		quest_item.set_tooltip_text(0, entry.quest_id)
		quest_item.set_metadata(0, entry.path)

# ============================================================================
# CREATE QUEST
# ============================================================================

func _on_create_quest_pressed() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Create New Quest"
	dialog.size = Vector2i(400, 260)

	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)

	# Subfolder
	var folder_row = HBoxContainer.new()
	vbox.add_child(folder_row)
	var folder_label = Label.new()
	folder_label.text = "Subfolder:"
	folder_row.add_child(folder_label)
	var folder_edit = LineEdit.new()
	folder_edit.placeholder_text = "region_1"
	folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_row.add_child(folder_edit)

	# Quest ID
	var id_row = HBoxContainer.new()
	vbox.add_child(id_row)
	var id_label = Label.new()
	id_label.text = "Quest ID:"
	id_row.add_child(id_label)
	var id_edit = LineEdit.new()
	id_edit.placeholder_text = "harbor_masters_request"
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_row.add_child(id_edit)

	# Display name
	var name_row = HBoxContainer.new()
	vbox.add_child(name_row)
	var name_label = Label.new()
	name_label.text = "Display name:"
	name_row.add_child(name_label)
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "The Harbor Master's Request"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)

	# Quest Type
	var type_row = HBoxContainer.new()
	vbox.add_child(type_row)
	var type_label = Label.new()
	type_label.text = "Quest Type:"
	type_row.add_child(type_label)
	var type_dropdown = OptionButton.new()
	type_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in QUEST_TYPE_NAMES.size():
		type_dropdown.add_item(QUEST_TYPE_NAMES[i], i)
	type_dropdown.select(1)  # Default to SIDE
	type_row.add_child(type_dropdown)

	dialog.confirmed.connect(func():
		var quest_id = id_edit.text.strip_edges()
		var display_name = name_edit.text.strip_edges()
		var subfolder = folder_edit.text.strip_edges()
		var quest_type = type_dropdown.get_selected_id()

		if quest_id == "":
			push_warning("[QuestManager] Quest ID cannot be empty")
			return

		if display_name == "":
			display_name = quest_id

		_create_quest_resource(quest_id, display_name, subfolder, quest_type)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered()

func _create_quest_resource(quest_id: String, display_name: String, subfolder: String, quest_type: int) -> void:
	var quest_script = load("res://resources/data/quest_definition.gd")
	if not quest_script:
		push_error("[QuestManager] Could not load quest_definition.gd")
		return

	var new_quest = quest_script.new()
	new_quest.quest_id = StringName(quest_id)
	new_quest.display_name = display_name
	new_quest.quest_type = quest_type

	# Build file path
	var dir_path = QUEST_ROOT
	if subfolder != "":
		dir_path = QUEST_ROOT.path_join(subfolder)
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file_name = "%s.tres" % quest_id
	var full_path = dir_path.path_join(file_name)

	# Check if file already exists
	if FileAccess.file_exists(full_path):
		push_warning("[QuestManager] File already exists: %s" % full_path)
		return

	var err = ResourceSaver.save(new_quest, full_path)
	if err == OK:
		print("[QuestManager] Created quest: %s at %s" % [quest_id, full_path])
		refresh()
		var loaded = load(full_path)
		if loaded:
			quest_created.emit(loaded, full_path)
	else:
		push_error("[QuestManager] Failed to create quest: %s" % error_string(err))

# ============================================================================
# DELETE QUEST
# ============================================================================

func _on_delete_quest_pressed() -> void:
	if not quest_tree:
		return
	var selected = quest_tree.get_selected()
	if selected == null:
		return
	var file_path = selected.get_metadata(0)
	if file_path == null or str(file_path) == "":
		return

	var dialog = ConfirmationDialog.new()
	dialog.title = "Delete Quest"
	dialog.dialog_text = "Delete quest file?\n%s\n\nThis cannot be undone." % str(file_path)
	dialog.confirmed.connect(func():
		var err = DirAccess.remove_absolute(str(file_path))
		if err == OK:
			print("[QuestManager] Deleted: %s" % str(file_path))
			refresh()
		else:
			push_error("[QuestManager] Failed to delete: %s" % error_string(err))
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

# ============================================================================
# HANDLERS
# ============================================================================

func _on_filter_changed(new_text: String) -> void:
	_rebuild_tree(new_text)

func _on_tree_item_selected() -> void:
	var selected = quest_tree.get_selected()
	if selected == null:
		return
	var file_path = selected.get_metadata(0)
	if file_path == null or str(file_path) == "":
		return
	var res = load(str(file_path))
	if res:
		quest_selected.emit(res, str(file_path))
