@tool
extends PanelContainer

## Emitted when any field on the dialogue entry is changed.
signal entry_modified(index: int)
## Emitted when NPC-level properties are changed (needs save).
signal npc_modified()
## Emitted when "Open in Dialogue Editor" is pressed.
signal open_encounter_requested(encounter_path: String)

const LOCATION_ROOTS: Array[String] = [
	"res://resources/definitions/locations/",
	"res://resources/maps/",
]
const SPEAKER_ROOT := "res://resources/dialogues/speakers/"

@onready var no_selection_label: Label = %NoSelectionLabel
@onready var detail_container: VBoxContainer = %DetailContainer

# Dialogue entry fields
@onready var encounter_id_edit: LineEdit = %EncounterIdEdit
@onready var priority_spin: SpinBox = %PrioritySpin
@onready var one_shot_check: CheckBox = %OneShotCheck
@onready var back_to_npc_button: Button = %BackToNPCButton

# Encounter reference
@onready var encounter_path_label: Label = %EncounterPathLabel
@onready var pick_encounter_button: Button = %PickEncounterButton
@onready var open_in_editor_button: Button = %OpenInEditorButton
@onready var create_encounter_button: Button = %CreateEncounterButton

# Entry icon
@onready var icon_path_label: Label = %IconPathLabel
@onready var pick_icon_button: Button = %PickIconButton
@onready var clear_icon_button: Button = %ClearIconButton

# Entry condition widget
@onready var condition_widget = %ConditionWidget

# NPC-level fields
@onready var npc_detail_container: VBoxContainer = %NPCDetailContainer
@onready var npc_id_edit: LineEdit = %NpcIdEdit
@onready var display_name_edit: LineEdit = %DisplayNameEdit
@onready var location_dropdown: OptionButton = %LocationDropdown
@onready var speaker_dropdown: OptionButton = %SpeakerDropdown
@onready var portrait_path_label: Label = %PortraitPathLabel
@onready var pick_portrait_button: Button = %PickPortraitButton
@onready var default_icon_path_label: Label = %DefaultIconPathLabel
@onready var pick_default_icon_button: Button = %PickDefaultIconButton
@onready var clear_default_icon_button: Button = %ClearDefaultIconButton
@onready var availability_widget = %AvailabilityWidget

var _current_entry: Resource = null
var _current_index: int = -1
var _npc_resource: Resource = null
var _suppress_signals: bool = false

var _location_cache: Array = []  # [{id: String}]
var _speaker_cache: Array = []   # [{display: String, path: String, resource: Resource}]

func _ready() -> void:
	# Dialogue entry signals
	if encounter_id_edit:
		encounter_id_edit.text_changed.connect(_on_encounter_id_changed)
	if priority_spin:
		priority_spin.value_changed.connect(_on_priority_changed)
	if one_shot_check:
		one_shot_check.toggled.connect(_on_one_shot_toggled)
	if pick_encounter_button:
		pick_encounter_button.pressed.connect(_on_pick_encounter_pressed)
	if open_in_editor_button:
		open_in_editor_button.pressed.connect(_on_open_in_editor_pressed)
	if create_encounter_button:
		create_encounter_button.pressed.connect(_on_create_encounter_pressed)
	if pick_icon_button:
		pick_icon_button.pressed.connect(_on_pick_icon_pressed)
	if clear_icon_button:
		clear_icon_button.pressed.connect(_on_clear_icon_pressed)
	if condition_widget:
		condition_widget.condition_changed.connect(_on_condition_changed)
	if back_to_npc_button:
		back_to_npc_button.pressed.connect(_on_back_to_npc_pressed)

	# NPC-level signals
	if npc_id_edit:
		npc_id_edit.text_changed.connect(_on_npc_id_changed)
	if display_name_edit:
		display_name_edit.text_changed.connect(_on_display_name_changed)
	if location_dropdown:
		location_dropdown.item_selected.connect(_on_location_selected)
	if speaker_dropdown:
		speaker_dropdown.item_selected.connect(_on_speaker_selected)
	if pick_portrait_button:
		pick_portrait_button.pressed.connect(_on_pick_portrait_pressed)
	if pick_default_icon_button:
		pick_default_icon_button.pressed.connect(_on_pick_default_icon_pressed)
	if clear_default_icon_button:
		clear_default_icon_button.pressed.connect(_on_clear_default_icon_pressed)
	if availability_widget:
		availability_widget.condition_changed.connect(_on_availability_changed)

	_show_no_selection()

# ============================================================================
# PUBLIC API
# ============================================================================

func load_npc(npc_resource: Resource) -> void:
	_npc_resource = npc_resource
	_current_entry = null
	_current_index = -1
	_show_npc_detail()

func load_entry(index: int, entry: Resource) -> void:
	_suppress_signals = true
	_current_index = index
	_current_entry = entry

	if not entry:
		_show_no_selection()
		_suppress_signals = false
		return

	_show_entry_detail()

	if encounter_id_edit:
		encounter_id_edit.text = str(entry.get("encounter_id"))
	if priority_spin:
		priority_spin.value = entry.get("priority") if entry.get("priority") != null else 0
	if one_shot_check:
		one_shot_check.button_pressed = entry.get("one_shot") == true

	# Load icon
	var icon = entry.get("icon")
	if icon and icon.resource_path != "":
		if icon_path_label:
			icon_path_label.text = icon.resource_path.get_file()
	else:
		if icon_path_label:
			icon_path_label.text = "(none)"

	# Load encounter path
	var encounter = entry.get("encounter")
	if encounter and encounter.resource_path != "":
		if encounter_path_label:
			encounter_path_label.text = encounter.resource_path.get_file()
	else:
		if encounter_path_label:
			encounter_path_label.text = "(none)"

	# Load condition into widget
	if condition_widget:
		condition_widget.load_condition(entry.get("condition"))

	_suppress_signals = false

func clear_entry() -> void:
	_current_entry = null
	_current_index = -1
	if _npc_resource:
		_show_npc_detail()
	else:
		_show_no_selection()

# ============================================================================
# DISPLAY STATES
# ============================================================================

func _show_no_selection() -> void:
	if no_selection_label:
		no_selection_label.visible = true
		no_selection_label.text = "Select an NPC from the browser"
	if detail_container:
		detail_container.visible = false
	if npc_detail_container:
		npc_detail_container.visible = false

func _show_npc_detail() -> void:
	_suppress_signals = true

	if no_selection_label:
		no_selection_label.visible = false
	if detail_container:
		detail_container.visible = false
	if npc_detail_container:
		npc_detail_container.visible = true

	if _npc_resource:
		if npc_id_edit:
			npc_id_edit.text = str(_npc_resource.get("npc_id"))
		if display_name_edit:
			display_name_edit.text = str(_npc_resource.get("display_name"))

		# Populate and select location
		_populate_location_dropdown()
		var loc_id = str(_npc_resource.get("home_location_id"))
		_select_dropdown_by_meta(location_dropdown, loc_id)

		# Populate and select speaker
		_populate_speaker_dropdown()
		var speaker = _npc_resource.get("speaker")
		if speaker and speaker.resource_path != "":
			_select_dropdown_by_meta(speaker_dropdown, speaker.resource_path)
		else:
			if speaker_dropdown:
				speaker_dropdown.select(0)  # (none)

		# Portrait
		var portrait = _npc_resource.get("portrait")
		if portrait and portrait.resource_path != "":
			if portrait_path_label:
				portrait_path_label.text = portrait.resource_path.get_file()
		else:
			if portrait_path_label:
				portrait_path_label.text = "(none)"

		# Default dialogue icon
		var default_icon = _npc_resource.get("default_dialogue_icon")
		if default_icon and default_icon.resource_path != "":
			if default_icon_path_label:
				default_icon_path_label.text = default_icon.resource_path.get_file()
		else:
			if default_icon_path_label:
				default_icon_path_label.text = "(none)"

		# Availability condition
		if availability_widget:
			availability_widget.load_condition(_npc_resource.get("availability_condition"))

	_suppress_signals = false

func _show_entry_detail() -> void:
	if no_selection_label:
		no_selection_label.visible = false
	if npc_detail_container:
		npc_detail_container.visible = false
	if detail_container:
		detail_container.visible = true

# ============================================================================
# LOCATION DROPDOWN
# ============================================================================

func _populate_location_dropdown() -> void:
	if not location_dropdown:
		return
	location_dropdown.clear()

	if _location_cache.is_empty():
		for root_path in LOCATION_ROOTS:
			_scan_locations(root_path)
		_location_cache.sort_custom(func(a, b): return a.id < b.id)

	# Add empty option
	location_dropdown.add_item("(none)")
	location_dropdown.set_item_metadata(0, "")

	for entry in _location_cache:
		var idx = location_dropdown.item_count
		location_dropdown.add_item(entry.id)
		location_dropdown.set_item_metadata(idx, entry.id)

func _scan_locations(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_locations(full_path)
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res is LocationNode and res.location_id != &"":
				var lid = String(res.location_id)
				# Deduplicate
				var found = false
				for existing in _location_cache:
					if existing.id == lid:
						found = true
						break
				if not found:
					_location_cache.append({"id": lid})
		file_name = dir.get_next()
	dir.list_dir_end()

# ============================================================================
# SPEAKER DROPDOWN
# ============================================================================

func _populate_speaker_dropdown() -> void:
	if not speaker_dropdown:
		return
	speaker_dropdown.clear()

	if _speaker_cache.is_empty():
		_scan_speakers(SPEAKER_ROOT)
		_speaker_cache.sort_custom(func(a, b): return a.display < b.display)

	# Add empty option
	speaker_dropdown.add_item("(none)")
	speaker_dropdown.set_item_metadata(0, "")

	for entry in _speaker_cache:
		var idx = speaker_dropdown.item_count
		speaker_dropdown.add_item(entry.display)
		speaker_dropdown.set_item_metadata(idx, entry.path)

func _scan_speakers(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_speakers(full_path)
		elif file_name.ends_with(".tres"):
			var res = load(full_path)
			if res and _resource_matches_type(res, "DialogueSpeaker"):
				var sid = str(res.get("speaker_id"))
				var display = str(res.get("display_name"))
				if display == "":
					display = sid
				display = "%s (%s)" % [display, file_name]
				_speaker_cache.append({
					"display": display,
					"path": full_path,
				})
		file_name = dir.get_next()
	dir.list_dir_end()

func _resource_matches_type(res: Resource, type_name: String) -> bool:
	var script = res.get_script()
	if script == null:
		return false
	if script.get_global_name() == type_name:
		return true
	var p = script.resource_path as String
	return p.ends_with(type_name.to_snake_case() + ".gd")

# ============================================================================
# HELPERS
# ============================================================================

func _select_dropdown_by_meta(dropdown: OptionButton, value: String) -> void:
	if not dropdown or value == "":
		return
	for i in dropdown.item_count:
		var meta = dropdown.get_item_metadata(i)
		if meta != null and str(meta) == value:
			dropdown.select(i)
			return

# ============================================================================
# NPC-LEVEL HANDLERS
# ============================================================================

func _on_npc_id_changed(new_text: String) -> void:
	if _npc_resource and not _suppress_signals:
		_npc_resource.set("npc_id", StringName(new_text))
		_emit_npc_modified()

func _on_display_name_changed(new_text: String) -> void:
	if _npc_resource and not _suppress_signals:
		_npc_resource.set("display_name", new_text)
		_emit_npc_modified()

func _on_location_selected(index: int) -> void:
	if _npc_resource and not _suppress_signals and location_dropdown:
		var meta = location_dropdown.get_item_metadata(index)
		var loc_id = str(meta) if meta != null else ""
		_npc_resource.set("home_location_id", StringName(loc_id))
		_emit_npc_modified()

func _on_speaker_selected(index: int) -> void:
	if _npc_resource and not _suppress_signals and speaker_dropdown:
		var meta = speaker_dropdown.get_item_metadata(index)
		var speaker_path = str(meta) if meta != null else ""
		if speaker_path != "":
			var speaker_res = load(speaker_path)
			_npc_resource.set("speaker", speaker_res)
		else:
			_npc_resource.set("speaker", null)
		_emit_npc_modified()

func _on_pick_portrait_pressed() -> void:
	if not _npc_resource:
		return
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.png, *.jpg, *.webp, *.svg", "Images")
	dialog.current_dir = "res://assets/busts/"
	dialog.file_selected.connect(_on_portrait_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

func _on_portrait_file_selected(path: String) -> void:
	if not _npc_resource:
		return
	var tex = load(path)
	if tex:
		_npc_resource.set("portrait", tex)
		if portrait_path_label:
			portrait_path_label.text = path.get_file()
		_emit_npc_modified()

func _on_pick_default_icon_pressed() -> void:
	if not _npc_resource:
		return
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.png, *.jpg, *.webp, *.svg", "Images")
	dialog.current_dir = "res://assets/"
	dialog.file_selected.connect(_on_default_icon_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

func _on_default_icon_file_selected(path: String) -> void:
	if not _npc_resource:
		return
	var tex = load(path)
	if tex:
		_npc_resource.set("default_dialogue_icon", tex)
		if default_icon_path_label:
			default_icon_path_label.text = path.get_file()
		_emit_npc_modified()

func _on_clear_default_icon_pressed() -> void:
	if not _npc_resource:
		return
	_npc_resource.set("default_dialogue_icon", null)
	if default_icon_path_label:
		default_icon_path_label.text = "(none)"
	_emit_npc_modified()

func _on_availability_changed(condition: Resource) -> void:
	if _npc_resource and not _suppress_signals:
		_npc_resource.set("availability_condition", condition)
		_emit_npc_modified()

func _on_back_to_npc_pressed() -> void:
	_current_entry = null
	_current_index = -1
	_show_npc_detail()

# ============================================================================
# DIALOGUE ENTRY HANDLERS
# ============================================================================

func _on_encounter_id_changed(new_text: String) -> void:
	if _current_entry and not _suppress_signals:
		_current_entry.set("encounter_id", StringName(new_text))
		_emit_modified()

func _on_priority_changed(new_value: float) -> void:
	if _current_entry and not _suppress_signals:
		_current_entry.set("priority", int(new_value))
		_emit_modified()

func _on_one_shot_toggled(pressed: bool) -> void:
	if _current_entry and not _suppress_signals:
		_current_entry.set("one_shot", pressed)
		_emit_modified()

func _on_condition_changed(condition: Resource) -> void:
	if _current_entry and not _suppress_signals:
		_current_entry.set("condition", condition)
		_emit_modified()

func _on_pick_icon_pressed() -> void:
	if not _current_entry:
		return
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.png, *.jpg, *.webp, *.svg", "Images")
	dialog.current_dir = "res://assets/"
	dialog.file_selected.connect(_on_icon_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

func _on_icon_file_selected(path: String) -> void:
	if not _current_entry:
		return
	var tex = load(path)
	if tex:
		_current_entry.set("icon", tex)
		if icon_path_label:
			icon_path_label.text = path.get_file()
		_emit_modified()

func _on_clear_icon_pressed() -> void:
	if not _current_entry:
		return
	_current_entry.set("icon", null)
	if icon_path_label:
		icon_path_label.text = "(none)"
	_emit_modified()

func _on_pick_encounter_pressed() -> void:
	if not _current_entry:
		return
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Dialogue Encounter")
	dialog.current_dir = "res://resources/dialogues/"
	dialog.file_selected.connect(_on_encounter_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

func _on_encounter_file_selected(path: String) -> void:
	if not _current_entry:
		return
	var encounter = load(path)
	if encounter:
		_current_entry.set("encounter", encounter)
		if encounter_path_label:
			encounter_path_label.text = path.get_file()
		_emit_modified()

func _on_open_in_editor_pressed() -> void:
	if not _current_entry:
		return
	var encounter = _current_entry.get("encounter")
	if encounter and encounter.resource_path != "":
		open_encounter_requested.emit(encounter.resource_path)
	else:
		push_warning("[NPCDialogueManager] No encounter assigned to this entry")

func _on_create_encounter_pressed() -> void:
	if not _current_entry or not _npc_resource:
		return

	var encounter_script = load("res://resources/data/dialogue_encounter.gd")
	if not encounter_script:
		push_warning("[NPCDialogueManager] Could not load dialogue_encounter.gd")
		return

	var new_encounter = encounter_script.new()
	var eid = str(_current_entry.get("encounter_id"))
	var npc_id = str(_npc_resource.get("npc_id"))

	# Ensure directory exists
	var dir_path = "res://resources/dialogues/%s/" % npc_id
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file_name = "%s.tres" % eid if eid != "" else "new_encounter.tres"
	var full_path = dir_path.path_join(file_name)

	var err = ResourceSaver.save(new_encounter, full_path)
	if err == OK:
		# Reload from disk so the resource has a proper resource_path.
		# Without this, Godot serializes it as an inline sub_resource
		# instead of an ExtResource reference to the .tres file.
		var loaded_encounter = load(full_path)
		_current_entry.set("encounter", loaded_encounter)
		if encounter_path_label:
			encounter_path_label.text = file_name
		_emit_modified()
		open_encounter_requested.emit(full_path)
	else:
		push_warning("[NPCDialogueManager] Failed to save encounter: %s" % error_string(err))

# ============================================================================
# SIGNAL HELPERS
# ============================================================================

func _emit_modified() -> void:
	if not _suppress_signals:
		entry_modified.emit(_current_index)

func _emit_npc_modified() -> void:
	if not _suppress_signals:
		npc_modified.emit()
