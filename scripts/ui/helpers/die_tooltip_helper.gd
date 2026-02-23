# res://scripts/ui/helpers/die_tooltip_helper.gd
# Shared helper for creating rich dice tooltips with affixes and theme styling
class_name DieTooltipHelper
extends RefCounted

## Build a rich tooltip showing die name, affixes, and details
static func build_tooltip(die_res: DieResource) -> PanelContainer:
	"""Build a compact tooltip showing die name and any dice affixes."""
	var panel = PanelContainer.new()
	panel.theme_type_variation = "TooltipPanel"
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.custom_minimum_size = Vector2(400, 0)
	panel.add_child(vbox)
	
	# Check if this is a standard die (name contains "D{size}") or unique
	var size_tag = "D%d" % die_res.die_type
	var is_unique = size_tag not in die_res.display_name
	
	# Die name
	var header = Label.new()
	header.theme_type_variation = "TooltipLabel"
	header.text = die_res.display_name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header)
	
	# Unique dice: show size + element beneath the name
	if is_unique:
		var subtitle = Label.new()
		subtitle.theme_type_variation = "TooltipLabel"
		var elem_name = die_res.get_element_name() if die_res.has_element() else ""
		subtitle.text = "%s %s" % [elem_name, size_tag] if elem_name else size_tag
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(subtitle)
		
		# Flavor text if present
		if die_res.has_method("get_flavor_text"):
			var flavor = die_res.get_flavor_text()
			if flavor and flavor != "":
				var flavor_label = Label.new()
				flavor_label.theme_type_variation = "TooltipLabel"
				flavor_label.text = flavor
				flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				flavor_label.add_theme_color_override("font_color", ThemeManager.PALETTE.danger)
				flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(flavor_label)
	
	# Dice affixes
	var all_affixes = die_res.get_all_affixes()
	for dice_affix in all_affixes:
		if not dice_affix:
			continue
		
		var affix_label = Label.new()
		affix_label.theme_type_variation = "TooltipLabel"
		
		# Use formatted description with actual stamped values
		if dice_affix.has_method("get_formatted_description"):
			affix_label.text = dice_affix.get_formatted_description()
			
			# Replace "N" placeholder with properly rounded value
			if "N%" in affix_label.text:
				var val = dice_affix.effect_value
				if dice_affix.effect_value_max <= 1.0:
					var rounded = snappedf(val, 0.01)
					affix_label.text = affix_label.text.replace("N%", "%d%%" % int(rounded * 100))
				else:
					affix_label.text = affix_label.text.replace("N%", "%d%%" % int(val))
			
			elif "N" in affix_label.text:
				var formatted_value = _format_affix_value(dice_affix)
				affix_label.text = affix_label.text.replace("N", formatted_value)
		
		elif dice_affix.has_method("get_description"):
			affix_label.text = dice_affix.get_description()
			
			if "N%" in affix_label.text:
				var val = dice_affix.effect_value
				var rounded = snappedf(val, 0.01) if val <= 1.0 else val
				affix_label.text = affix_label.text.replace("N%", "%d%%" % int(rounded * 100 if val <= 1.0 else rounded))
			elif "N" in affix_label.text:
				var formatted_value = _format_affix_value(dice_affix)
				affix_label.text = affix_label.text.replace("N", formatted_value)
		else:
			affix_label.text = dice_affix.affix_name
		
		affix_label.add_theme_color_override("font_color", ThemeManager.PALETTE.success)
		affix_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(affix_label)
	
	return panel


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
