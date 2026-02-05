# inventory_tab.gd - Inventory management tab with rarity shader support
# Self-registers with parent, emits signals upward
# Uses button-based category filtering with vertical sidebar
extends Control

# ============================================================================
# RARITY SHADER CONFIGURATION
# ============================================================================
@export var rarity_colors: RarityColors = null
@export var use_rarity_shaders: bool = true

@export_group("Shader Settings")
@export_range(0.0, 0.5) var border_width: float = 0.08
@export_range(0.0, 2.0) var glow_strength: float = 0.8
@export_range(0.0, 5.0) var pulse_speed: float = 1.5

# ============================================================================
# SIGNALS (emitted upward)
# ============================================================================
signal refresh_requested()
signal data_changed()
signal item_selected(item: Dictionary)
signal item_used(item: Dictionary)
signal item_equipped(item: Dictionary)

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var selected_item: Dictionary = {}
var item_buttons: Array[TextureButton] = []
var category_buttons: Array[Button] = []

# UI references
var inventory_grid: GridContainer
var item_details_panel: PanelContainer

# Current filter
var current_category: String = "All"

# Shader resources
var rarity_shader: Shader = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")  # Self-register
	add_to_group("player_menu_tab_content")  # Register as tab content
	await get_tree().process_frame
	
	# Load rarity shader
	rarity_shader = load("res://shaders/rarity_border.gdshader")
	
	# Load default rarity colors if not set
	if not rarity_colors:
		var default_colors = load("res://resources/data/rarity_colors.tres")
		if default_colors:
			rarity_colors = default_colors
		else:
			rarity_colors = RarityColors.new()
	
	_discover_ui_elements()
	print("🎒 InventoryTab: Ready")

func _discover_ui_elements():
	"""Discover UI elements within this tab's own subtree"""
	# Find inventory grid locally (it's a child of this node)
	var grids = find_children("ItemGrid", "GridContainer", true, false)
	if grids.size() > 0:
		inventory_grid = grids[0]
		print("  ✓ Inventory grid registered")
	else:
		print("  ⚠️ No ItemGrid found in subtree")

	# Find category buttons locally
	var buttons = find_children("*Button", "Button", true, false)
	for button in buttons:
		if button.is_in_group("inventory_category_button"):
			category_buttons.append(button)
			var cat_name = button.get_meta("category_name", "")
			if cat_name:
				button.toggled.connect(_on_category_button_toggled.bind(cat_name))
				print("  ✓ Connected category button: %s" % cat_name)

	# Find details panel locally
	var panels = find_children("*DetailsPanel*", "PanelContainer", true, false)
	if panels.size() > 0:
		item_details_panel = panels[0]
		print("  ✓ Details panel registered")
	else:
		print("  ⚠️ No inventory details panel found")

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
# PRIVATE DISPLAY METHODS
# ============================================================================

func _rebuild_inventory_grid():
	"""Rebuild inventory item grid"""
	if not inventory_grid:
		return
	
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
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
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
		var item_slot = item.get("slot", "")
		
		# Normalize slot names for comparison (remove spaces, lowercase)
		var normalized_item_slot = item_slot.replace(" ", "").to_lower()
		var normalized_category = current_category.replace(" ", "").to_lower()
		
		# Check if item matches category
		if normalized_item_slot == normalized_category:
			filtered.append(item)
		elif current_category == "Consumable" and item.get("type", "") == "Consumable":
			filtered.append(item)
	
	return filtered

func _create_item_button(item: Dictionary) -> TextureButton:
	"""Create a button for an inventory item with rarity shader"""
	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(80, 80)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	# Set item icon if available
	if item.has("icon") and item.icon:
		btn.texture_normal = item.icon
	else:
		# Create colored placeholder
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(_get_item_type_color(item))
		var tex = ImageTexture.create_from_image(img)
		btn.texture_normal = tex
	
	# Apply rarity shader
	if use_rarity_shaders and rarity_shader and rarity_colors:
		_apply_rarity_shader_to_button(btn, item)
	
	btn.pressed.connect(_on_item_button_pressed.bind(item))
	
	return btn

func _apply_rarity_shader_to_button(button: TextureButton, item: Dictionary):
	"""Apply rarity border shader to a button"""
	# Create shader material
	var shader_material = ShaderMaterial.new()
	shader_material.shader = rarity_shader
	
	# Get rarity color
	var rarity_name = item.get("rarity", "Common")
	var border_color = rarity_colors.get_color_for_rarity(rarity_name)
	
	# Set shader parameters
	shader_material.set_shader_parameter("border_color", border_color)
	shader_material.set_shader_parameter("border_width", border_width)
	shader_material.set_shader_parameter("glow_strength", glow_strength)
	shader_material.set_shader_parameter("pulse_speed", pulse_speed)
	
	# Apply material
	button.material = shader_material

func _get_item_type_color(item: Dictionary) -> Color:
	"""Get color for item type (fallback when no icon)"""
	if item.has("slot"):
		return Color(0.4, 0.6, 0.4)  # Equipment - green
	
	match item.get("type", ""):
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
	var action_buttons_containers = item_details_panel.find_children("ActionButtons", "HBoxContainer", true, false)
	
	print("  Found %d ActionButtons containers" % action_buttons_containers.size())
	
	# Get individual buttons from ActionButtons container
	var use_buttons = []
	var equip_buttons = []
	if action_buttons_containers.size() > 0:
		use_buttons = action_buttons_containers[0].find_children("*Use*", "Button", false, false)
		equip_buttons = action_buttons_containers[0].find_children("*Equip*", "Button", false, false)
		print("  Found %d Use buttons, %d Equip buttons" % [use_buttons.size(), equip_buttons.size()])
	
	if selected_item.is_empty():
		print("  No item selected - hiding buttons")
		# Clear details
		if name_labels.size() > 0:
			name_labels[0].text = "No Item Selected"
		if image_rects.size() > 0:
			image_rects[0].texture = null
		if desc_labels.size() > 0:
			desc_labels[0].text = ""
		if affix_containers.size() > 0:
			for child in affix_containers[0].get_children():
				child.queue_free()
		# Hide action buttons container
		if action_buttons_containers.size() > 0:
			action_buttons_containers[0].hide()
		return
	
	print("  Selected item: %s" % selected_item.get("name", "Unknown"))
	
	# Show item name
	if name_labels.size() > 0:
		name_labels[0].text = selected_item.get("name", "Unknown")
	
	# Show item image
	if image_rects.size() > 0:
		if selected_item.has("icon") and selected_item.icon:
			image_rects[0].texture = selected_item.icon
		else:
			# Create colored placeholder
			var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
			img.fill(_get_item_type_color(selected_item))
			var tex = ImageTexture.create_from_image(img)
			image_rects[0].texture = tex
	
	# Show description
	if desc_labels.size() > 0:
		desc_labels[0].text = selected_item.get("description", "No description.")
	
	# Show affixes
	if affix_containers.size() > 0 and selected_item.has("affixes"):
		var affix_container = affix_containers[0]
		for child in affix_container.get_children():
			child.queue_free()
		
		for affix in selected_item.affixes:
			var affix_display = _create_affix_display(affix)
			affix_container.add_child(affix_display)
	
	# Determine which buttons to show
	var is_equipment = selected_item.has("slot")
	var is_consumable = selected_item.get("type", "") == "Consumable"
	var show_any_button = is_equipment or is_consumable
	
	print("  is_equipment: %s, is_consumable: %s, show_any: %s" % [is_equipment, is_consumable, show_any_button])
	
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
		if is_consumable:
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
		if is_equipment:
			print("  ✅ Showing Equip button")
			equip_btn.show()
			equip_btn.disabled = false  # CRITICAL: Make sure it's enabled!
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

func _create_affix_display(affix: Dictionary) -> PanelContainer:
	"""Create a display panel for an affix"""
	var panel = PanelContainer.new()
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Affix name
	var name_label = Label.new()
	name_label.text = affix.get("display_name", affix.get("name", "Unknown"))
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(name_label)
	
	# Affix description
	var desc_label = Label.new()
	desc_label.text = affix.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
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
		refresh()

func _on_item_button_pressed(item: Dictionary):
	"""Item button clicked"""
	selected_item = item
	_update_item_details()
	item_selected.emit(item)  # Bubble up

func _on_use_item_pressed():
	"""Use item button pressed"""
	if selected_item.is_empty():
		return
	
	# Handle consumable items
	if selected_item.get("type", "") == "Consumable":
		_use_consumable(selected_item)
		item_used.emit(selected_item)  # Bubble up
		data_changed.emit()  # Bubble up

func _use_consumable(item: Dictionary):
	"""Use a consumable item"""
	if not player:
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
	selected_item = {}
	refresh()

func _on_equip_item_pressed():
	"""Equip item button pressed"""
	print("🔘 Equip button pressed!")
	print("  Selected item: %s" % selected_item.get("name", "Unknown"))
	print("  Player exists: %s" % (player != null))
	
	if selected_item.is_empty() or not player:
		print("  ❌ Cannot equip - selected_item empty or no player")
		return
	
	print("  Attempting to equip...")
	var success = player.equip_item(selected_item)
	print("  Equip result: %s" % success)
	
	if success:
		var item_name = selected_item.get("name", "Unknown")
		print("✅ Equipped: %s" % item_name)
		
		item_equipped.emit(selected_item)  # Bubble up
		data_changed.emit()  # Bubble up
		selected_item = {}
		refresh()
	else:
		print("❌ Failed to equip item")
