@tool
extends Control

@onready var npc_browser: PanelContainer = %NPCBrowserPanel
@onready var dialogue_table: PanelContainer = %DialogueTablePanel
@onready var entry_detail: PanelContainer = %EntryDetailPanel
@onready var save_button: Button = %SaveButton
@onready var validate_button: Button = %ValidateButton
@onready var current_npc_label: Label = %CurrentNPCLabel

var _current_npc: Resource = null
var _current_file_path: String = ""
var _is_dirty: bool = false

func _ready() -> void:
	# Connect browser
	if npc_browser:
		npc_browser.npc_selected.connect(_on_npc_selected)
		npc_browser.npc_created.connect(_on_npc_selected)

	# Connect table
	if dialogue_table:
		dialogue_table.entry_selected.connect(_on_entry_selected)
		dialogue_table.table_modified.connect(_on_table_modified)

	# Connect detail panel
	if entry_detail:
		entry_detail.entry_modified.connect(_on_entry_modified)
		entry_detail.npc_modified.connect(_on_npc_modified)
		entry_detail.open_encounter_requested.connect(_on_open_encounter_requested)

	# Buttons
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if validate_button:
		validate_button.pressed.connect(_on_validate_pressed)

# ============================================================================
# NPC SELECTION
# ============================================================================

func _on_npc_selected(npc_resource: Resource, file_path: String) -> void:
	# Warn if unsaved
	if _is_dirty:
		push_warning("[NPCDialogueManager] Unsaved changes to %s" % _current_file_path)

	_current_npc = npc_resource
	_current_file_path = file_path
	_is_dirty = false

	if current_npc_label:
		var display = str(npc_resource.get("display_name"))
		var npc_id = str(npc_resource.get("npc_id"))
		current_npc_label.text = "%s (%s)" % [display, npc_id]

	# Load into panels
	if dialogue_table:
		dialogue_table.load_npc(npc_resource)
	if entry_detail:
		entry_detail.load_npc(npc_resource)

# ============================================================================
# ENTRY SELECTION
# ============================================================================

func _on_entry_selected(index: int, entry: Resource) -> void:
	if entry_detail:
		entry_detail.load_entry(index, entry)

func _on_entry_modified(index: int) -> void:
	_is_dirty = true
	_update_title()
	if dialogue_table:
		dialogue_table.notify_entry_changed(index)

func _on_table_modified() -> void:
	_is_dirty = true
	_update_title()

func _on_npc_modified() -> void:
	_is_dirty = true
	_update_title()

# ============================================================================
# SAVE
# ============================================================================

func _on_save_pressed() -> void:
	if not _current_npc or _current_file_path == "":
		push_warning("[NPCDialogueManager] No NPC loaded to save")
		return

	var err = ResourceSaver.save(_current_npc, _current_file_path)
	if err == OK:
		_is_dirty = false
		_update_title()
		print("[NPCDialogueManager] Saved: %s" % _current_file_path)
	else:
		push_error("[NPCDialogueManager] Failed to save: %s — %s" % [_current_file_path, error_string(err)])

# ============================================================================
# VALIDATION
# ============================================================================

func _on_validate_pressed() -> void:
	if not _current_npc:
		return

	var warnings: Array[String] = []
	var errors: Array[String] = []

	var table = _current_npc.get("dialogue_table")
	if table == null or table.size() == 0:
		warnings.append("NPC has no dialogue entries")
		_show_validation_results(errors, warnings)
		return

	# NPC-level checks
	if _current_npc.get("speaker") == null:
		warnings.append("No speaker assigned — NPC won't have bust textures or voice in dialogue")
	if _current_npc.get("portrait") == null:
		warnings.append("No portrait assigned — NPC won't show in the radial menu")

	var seen_ids: Dictionary = {}
	var has_fallback: bool = false

	for i in table.size():
		var entry = table[i]
		var eid = str(entry.get("encounter_id"))
		var encounter = entry.get("encounter")
		var condition = entry.get("condition")

		# Check empty encounter_id
		if eid == "" or eid == "null":
			errors.append("Entry %d: missing encounter_id" % i)

		# Check duplicate encounter_id
		if eid in seen_ids:
			errors.append("Entry %d: duplicate encounter_id '%s' (also at entry %d)" % [i, eid, seen_ids[eid]])
		else:
			seen_ids[eid] = i

		# Check missing encounter
		if encounter == null:
			errors.append("Entry %d (%s): no encounter assigned" % [i, eid])
		elif encounter.resource_path == "":
			warnings.append("Entry %d (%s): encounter not saved to disk" % [i, eid])

		# Check for fallback (no condition or ALWAYS_TRUE without invert)
		if condition == null:
			has_fallback = true
		elif condition.get("condition_type") == 0 and not condition.get("invert"):
			has_fallback = true

	if not has_fallback:
		warnings.append("No fallback entry (all entries have conditions — NPC may have nothing to say)")

	# Check for priority collisions
	var priority_map: Dictionary = {}
	for i in table.size():
		var pri = table[i].get("priority") if table[i].get("priority") != null else 0
		if pri in priority_map:
			warnings.append("Entries %d and %d have the same priority (%d) — order is ambiguous" % [priority_map[pri], i, pri])
		else:
			priority_map[pri] = i

	_show_validation_results(errors, warnings)

func _show_validation_results(errors: Array[String], warnings: Array[String]) -> void:
	if errors.is_empty() and warnings.is_empty():
		print("[NPCDialogueManager] ✓ Validation passed — no issues found")
		return

	for e in errors:
		push_error("[NPCDialogueManager] ✗ %s" % e)
	for w in warnings:
		push_warning("[NPCDialogueManager] ⚠ %s" % w)

	print("[NPCDialogueManager] Validation: %d error(s), %d warning(s)" % [errors.size(), warnings.size()])

# ============================================================================
# CROSS-PLUGIN: OPEN IN DIALOGUE EDITOR
# ============================================================================

func set_editor_plugin(p: EditorPlugin) -> void:
	"""Called by plugin.gd so we can use make_bottom_panel_item_visible()."""
	_editor_plugin = p

var _editor_plugin: EditorPlugin = null

func _on_open_encounter_requested(encounter_path: String) -> void:
	# Fallback: open the resource in the inspector so the user can click through
	var encounter = load(encounter_path)
	if encounter:
		EditorInterface.edit_resource(encounter)
	print("[NPCDialogueManager] Opened encounter in inspector: %s" % encounter_path)

# ============================================================================
# UI HELPERS
# ============================================================================

func _update_title() -> void:
	if not current_npc_label:
		return
	if _current_npc:
		var display = str(_current_npc.get("display_name"))
		var npc_id = str(_current_npc.get("npc_id"))
		var dirty_marker = " *" if _is_dirty else ""
		current_npc_label.text = "%s (%s)%s" % [display, npc_id, dirty_marker]
	else:
		current_npc_label.text = ""
