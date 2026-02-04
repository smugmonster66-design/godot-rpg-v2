# character_tab.gd - Character stats display
# Self-registers with parent, emits signals upward
extends Control

# ============================================================================
# SIGNALS (emitted upward)
# ============================================================================
signal refresh_requested()
signal data_changed()

# ============================================================================
# STATE
# ============================================================================
var player: Player = null

# UI references (discovered dynamically)
var stats_container: VBoxContainer
var class_label: Label
var level_label: Label
var exp_bar: ProgressBar
var exp_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")  # Self-register with group
	_discover_ui_elements()
	print("👤 CharacterTab: Ready")

func _discover_ui_elements():
	"""Discover UI elements via self-registration groups"""
	await get_tree().process_frame  # Let children register themselves
	
	# Find labels by group
	var labels = get_tree().get_nodes_in_group("character_tab_ui")
	for label in labels:
		match label.get_meta("ui_role", ""):
			"class_label": class_label = label
			"level_label": level_label = label
			"exp_label": exp_label = label
	
	# Find progress bars
	var bars = get_tree().get_nodes_in_group("character_tab_ui")
	for bar in bars:
		if bar.get_meta("ui_role", "") == "exp_bar":
			exp_bar = bar
	
	# Find stats container
	var containers = get_tree().get_nodes_in_group("character_tab_ui")
	for container in containers:
		if container.get_meta("ui_role", "") == "stats_container":
			stats_container = container
	
	# Log what we found
	if class_label: print("  ✓ Class label registered")
	if level_label: print("  ✓ Level label registered")
	if exp_label: print("  ✓ Exp label registered")
	if exp_bar: print("  ✓ Exp bar registered")
	if stats_container: print("  ✓ Stats container registered")

# No _create_ui_structure() - we only use what's in the scene!

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh (called by parent)"""
	player = p_player
	
	# Connect to player signals
	if player:
		if player.has_signal("hp_changed") and not player.hp_changed.is_connected(_on_player_hp_changed):
			player.hp_changed.connect(_on_player_hp_changed)
		
		if player.has_signal("mana_changed") and not player.mana_changed.is_connected(_on_player_mana_changed):
			player.mana_changed.connect(_on_player_mana_changed)
		
		if player.has_signal("stat_changed") and not player.stat_changed.is_connected(_on_player_stat_changed):
			player.stat_changed.connect(_on_player_stat_changed)
		
		if player.has_signal("equipment_changed") and not player.equipment_changed.is_connected(_on_player_equipment_changed):
			player.equipment_changed.connect(_on_player_equipment_changed)
	
	refresh()

func refresh():
	"""Refresh all displayed data"""
	if not player:
		return
	
	_update_class_info()
	_update_stats_display()

func on_external_data_change():
	"""Called when other tabs modify player data"""
	refresh()

# ============================================================================
# PRIVATE DISPLAY METHODS
# ============================================================================

func _update_class_info():
	"""Update class name, level, and experience"""
	if not player.active_class:
		if class_label:
			class_label.text = "No Class Selected"
		return
	
	var active_class = player.active_class
	
	if class_label:
		class_label.text = "Class: %s" % active_class.player_class_name
	
	if level_label:
		level_label.text = "Level: %d" % active_class.level
	
	if exp_bar and exp_label:
		var exp_progress = active_class.get_exp_progress()
		exp_bar.value = exp_progress * 100
		exp_label.text = "XP: %d / %d" % [
			active_class.experience,
			active_class.get_exp_for_next_level()
		]

func _update_stats_display():
	"""Rebuild stats container"""
	if not stats_container:
		return
	
	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()
	
	# Display core stats
	_add_stat_row("HP", "%d / %d" % [player.current_hp, player.max_hp], Color.RED)
	_add_stat_row("Mana", "%d / %d" % [player.current_mana, player.max_mana], Color.CYAN)
	
	_add_separator()
	
	# Defensive stats
	_add_stat_row("Armor", str(player.get_armor()), Color.GRAY)
	_add_stat_row("Barrier", str(player.get_barrier()), Color.LIGHT_BLUE)
	
	_add_separator()
	
	# Primary stats
	_add_stat_row("Strength", str(player.get_total_stat("strength")), Color.ORANGE_RED)
	_add_stat_row("Agility", str(player.get_total_stat("agility")), Color.GREEN)
	_add_stat_row("Intellect", str(player.get_total_stat("intellect")), Color.ROYAL_BLUE)
	_add_stat_row("Luck", str(player.get_total_stat("luck")), Color.GOLD)

func _add_stat_row(stat_name: String, value: String, color: Color = Color.WHITE):
	"""Add a stat display row"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	var name_label = Label.new()
	name_label.text = stat_name + ":"
	name_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(name_label)
	
	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", color)
	hbox.add_child(value_label)
	
	stats_container.add_child(hbox)

func _add_separator():
	"""Add visual separator"""
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 5)
	stats_container.add_child(separator)

# ============================================================================
# SIGNAL HANDLERS (from player - bubbled up)
# ============================================================================

func _on_player_hp_changed(_current: int, _maximum: int):
	"""Player HP changed - refresh display"""
	refresh()
	data_changed.emit()  # Bubble up to parent

func _on_player_mana_changed(_current: int, _maximum: int):
	"""Player mana changed - refresh display"""
	refresh()
	data_changed.emit()  # Bubble up to parent

func _on_player_stat_changed(_stat_name: String, _old_value, _new_value):
	"""Player stat changed - refresh display"""
	refresh()
	data_changed.emit()  # Bubble up to parent

func _on_player_equipment_changed(_slot: String, _item):
	"""Player equipment changed - refresh display"""
	refresh()
	data_changed.emit()  # Bubble up to parent
