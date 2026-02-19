# theme_manager.gd
# AutoLoad singleton — unified visual theming for Roll The Bones
#
# Architecture (3-layer):
#   Layer 1 — base_theme.tres: StyleBoxes, button states, type variations,
#             fonts. Edited visually in Godot's native Theme Editor.
#   Layer 2 — This script: Loads the .tres, owns the semantic PALETTE,
#             provides helper methods, applies to project via ThemeDB.
#   Layer 3 — Theme Editor plugin (addons/theme_editor): edits PALETTE,
#             font sizes, status colors. JSON import/export.
#
# Usage:
#   Colors:  ThemeManager.PALETTE.fire
#   Helpers: ThemeManager.get_element_color("fire")
#            ThemeManager.get_rarity_color("Epic")
#            ThemeManager.get_status_color("burn")
#            ThemeManager.get_font_size("title")
#   Theme:   Automatically applied — all Controls inherit via ThemeDB
#   StyleBoxes: Edit base_theme.tres in Godot's Theme Editor
#   Type Variations: Set theme_type_variation on scene nodes
#     e.g. "ActionFieldPanel", "SkillButton", "CombatButton", "MenuPanel"
extends Node

# ============================================================================
# CONFIGURATION
# ============================================================================

const BASE_THEME_PATH := "res://resources/themes/base_theme.tres"
const CUSTOM_FONT_PATH := ""        # e.g. "res://assets/fonts/your_font.ttf"
const CUSTOM_FONT_BOLD_PATH := ""   # Optional bold variant

# ============================================================================
# THEME RESOURCE
# ============================================================================

var theme: Theme
var font_regular: Font = null
var font_bold: Font = null

# ============================================================================
# SEMANTIC PALETTE
# ============================================================================
# Every game color lives here. Other scripts reference ThemeManager.PALETTE.key
# instead of hardcoding Color() values.

const PALETTE := {
	# --- Backgrounds ---
	"bg_darkest":  Color(0.04, 0.03, 0.06),
	"bg_dark":     Color(0.06, 0.05, 0.08),
	"bg_panel":    Color(0.10, 0.10, 0.15, 0.90),
	"bg_elevated": Color(0.14, 0.12, 0.20, 0.95),
	"bg_input":    Color(0.08, 0.08, 0.12, 0.95),
	"bg_hover":    Color(0.18, 0.16, 0.26, 0.95),

	# --- Borders ---
	"border_subtle":  Color(0.25, 0.25, 0.35),
	"border_default": Color(0.30, 0.30, 0.40),
	"border_accent":  Color(0.40, 0.35, 0.60),
	"border_focus":   Color(0.50, 0.45, 0.75),

	# --- Text ---
	"text_primary":   Color(1.0, 1.0, 1.0),
	"text_secondary": Color(0.78, 0.78, 0.82),
	"text_muted":     Color(0.50, 0.50, 0.55),
	"text_shadow":    Color(0.0, 0.0, 0.0, 0.5),

	# --- Semantic ---
	"primary":         Color(0.30, 0.50, 0.80),
	"primary_hover":   Color(0.40, 0.60, 0.90),
	"primary_pressed": Color(0.22, 0.40, 0.70),
	"secondary":       Color(0.45, 0.45, 0.50),
	"success":  Color(0.30, 0.75, 0.35),
	"danger":   Color(0.85, 0.25, 0.25),
	"warning":  Color(0.90, 0.80, 0.20),
	"info":     Color(0.30, 0.75, 0.80),

	# --- Game States ---
	"locked":    Color(0.40, 0.40, 0.40),
	"available": Color(0.30, 0.50, 0.80),
	"maxed":     Color(1.0, 0.85, 0.20),

	# --- Elements ---
	"fire":     Color(1.0, 0.40, 0.15),
	"ice":      Color(0.35, 0.70, 1.0),
	"shock":    Color(0.85, 0.65, 1.0),
	"poison":   Color(0.40, 0.90, 0.30),
	"shadow":   Color(0.55, 0.25, 0.75),
	"slashing": Color(0.80, 0.80, 0.80),
	"blunt":    Color(0.65, 0.55, 0.40),
	"piercing": Color(0.90, 0.90, 0.70),

	# --- Rarity ---
	"rarity_common":    Color(0.70, 0.70, 0.70),
	"rarity_uncommon":  Color(0.20, 0.80, 0.20),
	"rarity_rare":      Color(0.20, 0.50, 1.0),
	"rarity_epic":      Color(0.70, 0.20, 0.90),
	"rarity_legendary": Color(1.0, 0.60, 0.0),

	# --- Combat Bars ---
	"health":     Color(0.20, 0.75, 0.25),
	"health_low": Color(0.85, 0.25, 0.25),
	"mana":       Color(0.25, 0.45, 0.90),
	"experience": Color(0.70, 0.55, 0.85),
	"armor":      Color(0.60, 0.60, 0.65),
	"barrier":    Color(0.40, 0.70, 0.95),

	# --- Stats ---
	"strength":  Color(1.0, 0.37, 0.16),
	"agility":   Color(0.0, 0.80, 0.0),
	"intellect": Color(0.25, 0.41, 0.88),
	"luck":      Color(1.0, 0.84, 0.0),

	# --- Cate ---
	"cate_happy":   Color(1.0, 0.85, 0.40),
	"cate_neutral": Color(0.70, 0.70, 0.75),
	"cate_annoyed": Color(0.80, 0.50, 0.30),
}

# ============================================================================
# FONT SIZES
# ============================================================================

const FONT_SIZES := {
	"tiny": 10,
	"small": 12,
	"caption": 13,
	"normal": 16,
	"large": 20,
	"title": 24,
	"header": 28,
	"display": 36,
}


# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("🎨 ThemeManager initializing...")
	_load_fonts()
	_load_base_theme()
	_apply_fonts_to_theme()
	_apply_to_project()
	print("🎨 ThemeManager ready")


func _load_fonts() -> void:
	if CUSTOM_FONT_PATH != "" and ResourceLoader.exists(CUSTOM_FONT_PATH):
		font_regular = load(CUSTOM_FONT_PATH) as Font
		print("  🔤 Loaded custom font: %s" % CUSTOM_FONT_PATH)
	if CUSTOM_FONT_BOLD_PATH != "" and ResourceLoader.exists(CUSTOM_FONT_BOLD_PATH):
		font_bold = load(CUSTOM_FONT_BOLD_PATH) as Font
		print("  🔤 Loaded bold font: %s" % CUSTOM_FONT_BOLD_PATH)


func _load_base_theme() -> void:
	# Load the .tres base theme. Falls back to an empty theme if missing.
	if ResourceLoader.exists(BASE_THEME_PATH):
		theme = load(BASE_THEME_PATH).duplicate()
		print("  🎨 Loaded base theme: %s" % BASE_THEME_PATH)
	else:
		push_warning("ThemeManager: base_theme.tres not found at %s — using empty theme" % BASE_THEME_PATH)
		push_warning("  Run editor_scripts/generate_base_theme.gd to create it.")
		theme = Theme.new()


func _apply_fonts_to_theme() -> void:
	# Apply custom font and sizes to the loaded theme.
	if font_regular:
		theme.default_font = font_regular
	#theme.default_font_size = FONT_SIZES.normal


func _apply_to_project():
	var project_theme = ThemeDB.get_project_theme()
	if project_theme and is_instance_valid(project_theme):
		project_theme.merge_with(theme)
		print("  🎨 Merged into project theme")
	else:
		get_tree().root.theme = theme
		print("  🎨 Applied theme to root viewport")


# ============================================================================
# PUBLIC API — ELEMENT COLORS
# ============================================================================

func get_element_color(element_string: String) -> Color:
	# Get element color by name string (e.g. 'fire', 'Ice', 'SHADOW').
	var key = element_string.to_lower()
	if PALETTE.has(key):
		return PALETTE[key]
	return PALETTE.text_primary


func get_element_color_enum(element: int) -> Color:
	# Get element color from ActionEffect.DamageType enum value.
	match element:
		0: return PALETTE.slashing
		1: return PALETTE.piercing
		2: return PALETTE.blunt
		3: return PALETTE.fire
		4: return PALETTE.ice
		5: return PALETTE.shock
		6: return PALETTE.poison
		7: return PALETTE.shadow
		_: return PALETTE.text_primary


func get_die_element_color(element: int) -> Color:
	# Get element color from DieResource.Element enum value.
	# Handles the different ordering vs ActionEffect.DamageType.
	# DieResource.Element: NONE=0, SLASHING=1, BLUNT=2, PIERCING=3,
	#   FIRE=4, ICE=5, SHOCK=6, POISON=7, SHADOW=8
	match element:
		0: return PALETTE.text_muted    # NONE
		1: return PALETTE.slashing
		2: return PALETTE.blunt
		3: return PALETTE.piercing
		4: return PALETTE.fire
		5: return PALETTE.ice
		6: return PALETTE.shock
		7: return PALETTE.poison
		8: return PALETTE.shadow
		_: return PALETTE.text_primary


# ============================================================================
# PUBLIC API — RARITY COLORS
# ============================================================================

func get_rarity_color(rarity_name: String) -> Color:
	# Get color by rarity name string (e.g. 'Epic', 'legendary').
	var key = "rarity_" + rarity_name.to_lower()
	if PALETTE.has(key):
		return PALETTE[key]
	return PALETTE.rarity_common


func get_rarity_color_enum(rarity: int) -> Color:
	# Get rarity color from EquippableItem.Rarity enum value (0-4).
	match rarity:
		0: return PALETTE.rarity_common
		1: return PALETTE.rarity_uncommon
		2: return PALETTE.rarity_rare
		3: return PALETTE.rarity_epic
		4: return PALETTE.rarity_legendary
		_: return PALETTE.rarity_common


# ============================================================================
# PUBLIC API — STATUS COLORS
# ============================================================================

func get_status_color(status_name: String) -> Color:
	# Get color for a combat status effect.
	match status_name.to_lower():
		"poison":    return Color(0.40, 0.85, 0.25)
		"burn":      return Color(1.0, 0.40, 0.10)
		"bleed":     return Color(0.80, 0.10, 0.10)
		"chill":     return Color(0.50, 0.80, 1.0)
		"stunned":   return Color(1.0, 1.0, 0.20)
		"slowed":    return Color(0.40, 0.40, 0.80)
		"corrode":   return Color(0.60, 0.50, 0.10)
		"shadow":    return Color(0.30, 0.10, 0.40)
		"block":     return Color(0.60, 0.60, 0.60)
		"dodge":     return Color(0.20, 0.90, 0.60)
		"overhealth": return Color(0.90, 0.90, 0.20)
		"expose":    return Color(1.0, 0.50, 0.50)
		"enfeeble":  return Color(0.50, 0.30, 0.50)
		"ignition":  return Color(1.0, 0.60, 0.0)
		_:           return PALETTE.text_secondary


# ============================================================================
# PUBLIC API — FONT SIZES
# ============================================================================

func get_font_size(size_name: String) -> int:
	# Get a named font size. Returns normal if name not found.
	return FONT_SIZES.get(size_name, FONT_SIZES.normal)


# ============================================================================
# PUBLIC API — SEMANTIC HELPERS
# ============================================================================

func get_semantic_color(type: String) -> Color:
	# Get a color by semantic meaning. Backward-compatible with old API.
	if PALETTE.has(type):
		return PALETTE[type]
	return Color.WHITE


func get_skill_state_style(state: int) -> StyleBoxFlat:
	# Return a duplicate StyleBoxFlat for a SkillButton state.
	# Pass SkillButton.State.LOCKED=0 / AVAILABLE=1 / MAXED=2.
	var style_name := "locked"
	match state:
		1: style_name = "available"
		2: style_name = "maxed"
	var sb = theme.get_stylebox(style_name, "SkillButton")
	if sb:
		return sb.duplicate()
	return _flat_box(PALETTE.bg_panel, PALETTE.border_default, 6, 2)


func get_element_panel(element_string: String, alpha: float = 0.15) -> StyleBoxFlat:
	# Create a panel StyleBox with a subtle element color tint.
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

func apply_theme_to_control(control: Control) -> void:
	# Apply theme to a specific control subtree.
	# NOTE: With project-level theme, this is usually unnecessary.
	control.theme = theme


func get_theme() -> Theme:
	# Direct access to the Theme resource.
	return theme


# ============================================================================
# STYLEBOX FACTORY (still available for dynamic runtime needs)
# ============================================================================

func _flat_box(
	bg_color: Color,
	border_color: Color,
	corner_radius: int = 0,
	border_width: int = 0
) -> StyleBoxFlat:
	# Create a StyleBoxFlat with uniform corners and borders.
	# Use this for dynamic/runtime StyleBoxes. For static styles,
	# edit base_theme.tres in Godot's Theme Editor instead.
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_corner_radius_all(corner_radius)
	sb.set_border_width_all(border_width)
	if corner_radius > 0:
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 1.0
	return sb
