# res://scripts/ui/popups/companion_info_popup.gd
# Companion detail popup. Shows name, portrait, description, action description,
# and HP bar. Mirrors the item_info_popup pattern.
extends Control

signal action_pressed(action: String, companion_instance)
signal popup_closed()

# ============================================================================
# STATE
# ============================================================================

var _instance = null
var _player: Player = null

# ============================================================================
# UI REFERENCES
# ============================================================================

var _backdrop: ColorRect
var _panel: PanelContainer
var _companion_name_label: Label
var _details_scroll: ScrollContainer
var _portrait_center: CenterContainer
var _portrait: TextureRect
var _description_label: RichTextLabel
var _action_desc_label: RichTextLabel
var _relationship_label: RichTextLabel
var _synergy_label: RichTextLabel
var _hp_bar  # resource_bar component
var _button_bar: HBoxContainer

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_discover_nodes()
	_connect_signals()
	_update_panel_size()
	get_viewport().size_changed.connect(_update_panel_size)

func _discover_nodes() -> void:
	_backdrop = find_child("Backdrop", true, false) as ColorRect
	_panel = find_child("Panel", true, false) as PanelContainer
	_companion_name_label = find_child("CompanionNameLabel", true, false) as Label
	_details_scroll = find_child("DetailsScroll", true, false) as ScrollContainer
	_portrait_center = find_child("PortraitCenter", true, false) as CenterContainer
	_portrait = find_child("Portrait", true, false) as TextureRect
	_description_label = find_child("DescriptionLabel", true, false) as RichTextLabel
	_action_desc_label = find_child("ActionDescLabel", true, false) as RichTextLabel
	_relationship_label = find_child("RelationshipLabel", true, false) as RichTextLabel
	_synergy_label = find_child("SynergyLabel", true, false) as RichTextLabel
	_hp_bar = find_child("HPBar", true, false)
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

func show_companion(instance, player: Player, buttons: Array = []) -> void:
	_instance = instance
	_player = player
	_populate_details()
	_build_buttons(buttons)
	_update_panel_size()
	if _details_scroll:
		_details_scroll.scroll_vertical = 0
	show()

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
	action_pressed.emit(action_name, _instance)

func _on_close() -> void:
	popup_closed.emit()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close()

# ============================================================================
# DETAIL DISPLAY
# ============================================================================

func _populate_details() -> void:
	if _instance == null or _instance.companion_data == null:
		return

	var data: CompanionData = _instance.companion_data

	# Name
	if _companion_name_label:
		_companion_name_label.theme_type_variation = &"itempopup_title"
		_companion_name_label.text = data.companion_name

	# Portrait
	if _portrait:
		_portrait.custom_minimum_size = Vector2(160, 160)
		if _portrait_center:
			_portrait_center.custom_minimum_size = Vector2(200, 200)
		if data.portrait:
			_portrait.texture = data.portrait
		else:
			_portrait.texture = null

	# Description
	if _description_label:
		if data.description != "":
			var desc_color = ThemeManager.PALETTE.text_secondary.to_html(false)
			DescriptionParser.set_bbcode(_description_label, "[center][color=#%s]%s[/color][/center]" % [desc_color, data.description])
			_description_label.visible = true
		else:
			_description_label.visible = false

	# Action description
	if _action_desc_label:
		var has_action = data.action_name != "" or data.action_description != ""
		if has_action:
			# Only the action name gets the action color; description uses default label styling
			var action_color = ThemeManager.PALETTE.get("info", Color(0.4, 0.8, 1.0)).to_html(false)
			var action_text := ""
			if data.action_name != "" and data.action_description != "":
				action_text = "[color=#%s]%s[/color]: %s" % [action_color, data.action_name, data.action_description]
			elif data.action_name != "":
				action_text = "[color=#%s]%s[/color]" % [action_color, data.action_name]
			else:
				action_text = data.action_description
			_action_desc_label.remove_theme_color_override("default_color")
			DescriptionParser.set_bbcode(_action_desc_label, "[center]%s[/center]" % action_text)
			_action_desc_label.visible = true
		else:
			_action_desc_label.visible = false

	# HP bar
	if _hp_bar and _player:
		var max_hp = _instance.get_max_hp(_player.max_hp, _player.level)
		_hp_bar.set_values("HP", _instance.current_hp, max_hp,
			ThemeManager.PALETTE.health, ThemeManager.PALETTE.health_low)

	# Relationship
	if _relationship_label:
		var comp_id = data.companion_id
		if comp_id != &"":
			var value = GameState.get_relationship(comp_id)
			var state = GameState.relationships.get_state(comp_id)
			var state_name = GameState.relationships.get_state_name(comp_id)
			var color = ThemeManager.get_relationship_color(state).to_html(false)
			DescriptionParser.set_bbcode(_relationship_label,
				"[center][color=#%s]%s[/color]  (%d/100)[/center]" % [color, state_name, value])
			_relationship_label.visible = true
		else:
			_relationship_label.visible = false

	# Synergies
	if _synergy_label:
		var synergy_text = _build_synergy_text(data)
		if synergy_text != "":
			DescriptionParser.set_bbcode(_synergy_label, synergy_text)
			_synergy_label.visible = true
		else:
			_synergy_label.visible = false


func _build_synergy_text(data: CompanionData) -> String:
	if not Engine.has_singleton("CompanionSynergyManager") and not has_node("/root/CompanionSynergyManager"):
		# Autoload not registered yet — try direct access
		var manager = get_node_or_null("/root/CompanionSynergyManager")
		if not manager:
			return ""
	else:
		pass

	var manager = get_node_or_null("/root/CompanionSynergyManager")
	if not manager or not manager.has_method("get_synergies_for_companion"):
		return ""

	var synergies = manager.get_synergies_for_companion(data)
	if synergies.is_empty():
		return ""

	var lines := []
	var synergy_color = ThemeManager.PALETTE.get("accent", Color(0.4, 0.8, 1.0)).to_html(false)
	for syn in synergies:
		var active = manager.is_synergy_active(syn.synergy_id)
		var status_text = "[color=#%s]%s[/color]" % [synergy_color, syn.synergy_name] if active else "[color=#808080]%s[/color]" % syn.synergy_name
		var desc_part = ": %s" % syn.description if syn.description != "" else ""
		var active_marker = " [Active]" if active else " [Inactive]"
		lines.append("[center]%s%s%s[/center]" % [status_text, desc_part, active_marker])

	return "\n".join(lines)
