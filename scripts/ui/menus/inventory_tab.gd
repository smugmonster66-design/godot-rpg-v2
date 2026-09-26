# inventory_tab.gd - Inventory management tab with equipment slot preview
# v4 — Item details via ItemInfoPopup; equipment slots at top; category bar at bottom.
# Self-registers with parent, emits signals upward
extends Control

const ItemInfoPopupScene = preload("res://scenes/ui/popups/item_info_popup.tscn")

# ============================================================================
# RARITY SHADER CONFIGURATION
# ============================================================================
@export var use_rarity_shaders: bool = true

@export_group("Shader Settings")

## How many pixels outward the shader searches for alpha edges
@export_range(1.0, 20.0) var glow_radius: float = 4.0

## Falloff curve power: low = wide soft spread, high = tight sharp edge
@export_range(0.5, 4.0) var glow_softness: float = 2.0

## What fraction of the radius the glow fills (0 = hairline at edge, 1 = full radius)
@export_range(0.0, 1.0) var glow_width: float = 0.6

## Overall brightness multiplier for the glow
@export_range(0.0, 5.0) var glow_strength: float = 1.5

## Tint vs additive mix (0 = pure additive bloom, 1 = pure color tint)
@export_range(0.0, 1.0) var glow_blend: float = 0.6

## Color intensity of the glow (0 = white/gray, 1 = normal, 2 = oversaturated)
@export_range(0.0, 2.0) var glow_saturation: float = 1.0

## How fast the glow pulses (0 = no animation)
@export_range(0.0, 5.0) var pulse_speed: float = 1.0

## How much the brightness oscillates when pulsing
@export_range(0.0, 1.0) var pulse_amount: float = 0.15

@export_group("Rarity Glow")
@export var grid_glow_config: RarityGlowConfig


@export_group("Grid Item Size")
@export var grid_item_size: float = 80.0
@export var grid_columns: int = 5
@export var grid_spacing: float = 10.0


# ============================================================================
# SIGNALS (emitted upward)
# Variant-typed: items can be EquippableItem (equipment) or Dictionary (consumables)
# ============================================================================
signal refresh_requested()
signal data_changed()
signal item_selected(item)
signal item_used(item)
signal item_equipped(item)

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
## Currently selected item — EquippableItem, Dictionary, or null.
var selected_item = null
var item_buttons: Array[Control] = []
var category_buttons: Array[Button] = []

# UI references
var inventory_grid: GridContainer

# Equipment slot display
var slot_buttons: Dictionary = {}  # slot_name -> EquipSlotButton

# Current filter
var current_category: String = "All"

# Shader resources
var rarity_shader: Shader = null

# Item info popup
var _active_info_popup: Control = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")  # Self-register
	add_to_group("player_menu_tab_content")  # Register as tab content
	await get_tree().process_frame

	# Load rarity shader
	rarity_shader = load("res://shaders/rarity_border.gdshader")

	_discover_ui_elements()
	print("🎒 InventoryTab: Ready")

func _discover_ui_elements():
	# Find inventory grid WITHIN THIS TAB (not global tree)
	var grids = []
	for child in find_children("*", "GridContainer", true, false):
		if child.is_in_group("inventory_grid"):
			grids.append(child)

	if grids.size() > 0:
		inventory_grid = grids[0]
		print("  ✓ Inventory grid registered")
	else:
		print("  ⚠️ No inventory_grid found")

	# Find category buttons WITHIN THIS TAB
	for button in find_children("*", "Button", true, false):
		if button.is_in_group("inventory_category_button"):
			category_buttons.append(button)
			var cat_name = button.get_meta("category_name", "")
			if cat_name:
				button.toggled.connect(_on_category_button_toggled.bind(cat_name))
				print("  ✓ Connected category button: %s" % cat_name)

	# Discover equipment slots
	_discover_equipment_slots()

	_update_category_button_visuals()

func _discover_equipment_slots():
	var slot_nodes := find_children("*", "EquipSlotButton", true, false)

	for slot_node: EquipSlotButton in slot_nodes:
		slot_buttons[slot_node.slot_name] = slot_node
		slot_node.slot_clicked.connect(_on_equip_slot_clicked)
		print("  ✓ Discovered inventory equipment slot: %s" % slot_node.slot_name)

	if slot_buttons.is_empty():
		print("  ⚠️ No EquipSlotButton instances found in inventory tab")

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh"""
	player = p_player

	if player:
		# Connect to player inventory signals if available
		if player.has_signal("inventory_changed") and not player.inventory_changed.is_connected(refresh):
			player.inventory_changed.connect(refresh)
		# Connect equipment changes so slots update
		if player.has_signal("equipment_changed") and not player.equipment_changed.is_connected(_on_player_equipment_changed):
			player.equipment_changed.connect(_on_player_equipment_changed)

	refresh()

func refresh():
	"""Refresh all inventory displays"""
	if not player:
		return

	print("🎒 Refreshing inventory - Total items: %d, Category: %s" % [player.inventory.size(), current_category])

	_update_equipment_slots()
	_rebuild_inventory_grid()

func on_external_data_change():
	"""Called when other tabs modify player data"""
	refresh()

# ============================================================================
# EQUIPMENT SLOT DISPLAY
# ============================================================================

func _update_equipment_slots():
	if not player:
		return
	for slot_name in slot_buttons:
		var slot: EquipSlotButton = slot_buttons[slot_name]
		var item: EquippableItem = player.equipment.get(slot_name)
		if item:
			slot.apply_equippable(item)
		else:
			slot.clear()
	_update_offhand_state()

func _update_offhand_state():
	var offhand_slot: EquipSlotButton = slot_buttons.get("Off Hand")
	if not offhand_slot:
		return

	var main_hand_item: EquippableItem = player.equipment.get("Main Hand")
	var is_heavy = main_hand_item != null and main_hand_item.is_heavy_weapon()

	if is_heavy:
		offhand_slot.modulate = Color(1, 1, 1, 0.5)
		offhand_slot.slot_button.disabled = true
		offhand_slot.slot_button.tooltip_text = "Blocked by two-handed weapon"
	else:
		offhand_slot.modulate = Color(1, 1, 1, 1)
		offhand_slot.slot_button.disabled = false
		offhand_slot.slot_button.tooltip_text = ""

func _on_equip_slot_clicked(slot_name: String):
	var item: EquippableItem = player.equipment.get(slot_name) if player else null
	if item:
		# Show popup for equipped item with Unequip option
		_show_item_info_popup(item)
	else:
		# Filter inventory to show items for this slot
		current_category = slot_name
		_update_category_button_visuals()
		_rebuild_inventory_grid()
		# Update the button group to match
		for button in category_buttons:
			var cat_name = button.get_meta("category_name", "")
			button.set_pressed_no_signal(cat_name == slot_name)

func _on_player_equipment_changed(_slot, _item):
	_update_equipment_slots()
	_rebuild_inventory_grid()

# ============================================================================
# ITEM INFO POPUP
# ============================================================================

func _show_item_info_popup(item) -> void:
	_close_info_popup()

	var buttons: Array = []
	if item is EquippableItem:
		if _is_item_equipped(item):
			buttons.append({"label": "Unequip", "action": "unequip"})
		else:
			if item.can_equip(player):
				buttons.append({"label": "Equip", "action": "equip"})
			else:
				buttons.append({"label": "Cannot Equip", "action": "close"})
	elif _is_consumable(item):
		buttons.append({"label": "Use", "action": "use"})
	buttons.append({"label": "Close", "action": "close"})

	_active_info_popup = ItemInfoPopupScene.instantiate()
	add_child(_active_info_popup)
	_active_info_popup.show_item(item, player, buttons)
	_active_info_popup.action_pressed.connect(_on_info_action)
	_active_info_popup.popup_closed.connect(_on_info_closed)

func _on_info_action(action: String, item) -> void:
	match action:
		"equip":
			_do_equip(item)
		"unequip":
			_do_unequip(item)
		"use":
			_do_use(item)
	_close_info_popup()

func _on_info_closed() -> void:
	_close_info_popup()

func _close_info_popup() -> void:
	if _active_info_popup and is_instance_valid(_active_info_popup):
		_active_info_popup.queue_free()
		_active_info_popup = null

# ============================================================================
# EQUIP / UNEQUIP / USE ACTIONS
# ============================================================================

func _do_equip(item) -> void:
	if not player or not item:
		return

	var success = player.equip_item(item)
	if success:
		print("✅ Equipped: %s" % _item_name(item))
		item_equipped.emit(item)
		data_changed.emit()
		refresh()
	else:
		print("❌ Failed to equip item")

func _do_unequip(item) -> void:
	if not player or not item:
		return

	if item is EquippableItem:
		for slot in player.equipment:
			if player.equipment[slot] == item:
				if player.unequip_item(slot):
					print("✅ Unequipped: %s" % _item_name(item))
					data_changed.emit()
					refresh()
				break

func _do_use(item) -> void:
	if not player or not item:
		return

	if _is_consumable(item):
		_use_consumable(item)
		item_used.emit(item)
		data_changed.emit()

func _use_consumable(item):
	"""Use a consumable item — ConsumableItem resource or legacy Dictionary."""
	if not player:
		return

	if item is ConsumableItem:
		# Die-targeted consumables need the selection popup
		if item.target_type == ConsumableItem.TargetType.SINGLE_DIE:
			_open_die_select_popup(item)
			return

		var result = player.use_consumable(item)
		if result.get("success", false):
			print("  [OK] Used %s -- %s" % [item.item_name, result.get("message", "")])
		else:
			print("  [FAIL] %s" % result.get("message", "Failed"))
		selected_item = null
		refresh()
		return

	# Legacy Dictionary path
	if item is Dictionary:
		var effect = item.get("effect", "")
		var amount = item.get("amount", 0)
		match effect:
			"heal":
				player.heal(amount)
				print("💊 Used %s - Healed %d HP" % [item.get("name", ""), amount])
			"restore_mana":
				player.restore_mana(amount)
				print("💊 Used %s - Restored %d Mana" % [item.get("name", ""), amount])
			_:
				print("❓ Unknown consumable effect: %s" % effect)
		player.inventory.erase(item)
		selected_item = null
		refresh()

# ============================================================================
# DIE SELECTION POPUP
# ============================================================================

var _die_select_popup: ConsumableDieSelectPopup = null

func _open_die_select_popup(consumable: ConsumableItem):
	"""Open the die selection popup for a die-targeted consumable."""
	# Close the info popup first
	_close_info_popup()
	# Close the player menu so the bottom UI panel is accessible for dragging
	if GameManager and GameManager.game_root and GameManager.game_root.player_menu:
		GameManager.game_root.player_menu.close_menu()

	if not _die_select_popup:
		var scene: PackedScene = load("res://scenes/ui/popups/consumable_die_select_popup.tscn")
		_die_select_popup = scene.instantiate()
		get_tree().root.add_child(_die_select_popup)
		_die_select_popup.die_confirmed.connect(_on_die_select_confirmed)
		_die_select_popup.cancelled.connect(_on_die_select_cancelled)

	_die_select_popup.open(consumable, player)


func _on_die_select_confirmed(consumable: ConsumableItem, die: DieResource):
	"""Player confirmed die selection — use the consumable."""
	var result = player.use_consumable(consumable, {"selected_die": die})
	if result.get("success", false):
		print("  [OK] Used %s on %s -- %s" % [
			consumable.item_name, die.get_display_name(), result.get("message", "")])
	else:
		print("  [FAIL] %s" % result.get("message", "Failed"))
	selected_item = null
	refresh()
	data_changed.emit()


func _on_die_select_cancelled():
	"""Player cancelled die selection."""
	print("  [--] Die selection cancelled")

# ============================================================================
# ITEM TYPE HELPERS — Abstracts EquippableItem vs Dictionary access
# ============================================================================

func _item_name(item) -> String:
	if item is EquippableItem:
		return item.item_name
	elif item is ConsumableItem:
		return item.item_name
	elif item is Dictionary:
		return item.get("name", "Unknown")
	return "Unknown"

func _item_icon(item) -> Texture2D:
	if item is EquippableItem:
		return item.icon
	elif item is ConsumableItem:
		return item.icon
	elif item is Dictionary:
		if item.has("icon") and item.icon:
			return item.icon
	return null

func _item_rarity_name(item) -> String:
	if item is EquippableItem:
		return item.get_rarity_name()
	elif item is ConsumableItem:
		return item.get_rarity_name()
	elif item is Dictionary:
		return item.get("rarity", "Common")
	return "Common"

func _item_slot(item) -> String:
	if item is EquippableItem:
		return item.get_slot_name()
	elif item is Dictionary:
		return item.get("slot", "")
	return ""

func _item_description(item) -> String:
	if item is EquippableItem:
		return item.description
	elif item is ConsumableItem:
		return item.description
	elif item is Dictionary:
		return item.get("description", "No description.")
	return "No description."

func _item_type(item) -> String:
	"""Get non-equipment type (Consumable, Quest, Material). Empty for EquippableItem."""
	if item is Dictionary:
		return item.get("type", "")
	return ""

func _is_equipment(item) -> bool:
	if item is EquippableItem:
		return true
	elif item is Dictionary:
		return item.has("slot")
	return false

func _is_consumable(item) -> bool:
	if item is ConsumableItem:
		return true
	return _item_type(item) == "Consumable"

func _is_item_equipped(item) -> bool:
	if not player:
		return false
	if item is EquippableItem:
		return player.is_item_equipped(item)
	elif item is Dictionary:
		if player.has_method("is_item_equipped"):
			return player.is_item_equipped(item)
	return false

func _item_set_definition(item):
	"""Returns SetDefinition or null."""
	if item is EquippableItem:
		return item.set_definition
	elif item is Dictionary:
		return item.get("set_definition")
	return null

# ============================================================================
# PRIVATE DISPLAY METHODS
# ============================================================================

func _rebuild_inventory_grid():
	"""Rebuild inventory item grid"""
	if not inventory_grid:
		return

	# Apply grid settings from exports
	inventory_grid.columns = grid_columns
	inventory_grid.add_theme_constant_override("h_separation", int(grid_spacing))
	inventory_grid.add_theme_constant_override("v_separation", int(grid_spacing))

	# Clear existing buttons
	for child in inventory_grid.get_children():
		child.queue_free()
	item_buttons.clear()

	if not player:
		return

	# Filter items by current category
	var filtered_items = _get_filtered_items()

	print("  📦 Showing %d items in %s" % [filtered_items.size(), current_category])

	# Show empty message if no items
	if filtered_items.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No items in this category"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
		inventory_grid.add_child(empty_label)
		return

	# Create button for each item in filtered inventory
	for item in filtered_items:
		var item_btn = _create_item_button(item)
		inventory_grid.add_child(item_btn)
		item_buttons.append(item_btn)

func _get_filtered_items() -> Array:
	"""Get items matching current category filter"""
	if not player:
		return []

	if current_category == "All":
		var all_items: Array = []
		all_items.append_array(player.inventory)
		all_items.append_array(player.consumables)
		return all_items

	var filtered = []
	for item in player.inventory:
		var item_slot_name = _item_slot(item)

		# Normalize slot names for comparison (remove spaces, lowercase)
		var normalized_item_slot = item_slot_name.replace(" ", "").to_lower()
		var normalized_category = current_category.replace(" ", "").to_lower()

		# Check if item matches category
		if normalized_item_slot == normalized_category:
			filtered.append(item)
		elif current_category == "Consumable" and _is_consumable(item):
			filtered.append(item)

	# Merge consumables when Consumable tab is selected
	if current_category == "Consumable":
		for consumable in player.consumables:
			filtered.append(consumable)

	return filtered

func _create_item_button(item) -> Control:
	"""Create a button for an inventory item with rarity shader and equipped overlay"""
	var glow_pad = grid_glow_config.padding if grid_glow_config else 0.0

	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(grid_item_size + glow_pad * 2, grid_item_size + glow_pad * 2)

	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(grid_item_size, grid_item_size)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.position = Vector2(glow_pad, glow_pad)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	# Set item icon if available
	var icon = _item_icon(item)
	if icon:
		btn.texture_normal = icon
	else:
		# Create colored placeholder
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(_get_item_type_color(item))
		var tex = ImageTexture.create_from_image(img)
		btn.texture_normal = tex

	# Apply rarity shader
	if use_rarity_shaders and rarity_shader:
		_apply_rarity_shader_to_button(btn, item)

	wrapper.add_child(btn)

	# Clickable area covers entire grid square
	var click_area = Button.new()
	click_area.flat = true
	click_area.position = Vector2.ZERO
	click_area.size = wrapper.custom_minimum_size
	click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.pressed.connect(_on_item_button_pressed.bind(item, btn))
	wrapper.add_child(click_area)

	# Rarity glow behind grid icon
	RarityGlowHelper.apply_glow(btn, btn.texture_normal, _item_rarity_name(item), grid_glow_config)

	# Equipped overlay
	if _is_item_equipped(item):
		# Dim the icon slightly
		btn.modulate = Color(0.6, 0.6, 0.6, 1.0)

		# "E" badge in top-right corner
		var badge = Label.new()
		badge.text = "E"
		badge.add_theme_color_override("font_color", ThemeManager.PALETTE.text_primary)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(20, 20)
		badge.position = Vector2(glow_pad + 2, glow_pad + 2)

		# Badge background
		var badge_bg = Panel.new()
		var style = ThemeManager._flat_box(
			Color(ThemeManager.PALETTE.success.r, ThemeManager.PALETTE.success.g,
				ThemeManager.PALETTE.success.b, 0.9),
			Color(0, 0, 0, 0), 4, 0)
		badge_bg.add_theme_stylebox_override("panel", style)
		badge_bg.custom_minimum_size = Vector2(20, 20)
		badge_bg.position = Vector2(glow_pad + 2, glow_pad + 2)
		badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		wrapper.add_child(badge_bg)
		wrapper.add_child(badge)

	return wrapper


func _apply_rarity_shader_to_button(button: TextureButton, item):
	"""Apply rarity outline glow shader to a button"""
	var shader_material = ShaderMaterial.new()
	shader_material.shader = rarity_shader

	var rarity_name = _item_rarity_name(item)
	var color = ThemeManager.get_rarity_color(rarity_name)

	shader_material.set_shader_parameter("border_color", color)
	shader_material.set_shader_parameter("glow_radius", glow_radius)
	shader_material.set_shader_parameter("glow_softness", glow_softness)
	shader_material.set_shader_parameter("glow_width", glow_width)
	shader_material.set_shader_parameter("glow_strength", glow_strength)
	shader_material.set_shader_parameter("glow_blend", glow_blend)
	shader_material.set_shader_parameter("glow_saturation", glow_saturation)
	shader_material.set_shader_parameter("pulse_speed", pulse_speed)
	shader_material.set_shader_parameter("pulse_amount", pulse_amount)

	button.material = shader_material


func _get_item_type_color(item) -> Color:
	"""Get color for item type (fallback when no icon)"""
	if _is_equipment(item):
		return Color(0.4, 0.6, 0.4)  # Equipment - green

	match _item_type(item):
		"Consumable": return Color(0.6, 0.4, 0.6)  # Purple
		"Quest": return Color(0.7, 0.6, 0.2)  # Gold
		"Material": return Color(0.5, 0.5, 0.5)  # Gray
		_: return Color(0.4, 0.4, 0.4)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_category_button_toggled(button_pressed: bool, category_name: String):
	"""Category button toggled"""
	if button_pressed:
		current_category = category_name
		print("🎒 Category changed to: %s" % category_name)
		_update_category_button_visuals()
		refresh()

func _on_item_button_pressed(item, button: TextureButton):
	"""Item button clicked — open item info popup"""
	selected_item = item
	item_selected.emit(item)
	_show_item_info_popup(item)

func _update_category_button_visuals():
	"""Dim unselected category buttons to 50%"""
	for button in category_buttons:
		var cat_name = button.get_meta("category_name", "")
		if cat_name == current_category:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
			button.set_pressed_no_signal(true)
		else:
			button.modulate = Color(1.0, 1.0, 1.0, 0.5)
			button.set_pressed_no_signal(false)
