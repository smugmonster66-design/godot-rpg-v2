# character_tab.gd - Character stats display (v3 — scene-based)
# Sections: Header, Vitals, Primary Stats, Defense, Elemental Stats,
#           Alignment, Companions, Currencies.
extends Control

# ============================================================================
# SIGNALS
# ============================================================================
signal refresh_requested()
signal data_changed()

# ============================================================================
# CONSTANTS
# ============================================================================
const BAR_HEIGHT := 40
const BAR_CORNER_RADIUS := 6

const CurrencyRowScene = preload("res://scenes/ui/components/character/currency_row.tscn")

## Maps ui_role → [Affix.Category, display_element_key] for elemental damage rows
## Category values are ints since GDScript enums can't be used in const dicts directly.
## We resolve them once in _ready via _build_elemental_maps().
var ELEM_DMG_MAP := {}
var ELEM_RESIST_MAP := {}

func _build_elemental_maps():
	ELEM_DMG_MAP = {
		"elem_slashing_dmg": Affix.Category.SLASHING_DAMAGE_BONUS,
		"elem_blunt_dmg": Affix.Category.BLUNT_DAMAGE_BONUS,
		"elem_piercing_dmg": Affix.Category.PIERCING_DAMAGE_BONUS,
		"elem_fire_dmg": Affix.Category.FIRE_DAMAGE_BONUS,
		"elem_ice_dmg": Affix.Category.ICE_DAMAGE_BONUS,
		"elem_shock_dmg": Affix.Category.SHOCK_DAMAGE_BONUS,
		"elem_poison_dmg": Affix.Category.POISON_DAMAGE_BONUS,
		"elem_shadow_dmg": Affix.Category.SHADOW_DAMAGE_BONUS,
	}
	ELEM_RESIST_MAP = {
		"elem_fire_resist": Affix.Category.FIRE_RESIST_BONUS,
		"elem_ice_resist": Affix.Category.ICE_RESIST_BONUS,
		"elem_shock_resist": Affix.Category.SHOCK_RESIST_BONUS,
		"elem_poison_resist": Affix.Category.POISON_RESIST_BONUS,
		"elem_shadow_resist": Affix.Category.SHADOW_RESIST_BONUS,
	}

## Display names for elemental rows
const ELEM_DISPLAY_NAMES := {
	"elem_slashing_dmg": "Slashing",
	"elem_blunt_dmg": "Blunt",
	"elem_piercing_dmg": "Piercing",
	"elem_fire_dmg": "Fire",
	"elem_ice_dmg": "Ice",
	"elem_shock_dmg": "Shock",
	"elem_poison_dmg": "Poison",
	"elem_shadow_dmg": "Shadow",
	"elem_fire_resist": "Fire",
	"elem_ice_resist": "Ice",
	"elem_shock_resist": "Shock",
	"elem_poison_resist": "Poison",
	"elem_shadow_resist": "Shadow",
}

## Element → palette color key
const ELEM_COLORS := {
	"slashing": "slashing", "blunt": "blunt", "piercing": "piercing",
	"fire": "fire", "ice": "ice", "shock": "shock",
	"poison": "poison", "shadow": "shadow",
}

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var smithing_config: Resource = null

# UI references (discovered via groups + metadata)
var class_label: Label
var level_label: Label
var exp_label: Label
var exp_bar  # resource_bar component
var hp_bar   # resource_bar component
var mana_bar # resource_bar component

# Primary stat rows
var stat_rows := {}  # "stat_strength" → stat_row node, etc.

# Defense rows
var armor_row = null
var barrier_row = null

# Elemental section
var elemental_section = null  # collapsible_section
var elemental_rows := {}  # ui_role → stat_row node

# Alignment
var virtue_axis = null
var order_axis = null

# Currencies
var gold_amount_label: Label = null
var components_container: VBoxContainer = null
var _component_row_cache := {}  # component_id → currency_row node

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")
	_build_elemental_maps()
	_load_smithing_config()
	_discover_ui_elements()

func _load_smithing_config():
	if ResourceLoader.exists("res://resources/crafting/smithing_config.tres"):
		smithing_config = load("res://resources/crafting/smithing_config.tres")

func _discover_ui_elements():
	await get_tree().process_frame

	var ui_nodes = find_children("*", "", true, false)
	for node in ui_nodes:
		if not node.is_in_group("character_tab_ui"):
			continue
		var role = node.get_meta("ui_role", "")
		match role:
			"class_label": class_label = node
			"level_label": level_label = node
			"exp_label": exp_label = node
			"exp_bar": exp_bar = node
			"hp_bar": hp_bar = node
			"mana_bar": mana_bar = node
			"stat_strength", "stat_agility", "stat_intellect", "stat_luck":
				stat_rows[role] = node
			"stat_armor": armor_row = node
			"stat_barrier": barrier_row = node
			"elemental_section": elemental_section = node
			"alignment_virtue": virtue_axis = node
			"alignment_order": order_axis = node
			"gold_amount": gold_amount_label = node
			"components_container": components_container = node

		# Elemental stat rows
		if role in ELEM_DMG_MAP or role in ELEM_RESIST_MAP:
			elemental_rows[role] = node

	if elemental_section:
		elemental_section.set_title("Elemental Stats")

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	player = p_player

	if player:
		if player.has_signal("hp_changed") and not player.hp_changed.is_connected(_on_player_hp_changed):
			player.hp_changed.connect(_on_player_hp_changed)
		if player.has_signal("stat_changed") and not player.stat_changed.is_connected(_on_player_stat_changed):
			player.stat_changed.connect(_on_player_stat_changed)
		if player.has_signal("equipment_changed") and not player.equipment_changed.is_connected(_on_player_equipment_changed):
			player.equipment_changed.connect(_on_player_equipment_changed)

	# Alignment counters: listen on GameState's relay signal, which survives
	# the Counters object being replaced on new game / load.
	if not GameState.counter_changed.is_connected(_on_counter_changed):
		GameState.counter_changed.connect(_on_counter_changed)

	refresh()

func refresh():
	if not player:
		return
	_update_header()
	_update_vitals()
	_update_primary_stats()
	_update_defense()
	_update_elemental_stats()
	_update_alignment()
	_update_currencies()

func on_external_data_change():
	refresh()

# ============================================================================
# HEADER — Class / Level / XP
# ============================================================================

func _update_header():
	if not player.active_class:
		if class_label:
			class_label.text = "No Class Selected"
		return

	var active_class = player.active_class

	if class_label:
		class_label.text = active_class.player_class_name

	if level_label:
		level_label.text = "Level %d" % active_class.level

	if exp_bar:
		var exp_progress = active_class.get_exp_progress()
		var current_exp = active_class.experience
		var next_level_exp = active_class.get_exp_for_next_level()
		exp_bar.set_values("Exp", current_exp, next_level_exp,
			ThemeManager.PALETTE.experience, null)

	if exp_label:
		exp_label.text = "Exp:"

# ============================================================================
# VITALS — HP + Mana
# ============================================================================

func _update_vitals():
	if hp_bar:
		hp_bar.set_values("HP", player.current_hp, player.max_hp,
			ThemeManager.PALETTE.health, ThemeManager.PALETTE.health_low)

	if mana_bar:
		var has_mana = player.active_class and player.active_class.mana_pool_template != null
		mana_bar.visible = has_mana
		if has_mana:
			mana_bar.set_values("Mana", player.current_mana, player.max_mana,
				ThemeManager.PALETTE.mana, null)

# ============================================================================
# PRIMARY STATS — STR / AGI / INT / LCK
# ============================================================================

func _update_primary_stats():
	var stat_configs = [
		["stat_strength", "Strength", "strength", ThemeManager.PALETTE.strength],
		["stat_agility", "Agility", "agility", ThemeManager.PALETTE.agility],
		["stat_intellect", "Intellect", "intellect", ThemeManager.PALETTE.intellect],
		["stat_luck", "Luck", "luck", ThemeManager.PALETTE.luck],
	]

	for config in stat_configs:
		var role: String = config[0]
		var display_name: String = config[1]
		var stat_name: String = config[2]
		var color: Color = config[3]

		var row = stat_rows.get(role)
		if not row:
			continue

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

		row.set_stat(display_name, value_text, color)

# ============================================================================
# DEFENSE — Armor + Barrier
# ============================================================================

func _update_defense():
	if armor_row:
		var armor_val: int = player.get_armor()
		var armor_pct: float = armor_val / (100.0 + armor_val) * 100.0 if armor_val > 0 else 0.0
		armor_row.set_stat("Armor", "%d  (%.0f%% phys reduction)" % [armor_val, armor_pct],
			ThemeManager.PALETTE.armor)

	if barrier_row:
		var barrier_val: int = player.get_barrier()
		var barrier_pct: float = barrier_val / (100.0 + barrier_val) * 100.0 if barrier_val > 0 else 0.0
		barrier_row.set_stat("Barrier", "%d  (%.0f%% magic reduction)" % [barrier_val, barrier_pct],
			ThemeManager.PALETTE.barrier)

# ============================================================================
# ELEMENTAL STATS — Damage bonuses + Resistances (collapsible)
# ============================================================================

func _update_elemental_stats():
	if not player.affix_manager:
		return

	var any_visible := false

	# Damage bonuses
	for role in ELEM_DMG_MAP:
		var row = elemental_rows.get(role)
		if not row:
			continue
		var category: Affix.Category = ELEM_DMG_MAP[role]
		var total := _sum_affix_pool(category)
		row.visible = total != 0
		if total != 0:
			any_visible = true
			var elem_key = ELEM_DISPLAY_NAMES[role].to_lower()
			var color = ThemeManager.PALETTE.get(elem_key, ThemeManager.PALETTE.text_primary)
			row.set_stat(ELEM_DISPLAY_NAMES[role], "+%d" % total if total > 0 else str(total), color)

	# Resistances
	for role in ELEM_RESIST_MAP:
		var row = elemental_rows.get(role)
		if not row:
			continue
		var category: Affix.Category = ELEM_RESIST_MAP[role]
		var total := _sum_affix_pool(category)
		row.visible = total != 0
		if total != 0:
			any_visible = true
			var elem_key = ELEM_DISPLAY_NAMES[role].to_lower()
			var color = ThemeManager.PALETTE.get(elem_key, ThemeManager.PALETTE.text_primary)
			row.set_stat(ELEM_DISPLAY_NAMES[role], "+%d" % total if total > 0 else str(total), color)

	# Hide entire section if nothing to show
	if elemental_section:
		elemental_section.visible = any_visible

func _sum_affix_pool(category: Affix.Category) -> int:
	var total := 0.0
	for affix in player.affix_manager.get_pool(category):
		total += affix.apply_effect()
	return int(total)

# ============================================================================
# ALIGNMENT — Virtue + Order axes
# ============================================================================

func _update_alignment():
	if virtue_axis:
		var virtue_val: int = GameState.counters.get_counter(&"virtue")
		virtue_axis.set_axis("Evil", "Good", virtue_val)

	if order_axis:
		var order_val: int = GameState.counters.get_counter(&"order")
		order_axis.set_axis("Chaotic", "Orderly", order_val)

# ============================================================================
# CURRENCIES — Gold + Crafting Components
# ============================================================================

func _update_currencies():
	# Gold
	if gold_amount_label:
		gold_amount_label.text = str(player.gold)
		gold_amount_label.add_theme_color_override("font_color", ThemeManager.PALETTE.warning)

	# Crafting components
	if not components_container:
		return

	var current_components: Dictionary = player.crafting_components if player.crafting_components else {}

	# Remove rows for components that no longer exist
	for comp_id in _component_row_cache.keys():
		if not current_components.has(comp_id):
			_component_row_cache[comp_id].queue_free()
			_component_row_cache.erase(comp_id)

	# Add or update rows
	for comp_id in current_components:
		var amount: int = current_components[comp_id]
		if amount <= 0:
			if _component_row_cache.has(comp_id):
				_component_row_cache[comp_id].visible = false
			continue

		var row = _component_row_cache.get(comp_id)
		if not row:
			row = CurrencyRowScene.instantiate()
			components_container.add_child(row)
			_component_row_cache[comp_id] = row
			# Wait a frame for the row's _ready to fire
			await get_tree().process_frame

		var comp_def = _find_component_definition(comp_id)
		var display_name = comp_def.display_name if comp_def else str(comp_id)
		var icon = comp_def.icon if comp_def else null
		var fallback = comp_def.abbreviation if comp_def else str(comp_id).left(3)
		var rarity_color = _get_rarity_color(comp_def.rarity_tier if comp_def else 0)

		row.visible = true
		row.set_currency(icon, display_name, amount, rarity_color, fallback)

func _find_component_definition(comp_id: StringName):
	if not smithing_config:
		return null
	for comp_def in smithing_config.components:
		if comp_def.component_id == comp_id:
			return comp_def
	return null

func _get_rarity_color(tier: int) -> Color:
	match tier:
		0: return ThemeManager.PALETTE.rarity_common
		1: return ThemeManager.PALETTE.rarity_uncommon
		2: return ThemeManager.PALETTE.rarity_rare
		3: return ThemeManager.PALETTE.rarity_epic
		4: return ThemeManager.PALETTE.rarity_legendary
		_: return ThemeManager.PALETTE.text_primary

# ============================================================================
# SIGNAL HANDLERS
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

func _on_counter_changed(counter_name: StringName, _old_value: int, _new_value: int):
	if counter_name == &"virtue" or counter_name == &"order":
		_update_alignment()
