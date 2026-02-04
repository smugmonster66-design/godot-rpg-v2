# post_combat_summary.gd - Post-combat results popup
extends Control

# ============================================================================
# NODE REFERENCES (assigned in scene)
# ============================================================================
@onready var overlay = $ColorRect
@onready var title_label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var exp_value = $CenterContainer/PanelContainer/VBoxContainer/ExpSection/ExpValue
@onready var loot_grid = $CenterContainer/PanelContainer/VBoxContainer/LootSection/LootGrid
@onready var close_button = $CenterContainer/PanelContainer/VBoxContainer/CloseButton

# ============================================================================
# SIGNALS
# ============================================================================
signal summary_closed()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	hide()
	close_button.pressed.connect(_on_close_pressed)
	overlay.gui_input.connect(_on_overlay_clicked)

# ============================================================================
# PUBLIC API
# ============================================================================

func show_summary(results: Dictionary):
	"""Display combat results
	
	results = {
		"victory": bool,
		"xp_gained": int,
		"loot": Array[Dictionary]
	}
	"""
	print("📊 Showing post-combat summary")
	
	# Set title
	if results.get("victory", false):
		title_label.text = "🎉 VICTORY! 🎉"
		title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		title_label.text = "💀 DEFEAT 💀"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	
	# Set XP
	var xp = results.get("xp_gained", 0)
	if xp > 0:
		exp_value.text = "+%d XP" % xp
		exp_value.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	else:
		exp_value.text = "No experience gained"
		exp_value.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	# Clear old loot
	for child in loot_grid.get_children():
		child.queue_free()
	
	# Display loot
	var loot = results.get("loot", [])
	if loot.size() > 0:
		for item in loot:
			var item_card = create_loot_card(item)
			loot_grid.add_child(item_card)
	else:
		var no_loot = Label.new()
		no_loot.text = "No loot found"
		no_loot.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		loot_grid.add_child(no_loot)
	
	show()

func create_loot_card(item: Dictionary) -> Control:
	"""Create a simple loot display card"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 120)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	
	# Item icon placeholder
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(80, 80)
	icon.color = get_item_color(item)
	vbox.add_child(icon)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(name_label)
	
	return card

func get_item_color(item: Dictionary) -> Color:
	"""Get color for item type"""
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
# SIGNAL HANDLERS
# ============================================================================

func _on_close_pressed():
	"""Close button clicked"""
	print("📊 Closing summary")
	hide()
	summary_closed.emit()

func _on_overlay_clicked(event: InputEvent):
	"""Click overlay to close"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()

# ============================================================================
# INPUT
# ============================================================================

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
