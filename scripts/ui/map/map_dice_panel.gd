# map_dice_panel.gd - Main player panel for the map screen
# Attach to: PanelContainer
# Contains portrait, health bar, and dice grid - see DICE_GRID_SETUP.md
extends PanelContainer
class_name MapDicePanel

# ============================================================================
# SIGNALS
# ============================================================================
signal dice_order_changed(from_index: int, to_index: int)
signal die_selected(die: DieResource)
signal die_info_requested(die: DieResource)
signal roll_requested()

# ============================================================================
# NODE REFERENCES - Discovered from scene via groups
# ============================================================================
var portrait_texture: TextureRect = null
var name_label: Label = null
var health_bar: ProgressBar = null
var health_label: Label = null
var mana_bar: ProgressBar = null
var mana_label: Label = null
var dice_grid: DiceGrid = null
var dice_count_label: Label = null
var roll_button: Button = null

# ============================================================================
# STATE
# ============================================================================
var player = null
var dice_collection: PlayerDiceCollection = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_discover_nodes()
	_connect_signals()
	print("🎲 MapDicePanel ready")

func _discover_nodes():
	"""Find all UI nodes by groups"""
	# Portrait
	var portraits = _find_in_group("player_portrait")
	if portraits.size() > 0 and portraits[0] is TextureRect:
		portrait_texture = portraits[0]
	
	# Name label
	var names = _find_in_group("player_name_label")
	if names.size() > 0 and names[0] is Label:
		name_label = names[0]
	
	# Health bar
	var health_bars = _find_in_group("player_health_bar")
	if health_bars.size() > 0 and health_bars[0] is ProgressBar:
		health_bar = health_bars[0]
	
	# Health label
	var health_labels = _find_in_group("player_health_label")
	if health_labels.size() > 0 and health_labels[0] is Label:
		health_label = health_labels[0]
	
	# Mana bar (optional)
	var mana_bars = _find_in_group("player_mana_bar")
	if mana_bars.size() > 0 and mana_bars[0] is ProgressBar:
		mana_bar = mana_bars[0]
	
	# Mana label (optional)
	var mana_labels = _find_in_group("player_mana_label")
	if mana_labels.size() > 0 and mana_labels[0] is Label:
		mana_label = mana_labels[0]
	
	# Dice grid
	var grids = _find_in_group("dice_grid")
	if grids.size() > 0 and grids[0] is DiceGrid:
		dice_grid = grids[0]
	
	# Dice count label
	var count_labels = _find_in_group("dice_count_label")
	if count_labels.size() > 0 and count_labels[0] is Label:
		dice_count_label = count_labels[0]
	
	# Roll button
	var roll_buttons = _find_in_group("roll_button")
	if roll_buttons.size() > 0 and roll_buttons[0] is Button:
		roll_button = roll_buttons[0]
	
	_log_discovery()

func _find_in_group(group_name: String) -> Array:
	"""Find children in a specific group"""
	var results: Array = []
	_find_in_group_recursive(self, group_name, results)
	return results

func _find_in_group_recursive(node: Node, group_name: String, results: Array):
	"""Recursively search for nodes in group"""
	if node.is_in_group(group_name):
		results.append(node)
	for child in node.get_children():
		_find_in_group_recursive(child, group_name, results)

func _log_discovery():
	"""Log what was found"""
	print("  Portrait: %s" % ("✓" if portrait_texture else "✗"))
	print("  Name Label: %s" % ("✓" if name_label else "✗"))
	print("  Health Bar: %s" % ("✓" if health_bar else "✗"))
	print("  Health Label: %s" % ("✓" if health_label else "✗"))
	print("  Dice Grid: %s" % ("✓" if dice_grid else "✗"))
	print("  Dice Count: %s" % ("✓" if dice_count_label else "✗"))
	print("  Roll Button: %s" % ("✓" if roll_button else "✗"))

func _connect_signals():
	"""Connect signals from discovered nodes"""
	if dice_grid:
		dice_grid.dice_reordered.connect(_on_dice_reordered)
		dice_grid.die_selected.connect(_on_die_selected)
		dice_grid.die_double_clicked.connect(_on_die_double_clicked)
	
	if roll_button:
		roll_button.pressed.connect(_on_roll_pressed)

# ============================================================================
# INITIALIZATION WITH PLAYER
# ============================================================================

func initialize(p_player):
	"""Initialize with player data (accepts Resource or Node)"""
	player = p_player
	
	# Get dice collection from player - check for dice_pool (the actual property name)
	if player.get("dice_pool"):
		dice_collection = player.dice_pool
		print("🎲 MapDicePanel: Found dice_pool")
	elif player.has_node("DicePool"):
		dice_collection = player.get_node("DicePool")
		print("🎲 MapDicePanel: Found DicePool node")
	else:
		print("⚠️ MapDicePanel: No dice collection found on player")
	
	# Initialize dice grid
	if dice_grid and dice_collection:
		dice_grid.initialize(dice_collection)
		if not dice_collection.dice_changed.is_connected(_update_dice_count):
			dice_collection.dice_changed.connect(_update_dice_count)
		print("🎲 MapDicePanel: DiceGrid initialized")
	else:
		print("⚠️ MapDicePanel: Cannot initialize grid (grid=%s, collection=%s)" % [dice_grid != null, dice_collection != null])
	
	# Connect player signals
	if player.has_signal("hp_changed"):
		if not player.hp_changed.is_connected(_on_hp_changed):
			player.hp_changed.connect(_on_hp_changed)
	if player.has_signal("mana_changed"):
		if not player.mana_changed.is_connected(_on_mana_changed):
			player.mana_changed.connect(_on_mana_changed)
	
	# Initial update
	refresh()
	print("🎲 MapDicePanel: Initialized with player")

func set_dice_collection(collection: PlayerDiceCollection):
	"""Set dice collection directly"""
	dice_collection = collection
	
	if dice_grid:
		dice_grid.initialize(dice_collection)
	
	if dice_collection and not dice_collection.dice_changed.is_connected(_update_dice_count):
		dice_collection.dice_changed.connect(_update_dice_count)
	
	_update_dice_count()

# ============================================================================
# DISPLAY UPDATES
# ============================================================================

func refresh():
	"""Refresh all displays"""
	_update_player_info()
	_update_health()
	_update_mana()
	_update_dice_count()
	
	if dice_grid:
		dice_grid.refresh()

func _update_player_info():
	"""Update name and portrait"""
	if not player:
		return
	
	if name_label:
		if player.get("active_class") and player.active_class:
			name_label.text = "%s Lv.%d" % [
				player.active_class.player_class_name,
				player.active_class.level
			]
		else:
			name_label.text = "Adventurer"

func _update_health():
	"""Update health bar and label"""
	if not player:
		return
	
	var current = player.get("current_hp") if player.get("current_hp") != null else 100
	var maximum = player.get("max_hp") if player.get("max_hp") != null else 100
	
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
	
	if health_label:
		health_label.text = "%d / %d" % [current, maximum]

func _update_mana():
	"""Update mana bar and label"""
	if not player:
		return
	
	var current = player.get("current_mana") if player.get("current_mana") != null else 50
	var maximum = player.get("max_mana") if player.get("max_mana") != null else 50
	
	if mana_bar:
		mana_bar.max_value = maximum
		mana_bar.value = current
	
	if mana_label:
		mana_label.text = "%d / %d" % [current, maximum]

func _update_dice_count():
	"""Update dice count label"""
	if not dice_count_label:
		return
	
	if dice_collection:
		dice_count_label.text = "%d / %d" % [
			dice_collection.get_total_count(),
			dice_collection.max_dice
		]
	else:
		dice_count_label.text = "0 / 0"

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_hp_changed(current: int, maximum: int):
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
	if health_label:
		health_label.text = "%d / %d" % [current, maximum]

func _on_mana_changed(current: int, maximum: int):
	if mana_bar:
		mana_bar.max_value = maximum
		mana_bar.value = current
	if mana_label:
		mana_label.text = "%d / %d" % [current, maximum]

func _on_dice_reordered(from_index: int, to_index: int):
	_update_dice_count()
	dice_order_changed.emit(from_index, to_index)

func _on_die_selected(slot: DieSlot, die: DieResource):
	die_selected.emit(die)

func _on_die_double_clicked(slot: DieSlot, die: DieResource):
	die_info_requested.emit(die)

func _on_roll_pressed():
	if dice_collection:
		dice_collection.roll_all_dice()
	roll_requested.emit()

# ============================================================================
# PUBLIC API
# ============================================================================

func set_portrait(texture: Texture2D):
	"""Set portrait texture"""
	if portrait_texture:
		portrait_texture.texture = texture

func get_selected_die() -> DieResource:
	"""Get currently selected die"""
	if dice_grid:
		return dice_grid.get_selected_die()
	return null

func set_roll_button_visible(visible: bool):
	"""Show/hide roll button"""
	if roll_button:
		roll_button.visible = visible

func set_roll_button_enabled(enabled: bool):
	"""Enable/disable roll button"""
	if roll_button:
		roll_button.disabled = not enabled
