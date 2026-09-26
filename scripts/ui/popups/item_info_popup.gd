# res://scripts/ui/popups/item_info_popup.gd
# Standalone item detail popup. Shows full item info (name, icon, affixes, dice,
# set info, requirements, sell value) with caller-defined action buttons.
#
# Usage:
#   popup.show_item(item, player, [
#       {"label": "Equip", "action": "equip"},
#       {"label": "Close", "action": "close"},
#   ])
extends Control

signal action_pressed(action: String, item)
signal popup_closed()

# ============================================================================
# CONFIG
# ============================================================================

@export var detail_icon_size: float = 160.0
@export var detail_container_size: float = 200.0

# ============================================================================
# STATE
# ============================================================================

var _item = null
var _player: Player = null
var _rarity_shader: Shader = null
var _active_die_tooltip = null

# ============================================================================
# UI REFERENCES
# ============================================================================

var _backdrop: ColorRect
var _panel: PanelContainer
var _item_name_label: Label
var _subtitle_label: Label
var _details_scroll: ScrollContainer
var _icon_center: CenterContainer
var _item_icon: TextureRect
var _description_label: RichTextLabel
var _affix_container: VBoxContainer
var _button_bar: HBoxContainer

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_rarity_shader = load("res://shaders/rarity_border.gdshader")
	_discover_nodes()
	_connect_signals()
	_update_panel_size()
	get_viewport().size_changed.connect(_update_panel_size)

func _discover_nodes() -> void:
	_backdrop = find_child("Backdrop", true, false) as ColorRect
	_panel = find_child("Panel", true, false) as PanelContainer
	_item_name_label = find_child("ItemNameLabel", true, false) as Label
	_subtitle_label = find_child("SubtitleLabel", true, false) as Label
	_details_scroll = find_child("DetailsScroll", true, false) as ScrollContainer
	_icon_center = find_child("IconCenter", true, false) as CenterContainer
	_item_icon = find_child("ItemIcon", true, false) as TextureRect
	_description_label = find_child("DescriptionLabel", true, false) as RichTextLabel
	_affix_container = find_child("AffixContainer", true, false) as VBoxContainer
	_button_bar = find_child("ButtonBar", true, false) as HBoxContainer

func _connect_signals() -> void:
	if _backdrop:
		_backdrop.gui_input.connect(_on_backdrop_input)

func _update_panel_size() -> void:
	if not _panel:
		return
	var vp = get_viewport().get_visible_rect().size
	var panel_h = int(vp.y * 0.85)
	var margin_v = int((vp.y - panel_h) / 2.0)
	var margin_h = 40
	_panel.offset_left = margin_h
	_panel.offset_top = margin_v
	_panel.offset_right = -margin_h
	_panel.offset_bottom = -margin_v

func _unhandled_input(event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()

# ============================================================================
# PUBLIC API
# ============================================================================

func show_item(item, player: Player, buttons: Array = []) -> void:
	_item = item
	_player = player
	_close_die_tooltip()
	_populate_details()
	_build_buttons(buttons)
	_update_panel_size()
	if _details_scroll:
		_details_scroll.scroll_vertical = 0
	show()
	# Defer auto-shrink until after layout passes so container widths are valid
	await get_tree().process_frame
	await get_tree().process_frame
	if _item_name_label:
		_auto_shrink_label(_item_name_label)
	if _subtitle_label and _subtitle_label.visible:
		_auto_shrink_label(_subtitle_label)

# ============================================================================
# BUTTON BAR
# ============================================================================

func _build_buttons(buttons: Array) -> void:
	if not _button_bar:
		return
	for child in _button_bar.get_children():
		child.queue_free()

	for def in buttons:
		var btn = Button.new()
		btn.text = def.get("label", "Action")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var action_name: String = def.get("action", "close")
		if action_name == "close":
			btn.pressed.connect(_on_close)
		else:
			btn.pressed.connect(_on_action.bind(action_name))
		_button_bar.add_child(btn)

func _on_action(action_name: String) -> void:
	action_pressed.emit(action_name, _item)

func _on_close() -> void:
	_close_die_tooltip()
	popup_closed.emit()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close()

# ============================================================================
# DETAIL DISPLAY
# ============================================================================

func _populate_details() -> void:
	if _item == null:
		return

	# ── 1. Item name (rarity colored) ──
	if _item_name_label:
		_item_name_label.theme_type_variation = &"itempopup_title"
		_item_name_label.text = _item_name(_item)
		var rarity_name = _item_rarity_name(_item)
		_item_name_label.add_theme_color_override("font_color", ThemeManager.get_rarity_color(rarity_name))

	# ── 2. Subtitle ──
	if _subtitle_label:
		_subtitle_label.theme_type_variation = &"itempopup_subtitle"
		if _item is EquippableItem:
			var slot_display = "Heavy Weapon" if _item.is_heavy_weapon() else _item.get_slot_name()
			var rarity_name = _item_rarity_name(_item)
			_subtitle_label.text = "Lv. %d · %s · %s" % [_item.item_level, slot_display, rarity_name]
			_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_subtitle_label.show()
		elif _item is ConsumableItem:
			var rarity_name = _item_rarity_name(_item)
			var tier_name = ConsumableItem.ConsumableTier.keys()[_item.tier].capitalize()
			_subtitle_label.text = "%s · %s" % [tier_name, rarity_name]
			_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_subtitle_label.show()
		else:
			_subtitle_label.text = ""
			_subtitle_label.hide()

	# ── 3. Item icon ──
	if _item_icon:
		_item_icon.custom_minimum_size = Vector2(detail_icon_size, detail_icon_size)
		if _icon_center:
			_icon_center.custom_minimum_size = Vector2(detail_container_size, detail_container_size)
		var icon_tex = _item_icon_tex(_item)
		if icon_tex:
			_item_icon.texture = icon_tex
		else:
			_item_icon.texture = null
		_apply_rarity_shader(_item_icon, _item)
		RarityGlowHelper.apply_glow(_item_icon, _item_icon.texture, _item_rarity_name(_item))

	# ── 4. Description ──
	if _description_label:
		_description_label.theme_type_variation = &"itempopup_description"
		DescriptionParser.set_bbcode(_description_label, _item_description(_item))

	# ── 5-13. Dynamic affix content ──
	if _affix_container:
		for child in _affix_container.get_children():
			child.queue_free()
		_build_affix_content(_affix_container)

func _build_affix_content(container: VBoxContainer) -> void:
	var equippable: EquippableItem = _item as EquippableItem if _item is EquippableItem else null
	if not equippable:
		return

	# ── 6. Dice Granted ──
	if _collect_all_granted_dice(equippable).size() > 0:
		_add_section_separator(container)
		var dice_section = _create_dice_granted_section(equippable)
		container.add_child(dice_section)

	# ── 7. Action Granted ──
	if equippable.grants_action and equippable.action:
		_add_section_separator(container)
		var action_label = DescriptionParser.make_rich_label(
			"Grants: %s" % equippable.action.action_name, Color(0.4, 0.8, 1.0))
		action_label.theme_type_variation = &"itempopup_action"
		container.add_child(action_label)
		if equippable.action.action_description and equippable.action.action_description != "":
			var action_desc = DescriptionParser.make_rich_label(
				equippable.action.action_description, ThemeManager.PALETTE.text_muted)
			action_desc.theme_type_variation = &"itempopup_action"
			container.add_child(action_desc)

	# ── 8. Base stat affixes (blue-white, one line) ──
	if equippable.base_affixes.size() > 0:
		_add_section_separator(container)
		var base_texts: Array[String] = []
		for affix in equippable.base_affixes:
			if affix:
				base_texts.append(affix.get_resolved_description())
		if not base_texts.is_empty():
			var lbl = DescriptionParser.make_rich_label(
				" | ".join(base_texts), Color(0.6, 0.75, 0.95))
			lbl.theme_type_variation = &"itempopup_affix_base"
			container.add_child(lbl)

	# ── 9. Inherent affixes (green) ──
	if equippable.inherent_affixes.size() > 0:
		for affix in equippable.inherent_affixes:
			if affix:
				var lbl = _create_affix_label(affix, Color(0.7, 0.9, 0.7))
				lbl.theme_type_variation = &"itempopup_affix_inherent"
				container.add_child(lbl)

	# ── 10. Rolled affixes (gold) / legendary unique (special) ──
	if equippable.rolled_affixes.size() > 0:
		_add_section_separator(container)
		var is_legendary = equippable.rarity == EquippableItem.Rarity.LEGENDARY
		var unique_name = equippable.unique_affix.affix_name if is_legendary and equippable.unique_affix else ""
		for affix in equippable.rolled_affixes:
			if not affix:
				continue
			if is_legendary and unique_name != "" and affix.affix_name == unique_name:
				# Legendary unique: "Name — Description" inline
				# Name color from itempopup_legendaryaffixname, desc from itempopup_affix_rolled
				var name_color = _get_theme_color(&"itempopup_legendaryaffixname")
				var desc_text = affix.get_resolved_description()
				var lbl = DescriptionParser.make_rich_label(
					"[color=#%s]%s[/color] — %s" % [name_color.to_html(false), affix.affix_name, desc_text])
				lbl.theme_type_variation = &"itempopup_affix_rolled"
				container.add_child(lbl)
			else:
				var lbl = _create_affix_label(affix, Color(0.9, 0.7, 0.3))
				lbl.theme_type_variation = &"itempopup_affix_rolled"
				container.add_child(lbl)

	# ── 11. Set info ──
	var set_def: SetDefinition = equippable.set_definition if equippable.set_definition else null
	if set_def:
		_add_section_separator(container)
		var equipped_count: int = 0
		if _player and _player.set_tracker:
			var set_info = _player.set_tracker.get_set_info(set_def.set_id)
			equipped_count = set_info.get("count", 0)
		var set_header = DescriptionParser.make_rich_label(
			"%s (%d/%d)" % [set_def.set_name, equipped_count, set_def.get_total_pieces()],
			set_def.set_color)
		set_header.theme_type_variation = &"itempopup_set_header"
		container.add_child(set_header)
		for threshold in set_def.thresholds:
			var is_active = _player and _player.set_tracker and _player.set_tracker.is_threshold_active(set_def.set_id, threshold.required_pieces)
			var prefix = "✓" if is_active else "✗"
			var threshold_label = DescriptionParser.make_rich_label(
				"  %s (%d) %s" % [prefix, threshold.required_pieces, threshold.description],
				ThemeManager.PALETTE.success if is_active else ThemeManager.PALETTE.locked)
			threshold_label.theme_type_variation = &"itempopup_set_threshold"
			container.add_child(threshold_label)

	# ── 12. Flavor text (red, centered) ──
	if equippable.flavor_text and equippable.flavor_text != "":
		_add_section_separator(container)
		var flavor = DescriptionParser.make_rich_label(
			"[center]%s[/center]" % equippable.flavor_text,
			Color(0.85, 0.2, 0.2))
		flavor.theme_type_variation = &"itempopup_flavor"
		container.add_child(flavor)

	# ── 13. Requirements + Sell value ──
	_add_section_separator(container)
	var bottom_row = HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Left: requirements
	var req_vbox = VBoxContainer.new()
	req_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if equippable.has_requirements():
		var all_reqs = []
		if equippable.required_level > 0:
			all_reqs.append(["Level %d" % equippable.required_level,
				_player and _player.level >= equippable.required_level])
		if equippable.required_strength > 0:
			all_reqs.append(["%d Strength" % equippable.required_strength,
				_player and _player.get_total_stat("strength") >= equippable.required_strength])
		if equippable.required_agility > 0:
			all_reqs.append(["%d Agility" % equippable.required_agility,
				_player and _player.get_total_stat("agility") >= equippable.required_agility])
		if equippable.required_intellect > 0:
			all_reqs.append(["%d Intellect" % equippable.required_intellect,
				_player and _player.get_total_stat("intellect") >= equippable.required_intellect])
		for req in all_reqs:
			var req_label = Label.new()
			req_label.theme_type_variation = &"itempopup_requirement"
			req_label.text = "Requires %s" % req[0]
			req_label.add_theme_color_override("font_color",
				ThemeManager.PALETTE.success if req[1] else ThemeManager.PALETTE.danger)
			req_vbox.add_child(req_label)
	bottom_row.add_child(req_vbox)

	# Right: sell value
	var sell_hbox = HBoxContainer.new()
	sell_hbox.alignment = BoxContainer.ALIGNMENT_END
	var coin_icon = TextureRect.new()
	coin_icon.texture = load("res://assets/icons/coins_icon.png")
	coin_icon.custom_minimum_size = Vector2(20, 20)
	coin_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.modulate = ThemeManager.PALETTE.warning
	sell_hbox.add_child(coin_icon)
	var sell_amount = Label.new()
	sell_amount.theme_type_variation = &"itempopup_sellvalue"
	sell_amount.text = " %d" % equippable.get_sell_value()
	sell_amount.add_theme_color_override("font_color", ThemeManager.PALETTE.warning)
	sell_hbox.add_child(sell_amount)
	bottom_row.add_child(sell_hbox)
	container.add_child(bottom_row)

# ============================================================================
# ITEM TYPE HELPERS
# ============================================================================

func _item_name(item) -> String:
	if item is EquippableItem: return item.item_name
	if item is ConsumableItem: return item.item_name
	return "Unknown"

func _item_icon_tex(item) -> Texture2D:
	if item is EquippableItem: return item.icon
	if item is ConsumableItem: return item.icon
	return null

func _item_rarity_name(item) -> String:
	if item is EquippableItem: return item.get_rarity_name()
	if item is ConsumableItem: return item.get_rarity_name()
	return "Common"

func _item_description(item) -> String:
	if item is EquippableItem: return item.description
	if item is ConsumableItem: return item.description
	return ""

# ============================================================================
# DISPLAY HELPERS
# ============================================================================

func _apply_rarity_shader(tex_rect: TextureRect, item) -> void:
	if not _rarity_shader:
		tex_rect.material = null
		return
	var rarity_name = _item_rarity_name(item)
	var color = ThemeManager.get_rarity_color(rarity_name)
	var mat = ShaderMaterial.new()
	mat.shader = _rarity_shader
	mat.set_shader_parameter("border_color", color)
	mat.set_shader_parameter("glow_radius", 4.0)
	mat.set_shader_parameter("glow_softness", 2.0)
	mat.set_shader_parameter("glow_width", 0.6)
	mat.set_shader_parameter("glow_strength", 1.5)
	mat.set_shader_parameter("glow_blend", 0.6)
	mat.set_shader_parameter("glow_saturation", 1.0)
	mat.set_shader_parameter("pulse_speed", 1.0)
	mat.set_shader_parameter("pulse_amount", 0.15)
	tex_rect.material = mat

func _create_affix_label(affix: Affix, color: Color = Color(0.9, 0.7, 0.3)) -> RichTextLabel:
	return DescriptionParser.make_rich_label(affix.get_resolved_description(), color)

func _get_theme_color(type_variation: StringName, color_name: StringName = &"default_color") -> Color:
	## Look up a color from a theme type variation. Falls back to white.
	if has_theme_color(color_name, type_variation):
		return get_theme_color(color_name, type_variation)
	return Color.WHITE

func _add_section_separator(container: VBoxContainer) -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	var line_style = StyleBoxLine.new()
	line_style.color = Color(1, 1, 1, 0.1)
	line_style.thickness = 1
	sep.add_theme_stylebox_override("separator", line_style)
	container.add_child(sep)

func _create_element_row(equippable: EquippableItem) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var elem_id = equippable.get_elemental_identity()
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if elem_id >= 0 and GameManager and GameManager.ELEMENT_VISUALS:
		var elem_icon = GameManager.ELEMENT_VISUALS.get_icon(elem_id)
		if elem_icon:
			icon_rect.texture = elem_icon
			icon_rect.modulate = GameManager.ELEMENT_VISUALS.get_tint_color(elem_id)
		row.add_child(icon_rect)
		var elem_label = Label.new()
		elem_label.theme_type_variation = &"itempopup_element"
		var elem_name = ActionEffect.DamageType.keys()[elem_id].capitalize() if elem_id < ActionEffect.DamageType.size() else "Unknown"
		elem_label.text = elem_name
		elem_label.add_theme_color_override("font_color", GameManager.ELEMENT_VISUALS.get_tint_color(elem_id))
		row.add_child(elem_label)
	else:
		icon_rect.modulate = Color(1, 1, 1, 0)
		row.add_child(icon_rect)
	return row

func _create_dice_granted_section(equippable: EquippableItem) -> VBoxContainer:
	var all_dice := _collect_all_granted_dice(equippable)
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	var header = Label.new()
	header.theme_type_variation = &"itempopup_dice_header"
	header.text = "Adds Dice:"
	section.add_child(header)
	var dice_row = HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 8)
	for die_res in all_dice:
		var die_visual = die_res.instantiate_pool_visual()
		if die_visual:
			var preview_size := Vector2(60, 60)
			var die_btn := Button.new()
			die_btn.flat = true
			die_btn.custom_minimum_size = preview_size
			die_btn.clip_contents = true
			die_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			die_btn.pressed.connect(_on_granted_die_pressed.bind(die_btn, die_res))
			dice_row.add_child(die_btn)
			die_btn.add_child(die_visual)
			var die_scale: float = preview_size.x / die_visual.base_size.x
			_lock_die_preview.call_deferred(die_visual, die_scale)
		else:
			var fallback := Button.new()
			fallback.flat = true
			var elem_name = die_res.get_element_name() if die_res.has_element() else ""
			fallback.text = "%s D%d" % [elem_name, die_res.die_type] if elem_name else "D%d" % die_res.die_type
			fallback.add_theme_color_override("font_color", ThemeManager.PALETTE.text_muted)
			fallback.pressed.connect(_on_granted_die_pressed.bind(fallback, die_res))
			dice_row.add_child(fallback)
	section.add_child(dice_row)
	return section

func _collect_all_granted_dice(equippable: EquippableItem) -> Array[DieResource]:
	var dice: Array[DieResource] = []
	for die in equippable.grants_dice:
		if die:
			dice.append(die)
	for affix in equippable.item_affixes:
		if affix is Affix and affix.category == Affix.Category.DICE:
			for die in affix.granted_dice:
				if die:
					dice.append(die)
	return dice

func _auto_shrink_label(label: Label, min_size: int = 10) -> void:
	label.remove_theme_font_size_override("font_size")
	var container_width: float = label.get_parent().size.x if label.get_parent() else label.size.x
	if container_width <= 0.0:
		return
	var font := label.get_theme_font("font")
	var base_size: int = label.get_theme_font_size("font_size")
	var current_size := base_size
	while current_size > min_size:
		var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, current_size).x
		if text_width <= container_width:
			break
		current_size -= 1
	if current_size < base_size:
		label.add_theme_font_size_override("font_size", current_size)

func _lock_die_preview(die_visual, die_scale: float) -> void:
	if not is_instance_valid(die_visual):
		return
	die_visual.draggable = false
	die_visual.pivot_offset = Vector2.ZERO
	die_visual.scale = Vector2(die_scale, die_scale)
	die_visual.custom_minimum_size = Vector2.ZERO
	die_visual.size = die_visual.base_size
	die_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	die_visual.set_process(false)
	for child in die_visual.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var val_label = die_visual.find_child("ValueLabel", true, false)
	if val_label:
		val_label.hide()

func _on_granted_die_pressed(source: Control, die_res: DieResource) -> void:
	if _active_die_tooltip and is_instance_valid(_active_die_tooltip):
		var is_same = _active_die_tooltip.is_for_source(source)
		_close_die_tooltip()
		if is_same:
			return
	var anchor_pos = source.get_screen_position() + source.size / 2.0
	_active_die_tooltip = DieTooltipPopup.show_die(die_res, anchor_pos, get_tree().root, source)
	_active_die_tooltip.dismissed.connect(_on_die_tooltip_dismissed)

func _on_die_tooltip_dismissed() -> void:
	_active_die_tooltip = null

func _close_die_tooltip() -> void:
	if _active_die_tooltip and is_instance_valid(_active_die_tooltip):
		_active_die_tooltip.dismiss()
	_active_die_tooltip = null
