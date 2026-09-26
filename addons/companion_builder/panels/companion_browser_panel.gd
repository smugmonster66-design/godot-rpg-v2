@tool
extends PanelContainer

signal companion_selected(resource: Resource, file_path: String)
signal companion_created(resource: Resource, file_path: String)

const COMPANION_ROOT := "res://resources/companions/"
const CompanionDataScript = preload("res://resources/data/companion_data.gd")

@onready var new_button: Button = %NewButton
@onready var refresh_button: Button = %RefreshButton
@onready var companion_list: ItemList = %CompanionList

var _file_paths: Array[String] = []
var _file_dialog: EditorFileDialog = null

# ============================================================================
# READY
# ============================================================================
func _ready() -> void:
	if new_button:
		new_button.pressed.connect(_on_new_pressed)
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	if companion_list:
		companion_list.item_selected.connect(_on_item_selected)

	call_deferred("_on_refresh_pressed")

# ============================================================================
# SCAN
# ============================================================================
func _on_refresh_pressed() -> void:
	if not companion_list:
		return
	companion_list.clear()
	_file_paths.clear()

	_scan_dir(COMPANION_ROOT)

	if _file_paths.is_empty():
		companion_list.add_item("(no companions found)")
		companion_list.set_item_disabled(0, true)
		companion_list.set_item_selectable(0, false)

func _scan_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				_scan_dir(full_path)
			elif file_name.ends_with(".tres"):
				var res = load(full_path)
				if res and _is_companion_data(res):
					var display = res.get("companion_name") if res.get("companion_name") else file_name
					var type_str = "SUMMON" if int(res.get("companion_type")) == 1 else "NPC"
					companion_list.add_item("%s [%s]" % [display, type_str])
					companion_list.set_item_tooltip(companion_list.item_count - 1, full_path)
					_file_paths.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _is_companion_data(res: Resource) -> bool:
	var script = res.get_script()
	if script == null:
		return false
	if script.get_global_name() == "CompanionData":
		return true
	var spath = script.resource_path as String
	return spath.ends_with("companion_data.gd")

# ============================================================================
# SELECTION
# ============================================================================
func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _file_paths.size():
		return
	var path = _file_paths[index]
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res:
		companion_selected.emit(res, path)

# ============================================================================
# NEW
# ============================================================================
func _on_new_pressed() -> void:
	if _file_dialog:
		_file_dialog.queue_free()

	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.add_filter("*.tres", "Companion Resource")
	_file_dialog.current_path = COMPANION_ROOT
	_file_dialog.file_selected.connect(_on_new_file_selected)
	add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.6)

func _on_new_file_selected(path: String) -> void:
	var data = CompanionDataScript.new()
	data.companion_name = "New Companion"
	data.companion_id = &"new_companion"

	data.take_over_path(path)
	var err = ResourceSaver.save(data, path)
	if err == OK:
		print("[CompanionBuilder] Created: %s" % path)
		_on_refresh_pressed()
		companion_created.emit(data, path)
	else:
		push_error("[CompanionBuilder] Failed to create: %s — %s" % [path, error_string(err)])

	if _file_dialog:
		_file_dialog.queue_free()
		_file_dialog = null
