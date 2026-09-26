# res://scripts/ui/popups/party_management_popup.gd
# Full-screen party management popup opened from the map radial menu.
# Mirrors companions_tab layout but adds activate/deactivate/swap actions.
extends Control

signal party_closed()

# ============================================================================
# CONSTANTS
# ============================================================================
const CompanionCardScene = preload("res://scenes/ui/components/character/companion_card.tscn")
const CompanionInfoPopupScene = preload("res://scenes/ui/popups/companion_info_popup.tscn")

# ============================================================================
# STATE
# ============================================================================
var _player: Player = null
var _active_popup: Control = null

# UI references (discovered via group + metadata)
var _active_slot_1 = null
var _active_slot_2 = null
var _active_btn_1: Button = null
var _active_btn_2: Button = null
var _no_active_label: Label = null
var _camp_container: VBoxContainer = null
var _no_camp_label: Label = null
var _camp_card_cache := {}  # companion_id → {card, wrapper}

# Scene nodes
var _backdrop: ColorRect = null
var _panel: PanelContainer = null
var _title_label: Label = null
var _close_button: Button = null

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
	_title_label = find_child("TitleLabel", true, false) as Label
	_close_button = find_child("CloseButton", true, false) as Button

	for node in find_children("*", "", true, false):
		if not node.is_in_group("party_popup_ui"):
			continue
		var role = node.get_meta("ui_role", "")
		match role:
			"active_slot_1": _active_slot_1 = node
			"active_slot_2": _active_slot_2 = node
			"no_active_label": _no_active_label = node
			"camp_container": _camp_container = node
			"no_camp_label": _no_camp_label = node

	_active_btn_1 = _wrap_card_with_button(_active_slot_1)
	_active_btn_2 = _wrap_card_with_button(_active_slot_2)

func _connect_signals() -> void:
	if _backdrop:
		_backdrop.gui_input.connect(_on_backdrop_input)
	if _close_button:
		_close_button.pressed.connect(_on_close)

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
# CARD WRAPPING (mirrors companions_tab pattern)
# ============================================================================

func _wrap_card_with_button(card) -> Button:
	if not card:
		return null
	var parent = card.get_parent()
	var idx = card.get_index()
	var wrapper = Control.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.remove_child(card)
	wrapper.add_child(card)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(wrapper)
	parent.move_child(wrapper, idx)
	var btn = Button.new()
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(btn)
	btn.pressed.connect(_on_active_card_pressed.bind(card))
	wrapper.custom_minimum_size = card.custom_minimum_size
	card.resized.connect(func(): wrapper.custom_minimum_size = card.size)
	return btn

# ============================================================================
# PUBLIC API
# ============================================================================

func show_party(player: Player) -> void:
	_player = player
	if _title_label:
		_title_label.theme_type_variation = &"itempopup_title"
	_refresh()
	_update_panel_size()
	show()

# ============================================================================
# REFRESH
# ============================================================================

func _refresh() -> void:
	if not _player:
		return
	_update_active_companions()
	_update_camp_companions()

func _update_active_companions() -> void:
	var active = _player.active_companions if _player.active_companions else []
	var count = active.size()

	if _active_slot_1:
		if count >= 1:
			_active_slot_1.set_companion(active[0], _player.max_hp, _player.level)
			if _active_slot_1.get_parent():
				_active_slot_1.get_parent().visible = true
		else:
			_active_slot_1.clear()
			if _active_slot_1.get_parent():
				_active_slot_1.get_parent().visible = false

	if _active_slot_2:
		if count >= 2:
			_active_slot_2.set_companion(active[1], _player.max_hp, _player.level)
			if _active_slot_2.get_parent():
				_active_slot_2.get_parent().visible = true
		else:
			_active_slot_2.clear()
			if _active_slot_2.get_parent():
				_active_slot_2.get_parent().visible = false

	if _no_active_label:
		_no_active_label.visible = count == 0

func _update_camp_companions() -> void:
	if not _camp_container:
		return

	var active = _player.active_companions if _player.active_companions else []
	var roster = _player.companion_roster if _player.companion_roster else []

	# Camp = roster minus active (compare by instance identity, not companion_id)
	var camp: Array = []
	for inst in roster:
		if inst and inst.companion_data and inst not in active:
			camp.append(inst)

	# Remove stale cache entries
	var camp_keys := {}
	for inst in camp:
		camp_keys[inst.get_instance_id()] = true
	for cache_key in _camp_card_cache.keys():
		if not camp_keys.has(cache_key):
			_camp_card_cache[cache_key].wrapper.queue_free()
			_camp_card_cache.erase(cache_key)

	# Add or update cards
	for inst in camp:
		var comp_id = inst.get_instance_id()
		var entry = _camp_card_cache.get(comp_id)
		if not entry:
			var card = CompanionCardScene.instantiate()
			var wrapper = Control.new()
			wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wrapper.add_child(card)
			card.set_anchors_preset(Control.PRESET_FULL_RECT)
			var btn = Button.new()
			btn.flat = true
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			wrapper.add_child(btn)
			btn.pressed.connect(_on_camp_card_pressed.bind(card))
			card.resized.connect(func(): wrapper.custom_minimum_size = card.size)
			_camp_container.add_child(wrapper)
			entry = {card = card, wrapper = wrapper}
			_camp_card_cache[comp_id] = entry
			await get_tree().process_frame

		entry.card.set_companion(inst, _player.max_hp, _player.level)

	if _no_camp_label:
		_no_camp_label.visible = camp.is_empty()

# ============================================================================
# CLICK HANDLERS
# ============================================================================

func _on_active_card_pressed(card) -> void:
	var instance = card.get_instance()
	if not instance:
		return
	_show_companion_popup(instance, true)

func _on_camp_card_pressed(card) -> void:
	var instance = card.get_instance()
	if not instance:
		return
	_show_companion_popup(instance, false)

# ============================================================================
# COMPANION INFO POPUP (with management actions)
# ============================================================================

func _show_companion_popup(instance, is_active: bool) -> void:
	_close_info_popup()

	var buttons := []

	if is_active:
		buttons.append({"label": "Deactivate", "action": "deactivate"})
	elif instance.is_dead:
		pass  # a downed companion can't join the party until they're back up (Gap 80)
	else:
		var active_count = _player.active_companions.size() if _player.active_companions else 0
		if active_count < 2:
			buttons.append({"label": "Activate", "action": "activate"})
		else:
			var name_1 = _player.active_companions[0].get_display_name() if _player.active_companions[0] else "Slot 1"
			var name_2 = _player.active_companions[1].get_display_name() if _player.active_companions[1] else "Slot 2"
			buttons.append({"label": "Replace %s" % name_1, "action": "swap_0"})
			buttons.append({"label": "Replace %s" % name_2, "action": "swap_1"})

	buttons.append({"label": "Close", "action": "close"})

	_active_popup = CompanionInfoPopupScene.instantiate()
	add_child(_active_popup)
	_active_popup.popup_closed.connect(_on_info_popup_closed)
	_active_popup.action_pressed.connect(_on_info_action)
	_active_popup.show_companion(instance, _player, buttons)

func _on_info_action(action: String, instance) -> void:
	match action:
		"deactivate":
			_do_deactivate(instance)
		"activate":
			_do_activate(instance)
		"swap_0":
			_do_swap(instance, 0)
		"swap_1":
			_do_swap(instance, 1)
	_close_info_popup()
	_refresh()
	CompanionSynergyManager.recalculate(_player)

func _on_info_popup_closed() -> void:
	_close_info_popup()

func _close_info_popup() -> void:
	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null

# ============================================================================
# COMPANION MANAGEMENT
# ============================================================================

func _do_deactivate(instance) -> void:
	if not _player.active_companions:
		return
	var idx = _player.active_companions.find(instance)
	if idx >= 0:
		_player.active_companions.remove_at(idx)

func _do_activate(instance) -> void:
	if not _player.active_companions:
		_player.active_companions = []
	if _player.active_companions.size() >= 2 or instance.is_dead:
		return
	# Ensure not already active
	if instance in _player.active_companions:
		return
	_player.active_companions.append(instance)

func _do_swap(camp_instance, slot_index: int) -> void:
	if not _player.active_companions or slot_index >= _player.active_companions.size():
		return
	if camp_instance.is_dead:
		return
	# Remove the active companion from slot (stays in roster)
	_player.active_companions[slot_index] = camp_instance

# ============================================================================
# CLOSE
# ============================================================================

func _on_close() -> void:
	party_closed.emit()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Don't close if an info popup is open
		if _active_popup and is_instance_valid(_active_popup):
			return
		_on_close()
