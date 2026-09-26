# companions_tab.gd - Companions tab showing active and camp companions
extends Control

# ============================================================================
# SIGNALS
# ============================================================================
signal refresh_requested()
signal data_changed()

# ============================================================================
# CONSTANTS
# ============================================================================
const CompanionCardScene = preload("res://scenes/ui/components/character/companion_card.tscn")
const CompanionInfoPopupScene = preload("res://scenes/ui/popups/companion_info_popup.tscn")

# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var _active_popup: Control = null

# UI references (discovered via groups + metadata)
var active_slot_1 = null
var active_slot_2 = null
var _active_btn_1: Button = null
var _active_btn_2: Button = null
var no_active_label: Label = null
var camp_container: VBoxContainer = null
var no_camp_label: Label = null
var _camp_card_cache := {}  # companion_id → {card, button} dict

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	add_to_group("menu_tabs")
	_discover_ui_elements()

func _discover_ui_elements():
	await get_tree().process_frame

	var ui_nodes = find_children("*", "", true, false)
	for node in ui_nodes:
		if not node.is_in_group("companions_tab_ui"):
			continue
		var role = node.get_meta("ui_role", "")
		match role:
			"active_slot_1":
				active_slot_1 = node
			"active_slot_2":
				active_slot_2 = node
			"no_active_label": no_active_label = node
			"camp_container": camp_container = node
			"no_camp_label": no_camp_label = node

	# Create click buttons overlaying active slots
	_active_btn_1 = _wrap_card_with_button(active_slot_1)
	_active_btn_2 = _wrap_card_with_button(active_slot_2)

func _wrap_card_with_button(card) -> Button:
	## Wraps a companion_card in a Control container with a flat Button overlay.
	## The card keeps its layout slot; the Button sits on top and catches clicks.
	if not card:
		return null
	var parent = card.get_parent()
	var idx = card.get_index()
	# Create wrapper Control to hold both card and button
	var wrapper = Control.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Reparent card into wrapper
	parent.remove_child(card)
	wrapper.add_child(card)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add wrapper where card was
	parent.add_child(wrapper)
	parent.move_child(wrapper, idx)
	# Create overlay button
	var btn = Button.new()
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(btn)
	btn.pressed.connect(_on_card_button_pressed.bind(card))
	# Sync wrapper minimum size with card
	wrapper.custom_minimum_size = card.custom_minimum_size
	card.resized.connect(func(): wrapper.custom_minimum_size = card.size)
	return btn

# ============================================================================
# PUBLIC API
# ============================================================================

func set_player(p_player: Player):
	player = p_player
	refresh()

func refresh():
	if not player:
		return
	_update_active_companions()
	_update_camp_companions()

func on_external_data_change():
	refresh()

func has_active_popup() -> bool:
	return _active_popup != null and is_instance_valid(_active_popup) and _active_popup.visible

# ============================================================================
# ACTIVE COMPANIONS
# ============================================================================

func _update_active_companions():
	var active = player.active_companions if player.active_companions else []
	var count = active.size()

	if active_slot_1:
		if count >= 1:
			active_slot_1.set_companion(active[0], player.max_hp, player.level)
			if active_slot_1.get_parent():
				active_slot_1.get_parent().visible = true
		else:
			active_slot_1.clear()

	if active_slot_2:
		if count >= 2:
			active_slot_2.set_companion(active[1], player.max_hp, player.level)
			if active_slot_2.get_parent():
				active_slot_2.get_parent().visible = true
		else:
			active_slot_2.clear()

	if no_active_label:
		no_active_label.visible = count == 0

# ============================================================================
# CAMP COMPANIONS
# ============================================================================

func _update_camp_companions():
	if not camp_container:
		return

	var active = player.active_companions if player.active_companions else []
	var roster = player.companion_roster if player.companion_roster else []

	# Camp = roster minus active (compare by instance identity, not companion_id)
	var camp: Array = []
	for inst in roster:
		if inst and inst.companion_data and inst not in active:
			camp.append(inst)

	# Remove entries for companions no longer in camp
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
			# Create wrapper + overlay button
			var wrapper = Control.new()
			wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wrapper.add_child(card)
			card.set_anchors_preset(Control.PRESET_FULL_RECT)
			var btn = Button.new()
			btn.flat = true
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			wrapper.add_child(btn)
			btn.pressed.connect(_on_card_button_pressed.bind(card))
			card.resized.connect(func(): wrapper.custom_minimum_size = card.size)
			camp_container.add_child(wrapper)
			entry = {card = card, wrapper = wrapper}
			_camp_card_cache[comp_id] = entry
			await get_tree().process_frame

		entry.card.set_companion(inst, player.max_hp, player.level)

	if no_camp_label:
		no_camp_label.visible = camp.is_empty()

# ============================================================================
# POPUP
# ============================================================================

func _on_card_button_pressed(card):
	var instance = card.get_instance()
	if not instance:
		return
	_show_companion_popup(instance)

func _show_companion_popup(instance):
	_close_popup()

	var buttons := [{"label": "Close", "action": "close"}]

	_active_popup = CompanionInfoPopupScene.instantiate()
	add_child(_active_popup)
	_active_popup.popup_closed.connect(_on_popup_closed)
	_active_popup.show_companion(instance, player, buttons)

func _on_popup_closed():
	_close_popup()

func _close_popup():
	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null
