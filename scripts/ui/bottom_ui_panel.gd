# res://scripts/ui/bottom_ui_panel.gd
# Persistent bottom UI panel - always visible over map and combat
# Contains portrait, player stats, dice grid, and menu button
extends PanelContainer
class_name BottomUIPanel

# ============================================================================
# SIGNALS
# ============================================================================
signal menu_button_pressed

const MANA_SELECTOR_SCENE = preload("res://scenes/ui/combat/mana_die_selector.tscn")

# ============================================================================
# NODE REFERENCES - Matching actual scene structure
# ============================================================================

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
var mana_die_selector: ManaDieSelector = null


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
	
	# Initialize mana die selector (replaces simple mana bar for casters)
	_setup_mana_die_selector()
	
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



func _setup_mana_die_selector():
	"""Instance and insert ManaDieSelector scene if player is a caster.
	Hides the simple ManaBar for all classes — non-casters have no use for it."""
	if not player:
		return

	# Remove old selector if reinitializing
	if mana_die_selector and is_instance_valid(mana_die_selector):
		mana_die_selector.queue_free()
		mana_die_selector = null

	# Hide the simple mana bar unconditionally — casters get the selector,
	# non-casters don't need any mana UI
	if mana_bar:
		mana_bar.hide()

	if player.has_method("has_mana_pool") and player.has_mana_pool():
		mana_die_selector = MANA_SELECTOR_SCENE.instantiate()

		# Insert right after the (now hidden) ManaBar in LeftSection
		if left_section and mana_bar:
			var mana_bar_idx = mana_bar.get_index()
			left_section.add_child(mana_die_selector)
			left_section.move_child(mana_die_selector, mana_bar_idx + 1)
		elif left_section:
			left_section.add_child(mana_die_selector)

		mana_die_selector.initialize(player)
		print("  ✅ ManaDieSelector instanced and initialized")
	else:
		print("  ℹ️ No mana pool — mana UI hidden")
func set_mana_drag_enabled(enabled: bool):
	"""Enable/disable mana die dragging. Called by CombatManager on phase change."""
	if mana_die_selector:
		mana_die_selector.set_drag_enabled(enabled)


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
	if not _can_open_menu():
		print("📱 Menu blocked — combat action phase")
		return
	menu_button_pressed.emit()
	if player_menu and player_menu.has_method("toggle_menu") and player:
		player_menu.toggle_menu(player)

func _can_open_menu() -> bool:
	"""Check if the player menu is allowed to open."""
	if not GameManager or not GameManager.game_root:
		return true
	if not GameManager.game_root.is_in_combat:
		return true
	var combat_manager = get_tree().get_first_node_in_group("combat_manager")
	if combat_manager and combat_manager.has_method("is_in_prep_phase"):
		return combat_manager.is_in_prep_phase()
	return false

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
