# res://scripts/debug/debug_loot_panel.gd
# Debug loot testing panel. Toggle with = key.
# Place in a CanvasLayer above your game UI. Remove before release.
extends Control

# ============================================================================
# CONFIGURATION
# ============================================================================

const TOGGLE_KEY := KEY_EQUAL
const UI_SCALE := 2  # Multiplier for all sizes
const ITEM_BASE_PATH := "res://resources/items/"
const CONSUMABLE_BASE_PATH := "res://resources/consumables/"

## If true, panel starts hidden.
@export var start_hidden: bool = true

# ============================================================================
# NODE REFERENCES (built in _ready)
# ============================================================================
var _bg: Panel
var _tab_container: TabContainer

# -- Tab 1: Loot Table --
var _table_dropdown: OptionButton
var _table_level_slider: HSlider
var _table_level_label: Label
var _table_region_spin: SpinBox
var _table_rarity_dropdown: OptionButton
var _table_roll_button: Button
var _table_roll_count_spin: SpinBox

# -- Tab 2: Raw Item --
var _raw_region_spin: SpinBox
var _raw_slot_dropdown: OptionButton
var _raw_item_dropdown: OptionButton
var _raw_rarity_dropdown: OptionButton
var _raw_level_slider: HSlider
var _raw_level_label: Label
var _raw_generate_button: Button

# -- Tab 3: Consumables --
var _con_region_spin: SpinBox
var _con_tier_dropdown: OptionButton
var _con_item_dropdown: OptionButton
var _con_count_spin: SpinBox
var _con_add_button: Button

# -- Shared --
var _results_scroll: ScrollContainer
var _results_vbox: VBoxContainer
var _clear_button: Button

# Populated by _scan_region(). slot_name -> Array of {name, path}
var _items_by_slot: Dictionary = {}

# Populated by _scan_consumable_region(). tier_folder -> Array of {name, path}
var _consumables_by_tier: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	var w := 480 * UI_SCALE
	var h := 520 * UI_SCALE
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true

	_bg = Panel.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bg)

	_build_ui()
	_populate_dropdowns()
	_apply_debug_style()

	set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 12)

	call_deferred("_deferred_initial_hide")


var _shown := true
var _home_position := Vector2.ZERO
const _OFFSCREEN := Vector2(-9999, -9999)


func _deferred_initial_hide() -> void:
	_home_position = position
	if start_hidden:
		_shown = false
		position = _OFFSCREEN


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == TOGGLE_KEY:
			_shown = not _shown
			if _shown:
				position = _home_position
			else:
				_home_position = position
				position = _OFFSCREEN
			get_viewport().set_input_as_handled()


# ============================================================================
# SCALED HELPERS
# ============================================================================

func _s(val: int) -> int:
	return val * UI_SCALE

func _sf(val: float) -> float:
	return val * UI_SCALE


# ============================================================================
# UI CONSTRUCTION
# ============================================================================

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", _s(12))
	margin.add_theme_constant_override("margin_right", _s(12))
	margin.add_theme_constant_override("margin_top", _s(12))
	margin.add_theme_constant_override("margin_bottom", _s(12))
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", _s(6))
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(root_vbox)

	# -- Title bar --
	var title_hbox := HBoxContainer.new()
	root_vbox.add_child(title_hbox)

	var title := Label.new()
	title.text = "Loot Debug (=)"
	title.theme_type_variation = &"normal"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func():
		_shown = false
		_home_position = position
		position = _OFFSCREEN)
	title_hbox.add_child(close_btn)

	root_vbox.add_child(HSeparator.new())

	# -- Tabs --
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_tab_container)

	_build_table_tab()
	_build_raw_tab()
	_build_consumable_tab()

	# -- Results --
	root_vbox.add_child(HSeparator.new())

	var results_header := HBoxContainer.new()
	root_vbox.add_child(results_header)

	var results_label := Label.new()
	results_label.text = "Results"
	results_label.theme_type_variation = &"normal"
	results_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_header.add_child(results_label)

	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.pressed.connect(_clear_results)
	results_header.add_child(_clear_button)

	_results_scroll = ScrollContainer.new()
	_results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_scroll.custom_minimum_size.y = _sf(180)
	root_vbox.add_child(_results_scroll)

	_results_vbox = VBoxContainer.new()
	_results_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_vbox.add_theme_constant_override("separation", _s(4))
	_results_scroll.add_child(_results_vbox)


func _build_table_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "Loot Tables"
	vbox.add_theme_constant_override("separation", _s(6))
	_tab_container.add_child(vbox)

	vbox.add_child(_label("Loot Table:"))
	_table_dropdown = OptionButton.new()
	vbox.add_child(_table_dropdown)

	var level_hbox := HBoxContainer.new()
	vbox.add_child(level_hbox)
	level_hbox.add_child(_label("Level:"))
	_table_level_slider = HSlider.new()
	_table_level_slider.min_value = 1
	_table_level_slider.max_value = 100
	_table_level_slider.value = 1
	_table_level_slider.step = 1
	_table_level_slider.custom_minimum_size.y = _sf(16)
	_table_level_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table_level_slider.value_changed.connect(func(v): _table_level_label.text = str(int(v)))
	level_hbox.add_child(_table_level_slider)
	_table_level_label = Label.new()
	_table_level_label.text = "1"
	_table_level_label.theme_type_variation = &"caption"
	_table_level_label.custom_minimum_size.x = _sf(30)
	level_hbox.add_child(_table_level_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _s(12))
	vbox.add_child(row)
	row.add_child(_label("Region:"))
	_table_region_spin = SpinBox.new()
	_table_region_spin.min_value = 1
	_table_region_spin.max_value = 6
	_table_region_spin.value = 1
	row.add_child(_table_region_spin)
	row.add_child(_label("Rolls:"))
	_table_roll_count_spin = SpinBox.new()
	_table_roll_count_spin.min_value = 1
	_table_roll_count_spin.max_value = 50
	_table_roll_count_spin.value = 1
	row.add_child(_table_roll_count_spin)

	var rar_hbox := HBoxContainer.new()
	vbox.add_child(rar_hbox)
	rar_hbox.add_child(_label("Rarity Override:"))
	_table_rarity_dropdown = OptionButton.new()
	_table_rarity_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rar_hbox.add_child(_table_rarity_dropdown)

	_table_roll_button = Button.new()
	_table_roll_button.text = "Roll Loot Table"
	_table_roll_button.pressed.connect(_on_roll_table)
	vbox.add_child(_table_roll_button)


func _build_raw_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "Raw Item"
	vbox.add_theme_constant_override("separation", _s(6))
	_tab_container.add_child(vbox)

	# Region spinner — drives which region_N folder to scan
	var reg_hbox := HBoxContainer.new()
	vbox.add_child(reg_hbox)
	reg_hbox.add_child(_label("Region:"))
	_raw_region_spin = SpinBox.new()
	_raw_region_spin.min_value = 1
	_raw_region_spin.max_value = 6
	_raw_region_spin.value = 1
	_raw_region_spin.value_changed.connect(_on_raw_region_changed)
	reg_hbox.add_child(_raw_region_spin)

	vbox.add_child(_label("Slot:"))
	_raw_slot_dropdown = OptionButton.new()
	_raw_slot_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raw_slot_dropdown.item_selected.connect(_on_raw_slot_selected)
	vbox.add_child(_raw_slot_dropdown)

	vbox.add_child(_label("Item:"))
	_raw_item_dropdown = OptionButton.new()
	_raw_item_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_raw_item_dropdown)

	vbox.add_child(_label("Rarity:"))
	_raw_rarity_dropdown = OptionButton.new()
	_raw_rarity_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_raw_rarity_dropdown)

	var level_hbox := HBoxContainer.new()
	vbox.add_child(level_hbox)
	level_hbox.add_child(_label("Level:"))
	_raw_level_slider = HSlider.new()
	_raw_level_slider.min_value = 1
	_raw_level_slider.max_value = 100
	_raw_level_slider.value = 1
	_raw_level_slider.step = 1
	_raw_level_slider.custom_minimum_size.y = _sf(16)
	_raw_level_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raw_level_slider.value_changed.connect(func(v): _raw_level_label.text = str(int(v)))
	level_hbox.add_child(_raw_level_slider)
	_raw_level_label = Label.new()
	_raw_level_label.text = "1"
	_raw_level_label.theme_type_variation = &"caption"
	_raw_level_label.custom_minimum_size.x = _sf(30)
	level_hbox.add_child(_raw_level_label)

	_raw_generate_button = Button.new()
	_raw_generate_button.text = "Generate Item"
	_raw_generate_button.pressed.connect(_on_generate_raw)
	vbox.add_child(_raw_generate_button)


# ============================================================================
# TAB 3: CONSUMABLES
# ============================================================================

func _build_consumable_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "Consumables"
	vbox.add_theme_constant_override("separation", _s(6))
	_tab_container.add_child(vbox)

	# Region spinner
	var reg_hbox := HBoxContainer.new()
	vbox.add_child(reg_hbox)
	reg_hbox.add_child(_label("Region:"))
	_con_region_spin = SpinBox.new()
	_con_region_spin.min_value = 1
	_con_region_spin.max_value = 6
	_con_region_spin.value = 1
	_con_region_spin.value_changed.connect(_on_con_region_changed)
	reg_hbox.add_child(_con_region_spin)

	# Tier dropdown
	vbox.add_child(_label("Tier:"))
	_con_tier_dropdown = OptionButton.new()
	_con_tier_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_con_tier_dropdown.item_selected.connect(_on_con_tier_selected)
	vbox.add_child(_con_tier_dropdown)

	# Item dropdown
	vbox.add_child(_label("Item:"))
	_con_item_dropdown = OptionButton.new()
	_con_item_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_con_item_dropdown)

	# Count spinner
	var count_hbox := HBoxContainer.new()
	vbox.add_child(count_hbox)
	count_hbox.add_child(_label("Count:"))
	_con_count_spin = SpinBox.new()
	_con_count_spin.min_value = 1
	_con_count_spin.max_value = 20
	_con_count_spin.value = 1
	count_hbox.add_child(_con_count_spin)

	# Add button
	_con_add_button = Button.new()
	_con_add_button.text = "Add to Player"
	_con_add_button.pressed.connect(_on_add_consumable)
	vbox.add_child(_con_add_button)


# ============================================================================
# CONSUMABLE SCANNING
# ============================================================================

# Display names for tier folders
const TIER_DISPLAY_NAMES := {
	"restoratives": "T1 Restoratives",
	"combat_preps": "T2 Combat Preps",
	"dice_elixirs": "T3 Dice Elixirs",
	"inscriptions": "T4 Inscriptions",
	"curios": "T5 Curios",
}

# Scan order
const TIER_FOLDER_ORDER: Array[String] = [
	"restoratives", "combat_preps", "dice_elixirs", "inscriptions", "curios"
]

func _scan_consumable_region(region: int) -> void:
	_consumables_by_tier.clear()
	var region_path := CONSUMABLE_BASE_PATH + "region_%d/" % region
	var dir := DirAccess.open(region_path)
	if not dir:
		push_warning("DebugLootPanel: could not open %s" % region_path)
		return

	# Scan in defined order so dropdown is predictable
	for folder: String in TIER_FOLDER_ORDER:
		var folder_path := region_path + folder + "/"
		var folder_dir := DirAccess.open(folder_path)
		if not folder_dir:
			continue
		var items: Array = _scan_consumable_folder(folder_path)
		if not items.is_empty():
			_consumables_by_tier[folder] = items

	if _consumables_by_tier.is_empty():
		push_warning("DebugLootPanel: no consumables found in %s" % region_path)


func _scan_consumable_folder(path: String) -> Array:
	var results: Array = []
	var dir := DirAccess.open(path)
	if not dir:
		return results

	# Collect filenames first to avoid iterator corruption
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()

	for file: String in files:
		var full_path := path + file
		var res := ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res != null and res is ConsumableItem:
			var ci: ConsumableItem = res as ConsumableItem
			results.append({"name": ci.item_name, "path": full_path})

	results.sort_custom(func(a, b): return a["name"] < b["name"])
	return results


# ============================================================================
# CONSUMABLE DROPDOWN POPULATION
# ============================================================================

func _refresh_consumable_tiers() -> void:
	_scan_consumable_region(int(_con_region_spin.value))
	_con_tier_dropdown.clear()

	if _consumables_by_tier.is_empty():
		_con_tier_dropdown.add_item("(No consumables found)")
		_con_tier_dropdown.disabled = true
		_con_item_dropdown.clear()
		_con_item_dropdown.disabled = true
		return

	_con_tier_dropdown.disabled = false
	for folder: String in TIER_FOLDER_ORDER:
		if _consumables_by_tier.has(folder):
			var display: String = TIER_DISPLAY_NAMES.get(folder, folder)
			_con_tier_dropdown.add_item(display)
			# Store the folder key in metadata so we can look it up on selection
			var idx: int = _con_tier_dropdown.item_count - 1
			_con_tier_dropdown.set_item_metadata(idx, folder)

	# Select first tier and populate items
	if _con_tier_dropdown.item_count > 0:
		_con_tier_dropdown.selected = 0
		var first_folder: String = _con_tier_dropdown.get_item_metadata(0)
		_populate_consumable_items(first_folder)


func _populate_consumable_items(tier_folder: String) -> void:
	_con_item_dropdown.clear()
	var items: Array = _consumables_by_tier.get(tier_folder, [])
	if items.is_empty():
		_con_item_dropdown.add_item("(No items)")
		_con_item_dropdown.disabled = true
		return

	_con_item_dropdown.disabled = false
	for entry: Dictionary in items:
		_con_item_dropdown.add_item(entry["name"])


func _on_con_region_changed(_value: float) -> void:
	_refresh_consumable_tiers()


func _on_con_tier_selected(idx: int) -> void:
	var folder: String = _con_tier_dropdown.get_item_metadata(idx)
	_populate_consumable_items(folder)


# ============================================================================
# CONSUMABLE ADD ACTION
# ============================================================================

func _on_add_consumable() -> void:
	var player := _get_player()
	if not player:
		_add_result_line("[color=red]No player found[/color]")
		return

	if not player.has_method("add_consumable"):
		_add_result_line("[color=red]Player.add_consumable() not found -- apply player.gd patch first[/color]")
		return

	var tier_idx: int = _con_tier_dropdown.selected
	if tier_idx < 0:
		_add_result_line("[color=red]No tier selected[/color]")
		return

	var tier_folder: String = _con_tier_dropdown.get_item_metadata(tier_idx)
	var item_idx: int = _con_item_dropdown.selected
	var items: Array = _consumables_by_tier.get(tier_folder, [])

	if item_idx < 0 or item_idx >= items.size():
		_add_result_line("[color=red]No item selected[/color]")
		return

	var entry: Dictionary = items[item_idx]
	var count: int = int(_con_count_spin.value)

	_add_result_line("[color=gray]-- Adding %dx %s --[/color]" % [count, entry["name"]])

	for _i in count:
		var loaded := ResourceLoader.load(entry["path"], "", ResourceLoader.CACHE_MODE_IGNORE)
		if not loaded or not loaded is ConsumableItem:
			_add_result_line("[color=red]  Failed to load: %s[/color]" % entry["path"])
			continue
		var ci: ConsumableItem = loaded.duplicate() as ConsumableItem
		player.add_consumable(ci)

	# Display what we added
	var loaded_for_display := ResourceLoader.load(entry["path"], "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded_for_display and loaded_for_display is ConsumableItem:
		_add_consumable_result(loaded_for_display as ConsumableItem, count)

	_add_result_line("[color=green]Added %dx %s to player[/color]" % [count, entry["name"]])


func _add_consumable_result(ci: ConsumableItem, count: int) -> void:
	var tier_names := ["Restorative", "Combat Prep", "Dice Elixir", "Inscription", "Curio"]
	var tier_name: String = tier_names[ci.tier] if ci.tier < tier_names.size() else "Unknown"
	var rarity_color := _get_rarity_hex(ci.rarity)

	_add_result_line("  [color=%s]%s[/color] x%d [%s, %dg]" % [
		rarity_color, ci.item_name, count, tier_name, ci.base_value])

	# Show effects based on tier
	match ci.tier:
		ConsumableItem.ConsumableTier.RESTORATIVE:
			var effects: Array[String] = []
			if ci.heal_amount > 0:
				effects.append("+%d HP" % ci.heal_amount)
			if ci.heal_percent > 0.0:
				effects.append("+%d%% HP" % int(ci.heal_percent * 100))
			if ci.mana_amount > 0:
				effects.append("+%d Mana" % ci.mana_amount)
			if ci.barrier_amount > 0:
				effects.append("+%d Barrier" % ci.barrier_amount)
			if ci.cleanse_debuffs:
				effects.append("Cleanse%s" % (
					" (%d)" % ci.cleanse_count if ci.cleanse_count > 0 else " all"))
			if not effects.is_empty():
				_add_result_line("    %s" % " | ".join(effects))

		ConsumableItem.ConsumableTier.COMBAT_PREP:
			for affix: Affix in ci.granted_affixes:
				if affix:
					_add_result_line("    Affix: %s (%s)" % [
						affix.affix_name, affix.get_category_name()])

		ConsumableItem.ConsumableTier.DICE_ELIXIR:
			_add_result_line("    Filter: %s" % ci.dice_target_filter)
			for da: DiceAffix in ci.granted_dice_affixes:
				if da:
					_add_result_line("    DiceAffix: %s" % da.affix_name)

		ConsumableItem.ConsumableTier.INSCRIPTION:
			if ci.inscription_affix:
				_add_result_line("    Inscribes: %s" % ci.inscription_affix.affix_name)
				_add_result_line("    %s" % ci.inscription_affix.description)

	if ci.flavor_text and not ci.flavor_text.is_empty():
		_add_result_line("    [color=gray][i]%s[/i][/color]" % ci.flavor_text)


# ============================================================================
# ITEM SCANNING
# ============================================================================

# Scans res://resources/items/region_N/ and builds _items_by_slot.
# Each slot folder name becomes a key; .tres files within are the items.
func _scan_region(region: int) -> void:
	_items_by_slot.clear()
	var region_path := ITEM_BASE_PATH + "region_%d/" % region
	var dir := DirAccess.open(region_path)
	if not dir:
		push_warning("DebugLootPanel: could not open %s" % region_path)
		return

	dir.list_dir_begin()
	var slot_folder := dir.get_next()
	while slot_folder != "":
		if dir.current_is_dir():
			var slot_path := region_path + slot_folder + "/"
			var slot_items := _scan_slot_folder(slot_path)
			if not slot_items.is_empty():
				_items_by_slot[slot_folder] = slot_items
		slot_folder = dir.get_next()
	dir.list_dir_end()

	if _items_by_slot.is_empty():
		push_warning("DebugLootPanel: no items found in %s" % region_path)


func _scan_slot_folder(path: String) -> Array:
	var results: Array = []
	var dir := DirAccess.open(path)
	if not dir:
		return results
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var full_path := path + fname
			var res := ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if res != null and res.has_method("get_slot_name") and res.get("item_name") != null:
				results.append({ "name": (res as EquippableItem).item_name, "path": full_path })
		fname = dir.get_next()
	dir.list_dir_end()
	results.sort_custom(func(a, b): return a["name"] < b["name"])
	return results


# ============================================================================
# DROPDOWN POPULATION
# ============================================================================

func _populate_dropdowns() -> void:
	_refresh_table_list()

	var rarity_names := ["Random", "Common", "Uncommon", "Rare", "Epic", "Legendary"]
	for dropdown in [_table_rarity_dropdown, _raw_rarity_dropdown]:
		dropdown.clear()
		for i in rarity_names.size():
			dropdown.add_item(rarity_names[i], i)
	_raw_rarity_dropdown.selected = 0

	_refresh_raw_slots()
	_refresh_consumable_tiers()


func _refresh_raw_slots() -> void:
	_scan_region(int(_raw_region_spin.value))
	_raw_slot_dropdown.clear()
	var slot_names: Array = _items_by_slot.keys()
	slot_names.sort()
	for slot_name in slot_names:
		_raw_slot_dropdown.add_item(slot_name)
	if not slot_names.is_empty():
		_populate_raw_items_for_slot(slot_names[0])
	else:
		_raw_item_dropdown.clear()
		_raw_item_dropdown.disabled = true


func _populate_raw_items_for_slot(slot_name: String) -> void:
	_raw_item_dropdown.clear()
	var items: Array = _items_by_slot.get(slot_name, [])
	for entry in items:
		_raw_item_dropdown.add_item(entry["name"])
	_raw_item_dropdown.disabled = items.is_empty()


func _on_raw_region_changed(_value: float) -> void:
	_refresh_raw_slots()


func _on_raw_slot_selected(idx: int) -> void:
	_populate_raw_items_for_slot(_raw_slot_dropdown.get_item_text(idx))


func _refresh_table_list() -> void:
	_table_dropdown.clear()
	if not _has_loot_manager():
		_table_dropdown.add_item("(LootManager not found)")
		_table_dropdown.disabled = true
		return

	var names: Array[String] = LootManager.get_all_table_names()
	if names.is_empty():
		_table_dropdown.add_item("(No loot tables loaded)")
		_table_dropdown.disabled = true
		return

	names.sort()
	for n in names:
		_table_dropdown.add_item(n)
	_table_dropdown.disabled = false


# ============================================================================
# ROLL ACTIONS
# ============================================================================

func _on_roll_table() -> void:
	if not _has_loot_manager():
		_add_result_line("[color=red]LootManager not available[/color]")
		return

	var table_name: String = _table_dropdown.get_item_text(_table_dropdown.selected)
	var level: int = int(_table_level_slider.value)
	var region: int = int(_table_region_spin.value)
	var roll_count: int = int(_table_roll_count_spin.value)
	var rarity_idx: int = _table_rarity_dropdown.selected

	_add_result_line("[color=gray]-- Rolling '%s' x%d (Lv.%d R%d) --[/color]" % [
		table_name, roll_count, level, region])

	var player: Player = _get_player()
	var items_added := 0

	for _i in roll_count:
		var results := LootManager.roll_loot(table_name, {}, level, region)

		for result in results:
			if result.get("type") == "item":
				var item: EquippableItem = result.get("item")
				if not item:
					continue

				# Rarity: 0 = Random, 1-5 = specific override
				var use_rarity: int
				if rarity_idx == 0:
					use_rarity = _roll_random_rarity()
				else:
					use_rarity = rarity_idx - 1

				item.rarity = use_rarity
				item.item_affixes.clear()
				item.inherent_affixes.clear()
				item.rolled_affixes.clear()
				item.initialize_affixes()

				_add_item_result(item)

				if player:
					player.add_to_inventory(item)
					items_added += 1

			elif result.get("type") == "currency":
				var amount: int = result.get("amount", 0)
				_add_result_line("  %d Gold" % amount)
				if player:
					player.gold += amount

	if items_added > 0:
		_add_result_line("[color=green]Added %d item(s) to inventory[/color]" % items_added)
	elif not player:
		_add_result_line("[color=yellow]No player - items displayed only[/color]")


func _on_generate_raw() -> void:
	var slot_name: String = _raw_slot_dropdown.get_item_text(_raw_slot_dropdown.selected)
	var item_idx: int = _raw_item_dropdown.selected
	var rarity_idx: int = _raw_rarity_dropdown.selected
	var level: int = int(_raw_level_slider.value)
	var region: int = int(_raw_region_spin.value)

	var items: Array = _items_by_slot.get(slot_name, [])
	if item_idx < 0 or item_idx >= items.size():
		_add_result_line("[color=red]No item selected[/color]")
		return

	var entry: Dictionary = items[item_idx]
	var loaded := ResourceLoader.load(entry["path"], "", ResourceLoader.CACHE_MODE_IGNORE)
	if not loaded:
		_add_result_line("[color=red]Failed to load: %s[/color]" % entry["path"])
		return

	var item: EquippableItem = loaded.duplicate()
	item.item_level = level
	item.region = region

	# Rarity: 0 = Random, 1-5 = specific override
	var use_rarity: int
	if rarity_idx == 0:
		use_rarity = _roll_random_rarity()
	else:
		use_rarity = rarity_idx - 1
	item.rarity = use_rarity

	item.item_affixes.clear()
	item.inherent_affixes.clear()
	item.rolled_affixes.clear()
	item.initialize_affixes()

	var rarity_name: String = EquippableItem.Rarity.keys()[item.rarity]
	_add_result_line("[color=gray]-- Spawning %s (Lv.%d R%d %s) --[/color]" % [
		entry["name"], level, region, rarity_name])

	_add_item_result(item)

	var player := _get_player()
	if player:
		player.add_to_inventory(item)
		_add_result_line("[color=green]Added to inventory[/color]")
	else:
		_add_result_line("[color=yellow]No player - displayed only[/color]")


# ============================================================================
# RESULT DISPLAY
# ============================================================================

func _add_item_result(item: EquippableItem) -> void:
	var rarity_name: String = str(EquippableItem.Rarity.keys()[item.rarity])
	var rarity_color := _get_rarity_hex(item.rarity)

	_add_result_line("  [color=%s]%s[/color] [Lv.%d %s %s]" % [
		rarity_color, item.item_name, item.item_level,
		rarity_name, item.get_slot_name()])

	if item.item_affixes.is_empty():
		_add_result_line("    [color=gray](no affixes)[/color]")
	else:
		for affix in item.item_affixes:
			if not affix:
				continue
			var line := "    "

			if affix.has_scaling():
				var val_str := affix.get_rolled_value_string()
				var range_str := affix.get_value_range_string()
				line += "%s %s [%s]" % [val_str, affix.affix_name, range_str]
			else:
				line += "%s (static)" % affix.affix_name

			if affix.proc_chance > 0.0:
				line += " | proc:%d%%" % int(affix.proc_chance * 100)

			if affix.has_scaling() and affix.effect_number == 0.0:
				line = "[color=red]ZERO: %s[/color]" % line

			_add_result_line(line)


func _add_result_line(bbcode_text: String) -> void:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.text = bbcode_text
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.theme_type_variation = &"small"
	_results_vbox.add_child(rtl)

	await get_tree().process_frame
	_results_scroll.scroll_vertical = int(_results_scroll.get_v_scroll_bar().max_value)


func _clear_results() -> void:
	for child in _results_vbox.get_children():
		child.queue_free()


# ============================================================================
# HELPERS
# ============================================================================

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"caption"
	return l


func _has_loot_manager() -> bool:
	if Engine.get_main_loop() is SceneTree:
		return Engine.get_main_loop().root.has_node("LootManager")
	return false


func _get_player() -> Player:
	if Engine.get_main_loop() is SceneTree:
		var root = Engine.get_main_loop().root
		if root.has_node("GameManager"):
			var gm = root.get_node("GameManager")
			if gm.get("player"):
				return gm.player
	return null


# Weighted random rarity: Common 40%, Uncommon 30%, Rare 18%, Epic 9%, Legendary 3%
# Weighted random rarity: Common 40%, Uncommon 30%, Rare 18%, Epic 12%
# Legendary is excluded — those are bespoke uniques from the world legendary pool
const RARITY_WEIGHTS: Array[float] = [40.0, 30.0, 18.0, 12.0]


func _roll_random_rarity() -> int:
	var total := 0.0
	for w in RARITY_WEIGHTS:
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	for i in RARITY_WEIGHTS.size():
		cumulative += RARITY_WEIGHTS[i]
		if roll <= cumulative:
			return i
	return 0


func _get_rarity_hex(rarity: int) -> String:
	if ThemeManager:
		var rarity_name: String = str(EquippableItem.Rarity.keys()[rarity])
		var c: Color = ThemeManager.get_rarity_color(rarity_name)
		return c.to_html(false)
	match rarity:
		0: return "aaaaaa"
		1: return "55cc55"
		2: return "5599ff"
		3: return "cc55ff"
		4: return "ffaa33"
		_: return "ffffff"


# ============================================================================
# STYLE
# ============================================================================

func _apply_debug_style() -> void:
	var bg_color := Color(0.08, 0.07, 0.12, 0.95)
	var border_color := Color(0.5, 0.4, 0.2, 0.8)
	if ThemeManager:
		bg_color = ThemeManager.PALETTE.bg_elevated
		border_color = ThemeManager.PALETTE.warning
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(_s(2))
	style.set_corner_radius_all(_s(6))
	style.set_content_margin_all(_s(4))
	_bg.add_theme_stylebox_override("panel", style)
