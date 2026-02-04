# inventory_tab_mobile.gd
# Mobile-optimized inventory with vertical category sidebar
extends Control

# ============================================================================
# STATE
# ============================================================================

var player: Player = null
var current_category: String = "All"

# ============================================================================
# UI REFERENCES
# ============================================================================

var main_hbox: HBoxContainer
var category_sidebar: VBoxContainer
var content_area: VBoxContainer
var scroll_container: ScrollContainer
var item_grid: GridContainer
var category_label: Label

# Category buttons (one for each category)
var category_buttons: Dictionary = {}

# Item popup (for item details)
var item_popup: Control = null

# ============================================================================
# SIGNALS
# ============================================================================

signal item_equipped(item: Dictionary)
signal item_used(item: Dictionary)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	print("📦 Mobile Inventory initializing...")
	setup_layout()
	setup_categories()
	create_item_popup()
	
	# Connect to responsive system
	if has_node("/root/ResponsiveUI"):
		ResponsiveUI.screen_size_changed.connect(_on_screen_size_changed)
		_on_screen_size_changed(ResponsiveUI.current_size)
	
	print("📦 Mobile Inventory ready")

# ============================================================================
# LAYOUT SETUP
# ============================================================================

func setup_layout():
	"""Create the horizontal split layout"""
	
	# Main horizontal split: sidebar | content
	main_hbox = HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)
	
	# LEFT: Category sidebar
	category_sidebar = VBoxContainer.new()
	category_sidebar.name = "CategorySidebar"
	category_sidebar.custom_minimum_size = Vector2(100, 0)
	category_sidebar.add_theme_constant_override("separation", 8)
	
	# Add colored background to sidebar
	var sidebar_panel = PanelContainer.new()
	var sidebar_style = StyleBoxFlat.new()
	sidebar_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	sidebar_panel.add_theme_stylebox_override("panel", sidebar_style)
	sidebar_panel.add_child(category_sidebar)
	main_hbox.add_child(sidebar_panel)
	
	# RIGHT: Content area
	content_area = VBoxContainer.new()
	content_area.name = "ContentArea"
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.add_theme_constant_override("separation", 8)
	main_hbox.add_child(content_area)
	
	# Category label (shows current category)
	category_label = Label.new()
	category_label.name = "CategoryLabel"
	category_label.text = "All Items"
	category_label.add_theme_font_size_override("font_size", 20)
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_area.add_child(category_label)
	
	# Scroll container for items
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(scroll_container)
	
	# Item grid inside scroll
	item_grid = GridContainer.new()
	item_grid.name = "ItemGrid"
	item_grid.columns = 4  # Will be updated by responsive system
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 8)
	scroll_container.add_child(item_grid)
	
	print("  ✅ Layout created")

# ============================================================================
# CATEGORY SETUP
# ============================================================================

func setup_categories():
	"""Create icon buttons for each category"""
	
	# Define categories
	var categories = [
		{"name": "All", "icon": "res://assets/ui/icons/categories/all.png"},
		{"name": "Head", "icon": "res://assets/ui/icons/categories/head.png"},
		{"name": "Torso", "icon": "res://assets/ui/icons/categories/torso.png"},
		{"name": "Gloves", "icon": "res://assets/ui/icons/categories/gloves.png"},
		{"name": "Boots", "icon": "res://assets/ui/icons/categories/boots.png"},
		{"name": "Main Hand", "icon": "res://assets/ui/icons/categories/weapon.png"},
		{"name": "Off Hand", "icon": "res://assets/ui/icons/categories/shield.png"},
		{"name": "Accessory", "icon": "res://assets/ui/icons/categories/accessory.png"},
		{"name": "Consumable", "icon": "res://assets/ui/icons/categories/potion.png"},
	]
	
	# Create button for each category
	for cat in categories:
		var btn = create_category_button(cat)
		category_sidebar.add_child(btn)
		category_buttons[cat.name] = btn
	
	# Set "All" as initially active
	if category_buttons.has("All"):
		category_buttons["All"].set_active(true)
	
	print("  ✅ Categories created (%d)" % categories.size())

func create_category_button(cat_data: Dictionary) -> IconButton:
	"""Create a single category button"""
	var btn = IconButton.new()
	
	# Load icon
	if ResourceLoader.exists(cat_data.icon):
		btn.icon_normal = load(cat_data.icon)
	else:
		print("  ⚠️  Category icon not found: %s" % cat_data.icon)
	
	btn.label_text = cat_data.name
	btn.show_label = false  # Icon only in sidebar (shows on hover via tooltip)
	btn.button_size = Vector2(80, 80)
	btn.tooltip_text = cat_data.name  # Show name on hover
	
	# Connect press
	btn.pressed.connect(func(): switch_category(cat_data.name))
	
	return btn

# ============================================================================
# CATEGORY SWITCHING
# ============================================================================

func switch_category(category: String):
	"""Switch to a different item category"""
	
	# Already on this category?
	if current_category == category:
		return
	
	print("📦 Switching to category: %s" % category)
	current_category = category
	
	# Update button states
	for name in category_buttons:
		category_buttons[name].set_active(name == category)
	
	# Update category label
	category_label.text = "%s" % ("All Items" if category == "All" else category)
	
	# Refresh items display
	refresh_items()

# ============================================================================
# ITEMS DISPLAY
# ============================================================================

func refresh_items():
	"""Refresh the displayed items based on current category"""
	
	# Clear existing items
	for child in item_grid.get_children():
		child.queue_free()
	
	if not player:
		print("  ⚠️  No player data")
		return
	
	# Filter items by category
	var items_to_show = []
	if current_category == "All":
		items_to_show = player.inventory.duplicate()
	else:
		for item in player.inventory:
			var item_slot = item.get("slot", "")
			var item_type = item.get("type", "")
			if item_slot == current_category or item_type == current_category:
				items_to_show.append(item)
	
	print("  📦 Showing %d items in %s" % [items_to_show.size(), current_category])
	
	# Show empty message if no items
	if items_to_show.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No items in this category"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_grid.add_child(empty_label)
		return
	
	# Create button for each item
	for item in items_to_show:
		var item_btn = create_item_button(item)
		item_grid.add_child(item_btn)

func create_item_button(item: Dictionary) -> TextureButton:
	"""Create a button for a single item"""
	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(80, 80)
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	# Set texture
	if item.has("icon") and item.icon:
		btn.texture_normal = item.icon
	else:
		# Create placeholder colored square
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(get_item_color(item))
		btn.texture_normal = ImageTexture.create_from_image(img)
	
	# Add border
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.5, 0.5, 0.5)
	
	# Tooltip
	btn.tooltip_text = item.get("name", "Unknown Item")
	
	# Connect click
	btn.pressed.connect(func(): _on_item_clicked(item))
	
	return btn

func get_item_color(item: Dictionary) -> Color:
	"""Get a color for item type"""
	match item.get("slot", item.get("type", "")):
		"Head": return Color(0.6, 0.4, 0.4)
		"Torso": return Color(0.4, 0.6, 0.4)
		"Gloves": return Color(0.4, 0.4, 0.6)
		"Boots": return Color(0.5, 0.5, 0.3)
		"Main Hand": return Color(0.7, 0.3, 0.3)
		"Off Hand": return Color(0.3, 0.5, 0.5)
		"Accessory": return Color(0.6, 0.3, 0.6)
		"Consumable": return Color(0.3, 0.6, 0.6)
		_: return Color(0.5, 0.5, 0.5)

# ============================================================================
# RESPONSIVE GRID
# ============================================================================

func _on_screen_size_changed(screen_size: int):
	"""Update grid columns based on screen size"""
	var new_columns = ResponsiveUI.get_recommended_grid_columns()
	
	# Adjust for sidebar taking space
	if screen_size <= 1:  # Phone
		new_columns = max(2, new_columns - 1)  # Leave room for sidebar
	
	item_grid.columns = new_columns
	print("📦 Grid columns updated: %d" % new_columns)

# ============================================================================
# ITEM POPUP
# ============================================================================

func create_item_popup():
	"""Create the popup for item details"""
	item_popup = Control.new()
	item_popup.name = "ItemPopup"
	item_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	item_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_popup.hide()
	add_child(item_popup)
	
	# Dark overlay
	var overlay = Panel.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.8)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	item_popup.add_child(overlay)
	
	# Close on overlay click
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			hide_item_popup()
	)
	
	# Popup panel
	var panel = PanelContainer.new()
	panel.name = "PopupPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	
	# Size based on screen
	if ResponsiveUI.is_mobile():
		panel.custom_minimum_size = Vector2(400, 500)
	else:
		panel.custom_minimum_size = Vector2(500, 600)
	
	panel.position = -panel.custom_minimum_size / 2
	item_popup.add_child(panel)
	
	# Content
	var vbox = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	# Item name
	var name_label = Label.new()
	name_label.name = "ItemName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)
	
	# Item image
	var image_rect = TextureRect.new()
	image_rect.name = "ItemImage"
	image_rect.custom_minimum_size = Vector2(128, 128)
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(image_rect)
	
	# Item description
	var desc_label = Label.new()
	desc_label.name = "ItemDescription"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size.x = 380
	vbox.add_child(desc_label)
	
	# Item stats
	var stats_label = Label.new()
	stats_label.name = "ItemStats"
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(stats_label)
	
	# Requirements (if can't equip)
	var req_label = Label.new()
	req_label.name = "Requirements"
	req_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	req_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	req_label.hide()
	vbox.add_child(req_label)
	
	# Action button
	var action_button = Button.new()
	action_button.name = "ActionButton"
	action_button.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(action_button)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 50)
	close_btn.pressed.connect(hide_item_popup)
	vbox.add_child(close_btn)
	
	print("  ✅ Item popup created")

func _on_item_clicked(item: Dictionary):
	"""Item button clicked - show details popup"""
	print("📦 Item clicked: %s" % item.get("name", "Unknown"))
	show_item_popup(item)

func show_item_popup(item: Dictionary):
	"""Display the item details popup"""
	if not item_popup:
		return
	
	var panel = item_popup.get_node("PopupPanel")
	var vbox = panel.get_node("Content")
	
	# Update name
	var name_label = vbox.get_node("ItemName")
	name_label.text = item.get("name", "Unknown Item")
	
	# Update image
	var image_rect = vbox.get_node("ItemImage")
	if item.has("icon") and item.icon:
		image_rect.texture = item.icon
	else:
		var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(get_item_color(item))
		image_rect.texture = ImageTexture.create_from_image(img)
	
	# Update description
	var desc_label = vbox.get_node("ItemDescription")
	desc_label.text = item.get("description", "No description.")
	
	# Update stats
	var stats_label = vbox.get_node("ItemStats")
	var stats_text = ""
	if item.has("stats"):
		stats_text = "Stats:\n"
		for stat in item.stats:
			stats_text += "  %s: +%d\n" % [stat.capitalize(), item.stats[stat]]
	stats_label.text = stats_text
	
	# Check if can equip
	var req_label = vbox.get_node("Requirements")
	var can_equip = can_equip_item(item)
	
	if item.has("slot") and not can_equip:
		var req_text = "Cannot equip - Requirements not met"
		req_label.text = req_text
		req_label.show()
	else:
		req_label.hide()
	
	# Setup action button
	var action_button = vbox.get_node("ActionButton")
	
	# Disconnect old signals
	for connection in action_button.pressed.get_connections():
		action_button.pressed.disconnect(connection.callable)
	
	# Determine button action
	var is_equippable = item.has("slot") and item.slot != ""
	var is_consumable = item.get("type", "") == "Consumable"
	
	if is_equippable:
		action_button.text = "Equip"
		action_button.disabled = not can_equip
		action_button.pressed.connect(func(): _on_equip_item(item))
	elif is_consumable:
		action_button.text = "Use"
		action_button.disabled = false
		action_button.pressed.connect(func(): _on_use_item(item))
	else:
		action_button.text = "N/A"
		action_button.disabled = true
	
	# Show popup
	item_popup.show()

func hide_item_popup():
	"""Hide the item details popup"""
	if item_popup:
		item_popup.hide()

func can_equip_item(item: Dictionary) -> bool:
	"""Check if player can equip this item"""
	if not player or not item.has("slot"):
		return false
	
	# Check requirements
	if item.has("requirements"):
		for req_stat in item.requirements:
			if player.get_total_stat(req_stat) < item.requirements[req_stat]:
				return false
	
	return true

func _on_equip_item(item: Dictionary):
	"""Equip button clicked"""
	if player and player.equip_item(item):
		print("✅ Equipped: %s" % item.name)
		item_equipped.emit(item)
		hide_item_popup()
		refresh_items()

func _on_use_item(item: Dictionary):
	"""Use button clicked"""
	if not player:
		return
	
	# Handle consumable effect
	if item.has("effect"):
		match item.effect:
			"heal":
				player.heal(item.get("amount", 0))
			"restore_mana":
				player.restore_mana(item.get("amount", 0))
			"cure_poison":
				player.remove_status_effect("poison")
			"remove_bleed":
				player.remove_status_effect("bleed")
	
	# Remove from inventory
	player.remove_from_inventory(item)
	item_used.emit(item)
	hide_item_popup()
	refresh_items()
	print("✅ Used: %s" % item.get("name", "item"))

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh display"""
	player = p_player
	print("📦 Player set - inventory size: %d" % (player.inventory.size() if player else 0))
	refresh_items()
