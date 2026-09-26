# res://scripts/ui/helpers/die_tooltip_helper.gd
# Shared helper for creating rich dice tooltips with affixes and theme styling
class_name DieTooltipHelper
extends RefCounted

## Build a rich tooltip showing die name, affixes, and details
static func build_tooltip(die_res: DieResource) -> PanelContainer:
	"""Build a compact tooltip showing die name and any dice affixes."""
	var panel = PanelContainer.new()
	panel.theme_type_variation = "TooltipPanel"
	# Explicitly assign theme so variations resolve when panel lands
	# inside Godot's internal tooltip popup (outside normal ThemeDB chain)
	if ThemeManager and ThemeManager.theme:
		panel.theme = ThemeManager.theme
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.custom_minimum_size = Vector2(400, 0)
	panel.add_child(vbox)
	
	# Check if this is a standard die (name contains "D{size}") or unique
	var size_tag = "D%d" % die_res.die_type
	var is_unique = size_tag not in die_res.display_name
	
	# Die name
	var header = DescriptionParser.make_rich_label("[center]%s[/center]" % die_res.display_name)
	header.theme_type_variation = "DieTooltipDetails"
	vbox.add_child(header)

	# Unique dice: show size + element beneath the name
	if is_unique:
		var elem_name = die_res.get_element_name() if die_res.has_element() else ""
		var sub_text = "%s %s" % [elem_name, size_tag] if elem_name else size_tag
		var subtitle = DescriptionParser.make_rich_label(
			"[center]%s[/center]" % sub_text, ThemeManager.PALETTE.text_muted)
		subtitle.theme_type_variation = "TooltipLabel"
		vbox.add_child(subtitle)

		# Flavor text if present
		if die_res.has_method("get_flavor_text"):
			var flavor = die_res.get_flavor_text()
			if flavor and flavor != "":
				var flavor_label = DescriptionParser.make_rich_label(
					"[center]%s[/center]" % flavor, ThemeManager.PALETTE.danger)
				flavor_label.theme_type_variation = "TooltipLabel"
				vbox.add_child(flavor_label)

	# Dice affixes
	var all_affixes = die_res.get_all_affixes()
	for dice_affix in all_affixes:
		if not dice_affix:
			continue

		# Build text first
		var affix_text: String
		if dice_affix.has_method("get_formatted_description"):
			affix_text = dice_affix.get_formatted_description()
			affix_text = _replace_n_placeholder(affix_text, dice_affix)
		elif dice_affix.has_method("get_description"):
			affix_text = dice_affix.get_description()
			affix_text = _replace_n_placeholder(affix_text, dice_affix)
		else:
			affix_text = dice_affix.affix_name

		var affix_label = DescriptionParser.make_rich_label(affix_text, ThemeManager.PALETTE.success)
		affix_label.theme_type_variation = "DieTooltipDetails"
		vbox.add_child(affix_label)

	return panel



static func _replace_n_placeholder(text: String, dice_affix: DiceAffix) -> String:
	var val := dice_affix.effect_value
	var val_min := dice_affix.effect_value_min
	var val_max := dice_affix.effect_value_max
	var is_percent := val_max <= 1.0 and val_min >= 0.0 and val_max > 0.0

	if "+N%" in text or "N%" in text:
		var pct_val: int
		if is_percent:
			pct_val = int(snappedf(val, 0.01) * 100)
		else:
			pct_val = int(val)
		text = text.replace("+N%", "+%d%%" % pct_val)
		text = text.replace("N%", "%d%%" % pct_val)
		return text

	if "+N" in text or "N" in text:
		var formatted := _format_affix_value(dice_affix)
		text = text.replace("+N", formatted)
		text = text.replace("N", formatted)

	return text

## Format affix value with proper rounding
static func _format_affix_value(dice_affix: DiceAffix) -> String:
	"""Format value matching game's _round_dice_value() logic"""
	var val = dice_affix.effect_value
	var val_min = dice_affix.effect_value_min
	var val_max = dice_affix.effect_value_max
	
	# Rule 1: Percentages (0.0-1.0 range)
	if val_max <= 1.0 and val_min >= 0.0 and val_max > 0.0:
		var rounded = snappedf(val, 0.01)
		return "%d%%" % int(rounded * 100)
	
	# Rule 2: Small values (max ≤ 5.0)
	elif val_max <= 5.0:
		var rounded = snappedf(val, 0.5)
		if rounded == int(rounded):
			return "+%d" % int(rounded)
		else:
			return "+%.1f" % rounded
	
	# Rule 3: Large values (>5.0)
	else:
		var rounded = roundf(val)
		return "+%d" % int(rounded)
