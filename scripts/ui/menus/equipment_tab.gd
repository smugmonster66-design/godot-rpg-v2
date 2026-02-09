# equipment_tab.gd - Equipment management tab
# v3 — Reads EquippableItem directly instead of Dictionary.
extends Control

# ============================================================================
# SIGNALS (emitted upward)
# ============================================================================
signal refresh_requested()
signal data_changed()
signal item_equipped(slot: String, item: EquippableItem)
signal item_unequipped(slot: String)

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var selected_slot: String = ""
var selected_item: EquippableItem = null

# Equipment slot components (discovered from scene) — slot_name -> EquipSlotButton
var slot_buttons: Dictionary = {}

# UI references
var item_details_panel: PanelContainer

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")
	add_to_group("player_menu_tab_content")
	await get_tree().process_frame
	_discover_ui_elements()
	print("⚔️ EquipmentTab: Ready")

func _discover_ui_elements():
	_discover_equipment_slots()
	
	var panels = get_tree().get_nodes_in_group("equipment_details_panel")
	if panels.size() > 0:
		item_details_panel = panels[0]
		print("  ✓ Equipment details panel registered")
		
		var unequip_buttons = item_details_panel.find_children("*Unequip*", "Button", true, false)
		if unequip_buttons.size() > 0:
			unequip_buttons[0].pressed.connect(_on_unequip_pressed)
	else:
		print("  ⚠️ No equipment details panel found in scene")

func _discover_equipment_slots():
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
	player = p_player
	
	if player:
		if player.has_signal("equipment_changed") and not player.equipment_changed.is_connected(_on_player_equipment_changed):
			player.equipment_changed.connect(_on_player_equipment_changed)
	
	refresh()

func refresh():
	if not player:
		return
	
	print("⚔️ EquipmentTab: Refreshing")
	
	for slot_name in slot_buttons:
		_update_equipment_slot(slot_name)
	
	_update_offhand_state()
	_update_item_details()

func on_external_data_change():
	print("⚔️ EquipmentTab: External data changed - refreshing")
	refresh()

# ============================================================================
# PRIVATE DISPLAY METHODS
# ============================================================================

func _update_equipment_slot(slot_name: String):
	var slot: EquipSlotButton = slot_buttons.get(slot_name)
	if not slot:
		return
	
	var item: EquippableItem = player.equipment.get(slot_name)
	
	if item:
		slot.apply_equippable(item)
	else:
		slot.clear()

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

func _update_item_details():
	if not item_details_panel:
		return
	
	var name_labels = item_details_panel.find_children("*Name*", "Label", true, false)
	var image_rects = item_details_panel.find_children("*Image*", "TextureRect", true, false)
	var desc_labels = item_details_panel.find_children("*Desc*", "Label", true, false)
	var affix_containers = item_details_panel.find_children("*Affix*", "VBoxContainer", true, false)
	var unequip_buttons = item_details_panel.find_children("*Unequip*", "Button", true, false)
	
	if not selected_item:
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
	
	# Show item details from EquippableItem
	if name_labels.size() > 0:
		name_labels[0].text = selected_item.item_name
		name_labels[0].add_theme_color_override("font_color", selected_item.get_rarity_color())
	
	if image_rects.size() > 0:
		if selected_item.icon:
			image_rects[0].texture = selected_item.icon
		else:
			var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
			img.fill(_get_slot_color(selected_item.get_slot_name()))
			image_rects[0].texture = ImageTexture.create_from_image(img)
	
	if desc_labels.size() > 0:
		desc_labels[0].text = selected_item.description
	
	# Affix list
	if affix_containers.size() > 0:
		var affix_container = affix_containers[0]
		for child in affix_container.get_children():
			child.queue_free()
		
		# Inherent affixes
		for affix in selected_item.inherent_affixes:
			if affix:
				_add_affix_label(affix_container, affix, Color(0.7, 0.8, 0.7))
		
		# Rolled affixes
		for affix in selected_item.rolled_affixes:
			_add_affix_label(affix_container, affix, Color(0.9, 0.7, 0.3))
		
		# Set info
		if selected_item.set_definition:
			var set_label = Label.new()
			set_label.text = "Set: %s" % selected_item.set_definition.set_name
			set_label.add_theme_color_override("font_color", selected_item.set_definition.set_color)
			set_label.add_theme_font_size_override("font_size", 13)
			affix_container.add_child(set_label)
		
		# Flavor text
		if selected_item.flavor_text != "":
			var flavor_label = Label.new()
			flavor_label.text = selected_item.flavor_text
			flavor_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
			flavor_label.add_theme_font_size_override("font_size", 11)
			flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			affix_container.add_child(flavor_label)
		
		# Sell value
		var sell_label = Label.new()
		sell_label.text = "Sell: %d gold" % selected_item.get_sell_value()
		sell_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
		sell_label.add_theme_font_size_override("font_size", 11)
		affix_container.add_child(sell_label)
	
	if unequip_buttons.size() > 0:
		unequip_buttons[0].show()

func _add_affix_label(container: VBoxContainer, affix: Affix, color: Color):
	"""Add a single affix display to the container."""
	var affix_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.6)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	affix_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	affix_panel.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = affix.affix_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", color)
	vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = affix.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	container.add_child(affix_panel)

func _get_slot_color(slot_name: String) -> Color:
	match slot_name:
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
	selected_slot = slot_name
	var item: EquippableItem = player.equipment.get(slot_name)
	
	if item != null:
		selected_item = item
		print("⚔️ Clicked slot: %s - Item: %s" % [slot_name, item.item_name])
	else:
		selected_item = null
		print("⚔️ Clicked slot: %s - Empty" % slot_name)
	
	_update_item_details()

func _on_unequip_pressed():
	if selected_slot.is_empty() or not player:
		return
	
	print("⚔️ Unequipping from slot: %s" % selected_slot)
	
	if player.unequip_item(selected_slot):
		item_unequipped.emit(selected_slot)
		data_changed.emit()
		selected_item = null
		selected_slot = ""
		refresh()

func _on_player_equipment_changed(_slot: String, _item):
	refresh()
