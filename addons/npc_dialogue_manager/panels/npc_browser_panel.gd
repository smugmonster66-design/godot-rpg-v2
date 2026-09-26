@tool
extends PanelContainer

## Emitted when an NPC is selected in the browser tree.
signal npc_selected(npc_resource: Resource, file_path: String)
## Emitted when a new NPC is created so the dock can select it.
signal npc_created(npc_resource: Resource, file_path: String)

const NPC_ROOT := "res://resources/npcs/"

@onready var filter_edit: LineEdit = %FilterEdit
@onready var npc_tree: Tree = %NPCTree
@onready var create_npc_button: Button = %CreateNPCButton
@onready var refresh_button: Button = %RefreshButton

var _npc_entries: Array[Dictionary] = []  # [{display, npc_id, path, region}]

func _ready() -> void:
	if filter_edit:
		filter_edit.placeholder_text = "Filter NPCs..."
		filter_edit.text_changed.connect(_on_filter_changed)
	if npc_tree:
		npc_tree.item_selected.connect(_on_tree_item_selected)
		npc_tree.hide_root = true
		npc_tree.columns = 1
	if create_npc_button:
		create_npc_button.pressed.connect(_on_create_npc_pressed)
	if refresh_button:
		refresh_button.pressed.connect(refresh)
	call_deferred("refresh")

# ============================================================================
# PUBLIC API
# ============================================================================

func refresh() -> void:
	_npc_entries.clear()
	_scan_npc_dir(NPC_ROOT, "")
	_npc_entries.sort_custom(func(a, b):
		if a.region != b.region:
			return a.region < b.region
		return a.display < b.display
	)
	_rebuild_tree(filter_edit.text if filter_edit else "")

# ============================================================================
# SCANNING
# ============================================================================

func _scan_npc_dir(path: String, region: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_region = file_name if region == "" else "%s/%s" % [region, file_name]
			_scan_npc_dir(full_path, sub_region)
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res and _is_npc_definition(res):
				var npc_id = str(res.get("npc_id"))
				var display = str(res.get("display_name"))
				if display == "":
					display = npc_id
				var entry_region = region if region != "" else "(root)"
				_npc_entries.append({
					"display": display,
					"npc_id": npc_id,
					"path": full_path,
					"region": entry_region,
				})
		file_name = dir.get_next()
	dir.list_dir_end()

func _is_npc_definition(res: Resource) -> bool:
	var script = res.get_script()
	if script == null:
		return false
	if script.get_global_name() == "NPCDefinition":
		return true
	var path = script.resource_path as String
	return path.ends_with("npc_definition.gd")

# ============================================================================
# TREE BUILDING
# ============================================================================

func _rebuild_tree(filter_text: String) -> void:
	if not npc_tree:
		return
	npc_tree.clear()
	var root = npc_tree.create_item()

	var filter_lower = filter_text.to_lower()
	var region_items: Dictionary = {}

	for entry in _npc_entries:
		# Apply filter
		if filter_lower != "":
			if entry.display.to_lower().find(filter_lower) == -1 and entry.npc_id.to_lower().find(filter_lower) == -1:
				continue

		# Get or create region folder
		var region_key = entry.region
		if not region_items.has(region_key):
			var region_item = npc_tree.create_item(root)
			region_item.set_text(0, region_key)
			region_item.set_selectable(0, false)
			region_items[region_key] = region_item

		# Add NPC entry
		var npc_item = npc_tree.create_item(region_items[region_key])
		npc_item.set_text(0, entry.display)
		npc_item.set_tooltip_text(0, entry.npc_id)
		npc_item.set_metadata(0, entry.path)

# ============================================================================
# CREATE NPC
# ============================================================================

func _on_create_npc_pressed() -> void:
	# Show a dialog to pick the region folder and enter the NPC id
	var dialog = ConfirmationDialog.new()
	dialog.title = "Create New NPC"
	dialog.size = Vector2i(400, 220)

	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)

	# Region dropdown
	var region_row = HBoxContainer.new()
	vbox.add_child(region_row)
	var region_label = Label.new()
	region_label.text = "Region folder:"
	region_row.add_child(region_label)
	var region_edit = LineEdit.new()
	region_edit.placeholder_text = "region_1"
	region_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_row.add_child(region_edit)

	# NPC ID
	var id_row = HBoxContainer.new()
	vbox.add_child(id_row)
	var id_label = Label.new()
	id_label.text = "NPC ID:"
	id_row.add_child(id_label)
	var id_edit = LineEdit.new()
	id_edit.placeholder_text = "blacksmith_haven"
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_row.add_child(id_edit)

	# Display name
	var name_row = HBoxContainer.new()
	vbox.add_child(name_row)
	var name_label = Label.new()
	name_label.text = "Display name:"
	name_row.add_child(name_label)
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "Hilda the Blacksmith"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)

	dialog.confirmed.connect(func():
		var npc_id = id_edit.text.strip_edges()
		var display_name = name_edit.text.strip_edges()
		var region = region_edit.text.strip_edges()

		if npc_id == "":
			push_warning("[NPCDialogueManager] NPC ID cannot be empty")
			return

		if display_name == "":
			display_name = npc_id

		_create_npc_resource(npc_id, display_name, region)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered()

func _create_npc_resource(npc_id: String, display_name: String, region: String) -> void:
	var npc_script = load("res://resources/data/npc_definition.gd")
	if not npc_script:
		push_error("[NPCDialogueManager] Could not load npc_definition.gd")
		return

	var new_npc = npc_script.new()
	new_npc.npc_id = StringName(npc_id)
	new_npc.display_name = display_name

	# Build file path
	var dir_path = NPC_ROOT
	if region != "":
		dir_path = NPC_ROOT.path_join(region)
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file_name = "npc_%s.tres" % npc_id
	var full_path = dir_path.path_join(file_name)

	# Check if file already exists
	if FileAccess.file_exists(full_path):
		push_warning("[NPCDialogueManager] File already exists: %s" % full_path)
		return

	var err = ResourceSaver.save(new_npc, full_path)
	if err == OK:
		print("[NPCDialogueManager] Created NPC: %s at %s" % [npc_id, full_path])
		refresh()
		# Reload the saved resource so it has the correct resource_path
		var loaded = load(full_path)
		if loaded:
			npc_created.emit(loaded, full_path)
	else:
		push_error("[NPCDialogueManager] Failed to create NPC: %s" % error_string(err))

# ============================================================================
# HANDLERS
# ============================================================================

func _on_filter_changed(new_text: String) -> void:
	_rebuild_tree(new_text)

func _on_tree_item_selected() -> void:
	var selected = npc_tree.get_selected()
	if selected == null:
		return
	var file_path = selected.get_metadata(0)
	if file_path == null or str(file_path) == "":
		return
	var res = load(str(file_path))
	if res:
		npc_selected.emit(res, str(file_path))
