# res://editor_scripts/generate_base_theme.gd
# Run via: Editor → Script → Run (Ctrl+Shift+X) with this script open.
#
# Generates res://resources/themes/base_theme.tres with all StyleBox
# configurations, button states, panel types, custom type variations,
# font sizes, and colors. After generation, edit the .tres in Godot's
# native Theme Editor for visual tweaking.
#
# ThemeManager loads this .tres at runtime and layers semantic colors on top.
# Re-run this script to regenerate from scratch (overwrites the .tres).
@tool
extends EditorScript

const OUTPUT_PATH := "res://resources/themes/base_theme.tres"

# ============================================================================
# PALETTE — copied from ThemeManager for generation
# ============================================================================
const P := {
	# Backgrounds
	bg_darkest  = Color(0.04, 0.03, 0.06),
	bg_dark     = Color(0.06, 0.05, 0.08),
	bg_panel    = Color(0.10, 0.10, 0.15, 0.90),
	bg_elevated = Color(0.14, 0.12, 0.20, 0.95),
	bg_input    = Color(0.08, 0.08, 0.12, 0.95),
	bg_hover    = Color(0.18, 0.16, 0.26, 0.95),
	# Borders
	border_subtle  = Color(0.25, 0.25, 0.35),
	border_default = Color(0.30, 0.30, 0.40),
	border_accent  = Color(0.40, 0.35, 0.60),
	border_focus   = Color(0.50, 0.45, 0.75),
	# Text
	text_primary   = Color(1.0, 1.0, 1.0),
	text_secondary = Color(0.78, 0.78, 0.82),
	text_muted     = Color(0.50, 0.50, 0.55),
	text_shadow    = Color(0.0, 0.0, 0.0, 0.5),
	# Semantic
	primary         = Color(0.30, 0.50, 0.80),
	primary_hover   = Color(0.40, 0.60, 0.90),
	primary_pressed = Color(0.22, 0.40, 0.70),
	secondary       = Color(0.45, 0.45, 0.50),
	success  = Color(0.30, 0.75, 0.35),
	danger   = Color(0.85, 0.25, 0.25),
	warning  = Color(0.90, 0.80, 0.20),
	info     = Color(0.30, 0.75, 0.80),
	# Skill states
	locked    = Color(0.40, 0.40, 0.40),
	available = Color(0.30, 0.50, 0.80),
	maxed     = Color(1.0, 0.85, 0.20),
	# Health bars
	health     = Color(0.20, 0.75, 0.25),
	health_low = Color(0.85, 0.25, 0.25),
	mana       = Color(0.25, 0.45, 0.90),
	experience = Color(0.70, 0.55, 0.85),
	armor      = Color(0.60, 0.60, 0.65),
	barrier    = Color(0.40, 0.70, 0.95),
}

# Font sizes
const FS := {
	tiny = 10, small = 12, caption = 13, normal = 16,
	large = 20, title = 24, header = 28, display = 36,
}


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════")
	print("  BASE THEME GENERATOR")
	print("═══════════════════════════════════════════════════")

	var theme := Theme.new()

	_setup_fonts(theme)
	_setup_default_controls(theme)
	_setup_buttons(theme)
	_setup_panels(theme)
	_setup_labels(theme)
	_setup_progress_bars(theme)
	_setup_scroll_containers(theme)
	_setup_tabs(theme)
	_setup_tooltips(theme)

	# Game-specific type variations
	_setup_action_field_type(theme)
	_setup_skill_button_type(theme)
	_setup_combat_panel_types(theme)
	_setup_menu_types(theme)

	# Save
	DirAccess.make_dir_recursive_absolute("res://resources/themes")
	var err = ResourceSaver.save(theme, OUTPUT_PATH)
	if err == OK:
		print("  ✅ Saved: %s" % OUTPUT_PATH)
		print("  📝 Open it in the Godot Theme Editor to tweak visually.")
	else:
		print("  ❌ Failed to save: error %d" % err)

	print("═══════════════════════════════════════════════════")
	print("")


# ============================================================================
# HELPER
# ============================================================================

func _flat(bg: Color, border: Color, radius: int = 0, bw: int = 0,
		margins: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(bw)
	if margins > 0:
		sb.content_margin_left = margins
		sb.content_margin_right = margins
		sb.content_margin_top = margins
		sb.content_margin_bottom = margins
	if radius > 0:
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 1.0
	return sb


func _empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


# ============================================================================
# FONTS
# ============================================================================

func _setup_fonts(t: Theme) -> void:
	t.default_font_size = FS.normal
	# Register named sizes on Label for ThemeManager.get_font_size() lookups
	for size_name in FS:
		t.set_font_size("font_size", size_name, FS[size_name])
	print("  🔤 Fonts: %d named sizes" % FS.size())


# ============================================================================
# DEFAULT CONTROL STYLES
# ============================================================================

func _setup_default_controls(t: Theme) -> void:
	# Base colors all controls inherit
	t.set_color("font_color", "Control", P.text_primary)
	print("  ⬛ Default control styles set")


# ============================================================================
# BUTTONS
# ============================================================================

func _setup_buttons(t: Theme) -> void:
	# --- Base Button ---
	t.set_stylebox("normal",   "Button", _flat(P.bg_elevated, P.border_default, 4, 2, 8))
	t.set_stylebox("hover",    "Button", _flat(P.bg_hover, P.border_accent, 4, 2, 8))
	t.set_stylebox("pressed",  "Button", _flat(P.primary_pressed, P.border_focus, 4, 2, 8))
	t.set_stylebox("disabled", "Button", _flat(
		Color(P.bg_panel.r, P.bg_panel.g, P.bg_panel.b, 0.5),
		P.border_subtle, 4, 1, 8))
	t.set_stylebox("focus",    "Button", _empty_box())

	t.set_color("font_color",          "Button", P.text_primary)
	t.set_color("font_hover_color",    "Button", P.text_primary)
	t.set_color("font_pressed_color",  "Button", P.maxed)
	t.set_color("font_disabled_color", "Button", P.text_muted)
	t.set_color("font_focus_color",    "Button", P.text_primary)

	print("  🔘 Buttons: base + 4 states")


# ============================================================================
# PANELS
# ============================================================================

func _setup_panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer",
		_flat(P.bg_panel, P.border_default, 8, 2, 4))

	t.set_stylebox("panel", "Panel",
		_flat(P.bg_panel, P.border_default, 8, 2, 4))

	print("  📦 Panels: PanelContainer + Panel")


# ============================================================================
# LABELS
# ============================================================================

func _setup_labels(t: Theme) -> void:
	t.set_color("font_color", "Label", P.text_primary)
	t.set_color("font_shadow_color", "Label", P.text_shadow)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	print("  🏷️ Labels: colors + shadow")


# ============================================================================
# PROGRESS BARS
# ============================================================================

func _setup_progress_bars(t: Theme) -> void:
	t.set_stylebox("background", "ProgressBar",
		_flat(Color(P.bg_darkest.r, P.bg_darkest.g, P.bg_darkest.b, 0.8),
			P.border_subtle, 4, 1))

	var fill = _flat(P.health, P.health.darkened(0.3), 3, 0)
	t.set_stylebox("fill", "ProgressBar", fill)

	print("  📊 ProgressBar: bg + fill")


# ============================================================================
# SCROLL CONTAINERS
# ============================================================================

func _setup_scroll_containers(t: Theme) -> void:
	# Thin scrollbar
	var grabber = _flat(P.border_accent, Color.TRANSPARENT, 4, 0)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar",
		_flat(P.border_focus, Color.TRANSPARENT, 4, 0))

	var scroll_bg = _flat(Color(P.bg_darkest.r, P.bg_darkest.g, P.bg_darkest.b, 0.3),
		Color.TRANSPARENT, 4, 0)
	scroll_bg.content_margin_left = 6
	scroll_bg.content_margin_right = 6
	t.set_stylebox("scroll", "VScrollBar", scroll_bg)

	print("  📜 ScrollContainer: thin scrollbar")


# ============================================================================
# TABS
# ============================================================================

func _setup_tabs(t: Theme) -> void:
	t.set_stylebox("tab_selected", "TabContainer",
		_flat(P.bg_elevated, P.border_accent, 4, 2, 8))
	t.set_stylebox("tab_unselected", "TabContainer",
		_flat(P.bg_dark, P.border_subtle, 4, 1, 8))
	t.set_stylebox("tab_hovered", "TabContainer",
		_flat(P.bg_hover, P.border_default, 4, 1, 8))
	t.set_stylebox("panel", "TabContainer",
		_flat(P.bg_panel, P.border_default, 0, 2, 4))

	t.set_color("font_selected_color",   "TabContainer", P.text_primary)
	t.set_color("font_unselected_color", "TabContainer", P.text_muted)
	t.set_color("font_hovered_color",    "TabContainer", P.text_secondary)

	print("  📑 Tabs: selected/unselected/hovered + panel")


# ============================================================================
# TOOLTIPS
# ============================================================================

func _setup_tooltips(t: Theme) -> void:
	var tip_style = _flat(
		Color(P.bg_darkest.r + 0.02, P.bg_darkest.g + 0.02, P.bg_darkest.b + 0.04, 0.98),
		P.border_accent, 6, 2, 8)
	t.set_stylebox("panel", "TooltipPanel", tip_style)
	t.set_color("font_color", "TooltipLabel", P.text_primary)
	t.set_font_size("font_size", "TooltipLabel", FS.small)

	print("  💬 Tooltips: dark panel + accent border")


# ============================================================================
# CUSTOM TYPE: ActionFieldPanel
# ============================================================================

func _setup_action_field_type(t: Theme) -> void:
	var normal = _flat(
		Color(0.12, 0.08, 0.18, 0.95),
		P.border_accent, 6, 2, 4)

	var highlighted = _flat(
		Color(0.16, 0.12, 0.24, 0.98),
		P.border_focus, 6, 3, 4)

	var disabled = _flat(
		Color(0.08, 0.08, 0.10, 0.6),
		P.border_subtle, 6, 1, 4)

	t.set_stylebox("panel", "ActionFieldPanel", normal)
	t.set_stylebox("panel_highlighted", "ActionFieldPanel", highlighted)
	t.set_stylebox("panel_disabled", "ActionFieldPanel", disabled)
	t.set_color("font_color", "ActionFieldPanel", P.text_primary)

	# Die slot within action field
	var slot = _flat(P.bg_input, P.border_subtle, 4, 2, 2)
	t.set_stylebox("die_slot_empty", "ActionFieldPanel", slot)

	var slot_hover = _flat(P.bg_hover, P.border_accent, 4, 2, 2)
	t.set_stylebox("die_slot_hover", "ActionFieldPanel", slot_hover)

	print("  ⚔️ ActionFieldPanel: normal/highlighted/disabled + die slots")


# ============================================================================
# CUSTOM TYPE: SkillButton
# ============================================================================

func _setup_skill_button_type(t: Theme) -> void:
	# Locked — dark, desaturated
	var locked = _flat(Color(0.12, 0.12, 0.14, 0.8), P.locked, 6, 2)
	locked.content_margin_left = 4
	locked.content_margin_right = 4
	locked.content_margin_top = 4
	locked.content_margin_bottom = 4
	t.set_stylebox("locked", "SkillButton", locked)

	# Available — blue glow
	var avail = _flat(
		Color(P.available.r * 0.15, P.available.g * 0.15, P.available.b * 0.15, 0.9),
		P.available, 6, 2)
	avail.content_margin_left = 4
	avail.content_margin_right = 4
	avail.content_margin_top = 4
	avail.content_margin_bottom = 4
	t.set_stylebox("available", "SkillButton", avail)

	# Maxed — gold border, warm tint
	var mx = _flat(
		Color(P.maxed.r * 0.12, P.maxed.g * 0.12, P.maxed.b * 0.12, 0.9),
		P.maxed, 6, 3)
	mx.content_margin_left = 4
	mx.content_margin_right = 4
	mx.content_margin_top = 4
	mx.content_margin_bottom = 4
	t.set_stylebox("maxed", "SkillButton", mx)

	t.set_color("font_locked_color",    "SkillButton", P.text_muted)
	t.set_color("font_available_color", "SkillButton", P.text_primary)
	t.set_color("font_maxed_color",     "SkillButton", P.maxed)

	print("  🔮 SkillButton: locked/available/maxed")


# ============================================================================
# CUSTOM TYPES: Combat panels
# ============================================================================

func _setup_combat_panel_types(t: Theme) -> void:
	# EnemyPanel
	t.set_stylebox("panel", "EnemyPanel",
		_flat(Color(0.12, 0.06, 0.06, 0.9), Color(0.5, 0.2, 0.2), 6, 2, 4))
	t.set_color("font_color", "EnemyPanel", P.text_primary)

	# DicePoolPanel
	t.set_stylebox("panel", "DicePoolPanel",
		_flat(Color(0.06, 0.08, 0.14, 0.9), P.border_default, 8, 2, 6))

	# CombatButton — slightly brighter than base Button
	t.set_stylebox("normal",  "CombatButton",
		_flat(P.primary, P.border_focus, 6, 2, 10))
	t.set_stylebox("hover",   "CombatButton",
		_flat(P.primary_hover, P.border_focus, 6, 2, 10))
	t.set_stylebox("pressed", "CombatButton",
		_flat(P.primary_pressed, P.primary, 6, 2, 10))
	t.set_stylebox("disabled", "CombatButton",
		_flat(P.secondary, P.border_subtle, 6, 1, 10))
	t.set_color("font_color", "CombatButton", P.text_primary)

	# BottomUIPanel
	t.set_stylebox("panel", "BottomUIPanel",
		_flat(Color(0.05, 0.04, 0.07, 0.95), P.border_subtle, 0, 2, 4))

	print("  ⚔️ Combat types: EnemyPanel, DicePoolPanel, CombatButton, BottomUIPanel")


# ============================================================================
# CUSTOM TYPES: Menu panels
# ============================================================================

func _setup_menu_types(t: Theme) -> void:
	# MenuPanel — main menu background
	t.set_stylebox("panel", "MenuPanel",
		_flat(Color(0.06, 0.05, 0.09, 0.98), P.border_accent, 12, 2, 8))

	# MenuHeader — section headers in menus
	t.set_stylebox("panel", "MenuHeader",
		_flat(Color(0.08, 0.06, 0.12, 0.9), P.border_subtle, 4, 0, 6))
	t.set_color("font_color", "MenuHeader", P.maxed)
	t.set_font_size("font_size", "MenuHeader", FS.title)

	# ItemSlotPanel — inventory/equipment slots
	t.set_stylebox("panel", "ItemSlotPanel",
		_flat(P.bg_input, P.border_subtle, 4, 2, 2))

	var slot_hover = _flat(P.bg_hover, P.border_accent, 4, 2, 2)
	t.set_stylebox("panel_hover", "ItemSlotPanel", slot_hover)

	var slot_selected = _flat(
		Color(P.primary.r * 0.2, P.primary.g * 0.2, P.primary.b * 0.2, 0.9),
		P.primary, 4, 2, 2)
	t.set_stylebox("panel_selected", "ItemSlotPanel", slot_selected)

	# IconButton type
	t.set_stylebox("normal", "IconButton",
		_flat(P.bg_elevated, P.border_accent, 6, 2, 4))
	t.set_stylebox("hover", "IconButton",
		_flat(P.bg_hover, P.border_default, 6, 1, 4))
	t.set_stylebox("pressed", "IconButton",
		_flat(P.primary_pressed, P.border_focus, 6, 2, 4))
	t.set_stylebox("inactive", "IconButton",
		_flat(P.bg_panel, P.border_default, 6, 1, 4))
	t.set_color("font_active_color",   "IconButton", P.text_primary)
	t.set_color("font_inactive_color", "IconButton", P.text_muted)

	print("  📋 Menu types: MenuPanel, MenuHeader, ItemSlotPanel, IconButton")
