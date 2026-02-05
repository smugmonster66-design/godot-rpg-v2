# equipment_tab.gd - Equipment management tab
# Uses EquipSlotButton components for slot display
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

# Equipment slot components (discovered from scene) — slot_name -> EquipSlotButton
var slot_buttons: Dictionary = {}

# UI references
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
	_discover_equipment_slots()
	
	# Find item details panel
	var panels = get_tree().get_nodes_in_group("equipment_details_panel")
	if panels.size() > 0:
		item_details_panel = panels[0]
		print("  ✓ Equipment details panel registered")
		
		# Connect unequip button
		var unequip_buttons = item_details_panel.find_children("*Unequip*", "Button", true, false)
		if unequip_buttons.size() > 0:
			unequip_buttons[0].pressed.connect(_on_unequip_pressed)
	else:
		print("  ⚠️ No equipment details panel found in scene")

func _discover_equipment_slots():
	"""Find all EquipSlotButton instances in the scene"""
	var slot_nodes := find_children("*", "EquipSlotButton", true, false)
	
	for slot_node: EquipSlotButton in slot_nodes:
		slot_buttons[slot_node.slot_name] = slot_node
		slot_node.slot_clicked.connect(_on_slot_clicked)
		print("  ✓ Discovered equipment slot: %s" % slot_node.slot_name)
	
	if slot_buttons.is_empty():
		print("  ⚠️ No EquipSlotButton instances found in scene")

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

func on_external_data_change():
	"""Called when other tabs modify player data"""
	print("⚔️ EquipmentTab: External data changed - refreshing")
	refresh()

# ============================================================================
# PRIVATE DISPLAY METHODS
# ============================================================================

func _update_equipment_slot(slot_name: String):
	"""Update a single slot's display via its EquipSlotButton"""
	var slot: EquipSlotButton = slot_buttons.get(slot_name)
	if not slot:
		print("  ⚠️ No EquipSlotButton found for: %s" % slot_name)
		return
	
	var item = player.equipment.get(slot_name)
	
	if item:
		print("  ⚔️ Slot %s has item: %s" % [slot_name, item.get("name", "?")])
		slot.apply_item(item)
	else:
		print("  ⚔️ Slot %s is empty" % slot_name)
		slot.clear()

func _update_offhand_state():
	"""Dim off-hand slot if heavy weapon is equipped"""
	var offhand_slot: EquipSlotButton = slot_buttons.get("Off Hand")
	if not offhand_slot:
		return
	
	var main_hand_item = player.equipment.get("Main Hand")
	var is_heavy = main_hand_item != null and main_hand_item.get("is_heavy", false)
	
	if is_heavy:
		offhand_slot.modulate = Color(1, 1, 1, 0.5)
		offhand_slot.slot_button.disabled = true
		offhand_slot.slot_button.tooltip_text = "Blocked by two-handed weapon"
	else:
		offhand_slot.modulate = Color(1, 1, 1, 1)
		offhand_slot.slot_button.disabled = false
		offhand_slot.slot_button.tooltip_text = ""

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

func _get_item_color(item: Dictionary) -> Color:
	"""Get color based on item slot type — used for details panel placeholder"""
	match item.get("slot", ""):
		"Head": return Color(0.6, 0.4, 0.4)
		"Torso": return Color(0.4, 0.6, 0.4)
		"Gloves": return Color(0.4, 0.4, 0.6)
		"Boots": return Color(0.5, 0.5, 0.3)
		"Main Hand": return Color(0.7, 0.3, 0.3)
		"Off Hand": return Color(0.3, 0.5, 0.5)
		"Accessory": return Color(0.6, 0.3, 0.6)
		_: return Color(0.5, 0.5, 0.5)

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
