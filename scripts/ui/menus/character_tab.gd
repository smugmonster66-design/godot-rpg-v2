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
	"""Rebuild stats container with comprehensive debug info"""
	if not stats_container:
		return
	
	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()
	
	# ── Vitals ──
	_add_section_header("Vitals")
	_add_stat_row("HP", "%d / %d" % [player.current_hp, player.max_hp], Color.RED)
	_add_stat_row("Mana", "%d / %d" % [player.current_mana, player.max_mana], Color.CYAN)
	
	_add_separator()
	
	# ── Primary Stats ──
	_add_section_header("Primary Stats")
	_add_stat_row("Strength", str(player.get_total_stat("strength")), Color.ORANGE_RED)
	_add_stat_row("Agility", str(player.get_total_stat("agility")), Color.GREEN)
	_add_stat_row("Intellect", str(player.get_total_stat("intellect")), Color.ROYAL_BLUE)
	_add_stat_row("Luck", str(player.get_total_stat("luck")), Color.GOLD)
	
	_add_separator()
	
	# ── Defense ──
	_add_section_header("Defense")
	_add_stat_row("Armor", str(player.get_armor()), Color.GRAY)
	_add_stat_row("Barrier", str(player.get_barrier()), Color.LIGHT_BLUE)
	
	_add_separator()
	
	# ── Resistances ──
	_add_section_header("Resistances")
	_add_stat_row("Fire Resist", str(player.get_resist("fire")), Color.ORANGE_RED)
	_add_stat_row("Ice Resist", str(player.get_resist("ice")), Color.SKY_BLUE)
	_add_stat_row("Shock Resist", str(player.get_resist("shock")), Color.YELLOW)
	_add_stat_row("Poison Resist", str(player.get_resist("poison")), Color.DARK_GREEN)
	_add_stat_row("Shadow Resist", str(player.get_resist("shadow")), Color.DARK_VIOLET)
	
	_add_separator()
	
	# ── Combat Modifiers (from AffixPoolManager) ──
	_add_section_header("Combat Modifiers")
	var dmg_bonus_count = player.affix_manager.get_pool(Affix.Category.DAMAGE_BONUS).size()
	var dmg_mult_count = player.affix_manager.get_pool(Affix.Category.DAMAGE_MULTIPLIER).size()
	var def_bonus_count = player.affix_manager.get_pool(Affix.Category.DEFENSE_BONUS).size()
	var def_mult_count = player.affix_manager.get_pool(Affix.Category.DEFENSE_MULTIPLIER).size()
	_add_stat_row("Dmg Bonuses", str(dmg_bonus_count), Color.WHITE)
	_add_stat_row("Dmg Multipliers", str(dmg_mult_count), Color.WHITE)
	_add_stat_row("Def Bonuses", str(def_bonus_count), Color.WHITE)
	_add_stat_row("Def Multipliers", str(def_mult_count), Color.WHITE)
	
	# Granted actions
	var granted_actions = player.affix_manager.get_granted_actions()
	if granted_actions.size() > 0:
		_add_stat_row("Granted Actions", str(granted_actions.size()), Color.MEDIUM_PURPLE)
		for action in granted_actions:
			var action_name = action.action_name if "action_name" in action else str(action)
			_add_stat_row("  •", action_name, Color(0.7, 0.6, 0.9))
	
	_add_separator()
	
	# ── Active Affixes (debug) ──
	_add_section_header("Active Affixes")
	var total_affixes: int = 0
	for category in player.affix_manager.pools:
		var pool = player.affix_manager.pools[category]
		for affix in pool:
			if affix.show_in_active_list:
				_add_stat_row("•", affix.affix_name, Color(0.6, 0.6, 0.6))
				total_affixes += 1
	if total_affixes == 0:
		_add_stat_row("", "None", Color(0.5, 0.5, 0.5))
	
	_add_separator()
	
	# ── Equipment Sets ──
	_add_section_header("Equipment Sets")
	if player.set_tracker:
		var active_sets = player.set_tracker.get_active_sets()
		if active_sets.is_empty():
			_add_stat_row("", "No sets equipped", Color(0.5, 0.5, 0.5))
		else:
			for set_id in active_sets:
				var info = active_sets[set_id]
				var set_def: SetDefinition = info.definition
				_add_stat_row(set_def.set_name, "%d / %d" % [info.count, info.total], set_def.set_color)
				for threshold in set_def.thresholds:
					var is_active = player.set_tracker.is_threshold_active(set_id, threshold.required_pieces)
					var prefix = "✓" if is_active else "✗"
					var color = Color.GREEN if is_active else Color(0.4, 0.4, 0.4)
					_add_stat_row("  %s (%d)" % [prefix, threshold.required_pieces], threshold.description, color)
	else:
		_add_stat_row("", "No set tracker", Color(0.5, 0.5, 0.5))
	
	_add_separator()
	
	# ── Dice Pool ──
	_add_section_header("Dice Pool")
	if player.dice_pool:
		_add_stat_row("Total Dice", str(player.dice_pool.dice.size()), Color.WHITE)
		var sources: Dictionary = {}
		for die in player.dice_pool.dice:
			var src = die.source if die.source else "Base"
			sources[src] = sources.get(src, 0) + 1
		for src in sources:
			_add_stat_row("  %s" % src, "×%d" % sources[src], Color(0.7, 0.7, 0.7))
	else:
		_add_stat_row("", "No dice pool", Color(0.5, 0.5, 0.5))

func _add_section_header(title: String):
	"""Add a bold section header"""
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	stats_container.add_child(label)



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
