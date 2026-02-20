# character_tab.gd - Character stats display (v2)
# Clean player-facing stat summary.
# Sections: Vitals, Primary Stats, Defense, Gold.
# Self-registers with parent, emits signals upward.
extends Control

# ============================================================================
# SIGNALS (emitted upward)
# ============================================================================
signal refresh_requested()
signal data_changed()

# ============================================================================
# CONSTANTS
# ============================================================================
## Resource bars
const BAR_HEIGHT := 40
const BAR_CORNER_RADIUS := 6

## Stat row label width
const STAT_LABEL_MIN_WIDTH := 200

# ============================================================================
# STATE
# ============================================================================
var player: Player = null

# UI references (discovered dynamically via groups + metadata)
var stats_container: VBoxContainer
var class_label: Label
var level_label: Label
var exp_bar: ProgressBar
var exp_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")
	_discover_ui_elements()
	print("👤 CharacterTab: Ready (v2)")


func _discover_ui_elements():
	"""Discover UI elements scoped to this tab's subtree"""
	await get_tree().process_frame

	var ui_nodes = find_children("*", "", true, false)
	for node in ui_nodes:
		if not node.is_in_group("character_tab_ui"):
			continue
		match node.get_meta("ui_role", ""):
			"class_label": class_label = node
			"level_label": level_label = node
			"exp_label": exp_label = node
			"exp_bar": exp_bar = node
			"stats_container": stats_container = node

	if class_label: print("  ✓ Class label registered")
	if level_label: print("  ✓ Level label registered")
	if exp_label: print("  ✓ Exp label registered")
	if exp_bar: print("  ✓ Exp bar registered")
	if stats_container: print("  ✓ Stats container registered")

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	"""Set player and refresh (called by parent)"""
	player = p_player

	if player:
		if player.has_signal("hp_changed") and not player.hp_changed.is_connected(_on_player_hp_changed):
			player.hp_changed.connect(_on_player_hp_changed)
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
# HEADER — Class / Level / XP
# ============================================================================

func _update_class_info():
	"""Update class name, level, and experience"""
	if not player.active_class:
		if class_label:
			class_label.text = "No Class Selected"
		return

	var active_class = player.active_class

	if class_label:
		class_label.text = active_class.player_class_name

	if level_label:
		level_label.text = "Level %d" % active_class.level

	if exp_bar and exp_label:
		exp_bar.show_percentage = false
		exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		exp_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
		var exp_progress = active_class.get_exp_progress()
		exp_bar.value = exp_progress * 100

		# Style exp bar fill — yellow/warning color
		var exp_fill = StyleBoxFlat.new()
		exp_fill.bg_color = ThemeManager.PALETTE.warning
		exp_fill.set_corner_radius_all(BAR_CORNER_RADIUS)
		exp_bar.add_theme_stylebox_override("fill", exp_fill)

		# Style exp bar background
		var exp_bg = StyleBoxFlat.new()
		exp_bg.bg_color = ThemeManager.PALETTE.bg_dark
		exp_bg.set_corner_radius_all(BAR_CORNER_RADIUS)
		exp_bg.border_color = ThemeManager.PALETTE.border_subtle
		exp_bg.set_border_width_all(1)
		exp_bar.add_theme_stylebox_override("background", exp_bg)

		exp_label.text = "%d / %d" % [
			active_class.experience,
			active_class.get_exp_for_next_level()
		]

# ============================================================================
# STATS DISPLAY — Four sections only
# ============================================================================

func _update_stats_display():
	"""Rebuild the stats container with player-facing sections."""
	if not stats_container:
		return

	for child in stats_container.get_children():
		child.queue_free()

	_build_vitals_section()
	_add_separator()

	_build_primary_stats_section()
	_add_separator()

	_build_defense_section()
	_add_separator()

	_build_gold_section()

# ============================================================================
# SECTION BUILDERS
# ============================================================================

func _build_vitals_section():
	"""HP bar"""
	_add_section_header("Vitals")

	_add_resource_bar(
		"HP",
		player.current_hp,
		player.max_hp,
		ThemeManager.PALETTE.health,
		ThemeManager.PALETTE.health_low
	)


func _build_primary_stats_section():
	"""STR / AGI / INT / LCK with base (+bonus) breakdown"""
	_add_section_header("Primary Stats")

	var stat_configs = [
		["Strength", "strength", ThemeManager.PALETTE.strength],
		["Agility", "agility", ThemeManager.PALETTE.agility],
		["Intellect", "intellect", ThemeManager.PALETTE.intellect],
		["Luck", "luck", ThemeManager.PALETTE.luck],
	]

	for config in stat_configs:
		var display_name: String = config[0]
		var stat_name: String = config[1]
		var color: Color = config[2]

		var base_val: int = player.get_base_stat(stat_name)
		var total_val: int = player.get_total_stat(stat_name)
		var bonus: int = total_val - base_val

		var value_text: String
		if bonus > 0:
			value_text = "%d (+%d)" % [base_val, bonus]
		elif bonus < 0:
			value_text = "%d (%d)" % [base_val, bonus]
		else:
			value_text = str(total_val)

		_add_stat_row(display_name, value_text, color)


func _build_defense_section():
	"""Armor and Barrier with raw value + % reduction"""
	_add_section_header("Defense")

	var armor_val: int = player.get_armor()
	var barrier_val: int = player.get_barrier()
	var armor_pct: float = armor_val / (100.0 + armor_val) * 100.0 if armor_val > 0 else 0.0
	var barrier_pct: float = barrier_val / (100.0 + barrier_val) * 100.0 if barrier_val > 0 else 0.0

	_add_stat_row("Armor", "%d  (%.0f%% phys reduction)" % [armor_val, armor_pct], ThemeManager.PALETTE.armor)
	_add_stat_row("Barrier", "%d  (%.0f%% magic reduction)" % [barrier_val, barrier_pct], ThemeManager.PALETTE.barrier)


func _build_gold_section():
	"""Gold display with icon placeholder"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Gold icon — swap for TextureRect when asset exists:
	# var icon = TextureRect.new()
	# icon.texture = preload("res://assets/ui/icons/gold.png")
	# icon.custom_minimum_size = Vector2(32, 32)
	# icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_label = Label.new()
	icon_label.text = "🪙"
	icon_label.theme_type_variation = "large"
	hbox.add_child(icon_label)

	var gold_label = Label.new()
	gold_label.text = str(player.gold)
	gold_label.theme_type_variation = "large"
	gold_label.add_theme_color_override("font_color", ThemeManager.PALETTE.warning)
	hbox.add_child(gold_label)

	stats_container.add_child(hbox)

# ============================================================================
# UI ELEMENT BUILDERS
# ============================================================================

func _add_section_header(title: String):
	"""Section header — uses 'header' theme type variation"""
	var label = Label.new()
	label.text = title
	label.theme_type_variation = "header"
	label.add_theme_color_override("font_color", ThemeManager.PALETTE.warning)
	stats_container.add_child(label)


func _add_stat_row(stat_name: String, value: String, color: Color = Color.WHITE):
	"""Stat row — inherits theme default font size, no overrides"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	if stat_name != "":
		var name_label = Label.new()
		name_label.text = stat_name
		name_label.custom_minimum_size = Vector2(STAT_LABEL_MIN_WIDTH, 0)
		name_label.add_theme_color_override("font_color", ThemeManager.PALETTE.text_secondary)
		hbox.add_child(name_label)

	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", color)
	hbox.add_child(value_label)

	stats_container.add_child(hbox)


func _add_resource_bar(bar_label: String, current: int, maximum: int,
		fill_color: Color, low_color = null):
	"""Labeled ProgressBar with current/max text overlay"""
	var bar_holder = Control.new()
	bar_holder.custom_minimum_size = Vector2(0, BAR_HEIGHT)

	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maximum if maximum > 0 else 1
	bar.value = current
	bar.show_percentage = false
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)

	var fill_style = StyleBoxFlat.new()
	var pct: float = float(current) / float(maximum) if maximum > 0 else 0.0
	if low_color and pct < 0.25:
		fill_style.bg_color = low_color
	else:
		fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(BAR_CORNER_RADIUS)
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = ThemeManager.PALETTE.bg_dark
	bg_style.set_corner_radius_all(BAR_CORNER_RADIUS)
	bg_style.border_color = ThemeManager.PALETTE.border_subtle
	bg_style.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg_style)

	bar_holder.add_child(bar)

	# Text overlay centered on bar
	var overlay = Label.new()
	overlay.text = "%s: %d / %d" % [bar_label, current, maximum]
	overlay.theme_type_variation = "small"
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_color_override("font_color", ThemeManager.PALETTE.text_primary)
	overlay.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	overlay.add_theme_constant_override("shadow_offset_x", 1)
	overlay.add_theme_constant_override("shadow_offset_y", 1)
	bar_holder.add_child(overlay)

	stats_container.add_child(bar_holder)


func _add_separator():
	"""Visible line separator between sections"""
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 12)
	var line_style = StyleBoxLine.new()
	line_style.color = ThemeManager.PALETTE.border_subtle
	line_style.thickness = 1
	sep.add_theme_stylebox_override("separator", line_style)
	stats_container.add_child(sep)

# ============================================================================
# SIGNAL HANDLERS (from player — bubbled up)
# ============================================================================

func _on_player_hp_changed(_current: int, _maximum: int):
	refresh()
	data_changed.emit()

func _on_player_stat_changed(_stat_name: String, _old_value, _new_value):
	refresh()
	data_changed.emit()

func _on_player_equipment_changed(_slot: String, _item):
	refresh()
	data_changed.emit()
