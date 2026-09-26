@tool
extends "res://addons/dialogue_editor/nodes/base_dialogue_node.gd"

# ============================================================================
# CONSTANTS
# ============================================================================
const EVENT_ROOT := "res://resources/events/"
## Scanned recursively (sub-folders become dropdown categories)
const ENCOUNTER_ROOT := "res://resources/encounters/"
const DUNGEON_ROOT := "res://resources/dungeon/"
const QUEST_ROOT := "res://resources/definitions/quests/"
const ITEM_ROOT := "res://resources/items/"
const CONSUMABLE_ROOT := "res://resources/consumables/"

# ============================================================================
# ACTION TYPES
# ============================================================================
enum GameActionType {
	START_COMBAT,     # resource path to CombatEncounter .tres
	OPEN_SHOP,        # shop_id string
	CUSTOM_EVENT,     # event_id from GameEventDefinition
	ENTER_DUNGEON,    # resource path to DungeonDefinition .tres
	ACCEPT_QUEST,     # quest_id from QuestDefinition
	COMPLETE_QUEST,   # quest_id from QuestDefinition
	REPORT_OBJECTIVE, # quest_id:objective_id
	OPEN_SMITHING,    # resource path to SmithingConfig .tres
	GRANT_ITEM,       # res://path/to/item.tres or res://path/to/item.tres:<quantity>
	HEAL,             # "25" (flat HP), "50%" (of max HP) or "25+50%"
}

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var type_dropdown: OptionButton = $VBox/TypeRow/TypeDropdown
@onready var param_label: Label = $VBox/ParamRow/ParamLabel
@onready var param_edit: LineEdit = $VBox/ParamRow/ParamEdit
@onready var param_dropdown: OptionButton = $VBox/ParamRow/ParamDropdown
@onready var objective_row: HBoxContainer = $VBox/ObjectiveRow
@onready var objective_dropdown: OptionButton = $VBox/ObjectiveRow/ObjectiveDropdown

# ============================================================================
# STATE
# ============================================================================
var action_type: GameActionType = GameActionType.START_COMBAT
var param: String = ""
## For REPORT_OBJECTIVE: the selected quest_id (objective dropdown is populated from this)
var _selected_quest_id: String = ""
## For GRANT_ITEM: the item path and quantity encoded into param
var _item_path: String = ""
var _item_qty: int = 1
var _qty_row: HBoxContainer = null
var _qty_spin: SpinBox = null

## Cached scan results per type — avoids re-scanning on every UI update.
## Key: scan root path, Value: Array of { id: String, category: String }
var _scan_cache: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	title = "ACTION"

	# Visual styling — amber/orange
	add_theme_color_override("title_color", Color(0.9, 0.7, 0.3))

	# One input, one output (pass-through)
	set_slot(0, true, 0, Color(0.9, 0.7, 0.3), true, 0, Color(0.9, 0.7, 0.3))

	# Populate type dropdown
	if type_dropdown:
		type_dropdown.clear()
		type_dropdown.add_item("Start Combat", GameActionType.START_COMBAT)
		type_dropdown.add_item("Open Shop", GameActionType.OPEN_SHOP)
		type_dropdown.add_item("Custom Event", GameActionType.CUSTOM_EVENT)
		type_dropdown.add_item("Enter Dungeon", GameActionType.ENTER_DUNGEON)
		type_dropdown.add_item("Accept Quest", GameActionType.ACCEPT_QUEST)
		type_dropdown.add_item("Complete Quest", GameActionType.COMPLETE_QUEST)
		type_dropdown.add_item("Report Objective", GameActionType.REPORT_OBJECTIVE)
		type_dropdown.add_item("Open Smithing", GameActionType.OPEN_SMITHING)
		type_dropdown.add_item("Grant Item", GameActionType.GRANT_ITEM)
		type_dropdown.add_item("Heal", GameActionType.HEAL)
		type_dropdown.item_selected.connect(_on_type_selected)

	if param_edit:
		param_edit.text_changed.connect(_on_param_changed)

	# @onready may not resolve in @tool GraphNode context — always try explicit lookup
	if param_dropdown == null:
		param_dropdown = get_node_or_null("VBox/ParamRow/ParamDropdown")
	if param_label == null:
		param_label = get_node_or_null("VBox/ParamRow/ParamLabel")
	if param_edit == null:
		param_edit = get_node_or_null("VBox/ParamRow/ParamEdit")
	if type_dropdown == null:
		type_dropdown = get_node_or_null("VBox/TypeRow/TypeDropdown")

	if param_dropdown:
		param_dropdown.item_selected.connect(_on_param_dropdown_selected)

	if objective_row == null:
		objective_row = get_node_or_null("VBox/ObjectiveRow")
	if objective_dropdown == null:
		objective_dropdown = get_node_or_null("VBox/ObjectiveRow/ObjectiveDropdown")
	if objective_dropdown:
		objective_dropdown.item_selected.connect(_on_objective_dropdown_selected)

	_create_quantity_row()

	# Defer the UI update so all children are guaranteed in the tree
	call_deferred("_update_param_ui")

func _create_quantity_row() -> void:
	"""Quantity row for GRANT_ITEM (built in code; the .tscn has no such row)."""
	var vbox = find_child("VBox", false, false)
	if vbox == null or _qty_row != null:
		return
	_qty_row = HBoxContainer.new()
	_qty_row.name = "QuantityRow"
	_qty_row.visible = false
	var lbl = Label.new()
	lbl.text = "Quantity:"
	_qty_row.add_child(lbl)
	_qty_spin = SpinBox.new()
	_qty_spin.min_value = 1
	_qty_spin.max_value = 999
	_qty_spin.step = 1
	_qty_spin.value = _item_qty
	_qty_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_qty_spin.value_changed.connect(_on_qty_changed)
	_qty_row.add_child(_qty_spin)
	vbox.add_child(_qty_row)

func _on_qty_changed(value: float) -> void:
	_item_qty = int(value)
	_update_grant_item_param()

func _update_grant_item_param() -> void:
	"""GRANT_ITEM param: the item path, plus :<quantity> when quantity > 1."""
	param = _item_path if _item_qty <= 1 else "%s:%d" % [_item_path, _item_qty]
	_emit_modified()

static func split_item_param(p: String) -> Array:
	"""'res://x/y.tres:3' -> ['res://x/y.tres', 3]; 'res://x/y.tres' -> [.., 1]."""
	var idx = p.rfind(":")
	if idx > 0:
		var tail = p.substr(idx + 1)
		var head = p.substr(0, idx)
		if tail.is_valid_int() and not head.ends_with(":") and head != "res":
			return [head, maxi(1, int(tail))]
	return [p, 1]

# ============================================================================
# UI HANDLERS
# ============================================================================

func _on_type_selected(index: int) -> void:
	action_type = type_dropdown.get_item_id(index) as GameActionType if type_dropdown else index as GameActionType
	param = ""
	_selected_quest_id = ""
	_item_path = ""
	_item_qty = 1
	if _qty_spin:
		_qty_spin.set_value_no_signal(1)
	_update_param_ui()
	_emit_modified()

func _on_param_changed(new_text: String) -> void:
	param = new_text
	_emit_modified()

func _on_param_dropdown_selected(index: int) -> void:
	if param_dropdown and index >= 0:
		var meta = param_dropdown.get_item_metadata(index)
		var value: String = str(meta) if meta != null and str(meta) != "" else param_dropdown.get_item_text(index)

		if action_type == GameActionType.REPORT_OBJECTIVE:
			# Quest selected — populate objective dropdown
			_selected_quest_id = value
			_populate_objective_dropdown_for_quest(value)
		elif action_type == GameActionType.GRANT_ITEM:
			_item_path = value
			_update_grant_item_param()
		else:
			param = value
			_emit_modified()

func _on_objective_dropdown_selected(index: int) -> void:
	if objective_dropdown and index >= 0:
		var meta = objective_dropdown.get_item_metadata(index)
		var objective_id: String = str(meta) if meta != null and str(meta) != "" else objective_dropdown.get_item_text(index)
		param = "%s:%s" % [_selected_quest_id, objective_id]
		_emit_modified()

func _resolve_refs() -> void:
	"""Re-resolve node references in case @onready failed (@tool timing)."""
	if param_label == null:
		param_label = get_node_or_null("VBox/ParamRow/ParamLabel")
	if param_edit == null:
		param_edit = get_node_or_null("VBox/ParamRow/ParamEdit")
	if param_dropdown == null:
		param_dropdown = get_node_or_null("VBox/ParamRow/ParamDropdown")
	if objective_row == null:
		objective_row = get_node_or_null("VBox/ObjectiveRow")
	if objective_dropdown == null:
		objective_dropdown = get_node_or_null("VBox/ObjectiveRow/ObjectiveDropdown")
	# Last resort: create the OptionButton programmatically
	if param_dropdown == null:
		var param_row = get_node_or_null("VBox/ParamRow")
		if param_row:
			param_dropdown = OptionButton.new()
			param_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			param_dropdown.visible = false
			param_row.add_child(param_dropdown)
			param_dropdown.item_selected.connect(_on_param_dropdown_selected)
			print("[ActionNode] Created ParamDropdown programmatically")

func _update_param_ui() -> void:
	_resolve_refs()
	if not param_label:
		return

	# Hide objective row for all types except REPORT_OBJECTIVE
	if objective_row:
		objective_row.visible = (action_type == GameActionType.REPORT_OBJECTIVE)
	if _qty_row:
		_qty_row.visible = (action_type == GameActionType.GRANT_ITEM)

	match action_type:
		GameActionType.START_COMBAT:
			param_label.text = "Encounter:"
			_show_dropdown_for(ENCOUNTER_ROOT, "encounter_name", "CombatEncounter")
		GameActionType.OPEN_SHOP:
			param_label.text = "Shop ID:"
			_show_line_edit("shop_id")
		GameActionType.CUSTOM_EVENT:
			param_label.text = "Event:"
			_show_dropdown_for(EVENT_ROOT, "event_id", "GameEventDefinition")
		GameActionType.ENTER_DUNGEON:
			param_label.text = "Dungeon:"
			_show_dropdown_for(DUNGEON_ROOT, "dungeon_name", "DungeonDefinition", "DungeonChain")
		GameActionType.ACCEPT_QUEST:
			param_label.text = "Quest:"
			_show_dropdown_for(QUEST_ROOT, "display_name", "QuestDefinition")
		GameActionType.COMPLETE_QUEST:
			param_label.text = "Quest:"
			_show_dropdown_for(QUEST_ROOT, "display_name", "QuestDefinition")
		GameActionType.REPORT_OBJECTIVE:
			param_label.text = "Quest:"
			_show_report_objective_ui()
		GameActionType.OPEN_SMITHING:
			param_label.text = "Config:"
			if param == "":
				param = "res://resources/crafting/smithing_config.tres"
			_show_line_edit("res://resources/crafting/smithing_config.tres")
		GameActionType.GRANT_ITEM:
			param_label.text = "Item:"
			_show_grant_item_ui()
		GameActionType.HEAL:
			param_label.text = "Heal:"
			_show_line_edit("25, 50% or 25+50%")

func _show_line_edit(placeholder: String) -> void:
	if param_edit:
		param_edit.visible = true
		param_edit.placeholder_text = placeholder
		param_edit.text = param
	if param_dropdown:
		param_dropdown.visible = false

# ============================================================================
# DROPDOWN (shared by START_COMBAT, CUSTOM_EVENT, ENTER_DUNGEON)
# ============================================================================

func _show_dropdown_for(root_path: String, display_field: String, type_filter: String, disabled_type: String = "") -> void:
	"""Show param_dropdown populated by scanning root_path for resources.
	Resources of disabled_type are listed greyed out (e.g. DungeonChain, which
	the ENTER_DUNGEON runtime action cannot start)."""
	if param_edit:
		param_edit.visible = false
	if not param_dropdown:
		print("[ActionNode] _show_dropdown_for: param_dropdown is NULL, falling back to LineEdit")
		if param_edit:
			param_edit.visible = true
			param_edit.placeholder_text = root_path
		return
	param_dropdown.visible = true

	# Scan on first use per root path
	if not _scan_cache.has(root_path):
		var results: Array = []
		_scan_resource_dir(root_path, "", display_field, type_filter, results)
		if disabled_type != "":
			var extra: Array = []
			_scan_resource_dir(root_path, "", "chain_name", disabled_type, extra)
			for e in extra:
				e.display = "%s (chain: not supported by Enter Dungeon)" % e.display
				e.disabled = true
			results.append_array(extra)
		results.sort_custom(func(a, b):
			if a.category != b.category:
				return a.category < b.category
			return a.display < b.display
		)
		_scan_cache[root_path] = results

	_populate_dropdown(_scan_cache[root_path])

func _populate_dropdown(entries: Array) -> void:
	param_dropdown.clear()

	var current_category := ""
	for entry in entries:
		var cat = entry.category as String
		if cat != current_category:
			if cat != "":
				param_dropdown.add_separator(cat)
			current_category = cat
		var idx = param_dropdown.item_count
		param_dropdown.add_item(entry.display)
		param_dropdown.set_item_metadata(idx, entry.id)
		if entry.get("disabled", false):
			param_dropdown.set_item_disabled(idx, true)

	if entries.is_empty():
		param_dropdown.add_item("(none found)")
		param_dropdown.set_item_disabled(0, true)
		return

	_select_dropdown_value(param)

	# If nothing was pre-selected, sync param to whichever item is showing
	# (OptionButton auto-selects item 0 visually but doesn't emit item_selected)
	if param == "" and param_dropdown.selected >= 0 and not param_dropdown.is_item_disabled(param_dropdown.selected):
		var meta = param_dropdown.get_item_metadata(param_dropdown.selected)
		if meta != null and str(meta) != "":
			param = str(meta)
		else:
			param = param_dropdown.get_item_text(param_dropdown.selected)
		_emit_modified()

func _select_dropdown_value(value: String) -> void:
	if not param_dropdown or value == "":
		return
	for i in param_dropdown.item_count:
		var meta = param_dropdown.get_item_metadata(i)
		if meta != null and str(meta) == value:
			param_dropdown.select(i)
			return
		if param_dropdown.get_item_text(i) == value:
			param_dropdown.select(i)
			return
	# Value not in dropdown — append it so it's not silently lost
	if value != "":
		param_dropdown.add_separator()
		var idx = param_dropdown.item_count
		param_dropdown.add_item(value)
		param_dropdown.set_item_metadata(idx, value)
		param_dropdown.select(idx)

# ============================================================================
# GRANT ITEM — item picker (equipment + consumables) + quantity
# ============================================================================

func _show_grant_item_ui() -> void:
	var parts = split_item_param(param)
	_item_path = parts[0]
	_item_qty = parts[1]
	if _qty_spin:
		_qty_spin.set_value_no_signal(_item_qty)
	if param_edit:
		param_edit.visible = false
	if not param_dropdown:
		if param_edit:
			param_edit.visible = true
			param_edit.placeholder_text = "res://resources/items/...tres:1"
			param_edit.text = param
		return
	param_dropdown.visible = true
	var cache_key = "_grant_items"
	if not _scan_cache.has(cache_key):
		var results: Array = []
		_scan_resource_dir(ITEM_ROOT, "items", "item_name", "EquippableItem", results)
		_scan_resource_dir(CONSUMABLE_ROOT, "consumables", "item_name", "ConsumableItem", results)
		results.sort_custom(func(a, b):
			if a.category != b.category:
				return a.category < b.category
			return a.display < b.display
		)
		_scan_cache[cache_key] = results
	# _populate_dropdown selects by `param`, so select by the item path, then
	# re-encode the quantity (auto-picks the first item if none was set)
	var saved_param = param
	param = _item_path
	_populate_dropdown(_scan_cache[cache_key])
	_item_path = param
	var new_param = _item_path if _item_qty <= 1 else "%s:%d" % [_item_path, _item_qty]
	param = new_param
	if new_param != saved_param:
		_emit_modified()

# ============================================================================
# REPORT OBJECTIVE — two-dropdown flow (Quest → Objective)
# ============================================================================

func _show_report_objective_ui() -> void:
	"""Show quest dropdown in ParamRow. Selecting a quest populates ObjectiveRow."""
	if param_edit:
		param_edit.visible = false
	if not param_dropdown:
		return
	param_dropdown.visible = true

	# Populate quest dropdown
	_show_dropdown_for(QUEST_ROOT, "display_name", "QuestDefinition")

	# If we already have a param (loading saved data), parse and restore both dropdowns
	if param != "" and param.find(":") >= 0:
		var sep = param.find(":")
		_selected_quest_id = param.substr(0, sep)
		var objective_id = param.substr(sep + 1)
		_select_dropdown_value(_selected_quest_id)
		_populate_objective_dropdown_for_quest(_selected_quest_id)
		_select_objective_dropdown_value(objective_id)
	elif _selected_quest_id != "":
		_populate_objective_dropdown_for_quest(_selected_quest_id)

func _populate_objective_dropdown_for_quest(quest_id: String) -> void:
	"""Scan the quest definition and populate the objective dropdown with its objectives."""
	if not objective_dropdown:
		return

	objective_dropdown.clear()

	# Find the quest definition resource
	var cache_key = "_obj_%s" % quest_id
	if not _scan_cache.has(cache_key):
		var entries: Array = []
		var dir = DirAccess.open(QUEST_ROOT)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres"):
					var res = load(QUEST_ROOT.path_join(file_name))
					if res and _resource_matches_type(res, "QuestDefinition"):
						var qid = str(res.get("quest_id"))
						if qid == quest_id:
							var objectives = res.get("objectives")
							if objectives:
								for obj in objectives:
									var oid = str(obj.get("objective_id"))
									var odesc = str(obj.get("description"))
									# Clean up placeholder tokens for display
									var clean_desc = odesc.replace("{current}", "0").replace("{required}", str(obj.get("required_count")))
									entries.append({"display": clean_desc, "id": oid})
							break
				file_name = dir.get_next()
			dir.list_dir_end()
		_scan_cache[cache_key] = entries

	var entries = _scan_cache[cache_key] as Array
	for entry in entries:
		var idx = objective_dropdown.item_count
		objective_dropdown.add_item(entry.display)
		objective_dropdown.set_item_metadata(idx, entry.id)

	if entries.is_empty():
		objective_dropdown.add_item("(no objectives)")
		objective_dropdown.set_item_disabled(0, true)
		return

	# Auto-select first objective if no param yet
	if param == "" or param.find(":") < 0:
		var first_meta = objective_dropdown.get_item_metadata(0)
		if first_meta != null:
			param = "%s:%s" % [quest_id, str(first_meta)]
			_emit_modified()

func _select_objective_dropdown_value(objective_id: String) -> void:
	if not objective_dropdown or objective_id == "":
		return
	for i in objective_dropdown.item_count:
		var meta = objective_dropdown.get_item_metadata(i)
		if meta != null and str(meta) == objective_id:
			objective_dropdown.select(i)
			return

# ============================================================================
# RESOURCE SCANNING (editor-time filesystem scan)
# ============================================================================

func _scan_resource_dir(
	path: String,
	category: String,
	display_field: String,
	type_filter: String,
	results: Array
) -> void:
	"""Recursively scan a directory for .tres resources matching type_filter."""
	var dir = DirAccess.open(path)
	if dir == null:
		return

	var subdirs: Array[String] = []
	var files: Array[String] = []

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			subdirs.append(file_name)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()
	for fname in files:
		var full_path = path.path_join(fname)
		var res = load(full_path)
		if res == null:
			continue

		# Type check — compare class name
		if type_filter != "" and not _resource_matches_type(res, type_filter):
			continue

		# Build display name and ID
		var display_name: String = fname.get_basename()
		var id_value: String = full_path  # default: resource path

		if type_filter == "GameEventDefinition":
			# Events use event_id as the stored value
			var eid = res.get("event_id")
			if eid != null and str(eid) != "":
				id_value = str(eid)
				display_name = str(eid)
		elif type_filter == "QuestDefinition":
			# Quests use quest_id as the stored value
			var qid = res.get("quest_id")
			if qid != null and str(qid) != "":
				id_value = str(qid)

		# Try to get a human-readable display name from the resource
		var dval = res.get(display_field)
		if dval != null and str(dval) != "":
			display_name = str(dval)

		results.append({
			"display": display_name,
			"id": id_value,
			"category": category,
		})

	# Recurse into subdirectories
	subdirs.sort()
	for subdir in subdirs:
		var sub_category = subdir if category == "" else "%s/%s" % [category, subdir]
		_scan_resource_dir(path.path_join(subdir), sub_category, display_field, type_filter, results)

func _resource_matches_type(res: Resource, type_name: String) -> bool:
	"""Check if a resource's script class matches the expected type name."""
	var script = res.get_script()
	if script == null:
		return false
	# Check class_name from script
	if script.get_global_name() == type_name:
		return true
	# Fallback: check the script path for a hint
	var path = script.resource_path as String
	if path.ends_with(type_name.to_snake_case() + ".gd"):
		return true
	return false

# ============================================================================
# SERIALIZATION
# ============================================================================

func get_node_type() -> String:
	return "game_action"

func get_node_data() -> Dictionary:
	var data = super.get_node_data()
	data.action_type = action_type
	data.param = param
	return data

func set_node_data(data: Dictionary) -> void:
	super.set_node_data(data)

	action_type = data.get("action_type", GameActionType.START_COMBAT)
	param = data.get("param", "")

	if action_type == GameActionType.GRANT_ITEM:
		var parts = split_item_param(param)
		_item_path = parts[0]
		_item_qty = parts[1]

	if type_dropdown:
		type_dropdown.select(type_dropdown.get_item_index(action_type))

	# Defer so children are resolved in @tool context
	call_deferred("_update_param_ui")
