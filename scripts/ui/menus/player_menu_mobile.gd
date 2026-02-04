# player_menu_scene.gd
# Menu that uses scene-based UI nodes (not code-generated)
extends Control

var player: Player = null
var current_tab: String = "Character"

# Get references to scene nodes
@onready var character_button = $MainVBox/NavBarPanel/NavBar/CharacterButton
@onready var skills_button = $MainVBox/NavBarPanel/NavBar/SkillsButton
@onready var equipment_button = $MainVBox/NavBarPanel/NavBar/EquipmentButton
@onready var inventory_button = $MainVBox/NavBarPanel/NavBar/InventoryButton
@onready var content_container = $MainVBox/ContentContainer
@onready var close_button = $MainVBox/BottomBar/CloseButton

var nav_buttons: Dictionary = {}

signal menu_closed()

func _ready():
	print("📱 Player Menu (Scene-based) initializing...")
	
	# Store button references
	nav_buttons = {
		"Character": character_button,
		"Skills": skills_button,
		"Equipment": equipment_button,
		"Inventory": inventory_button
	}
	
	# Connect button signals
	character_button.pressed.connect(func(): switch_tab("Character"))
	skills_button.pressed.connect(func(): switch_tab("Skills"))
	equipment_button.pressed.connect(func(): switch_tab("Equipment"))
	inventory_button.pressed.connect(func(): switch_tab("Inventory"))
	close_button.pressed.connect(_on_close_pressed)
	
	# Start hidden
	hide()
	
	print("📱 Player Menu ready")

func open_menu(p_player: Player):
	"""Open the menu"""
	player = p_player
	show()
	switch_tab("Character")  # Always start on Character

func switch_tab(tab_name: String):
	"""Switch to a different tab"""
	if current_tab == tab_name:
		return
	
	print("📱 Switching to: %s" % tab_name)
	current_tab = tab_name
	
	# Update button visual states
	update_button_states()
	
	# Load tab content
	load_tab_content(tab_name)

func update_button_states():
	"""Update active/inactive button appearances"""
	for name in nav_buttons:
		var btn = nav_buttons[name]
		var is_active = (name == current_tab)
		
		if is_active:
			# Active button - bright
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if btn.get_child_count() > 0:
				var label = btn.get_child(0)
				label.add_theme_color_override("font_color", Color.WHITE)
		else:
			# Inactive button - dimmed
			btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
			if btn.get_child_count() > 0:
				var label = btn.get_child(0)
				label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func load_tab_content(tab_name: String):
	"""Load the appropriate tab content"""
	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()
	
	var new_tab: Control = null
	
	match tab_name:
		"Character":
			new_tab = load_character_tab()
		"Skills":
			new_tab = load_skills_tab()
		"Equipment":
			new_tab = load_equipment_tab()
		"Inventory":
			new_tab = load_inventory_tab()
	
	if new_tab:
		new_tab.set_anchors_preset(Control.PRESET_FULL_RECT)
		content_container.add_child(new_tab)
		
		if new_tab.has_method("set_player"):
			new_tab.set_player(player)

func load_character_tab() -> Control:
	var script = load("res://scripts/character_tab.gd")
	var tab = Control.new()
	tab.set_script(script)
	return tab

func load_skills_tab() -> Control:
	var script = load("res://scripts/skills_tab.gd")
	var tab = Control.new()
	tab.set_script(script)
	return tab

func load_equipment_tab() -> Control:
	var script = load("res://scripts/equipment_tab.gd")
	var tab = Control.new()
	tab.set_script(script)
	return tab

func load_inventory_tab() -> Control:
	var script = load("res://scripts/inventory_tab_mobile.gd")
	var tab = Control.new()
	tab.set_script(script)
	return tab

func _on_close_pressed():
	hide()
	menu_closed.emit()

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
