## Main dungeon controller. Manages run state, handles node encounters,
## coordinates with GameRoot for combat transitions.
## Node2D — lives in world space for the 2.5D corridor.
extends Node2D
class_name DungeonScene

# ============================================================================
# SIGNALS
# ============================================================================
signal dungeon_started(definition: DungeonDefinition)
signal dungeon_completed(run: DungeonRun)
signal dungeon_failed(run: DungeonRun)
signal node_entered(node: DungeonNodeData)
signal node_completed(node: DungeonNodeData)
signal combat_requested(encounter: CombatEncounter)

# ============================================================================
# STATE
# ============================================================================
var current_run: DungeonRun = null
var _generator: DungeonMapGenerator = DungeonMapGenerator.new()
var _player: Player = null
var _awaiting_combat: bool = false
var _combat_node: DungeonNodeData = null

# ============================================================================
# NODE REFERENCES — all discovered from scene tree, never code-created
# ============================================================================
var corridor_builder: DungeonCorridorBuilder = null
var dungeon_camera: Camera2D = null
var floor_label: Label = null
var dungeon_name_label: Label = null
var progress_bar: TextureProgressBar = null
var popup_layer: CanvasLayer = null

@onready var transition_overlay: ColorRect = $PopupLayer/TransitionOverlay

# Popup references — discovered packed scene instances
var event_popup = null
var shop_popup = null
var rest_popup = null
var shrine_popup = null
var treasure_popup = null
var complete_popup = null

# ============================================================================
# INITIALIZATION — node-based discovery (matches PlayerMenu/CombatUI pattern)
# ============================================================================

func _ready():
	add_to_group("dungeon_scene")
	_discover_nodes()
	_setup_dust_motes()
	_connect_signals()
	print("🏰 DungeonScene ready")

func _discover_nodes():
	print("  🔍 Discovering dungeon nodes...")

	corridor_builder = find_child("CorridorBuilder", true, false) as DungeonCorridorBuilder
	print("    CorridorBuilder: %s" % ("✓" if corridor_builder else "✗"))

	dungeon_camera = find_child("DungeonCamera", true, false) as Camera2D
	print("    DungeonCamera: %s" % ("✓" if dungeon_camera else "✗"))

	floor_label = find_child("FloorLabel", true, false) as Label
	dungeon_name_label = find_child("DungeonNameLabel", true, false) as Label
	progress_bar = find_child("ProgressBar", true, false) as TextureProgressBar

	popup_layer = find_child("PopupLayer", true, false) as CanvasLayer

	# Discover popup packed scene instances within PopupLayer
	if popup_layer:
		event_popup = popup_layer.find_child("EventPopup", true, false)
		shop_popup = popup_layer.find_child("ShopPopup", true, false)
		rest_popup = popup_layer.find_child("RestPopup", true, false)
		shrine_popup = popup_layer.find_child("ShrinePopup", true, false)
		treasure_popup = popup_layer.find_child("TreasurePopup", true, false)
		complete_popup = popup_layer.find_child("CompletePopup", true, false)

	# Hide all popups on startup
	_hide_all_popups()

func _connect_signals():
	# Corridor builder → door selection
	if corridor_builder:
		corridor_builder.camera = dungeon_camera
		corridor_builder.player_sprite = corridor_builder.find_child("PlayerSprite", true, false)
		if not corridor_builder.door_selected.is_connected(_on_door_selected):
			corridor_builder.door_selected.connect(_on_door_selected)

	# Popup result signals — each popup emits popup_closed(result: Dictionary)
	for popup in [event_popup, shop_popup, rest_popup, shrine_popup,
				  treasure_popup, complete_popup]:
		if popup and popup.has_signal("popup_closed"):
			if not popup.popup_closed.is_connected(_on_popup_closed):
				popup.popup_closed.connect(_on_popup_closed)

func _hide_all_popups():
	for popup in [event_popup, shop_popup, rest_popup, shrine_popup,
				  treasure_popup, complete_popup]:
		if popup: popup.hide()

# ============================================================================
# PUBLIC API
# ============================================================================

func enter_dungeon(definition: DungeonDefinition, player: Player):
	_player = player

	var warnings = definition.validate()
	for w in warnings:
		push_warning("Dungeon: %s" % w)

	current_run = _generator.generate(definition)
	current_run.start(definition, player.gold)

	# Update UI labels
	if dungeon_name_label:
		dungeon_name_label.text = definition.dungeon_name
	_update_floor_ui()

	_apply_theme(definition)

	# Build corridor
	if corridor_builder:
		corridor_builder.build_corridor(current_run)

	dungeon_started.emit(definition)

	# Visit start node
	_enter_node(current_run.floors[0][0])
	
	# Auto-enter start node
	var start_nodes = current_run.get_floor_nodes(0)
	if start_nodes.size() > 0:
		_enter_node(start_nodes[0].id)

func exit_dungeon():
	_cleanup_temp_effects()
	if corridor_builder:
		corridor_builder.clear_corridor()
	current_run = null
	_player = null

# ============================================================================
# NODE HANDLING
# ============================================================================

func _on_door_selected(node_id: int):
	if _awaiting_combat: return
	_enter_node(node_id)

func _enter_node(node_id: int):
	var node = current_run.get_node(node_id)
	if not node:
		push_error("DungeonScene: Invalid node %d" % node_id)
		return

	current_run.visit_node(node_id)
	_update_floor_ui()
	node_entered.emit(node)

	match node.node_type:
		DungeonEnums.NodeType.START:    _handle_start(node)
		DungeonEnums.NodeType.COMBAT:   _handle_combat(node)
		DungeonEnums.NodeType.ELITE:    _handle_combat(node)
		DungeonEnums.NodeType.BOSS:     _handle_combat(node)
		DungeonEnums.NodeType.SHOP:     _handle_shop(node)
		DungeonEnums.NodeType.REST:     _handle_rest(node)
		DungeonEnums.NodeType.EVENT:    _handle_event(node)
		DungeonEnums.NodeType.TREASURE: _handle_treasure(node)
		DungeonEnums.NodeType.SHRINE:   _handle_shrine(node)

# ============================================================================
# ENCOUNTER HANDLERS
# ============================================================================

func _handle_start(node: DungeonNodeData):
	current_run.complete_node(node.id)
	node_completed.emit(node)

func _handle_combat(node: DungeonNodeData):
	if not node.encounter:
		_complete_and_advance(node)
		return
	_awaiting_combat = true
	_combat_node = node
	# Delay → transition → then emit combat
	_play_combat_transition(node.encounter)

func _play_combat_transition(encounter: CombatEncounter):
	if not transition_overlay:
		combat_requested.emit(encounter)
		return

	transition_overlay.modulate = Color(1, 1, 1, 0)
	transition_overlay.visible = true

	var tw = create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(transition_overlay, "color", Color.WHITE, 0.1)
	tw.tween_property(transition_overlay, "modulate:a", 1.0, 0.1)
	tw.tween_interval(0.15)
	tw.tween_property(transition_overlay, "color", Color.BLACK, 0.2)
	tw.tween_interval(0.2)
	# Emit LAST — after this, dungeon gets disabled and tween dies. That's fine.
	tw.tween_callback(func():
		combat_requested.emit(encounter)
	)

func on_combat_ended(player_won: bool):
	"""Called by GameRoot. Dungeon owns ALL reward distribution."""
	_awaiting_combat = false
	if not _combat_node: return
	var node = _combat_node
	_combat_node = null

	if player_won:
		var gold = 0; var exp = 0
		match node.node_type:
			DungeonEnums.NodeType.COMBAT:
				gold = current_run.definition.gold_per_combat
				exp = current_run.definition.exp_per_combat
			DungeonEnums.NodeType.ELITE:
				gold = current_run.definition.gold_per_elite
				exp = current_run.definition.exp_per_elite
			DungeonEnums.NodeType.BOSS:
				gold = current_run.definition.gold_per_elite * 2
				exp = current_run.definition.exp_per_elite * 2
		if gold > 0:
			_player.add_gold(gold); current_run.track_gold(gold)
		if exp > 0:
			_player.add_experience(exp); current_run.track_exp(exp)
		_complete_and_advance(node)
		if node.node_type == DungeonEnums.NodeType.BOSS:
			_on_dungeon_complete()
	else:
		_on_player_died()

func _handle_shop(node: DungeonNodeData):
	var items: Array[EquippableItem] = []
	for i in 3:
		var item = current_run.definition.generate_shop_item()
		if item: items.append(item)
	if shop_popup and shop_popup.has_method("show_popup"):
		shop_popup.show_popup({"node": node, "items": items, "run": current_run})

func _handle_rest(node: DungeonNodeData):
	if rest_popup and rest_popup.has_method("show_popup"):
		rest_popup.show_popup({
			"node": node,
			"affix_pool": current_run.definition.rest_affix_pool,
			"run": current_run, "player": _player
		})

func _handle_event(node: DungeonNodeData):
	if not node.event:
		_complete_and_advance(node)
		return
	if event_popup and event_popup.has_method("show_popup"):
		event_popup.show_popup({"node": node, "event": node.event, "run": current_run})

func _handle_treasure(node: DungeonNodeData):
	var item = current_run.definition.generate_loot_item()
	if item:
		_player.add_to_inventory(item)
		current_run.track_item(item)
	if treasure_popup and treasure_popup.has_method("show_popup"):
		treasure_popup.show_popup({"node": node, "item": item, "run": current_run})
	else:
		_complete_and_advance(node)

func _handle_shrine(node: DungeonNodeData):
	if not node.shrine:
		_complete_and_advance(node)
		return
	if shrine_popup and shrine_popup.has_method("show_popup"):
		shrine_popup.show_popup({"node": node, "shrine": node.shrine, "run": current_run})

# ============================================================================
# POPUP RESULT HANDLER
# ============================================================================

func _on_popup_closed(result: Dictionary):
	"""Universal handler — all popups emit popup_closed({type, node_id, ...})"""
	var node_id: int = result.get("node_id", -1)
	var popup_type: String = result.get("type", "")

	match popup_type:
		"event":
			var choice: DungeonEventChoice = result.get("choice")
			var succeeded: bool = result.get("succeeded", true)
			_apply_event_rewards(node_id, choice, succeeded)
		"shop":
			for item in result.get("purchased", []):
				current_run.track_item(item)
		"rest":
			var heal: int = result.get("heal_amount", 0)
			if heal > 0 and _player: _player.heal(heal)
			var affix: DiceAffix = result.get("chosen_affix")
			if affix: _apply_temp_affix(affix)
		"shrine":
			if result.get("accepted", false):
				var node = current_run.get_node(node_id)
				if node and node.shrine:
					_apply_shrine(node.shrine)
		"treasure", "complete":
			pass  # rewards already applied before popup opened

	if node_id >= 0:
		_complete_and_advance(current_run.get_node(node_id))

func _apply_event_rewards(node_id: int, choice: DungeonEventChoice, succeeded: bool):
	if not _player or not choice: return
	if succeeded:
		if choice.heal_amount != 0: _player.heal(choice.heal_amount)
		if choice.heal_percent != 0.0:
			_player.heal(int(_player.max_health * choice.heal_percent))
		if choice.gold_reward != 0:
			_player.add_gold(choice.gold_reward)
			if choice.gold_reward > 0: current_run.track_gold(choice.gold_reward)
		if choice.experience_reward != 0:
			_player.add_experience(choice.experience_reward)
			current_run.track_exp(choice.experience_reward)
		if choice.grant_item:
			var item = LootManager.generate_drop(
				choice.grant_item,
				current_run.definition.dungeon_level,
				current_run.definition.dungeon_region
			).get("item") as EquippableItem
			if item:
				_player.add_to_inventory(item)
				current_run.track_item(item)
		if choice.grant_temp_affix:
			_apply_temp_affix(choice.grant_temp_affix)
	else:
		if choice.fail_heal_amount != 0: _player.heal(choice.fail_heal_amount)
		if choice.fail_gold_reward != 0: _player.add_gold(choice.fail_gold_reward)
	var node = current_run.get_node(node_id)
	if node and node.event:
		current_run.track_event(node.event.event_id)

func _apply_shrine(shrine: DungeonShrine):
	if shrine.blessing_affix and _player:
		_player.affix_manager.add_affix(shrine.blessing_affix)
		current_run.track_shrine_affix(shrine.blessing_affix)
	if shrine.curse_affix and _player:
		_player.affix_manager.add_affix(shrine.curse_affix)
		current_run.track_shrine_affix(shrine.curse_affix)

# ============================================================================
# PROGRESSION HELPERS
# ============================================================================

func _complete_and_advance(node: DungeonNodeData):
	if not node: return
	current_run.complete_node(node.id)
	node_completed.emit(node)
	_update_floor_ui()

func _update_floor_ui():
	if not current_run: return
	if floor_label:
		floor_label.text = "Floor %d / %d" % [current_run.current_floor + 1,
			current_run.definition.floor_count]
	if progress_bar:
		progress_bar.max_value = current_run.definition.floor_count - 1
		progress_bar.value = current_run.current_floor

# ============================================================================
# COMPLETION / FAILURE
# ============================================================================

func _on_dungeon_complete():
	current_run.is_complete = true
	var def = current_run.definition
	if def.first_clear_item and not _is_first_cleared(def.dungeon_id):
		var item = def.generate_first_clear_item()
		if item and _player:
			_player.add_to_inventory(item); current_run.track_item(item)
		if def.first_clear_gold > 0 and _player:
			_player.add_gold(def.first_clear_gold); current_run.track_gold(def.first_clear_gold)
		if def.first_clear_exp > 0 and _player:
			_player.add_experience(def.first_clear_exp); current_run.track_exp(def.first_clear_exp)
		_mark_first_cleared(def.dungeon_id)
	if complete_popup and complete_popup.has_method("show_popup"):
		complete_popup.show_popup({"type": "complete", "run": current_run})
	dungeon_completed.emit(current_run)

func _on_player_died():
	current_run.is_failed = true
	if _player:
		_player.gold = current_run.gold_snapshot_on_entry
		for item in current_run.items_earned:
			_player.remove_from_inventory(item)
	_cleanup_temp_effects()
	dungeon_failed.emit(current_run)

# ============================================================================
# TEMP EFFECTS
# ============================================================================

func _apply_temp_affix(affix: DiceAffix):
	if not _player: return
	for die in _player.dice_pool.dice:
		var copy = affix.duplicate(true)
		copy.source_type = "dungeon_temp"
		die.add_affix(copy)
	current_run.track_temp_affix(affix)

func _cleanup_temp_effects():
	if not _player: return
	for die in _player.dice_pool.dice:
		var to_remove = []
		for a in die.affixes:
			if a.source_type == "dungeon_temp": to_remove.append(a)
		for a in to_remove: die.remove_affix(a)
	if current_run:
		for affix in current_run.shrine_affixes_applied:
			_player.affix_manager.remove_affix(affix)


# New method in dungeon_scene.gd:

func _apply_theme(definition: DungeonDefinition):
	# Ambient parallax textures
	var floor_sprite = find_child("FloorSprite", true, false) as Sprite2D
	var side_wall_sprite = find_child("SideWallSprite", true, false) as Sprite2D
	var ceiling_sprite = find_child("CeilingSprite", true, false) as Sprite2D
	var frame_overlay = find_child("FrameOverlay", true, false) as TextureRect

	if floor_sprite and definition.floor_texture:
		floor_sprite.texture = definition.floor_texture
	if side_wall_sprite and definition.side_wall_texture:
		side_wall_sprite.texture = definition.side_wall_texture
	if ceiling_sprite and definition.ceiling_texture:
		ceiling_sprite.texture = definition.ceiling_texture
	if frame_overlay and definition.frame_texture:
		frame_overlay.texture = definition.frame_texture

	# Torch color
	var torch_left = find_child("TorchLeft", true, false)
	var torch_right = find_child("TorchRight", true, false)
	if definition.torch_color != Color.BLACK:
		for torch in [torch_left, torch_right]:
			if not torch: continue
			var light = torch.find_child("TorchLight", false, false) as PointLight2D
			if light:
				light.color = definition.torch_color


	var overlay = $CorridorFrame/FrameOverlay  # adjust path
	if overlay and overlay.material:
		var mat = overlay.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("fog_color", definition.fog_color)
			mat.set_shader_parameter("accent_color", definition.ambient_color)

	var surfaces = find_child("CorridorSurfaces", true, false) as CorridorSurfaces
	if surfaces:
		surfaces.apply_theme(definition)

	# Dust motes tinted to ambient color
	var dust = find_child("DustMotes", true, false) as GPUParticles2D
	if dust and definition.ambient_color != Color.BLACK:
		dust.modulate = definition.ambient_color


func _setup_dust_motes():
	var dust = find_child("DustMotes", true, false) as GPUParticles2D
	if not dust: return

	var mat = ParticleProcessMaterial.new()

	# Slow random drift
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -2.0, 0)

	# Gentle size variation
	mat.scale_min = 0.5
	mat.scale_max = 1.5

	# Spawn across the visible corridor area
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(500, 800, 0)

	# Fade in and out
	var alpha_curve = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 0.6))
	curve.add_point(Vector2(0.8, 0.6))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve

	# Warm white base — _apply_theme tints via modulate
	mat.color = Color(1.0, 0.95, 0.85, 0.4)

	dust.process_material = mat

	# Tiny soft circle texture
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var center = Vector2(3.5, 3.5)
	for x in 8:
		for y in 8:
			var dist = Vector2(x, y).distance_to(center) / 3.5
			var a = clampf(1.0 - dist * dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex = ImageTexture.create_from_image(img)
	dust.texture = tex


func _is_first_cleared(dungeon_id: String) -> bool:
	return GameManager.completed_encounters.has("dungeon_" + dungeon_id) if GameManager else false

func _mark_first_cleared(dungeon_id: String):
	if GameManager:
		GameManager.completed_encounters.append("dungeon_" + dungeon_id)
