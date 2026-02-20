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

var _active_die_tooltip: PanelContainer = null

# Add to STATE section
var _selected_button: TextureButton = null

var _details_scroll: ScrollContainer = null

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
	_ensure_details_scroll()

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
		#badge.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZES.caption)
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
	"""Update the item details panel."""
	if not item_details_panel:
		return
	
	# ── Discover fixed UI nodes ──
	var name_labels = find_children("*Name*", "Label", true, false)
	var image_rects = item_details_panel.find_children("*Image*", "TextureRect", true, false)
	var desc_labels = item_details_panel.find_children("*Desc*", "Label", true, false)
	var affix_containers = item_details_panel.find_children("*Affix*", "VBoxContainer", true, false)
	var action_buttons_containers = find_children("ActionButtons", "HBoxContainer", true, false)
	
	var use_buttons = []
	var equip_buttons = []
	if action_buttons_containers.size() > 0:
		use_buttons = action_buttons_containers[0].find_children("*Use*", "Button", false, false)
		equip_buttons = action_buttons_containers[0].find_children("*Equip*", "Button", false, false)
	
	# ── No item selected — clear everything ──
	if selected_item == null:
		# Close any floating die tooltip
		_close_die_tooltip()
		if name_labels.size() > 0:
			name_labels[0].text = "No Item Selected"
			name_labels[0].remove_theme_color_override("font_color")
			var subtitle_label = name_labels[0].get_parent().find_child("SubtitleLabel", false, false)
			if subtitle_label:
				subtitle_label.text = ""
				subtitle_label.hide()
		if image_rects.size() > 0:
			image_rects[0].texture = null
			image_rects[0].material = null
			RarityGlowHelper.clear_glow(image_rects[0])
		if desc_labels.size() > 0:
			desc_labels[0].text = ""
		if affix_containers.size() > 0:
			for child in affix_containers[0].get_children():
				child.queue_free()
		if action_buttons_containers.size() > 0:
			action_buttons_containers[0].hide()
		if _details_scroll:
			_details_scroll.scroll_vertical = 0
		return
	
	# Close any floating die tooltip from previous item
	_close_die_tooltip()
	
	# ── 1. Item name (rarity colored) + subtitle ──
	if name_labels.size() > 0:
		var rarity_name = _item_rarity_name(selected_item)
		name_labels[0].text = _item_name(selected_item)
		name_labels[0].add_theme_color_override("font_color", ThemeManager.get_rarity_color(rarity_name))
		
		# Populate subtitle label (scene sibling of ItemName)
		var subtitle_label = name_labels[0].get_parent().find_child("SubtitleLabel", false, false)
		if subtitle_label:
			if selected_item is EquippableItem:
				var slot_display = "Heavy Weapon" if selected_item.is_heavy_weapon() else selected_item.get_slot_name()
				subtitle_label.text = "%s · %s" % [selected_item.get_rarity_name(), slot_display]
				subtitle_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
				subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				subtitle_label.show()
			else:
				subtitle_label.text = ""
				subtitle_label.hide()
	
	# ── 3. Item image ──
	if image_rects.size() > 0:
		image_rects[0].custom_minimum_size = Vector2(detail_icon_size, detail_icon_size)
		var center = image_rects[0].get_parent()
		if center is CenterContainer:
			center.custom_minimum_size = Vector2(detail_container_size, detail_container_size)
		
		var item_icon = _item_icon(selected_item)
		if item_icon:
			image_rects[0].texture = item_icon
		else:
			var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
			img.fill(_get_item_type_color(selected_item))
			image_rects[0].texture = ImageTexture.create_from_image(img)
		_apply_rarity_shader_to_texture_rect(image_rects[0], selected_item)
		RarityGlowHelper.apply_glow(image_rects[0], image_rects[0].texture, _item_rarity_name(selected_item), detail_glow_config)
	
	# ── 4. Description ──
	if desc_labels.size() > 0:
		desc_labels[0].text = _item_description(selected_item)
	
	# ── Build dynamic content in affix container ──
	if affix_containers.size() > 0:
		var affix_container: VBoxContainer = affix_containers[0]
		for child in affix_container.get_children():
			child.queue_free()
		
		var equippable: EquippableItem = null
		if selected_item is EquippableItem:
			equippable = selected_item
		
		if equippable:
			# ── 5. Elemental identity ──
			var elem_row = _create_element_row(equippable)
			affix_container.add_child(elem_row)
			
			# ── 6. Dice Granted ──
			# ── 6. Dice Granted (direct + affix) ──
			if _collect_all_granted_dice(equippable).size() > 0:
				_add_section_separator(affix_container)
				var dice_section = _create_dice_granted_section(equippable)
				affix_container.add_child(dice_section)
			
			# ── 7. Action Granted ──
			if equippable.grants_action and equippable.action:
				_add_section_separator(affix_container)
				var action_label = Label.new()
				action_label.text = "Grants: %s" % equippable.action.action_name
				#action_label.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZES.caption)
				action_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
				affix_container.add_child(action_label)
				if equippable.action.action_description and equippable.action.action_description != "":
					var action_desc = Label.new()
					action_desc.text = equippable.action.action_description
					#action_desc.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZES.small)
					action_desc.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
					action_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					affix_container.add_child(action_desc)
			
			# ── 8. Base stat affixes (blue) ──
			if equippable.base_affixes.size() > 0:
				_add_section_separator(affix_container)
				for affix in equippable.base_affixes:
					if affix:
						var lbl = _create_affix_label(affix, Color(0.6, 0.75, 0.95))
						affix_container.add_child(lbl)
			
			# ── 9. Inherent affixes (green) ──
			if equippable.inherent_affixes.size() > 0:
				for affix in equippable.inherent_affixes:
					if affix:
						var lbl = _create_affix_label(affix, Color(0.7, 0.9, 0.7))
						affix_container.add_child(lbl)
			
			# ── 10. Rolled affixes (gold) ──
			if equippable.rolled_affixes.size() > 0:
				_add_section_separator(affix_container)
				for affix in equippable.rolled_affixes:
					if affix:
						var lbl = _create_affix_label(affix, Color(0.9, 0.7, 0.3))
						affix_container.add_child(lbl)
			
			# ── 11. Set info ──
			var set_def: SetDefinition = _item_set_definition(selected_item)
			if set_def:
				_add_section_separator(affix_container)
				var set_header = Label.new()
				var equipped_count: int = 0
				if player and player.set_tracker:
					equipped_count = player.set_tracker.get_equipped_count(set_def.set_id)
				set_header.text = "%s (%d/%d)" % [set_def.set_name, equipped_count, set_def.get_total_pieces()]
				set_header.add_theme_color_override("font_color", set_def.set_color)
				affix_container.add_child(set_header)
				
				for threshold in set_def.thresholds:
					var is_active = player and player.set_tracker and player.set_tracker.is_threshold_active(set_def.set_id, threshold.required_pieces)
					var threshold_label = Label.new()
					var prefix = "✓" if is_active else "✗"
					threshold_label.text = "  %s (%d) %s" % [prefix, threshold.required_pieces, threshold.description]
					threshold_label.add_theme_color_override("font_color",
						ThemeManager.PALETTE.success if is_active else ThemeManager.PALETTE.locked)
					threshold_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					affix_container.add_child(threshold_label)
			
			# ── 12. Item Level ──
			_add_section_separator(affix_container)
			if equippable.item_level > 0:
				var level_label = Label.new()
				level_label.text = "Item Level %d (Region %d)" % [equippable.item_level, equippable.region]
				level_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
				affix_container.add_child(level_label)
			
			# ── 13. Sell value ──
			var sell_label = Label.new()
			sell_label.text = "Sell: %d gold" % equippable.get_sell_value()
			sell_label.add_theme_color_override("font_color", ThemeManager.PALETTE.warning)
			affix_container.add_child(sell_label)
			
			# ── 14. Requirements (all shown: green if met, red if not) ──
			if equippable.has_requirements():
				_add_section_separator(affix_container)
				var all_reqs = []
				if equippable.required_level > 0:
					all_reqs.append(["Level %d" % equippable.required_level,
						player and player.level >= equippable.required_level])
				if equippable.required_strength > 0:
					all_reqs.append(["%d Strength" % equippable.required_strength,
						player and player.get_total_stat("strength") >= equippable.required_strength])
				if equippable.required_agility > 0:
					all_reqs.append(["%d Agility" % equippable.required_agility,
						player and player.get_total_stat("agility") >= equippable.required_agility])
				if equippable.required_intellect > 0:
					all_reqs.append(["%d Intellect" % equippable.required_intellect,
						player and player.get_total_stat("intellect") >= equippable.required_intellect])
				
				for req in all_reqs:
					var req_label = Label.new()
					req_label.text = "Requires %s" % req[0]
					req_label.add_theme_color_override("font_color",
						ThemeManager.PALETTE.success if req[1] else ThemeManager.PALETTE.danger)
					affix_container.add_child(req_label)
			
			# ── 15. Flavor text (red, centered) ──
			if equippable.flavor_text and equippable.flavor_text != "":
				_add_section_separator(affix_container)
				var flavor = Label.new()
				flavor.theme_type_variation = &"FlavorLabel"
				flavor.text = equippable.flavor_text
				flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				#flavor.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZES.small)
				flavor.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2))
				flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				affix_container.add_child(flavor)
	
	# ── Action buttons ──
	var is_equip = _is_equipment(selected_item)
	var is_consumable = _is_consumable(selected_item)
	var is_equipped = _is_item_equipped(selected_item)
	
	if action_buttons_containers.size() > 0:
		action_buttons_containers[0].show()
		
		if use_buttons.size() > 0:
			var use_btn = use_buttons[0]
			if is_consumable:
				use_btn.show()
				use_btn.text = "Use"
				for connection in use_btn.pressed.get_connections():
					use_btn.pressed.disconnect(connection.callable)
				use_btn.pressed.connect(_on_use_item_pressed)
			else:
				use_btn.hide()
		
		if equip_buttons.size() > 0:
			var equip_btn = equip_buttons[0]
			if is_equip:
				equip_btn.show()
				equip_btn.text = "Unequip" if is_equipped else "Equip"
				equip_btn.disabled = false
				
				if not is_equipped and selected_item is EquippableItem:
					if not selected_item.can_equip(player):
						equip_btn.disabled = true
				
				for connection in equip_btn.pressed.get_connections():
					equip_btn.pressed.disconnect(connection.callable)
				equip_btn.pressed.connect(_on_equip_item_pressed)
			else:
				equip_btn.hide()
	
	# Reset scroll to top when selecting a new item
	if _details_scroll:
		_details_scroll.scroll_vertical = 0



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

func _create_affix_label(affix: Affix, color: Color = Color(0.9, 0.7, 0.3)) -> Label:
	"""Create a simple colored label showing the affix's resolved description."""
	var lbl = Label.new()
	lbl.text = affix.get_resolved_description()
	#lbl.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZES.caption)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _add_section_separator(container: VBoxContainer):
	"""Add a thin horizontal line between sections."""
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	var line_style = StyleBoxLine.new()
	line_style.color = Color(1, 1, 1, 0.1)
	line_style.thickness = 1
	sep.add_theme_stylebox_override("separator", line_style)
	container.add_child(sep)

func _create_element_row(equippable: EquippableItem) -> HBoxContainer:
	"""Create a row showing the item's elemental identity (icon + label)."""
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	
	var elem_id = equippable.get_elemental_identity()
	
	# Icon (or spacer)
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if elem_id >= 0 and GameManager and GameManager.ELEMENT_VISUALS:
		var elem_icon = GameManager.ELEMENT_VISUALS.get_icon(elem_id)
		if elem_icon:
			icon_rect.texture = elem_icon
			icon_rect.modulate = GameManager.ELEMENT_VISUALS.get_tint_color(elem_id)
		
		row.add_child(icon_rect)
		
		# Element name label
		var elem_label = Label.new()
		var elem_name = ActionEffect.DamageType.keys()[elem_id].capitalize() if elem_id < ActionEffect.DamageType.size() else "Unknown"
		elem_label.text = elem_name
		#elem_label.add_theme_font_size_override("font_size", ThemeManager.FONT_SIZES.caption)
		elem_label.add_theme_color_override("font_color", GameManager.ELEMENT_VISUALS.get_tint_color(elem_id))
		row.add_child(elem_label)
	else:
		# No element — invisible spacer keeps layout consistent
		icon_rect.modulate = Color(1, 1, 1, 0)
		row.add_child(icon_rect)
	
	return row

# Keep old name as wrapper so nothing breaks elsewhere
func _create_affix_display_from_affix(affix: Affix, name_color: Color = Color(0.9, 0.7, 0.3)) -> Control:
	return _create_affix_label(affix, name_color)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _create_dice_granted_section(equippable: EquippableItem) -> VBoxContainer:
	"""Create a section showing all granted dice (direct + affix) as tappable previews."""
	var all_dice := _collect_all_granted_dice(equippable)
	
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	
	var header = Label.new()
	header.text = "Adds Dice:"
	header.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
	section.add_child(header)
	
	var dice_row = HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 8)
	
	for die_res in all_dice:
		var die_visual = die_res.instantiate_pool_visual()
		if die_visual:
			var preview_size := Vector2(60, 60)
			
			# Clickable wrapper — flat Button gives reliable hit area
			var die_btn := Button.new()
			die_btn.flat = true
			die_btn.custom_minimum_size = preview_size
			die_btn.clip_contents = true
			die_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			die_btn.pressed.connect(_on_granted_die_pressed.bind(die_btn, die_res))
			dice_row.add_child(die_btn)
			
			# Add die visual inside button
			die_btn.add_child(die_visual)
			
			# Defer overrides — _ready() resets mouse_filter/size/custom_minimum_size
			var die_scale: float = preview_size.x / die_visual.base_size.x
			_lock_die_preview.call_deferred(die_visual, die_scale)
		else:
			var fallback := Button.new()
			fallback.flat = true
			var elem_name = die_res.get_element_name() if die_res.has_element() else ""
			fallback.text = "%s D%d" % [elem_name, die_res.die_type] if elem_name else "D%d" % die_res.die_type
			fallback.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
			fallback.pressed.connect(_on_granted_die_pressed.bind(fallback, die_res))
			dice_row.add_child(fallback)
	
	section.add_child(dice_row)
	return section

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

func _collect_all_granted_dice(equippable: EquippableItem) -> Array[DieResource]:
	"""Gather every die this item grants — both direct and via affixes."""
	var dice: Array[DieResource] = []
	
	# Direct grants (dragged into grants_dice in inspector)
	for die in equippable.grants_dice:
		if die:
			dice.append(die)
	
	# Affix-granted dice (e.g. "Grant Blunt D4" utility affixes)
	for affix in equippable.item_affixes:
		if affix is Affix and affix.category == Affix.Category.DICE:
			for die in affix.granted_dice:
				if die:
					dice.append(die)
	
	return dice

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

func _ensure_details_scroll():
	"""Wrap the DetailsVBox in a ScrollContainer if not already done."""
	if not item_details_panel:
		return
	if _details_scroll:
		return  # Already wrapped
	
	var details_vbox = item_details_panel.find_child("DetailsVBox", false, false)
	if not details_vbox:
		print("  ⚠️ DetailsVBox not found — can't add scroll")
		return
	
	# Create ScrollContainer
	_details_scroll = ScrollContainer.new()
	_details_scroll.name = "DetailsScroll"
	_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Reparent: remove DetailsVBox from panel, add scroll, put vbox inside scroll
	var parent = details_vbox.get_parent()
	var idx = details_vbox.get_index()
	parent.remove_child(details_vbox)
	parent.add_child(_details_scroll)
	parent.move_child(_details_scroll, idx)
	_details_scroll.add_child(details_vbox)
	
	# Make sure DetailsVBox expands inside scroll
	details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Subtle scrollbar
	var v_bar = _details_scroll.get_v_scroll_bar()
	if v_bar:
		v_bar.modulate.a = 0.3
	
	print("  ✓ Details panel wrapped in ScrollContainer")


func _lock_die_preview(die_visual, die_scale: float):
	"""Deferred: lock down die preview after _ready() has finished."""
	if not is_instance_valid(die_visual):
		return
	die_visual.draggable = false
	die_visual.pivot_offset = Vector2.ZERO  # Scale from top-left, not center
	die_visual.scale = Vector2(die_scale, die_scale)
	die_visual.custom_minimum_size = Vector2.ZERO
	die_visual.size = die_visual.base_size
	die_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	die_visual.set_process(false)  # Disable drag cleanup process
	for child in die_visual.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var val_label = die_visual.find_child("ValueLabel", true, false)
	if val_label:
		val_label.hide()


func _on_granted_die_pressed(source: Control, die_res: DieResource):
	"""Toggle a floating popup tooltip on button press."""
	# Close existing tooltip (same die = toggle off, different die = swap)
	if _active_die_tooltip and is_instance_valid(_active_die_tooltip):
		var is_same = _active_die_tooltip.get_meta("source_die", null) == source
		_close_die_tooltip()
		if is_same:
			return
	
	_active_die_tooltip = _build_die_tooltip(die_res)
	_active_die_tooltip.set_meta("source_die", source)
	
	# Create a temporary CanvasLayer above everything
	var overlay_layer = CanvasLayer.new()
	overlay_layer.name = "DieTooltipLayer"
	overlay_layer.layer = 200  # Above all other UI layers
	get_tree().root.add_child(overlay_layer)
	overlay_layer.add_child(_active_die_tooltip)
	
	# Convert source position to screen space
	var anchor_screen_pos = source.get_screen_position() + source.size / 2.0
	_position_die_tooltip.call_deferred(anchor_screen_pos)

func _position_die_tooltip(anchor_pos: Vector2):
	"""Position the floating tooltip near the anchor point, clamped to screen."""
	if not _active_die_tooltip or not is_instance_valid(_active_die_tooltip):
		return
	
	var tooltip_size = _active_die_tooltip.size
	var viewport_size = get_viewport_rect().size
	
	# Center above the anchor
	var pos = Vector2(
		anchor_pos.x - tooltip_size.x / 2.0,
		anchor_pos.y - tooltip_size.y - 12.0
	)
	# If it would go above screen, put it below instead
	if pos.y < 8.0:
		pos.y = anchor_pos.y + 20.0
	# Clamp horizontally
	pos.x = clampf(pos.x, 8.0, viewport_size.x - tooltip_size.x - 8.0)
	
	_active_die_tooltip.position = pos
	
	# Close when tapped
	_active_die_tooltip.gui_input.connect(_on_die_tooltip_input)


func _on_die_tooltip_input(event: InputEvent):
	"""Close tooltip when tapped."""
	if event is InputEventMouseButton and event.pressed:
		_close_die_tooltip()


func _close_die_tooltip():
	"""Clean up tooltip and its CanvasLayer."""
	if _active_die_tooltip and is_instance_valid(_active_die_tooltip):
		var layer = _active_die_tooltip.get_parent()
		_active_die_tooltip.queue_free()
		if layer is CanvasLayer and layer.name == "DieTooltipLayer":
			layer.queue_free()
	_active_die_tooltip = null

func _build_die_tooltip(die_res: DieResource) -> PanelContainer:
	"""Build a compact tooltip showing die name and any dice affixes.
	Standard dice (e.g. 'Ice D6') just show name + affixes.
	Unique dice with custom names show full details."""
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(1, 1, 1, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Check if this is a standard die (name contains "D{size}") or unique
	var size_tag = "D%d" % die_res.die_type
	var is_unique = size_tag not in die_res.display_name
	
	# Die name
	var header = Label.new()
	header.text = die_res.display_name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(header)
	
	# Unique dice: show size + element beneath the name
	if is_unique:
		var subtitle = Label.new()
		var elem_name = die_res.get_element_name() if die_res.has_element() else ""
		subtitle.text = "%s %s" % [elem_name, size_tag] if elem_name else size_tag
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
		vbox.add_child(subtitle)
		
		# Flavor text if present
		if die_res.has_method("get_flavor_text"):
			var flavor = die_res.get_flavor_text()
			if flavor and flavor != "":
				var flavor_label = Label.new()
				flavor_label.text = flavor
				flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				flavor_label.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2))
				flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(flavor_label)
	
	# Dice affixes
	var all_affixes = die_res.get_all_affixes()
	for dice_affix in all_affixes:
		if not dice_affix:
			continue
		var affix_label = Label.new()
		affix_label.text = dice_affix.get_description() if dice_affix.has_method("get_description") else dice_affix.affix_name
		affix_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		vbox.add_child(affix_label)
	
	return panel

func _update_category_button_visuals():
	"""Dim unselected category buttons to 50%"""
	for button in category_buttons:
		if button.button_pressed:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			button.modulate = Color(1.0, 1.0, 1.0, 0.5)
