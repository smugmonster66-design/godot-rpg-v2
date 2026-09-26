# res://scripts/ui/stash/stash_popup.gd
# Full-screen stash/bank popup. Top half shows stash contents, bottom half shows
# player inventory with category tabs, and a transfer bar in the middle.
# Tapping an item opens an ItemInfoPopup with Deposit/Withdraw + Close buttons.
extends Control

signal stash_closed()

const ItemInfoPopupScene = preload("res://scenes/ui/popups/item_info_popup.tscn")

# ============================================================================
# CONFIG
# ============================================================================

@export var grid_item_size: float = 144.0
@export var grid_columns: int = 6
@export var grid_spacing: float = 10.0

# ============================================================================
# STATE
# ============================================================================

var _player: Player = null
var _stash: StashData = null
var _current_category: String = "All"
var _stash_category: String = "All"
var _active_info_popup: Control = null

# ============================================================================
# UI REFERENCES (discovered in _ready)
# ============================================================================

var _backdrop: ColorRect
var _panel: PanelContainer
var _stash_header: Label
var _stash_grid: GridContainer
var _stash_category_tabs: GridContainer
var _inventory_grid: GridContainer
var _category_tabs: GridContainer
var _deposit_button: Button
var _withdraw_button: Button
var _close_button: Button

var _rarity_shader: Shader = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_rarity_shader = load("res://shaders/rarity_border.gdshader")
	_discover_nodes()
	_connect_signals()

func _discover_nodes() -> void:
	_backdrop = find_child("Backdrop", true, false) as ColorRect
	_panel = find_child("Panel", true, false) as PanelContainer
	_stash_header = find_child("StashHeader", true, false) as Label
	_stash_grid = find_child("StashGrid", true, false) as GridContainer
	_stash_category_tabs = find_child("StashCategoryTabs", true, false) as GridContainer
	_inventory_grid = find_child("InventoryGrid", true, false) as GridContainer
	_category_tabs = find_child("CategoryTabs", true, false) as GridContainer
	_deposit_button = find_child("DepositButton", true, false) as Button
	_withdraw_button = find_child("WithdrawButton", true, false) as Button
	_close_button = find_child("CloseButton", true, false) as Button

func _connect_signals() -> void:
	if _deposit_button:
		_deposit_button.hide()
	if _withdraw_button:
		_withdraw_button.hide()
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)
	if _backdrop:
		_backdrop.gui_input.connect(_on_backdrop_input)
	_update_panel_size()
	get_viewport().size_changed.connect(_update_panel_size)

func _update_panel_size() -> void:
	if not _panel:
		return
	var vp = get_viewport().get_visible_rect().size
	var panel_h = int(vp.y * 0.90)
	var margin_v = int((vp.y - panel_h) / 2.0)
	var margin_h = 20
	_panel.offset_left = margin_h
	_panel.offset_top = margin_v
	_panel.offset_right = -margin_h
	_panel.offset_bottom = -margin_v

func _unhandled_input(event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()

# ============================================================================
# PUBLIC API
# ============================================================================

func setup(player: Player, stash: StashData) -> void:
	_player = player
	_stash = stash
	_current_category = "All"
	_stash_category = "All"
	_build_category_tabs(_category_tabs, _current_category, _on_inventory_category_selected)
	_build_category_tabs(_stash_category_tabs, _stash_category, _on_stash_category_selected)
	_update_panel_size()
	_refresh()

# ============================================================================
# REFRESH
# ============================================================================

func _refresh() -> void:
	_populate_stash_grid()
	_populate_inventory_grid()
	_update_stash_header()

func _update_stash_header() -> void:
	if _stash_header and _stash:
		_stash_header.text = "Stash (%d/%d)" % [_stash.get_equipment_count() + _stash.get_consumable_count(), _stash.max_equipment_slots]

# ============================================================================
# STASH GRID
# ============================================================================

func _populate_stash_grid() -> void:
	if not _stash_grid:
		return
	_clear_grid(_stash_grid)
	_stash_grid.columns = grid_columns
	_stash_grid.add_theme_constant_override("h_separation", int(grid_spacing))
	_stash_grid.add_theme_constant_override("v_separation", int(grid_spacing))

	var items = _get_filtered_stash()
	for item in items:
		if item is EquippableItem:
			var cell = _create_item_cell(item, "stash")
			_stash_grid.add_child(cell)
		elif item is ConsumableItem:
			var cell = _create_consumable_cell(item, "stash")
			_stash_grid.add_child(cell)

func _get_filtered_stash() -> Array:
	if _stash_category == "All":
		var all_items: Array = []
		all_items.append_array(_stash.equipment)
		all_items.append_array(_stash.get_consumable_items())
		return all_items

	if _stash_category == "Consumable":
		var result: Array = []
		result.append_array(_stash.get_consumable_items())
		return result

	var filtered: Array = []
	for item in _stash.equipment:
		if item is EquippableItem and item.get_slot_name() == _stash_category:
			filtered.append(item)
	return filtered

# ============================================================================
# INVENTORY GRID
# ============================================================================

func _populate_inventory_grid() -> void:
	if not _inventory_grid:
		return
	_clear_grid(_inventory_grid)
	_inventory_grid.columns = grid_columns
	_inventory_grid.add_theme_constant_override("h_separation", int(grid_spacing))
	_inventory_grid.add_theme_constant_override("v_separation", int(grid_spacing))

	var items = _get_filtered_inventory()
	for item in items:
		if item is EquippableItem:
			var cell = _create_item_cell(item, "inventory")
			_inventory_grid.add_child(cell)
		elif item is ConsumableItem:
			var cell = _create_consumable_cell(item, "inventory")
			_inventory_grid.add_child(cell)

func _get_filtered_inventory() -> Array:
	if _current_category == "All":
		var all_items: Array = []
		all_items.append_array(_player.inventory)
		all_items.append_array(_player.consumables)
		return all_items

	if _current_category == "Consumable":
		var result: Array = []
		result.append_array(_player.consumables)
		return result

	var filtered: Array = []
	for item in _player.inventory:
		if item is EquippableItem and item.get_slot_name() == _current_category:
			filtered.append(item)
	return filtered

# ============================================================================
# GRID CELL CREATION
# ============================================================================

func _create_item_cell(item: EquippableItem, source: String) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(grid_item_size, grid_item_size)

	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(grid_item_size, grid_item_size)
	btn.texture_normal = item.icon
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	wrapper.add_child(btn)

	if _rarity_shader and item.rarity > EquippableItem.Rarity.COMMON:
		var mat = ShaderMaterial.new()
		mat.shader = _rarity_shader
		mat.set_shader_parameter("border_color", ThemeManager.get_rarity_color_enum(item.rarity))
		mat.set_shader_parameter("glow_radius", 4.0)
		mat.set_shader_parameter("glow_softness", 2.0)
		mat.set_shader_parameter("glow_width", 0.6)
		mat.set_shader_parameter("glow_strength", 1.5)
		mat.set_shader_parameter("glow_blend", 0.6)
		mat.set_shader_parameter("glow_saturation", 1.0)
		mat.set_shader_parameter("pulse_speed", 1.0)
		mat.set_shader_parameter("pulse_amount", 0.15)
		btn.material = mat

	RarityGlowHelper.apply_glow(btn, btn.texture_normal, item.get_rarity_name())

	var click_area = Button.new()
	click_area.flat = true
	click_area.position = Vector2.ZERO
	click_area.size = wrapper.custom_minimum_size
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.pressed.connect(_on_item_tapped.bind(item, source))
	wrapper.add_child(click_area)

	if source == "inventory" and _player.is_item_equipped(item):
		btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		var badge = Label.new()
		badge.text = "E"
		badge.position = Vector2(2, 2)
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color.WHITE)
		wrapper.add_child(badge)

	return wrapper

func _create_consumable_cell(item: ConsumableItem, source: String) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(grid_item_size, grid_item_size)

	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(grid_item_size, grid_item_size)
	btn.texture_normal = item.icon
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	wrapper.add_child(btn)

	var click_area = Button.new()
	click_area.flat = true
	click_area.position = Vector2.ZERO
	click_area.size = wrapper.custom_minimum_size
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.pressed.connect(_on_item_tapped.bind(item, source))
	wrapper.add_child(click_area)

	if item.current_stack > 1:
		var stack_label = Label.new()
		stack_label.text = "x%d" % item.current_stack
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack_label.position = Vector2(0, grid_item_size - 20)
		stack_label.size = Vector2(grid_item_size - 4, 20)
		stack_label.add_theme_font_size_override("font_size", 14)
		stack_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		wrapper.add_child(stack_label)

	return wrapper

# ============================================================================
# CATEGORY TABS
# ============================================================================

func _build_category_tabs(grid: GridContainer, active: String, callback: Callable) -> void:
	if not grid:
		return
	for child in grid.get_children():
		child.queue_free()

	var categories = ["All", "Head", "Torso", "Gloves", "Boots", "Main Hand", "Off Hand", "Accessory", "Consumable"]
	for cat in categories:
		var btn = Button.new()
		btn.text = cat
		btn.toggle_mode = true
		btn.button_pressed = (cat == active)
		btn.pressed.connect(callback.bind(cat))
		grid.add_child(btn)

# ============================================================================
# ITEM INFO POPUP
# ============================================================================

func _on_item_tapped(item, source: String) -> void:
	if _active_info_popup and is_instance_valid(_active_info_popup):
		_active_info_popup.queue_free()
		_active_info_popup = null

	var buttons: Array = []
	if source == "inventory":
		if item is EquippableItem and _player.is_item_equipped(item):
			buttons.append({"label": "Equipped", "action": "close"})
		else:
			buttons.append({"label": "Deposit", "action": "deposit"})
	elif source == "stash":
		buttons.append({"label": "Withdraw", "action": "withdraw"})
	buttons.append({"label": "Close", "action": "close"})

	_active_info_popup = ItemInfoPopupScene.instantiate()
	add_child(_active_info_popup)
	_active_info_popup.show_item(item, _player, buttons)
	_active_info_popup.action_pressed.connect(_on_info_action.bind(source))
	_active_info_popup.popup_closed.connect(_on_info_closed)

func _on_info_action(action: String, item, source: String) -> void:
	if action == "deposit":
		_do_deposit(item)
	elif action == "withdraw":
		_do_withdraw(item)
	_close_info_popup()

func _on_info_closed() -> void:
	_close_info_popup()

func _close_info_popup() -> void:
	if _active_info_popup and is_instance_valid(_active_info_popup):
		_active_info_popup.queue_free()
		_active_info_popup = null

# ============================================================================
# TRANSFER LOGIC
# ============================================================================

func _do_deposit(item) -> void:
	if item is EquippableItem:
		if _player.is_item_equipped(item):
			return
		if _stash.add_equipment(item):
			_player.remove_from_inventory(item)
	elif item is ConsumableItem:
		if _stash.add_consumable(item):
			_player.remove_consumable(item)
	_refresh()

func _do_withdraw(item) -> void:
	if item is EquippableItem:
		_stash.remove_equipment(item)
		_player.add_to_inventory(item)
	elif item is ConsumableItem:
		_stash.remove_consumable(item.resource_path, item.current_stack)
		_player.add_consumable(item)
	_refresh()

# ============================================================================
# CATEGORY SELECTION
# ============================================================================

func _on_inventory_category_selected(category: String) -> void:
	_current_category = category
	_sync_tab_buttons(_category_tabs, category)
	_populate_inventory_grid()

func _on_stash_category_selected(category: String) -> void:
	_stash_category = category
	_sync_tab_buttons(_stash_category_tabs, category)
	_populate_stash_grid()
	_update_stash_header()

func _sync_tab_buttons(grid: GridContainer, active: String) -> void:
	if not grid:
		return
	for btn in grid.get_children():
		if btn is Button:
			btn.button_pressed = (btn.text == active)

# ============================================================================
# CLOSE
# ============================================================================

func _on_close_pressed() -> void:
	_close_info_popup()
	stash_closed.emit()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close_pressed()

# ============================================================================
# HELPERS
# ============================================================================

func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()
