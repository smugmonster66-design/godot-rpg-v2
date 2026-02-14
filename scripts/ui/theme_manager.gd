# theme_manager.gd
# AutoLoad singleton — unified visual theming for Roll The Bones
#
# Sets the project-level theme so every Control inherits styles automatically.
# Provides a centralized palette, element/rarity/game-state colors, font sizes,
# and custom theme type variations for game-specific widgets.
#
# Usage:
#   - Autoload as "ThemeManager"
#   - Colors:  ThemeManager.PALETTE.fire, ThemeManager.get_element_color(...)
#   - Fonts:   ThemeManager.get_font_size("title")
#   - Rarity:  ThemeManager.get_rarity_color("Epic")
#   - Theme:   Automatically applied to all UI via ThemeDB
#   - Custom types: Set theme_type_variation on nodes (e.g. "ActionFieldPanel")
#
# Nodes that need styles beyond what the theme provides can still call
# add_theme_*_override() — those take precedence over the inherited theme.
extends Node

# ============================================================================
# THEME RESOURCE
# ============================================================================
var theme: Theme

# Optional: load a custom font file. Set this path to your .ttf/.otf or leave
# empty to use Godot's built-in default.
const CUSTOM_FONT_PATH := ""  # e.g. "res://assets/fonts/your_font.ttf"
const CUSTOM_FONT_BOLD_PATH := ""  # e.g. "res://assets/fonts/your_font_bold.ttf"

# Cached font resources (null = engine default)
var font_regular: Font = null
var font_bold: Font = null

# ============================================================================
# CENTRALIZED PALETTE
# ============================================================================
# Every color in the game lives here. Nothing else should hardcode Color().
# Reference as: ThemeManager.PALETTE.bg_dark, ThemeManager.PALETTE.fire, etc.

const PALETTE = {
	# ── Base UI ──────────────────────────────────────────────────────────
	"bg_darkest":       Color(0.04, 0.03, 0.06),       # Deepest background
	"bg_dark":          Color(0.06, 0.05, 0.08),       # Primary background
	"bg_panel":         Color(0.10, 0.10, 0.15, 0.90), # Standard panel fill
	"bg_elevated":      Color(0.14, 0.12, 0.20, 0.95), # Raised panels / modals
	"bg_input":         Color(0.08, 0.08, 0.12, 0.95), # Input field backgrounds
	"bg_hover":         Color(0.18, 0.16, 0.26, 0.95), # Hovered interactive elements

	"border_subtle":    Color(0.25, 0.25, 0.35),       # Quiet panel borders
	"border_default":   Color(0.30, 0.30, 0.40),       # Standard borders
	"border_accent":    Color(0.40, 0.35, 0.60),       # Highlighted borders
	"border_focus":     Color(0.50, 0.45, 0.75),       # Focused element borders

	# ── Text ─────────────────────────────────────────────────────────────
	"text_primary":     Color(1.0, 1.0, 1.0),          # Headers / important
	"text_secondary":   Color(0.78, 0.78, 0.82),       # Body text
	"text_muted":       Color(0.50, 0.50, 0.55),       # Disabled / hint text
	"text_shadow":      Color(0.0, 0.0, 0.0, 0.50),    # Drop shadow on labels

	# ── Semantic ─────────────────────────────────────────────────────────
	"primary":          Color(0.30, 0.50, 0.80),       # Buttons, links
	"primary_hover":    Color(0.40, 0.60, 0.90),
	"primary_pressed":  Color(0.22, 0.40, 0.70),
	"secondary":        Color(0.45, 0.45, 0.50),       # Secondary actions
	"success":          Color(0.30, 0.75, 0.35),       # Positive feedback
	"danger":           Color(0.85, 0.25, 0.25),       # Damage, delete, death
	"warning":          Color(0.90, 0.80, 0.20),       # Caution / resource low
	"info":             Color(0.30, 0.75, 0.80),       # Informational

	# ── Game States ──────────────────────────────────────────────────────
	"locked":           Color(0.40, 0.40, 0.40),       # Locked skills / items
	"available":        Color(0.30, 0.50, 0.80),       # Can interact / purchase
	"maxed":            Color(1.0, 0.85, 0.20),        # Fully upgraded / gold

	# ── Elements (UI tint colors — shaders handle dice visuals separately)
	"fire":             Color(1.0, 0.40, 0.15),
	"ice":              Color(0.35, 0.70, 1.0),
	"shock":            Color(0.85, 0.65, 1.0),
	"poison":           Color(0.40, 0.90, 0.30),
	"shadow":           Color(0.55, 0.25, 0.75),
	"slashing":         Color(0.80, 0.80, 0.80),
	"blunt":            Color(0.65, 0.55, 0.40),
	"piercing":         Color(0.90, 0.90, 0.70),

	# ── Rarity ───────────────────────────────────────────────────────────
	"rarity_common":    Color(0.70, 0.70, 0.70),       # Gray
	"rarity_uncommon":  Color(0.20, 0.80, 0.20),       # Green
	"rarity_rare":      Color(0.20, 0.50, 1.0),        # Blue
	"rarity_epic":      Color(0.70, 0.20, 0.90),       # Purple
	"rarity_legendary": Color(1.0, 0.60, 0.0),         # Orange-Gold

	# ── Combat Specific ──────────────────────────────────────────────────
	"health":           Color(0.20, 0.75, 0.25),       # HP bars
	"health_low":       Color(0.85, 0.25, 0.25),       # HP critical
	"mana":             Color(0.25, 0.45, 0.90),       # Mana bars
	"experience":       Color(0.70, 0.55, 0.85),       # XP bars
	"armor":            Color(0.60, 0.60, 0.65),       # Armor indicator
	"barrier":          Color(0.40, 0.70, 0.95),       # Magic barrier

	# ── Cate (the divine cat companion) ──────────────────────────────────
	"cate_happy":       Color(1.0, 0.85, 0.40),
	"cate_neutral":     Color(0.70, 0.70, 0.75),
	"cate_annoyed":     Color(0.80, 0.50, 0.30),
}


# ============================================================================
# FONT SIZES
# ============================================================================
const FONT_SIZES = {
	"tiny":     10,
	"small":    12,
	"caption":  13,
	"normal":   16,
	"large":    20,
	"title":    24,
	"header":   28,
	"display":  36,
}


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("🎨 ThemeManager initializing...")
	_load_fonts()
	_build_theme()
	_apply_to_project()
	print("🎨 ThemeManager ready — project theme applied")


func _load_fonts():
	"""Load custom fonts if paths are configured."""
	if CUSTOM_FONT_PATH != "" and ResourceLoader.exists(CUSTOM_FONT_PATH):
		font_regular = load(CUSTOM_FONT_PATH) as Font
		print("  🔤 Loaded custom font: %s" % CUSTOM_FONT_PATH)

	if CUSTOM_FONT_BOLD_PATH != "" and ResourceLoader.exists(CUSTOM_FONT_BOLD_PATH):
		font_bold = load(CUSTOM_FONT_BOLD_PATH) as Font
		print("  🔤 Loaded custom bold font: %s" % CUSTOM_FONT_BOLD_PATH)


func _build_theme():
	"""Assemble the complete Theme resource."""
	theme = Theme.new()

	_setup_fonts()
	_setup_default_controls()
	_setup_buttons()
	_setup_panels()
	_setup_labels()
	_setup_progress_bars()
	_setup_scroll_containers()
	_setup_tabs()
	_setup_tooltips()

	# Game-specific widget type variations
	_setup_action_field_type()
	_setup_skill_button_type()
	_setup_combat_panel_types()
	_setup_menu_types()

	print("  🎨 Theme built (%d type variations)" % _count_type_variations())


func _apply_to_project():
	"""Set as the project-wide default theme so all Controls inherit it."""
	# Merge into ThemeDB's project theme — this cascades to every Control
	# that doesn't have an explicit theme override.
	ThemeDB.get_project_theme().merge_with(theme)
	print("  🎨 Merged into project theme")


# ============================================================================
# FONTS
# ============================================================================

func _setup_fonts():
	"""Configure font and size defaults."""
	theme.default_font_size = FONT_SIZES.normal

	if font_regular:
		theme.default_font = font_regular

	# Register named sizes on Label for convenience:
	# Usage: label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("title"))
	for size_name in FONT_SIZES:
		theme.set_font_size("font_size", size_name, FONT_SIZES[size_name])


# ============================================================================
# DEFAULT CONTROL STYLES (inherited by all controls unless overridden)
# ============================================================================

func _setup_default_controls():
	"""Baseline styles that give every control the game's dark theme feel."""
	# LineEdit
	var line_edit_normal = _flat_box(PALETTE.bg_input, PALETTE.border_default, 4, 1)
	line_edit_normal.content_margin_left = 8
	line_edit_normal.content_margin_right = 8
	line_edit_normal.content_margin_top = 4
	line_edit_normal.content_margin_bottom = 4
	theme.set_stylebox("normal", "LineEdit", line_edit_normal)

	var line_edit_focus = _flat_box(PALETTE.bg_input, PALETTE.border_focus, 4, 2)
	line_edit_focus.content_margin_left = 8
	line_edit_focus.content_margin_right = 8
	line_edit_focus.content_margin_top = 4
	line_edit_focus.content_margin_bottom = 4
	theme.set_stylebox("focus", "LineEdit", line_edit_focus)

	theme.set_color("font_color", "LineEdit", PALETTE.text_primary)
	theme.set_color("font_placeholder_color", "LineEdit", PALETTE.text_muted)
	theme.set_color("caret_color", "LineEdit", PALETTE.primary)


# ============================================================================
# BUTTONS
# ============================================================================

func _setup_buttons():
	"""Standard button appearance — all Button nodes inherit this."""
	# Normal
	var btn_normal = _flat_box(PALETTE.bg_panel, PALETTE.border_default, 6, 1)
	btn_normal.content_margin_left = 16
	btn_normal.content_margin_right = 16
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", btn_normal)

	# Hover
	var btn_hover = _flat_box(PALETTE.bg_hover, PALETTE.border_accent, 6, 1)
	btn_hover.content_margin_left = 16
	btn_hover.content_margin_right = 16
	btn_hover.content_margin_top = 8
	btn_hover.content_margin_bottom = 8
	theme.set_stylebox("hover", "Button", btn_hover)

	# Pressed
	var btn_pressed = _flat_box(PALETTE.primary_pressed, PALETTE.border_focus, 6, 2)
	btn_pressed.content_margin_left = 16
	btn_pressed.content_margin_right = 16
	btn_pressed.content_margin_top = 8
	btn_pressed.content_margin_bottom = 8
	theme.set_stylebox("pressed", "Button", btn_pressed)

	# Disabled
	var btn_disabled = _flat_box(Color(0.12, 0.12, 0.14, 0.7), Color(0.25, 0.25, 0.25), 6, 1)
	btn_disabled.content_margin_left = 16
	btn_disabled.content_margin_right = 16
	btn_disabled.content_margin_top = 8
	btn_disabled.content_margin_bottom = 8
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# Focus (keyboard/gamepad navigation)
	var btn_focus = _flat_box(PALETTE.bg_panel, PALETTE.border_focus, 6, 2)
	btn_focus.content_margin_left = 16
	btn_focus.content_margin_right = 16
	btn_focus.content_margin_top = 8
	btn_focus.content_margin_bottom = 8
	theme.set_stylebox("focus", "Button", btn_focus)

	# Colors
	theme.set_color("font_color", "Button", PALETTE.text_primary)
	theme.set_color("font_hover_color", "Button", PALETTE.primary_hover)
	theme.set_color("font_pressed_color", "Button", Color(1.0, 1.0, 0.85))
	theme.set_color("font_disabled_color", "Button", PALETTE.text_muted)
	theme.set_color("font_focus_color", "Button", PALETTE.text_primary)

	theme.set_font_size("font_size", "Button", FONT_SIZES.normal)


# ============================================================================
# PANELS
# ============================================================================

func _setup_panels():
	"""PanelContainer default — dark translucent with subtle border."""
	var panel = _flat_box(PALETTE.bg_panel, PALETTE.border_subtle, 8, 1)
	panel.content_margin_left = 8
	panel.content_margin_right = 8
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	theme.set_stylebox("panel", "PanelContainer", panel)

	# Also style raw Panel nodes
	theme.set_stylebox("panel", "Panel", panel.duplicate())


# ============================================================================
# LABELS
# ============================================================================

func _setup_labels():
	"""Label defaults — white text with soft drop shadow."""
	theme.set_color("font_color", "Label", PALETTE.text_primary)
	theme.set_color("font_shadow_color", "Label", PALETTE.text_shadow)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_font_size("font_size", "Label", FONT_SIZES.normal)


# ============================================================================
# PROGRESS BARS (HP / Mana / XP)
# ============================================================================

func _setup_progress_bars():
	"""ProgressBar default styling — for stat_display.gd and similar."""
	var bg = _flat_box(PALETTE.bg_darkest, PALETTE.border_subtle, 4, 1)
	theme.set_stylebox("background", "ProgressBar", bg)

	var fill = _flat_box(PALETTE.health, Color(0.0, 0.0, 0.0, 0.0), 4, 0)
	theme.set_stylebox("fill", "ProgressBar", fill)

	theme.set_font_size("font_size", "ProgressBar", FONT_SIZES.small)
	theme.set_color("font_color", "ProgressBar", PALETTE.text_primary)


# ============================================================================
# SCROLL CONTAINERS
# ============================================================================

func _setup_scroll_containers():
	"""Thin, subtle scrollbar that doesn't fight the dark theme."""
	var grabber = _flat_box(Color(0.35, 0.35, 0.45, 0.6), Color(0.0, 0.0, 0.0, 0.0), 4, 0)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", _flat_box(
		Color(0.45, 0.45, 0.55, 0.8), Color(0.0, 0.0, 0.0, 0.0), 4, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _flat_box(
		Color(0.55, 0.55, 0.65, 0.9), Color(0.0, 0.0, 0.0, 0.0), 4, 0))

	# Track
	var scroll_bg = _flat_box(Color(0.08, 0.08, 0.10, 0.4), Color(0.0, 0.0, 0.0, 0.0), 4, 0)
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)


# ============================================================================
# TAB CONTAINERS
# ============================================================================

func _setup_tabs():
	"""TabContainer / TabBar for menus like PlayerMenu tabs."""
	# Active tab
	var tab_selected = _flat_box(PALETTE.bg_elevated, PALETTE.border_accent, 6, 1)
	tab_selected.border_width_bottom = 0
	tab_selected.content_margin_left = 12
	tab_selected.content_margin_right = 12
	tab_selected.content_margin_top = 6
	tab_selected.content_margin_bottom = 6
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)
	theme.set_stylebox("tab_selected", "TabBar", tab_selected.duplicate())

	# Unselected tab
	var tab_unselected = _flat_box(PALETTE.bg_dark, PALETTE.border_subtle, 6, 1)
	tab_unselected.border_width_bottom = 0
	tab_unselected.content_margin_left = 12
	tab_unselected.content_margin_right = 12
	tab_unselected.content_margin_top = 6
	tab_unselected.content_margin_bottom = 6
	theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected)
	theme.set_stylebox("tab_unselected", "TabBar", tab_unselected.duplicate())

	# Hovered tab
	var tab_hover = _flat_box(PALETTE.bg_hover, PALETTE.border_default, 6, 1)
	tab_hover.border_width_bottom = 0
	tab_hover.content_margin_left = 12
	tab_hover.content_margin_right = 12
	tab_hover.content_margin_top = 6
	tab_hover.content_margin_bottom = 6
	theme.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	theme.set_stylebox("tab_hovered", "TabBar", tab_hover.duplicate())

	# Panel below tabs
	var tab_panel = _flat_box(PALETTE.bg_elevated, PALETTE.border_accent, 0, 1)
	tab_panel.corner_radius_top_left = 0
	tab_panel.content_margin_left = 8
	tab_panel.content_margin_right = 8
	tab_panel.content_margin_top = 8
	tab_panel.content_margin_bottom = 8
	theme.set_stylebox("panel", "TabContainer", tab_panel)

	# Colors
	theme.set_color("font_selected_color", "TabContainer", PALETTE.text_primary)
	theme.set_color("font_unselected_color", "TabContainer", PALETTE.text_muted)
	theme.set_color("font_hovered_color", "TabContainer", PALETTE.primary_hover)
	theme.set_color("font_selected_color", "TabBar", PALETTE.text_primary)
	theme.set_color("font_unselected_color", "TabBar", PALETTE.text_muted)
	theme.set_color("font_hovered_color", "TabBar", PALETTE.primary_hover)


# ============================================================================
# TOOLTIPS
# ============================================================================

func _setup_tooltips():
	"""Dark tooltip panel for item/skill hover info."""
	var tip_panel = _flat_box(
		Color(0.08, 0.07, 0.12, 0.96),
		PALETTE.border_accent, 6, 2)
	tip_panel.content_margin_left = 12
	tip_panel.content_margin_right = 12
	tip_panel.content_margin_top = 8
	tip_panel.content_margin_bottom = 8
	# Subtle shadow via expand margins
	tip_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	tip_panel.shadow_size = 4
	theme.set_stylebox("panel", "TooltipPanel", tip_panel)
	theme.set_color("font_color", "TooltipLabel", PALETTE.text_secondary)
	theme.set_font_size("font_size", "TooltipLabel", FONT_SIZES.caption)


# ============================================================================
#  CUSTOM TYPE: ActionFieldPanel
# ============================================================================
# Usage: On your ActionField's root PanelContainer, set
#   theme_type_variation = "ActionFieldPanel"

func _setup_action_field_type():
	"""Styled panel for combat action fields where dice are placed."""
	# Default state
	var af_normal = _flat_box(
		Color(0.12, 0.08, 0.18, 0.92),
		PALETTE.border_default, 6, 1)
	af_normal.content_margin_left = 6
	af_normal.content_margin_right = 6
	af_normal.content_margin_top = 4
	af_normal.content_margin_bottom = 4
	theme.set_stylebox("panel", "ActionFieldPanel", af_normal)

	# Colors for action name labels
	theme.set_color("font_color", "ActionFieldPanel", PALETTE.text_primary)
	theme.set_font_size("font_size", "ActionFieldPanel", FONT_SIZES.caption)


# ============================================================================
#  CUSTOM TYPE: SkillButton
# ============================================================================
# Usage: On your SkillButton's root PanelContainer, set
#   theme_type_variation = "SkillButton"
# Then swap stylebox in code: add_theme_stylebox_override("panel", ThemeManager.get_skill_state_style(state))

func _setup_skill_button_type():
	"""Three-state skill button for the skill tree."""
	# Locked
	var locked = _flat_box(
		Color(0.10, 0.10, 0.12, 0.80),
		PALETTE.locked, 6, 1)
	locked.content_margin_left = 4
	locked.content_margin_right = 4
	locked.content_margin_top = 4
	locked.content_margin_bottom = 4
	theme.set_stylebox("locked", "SkillButton", locked)

	# Available (can level up)
	var available = _flat_box(
		Color(0.10, 0.14, 0.22, 0.92),
		PALETTE.available, 6, 2)
	available.content_margin_left = 4
	available.content_margin_right = 4
	available.content_margin_top = 4
	available.content_margin_bottom = 4
	theme.set_stylebox("available", "SkillButton", available)

	# Maxed (fully ranked)
	var maxed = _flat_box(
		Color(0.18, 0.16, 0.08, 0.92),
		PALETTE.maxed, 6, 2)
	maxed.content_margin_left = 4
	maxed.content_margin_right = 4
	maxed.content_margin_top = 4
	maxed.content_margin_bottom = 4
	theme.set_stylebox("maxed", "SkillButton", maxed)

	# Default
	theme.set_stylebox("panel", "SkillButton", locked.duplicate())

	theme.set_color("font_color", "SkillButton", PALETTE.text_primary)
	theme.set_font_size("font_size", "SkillButton", FONT_SIZES.small)


# ============================================================================
#  CUSTOM TYPE: CombatPanel (Enemy panel, player health area, etc.)
# ============================================================================

func _setup_combat_panel_types():
	"""Specialized panels for the combat screen."""
	# EnemyPanel — slightly different tint
	var enemy_panel = _flat_box(
		Color(0.14, 0.08, 0.10, 0.90),
		Color(0.45, 0.25, 0.25), 8, 1)
	enemy_panel.content_margin_left = 8
	enemy_panel.content_margin_right = 8
	enemy_panel.content_margin_top = 6
	enemy_panel.content_margin_bottom = 6
	theme.set_stylebox("panel", "EnemyPanel", enemy_panel)

	# DicePoolPanel — where rolled dice sit
	var dice_panel = _flat_box(
		Color(0.08, 0.10, 0.16, 0.85),
		PALETTE.border_subtle, 8, 1)
	dice_panel.content_margin_left = 6
	dice_panel.content_margin_right = 6
	dice_panel.content_margin_top = 6
	dice_panel.content_margin_bottom = 6
	theme.set_stylebox("panel", "DicePoolPanel", dice_panel)

	# CombatButton — primary action buttons (Roll, End Turn)
	var combat_btn = _flat_box(PALETTE.primary, PALETTE.border_focus, 8, 2)
	combat_btn.content_margin_left = 20
	combat_btn.content_margin_right = 20
	combat_btn.content_margin_top = 10
	combat_btn.content_margin_bottom = 10
	theme.set_stylebox("normal", "CombatButton", combat_btn)

	var combat_btn_hover = _flat_box(PALETTE.primary_hover, PALETTE.border_focus, 8, 2)
	combat_btn_hover.content_margin_left = 20
	combat_btn_hover.content_margin_right = 20
	combat_btn_hover.content_margin_top = 10
	combat_btn_hover.content_margin_bottom = 10
	theme.set_stylebox("hover", "CombatButton", combat_btn_hover)

	var combat_btn_pressed = _flat_box(PALETTE.primary_pressed, Color(0.6, 0.55, 0.85), 8, 2)
	combat_btn_pressed.content_margin_left = 20
	combat_btn_pressed.content_margin_right = 20
	combat_btn_pressed.content_margin_top = 10
	combat_btn_pressed.content_margin_bottom = 10
	theme.set_stylebox("pressed", "CombatButton", combat_btn_pressed)

	theme.set_color("font_color", "CombatButton", PALETTE.text_primary)
	theme.set_font_size("font_size", "CombatButton", FONT_SIZES.large)


# ============================================================================
#  CUSTOM TYPE: MenuPanel, MenuHeader
# ============================================================================

func _setup_menu_types():
	"""PlayerMenu, inventory, and settings panels."""
	# MenuPanel — the large overlay menus
	var menu_bg = _flat_box(
		Color(0.07, 0.06, 0.10, 0.97),
		PALETTE.border_accent, 10, 2)
	menu_bg.content_margin_left = 12
	menu_bg.content_margin_right = 12
	menu_bg.content_margin_top = 12
	menu_bg.content_margin_bottom = 12
	theme.set_stylebox("panel", "MenuPanel", menu_bg)

	# MenuHeader — title bar area within menus
	var header = _flat_box(
		Color(0.12, 0.10, 0.18, 0.95),
		Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	header.border_width_bottom = 2
	header.border_color = PALETTE.border_accent
	header.content_margin_left = 12
	header.content_margin_right = 12
	header.content_margin_top = 8
	header.content_margin_bottom = 8
	theme.set_stylebox("panel", "MenuHeader", header)

	theme.set_color("font_color", "MenuHeader", PALETTE.text_primary)
	theme.set_font_size("font_size", "MenuHeader", FONT_SIZES.title)

	# ItemSlotPanel — individual equipment/inventory slots
	var item_slot = _flat_box(
		PALETTE.bg_input, PALETTE.border_subtle, 4, 1)
	item_slot.content_margin_left = 4
	item_slot.content_margin_right = 4
	item_slot.content_margin_top = 4
	item_slot.content_margin_bottom = 4
	theme.set_stylebox("panel", "ItemSlotPanel", item_slot)

	# BottomUIPanel — the persistent bottom bar
	var bottom_bar = _flat_box(
		Color(0.06, 0.05, 0.09, 0.95),
		Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	bottom_bar.border_width_top = 2
	bottom_bar.border_color = PALETTE.border_accent
	bottom_bar.content_margin_left = 8
	bottom_bar.content_margin_right = 8
	bottom_bar.content_margin_top = 6
	bottom_bar.content_margin_bottom = 6
	theme.set_stylebox("panel", "BottomUIPanel", bottom_bar)


# ============================================================================
# PUBLIC API — COLOR LOOKUPS
# ============================================================================

func get_semantic_color(type: String) -> Color:
	"""Get a color by semantic meaning. Backward-compatible with old API."""
	if PALETTE.has(type):
		return PALETTE[type]
	# Legacy fallback names
	match type:
		"primary":   return PALETTE.primary
		"secondary": return PALETTE.secondary
		"success":   return PALETTE.success
		"danger":    return PALETTE.danger
		"warning":   return PALETTE.warning
		"info":      return PALETTE.info
		_:           return Color.WHITE


func get_element_color(element_string: String) -> Color:
	"""Get UI tint color for an element by lowercase name.
	For shader materials, use ElementVisualConfig via GameManager.ELEMENT_VISUALS instead."""
	var key = element_string.to_lower()
	if PALETTE.has(key):
		return PALETTE[key]
	return PALETTE.text_primary


func get_element_color_enum(element: int) -> Color:
	"""Get element color from DieResource.Element or ActionEffect.DamageType enum value."""
	# Maps to the same element names used in mana_pool.gd / affix_evaluator.gd
	match element:
		0: return PALETTE.slashing   # SLASHING
		1: return PALETTE.piercing   # PIERCING
		2: return PALETTE.blunt      # BLUNT
		3: return PALETTE.fire       # FIRE
		4: return PALETTE.ice        # ICE
		5: return PALETTE.shock      # SHOCK
		6: return PALETTE.poison     # POISON
		7: return PALETTE.shadow     # SHADOW
		_: return PALETTE.text_primary


func get_rarity_color(rarity_name: String) -> Color:
	"""Get color for a rarity tier by name string."""
	var key = "rarity_" + rarity_name.to_lower()
	if PALETTE.has(key):
		return PALETTE[key]
	return PALETTE.rarity_common


func get_rarity_color_enum(rarity: int) -> Color:
	"""Get rarity color from EquippableItem.Rarity enum value (0-4)."""
	match rarity:
		0: return PALETTE.rarity_common
		1: return PALETTE.rarity_uncommon
		2: return PALETTE.rarity_rare
		3: return PALETTE.rarity_epic
		4: return PALETTE.rarity_legendary
		_: return PALETTE.rarity_common


# ============================================================================
# PUBLIC API — FONT SIZES
# ============================================================================

func get_font_size(size_name: String) -> int:
	"""Get a named font size. Returns normal size if name not found."""
	return FONT_SIZES.get(size_name, FONT_SIZES.normal)


# ============================================================================
# PUBLIC API — SKILL BUTTON HELPERS
# ============================================================================

func get_skill_state_style(state: int) -> StyleBoxFlat:
	"""Return a duplicate StyleBoxFlat for a SkillButton state.
	Pass SkillButton.State.LOCKED / AVAILABLE / MAXED (0/1/2)."""
	match state:
		0: return theme.get_stylebox("locked", "SkillButton").duplicate()
		1: return theme.get_stylebox("available", "SkillButton").duplicate()
		2: return theme.get_stylebox("maxed", "SkillButton").duplicate()
		_: return theme.get_stylebox("locked", "SkillButton").duplicate()


# ============================================================================
# PUBLIC API — ELEMENT-TINTED STYLEBOXES
# ============================================================================

func get_element_panel(element_string: String, alpha: float = 0.15) -> StyleBoxFlat:
	"""Create a panel StyleBox with a subtle element color tint.
	Good for action fields, status effect panels, etc."""
	var elem_color = get_element_color(element_string)
	var tinted_bg = Color(
		PALETTE.bg_panel.r + elem_color.r * alpha,
		PALETTE.bg_panel.g + elem_color.g * alpha,
		PALETTE.bg_panel.b + elem_color.b * alpha,
		PALETTE.bg_panel.a)
	return _flat_box(tinted_bg, elem_color.darkened(0.3), 6, 2)


# ============================================================================
# PUBLIC API — BACKWARD COMPATIBILITY
# ============================================================================

func apply_theme_to_control(control: Control):
	"""Apply the theme to a specific control subtree.
	NOTE: With the project-level theme, this is usually unnecessary.
	It still works for cases where you need to force-apply mid-frame."""
	control.theme = theme


func get_theme() -> Theme:
	"""Direct access to the Theme resource if needed."""
	return theme


# ============================================================================
# PRIVATE — STYLEBOX FACTORY
# ============================================================================

func _flat_box(
	bg_color: Color,
	border_color: Color,
	corner_radius: int = 0,
	border_width: int = 0
) -> StyleBoxFlat:
	"""Create a StyleBoxFlat with uniform corners and borders."""
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color

	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius

	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width

	# Anti-aliasing on rounded corners
	if corner_radius > 0:
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 1.0

	return sb


func _count_type_variations() -> int:
	"""Count how many custom type variations we registered (for debug logging)."""
	var custom_types = [
		"ActionFieldPanel", "SkillButton", "EnemyPanel", "DicePoolPanel",
		"CombatButton", "MenuPanel", "MenuHeader", "ItemSlotPanel",
		"BottomUIPanel",
	]
	var count := 0
	for t in custom_types:
		if theme.get_stylebox_list(t).size() > 0 or theme.get_color_list(t).size() > 0:
			count += 1
	return count
