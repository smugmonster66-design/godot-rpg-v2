# res://addons/action_effect_editor/action_effect_inspector_plugin.gd
# EditorInspectorPlugin that injects a live summary banner at the top
# of ActionEffect and ActionEffectSubEffect inspectors.
#
# The banner shows:
#   - Color-coded category badge (Core / Defensive / Multi-Target / etc.)
#   - Full human-readable summary from get_summary()
#   - Compound indicator when sub_effects are populated
#   - Auto-refreshes when the resource changes
@tool
extends EditorInspectorPlugin

# ============================================================================
# CATEGORY COLORS — matches the 6 categories from action_effect.gd header
# ============================================================================
const CATEGORY_COLORS := {
	"Core":           Color(0.75, 0.45, 0.45),  # warm red
	"Defensive":      Color(0.40, 0.65, 0.85),  # steel blue
	"Combat Mod":     Color(0.85, 0.55, 0.25),  # amber
	"Multi-Target":   Color(0.80, 0.75, 0.30),  # gold
	"Economy":        Color(0.40, 0.75, 0.45),  # green
	"Battlefield":    Color(0.65, 0.45, 0.80),  # purple
	"Summon":         Color(0.35, 0.75, 0.75),  # teal
}

# ============================================================================
# EFFECT TYPE → CATEGORY MAPPING
# ============================================================================
const EFFECT_CATEGORIES := {
	# Core
	0: "Core",   # DAMAGE
	1: "Core",   # HEAL
	2: "Core",   # ADD_STATUS
	3: "Core",   # REMOVE_STATUS
	4: "Core",   # CLEANSE
	# Defensive
	5: "Defensive",   # SHIELD
	6: "Defensive",   # ARMOR_BUFF
	7: "Defensive",   # DAMAGE_REDUCTION
	8: "Defensive",   # REFLECT
	# Combat Modifier
	9:  "Combat Mod",  # LIFESTEAL
	10: "Combat Mod",  # EXECUTE
	11: "Combat Mod",  # COMBO_MARK
	12: "Combat Mod",  # ECHO
	# Multi-Target
	13: "Multi-Target",  # SPLASH
	14: "Multi-Target",  # CHAIN
	15: "Multi-Target",  # RANDOM_STRIKES
	# Economy
	16: "Economy",  # MANA_MANIPULATE
	17: "Economy",  # MODIFY_COOLDOWN
	18: "Economy",  # REFUND_CHARGES
	19: "Economy",  # GRANT_TEMP_ACTION
	# Battlefield
	20: "Battlefield",  # CHANNEL
	21: "Battlefield",  # COUNTER_SETUP
	# Summon
	22: "Summon",  # SUMMON_COMPANION
}

# ============================================================================
# EFFECT TYPE COLORS (individual, more specific than category)
# ============================================================================
const EFFECT_TYPE_COLORS := {
	0:  Color(0.90, 0.30, 0.30),  # DAMAGE - red
	1:  Color(0.30, 0.85, 0.40),  # HEAL - green
	2:  Color(0.80, 0.60, 0.20),  # ADD_STATUS - amber
	3:  Color(0.60, 0.60, 0.60),  # REMOVE_STATUS - gray
	4:  Color(0.50, 0.80, 0.50),  # CLEANSE - light green
	5:  Color(0.40, 0.65, 0.85),  # SHIELD - blue
	6:  Color(0.55, 0.70, 0.80),  # ARMOR_BUFF - light blue
	7:  Color(0.45, 0.60, 0.75),  # DAMAGE_REDUCTION - slate
	8:  Color(0.70, 0.50, 0.80),  # REFLECT - purple
	9:  Color(0.85, 0.35, 0.50),  # LIFESTEAL - crimson
	10: Color(0.90, 0.25, 0.25),  # EXECUTE - deep red
	11: Color(0.85, 0.65, 0.30),  # COMBO_MARK - orange
	12: Color(0.75, 0.55, 0.85),  # ECHO - lavender
	13: Color(0.85, 0.75, 0.30),  # SPLASH - gold
	14: Color(0.80, 0.80, 0.35),  # CHAIN - yellow
	15: Color(0.90, 0.70, 0.25),  # RANDOM_STRIKES - orange-gold
	16: Color(0.35, 0.70, 0.85),  # MANA_MANIPULATE - cyan
	17: Color(0.40, 0.75, 0.45),  # MODIFY_COOLDOWN - green
	18: Color(0.50, 0.80, 0.55),  # REFUND_CHARGES - light green
	19: Color(0.45, 0.75, 0.70),  # GRANT_TEMP_ACTION - teal
	20: Color(0.65, 0.45, 0.80),  # CHANNEL - purple
	21: Color(0.70, 0.50, 0.75),  # COUNTER_SETUP - mauve
	22: Color(0.35, 0.75, 0.75),  # SUMMON_COMPANION - teal
}


# ============================================================================
# PLUGIN INTERFACE
# ============================================================================

func _can_handle(object: Object) -> bool:
	return object is ActionEffect or object is ActionEffectSubEffect


func _parse_begin(object: Object) -> void:
	if object is ActionEffect:
		var banner := _create_action_effect_banner(object as ActionEffect)
		add_custom_control(banner)
	elif object is ActionEffectSubEffect:
		var banner := _create_sub_effect_banner(object as ActionEffectSubEffect)
		add_custom_control(banner)


# ============================================================================
# ACTION EFFECT BANNER
# ============================================================================

func _create_action_effect_banner(effect: ActionEffect) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	# --- Main summary panel ---
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var cat: String = EFFECT_CATEGORIES.get(effect.effect_type, "Core")
	var cat_color: Color = CATEGORY_COLORS.get(cat, Color(0.5, 0.5, 0.5))
	style.bg_color = Color(cat_color.r * 0.15, cat_color.g * 0.15, cat_color.b * 0.15, 0.95)
	style.border_color = cat_color * Color(0.6, 0.6, 0.6, 0.8)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Row 1: Category badge + effect type name
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)

	# Category badge
	var badge := Label.new()
	badge.text = " %s " % cat.to_upper()
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = cat_color * Color(0.7, 0.7, 0.7, 0.9)
	badge_style.set_corner_radius_all(3)
	badge_style.set_content_margin_all(2)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge.add_theme_stylebox_override("normal", badge_style)
	top_row.add_child(badge)

	# Effect type name
	var type_label := Label.new()
	var type_color: Color = EFFECT_TYPE_COLORS.get(effect.effect_type, Color.WHITE)
	type_label.text = effect.get_effect_type_name()
	type_label.add_theme_color_override("font_color", type_color)
	type_label.add_theme_font_size_override("font_size", 14)
	top_row.add_child(type_label)

	# Compound indicator
	if effect.is_compound():
		var compound_badge := Label.new()
		compound_badge.text = " COMPOUND x%d " % effect.sub_effects.size()
		compound_badge.add_theme_font_size_override("font_size", 10)
		compound_badge.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
		var cb_style := StyleBoxFlat.new()
		cb_style.bg_color = Color(0.4, 0.4, 0.1, 0.8)
		cb_style.set_corner_radius_all(3)
		cb_style.set_content_margin_all(2)
		cb_style.content_margin_left = 6
		cb_style.content_margin_right = 6
		compound_badge.add_theme_stylebox_override("normal", cb_style)
		top_row.add_child(compound_badge)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	# Target badge
	var target_badge := Label.new()
	target_badge.text = " %s " % effect.get_target_type_name()
	target_badge.add_theme_font_size_override("font_size", 10)
	var target_colors := {
		0: Color(0.3, 0.7, 0.3),   # SELF - green
		1: Color(0.8, 0.3, 0.3),   # SINGLE_ENEMY - red
		2: Color(0.9, 0.4, 0.4),   # ALL_ENEMIES - bright red
		3: Color(0.3, 0.5, 0.8),   # SINGLE_ALLY - blue
		4: Color(0.4, 0.6, 0.9),   # ALL_ALLIES - bright blue
	}
	var t_color: Color = target_colors.get(effect.target, Color(0.5, 0.5, 0.5))
	target_badge.add_theme_color_override("font_color", Color.WHITE)
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = t_color * Color(0.6, 0.6, 0.6, 0.8)
	tb_style.set_corner_radius_all(3)
	tb_style.set_content_margin_all(2)
	tb_style.content_margin_left = 6
	tb_style.content_margin_right = 6
	target_badge.add_theme_stylebox_override("normal", tb_style)
	top_row.add_child(target_badge)

	vbox.add_child(top_row)

	# Row 2: Full summary text
	var summary_label := RichTextLabel.new()
	summary_label.bbcode_enabled = true
	summary_label.fit_content = true
	summary_label.scroll_active = false
	summary_label.custom_minimum_size.y = 20
	summary_label.add_theme_font_size_override("normal_font_size", 12)

	var summary_text := effect.get_summary()
	summary_label.text = summary_text
	vbox.add_child(summary_label)

	# Row 3: Condition + Value Source info (if non-default)
	var info_parts: Array[String] = []
	if effect.has_condition():
		info_parts.append("[color=#c8a83a]IF: %s[/color]" % effect.condition.get_description())
	if effect.value_source != ActionEffect.ValueSource.STATIC:
		info_parts.append("[color=#6ab0d6]Scales: %s[/color]" % ActionEffect.ValueSource.keys()[effect.value_source])

	if info_parts.size() > 0:
		var info_label := RichTextLabel.new()
		info_label.bbcode_enabled = true
		info_label.fit_content = true
		info_label.scroll_active = false
		info_label.custom_minimum_size.y = 16
		info_label.add_theme_font_size_override("normal_font_size", 11)
		info_label.text = "  ".join(info_parts)
		vbox.add_child(info_label)

	panel.add_child(vbox)
	container.add_child(panel)

	# --- Separator ---
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	container.add_child(sep)

	return container


# ============================================================================
# SUB-EFFECT BANNER (lighter version)
# ============================================================================

func _create_sub_effect_banner(sub: ActionEffectSubEffect) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var cat: String = EFFECT_CATEGORIES.get(sub.effect_type, "Core")
	var cat_color: Color = CATEGORY_COLORS.get(cat, Color(0.5, 0.5, 0.5))
	style.bg_color = Color(cat_color.r * 0.12, cat_color.g * 0.12, cat_color.b * 0.12, 0.90)
	style.border_color = cat_color * Color(0.5, 0.5, 0.5, 0.6)
	style.set_border_width_all(1)
	style.border_width_left = 2
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	# Category mini-badge
	var badge := Label.new()
	badge.text = cat.to_upper()
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", cat_color)
	hbox.add_child(badge)

	# Summary
	var summary := Label.new()
	summary.text = sub.get_summary()
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(summary)

	panel.add_child(hbox)
	return panel
