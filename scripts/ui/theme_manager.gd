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

# ============================================================================
# THEME RESOURCE
# ============================================================================

var theme: Theme

# ============================================================================
# SEMANTIC PALETTE
# ============================================================================
# Every game color lives here. Other scripts reference ThemeManager.PALETTE.key
# instead of hardcoding Color() values.

# All colors sourced from the Endesga-64 palette (endesga-64.hex).
# Swatches referenced by index for traceability:
#   Neutrals: #131313(2) #1b1b1b(3) #272727(4) #3d3d3d(5) #5d5d5d(6)
#             #858585(7) #b4b4b4(8) #ffffff(9)
#   Blues:    #c7cfdd(10) #92a1b9(11) #657392(12) #424c6e(13) #2a2f4e(14)
#             #1a1932(15) #0e071b(16) #00396d(41) #0069aa(42) #0098dc(43)
#             #00cdf9(44) #0cf1ff(45) #94fdff(46)
#   Purples:  #1c121c(17) #3b1443(54) #622461(55) #93388f(56) #ca52c9(57)
#             #db3ffd(49) #f389f5(48)
#   Reds:     #c42430(62) #ea323c(61) #f5555d(60) #ff0040(1)
#   Oranges:  #ff5000(29) #ed7614(30) #ffa214(31) #ffc825(32) #ffeb57(33)
#             #edab50(25) #e07438(26) #bf6f4a(21) #e69c69(22) #f6ca9f(23)
#   Greens:   #5ac54f(36) #99e65f(35) #33984b(37) #d3fc7e(34)
#   Browns:   #8a4836(20) #5d2c28(19) #391f21(18)

const PALETTE := {
	# --- Backgrounds ---
	"bg_darkest":  Color(0.055, 0.027, 0.106),        # (16) #0e071b
	"bg_dark":     Color(0.102, 0.098, 0.196),        # (15) #1a1932
	"bg_panel":    Color(0.165, 0.184, 0.306, 0.90),  # (14) #2a2f4e
	"bg_elevated": Color(0.259, 0.298, 0.431, 0.95),  # (13) #424c6e
	"bg_input":    Color(0.102, 0.098, 0.196, 0.95),  # (15) #1a1932
	"bg_hover":    Color(0.259, 0.298, 0.431, 0.95),  # (13) #424c6e

	# --- Borders ---
	"border_subtle":  Color(0.259, 0.298, 0.431),     # (13) #424c6e
	"border_default": Color(0.396, 0.451, 0.573),     # (12) #657392
	"border_accent":  Color(0.573, 0.631, 0.725),     # (11) #92a1b9
	"border_focus":   Color(0.780, 0.812, 0.867),     # (10) #c7cfdd

	# --- Text ---
	"text_primary":   Color(1.000, 1.000, 1.000),     # (9)  #ffffff
	"text_secondary": Color(0.780, 0.812, 0.867),     # (10) #c7cfdd
	"text_muted":     Color(0.573, 0.631, 0.725),     # (11) #92a1b9
	"text_shadow":    Color(0.0, 0.0, 0.0, 0.5),

	# --- Semantic ---
	"primary":         Color(0.000, 0.412, 0.667),    # (42) #0069aa
	"primary_hover":   Color(0.000, 0.596, 0.863),    # (43) #0098dc
	"primary_pressed": Color(0.000, 0.224, 0.427),    # (41) #00396d
	"secondary":       Color(0.396, 0.451, 0.573),    # (12) #657392
	"success":         Color(0.353, 0.773, 0.310),    # (36) #5ac54f
	"danger":          Color(0.918, 0.196, 0.235),    # (61) #ea323c
	"warning":         Color(1.000, 0.784, 0.145),    # (32) #ffc825
	"info":            Color(0.000, 0.804, 0.976),    # (44) #00cdf9

	# --- Game States ---
	"locked":    Color(0.365, 0.365, 0.365),          # (6)  #5d5d5d
	"available": Color(0.000, 0.412, 0.667),          # (42) #0069aa
	"maxed":     Color(1.000, 0.922, 0.341),          # (33) #ffeb57

	# --- Elements ---
	"fire":     Color(1.000, 0.314, 0.000),           # (29) #ff5000
	"ice":      Color(0.047, 0.945, 1.000),           # (45) #0cf1ff
	"shock":    Color(0.000, 0.412, 0.667),    # (42) #0069aa
	"poison":   Color(0.353, 0.773, 0.310),           # (36) #5ac54f
	"shadow":   Color(0.384, 0.141, 0.380),           # (55) #622461
	"slashing": Color(0.706, 0.706, 0.706),           # (8)  #b4b4b4
	"blunt":    Color(0.749, 0.435, 0.290),           # (21) #bf6f4a
	"piercing": Color(0.965, 0.792, 0.624),           # (23) #f6ca9f

	# --- Rarity ---
	"rarity_common":    Color(0.706, 0.706, 0.706),   # (8)  #b4b4b4
	"rarity_uncommon":  Color(0.353, 0.773, 0.310),   # (36) #5ac54f
	"rarity_rare":      Color(0.000, 0.596, 0.863),   # (43) #0098dc
	"rarity_epic":      Color(0.792, 0.322, 0.788),   # (57) #ca52c9
	"rarity_legendary": Color(1.000, 0.635, 0.078),   # (31) #ffa214

	# --- Combat Bars ---
	"health":     Color(0.353, 0.773, 0.310),         # (36) #5ac54f
	"health_low": Color(0.769, 0.141, 0.188),         # (62) #c42430
	"mana":       Color(0.000, 0.412, 0.667),         # (42) #0069aa
	"experience": Color(0.792, 0.322, 0.788),         # (57) #ca52c9
	"armor":      Color(0.522, 0.522, 0.522),         # (7)  #858585
	"barrier":    Color(0.000, 0.596, 0.863),         # (43) #0098dc

	# --- Stats ---
	"strength":  Color(1.000, 0.314, 0.000),          # (29) #ff5000
	"agility":   Color(0.600, 0.902, 0.373),          # (35) #99e65f
	"intellect": Color(0.000, 0.412, 0.667),          # (42) #0069aa
	"luck":      Color(1.000, 0.922, 0.341),          # (33) #ffeb57

	# --- Cate ---
	"cate_happy":   Color(1.000, 0.784, 0.145),       # (32) #ffc825
	"cate_neutral": Color(0.573, 0.631, 0.725),       # (11) #92a1b9
	"cate_annoyed": Color(0.878, 0.455, 0.220),       # (26) #e07438

# --- Endesga-64 Raw Palette ---
	# Every source color, accessible via PALETTE["e64_01"] etc.
	"e64_01": Color(1.000, 0.000, 0.251),  # #ff0040 hot red
	"e64_02": Color(0.075, 0.075, 0.075),  # #131313 near black
	"e64_03": Color(0.106, 0.106, 0.106),  # #1b1b1b dark grey
	"e64_04": Color(0.153, 0.153, 0.153),  # #272727 dark grey
	"e64_05": Color(0.239, 0.239, 0.239),  # #3d3d3d mid-dark grey
	"e64_06": Color(0.365, 0.365, 0.365),  # #5d5d5d mid grey
	"e64_07": Color(0.522, 0.522, 0.522),  # #858585 grey
	"e64_08": Color(0.706, 0.706, 0.706),  # #b4b4b4 light grey
	"e64_09": Color(1.000, 1.000, 1.000),  # #ffffff white
	"e64_10": Color(0.780, 0.812, 0.867),  # #c7cfdd cool off-white
	"e64_11": Color(0.573, 0.631, 0.725),  # #92a1b9 blue-grey
	"e64_12": Color(0.396, 0.451, 0.573),  # #657392 steel blue
	"e64_13": Color(0.259, 0.298, 0.431),  # #424c6e dark blue-grey
	"e64_14": Color(0.165, 0.184, 0.306),  # #2a2f4e dark navy
	"e64_15": Color(0.102, 0.098, 0.196),  # #1a1932 deep navy
	"e64_16": Color(0.055, 0.027, 0.106),  # #0e071b near-black purple
	"e64_17": Color(0.110, 0.071, 0.110),  # #1c121c dark plum
	"e64_18": Color(0.224, 0.122, 0.129),  # #391f21 dark maroon
	"e64_19": Color(0.365, 0.173, 0.157),  # #5d2c28 maroon
	"e64_20": Color(0.541, 0.282, 0.212),  # #8a4836 sienna
	"e64_21": Color(0.749, 0.435, 0.290),  # #bf6f4a warm brown
	"e64_22": Color(0.902, 0.612, 0.412),  # #e69c69 tan
	"e64_23": Color(0.965, 0.792, 0.624),  # #f6ca9f pale skin
	"e64_24": Color(0.976, 0.902, 0.816),  # #f9e6cf lightest skin
	"e64_25": Color(0.929, 0.671, 0.314),  # #edab50 amber
	"e64_26": Color(0.878, 0.455, 0.220),  # #e07438 burnt orange
	"e64_27": Color(0.776, 0.271, 0.141),  # #c64524 deep orange
	"e64_28": Color(0.557, 0.145, 0.114),  # #8e251d dark red-brown
	"e64_29": Color(1.000, 0.314, 0.000),  # #ff5000 fire orange
	"e64_30": Color(0.929, 0.463, 0.078),  # #ed7614 orange
	"e64_31": Color(1.000, 0.635, 0.078),  # #ffa214 amber-gold
	"e64_32": Color(1.000, 0.784, 0.145),  # #ffc825 warm yellow
	"e64_33": Color(1.000, 0.922, 0.341),  # #ffeb57 bright yellow
	"e64_34": Color(0.827, 0.988, 0.494),  # #d3fc7e yellow-green
	"e64_35": Color(0.600, 0.902, 0.373),  # #99e65f lime green
	"e64_36": Color(0.353, 0.773, 0.310),  # #5ac54f mid green
	"e64_37": Color(0.200, 0.596, 0.294),  # #33984b forest green
	"e64_38": Color(0.118, 0.435, 0.314),  # #1e6f50 deep green
	"e64_39": Color(0.078, 0.298, 0.298),  # #134c4c dark teal
	"e64_40": Color(0.047, 0.180, 0.267),  # #0c2e44 dark blue-teal
	"e64_41": Color(0.000, 0.224, 0.427),  # #00396d deep blue
	"e64_42": Color(0.000, 0.412, 0.667),  # #0069aa ocean blue
	"e64_43": Color(0.000, 0.596, 0.863),  # #0098dc sky blue
	"e64_44": Color(0.000, 0.804, 0.976),  # #00cdf9 bright cyan
	"e64_45": Color(0.047, 0.945, 1.000),  # #0cf1ff icy cyan
	"e64_46": Color(0.580, 0.992, 1.000),  # #94fdff pale frost
	"e64_47": Color(0.992, 0.824, 0.929),  # #fdd2ed pale pink
	"e64_48": Color(0.953, 0.537, 0.961),  # #f389f5 hot pink
	"e64_49": Color(0.859, 0.247, 0.992),  # #db3ffd electric violet
	"e64_50": Color(0.478, 0.035, 0.980),  # #7a09fa deep violet
	"e64_51": Color(0.188, 0.012, 0.851),  # #3003d9 indigo
	"e64_52": Color(0.047, 0.008, 0.576),  # #0c0293 deep indigo
	"e64_53": Color(0.012, 0.098, 0.247),  # #03193f midnight
	"e64_54": Color(0.231, 0.078, 0.263),  # #3b1443 dark purple
	"e64_55": Color(0.384, 0.141, 0.380),  # #622461 void purple
	"e64_56": Color(0.576, 0.220, 0.561),  # #93388f drained purple
	"e64_57": Color(0.792, 0.322, 0.788),  # #ca52c9 bright purple
	"e64_58": Color(0.784, 0.314, 0.525),  # #c85086 rose purple
	"e64_59": Color(0.965, 0.506, 0.529),  # #f68187 soft red-pink
	"e64_60": Color(0.961, 0.333, 0.365),  # #f5555d coral red
	"e64_61": Color(0.918, 0.196, 0.235),  # #ea323c danger red
	"e64_62": Color(0.769, 0.141, 0.188),  # #c42430 blood red
	"e64_63": Color(0.537, 0.118, 0.169),  # #891e2b dark crimson
	"e64_64": Color(0.341, 0.110, 0.153),  # #571c27 deepest crimson
}











# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("ThemeManager initializing...")
	_load_base_theme()
	_apply_to_project()
	print("ThemeManager ready")


func _load_base_theme() -> void:
	if ResourceLoader.exists(BASE_THEME_PATH):
		theme = load(BASE_THEME_PATH)
		print("  Loaded base theme: %s" % BASE_THEME_PATH)
	else:
		push_warning("ThemeManager: base_theme.tres not found — using empty theme")
		theme = Theme.new()




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
	# Endesga-64 palette — exact hex matches from endesga-64.hex
	match status_name.to_lower():
		"burn":       return Color.html("FF5000")  # vivid orange-red
		"bleed":      return Color.html("C42430")  # deep blood red
		"poison":     return Color.html("5AC54F")  # toxic mid-green
		"chill":      return Color.html("0CF1FF")  # icy bright cyan
		"freeze":     return Color.html("94FDFF")  # pale frost cyan
		"static":     return Color.html("0098DC")  # electric mid-blue
		"stunned":    return Color.html("FFC825")  # lightning yellow
		"slowed":     return Color.html("657392")  # muted steel-blue
		"corrode":    return Color.html("EDAB50")  # rusty amber
		"shadow":     return Color.html("622461")  # dark violet
		"expose":     return Color.html("F68187")  # vulnerability pink
		"enfeeble":   return Color.html("93388F")  # drained purple
		"ignition":   return Color.html("FFA214")  # warm amber
		"block":      return Color.html("858585")  # steel grey
		"dodge":      return Color.html("00CDF9")  # agile bright blue
		"overhealth": return Color.html("FFEB57")  # gold excess
		"taunt":      return Color.html("FF0040")  # hot red provocation
		"barrier":    return Color.html("0069AA")  # protective navy
		"fortified":  return PALETTE.armor    # Color(0.60, 0.60, 0.65)
		"warded":     return PALETTE.barrier  # Color(0.40, 0.70, 0.95)
		_:            return PALETTE.text_secondary


# ============================================================================
# PUBLIC API — FONT SIZES
# ============================================================================


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
