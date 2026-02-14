@tool
# res://addons/dungeon_editor/dungeon_definition_editor.gd
# Visual editor for DungeonDefinition resources.
# Reads/writes ONLY the fields that exist on the actual DungeonDefinition class.
extends VBoxContainer

# ============================================================================
# EXTERNAL
# ============================================================================
var editor_interface: EditorInterface = null

# ============================================================================
# STATE
# ============================================================================
var definition: DungeonDefinition = null
var _file_path: String = ""
var _dirty: bool = false

# ============================================================================
# UI REFERENCES
# ============================================================================
var toolbar: HBoxContainer
var name_label: Label
var tab_container: TabContainer
var validation_panel: RichTextLabel
var file_dialog: FileDialog

# Tab roots (for field discovery)
var identity_tab: VBoxContainer
var structure_tab: VBoxContainer
var encounters_tab: VBoxContainer
var events_tab: VBoxContainer
var loot_tab: VBoxContainer
var theme_tab: VBoxContainer
var first_clear_tab: VBoxContainer

# ============================================================================
# COLORS — matched to DungeonEnums.get_node_color()
# ============================================================================
const C_COMBAT := Color(0.8, 0.3, 0.3)
const C_ELITE := Color(0.9, 0.5, 0.1)
const C_BOSS := Color(0.8, 0.1, 0.1)
const C_EVENT := Color(0.6, 0.4, 0.8)
const C_SHOP := Color(0.9, 0.8, 0.2)
const C_REST := Color(0.2, 0.6, 0.9)
const C_TREASURE := Color(1.0, 0.85, 0.0)
const C_SHRINE := Color(0.4, 0.8, 0.8)
const C_OK := Color(0.4, 0.9, 0.4)
const C_WARN := Color(0.9, 0.9, 0.3)
const C_ERR := Color(0.9, 0.3, 0.3)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	name = "DungeonDefinitionEditor"

func _ready():
	_build_ui()
	_set_empty_state()

func _build_ui():
	# --- Toolbar ---
	toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size.y = 36
	add_child(toolbar)

	_add_toolbar_button("New", _on_new)
	_add_toolbar_button("Load", _on_load)
	_add_toolbar_button("Save", _on_save)
	toolbar.add_child(VSeparator.new())
	_add_toolbar_button("Validate", _on_validate)
	_add_toolbar_button("Inspect", _on_inspect_definition)
	toolbar.add_child(VSeparator.new())

	name_label = Label.new()
	name_label.text = "No dungeon loaded"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	toolbar.add_child(name_label)

	add_child(HSeparator.new())

	# --- Tabs ---
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(tab_container)

	_build_identity_tab()
	_build_structure_tab()
	_build_encounters_tab()
	_build_events_tab()
	_build_loot_tab()
	_build_theme_tab()
	_build_first_clear_tab()

	# --- Validation output ---
	add_child(HSeparator.new())
	validation_panel = RichTextLabel.new()
	validation_panel.custom_minimum_size.y = 80
	validation_panel.bbcode_enabled = true
	validation_panel.fit_content = true
	validation_panel.scroll_following = true
	validation_panel.text = ""
	add_child(validation_panel)

	# --- File dialog ---
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tres", "Godot Resource")
	file_dialog.size = Vector2i(700, 500)
	add_child(file_dialog)

func _add_toolbar_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	toolbar.add_child(btn)
	return btn

# ============================================================================
# TAB: IDENTITY
# ============================================================================

func _build_identity_tab():
	identity_tab = _create_tab("Identity")
	var scroll = _wrap_in_scroll(identity_tab)

	_add_section_header(scroll, "Dungeon Identity")
	_add_line_edit(scroll, "dungeon_name", "Dungeon Name")
	_add_line_edit(scroll, "dungeon_id", "Dungeon ID")
	_add_text_edit(scroll, "description", "Description", 80)
	_add_info_label(scroll, "Set the dungeon icon via the Inspector (click Inspect button).")

# ============================================================================
# TAB: STRUCTURE
# ============================================================================

func _build_structure_tab():
	structure_tab = _create_tab("Structure")
	var scroll = _wrap_in_scroll(structure_tab)

	_add_section_header(scroll, "Floor Layout")
	_add_spinbox(scroll, "floor_count", "Total Floors", 6, 15)
	_add_spinbox(scroll, "min_nodes_per_floor", "Min Nodes/Floor", 1, 4)
	_add_spinbox(scroll, "max_nodes_per_floor", "Max Nodes/Floor", 1, 4)

	_add_section_header(scroll, "Difficulty")
	_add_spinbox(scroll, "dungeon_level", "Dungeon Level", 1, 100)
	_add_spinbox(scroll, "dungeon_region", "Region (1–6)", 1, 6)

	_add_section_header(scroll, "Safe Floor Rules")
	_add_checkbox(scroll, "safe_floor_before_boss", "Safe floor before boss")
	_add_checkbox(scroll, "mid_safe_floor", "Mid-dungeon safe floor")

	_add_info_label(scroll, "Safe floors contain only REST and SHOP nodes.\nMid floor index = floor_count / 2.")

# ============================================================================
# TAB: ENCOUNTERS
# ============================================================================

func _build_encounters_tab():
	encounters_tab = _create_tab("Encounters")
	var scroll = _wrap_in_scroll(encounters_tab)

	_add_section_header(scroll, "Combat Encounters (standard fights)")
	_add_pool_list(scroll, "combat_encounters", C_COMBAT)

	_add_section_header(scroll, "Elite Encounters (harder fights, better rewards)")
	_add_pool_list(scroll, "elite_encounters", C_ELITE)

	_add_section_header(scroll, "Boss Encounters (one per boss floor)")
	_add_pool_list(scroll, "boss_encounters", C_BOSS)

	_add_info_label(scroll, "All three pools are Array[CombatEncounter].\nClick 'Edit in Inspector' to drag .tres files into the arrays.")

# ============================================================================
# TAB: EVENTS & SHRINES
# ============================================================================

func _build_events_tab():
	events_tab = _create_tab("Events & Shrines")
	var scroll = _wrap_in_scroll(events_tab)

	_add_section_header(scroll, "Event Pool (Array[DungeonEvent])")
	_add_pool_list(scroll, "event_pool", C_EVENT)
	_add_info_label(scroll, "Each DungeonEvent needs: event_name, event_id, description, choices.\nFloor restrictions via min_floor/max_floor on each event.")

	_add_section_header(scroll, "Shrine Pool (Array[DungeonShrine])")
	_add_pool_list(scroll, "shrine_pool", C_SHRINE)
	_add_info_label(scroll, "Each DungeonShrine needs: shrine_name, blessing_affix.\nOptional: curse_affix for risk/reward tradeoffs.")

# ============================================================================
# TAB: LOOT & ECONOMY
# ============================================================================

func _build_loot_tab():
	loot_tab = _create_tab("Loot & Economy")
	var scroll = _wrap_in_scroll(loot_tab)

	_add_section_header(scroll, "Loot Pool (treasure drops)")
	_add_pool_list(scroll, "loot_pool", C_TREASURE)

	_add_section_header(scroll, "Shop Pool (shop inventory)")
	_add_pool_list(scroll, "shop_pool", C_SHOP)

	_add_section_header(scroll, "Rest Affix Pool (temporary dice affixes at rest sites)")
	_add_pool_list(scroll, "rest_affix_pool", C_REST)

	_add_section_header(scroll, "Economy")
	_add_spinbox(scroll, "gold_per_combat", "Gold per Combat", 0, 999)
	_add_spinbox(scroll, "gold_per_elite", "Gold per Elite", 0, 999)
	_add_spinbox(scroll, "exp_per_combat", "EXP per Combat", 0, 999)
	_add_spinbox(scroll, "exp_per_elite", "EXP per Elite", 0, 999)

# ============================================================================
# TAB: THEME
# ============================================================================

func _build_theme_tab():
	theme_tab = _create_tab("Theme")
	var scroll = _wrap_in_scroll(theme_tab)

	_add_section_header(scroll, "Corridor Textures")
	_add_info_label(scroll, "Drag textures into these fields via the Inspector (click Inspect).")
	_add_texture_preview(scroll, "wall_texture", "Wall Texture")
	_add_texture_preview(scroll, "door_texture", "Door Texture")
	_add_texture_preview(scroll, "floor_texture", "Floor Texture")

	_add_section_header(scroll, "Lighting & Atmosphere")
	_add_color_row(scroll, "fog_color", "Fog Color")
	_add_color_row(scroll, "ambient_color", "Ambient Color")
	_add_color_row(scroll, "torch_color", "Torch Color")

# ============================================================================
# TAB: FIRST CLEAR
# ============================================================================

func _build_first_clear_tab():
	first_clear_tab = _create_tab("First Clear")
	var scroll = _wrap_in_scroll(first_clear_tab)

	_add_section_header(scroll, "First Clear Rewards")
	_add_spinbox(scroll, "first_clear_gold", "Gold", 0, 99999)
	_add_spinbox(scroll, "first_clear_exp", "EXP", 0, 99999)
	_add_info_label(scroll, "First clear item: set via Inspector (first_clear_item export).\nUses LootManager.generate_drop() at dungeon_level/dungeon_region.")

# ============================================================================
# UI WIDGET BUILDERS
# ============================================================================

func _create_tab(title: String) -> VBoxContainer:
	var tab = VBoxContainer.new()
	tab.name = title
	tab_container.add_child(tab)
	return tab

func _wrap_in_scroll(tab: VBoxContainer) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)

	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	scroll.add_child(inner)
	return inner

func _add_section_header(parent: Control, text: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(lbl)
	parent.add_child(margin)

func _add_info_label(parent: Control, text: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(lbl)

func _add_line_edit(parent: Control, field: String, placeholder: String):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = placeholder + ":"
	label.custom_minimum_size.x = 180
	hbox.add_child(label)

	var edit = LineEdit.new()
	edit.name = "Field_" + field
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(new_text: String):
		if definition:
			definition.set(field, new_text)
			_mark_dirty()
	)
	hbox.add_child(edit)
	parent.add_child(hbox)

func _add_text_edit(parent: Control, field: String, placeholder: String, height: int = 60):
	var label = Label.new()
	label.text = placeholder + ":"
	parent.add_child(label)

	var edit = TextEdit.new()
	edit.name = "Field_" + field
	edit.custom_minimum_size.y = height
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = placeholder
	edit.text_changed.connect(func():
		if definition:
			definition.set(field, edit.text)
			_mark_dirty()
	)
	parent.add_child(edit)

func _add_spinbox(parent: Control, field: String, label_text: String,
		min_val: int = 0, max_val: int = 100):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 180
	hbox.add_child(label)

	var spin = SpinBox.new()
	spin.name = "Field_" + field
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = 1
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(val: float):
		if definition:
			definition.set(field, int(val))
			_mark_dirty()
	)
	hbox.add_child(spin)
	parent.add_child(hbox)

func _add_checkbox(parent: Control, field: String, label_text: String):
	var hbox = HBoxContainer.new()
	var cb = CheckBox.new()
	cb.name = "Field_" + field
	cb.text = label_text
	cb.toggled.connect(func(pressed: bool):
		if definition:
			definition.set(field, pressed)
			_mark_dirty()
	)
	hbox.add_child(cb)
	parent.add_child(hbox)

func _add_pool_list(parent: Control, field: String, color: Color):
	var container = VBoxContainer.new()
	container.name = "Pool_" + field

	# Header row: count + buttons
	var header = HBoxContainer.new()
	var count_label = Label.new()
	count_label.name = "PoolCount_" + field
	count_label.text = "0 entries"
	count_label.add_theme_color_override("font_color", color)
	header.add_child(count_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var inspect_btn = Button.new()
	inspect_btn.text = "Edit in Inspector"
	inspect_btn.pressed.connect(func(): _inspect_field(field))
	header.add_child(inspect_btn)

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(func(): _refresh_all())
	header.add_child(refresh_btn)

	container.add_child(header)

	# Item list
	var item_list = ItemList.new()
	item_list.name = "PoolItems_" + field
	item_list.custom_minimum_size.y = 120
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.allow_reselect = true
	item_list.item_clicked.connect(func(index: int, _at: Vector2, _btn: int):
		_inspect_pool_item(field, index)
	)
	container.add_child(item_list)
	parent.add_child(container)

func _add_texture_preview(parent: Control, field: String, label_text: String):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 180
	hbox.add_child(label)

	var preview = TextureRect.new()
	preview.name = "TexPreview_" + field
	preview.custom_minimum_size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(preview)

	var status = Label.new()
	status.name = "TexStatus_" + field
	status.text = "(none)"
	status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hbox.add_child(status)

	parent.add_child(hbox)

func _add_color_row(parent: Control, field: String, label_text: String):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 180
	hbox.add_child(label)

	var swatch = ColorRect.new()
	swatch.name = "ColorSwatch_" + field
	swatch.custom_minimum_size = Vector2(40, 24)
	swatch.color = Color.BLACK
	hbox.add_child(swatch)

	var hex_label = Label.new()
	hex_label.name = "ColorHex_" + field
	hex_label.text = "#000000"
	hex_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(hex_label)

	var edit_btn = Button.new()
	edit_btn.text = "Edit"
	edit_btn.pressed.connect(func(): _inspect_field(field))
	hbox.add_child(edit_btn)

	parent.add_child(hbox)

# ============================================================================
# TOOLBAR ACTIONS
# ============================================================================

func _on_new():
	definition = DungeonDefinition.new()
	definition.dungeon_name = "New Dungeon"
	definition.dungeon_id = "new_dungeon"
	_file_path = ""
	_dirty = true
	_refresh_all()
	_set_validation_text("[color=#88ff88]New dungeon created. Configure and Save.[/color]")

func _on_load():
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Load DungeonDefinition"
	file_dialog.current_dir = "res://resources/dungeon/"

	# Disconnect any previous connection to avoid double-fires
	if file_dialog.file_selected.is_connected(_on_file_loaded):
		file_dialog.file_selected.disconnect(_on_file_loaded)
	file_dialog.file_selected.connect(_on_file_loaded)
	file_dialog.popup_centered()

func _on_file_loaded(path: String):
	var res = load(path)
	if res is DungeonDefinition:
		definition = res
		_file_path = path
		_dirty = false
		_refresh_all()
		_set_validation_text("[color=#88ff88]Loaded: %s[/color]" % path)
	else:
		_set_validation_text("[color=#ff4444]Error: %s is not a DungeonDefinition[/color]" % path)

func _on_save():
	if not definition:
		_set_validation_text("[color=#ff4444]Nothing to save — create or load first.[/color]")
		return

	if _file_path != "":
		_save_to_path(_file_path)
	else:
		file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.title = "Save DungeonDefinition"
		file_dialog.current_dir = "res://resources/dungeon/"
		file_dialog.current_file = (definition.dungeon_id + ".tres") if definition.dungeon_id else "dungeon.tres"

		if file_dialog.file_selected.is_connected(_on_file_saved):
			file_dialog.file_selected.disconnect(_on_file_saved)
		file_dialog.file_selected.connect(_on_file_saved)
		file_dialog.popup_centered()

func _on_file_saved(path: String):
	_file_path = path
	_save_to_path(path)

func _save_to_path(path: String):
	var err = ResourceSaver.save(definition, path)
	if err == OK:
		_dirty = false
		_update_title()
		_set_validation_text("[color=#88ff88]Saved to %s[/color]" % path)
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
	else:
		_set_validation_text("[color=#ff4444]Save failed (error %d)[/color]" % err)

func _on_validate():
	if not definition:
		_set_validation_text("[color=#ffcc44]No dungeon loaded.[/color]")
		return

	var warnings = definition.validate()
	if warnings.is_empty():
		_set_validation_text("[color=#88ff88]✅ Validation passed — no issues found.[/color]")
	else:
		var lines: Array[String] = []
		lines.append("[color=#ffcc44]⚠️ %d warning(s):[/color]" % warnings.size())
		for w in warnings:
			lines.append("[color=#ffaa44]  • %s[/color]" % w)
		_set_validation_text("\n".join(lines))

func _on_inspect_definition():
	if definition and editor_interface:
		editor_interface.inspect_object(definition)

# ============================================================================
# INSPECT HELPERS
# ============================================================================

func _inspect_field(_field: String):
	"""Open the definition in the Inspector."""
	if definition and editor_interface:
		editor_interface.inspect_object(definition)

func _inspect_pool_item(field: String, index: int):
	"""Open a specific pool item in the Inspector."""
	if not definition:
		return
	var pool = definition.get(field)
	if pool is Array and index >= 0 and index < pool.size():
		var item = pool[index]
		if item and editor_interface:
			editor_interface.inspect_object(item)

# ============================================================================
# REFRESH / SYNC
# ============================================================================

func _refresh_all():
	if not definition:
		_set_empty_state()
		return

	_update_title()
	_refresh_field_values()
	_refresh_pools()
	_refresh_theme_previews()

func _set_empty_state():
	if name_label:
		name_label.text = "No dungeon loaded"
	if validation_panel:
		validation_panel.text = ""

func _update_title():
	if not name_label or not definition:
		return
	var title = definition.dungeon_name if definition.dungeon_name else "(unnamed)"
	if _file_path:
		title += "  —  " + _file_path
	if _dirty:
		title += " *"
	name_label.text = title

func _mark_dirty():
	_dirty = true
	_update_title()

func _refresh_field_values():
	if not definition:
		return

	# Identity
	_set_field_value("dungeon_name", definition.dungeon_name)
	_set_field_value("dungeon_id", definition.dungeon_id)
	_set_field_value("description", definition.description)

	# Structure
	_set_field_value("floor_count", definition.floor_count)
	_set_field_value("min_nodes_per_floor", definition.min_nodes_per_floor)
	_set_field_value("max_nodes_per_floor", definition.max_nodes_per_floor)
	_set_field_value("dungeon_level", definition.dungeon_level)
	_set_field_value("dungeon_region", definition.dungeon_region)
	_set_field_value("safe_floor_before_boss", definition.safe_floor_before_boss)
	_set_field_value("mid_safe_floor", definition.mid_safe_floor)

	# Economy
	_set_field_value("gold_per_combat", definition.gold_per_combat)
	_set_field_value("gold_per_elite", definition.gold_per_elite)
	_set_field_value("exp_per_combat", definition.exp_per_combat)
	_set_field_value("exp_per_elite", definition.exp_per_elite)

	# First Clear
	_set_field_value("first_clear_gold", definition.first_clear_gold)
	_set_field_value("first_clear_exp", definition.first_clear_exp)

func _set_field_value(field: String, value: Variant):
	var node = _find_recursive(self, "Field_" + field)
	if not node:
		return
	if node is LineEdit:
		node.text = str(value) if value else ""
	elif node is TextEdit:
		node.text = str(value) if value else ""
	elif node is SpinBox:
		node.set_value_no_signal(float(value))
	elif node is CheckBox:
		node.set_pressed_no_signal(bool(value))

func _find_recursive(parent: Node, target_name: String) -> Control:
	for child in parent.get_children():
		if child.name == target_name:
			return child as Control
		var found = _find_recursive(child, target_name)
		if found:
			return found
	return null

# ============================================================================
# POOL REFRESH
# ============================================================================

func _refresh_pools():
	if not definition:
		return
	_refresh_pool("combat_encounters", _summarize_encounter)
	_refresh_pool("elite_encounters", _summarize_encounter)
	_refresh_pool("boss_encounters", _summarize_encounter)
	_refresh_pool("event_pool", _summarize_event)
	_refresh_pool("shrine_pool", _summarize_shrine)
	_refresh_pool("loot_pool", _summarize_item)
	_refresh_pool("shop_pool", _summarize_item)
	_refresh_pool("rest_affix_pool", _summarize_dice_affix)

func _refresh_pool(field: String, summary_fn: Callable):
	var pool = definition.get(field)
	if not pool is Array:
		return

	var count_node = _find_recursive(self, "PoolCount_" + field)
	if count_node is Label:
		count_node.text = "%d entries" % pool.size()

	var list_node = _find_recursive(self, "PoolItems_" + field)
	if not list_node is ItemList:
		return

	list_node.clear()
	for i in range(pool.size()):
		var item = pool[i]
		if item == null:
			list_node.add_item("[%d] (null)" % i)
			list_node.set_item_custom_fg_color(i, C_ERR)
		else:
			list_node.add_item("[%d] %s" % [i, summary_fn.call(item)])

# --- Summary formatters (match actual resource classes) ---

func _summarize_encounter(enc: Resource) -> String:
	if "encounter_name" in enc:
		var enemies = enc.get("enemies")
		var count: int = enemies.size() if enemies else 0
		return "%s (%d enemies)" % [enc.encounter_name, count]
	return str(enc)

func _summarize_event(event: Resource) -> String:
	if "event_name" in event:
		var choices_arr = event.get("choices")
		var choices: int = choices_arr.size() if choices_arr else 0
		var floor_str = ""
		var mn: int = event.get("min_floor") if "min_floor" in event else 0
		var mx: int = event.get("max_floor") if "max_floor" in event else 99
		if mn > 0 or mx < 99:
			floor_str = " [floors %d–%d]" % [mn, mx]
		return "%s (%d choices)%s" % [event.event_name, choices, floor_str]
	return str(event)

func _summarize_shrine(shrine: Resource) -> String:
	if "shrine_name" in shrine:
		var curse_str = " + curse" if shrine.has_method("has_curse") and shrine.has_curse() else ""
		return "%s (blessing%s)" % [shrine.shrine_name, curse_str]
	return str(shrine)

func _summarize_item(item: Resource) -> String:
	if "item_name" in item:
		var rarity_names = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
		var r: int = item.get("rarity") if "rarity" in item else 0
		var rarity_str = rarity_names[r] if r < rarity_names.size() else "?"
		return "%s (%s)" % [item.item_name, rarity_str]
	return str(item)

func _summarize_dice_affix(affix: Resource) -> String:
	if affix.has_method("get_display_text"):
		return affix.get_display_text()
	if "affix_name" in affix:
		return affix.affix_name
	return str(affix)

# ============================================================================
# THEME PREVIEW REFRESH
# ============================================================================

func _refresh_theme_previews():
	if not definition:
		return

	_refresh_texture_preview("wall_texture", definition.wall_texture)
	_refresh_texture_preview("door_texture", definition.door_texture)
	_refresh_texture_preview("floor_texture", definition.floor_texture)

	_refresh_color_swatch("fog_color", definition.fog_color)
	_refresh_color_swatch("ambient_color", definition.ambient_color)
	_refresh_color_swatch("torch_color", definition.torch_color)

func _refresh_texture_preview(field: String, tex: Texture2D):
	var preview = _find_recursive(self, "TexPreview_" + field)
	var status = _find_recursive(self, "TexStatus_" + field)
	if preview is TextureRect:
		preview.texture = tex
	if status is Label:
		if tex:
			status.text = tex.resource_path.get_file() if tex.resource_path else "(embedded)"
			status.add_theme_color_override("font_color", C_OK)
		else:
			status.text = "(none)"
			status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _refresh_color_swatch(field: String, color: Color):
	var swatch = _find_recursive(self, "ColorSwatch_" + field)
	var hex_label = _find_recursive(self, "ColorHex_" + field)
	if swatch is ColorRect:
		swatch.color = color
	if hex_label is Label:
		hex_label.text = "#" + color.to_html(false)

# ============================================================================
# VALIDATION DISPLAY
# ============================================================================

func _set_validation_text(bbcode: String):
	if validation_panel:
		validation_panel.clear()
		validation_panel.append_text(bbcode)
