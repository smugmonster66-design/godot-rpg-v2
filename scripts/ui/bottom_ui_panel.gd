# res://scripts/ui/bottom_ui_panel.gd
# Persistent bottom UI panel - always visible over map and combat
# Contains portrait, player stats, dice grid, and menu button
extends PanelContainer
class_name BottomUIPanel

# ============================================================================
# SIGNALS
# ============================================================================
signal menu_button_pressed

# ============================================================================
# NODE REFERENCES - Matching actual scene structure
# ============================================================================
# Portrait section
@onready var portrait_section: VBoxContainer = $MainHBox/PortraitSection
@onready var portrait_container: Control = $MainHBox/PortraitSection/PortraitVBox/PortraitContainer
@onready var portrait_back_panel: Panel = $MainHBox/PortraitSection/PortraitVBox/PortraitContainer/BackPanel
@onready var portrait_texture: TextureRect = $MainHBox/PortraitSection/PortraitVBox/PortraitContainer/PortraitTexture
@onready var portrait_front_panel: Panel = $MainHBox/PortraitSection/PortraitVBox/PortraitContainer/FrontPanel

# Left section - stats and dice
@onready var left_section: VBoxContainer = $MainHBox/LeftSection
@onready var class_label: Label = $MainHBox/LeftSection/Label
@onready var health_bar: TextureProgressBar = $MainHBox/LeftSection/HealthBar
@onready var mana_bar: TextureProgressBar = $MainHBox/LeftSection/ManaBar
@onready var exp_bar: TextureProgressBar = $MainHBox/LeftSection/ExpBar

# Dice section
@onready var dice_section: VBoxContainer = $MainHBox/LeftSection/DiceSection
@onready var dice_grid: Control = $MainHBox/LeftSection/DiceSection/DiceGrid
@onready var dice_count_label: Label = $MainHBox/LeftSection/DiceSection/DiceHeader/DiceCountLabel

# Right section - menu button
@onready var right_section: VBoxContainer = $MainHBox/RightSection
@onready var menu_button: Button = $MainHBox/RightSection/MenuButton

# ============================================================================
# STATE
# ============================================================================
var player: Resource = null
var player_menu: Control = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("📱 BottomUIPanel ready")
	
	# Connect button signals
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
		print("  ✅ Menu button connected")
	else:
		print("  ❌ Menu button not found at $MainHBox/RightSection/MenuButton")
	
	# Check dice grid exists
	if dice_grid:
		print("  ✅ Dice grid found: %s" % dice_grid)
	else:
		print("  ❌ Dice grid NOT found at $MainHBox/LeftSection/DiceSection/DiceGrid")
	
	# NOTE: Don't initialize with player here - GameRoot calls initialize() 
	# after GameManager.player_created fires

func initialize(p_player: Resource):
	"""Initialize with player reference"""
	player = p_player
	print("📱 BottomUIPanel: Initializing with player")
	print("  player: %s" % player)
	
	if not player:
		print("  ❌ Player is null!")
		return
	
	# Initialize dice grid
	if dice_grid:
		print("  dice_grid: %s" % dice_grid)
		if dice_grid.has_method("initialize"):
			var dice_collection = player.get("dice_pool")
			if dice_collection:
				dice_grid.initialize(dice_collection)
				print("  ✅ Dice grid initialized with dice_pool")
				
				# Connect to dice_changed signal for count updates
				if dice_collection.has_signal("dice_changed"):
					if not dice_collection.dice_changed.is_connected(_update_dice_count):
						dice_collection.dice_changed.connect(_update_dice_count)
				_update_dice_count()
			else:
				print("  ⚠️ Player has no dice_pool")
		else:
			print("  ⚠️ Dice grid has no initialize method")
	else:
		print("  ❌ No dice_grid reference")
	
	# Update player stats display
	_update_stats_display()
	
	# Connect to player signals for live updates
	_connect_player_signals()
	
	print("📱 BottomUIPanel: Initialization complete")

func set_player_menu(menu: Control):
	"""Set reference to player menu for toggle"""
	player_menu = menu
	print("📱 BottomUIPanel: Player menu reference set")

# ============================================================================
# STATS DISPLAY
# ============================================================================

func _update_stats_display():
	"""Update all stat displays from player data"""
	if not player:
		return
	
	# Class and level label
	if class_label:
		var display_class_name = "Unknown"
		var display_level = 1
		if player.active_class:
			display_class_name = player.active_class.player_class_name
			display_level = player.active_class.level
		class_label.text = "%s Lvl %d" % [display_class_name, display_level]
	
	# Health bar
	if health_bar:
		health_bar.max_value = player.max_hp
		health_bar.value = player.current_hp
	
	# Mana bar
	if mana_bar:
		mana_bar.max_value = player.max_mana
		mana_bar.value = player.current_mana
	
	# Experience bar
	if exp_bar and player.active_class:
		exp_bar.max_value = player.active_class.get_exp_for_next_level()
		exp_bar.value = player.active_class.experience

func _update_dice_count():
	"""Update the dice count label"""
	if not dice_count_label:
		return
	
	if player and player.dice_pool:
		var current = player.dice_pool.get_pool_count()
		var max_dice = player.dice_pool.max_dice if player.dice_pool.get("max_dice") else 10
		dice_count_label.text = "%d/%d" % [current, max_dice]

func _connect_player_signals():
	"""Connect to player signals for live stat updates"""
	if not player:
		return
	
	if player.has_signal("hp_changed"):
		if not player.hp_changed.is_connected(_on_hp_changed):
			player.hp_changed.connect(_on_hp_changed)
	
	if player.has_signal("mana_changed"):
		if not player.mana_changed.is_connected(_on_mana_changed):
			player.mana_changed.connect(_on_mana_changed)
	
	if player.has_signal("class_changed"):
		if not player.class_changed.is_connected(_on_class_changed):
			player.class_changed.connect(_on_class_changed)

func _on_hp_changed(current: int, maximum: int):
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current

func _on_mana_changed(current: int, maximum: int):
	if mana_bar:
		mana_bar.max_value = maximum
		mana_bar.value = current

func _on_class_changed(_new_class):
	_update_stats_display()

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_menu_button_pressed():
	print("📱 Menu button pressed")
	menu_button_pressed.emit()
	if player_menu and player_menu.has_method("toggle_menu") and player:
		player_menu.toggle_menu(player)


# ============================================================================
# COMBAT STATE CALLBACKS
# ============================================================================

func on_combat_started():
	"""Called when combat begins"""
	# Could hide/show certain elements during combat
	pass

func on_combat_ended(_player_won: bool):
	"""Called when combat ends"""
	# Refresh displays after combat
	_update_stats_display()
	if dice_grid and dice_grid.has_method("refresh"):
		dice_grid.refresh()

# ============================================================================
# PUBLIC API
# ============================================================================

func get_dice_panel() -> Control:
	"""Return the dice grid for external access"""
	return dice_grid

func refresh_dice():
	"""Refresh the dice grid display"""
	if dice_grid and dice_grid.has_method("refresh"):
		dice_grid.refresh()
	_update_dice_count()

func refresh_stats():
	"""Refresh the stats display"""
	_update_stats_display()

func set_portrait(texture: Texture2D):
	"""Set the portrait texture"""
	if portrait_texture:
		portrait_texture.texture = texture

func set_back_panel_style(style: StyleBox):
	"""Set the back panel style (behind portrait)"""
	if portrait_back_panel:
		portrait_back_panel.add_theme_stylebox_override("panel", style)

func set_front_panel_style(style: StyleBox):
	"""Set the front panel style (frame in front of portrait)"""
	if portrait_front_panel:
		portrait_front_panel.add_theme_stylebox_override("panel", style)
