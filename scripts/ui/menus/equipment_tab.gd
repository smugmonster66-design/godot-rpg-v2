# equipment_tab.gd - Equipment management tab
# Uses existing scene structure, no programmatic UI creation
extends Control

# ============================================================================
# SIGNALS (emitted upward)
# ============================================================================
signal refresh_requested()
signal data_changed()
signal item_equipped(slot: String, item: Dictionary)
signal item_unequipped(slot: String)

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var selected_slot: String = ""
var selected_item: Dictionary = {}

# Equipment slot containers (discovered from scene)
var slot_buttons: Dictionary = {}

# UI references
var equipment_grid: GridContainer
var item_details_panel: PanelContainer

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")  # Self-register
	add_to_group("player_menu_tab_content")  # Register as tab content
	await get_tree().process_frame
	_discover_ui_elements()
	print("⚔️ EquipmentTab: Ready")

func _discover_ui_elements():
	"""Discover UI elements from existing scene"""
	# Find equipment grid by group
	var grids = get_tree().get_nodes_in_group("equipment_grid")
	if grids.size() > 0:
		equipment_grid = grids[0]
		print("  ✓ Equipment grid registered")
		_discover_equipment_slots()
	else:
		print("  ⚠️ No equipment_grid found - add EquipmentGrid to group 'equipment_grid'")
	
	# Find or create item details panel
	var panels = get_tree().get_nodes_in_group("equipment_details_panel")
	if panels.size() > 0:
		item_details_panel = panels[0]
		print("  ✓ Equipment details panel registered")
	else:
		print("  ⚠️ No equipment details panel found in scene")

func _discover_equipment_slots():
	"""Find all equipment slot containers that exist in the scene"""
	if not equipment_grid:
		return
	
	# Find all VBoxContainer children that are slot containers
	var containers = equipment_grid.find_children("*Slot", "VBoxContainer", false, false)
	
	for container in containers:
		# Extract slot name: "Head Slot" -> "Head", "MainHand Slot" -> "Main Hand"
		var slot_name = container.name.replace(" Slot", "")
		
		# Handle MainHand/OffHand naming
		if slot_name == "MainHand":
			slot_name = "Main Hand"
		elif slot_name == "OffHand":
			slot_name = "Off Hand"
		
		slot_buttons[slot_name] = container
		
		# Connect button signal
		var button = container.get_node_or_null("SlotButton")
		if button:
			button.pressed.connect(_on_slot_clicked.bind(slot_name))
			print("  ✓ Discovered equipment slot: %s" % slot_name)

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh"""
	player = p_player
	
	# Connect to player equipment signals
	if player:
		if player.has_signal("equipment_changed") and not player.equipment_changed.is_connected(_on_player_equipment_changed):
			player.equipment_changed.connect(_on_player_equipment_changed)
	
	refresh()

func refresh():
	"""Refresh all equipment slot displays"""
	if not player:
		return
	
	print("⚔️ EquipmentTab: Refreshing - checking all slots")
	
	for slot_name in slot_buttons:
		_update_equipment_slot(slot_name)
	
	_update_offhand_state()
	
	_update_item_details()


func _update_offhand_state():
	"""Dim off-hand slot if heavy weapon is equipped"""
	var offhand_container = slot_buttons.get("Off Hand")
	if not offhand_container:
		return
	
	var main_hand_item = player.equipment.get("Main Hand")
	var is_heavy = main_hand_item != null and main_hand_item.get("is_heavy", false)
	
	if is_heavy:
		# Dim the entire off-hand slot to 50%
		offhand_container.modulate = Color(1, 1, 1, 0.5)
		
		# Optionally disable the button
		var button = offhand_container.get_node_or_null("SlotButton")
		if button:
			button.disabled = true
			button.tooltip_text = "Blocked by two-handed weapon"
	else:
		# Restore normal state
		offhand_container.modulate = Color(1, 1, 1, 1)
		
		var button = offhand_container.get_node_or_null("SlotButton")
		if button:
			button.disabled = false
			button.tooltip_text = ""

func on_external_data_change():
	"""Called when other tabs modify player data"""
	print("⚔️ EquipmentTab: External data changed - refreshing")
	refresh()

# ============================================================================
# PRIVATE DISPLAY METHODS
# ============================================================================

func _update_equipment_slot(slot_name: String):
	"""Update a single slot's display"""
	var slot_container = slot_buttons.get(slot_name)
	if not slot_container:
		print("  ⚠️ No slot container found for: %s" % slot_name)
		return
	
	var button = slot_container.get_node_or_null("SlotButton")
	if not button:
		print("  ⚠️ No button found in slot: %s" % slot_name)
		return
	
	var item = player.equipment.get(slot_name)
	
	if item:
		# Show equipped item
		print("  ⚔️ Slot %s has item: %s" % [slot_name, item.get("name", "?")])
		_apply_item_visual(button, item)
	else:
		# Empty slot
		print("  ⚔️ Slot %s is empty" % slot_name)
		_apply_empty_visual(button)

func _apply_item_visual(button: Button, item: Dictionary):
	"""Apply item visual to button"""
	# Clear any previous styling
	button.text = ""
	button.icon = null
	
	# Remove old style overrides
	button.remove_theme_stylebox_override("normal")
	button.remove_theme_stylebox_override("hover")
	button.remove_theme_stylebox_override("pressed")
	button.remove_theme_font_size_override("font_size")
	
	if item.has("icon") and item.icon:
		# Show item icon
		button.icon = item.icon
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		
		# CRITICAL: Set these properties for icon display
		button.custom_minimum_size = Vector2(80, 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Create a minimal background so button is visible
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
		bg_style.set_corner_radius_all(4)
		bg_style.set_border_width_all(1)
		bg_style.border_color = Color(0.3, 0.3, 0.3)
		button.add_theme_stylebox_override("normal", bg_style)
		
		# Hover state
		var hover_style = bg_style.duplicate()
		hover_style.border_color = Color(0.5, 0.5, 0.5)
		button.add_theme_stylebox_override("hover", hover_style)
		
		# Pressed state
		var pressed_style = bg_style.duplicate()
		pressed_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
		button.add_theme_stylebox_override("pressed", pressed_style)
	else:
		# Show colored placeholder with item initial
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = _get_item_color(item)
		stylebox.set_corner_radius_all(4)
		button.add_theme_stylebox_override("normal", stylebox)
		button.add_theme_stylebox_override("hover", stylebox)
		button.add_theme_stylebox_override("pressed", stylebox)
		
		# Show first letter of item name
		var item_name = item.get("name", "?")
		button.text = item_name[0] if item_name.length() > 0 else "?"
		button.add_theme_font_size_override("font_size", 24)

func _apply_empty_visual(button: Button):
	"""Apply empty slot visual"""
	button.icon = null
	button.text = "Empty"
	button.add_theme_font_size_override("font_size", 12)
	
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	stylebox.border_color = Color(0.4, 0.4, 0.4)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", stylebox)
	button.add_theme_stylebox_override("hover", stylebox)
	button.add_theme_stylebox_override("pressed", stylebox)

func _get_item_color(item: Dictionary) -> Color:
	"""Get color based on item slot type"""
	match item.get("slot", ""):
		"Head": return Color(0.6, 0.4, 0.4)
		"Torso": return Color(0.4, 0.6, 0.4)
		"Gloves": return Color(0.4, 0.4, 0.6)
		"Boots": return Color(0.5, 0.5, 0.3)
		"Main Hand": return Color(0.7, 0.3, 0.3)
		"Off Hand": return Color(0.3, 0.5, 0.5)
		"Accessory": return Color(0.6, 0.3, 0.6)
		_: return Color(0.5, 0.5, 0.5)

func _update_item_details():
	"""Update the item details panel"""
	if not item_details_panel:
		return
	
	# Find UI elements
	var name_labels = item_details_panel.find_children("*Name*", "Label", true, false)
	var image_rects = item_details_panel.find_children("*Image*", "TextureRect", true, false)
	var desc_labels = item_details_panel.find_children("*Desc*", "Label", true, false)
	var affix_containers = item_details_panel.find_children("*Affix*", "VBoxContainer", true, false)
	var unequip_buttons = item_details_panel.find_children("*Unequip*", "Button", true, false)
	
	# Handle no item selected
	if selected_item.is_empty():
		if name_labels.size() > 0:
			name_labels[0].text = "No Item Selected"
		if image_rects.size() > 0:
			image_rects[0].texture = null
		if desc_labels.size() > 0:
			desc_labels[0].text = "Select an equipped item to view details"
		if affix_containers.size() > 0:
			for child in affix_containers[0].get_children():
				child.queue_free()
		if unequip_buttons.size() > 0:
			unequip_buttons[0].hide()
		return
	
	# Show item details
	if name_labels.size() > 0:
		var display_name = selected_item.get("display_name", selected_item.get("name", "Unknown"))
		name_labels[0].text = display_name
	
	if image_rects.size() > 0:
		if selected_item.has("icon") and selected_item.icon:
			image_rects[0].texture = selected_item.icon
		else:
			# Create colored placeholder
			var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
			img.fill(_get_item_color(selected_item))
			image_rects[0].texture = ImageTexture.create_from_image(img)
	
	if desc_labels.size() > 0:
		desc_labels[0].text = selected_item.get("description", "")
	
	# Show affixes
	if affix_containers.size() > 0:
		var affix_container = affix_containers[0]
		
		# Clear existing
		for child in affix_container.get_children():
			child.queue_free()
		
		# Add affixes
		if selected_item.has("affixes") and selected_item.affixes is Array:
			for i in range(min(4, selected_item.affixes.size())):
				var affix = selected_item.affixes[i]
				_create_affix_display(affix_container, affix)
	
	# Show unequip button
	if unequip_buttons.size() > 0:
		unequip_buttons[0].show()

func _create_affix_display(container: VBoxContainer, affix: Dictionary):
	"""Create a display for a single affix"""
	var affix_panel = PanelContainer.new()
	
	# Style the affix panel
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.2, 0.25, 0.8)
	stylebox.border_color = Color(0.4, 0.4, 0.5)
	stylebox.set_border_width_all(1)
	stylebox.set_corner_radius_all(4)
	affix_panel.add_theme_stylebox_override("panel", stylebox)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	affix_panel.add_child(vbox)
	
	# Affix name
	var name_label = Label.new()
	name_label.text = affix.get("display_name", affix.get("name", "Unknown Affix"))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))  # Gold
	vbox.add_child(name_label)
	
	# Affix description
	var desc_label = Label.new()
	desc_label.text = affix.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	container.add_child(affix_panel)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_slot_clicked(slot_name: String):
	"""Equipment slot clicked"""
	selected_slot = slot_name
	
	# Get item from slot (might be null)
	var item = player.equipment.get(slot_name)
	
	if item != null:
		selected_item = item
		print("⚔️ Clicked slot: %s - Item: %s" % [slot_name, selected_item.get("name", "?")])
	else:
		selected_item = {}
		print("⚔️ Clicked slot: %s - Empty" % slot_name)
	
	_update_item_details()

func _on_unequip_pressed():
	"""Unequip button pressed"""
	if selected_slot.is_empty() or not player:
		return
	
	print("⚔️ Unequipping from slot: %s" % selected_slot)
	
	if player.unequip_item(selected_slot):
		item_unequipped.emit(selected_slot)
		data_changed.emit()  # Bubble up to notify other tabs
		selected_item = {}
		selected_slot = ""
		refresh()
		print("✅ Unequipped successfully")

func _on_player_equipment_changed(_slot: String, _item):
	"""Player equipment changed (bubbled from Player)"""
	refresh()
