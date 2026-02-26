# res://scripts/debug/debug_loot_panel.gd
# Debug loot testing panel. Toggle with = key.
# Place in a CanvasLayer above your game UI. Remove before release.
extends Control

# ============================================================================
# CONFIGURATION
# ============================================================================

const TOGGLE_KEY := KEY_EQUAL
const UI_SCALE := 2  # Multiplier for all sizes

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
var _raw_slot_dropdown: OptionButton
var _raw_rarity_dropdown: OptionButton
var _raw_level_slider: HSlider
var _raw_level_label: Label
var _raw_region_spin: SpinBox
var _raw_generate_button: Button

# -- Shared --
var _results_scroll: ScrollContainer
var _results_vbox: VBoxContainer
var _clear_button: Button

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

func _font_size(base: int) -> int:
	return base * UI_SCALE


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
	title.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.normal))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.normal))
	close_btn.pressed.connect(func():
		_shown = false
		_home_position = position
		position = _OFFSCREEN)
	title_hbox.add_child(close_btn)

	root_vbox.add_child(HSeparator.new())

	# -- Tabs --
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.theme_type_variation = &"caption"
	root_vbox.add_child(_tab_container)

	_build_table_tab()
	_build_raw_tab()

	# -- Results --
	root_vbox.add_child(HSeparator.new())

	var results_header := HBoxContainer.new()
	root_vbox.add_child(results_header)

	var results_label := Label.new()
	results_label.text = "Results"
	results_label.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.normal))
	results_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_header.add_child(results_label)

	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
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
	_table_dropdown.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
	vbox.add_child(_table_dropdown)

	var level_hbox := HBoxContainer.new()
	vbox.add_child(level_hbox)
	level_hbox.add_child(_label("Level:"))
	_table_level_slider = HSlider.new()
	_table_level_slider.min_value = 1
	_table_level_slider.max_value = 100
	_table_level_slider.value = 15
	_table_level_slider.step = 1
	_table_level_slider.custom_minimum_size.y = _sf(16)
	_table_level_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table_level_slider.value_changed.connect(func(v): _table_level_label.text = str(int(v)))
	level_hbox.add_child(_table_level_slider)
	_table_level_label = Label.new()
	_table_level_label.text = "15"
	_table_level_label.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
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
	_table_region_spin.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
	row.add_child(_table_region_spin)
	row.add_child(_label("Rolls:"))
	_table_roll_count_spin = SpinBox.new()
	_table_roll_count_spin.min_value = 1
	_table_roll_count_spin.max_value = 50
	_table_roll_count_spin.value = 1
	_table_roll_count_spin.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
	row.add_child(_table_roll_count_spin)

	var rar_hbox := HBoxContainer.new()
	vbox.add_child(rar_hbox)
	rar_hbox.add_child(_label("Rarity Override:"))
	_table_rarity_dropdown = OptionButton.new()
	_table_rarity_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table_rarity_dropdown.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
	rar_hbox.add_child(_table_rarity_dropdown)

	_table_roll_button = Button.new()
	_table_roll_button.text = "Roll Loot Table"
	_table_roll_button.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.normal))
	_table_roll_button.pressed.connect(_on_roll_table)
	vbox.add_child(_table_roll_button)


func _build_raw_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "Raw Item"
	vbox.add_theme_constant_override("separation", _s(6))
	_tab_container.add_child(vbox)

	vbox.add_child(_label("Equip Slot:"))
	_raw_slot_dropdown = OptionButton.new()
	_raw_slot_dropdown.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
	vbox.add_child(_raw_slot_dropdown)

	var rar_hbox := HBoxContainer.new()
	vbox.add_child(rar_hbox)
	rar_hbox.add_child(_label("Rarity:"))
	_raw_rarity_dropdown = OptionButton.new()
	_raw_rarity_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raw_rarity_dropdown.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
	rar_hbox.add_child(_raw_rarity_dropdown)

	var level_hbox := HBoxContainer.new()
	vbox.add_child(level_hbox)
	level_hbox.add_child(_label("Level:"))
	_raw_level_slider = HSlider.new()
	_raw_level_slider.min_value = 1
	_raw_level_slider.max_value = 100
	_raw_level_slider.value = 15
	_raw_level_slider.step = 1
	_raw_level_slider.custom_minimum_size.y = _sf(16)
	_raw_level_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raw_level_slider.value_changed.connect(func(v): _raw_level_label.text = str(int(v)))
	level_hbox.add_child(_raw_level_slider)
	_raw_level_label = Label.new()
	_raw_level_label.text = "15"
	_raw_level_label.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
	_raw_level_label.custom_minimum_size.x = _sf(30)
	level_hbox.add_child(_raw_level_label)

	var reg_hbox := HBoxContainer.new()
	vbox.add_child(reg_hbox)
	reg_hbox.add_child(_label("Region:"))
	_raw_region_spin = SpinBox.new()
	_raw_region_spin.min_value = 1
	_raw_region_spin.max_value = 6
	_raw_region_spin.value = 1
	_raw_region_spin.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
	reg_hbox.add_child(_raw_region_spin)

	_raw_generate_button = Button.new()
	_raw_generate_button.text = "Generate Item"
	_raw_generate_button.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.normal))
	_raw_generate_button.pressed.connect(_on_generate_raw)
	vbox.add_child(_raw_generate_button)


# ============================================================================
# DROPDOWN POPULATION
# ============================================================================

func _populate_dropdowns() -> void:
	_refresh_table_list()

	var rarity_names := ["Auto (Template)", "Common", "Uncommon", "Rare", "Epic", "Legendary"]
	for dropdown in [_table_rarity_dropdown, _raw_rarity_dropdown]:
		dropdown.clear()
		for i in rarity_names.size():
			dropdown.add_item(rarity_names[i], i)
	_raw_rarity_dropdown.selected = 3

	_raw_slot_dropdown.clear()
	var slot_names := ["Head", "Torso", "Gloves", "Boots", "Main Hand", "Off Hand", "Heavy", "Accessory"]
	for i in slot_names.size():
		_raw_slot_dropdown.add_item(slot_names[i], i)


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

				if rarity_idx > 0:
					item.rarity = rarity_idx - 1
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
	var slot_idx: int = _raw_slot_dropdown.selected
	var rarity_idx: int = _raw_rarity_dropdown.selected
	var level: int = int(_raw_level_slider.value)
	var region: int = int(_raw_region_spin.value)

	var template := EquippableItem.new()
	template.item_name = _generate_item_name(slot_idx, rarity_idx)
	template.equip_slot = slot_idx as EquippableItem.EquipSlot
	template.rarity = (rarity_idx - 1) if rarity_idx > 0 else EquippableItem.Rarity.RARE
	template.item_level = level
	template.region = region

	_add_result_line("[color=gray]-- Generating %s (Lv.%d R%d %s) --[/color]" % [
		template.item_name, level, region,
		EquippableItem.Rarity.keys()[template.rarity]])

	if _has_loot_manager():
		var result := LootManager.generate_drop(template, level, region)
		var item: EquippableItem = result.get("item")
		if item:
			_add_item_result(item)
			var player := _get_player()
			if player:
				player.add_to_inventory(item)
				_add_result_line("[color=green]Added to inventory[/color]")
			return

	template.initialize_affixes()
	_add_item_result(template)

	var player := _get_player()
	if player:
		player.add_to_inventory(template)
		_add_result_line("[color=green]Added to inventory[/color]")


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
	rtl.add_theme_font_size_override("normal_font_size", _font_size(ThemeManager.FONT_SIZES.small))
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
	l.add_theme_font_size_override("font_size", _font_size(ThemeManager.FONT_SIZES.caption))
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


func _generate_item_name(slot_idx: int, rarity_idx: int) -> String:
	var slot_names := ["Helm", "Chestpiece", "Gauntlets", "Greaves",
					   "Blade", "Shield", "Greatsword", "Ring"]
	var prefixes := ["", "Sturdy", "Fine", "Runed", "Mythic"]
	var slot_name: String = slot_names[slot_idx] if slot_idx < slot_names.size() else "Item"
	var prefix: String = prefixes[rarity_idx] if rarity_idx < prefixes.size() else "Debug"
	if prefix.is_empty():
		return "Debug %s" % slot_name
	return "%s %s" % [prefix, slot_name]


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
