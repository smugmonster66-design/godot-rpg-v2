# res://scripts/ui/smithing/smithing_popup.gd
# Smithing popup — Salvage items for components, Upgrade items to player level.
# Opened via NPC dialogue (game_action:7:<config_path>).
extends Control

signal smithing_closed

# ============================================================================
# CONFIGURATION
# ============================================================================
@export var grid_item_size: float = 144.0
@export var grid_columns: int = 4
@export var grid_spacing: float = 10.0
@export var detail_icon_size: float = 160.0

# ============================================================================
# STATE
# ============================================================================
var _player: Player = null
var _config: SmithingConfig = null
var _selected_item: EquippableItem = null
var _locked_affixes: Dictionary = {}  # int index → bool locked
var _is_item_equipped: bool = false

# ============================================================================
# UI REFERENCES (discovered dynamically via find_child)
# ============================================================================
var backdrop: ColorRect
var panel: PanelContainer
var title_label: Label
var item_icon: TextureRect
var item_name_label: Label
var item_subtitle_label: Label
var base_affix_list: VBoxContainer
var inherent_affix_list: VBoxContainer
var rolled_affix_lock_rows: VBoxContainer
var resource_cost_bar: HBoxContainer
var upgrade_button: Button
var salvage_button: Button
var close_button: Button
var category_tabs: GridContainer
var inventory_grid: GridContainer
var confirm_dialog: ConfirmationDialog

var _rarity_shader: Shader = null

func _discover_nodes() -> void:
	backdrop = find_child("Backdrop", true, false) as ColorRect
	panel = find_child("Panel", true, false) as PanelContainer
	title_label = find_child("TitleLabel", true, false) as Label
	item_icon = find_child("ItemIcon", true, false) as TextureRect
	item_name_label = find_child("ItemNameLabel", true, false) as Label
	item_subtitle_label = find_child("SubtitleLabel", true, false) as Label
	base_affix_list = find_child("BaseAffixList", true, false) as VBoxContainer
	inherent_affix_list = find_child("InherentAffixList", true, false) as VBoxContainer
	rolled_affix_lock_rows = find_child("RolledAffixLockRows", true, false) as VBoxContainer
	resource_cost_bar = find_child("ResourceCostBar", true, false) as HBoxContainer
	upgrade_button = find_child("UpgradeButton", true, false) as Button
	salvage_button = find_child("SalvageButton", true, false) as Button
	close_button = find_child("CloseButton", true, false) as Button
	category_tabs = find_child("CategoryTabs", true, false) as GridContainer
	inventory_grid = find_child("InventoryGrid", true, false) as GridContainer
	confirm_dialog = find_child("ConfirmDialog", true, false) as ConfirmationDialog

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_rarity_shader = load("res://shaders/rarity_border.gdshader")
	backdrop.gui_input.connect(_on_backdrop_input)
	close_button.pressed.connect(_on_close_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	salvage_button.pressed.connect(_on_salvage_pressed)
	# Set panel min height to 3/4 viewport
	_update_panel_min_height()
	get_viewport().size_changed.connect(_update_panel_min_height)

func _update_panel_min_height() -> void:
	# Panel uses full-rect anchors (0-1). Set offsets to center at 3/4 viewport height.
	var vp = get_viewport().get_visible_rect().size
	var panel_h = int(vp.y * 0.75)
	var margin_v = int((vp.y - panel_h) / 2.0)
	var margin_h = 20  # small horizontal padding
	panel.offset_left = margin_h
	panel.offset_top = margin_v
	panel.offset_right = -margin_h
	panel.offset_bottom = -margin_v

func _unhandled_input(event: InputEvent) -> void:
	# Consume any input that wasn't handled by our GUI, so the map can't receive it
	if visible:
		get_viewport().set_input_as_handled()

func show_smithing(player: Player, config: SmithingConfig) -> void:
	_player = player
	_config = config
	_selected_item = null
	_locked_affixes.clear()
	_build_category_tabs()
	_populate_inventory_grid()
	_update_detail_panel()
	_update_resource_cost_bar()
	_update_panel_min_height()
	show()

# ============================================================================
# INVENTORY GRID
# ============================================================================

var _current_category: String = "All"

func _build_category_tabs() -> void:
	for child in category_tabs.get_children():
		child.queue_free()

	var categories = ["All", "Head", "Torso", "Gloves", "Boots", "Main Hand", "Off Hand", "Heavy", "Accessory"]
	for cat in categories:
		var btn = Button.new()
		btn.text = cat
		btn.toggle_mode = true
		btn.button_pressed = (cat == _current_category)
		btn.pressed.connect(_on_category_selected.bind(cat))
		btn.theme_type_variation = &"smithing_button"
		category_tabs.add_child(btn)

func _on_category_selected(category: String) -> void:
	_current_category = category
	for btn in category_tabs.get_children():
		if btn is Button:
			btn.button_pressed = (btn.text == category)
	_populate_inventory_grid()

func _populate_inventory_grid() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()

	# Collect all items: inventory + equipped
	var items: Array[EquippableItem] = []
	for item in _player.inventory:
		if _matches_category(item):
			items.append(item)
	for slot_name in _player.equipment:
		var item = _player.equipment[slot_name]
		if item is EquippableItem and _matches_category(item):
			items.append(item)

	for item in items:
		var wrapper = _create_grid_item(item)
		inventory_grid.add_child(wrapper)

func _matches_category(item: EquippableItem) -> bool:
	if _current_category == "All":
		return true
	var slot_name = "Heavy" if item.is_heavy_weapon() else item.get_slot_name()
	return slot_name == _current_category

func _create_grid_item(item: EquippableItem) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(grid_item_size, grid_item_size)

	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(grid_item_size, grid_item_size)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	if item.icon:
		btn.texture_normal = item.icon
	else:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.4, 0.4, 0.4))
		btn.texture_normal = ImageTexture.create_from_image(img)

	# Rarity border shader
	if _rarity_shader:
		var mat = ShaderMaterial.new()
		mat.shader = _rarity_shader
		var color = ThemeManager.get_rarity_color(item.get_rarity_name())
		mat.set_shader_parameter("border_color", color)
		mat.set_shader_parameter("glow_radius", 4.0)
		mat.set_shader_parameter("glow_softness", 2.0)
		mat.set_shader_parameter("glow_width", 0.6)
		mat.set_shader_parameter("glow_strength", 1.5)
		mat.set_shader_parameter("glow_blend", 0.6)
		mat.set_shader_parameter("glow_saturation", 1.0)
		mat.set_shader_parameter("pulse_speed", 1.0)
		mat.set_shader_parameter("pulse_amount", 0.15)
		btn.material = mat

	wrapper.add_child(btn)

	# Rarity glow behind icon
	RarityGlowHelper.apply_glow(btn, btn.texture_normal, item.get_rarity_name())

	# Click area
	var click_area = Button.new()
	click_area.flat = true
	click_area.position = Vector2.ZERO
	click_area.size = wrapper.custom_minimum_size
	click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.pressed.connect(_on_item_selected.bind(item))
	wrapper.add_child(click_area)

	# Equipped badge
	if _player.is_item_equipped(item):
		btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		var badge = Label.new()
		badge.text = "E"
		badge.add_theme_color_override("font_color", ThemeManager.PALETTE.text_primary)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(20, 20)
		badge.position = Vector2(2, 2)

		var badge_bg = Panel.new()
		var style = ThemeManager._flat_box(
			Color(ThemeManager.PALETTE.success.r, ThemeManager.PALETTE.success.g,
				ThemeManager.PALETTE.success.b, 0.9),
			Color(0, 0, 0, 0), 4, 0)
		badge_bg.add_theme_stylebox_override("panel", style)
		badge_bg.custom_minimum_size = Vector2(20, 20)
		badge_bg.position = Vector2(2, 2)
		badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.add_child(badge_bg)
		wrapper.add_child(badge)

	# Selection highlight
	if item == _selected_item:
		var highlight = ColorRect.new()
		highlight.color = Color(1, 1, 1, 0.2)
		highlight.position = Vector2.ZERO
		highlight.size = wrapper.custom_minimum_size
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.add_child(highlight)

	return wrapper

# ============================================================================
# ITEM SELECTION & DETAIL PANEL
# ============================================================================

func _on_item_selected(item: EquippableItem) -> void:
	_selected_item = item
	_locked_affixes.clear()
	_is_item_equipped = _player.is_item_equipped(item)
	_update_detail_panel()
	_populate_inventory_grid()  # Refresh to show selection highlight

func _update_detail_panel() -> void:
	if not _selected_item:
		item_name_label.text = "Select an item"
		item_name_label.remove_theme_color_override("font_color")
		item_subtitle_label.text = ""
		item_icon.texture = null
		item_icon.material = null
		_clear_container(base_affix_list)
		_clear_container(inherent_affix_list)
		_clear_container(rolled_affix_lock_rows)
		_clear_container(resource_cost_bar)
		upgrade_button.disabled = true
		salvage_button.disabled = true
		return

	var item = _selected_item

	# Name
	var rarity_color = ThemeManager.get_rarity_color(item.get_rarity_name())
	item_name_label.text = item.item_name
	item_name_label.add_theme_color_override("font_color", rarity_color)

	# Subtitle
	var slot_display = "Heavy Weapon" if item.is_heavy_weapon() else item.get_slot_name()
	item_subtitle_label.text = "%s · Lv. %d" % [slot_display, item.item_level]
	item_subtitle_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)

	# Icon with rarity shader
	item_icon.custom_minimum_size = Vector2(detail_icon_size, detail_icon_size)
	item_icon.texture = item.icon if item.icon else null
	if _rarity_shader and item_icon.texture:
		var mat = ShaderMaterial.new()
		mat.shader = _rarity_shader
		mat.set_shader_parameter("border_color", rarity_color)
		mat.set_shader_parameter("glow_radius", 6.0)
		mat.set_shader_parameter("glow_softness", 2.0)
		mat.set_shader_parameter("glow_width", 0.6)
		mat.set_shader_parameter("glow_strength", 2.0)
		mat.set_shader_parameter("glow_blend", 0.6)
		mat.set_shader_parameter("glow_saturation", 1.0)
		mat.set_shader_parameter("pulse_speed", 1.0)
		mat.set_shader_parameter("pulse_amount", 0.15)
		item_icon.material = mat
	else:
		item_icon.material = null

	# Base affixes (read-only)
	_clear_container(base_affix_list)
	for affix in item.base_affixes:
		var label = _create_affix_label(affix, ThemeManager.PALETTE.text_secondary)
		base_affix_list.add_child(label)

	# Inherent affixes (read-only, green tint)
	_clear_container(inherent_affix_list)
	for affix in item.inherent_affixes:
		var label = _create_affix_label(affix, Color(0.4, 0.85, 0.4))
		inherent_affix_list.add_child(label)

	# Rolled affixes with lock toggles
	_build_affix_lock_rows()

	# Update costs and buttons
	_update_resource_cost_bar()

	# Upgrade: disabled if item already at player level or higher
	upgrade_button.disabled = (item.item_level >= _player.level)
	upgrade_button.text = "Upgrade to Lv. %d" % _player.level

	# Salvage: disabled if item is equipped
	salvage_button.disabled = _is_item_equipped
	if _is_item_equipped:
		salvage_button.tooltip_text = "Unequip item first"
	else:
		salvage_button.tooltip_text = ""

# ============================================================================
# AFFIX LOCK ROWS
# ============================================================================

func _build_affix_lock_rows() -> void:
	_clear_container(rolled_affix_lock_rows)
	if not _selected_item:
		return

	# Count non-unique rolled affixes (exclude legendary unique which is always at the end)
	var rolled = _selected_item.rolled_affixes
	var affix_count = _selected_item.get_affix_count_for_rarity()

	for i in range(rolled.size()):
		# Skip the unique affix slot for legendary items (last entry past normal count)
		if _selected_item.rarity == EquippableItem.Rarity.LEGENDARY and _selected_item.unique_affix and i >= affix_count:
			# Show unique affix as read-only
			var unique_row = _create_affix_label(rolled[i], ThemeManager.PALETTE.rarity_legendary)
			rolled_affix_lock_rows.add_child(unique_row)
			continue

		var affix = rolled[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Affix description
		var affix_label = RichTextLabel.new()
		affix_label.bbcode_enabled = true
		affix_label.fit_content = true
		affix_label.scroll_active = false
		affix_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color_hex = "daa520"
		affix_label.text = "[color=#%s]%s[/color]" % [color_hex, _get_affix_display_text(affix)]
		row.add_child(affix_label)

		# Lock toggle button with cost shown inline
		var is_locked = _locked_affixes.get(i, false)
		var lock_cost = _get_lock_cost_for_slot(i)
		var cost_text = _format_lock_cost_text(lock_cost)

		var lock_btn = Button.new()
		lock_btn.text = ("Locked (%s)" % cost_text) if is_locked else ("Lock (%s)" % cost_text)
		lock_btn.toggle_mode = true
		lock_btn.button_pressed = is_locked
		lock_btn.custom_minimum_size = Vector2(100, 0)
		lock_btn.pressed.connect(_toggle_lock.bind(i))

		if is_locked:
			lock_btn.add_theme_color_override("font_color", ThemeManager.PALETTE.warning)

		row.add_child(lock_btn)

		rolled_affix_lock_rows.add_child(row)

func _toggle_lock(index: int) -> void:
	_locked_affixes[index] = not _locked_affixes.get(index, false)
	if not _locked_affixes[index]:
		_locked_affixes.erase(index)
	_build_affix_lock_rows()
	_update_resource_cost_bar()

# ============================================================================
# COST DISPLAY
# ============================================================================

func _get_lock_cost_for_slot(slot_index: int) -> Dictionary:
	"""Lock cost per affix slot: 0=uncommon, 1=rare, 2=epic."""
	match slot_index:
		0: return {&"uncommon": 1}
		1: return {&"rare": 1}
		2: return {&"epic": 1}
		_: return {&"epic": 1}

func _calculate_total_upgrade_cost() -> Dictionary:
	"""Base upgrade cost + per-slot lock costs for all locked affixes."""
	if not _selected_item or not _config:
		return {}
	var total = _config.get_upgrade_base_cost(_selected_item.rarity).duplicate()
	for idx in _locked_affixes:
		if _locked_affixes[idx]:
			var lock_cost = _get_lock_cost_for_slot(idx)
			for comp_id in lock_cost:
				total[comp_id] = total.get(comp_id, 0) + lock_cost[comp_id]
	return total

func _update_resource_cost_bar() -> void:
	"""Consolidated current/required display: '2/5 Cmn  0/1 Epc' etc."""
	_clear_container(resource_cost_bar)
	if not _config or not _player:
		return

	var total_cost = _calculate_total_upgrade_cost() if _selected_item else {}

	for comp in _config.components:
		if not comp:
			continue
		var current = _player.get_component_count(comp.component_id)
		var required = total_cost.get(comp.component_id, 0)

		# Skip components with 0 current and 0 required
		if current == 0 and required == 0:
			continue

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)

		var rarity_color = _get_rarity_color_for_tier(comp.rarity_tier)
		var has_enough = current >= required if required > 0 else true

		if comp.icon:
			var icon_rect = TextureRect.new()
			icon_rect.texture = comp.icon
			icon_rect.custom_minimum_size = Vector2(28, 28)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(icon_rect)

		var lbl = Label.new()
		lbl.theme_type_variation = &"smithing_component"
		if required > 0:
			var text_color = "55ff55" if has_enough else "ff5555"
			# Show as current/required with color coding
			if comp.icon:
				lbl.text = "%d/%d" % [current, required]
			else:
				lbl.text = "%d/%d %s" % [current, required, _comp_short_name(comp)]
			lbl.add_theme_color_override("font_color", Color(text_color))
		else:
			if comp.icon:
				lbl.text = str(current)
			else:
				lbl.text = "%d %s" % [current, _comp_short_name(comp)]
			lbl.add_theme_color_override("font_color", rarity_color)

		hbox.add_child(lbl)
		resource_cost_bar.add_child(hbox)

	# Update upgrade button
	if _selected_item:
		if _selected_item.item_level >= _player.level:
			upgrade_button.disabled = true
			upgrade_button.text = "Already at level"
		else:
			var can_afford = _player.can_afford_components(total_cost)
			upgrade_button.disabled = not can_afford
			upgrade_button.text = "Upgrade to Lv. %d" % _player.level

# ============================================================================
# UPGRADE
# ============================================================================

func _on_upgrade_pressed() -> void:
	if not _selected_item or not _config:
		return

	var total_cost = _calculate_total_upgrade_cost()

	if not _player.can_afford_components(total_cost):
		return

	var locked_count = _locked_affixes.size()
	# Show confirmation
	confirm_dialog.dialog_text = "Upgrade %s from Lv. %d to Lv. %d?\n\nLocked affixes: %d" % [
		_selected_item.item_name, _selected_item.item_level, _player.level, locked_count]
	confirm_dialog.title = "Confirm Upgrade"

	# Disconnect previous connections
	if confirm_dialog.confirmed.get_connections().size() > 0:
		for conn in confirm_dialog.confirmed.get_connections():
			confirm_dialog.confirmed.disconnect(conn.callable)

	confirm_dialog.confirmed.connect(_execute_upgrade, CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()

func _execute_upgrade() -> void:
	if not _selected_item or not _config:
		return

	var total_cost = _calculate_total_upgrade_cost()

	if not _player.spend_component_dict(total_cost):
		return

	# Build locked indices array
	var locked_indices: Array[int] = []
	for idx in _locked_affixes:
		if _locked_affixes[idx]:
			locked_indices.append(idx)

	_selected_item.upgrade_to_level(_player.level, locked_indices)

	# Refresh UI
	_locked_affixes.clear()
	_update_detail_panel()
	_update_resource_cost_bar()
	_populate_inventory_grid()

# ============================================================================
# SALVAGE
# ============================================================================

func _on_salvage_pressed() -> void:
	if not _selected_item or not _config or _is_item_equipped:
		return

	var yields = _config.get_salvage_yield(_selected_item.rarity)
	var yield_parts: Array[String] = []
	for comp_id in yields:
		var comp = _config.get_component_by_id(comp_id)
		var short = _comp_short_name(comp) if comp else str(comp_id)
		yield_parts.append("%d %s" % [yields[comp_id], short])

	confirm_dialog.dialog_text = "Salvage %s?\n\nThis will destroy the item.\nYou will receive: %s" % [
		_selected_item.item_name, ", ".join(yield_parts)]
	confirm_dialog.title = "Confirm Salvage"

	if confirm_dialog.confirmed.get_connections().size() > 0:
		for conn in confirm_dialog.confirmed.get_connections():
			confirm_dialog.confirmed.disconnect(conn.callable)

	confirm_dialog.confirmed.connect(_execute_salvage, CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()

func _execute_salvage() -> void:
	if not _selected_item or not _config:
		return

	var yields = _config.get_salvage_yield(_selected_item.rarity)

	# Award components
	for comp_id in yields:
		_player.add_components(comp_id, yields[comp_id])

	# Remove from inventory
	_player.remove_from_inventory(_selected_item)

	# Clear selection
	_selected_item = null
	_locked_affixes.clear()
	_is_item_equipped = false

	_update_detail_panel()
	_update_resource_cost_bar()
	_populate_inventory_grid()

# ============================================================================
# CLOSE / BACKDROP
# ============================================================================

func _on_close_pressed() -> void:
	smithing_closed.emit()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close_pressed()

# ============================================================================
# HELPERS
# ============================================================================

func _clear_container(container: Control) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

func _create_affix_label(affix: Affix, color: Color) -> RichTextLabel:
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.theme_type_variation = &"smithing_affix"
	var color_hex = color.to_html(false)
	var text = _get_affix_display_text(affix)
	rtl.text = "[color=#%s]%s[/color]" % [color_hex, text]
	DescriptionParser.set_bbcode(rtl, "[color=#%s]%s[/color]" % [color_hex, text])
	return rtl

func _get_affix_display_text(affix: Affix) -> String:
	if affix.get_resolved_description() != "":
		return affix.get_resolved_description()
	var val_str = affix.get_rolled_value_string() if affix.has_scaling() else ""
	if val_str != "":
		return "%s %s" % [affix.affix_name, val_str]
	return affix.affix_name

func _format_cost_with_icons(cost: Dictionary) -> HBoxContainer:
	"""Create an HBox showing cost with icons (if available) or text."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	for comp_id in cost:
		var amount = cost[comp_id]
		var comp = _config.get_component_by_id(comp_id) if _config else null
		if comp and comp.icon:
			var icon_rect = TextureRect.new()
			icon_rect.texture = comp.icon
			icon_rect.custom_minimum_size = Vector2(16, 16)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(icon_rect)
			var lbl = Label.new()
			lbl.text = str(amount)
			lbl.theme_type_variation = &"smithing_cost"
			lbl.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
			hbox.add_child(lbl)
		else:
			var lbl = Label.new()
			var short = _comp_short_name(comp) if comp else str(comp_id).capitalize()
			lbl.text = "%d %s" % [amount, short]
			lbl.theme_type_variation = &"smithing_cost"
			lbl.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
			hbox.add_child(lbl)
	return hbox

func _format_lock_cost_text(cost: Dictionary) -> String:
	"""Plain text for lock button: '1 Unc', '1 Rre', etc."""
	var parts: Array[String] = []
	for comp_id in cost:
		var amount = cost[comp_id]
		var comp = _config.get_component_by_id(comp_id) if _config else null
		var short = _comp_short_name(comp) if comp else str(comp_id)
		parts.append("%d %s" % [amount, short])
	return ", ".join(parts) if parts.size() > 0 else "Free"

func _comp_short_name(comp: CraftingComponentDefinition) -> String:
	"""Return abbreviation if set, otherwise display_name."""
	if comp and comp.abbreviation != "":
		return comp.abbreviation
	if comp:
		return comp.display_name
	return "?"

func _get_rarity_color_for_tier(tier: int) -> Color:
	match tier:
		0: return ThemeManager.PALETTE.rarity_common
		1: return ThemeManager.PALETTE.rarity_uncommon
		2: return ThemeManager.PALETTE.rarity_rare
		3: return ThemeManager.PALETTE.rarity_epic
		4: return ThemeManager.PALETTE.rarity_legendary
		_: return ThemeManager.PALETTE.text_primary
