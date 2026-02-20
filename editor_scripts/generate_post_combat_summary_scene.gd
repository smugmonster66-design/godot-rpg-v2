# res://editor_scripts/generate_post_combat_summary_scene.gd
# Run from Editor → Script → Run (Ctrl+Shift+X) to generate the scene file.
# Uses ThemeManager PALETTE/FONT_SIZES when available, falls back to matching constants.
@tool
extends EditorScript

const SAVE_PATH := "res://scenes/ui/popups/post_combat_summary.tscn"
const SCRIPT_PATH := "res://scripts/ui/combat/post_combat_summary.gd"

# ============================================================================
# THEME CONSTANTS — mirrors ThemeManager so generator works even without autoload
# ============================================================================

# Font sizes (from ThemeManager.FONT_SIZES)
var F_SMALL: int = 12
var F_CAPTION: int = 13
var F_NORMAL: int = 16
var F_LARGE: int = 20
var F_TITLE: int = 24
var F_HEADER: int = 28

# Colors (from ThemeManager.PALETTE)
var C_BG_ELEVATED: Color = Color(0.14, 0.12, 0.20, 0.95)
var C_BG_HOVER: Color = Color(0.18, 0.16, 0.26, 0.95)
var C_BORDER_ACCENT: Color = Color(0.40, 0.35, 0.60)
var C_BORDER_DEFAULT: Color = Color(0.30, 0.30, 0.40)
var C_TEXT_SECONDARY: Color = Color(0.78, 0.78, 0.82)
var C_TEXT_MUTED: Color = Color(0.50, 0.50, 0.55)
var C_SUCCESS: Color = Color(0.30, 0.75, 0.35)
var C_WARNING: Color = Color(0.90, 0.80, 0.20)
var C_EXPERIENCE: Color = Color(0.70, 0.55, 0.85)
var C_MAXED: Color = Color(1.0, 0.85, 0.20)


func _run():
	_sync_theme()
	print("🔨 Generating PostCombatSummary scene...")
	var root := _build_scene()
	var scene := PackedScene.new()
	scene.pack(root)
	var err := ResourceSaver.save(scene, SAVE_PATH)
	if err == OK:
		print("  ✅ Saved to %s" % SAVE_PATH)
	else:
		push_error("  ❌ Failed to save: %d" % err)
	root.queue_free()


func _sync_theme():
	"""Pull live values from ThemeManager if available (editor autoload)."""
	var tm = Engine.get_singleton("ThemeManager") if Engine.has_singleton("ThemeManager") else null
	if not tm:
		# Try scene tree autoload
		if Engine.get_main_loop() is SceneTree:
			tm = Engine.get_main_loop().root.get_node_or_null("ThemeManager")
	if not tm:
		print("  ⚠️ ThemeManager not available — using built-in constants")
		return
	print("  🎨 Syncing from ThemeManager")
	if "FONT_SIZES" in tm:
		F_SMALL = tm.FONT_SIZES.small
		F_CAPTION = tm.FONT_SIZES.caption
		F_NORMAL = tm.FONT_SIZES.normal
		F_LARGE = tm.FONT_SIZES.large
		F_TITLE = tm.FONT_SIZES.title
		F_HEADER = tm.FONT_SIZES.header
	if "PALETTE" in tm:
		C_BG_ELEVATED = tm.PALETTE.bg_elevated
		C_BG_HOVER = tm.PALETTE.bg_hover
		C_BORDER_ACCENT = tm.PALETTE.border_accent
		C_BORDER_DEFAULT = tm.PALETTE.border_default
		C_TEXT_SECONDARY = tm.PALETTE.text_secondary
		C_TEXT_MUTED = tm.PALETTE.text_muted
		C_SUCCESS = tm.PALETTE.success
		C_WARNING = tm.PALETTE.warning
		C_EXPERIENCE = tm.PALETTE.experience
		C_MAXED = tm.PALETTE.maxed


func _build_scene() -> Control:
	# ── Root ──
	var root := Control.new()
	root.name = "PostCombatSummary"
	root.visible = false
	_full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var script = load(SCRIPT_PATH)
	if script:
		root.set_script(script)

	# ── Overlay ──
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	_full_rect(overlay)
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	overlay.owner = root

	# ── CenterContainer ──
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	_full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.owner = root

	# ── Panel ──
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(650, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_panel_style(panel, C_BG_ELEVATED, C_BORDER_ACCENT, 12, 2)
	center.add_child(panel)
	panel.owner = root

	# ── MarginContainer ──
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	margin.owner = root

	# ── VBox ──
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	vbox.owner = root

	# ────────────────────────────────────────
	# TITLE
	# ────────────────────────────────────────
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "VICTORY!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", F_HEADER)
	title.add_theme_color_override("font_color", C_SUCCESS)
	vbox.add_child(title)
	title.owner = root

	# ── Sep1 ──
	var sep1 := HSeparator.new()
	sep1.name = "Sep1"
	vbox.add_child(sep1)
	sep1.owner = root

	# ────────────────────────────────────────
	# REWARDS SECTION
	# ────────────────────────────────────────
	var rewards := VBoxContainer.new()
	rewards.name = "RewardsSection"
	rewards.add_theme_constant_override("separation", 10)
	vbox.add_child(rewards)
	rewards.owner = root

	# ── XP Row ──
	var xp_row := HBoxContainer.new()
	xp_row.name = "XPRow"
	xp_row.add_theme_constant_override("separation", 8)
	rewards.add_child(xp_row)
	xp_row.owner = root

	var xp_icon_label := Label.new()
	xp_icon_label.name = "XPIconLabel"
	xp_icon_label.text = "⚔️ XP:"
	xp_icon_label.add_theme_font_size_override("font_size", F_LARGE)
	xp_row.add_child(xp_icon_label)
	xp_icon_label.owner = root

	var xp_value := Label.new()
	xp_value.name = "XPValueLabel"
	xp_value.text = "+0"
	xp_value.add_theme_font_size_override("font_size", F_LARGE)
	xp_value.add_theme_color_override("font_color", C_WARNING)
	xp_row.add_child(xp_value)
	xp_value.owner = root

	# ── XP Bar Row ──
	var xp_bar_row := HBoxContainer.new()
	xp_bar_row.name = "XPBarRow"
	xp_bar_row.add_theme_constant_override("separation", 8)
	rewards.add_child(xp_bar_row)
	xp_bar_row.owner = root

	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Lv 1"
	level_label.add_theme_font_size_override("font_size", F_CAPTION)
	level_label.add_theme_color_override("font_color", C_EXPERIENCE)
	xp_bar_row.add_child(level_label)
	level_label.owner = root

	var xp_bar := ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.custom_minimum_size = Vector2(0, 22)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.min_value = 0
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_bar.show_percentage = false
	xp_bar_row.add_child(xp_bar)
	xp_bar.owner = root

	var next_level := Label.new()
	next_level.name = "NextLevelLabel"
	next_level.text = "Lv 2"
	next_level.add_theme_font_size_override("font_size", F_CAPTION)
	next_level.add_theme_color_override("font_color", C_EXPERIENCE)
	xp_bar_row.add_child(next_level)
	next_level.owner = root

	# ── Level Up Label ──
	var lvl_up := Label.new()
	lvl_up.name = "LevelUpLabel"
	lvl_up.text = "✨ LEVEL UP! ✨"
	lvl_up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_up.add_theme_font_size_override("font_size", F_LARGE)
	lvl_up.add_theme_color_override("font_color", C_MAXED)
	lvl_up.visible = false
	rewards.add_child(lvl_up)
	lvl_up.owner = root

	# ── Gold Row ──
	var gold_row := HBoxContainer.new()
	gold_row.name = "GoldRow"
	gold_row.add_theme_constant_override("separation", 8)
	rewards.add_child(gold_row)
	gold_row.owner = root

	var gold_icon := Label.new()
	gold_icon.name = "GoldIconLabel"
	gold_icon.text = "💰 Gold:"
	gold_icon.add_theme_font_size_override("font_size", F_LARGE)
	gold_row.add_child(gold_icon)
	gold_icon.owner = root

	var gold_value := Label.new()
	gold_value.name = "GoldValueLabel"
	gold_value.text = "+0"
	gold_value.add_theme_font_size_override("font_size", F_LARGE)
	gold_value.add_theme_color_override("font_color", C_WARNING)
	gold_row.add_child(gold_value)
	gold_value.owner = root

	# ── Sep2 ──
	var sep2 := HSeparator.new()
	sep2.name = "Sep2"
	vbox.add_child(sep2)
	sep2.owner = root

	# ────────────────────────────────────────
	# LOOT SECTION
	# ────────────────────────────────────────
	var loot_section := VBoxContainer.new()
	loot_section.name = "LootSection"
	loot_section.add_theme_constant_override("separation", 8)
	vbox.add_child(loot_section)
	loot_section.owner = root

	var loot_header := Label.new()
	loot_header.name = "LootHeader"
	loot_header.text = "Items Found"
	loot_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_header.add_theme_font_size_override("font_size", F_LARGE)
	loot_section.add_child(loot_header)
	loot_header.owner = root

	var loot_scroll := ScrollContainer.new()
	loot_scroll.name = "LootScroll"
	loot_scroll.custom_minimum_size = Vector2(0, 200)
	loot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loot_section.add_child(loot_scroll)
	loot_scroll.owner = root

	var loot_grid := GridContainer.new()
	loot_grid.name = "LootGrid"
	loot_grid.columns = 3
	loot_grid.add_theme_constant_override("h_separation", 8)
	loot_grid.add_theme_constant_override("v_separation", 8)
	loot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loot_scroll.add_child(loot_grid)
	loot_grid.owner = root

	# ────────────────────────────────────────
	# ITEM DETAIL PANEL
	# ────────────────────────────────────────
	var detail_panel := PanelContainer.new()
	detail_panel.name = "ItemDetailPanel"
	detail_panel.visible = false
	_apply_panel_style(detail_panel, C_BG_HOVER, C_BORDER_DEFAULT, 8, 1)
	vbox.add_child(detail_panel)
	detail_panel.owner = root

	var detail_margin := MarginContainer.new()
	detail_margin.name = "DetailMargin"
	detail_margin.add_theme_constant_override("margin_left", 12)
	detail_margin.add_theme_constant_override("margin_right", 12)
	detail_margin.add_theme_constant_override("margin_top", 12)
	detail_margin.add_theme_constant_override("margin_bottom", 12)
	detail_panel.add_child(detail_margin)
	detail_margin.owner = root

	var detail_vbox := VBoxContainer.new()
	detail_vbox.name = "DetailVBox"
	detail_vbox.add_theme_constant_override("separation", 6)
	detail_margin.add_child(detail_vbox)
	detail_vbox.owner = root

	# Detail Header (icon + name)
	var detail_header := HBoxContainer.new()
	detail_header.name = "DetailHeader"
	detail_header.add_theme_constant_override("separation", 10)
	detail_vbox.add_child(detail_header)
	detail_header.owner = root

	var detail_icon := TextureRect.new()
	detail_icon.name = "DetailIcon"
	detail_icon.custom_minimum_size = Vector2(64, 64)
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_header.add_child(detail_icon)
	detail_icon.owner = root

	var detail_name_vbox := VBoxContainer.new()
	detail_name_vbox.name = "DetailNameVBox"
	detail_name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_header.add_child(detail_name_vbox)
	detail_name_vbox.owner = root

	var detail_name := Label.new()
	detail_name.name = "DetailNameLabel"
	detail_name.text = "Item Name"
	detail_name.add_theme_font_size_override("font_size", F_LARGE)
	detail_name_vbox.add_child(detail_name)
	detail_name.owner = root

	var detail_slot := Label.new()
	detail_slot.name = "DetailSlotLabel"
	detail_slot.text = "Slot — Rarity"
	detail_slot.add_theme_font_size_override("font_size", F_CAPTION)
	detail_slot.add_theme_color_override("font_color", C_TEXT_SECONDARY)
	detail_name_vbox.add_child(detail_slot)
	detail_slot.owner = root

	# Affix list
	var affix_list := VBoxContainer.new()
	affix_list.name = "DetailAffixList"
	affix_list.add_theme_constant_override("separation", 4)
	detail_vbox.add_child(affix_list)
	affix_list.owner = root

	# ────────────────────────────────────────
	# CONTINUE BUTTON
	# ────────────────────────────────────────
	var btn := Button.new()
	btn.name = "ContinueButton"
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(btn)
	btn.owner = root

	print("  🔨 Built %d nodes" % _count_nodes(root))
	return root


# ============================================================================
# HELPERS
# ============================================================================

func _full_rect(ctrl: Control) -> void:
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.anchor_right = 1.0
	ctrl.anchor_bottom = 1.0
	ctrl.offset_left = 0
	ctrl.offset_top = 0
	ctrl.offset_right = 0
	ctrl.offset_bottom = 0


func _apply_panel_style(panel: PanelContainer, bg: Color, border: Color,
		corner: int, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
