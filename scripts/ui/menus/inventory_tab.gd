# inventory_tab.gd - Inventory management tab with rarity shader support
# v3 — Reads EquippableItem directly; Dictionary fallback for consumables/misc.
# Self-registers with parent, emits signals upward
# Uses button-based category filtering with vertical sidebar
extends Control

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
@export var detail_glow_config: RarityGlowConfig
@export var grid_glow_config: RarityGlowConfig


@export_group("Grid Item Size")
@export var grid_item_size: float = 80.0
@export var grid_columns: int = 5
@export var grid_spacing: float = 10.0



@export_group("Detail Panel Sizing")
@export var detail_icon_size: float = 128.0
@export var detail_container_size: float = 180.0

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
var item_details_panel: PanelContainer

# Current filter
var current_category: String = "All"

# Shader resources
var rarity_shader: Shader = null

# Add to STATE section
var _selected_button: TextureButton = null

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
	
	# Find details panel WITHIN THIS TAB
	for panel in find_children("*", "PanelContainer", true, false):
		if panel.is_in_group("inventory_details_panel"):
			item_details_panel = panel
			print("  ✓ Details panel registered")
			break
	
	_update_category_button_visuals()

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
	
	refresh()

func refresh():
	"""Refresh all inventory displays"""
	if not player:
		return
	
	print("🎒 Refreshing inventory - Total items: %d, Category: %s" % [player.inventory.size(), current_category])
	
	_rebuild_inventory_grid()
	_update_item_details()

func on_external_data_change():
	"""Called when other tabs modify player data"""
	refresh()

# ============================================================================
# ITEM TYPE HELPERS — Abstracts EquippableItem vs Dictionary access
# ============================================================================

func _item_name(item) -> String:
	if item is EquippableItem:
		return item.item_name
	elif item is Dictionary:
		return item.get("name", "Unknown")
	return "Unknown"

func _item_icon(item) -> Texture2D:
	if item is EquippableItem:
		return item.icon
	elif item is Dictionary:
		if item.has("icon") and item.icon:
			return item.icon
	return null

func _item_rarity_name(item) -> String:
	if item is EquippableItem:
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
	return _item_type(item) == "Consumable"

func _is_item_equipped(item) -> bool:
	if not player:
		return false
	if item is EquippableItem:
		return player.is_item_equipped(item)
	elif item is Dictionary:
		# Legacy path — player.is_item_equipped may still accept Dictionary
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
		return player.inventory
	
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
	
	return filtered

func _create_item_button(item) -> Control:
	"""Create a button for an inventory item with rarity shader and equipped overlay"""
	# Wrapper so we can layer the overlay
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
		badge.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZES.caption)
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
	
	
	# DEBUG
	print("🔆 Grid item: wrapper.clip=%s, btn.clip=%s, btn.size=%s" % [
		wrapper.clip_contents, btn.clip_contents, btn.custom_minimum_size
	])
	var p = wrapper
	while p:
		if p is ScrollContainer or p is PanelContainer or p.clip_contents:
			print("  📎 Clipper: %s (type=%s, clip=%s)" % [p.name, p.get_class(), p.clip_contents])
		p = p.get_parent()
	
	
	
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




func _update_item_details():
	"""Update the item details panel"""
	print("🔍 _update_item_details called")
	
	if not item_details_panel:
		print("  ❌ No item_details_panel!")
		return
	
	# Find UI elements in details panel
	var name_labels = item_details_panel.find_children("*Name*", "Label", true, false)
	var image_rects = item_details_panel.find_children("*Image*", "TextureRect", true, false)
	var desc_labels = item_details_panel.find_children("*Desc*", "Label", true, false)
	var affix_containers = item_details_panel.find_children("*Affix*", "VBoxContainer", true, false)
	var action_buttons_containers = find_children("ActionButtons", "HBoxContainer", true, false)
	
	print("  Found %d ActionButtons containers" % action_buttons_containers.size())
	
	# Get individual buttons from ActionButtons container
	var use_buttons = []
	var equip_buttons = []
	if action_buttons_containers.size() > 0:
		use_buttons = action_buttons_containers[0].find_children("*Use*", "Button", false, false)
		equip_buttons = action_buttons_containers[0].find_children("*Equip*", "Button", false, false)
		print("  Found %d Use buttons, %d Equip buttons" % [use_buttons.size(), equip_buttons.size()])
	
	if selected_item == null:
		print("  No item selected - hiding buttons")
		# Clear details
		if name_labels.size() > 0:
			name_labels[0].text = "No Item Selected"
			name_labels[0].remove_theme_color_override("font_color")
		if image_rects.size() > 0:
			image_rects[0].texture = null
			image_rects[0].material = null
			RarityGlowHelper.clear_glow(image_rects[0])
		if desc_labels.size() > 0:
			desc_labels[0].text = ""
		if affix_containers.size() > 0:
			for child in affix_containers[0].get_children():
				child.queue_free()
		# Hide action buttons container
		if action_buttons_containers.size() > 0:
			action_buttons_containers[0].hide()
		return
	
	print("  Selected item: %s" % _item_name(selected_item))
	
	# Show item name with rarity color
	if name_labels.size() > 0:
		var rarity_name = _item_rarity_name(selected_item)
		name_labels[0].text = _item_name(selected_item)
		name_labels[0].add_theme_color_override("font_color", ThemeManager.get_rarity_color(rarity_name))
	
	# Show item image with rarity shader + glow layer
	if image_rects.size() > 0:
		image_rects[0].custom_minimum_size = Vector2(detail_icon_size, detail_icon_size)
		
		# Constrain the container so glow doesn't bleed into neighbors
		var center = image_rects[0].get_parent()
		if center is CenterContainer:
			center.custom_minimum_size = Vector2(detail_container_size, detail_container_size)
			#center.clip_contents = true
		
		var icon = _item_icon(selected_item)
		if icon:
			image_rects[0].texture = icon
		else:
			# Create colored placeholder
			var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
			img.fill(_get_item_type_color(selected_item))
			var tex = ImageTexture.create_from_image(img)
			image_rects[0].texture = tex
		_apply_rarity_shader_to_texture_rect(image_rects[0], selected_item)
		RarityGlowHelper.apply_glow(image_rects[0], image_rects[0].texture, _item_rarity_name(selected_item), detail_glow_config)
	
	# Show description
	if desc_labels.size() > 0:
		desc_labels[0].text = _item_description(selected_item)
	
	# Show affixes
	if affix_containers.size() > 0:
		var affix_container = affix_containers[0]
		for child in affix_container.get_children():
			child.queue_free()
		
		# ── Resolve EquippableItem reference ──
		# Inventory stores EquippableItem Resources directly (v3).
		var equippable: EquippableItem = null
		if selected_item is EquippableItem:
			equippable = selected_item
		
		# ── Affix display (EquippableItem path) ──
		if equippable:
			# Item level / region
			if equippable.item_level > 0:
				var level_label = Label.new()
				level_label.text = "Item Level %d (Region %d)" % [equippable.item_level, equippable.region]
				level_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
				affix_container.add_child(level_label)
			
			# Inherent affixes (green-tinted — manual/identity affixes)
			for affix in equippable.inherent_affixes:
				if affix:
					var display = _create_affix_display_from_affix(affix, Color(0.7, 0.9, 0.7))
					affix_container.add_child(display)
			
			# Rolled affixes (gold-tinted — random table rolls)
			for affix in equippable.rolled_affixes:
				if affix:
					var display = _create_affix_display_from_affix(affix, Color(0.9, 0.7, 0.3))
					affix_container.add_child(display)
			
			# Equip requirements (red if unmet)
			if equippable.has_requirements():
				var unmet = equippable.get_unmet_requirements(player) if player else []
				for req_text in unmet:
					var req_label = Label.new()
					req_label.text = req_text
					req_label.add_theme_color_override("font_color", ThemeManager.PALETTE.danger)
					affix_container.add_child(req_label)
			
			# Sell value
			var sell_label = Label.new()
			sell_label.text = "Sell: %d gold" % equippable.get_sell_value()
			sell_label.add_theme_color_override("font_color", ThemeManager.PALETTE.warning)
			affix_container.add_child(sell_label)
		
		
		# Show set info (works for both types)
		var set_def: SetDefinition = _item_set_definition(selected_item)
		if set_def:
			# Set header
			var set_header = Label.new()
			var equipped_count: int = 0
			if player and player.set_tracker:
				equipped_count = player.set_tracker.get_equipped_count(set_def.set_id)
			set_header.text = "%s (%d/%d)" % [set_def.set_name, equipped_count, set_def.get_total_pieces()]
			set_header.add_theme_color_override("font_color", set_def.set_color)
			affix_container.add_child(set_header)
			
			# Threshold bonuses
			for threshold in set_def.thresholds:
				var is_active = player and player.set_tracker and player.set_tracker.is_threshold_active(set_def.set_id, threshold.required_pieces)
				var threshold_label = Label.new()
				var prefix = "✓" if is_active else "✗"
				threshold_label.text = "  %s (%d) %s" % [prefix, threshold.required_pieces, threshold.description]
				threshold_label.add_theme_color_override("font_color",
					ThemeManager.PALETTE.success if is_active else ThemeManager.PALETTE.locked)
				threshold_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				affix_container.add_child(threshold_label)
	
	# Determine which buttons to show
	var is_equip = _is_equipment(selected_item)
	var is_consume = _is_consumable(selected_item)
	var show_any_button = is_equip or is_consume
	
	print("  is_equipment: %s, is_consumable: %s, show_any: %s" % [is_equip, is_consume, show_any_button])
	
	# Show/hide ActionButtons container
	if action_buttons_containers.size() > 0:
		if show_any_button:
			print("  ✅ Showing ActionButtons container")
			action_buttons_containers[0].show()
		else:
			print("  ❌ Hiding ActionButtons container")
			action_buttons_containers[0].hide()
	
	# Configure Use button for consumables
	if use_buttons.size() > 0:
		var use_btn = use_buttons[0]
		if is_consume:
			print("  ✅ Showing Use button")
			use_btn.show()
			use_btn.disabled = false
			# Disconnect old connections
			for connection in use_btn.pressed.get_connections():
				use_btn.pressed.disconnect(connection.callable)
			use_btn.pressed.connect(_on_use_item_pressed)
		else:
			print("  ❌ Hiding Use button")
			use_btn.hide()
	
	# Configure Equip button for equipment
	if equip_buttons.size() > 0:
		var equip_btn = equip_buttons[0]
		if is_equip:
			print("  ✅ Showing Equip button")
			equip_btn.show()
			equip_btn.disabled = false
			# Toggle label based on equipped state
			if _is_item_equipped(selected_item):
				equip_btn.text = "Unequip"
			else:
				equip_btn.text = "Equip"
				# Show requirement lock for EquippableItem
				var eq_ref: EquippableItem = selected_item if selected_item is EquippableItem else null
				if eq_ref and player and not eq_ref.can_equip(player):
					equip_btn.text = "Equip (Locked)"
					equip_btn.disabled = true
			print("    Button disabled state: %s" % equip_btn.disabled)
			# Disconnect old connections
			for connection in equip_btn.pressed.get_connections():
				print("    Disconnecting old connection")
				equip_btn.pressed.disconnect(connection.callable)
			print("    Connecting _on_equip_item_pressed")
			equip_btn.pressed.connect(_on_equip_item_pressed)
			print("    Button now has %d connections" % equip_btn.pressed.get_connections().size())
		else:
			print("  ❌ Hiding Equip button")
			equip_btn.hide()


func _apply_rarity_shader_to_texture_rect(tex_rect: TextureRect, item):
	"""Apply rarity glow shader to any TextureRect"""
	if not use_rarity_shaders or not rarity_shader:
		tex_rect.material = null
		return
	
	var rarity_name = _item_rarity_name(item)
	var color = ThemeManager.get_rarity_color(rarity_name)
	
	var mat = ShaderMaterial.new()
	mat.shader = rarity_shader
	mat.set_shader_parameter("border_color", color)
	mat.set_shader_parameter("glow_radius", glow_radius)
	mat.set_shader_parameter("glow_softness", glow_softness)
	mat.set_shader_parameter("glow_width", glow_width)
	mat.set_shader_parameter("glow_strength", glow_strength)
	mat.set_shader_parameter("glow_blend", glow_blend)
	mat.set_shader_parameter("glow_saturation", glow_saturation)
	mat.set_shader_parameter("pulse_speed", pulse_speed)
	mat.set_shader_parameter("pulse_amount", pulse_amount)
	tex_rect.material = mat

func _create_affix_display(affix: Dictionary) -> PanelContainer:
	"""LEGACY: Display panel for Dictionary-based affixes.
	Equipment now uses _create_affix_display_from_affix(). This remains
	for potential future Dictionary-based item types (consumables, quest items)."""
	var panel = PanelContainer.new()
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Affix name
	var name_label = Label.new()
	name_label.text = affix.get("display_name", affix.get("name", "Unknown"))
	name_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(name_label)
	
	# Affix description
	var desc_label = Label.new()
	desc_label.text = affix.get("description", "")
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	return panel

func _create_affix_display_from_affix(affix: Affix, name_color: Color = Color(0.9, 0.7, 0.3)) -> PanelContainer:
	"""Create a display panel for an Affix resource (EquippableItem path)"""
	var panel = PanelContainer.new()
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Affix name
	var name_label = Label.new()
	name_label.text = affix.affix_name
	name_label.add_theme_color_override("font_color", name_color)
	vbox.add_child(name_label)
	
	# Affix description
	var desc_label = Label.new()
	desc_label.text = affix.get_resolved_description()
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	return panel

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
	"""Item button clicked"""
	selected_item = item
	_highlight_selected_button(button)
	_update_item_details()
	item_selected.emit(item)  # Bubble up


func _highlight_selected_button(button: TextureButton):
	# Reset previous selection
	if _selected_button and is_instance_valid(_selected_button):
		_selected_button.modulate = Color.WHITE
	# Highlight new selection
	_selected_button = button
	_selected_button.modulate = Color(1.2, 1.2, 0.8)  # Slight bright/warm tint

func _on_use_item_pressed():
	"""Use item button pressed"""
	if selected_item == null:
		return
	
	# Handle consumable items
	if _is_consumable(selected_item):
		_use_consumable(selected_item)
		item_used.emit(selected_item)  # Bubble up
		data_changed.emit()  # Bubble up

func _use_consumable(item):
	"""Use a consumable item (Dictionary-based consumables only)"""
	if not player:
		return
	
	# Consumables are still Dictionary-based
	if not item is Dictionary:
		return
	
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
	
	# Remove from inventory
	player.inventory.erase(item)
	selected_item = null
	refresh()

func _on_equip_item_pressed():
	"""Equip/unequip item button pressed"""
	print("🔘 Equip button pressed!")
	print("  Selected item: %s" % _item_name(selected_item))
	print("  Player exists: %s" % (player != null))
	
	if selected_item == null or not player:
		print("  ❌ Cannot equip - no item selected or no player")
		return
	
	if _is_item_equipped(selected_item):
		# Already equipped — unequip it
		if selected_item is EquippableItem:
			for slot in player.equipment:
				if player.equipment[slot] == selected_item:
					if player.unequip_item(slot):
						print("✅ Unequipped: %s" % _item_name(selected_item))
						data_changed.emit()
						refresh()
					break
		return
	
	print("  Attempting to equip...")
	var success = player.equip_item(selected_item)
	print("  Equip result: %s" % success)
	
	if success:
		print("✅ Equipped: %s" % _item_name(selected_item))
		
		item_equipped.emit(selected_item)
		data_changed.emit()
		refresh()
	else:
		print("❌ Failed to equip item")


func _update_category_button_visuals():
	"""Dim unselected category buttons to 50%"""
	for button in category_buttons:
		if button.button_pressed:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			button.modulate = Color(1.0, 1.0, 1.0, 0.5)
