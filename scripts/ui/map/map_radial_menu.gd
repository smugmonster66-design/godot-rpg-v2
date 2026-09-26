# res://scripts/ui/map/map_radial_menu.gd
# Radial action menu that appears when a MapNodeButton is pressed.
# Supports sub-radials via a stack (for NPCs, Party, etc.).
extends Control

signal action_completed()                       # Emitted when a non-navigational action finishes
signal radial_closed()                          # Emitted when the radial is dismissed
signal travel_requested(location: LocationNode) # Emitted when Travel is confirmed
signal zone_entered(map_def: MapDefinition)     # Emitted when Enter Zone is pressed

const MapRadialButton = preload("res://scenes/ui/map/map_radial_button.tscn")

## How far buttons are placed from the node center (pixels). Set on the scene instance.
@export var radial_radius: float = 280.0

const MIN_BUTTON_SIZE := 160.0

@onready var _dimmer: ColorRect = $Dimmer
@onready var _radial_container: Control = $RadialContainer
@onready var _back_button: Button = $RadialContainer/BackButton

var _current_location: LocationNode = null
var _player = null
var _game_root = null

# Stack of {buttons: Array[MapNodeButtonDef], title: String}
var _radial_stack: Array = []

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	visible = false
	_dimmer.gui_input.connect(_on_dimmer_input)
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.visible = false

# ============================================================================
# PUBLIC API
# ============================================================================

func show_for_node(location: LocationNode, screen_pos: Vector2, player, game_root) -> void:
	_current_location = location
	_player = player
	_game_root = game_root
	_radial_stack.clear()

	# Build button list.
	# At the current node: show all configured actions.
	# At another node: show travel button if reachable via any path (multi-hop).
	var is_at_node = GameState.map.current_location == location.location_id
	var all_buttons: Array = []
	if is_at_node:
		all_buttons.append_array(location.radial_buttons)
	else:
		if MapManager.can_reach(location.location_id):
			var travel_def = MapNodeButtonDef.new()
			travel_def.button_category = MapNodeButtonDef.ButtonCategory.TRAVEL
			all_buttons.append(travel_def)

	# Early exit — don't open the radial if nothing will actually show
	var has_visible = false
	for bd in all_buttons:
		var b = bd as MapNodeButtonDef
		if b == null:
			continue
		if b.hide_when_condition_fails and not b.is_condition_met(player):
			continue
		has_visible = true
		break
	if not has_visible:
		return

	visible = true
	_push_radial(all_buttons, location.get_display_name())
	_position_radial(screen_pos)

func hide_radial() -> void:
	visible = false
	_clear_buttons()
	_radial_stack.clear()
	radial_closed.emit()

func push_sub_radial(buttons: Array, title: String) -> void:
	_push_radial(buttons, title)

# ============================================================================
# INTERNAL
# ============================================================================

func _push_radial(buttons: Array, title: String) -> void:
	_radial_stack.push_back({"buttons": buttons, "title": title})
	_rebuild_radial()

func _pop_radial() -> void:
	if _radial_stack.size() > 1:
		_radial_stack.pop_back()
		_rebuild_radial()
	else:
		hide_radial()

func _rebuild_radial() -> void:
	_clear_buttons()
	if _radial_stack.is_empty():
		return

	var current = _radial_stack.back()
	_back_button.visible = _radial_stack.size() > 1

	var button_defs: Array = current["buttons"]
	# Filter out hidden buttons before computing layout
	var visible_defs: Array = []
	for bd in button_defs:
		var b = bd as MapNodeButtonDef
		if b == null:
			continue
		if b.hide_when_condition_fails and not b.is_condition_met(_player):
			continue
		visible_defs.append(b)

	if visible_defs.is_empty():
		return

	var count = visible_defs.size()

	# Stagger tween — all buttons animate in parallel, each slightly delayed
	var tween = create_tween()
	tween.set_parallel(true)

	for i in count:
		var bd = visible_defs[i] as MapNodeButtonDef
		var btn = MapRadialButton.instantiate()
		_radial_container.add_child(btn)
		btn.setup(bd, _player)
		btn.action_requested.connect(_on_button_action)

		# New content / quest indicator for NPC buttons
		_update_new_content_indicator(btn, bd)
		_update_quest_indicator(btn, bd)

		# Circular layout: distribute evenly starting from top
		var angle = (TAU / count) * i - PI * 0.5
		var offset = Vector2(cos(angle), sin(angle)) * radial_radius
		var half_size = btn.button_size * 0.5
		btn.pivot_offset = half_size
		btn.position = offset - half_size

		# Pop-out animation: scale 0 → 1 with staggered delay
		btn.scale = Vector2.ZERO
		tween.tween_property(btn, "scale", Vector2.ONE, 0.22) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_BACK) \
			.set_delay(i * 0.06)

func _clear_buttons() -> void:
	for child in _radial_container.get_children():
		if child != _back_button:
			child.queue_free()

func _update_new_content_indicator(btn, bd: MapNodeButtonDef) -> void:
	if bd.button_category != MapNodeButtonDef.ButtonCategory.NPCS:
		return
	if not btn.has_method("set_new_content_visible"):
		return
	if bd.npc_id != &"":
		# Specific NPC button — check this NPC
		var npc = NPCManager.get_npc(bd.npc_id)
		if npc and NPCManager.has_new_content(npc):
			btn.set_new_content_visible(true)
	elif _current_location:
		# Generic NPCS button — check if any NPC at this location has new content
		if NPCManager.location_has_new_npc_content(_current_location.location_id):
			btn.set_new_content_visible(true)

func _update_quest_indicator(btn, bd: MapNodeButtonDef) -> void:
	"""Show quest badge on NPC buttons that have available or turn-in quests."""
	if bd.button_category != MapNodeButtonDef.ButtonCategory.NPCS:
		return
	if bd.npc_id == &"":
		return
	if not QuestManager.npc_has_quest_indicator(bd.npc_id):
		return
	# Show the new content indicator (reuses existing badge)
	if btn.has_method("set_new_content_visible"):
		btn.set_new_content_visible(true)

func _position_radial(screen_pos: Vector2) -> void:
	# Center the radial container on the click position, clamped to viewport
	var vp = get_viewport_rect()
	var margin = radial_radius + MIN_BUTTON_SIZE
	var clamped_pos = Vector2(
		clamp(screen_pos.x, margin, vp.size.x - margin),
		clamp(screen_pos.y, margin, vp.size.y - margin)
	)
	_radial_container.position = clamped_pos

# ============================================================================
# ACTION DISPATCH
# ============================================================================

func _on_button_action(button_def: MapNodeButtonDef) -> void:
	match button_def.button_category:
		MapNodeButtonDef.ButtonCategory.QUESTS:
			_handle_quests()
		MapNodeButtonDef.ButtonCategory.NPCS:
			_handle_npcs(button_def)
		MapNodeButtonDef.ButtonCategory.ENTER_DUNGEON:
			_handle_enter_dungeon(button_def)
		MapNodeButtonDef.ButtonCategory.ENTER_ZONE:
			_handle_enter_zone(button_def)
		MapNodeButtonDef.ButtonCategory.REST:
			_handle_rest(button_def)
		MapNodeButtonDef.ButtonCategory.PARTY:
			_handle_party()
		MapNodeButtonDef.ButtonCategory.STASH:
			_handle_stash()
		MapNodeButtonDef.ButtonCategory.TRAVEL:
			_handle_travel()
		_:
			push_warning("MapRadialMenu: Unhandled button category %d" % button_def.button_category)
			hide_radial()

func _handle_quests() -> void:
	hide_radial()
	if _game_root and _game_root.has_method("show_quest_popup"):
		_game_root.show_quest_popup(_current_location)

func _handle_stash() -> void:
	hide_radial()
	if _game_root and _game_root.has_method("show_stash_popup"):
		_game_root.show_stash_popup()

func _handle_npcs(button_def: MapNodeButtonDef = null) -> void:
	# If this button targets a specific NPC + specific encounter, play it directly
	if button_def and button_def.npc_id != &"" and button_def.encounter_id != &"":
		_play_encounter(button_def.npc_id, button_def.encounter_id)
		return

	# If this button targets a specific NPC, show conversations or talk directly
	if button_def and button_def.npc_id != &"":
		_talk_to_npc(button_def.npc_id)
		return

	# Generic NPCS button — build sub-radial from NPCManager
	if _current_location == null:
		return
	var npcs = NPCManager.get_npcs_at_location(_current_location.location_id)
	var buttons: Array[MapNodeButtonDef] = []
	for npc in npcs:
		var entry = NPCManager.get_active_encounter(npc)
		if entry == null:
			continue  # NPC has nothing to say right now
		var btn_def = MapNodeButtonDef.new()
		btn_def.button_category = MapNodeButtonDef.ButtonCategory.NPCS
		btn_def.npc_id = npc.npc_id
		btn_def.label = npc.display_name
		if npc.portrait:
			btn_def.icon = npc.portrait
		buttons.append(btn_def)
	if buttons.is_empty():
		return
	push_sub_radial(buttons, "Talk to...")

func _talk_to_npc(npc_id: StringName) -> void:
	var npc = NPCManager.get_npc(npc_id)
	if npc == null:
		push_warning("MapRadialMenu: NPC '%s' not found" % npc_id)
		return

	# Get all available encounters at the highest priority
	var entries = NPCManager.get_active_encounters(npc)
	if entries.is_empty():
		push_warning("MapRadialMenu: NPC '%s' has no active dialogue" % npc_id)
		return

	# Single encounter — play directly (current behavior)
	if entries.size() == 1:
		var entry = entries[0]
		NPCManager.mark_encounter_seen(npc_id, entry.encounter_id)
		DialogueManager.start_dialogue(entry.encounter)
		hide_radial()
		return

	# Multiple encounters — build conversation sub-radial
	var buttons: Array[MapNodeButtonDef] = []
	for entry in entries:
		var btn_def = MapNodeButtonDef.new()
		btn_def.button_category = MapNodeButtonDef.ButtonCategory.NPCS
		btn_def.npc_id = npc_id
		btn_def.encounter_id = entry.encounter_id
		# Use the entry's display name from encounter_id
		btn_def.label = String(entry.encounter_id).capitalize()
		# Icon: entry icon → NPC default_dialogue_icon → generic NPCS category icon
		if entry.icon:
			btn_def.icon = entry.icon
		elif npc.default_dialogue_icon:
			btn_def.icon = npc.default_dialogue_icon
		buttons.append(btn_def)
	push_sub_radial(buttons, npc.display_name)

func _play_encounter(npc_id: StringName, encounter_id: StringName) -> void:
	"""Play a specific encounter by ID for the given NPC."""
	var npc = NPCManager.get_npc(npc_id)
	if npc == null:
		push_warning("MapRadialMenu: NPC '%s' not found" % npc_id)
		return
	var entry = NPCManager.get_encounter_by_id(npc, encounter_id)
	if entry == null or entry.encounter == null:
		push_warning("MapRadialMenu: Encounter '%s' not found on NPC '%s'" % [encounter_id, npc_id])
		return
	NPCManager.mark_encounter_seen(npc_id, encounter_id)
	DialogueManager.start_dialogue(entry.encounter)
	hide_radial()

func _handle_enter_dungeon(button_def: MapNodeButtonDef) -> void:
	hide_radial()
	if _game_root == null:
		push_warning("MapRadialMenu: No game_root for dungeon entry")
		return

	if button_def.dungeon_chain != null:
		if _game_root.has_method("enter_dungeon_chain"):
			_game_root.enter_dungeon_chain(button_def.dungeon_chain)
		else:
			push_warning("MapRadialMenu: GameRoot missing enter_dungeon_chain()")
	elif button_def.dungeon_definition != null:
		_game_root.enter_dungeon(button_def.dungeon_definition)
	else:
		push_warning("MapRadialMenu: ENTER_DUNGEON button has no dungeon_definition or dungeon_chain")

func _handle_enter_zone(button_def: MapNodeButtonDef) -> void:
	if button_def.sub_map == null:
		push_warning("MapRadialMenu: ENTER_ZONE button has no sub_map assigned")
		hide_radial()
		return
	hide_radial()
	zone_entered.emit(button_def.sub_map)

func _handle_rest(button_def: MapNodeButtonDef) -> void:
	if _player == null:
		return
	var cost = button_def.rest_cost_gold
	if cost > 0 and _player.gold < cost:
		return  # Not enough gold — no action (add UI feedback here when needed)
	if cost > 0:
		_player.gold -= cost

	var heal_amount = int(_player.max_hp * button_def.rest_heal_percent)

	# Compute heal ratio BEFORE healing player (for proportional companion heal)
	var player_missing = _player.max_hp - _player.current_hp
	var heal_ratio: float = 1.0
	if player_missing > 0 and heal_amount > 0:
		heal_ratio = clampf(float(heal_amount) / float(player_missing), 0.0, 1.0)
	elif player_missing > 0 and heal_amount == 0:
		heal_ratio = 0.0

	# Heal player (uses heal() which emits hp_changed signal)
	if heal_amount > 0:
		var actual_heal = mini(heal_amount, player_missing)
		_player.heal(heal_amount)
		if actual_heal > 0:
			GameEventBus.emit_heal_received(actual_heal)

	# Heal companions proportionally (mirrors dungeon_scene.gd rest logic)
	if heal_ratio > 0.0:
		for instance in _player.active_companions:
			if not instance or not instance.companion_data:
				continue
			var comp_max = instance.get_max_hp(_player.max_hp, _player.level)
			if instance.is_dead:
				instance.is_dead = false
				instance.current_hp = maxi(int(comp_max * heal_ratio), 1)
			else:
				if instance.current_hp < 0:
					instance.initialize_hp(_player.max_hp, _player.level)
				var comp_missing = comp_max - instance.current_hp
				if comp_missing > 0:
					var comp_heal = maxi(int(comp_missing * heal_ratio), 1)
					instance.current_hp = mini(instance.current_hp + comp_heal, comp_max)

	hide_radial()
	action_completed.emit()

func _handle_party() -> void:
	hide_radial()
	if _game_root and _game_root.has_method("show_party_popup"):
		_game_root.show_party_popup()

func _handle_travel() -> void:
	var location = _current_location
	hide_radial()
	travel_requested.emit(location)

# ============================================================================
# INPUT
# ============================================================================

func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_back_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var local_pos = _radial_container.get_local_mouse_position()

	# Check Back button first
	if _back_button.visible and Rect2(_back_button.position, _back_button.size).has_point(local_pos):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return

	# Check each spawned action button
	for child in _radial_container.get_children():
		if child == _back_button:
			continue
		if not (child is Control):
			continue
		var btn := child as Control
		if not btn.visible or (btn is Button and (btn as Button).disabled):
			continue
		if Rect2(btn.position, btn.size).has_point(local_pos):
			get_viewport().set_input_as_handled()
			if btn.has_method("get_button_def"):
				var bd: MapNodeButtonDef = btn.get_button_def()
				if bd:
					_on_button_action(bd)
			return

	# Click was outside all buttons — dismiss
	get_viewport().set_input_as_handled()
	_on_back_pressed()

func _on_back_pressed() -> void:
	_pop_radial()
