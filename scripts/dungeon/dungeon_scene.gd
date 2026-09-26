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
## The player took a way out and left with their loot (run banked).
signal dungeon_left(run: DungeonRun)

# ── Chain signals ──
signal chain_dungeon_cemented(run: DungeonRun, chain_runner: DungeonChainRunner)
signal chain_completed(chain_runner: DungeonChainRunner)
signal chain_failed(run: DungeonRun, chain_runner: DungeonChainRunner)

# ============================================================================
# STATE
# ============================================================================
var current_run: DungeonRun = null
var _chain_runner: DungeonChainRunner = null
var _generator: DungeonMapGenerator = DungeonMapGenerator.new()
var _player: Player = null
var _awaiting_combat: bool = false
var _combat_node: DungeonNodeData = null

# ── Roguelite affix choice state ──
var _awaiting_affix_choice: bool = false
var _pending_advance_node: DungeonNodeData = null
var _pending_boss_complete: bool = false

# ============================================================================
# NODE REFERENCES — all discovered from scene tree, never code-created
# ============================================================================
var dungeon_map: DungeonMap = null
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
var run_affix_popup = null

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

	dungeon_map = find_child("DungeonMap", true, false) as DungeonMap
	print("    DungeonMap: %s" % ("✓" if dungeon_map else "✗"))

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
		run_affix_popup = popup_layer.find_child("RunAffixChoicePopup", true, false)

	# Hide all popups on startup
	_hide_all_popups()

func _connect_signals():
	# Corridor builder → door selection
	if dungeon_map:
		dungeon_map.camera = dungeon_camera
		if not dungeon_map.node_selected.is_connected(_on_node_selected):
			dungeon_map.node_selected.connect(_on_node_selected)

	# Popup result signals — each popup emits popup_closed(result: Dictionary)
	for popup in [event_popup, shop_popup, rest_popup, shrine_popup,
				  treasure_popup, complete_popup, run_affix_popup]:
		if popup and popup.has_signal("popup_closed"):
			if not popup.popup_closed.is_connected(_on_popup_closed):
				popup.popup_closed.connect(_on_popup_closed)

func _hide_all_popups():
	for popup in [event_popup, shop_popup, rest_popup, shrine_popup,
				  treasure_popup, complete_popup, run_affix_popup]:
		if popup: popup.hide()

# ============================================================================
# PUBLIC API
# ============================================================================

func enter_chain(chain: DungeonChain, player: Player):
	"""Enter a chain of dungeons. Completing each dungeon cements its gains
	and immediately starts the next one."""
	_player = player
	_chain_runner = DungeonChainRunner.new(chain)
	var first_def = _chain_runner.get_current_definition()
	if not first_def:
		push_error("DungeonScene: Chain has no dungeons")
		return
	enter_dungeon(first_def, player)

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


	# Build corridor
	if dungeon_map:
		dungeon_map.build_map(current_run)

	dungeon_started.emit(definition)

	# ── Roguelite: offer entry affix before first node ──
	if definition.has_run_affix_pool() and definition.offer_on_entry:
		_pending_advance_node = null
		_pending_boss_complete = false
		_show_run_affix_choice("entry")
	else:
		_enter_start_node()

func _enter_start_node():
	"""Enter the first node on floor 0. Deferred by entry affix popup."""
	_enter_node(current_run.floors[0][0])
	var start_nodes = current_run.get_floor_nodes(0)
	if start_nodes.size() > 0:
		_enter_node(start_nodes[0].id)

# ============================================================================
# SAVE / RESUME (runs survive closing the app)
# ============================================================================

func is_at_safe_point() -> bool:
	"""True between nodes: no fight, popup or affix choice pending."""
	if current_run == null or _awaiting_combat or _awaiting_affix_choice:
		return false
	for popup in [event_popup, shop_popup, rest_popup, shrine_popup,
				  treasure_popup, complete_popup, run_affix_popup]:
		if popup and popup.visible:
			return false
	return true

func serialize_run() -> Dictionary:
	if current_run == null:
		return {}
	var state: Dictionary = current_run.to_dict(_player)
	if _chain_runner and _chain_runner.chain:
		state["chain"] = _chain_runner.chain.resource_path
		state["chain_index"] = _chain_runner.current_index
	return state

func resume_fight_at_current_node() -> void:
	"""A run saved during a fight: the current node is the fight."""
	if current_run == null:
		return
	_combat_node = current_run.get_node(current_run.current_node_id)
	_awaiting_combat = _combat_node != null

func get_run_stat_affixes() -> Array:
	"""Stat affixes from shrines and run affixes (rebuilt from gear on load,
	so a resumed run re-applies them)."""
	return current_run.shrine_affixes_applied.duplicate() if current_run else []

func resume_run(state: Dictionary, stat_affixes: Array, player: Player) -> bool:
	"""Rebuild a saved run and put the player back where they were."""
	var run: DungeonRun = DungeonRun.from_dict(state, player)
	if run == null:
		return false
	_player = player
	current_run = run
	var chain_path: String = state.get("chain", "")
	if chain_path != "" and ResourceLoader.exists(chain_path):
		_chain_runner = DungeonChainRunner.new(load(chain_path))
		_chain_runner.current_index = int(state.get("chain_index", 0))
	for a in stat_affixes:
		if a is Affix:
			_player.affix_manager.add_affix(a)
			current_run.shrine_affixes_applied.append(a)
	if dungeon_name_label:
		dungeon_name_label.text = run.definition.dungeon_name
	_update_floor_ui()
	if dungeon_map:
		dungeon_map.build_map(run, false)
		dungeon_map.restore_progress()
	dungeon_started.emit(run.definition)
	print("🏰 Resumed run: %s, floor %d" % [run.definition.dungeon_name, run.current_floor + 1])
	return true

func exit_dungeon():
	_cleanup_temp_effects()
	if dungeon_map:
		dungeon_map.clear_map()
	current_run = null
	_chain_runner = null
	_player = null

# ============================================================================
# NODE HANDLING
# ============================================================================

func _on_node_selected(node_id: int):
	if _awaiting_combat or _awaiting_affix_choice: return
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
		DungeonEnums.NodeType.EXIT:     _handle_exit(node)

# ============================================================================
# ENCOUNTER HANDLERS
# ============================================================================

func _handle_start(node: DungeonNodeData):
	_complete_and_advance(node)

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
	"""Called by GameRoot. Dungeon owns ALL reward distribution.
	v4: Now rolls per-enemy loot in addition to flat dungeon gold/exp."""
	_awaiting_combat = false
	if not _combat_node: return
	var node = _combat_node
	_combat_node = null

	if player_won:
		# ── Flat dungeon gold/exp (unchanged) ──
		var gold: int = 0
		var exp: int = 0
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

		# ── Per-enemy loot (v4) ──
		var region_config: RegionLootConfig = null
		if GameManager and GameManager.region_loot_config:
			region_config = GameManager.region_loot_config

		if region_config and node.encounter:
			var luck: float = 0.0
			if _player:
				luck = float(_player.get_total_stat("luck"))

			for enemy_data: EnemyData in node.encounter.enemies:
				if not enemy_data:
					continue

				# Use effective level: scale to player, floor at enemy minimum
				var eff_level: int = enemy_data.get_effective_level(
					_player.level if _player else 1)

				var results: Array[Dictionary] = LootManager.roll_loot_from_combat(
					region_config,
					enemy_data.enemy_tier,
					enemy_data.enemy_archetype,
					eff_level,
					luck,
				)

				for result: Dictionary in results:
					if result.get("type") == "currency":
						gold += result.get("amount", 0)
					else:
						var item: EquippableItem = result.get("item")
						if item and _player:
							_player.add_to_inventory(item)
							current_run.track_item(item)
							GameEventBus.emit_item_gained(item.item_name, item.rarity, _get_portrait())

		# ── Apply gold/exp ──
		if gold > 0:
			_player.add_gold(gold)
			current_run.track_gold(gold)
			GameEventBus.emit_gold_gained(gold, _get_portrait())
		if exp > 0:
			_player.add_experience(exp)
			current_run.track_exp(exp)
			GameEventBus.emit_exp_gained(exp, _get_portrait())

		# ── Award relationship points to active companions ──
		for inst in _player.active_companions:
			if inst and inst.companion_data and inst.companion_data.companion_id != &"":
				GameState.modify_relationship(inst.companion_data.companion_id, 2)

		# ── Roguelite: offer affix after elite or boss ──
		var _should_offer_affix: bool = false
		var _affix_trigger: String = ""

		if current_run and current_run.definition.has_run_affix_pool():
			if node.node_type == DungeonEnums.NodeType.ELITE \
					and current_run.definition.offer_after_elite:
				_should_offer_affix = true
				_affix_trigger = "elite"
			elif node.node_type == DungeonEnums.NodeType.BOSS \
					and current_run.definition.offer_after_boss:
				_should_offer_affix = true
				_affix_trigger = "boss"

		if _should_offer_affix:
			_pending_advance_node = node
			_pending_boss_complete = (node.node_type == DungeonEnums.NodeType.BOSS)
			_show_run_affix_choice(_affix_trigger)
		else:
			_complete_and_advance(node)
			if node.node_type == DungeonEnums.NodeType.BOSS:
				_on_dungeon_complete()
	else:
		_on_player_died()

func _handle_shop(node: DungeonNodeData):
	var items: Array = []
	for i in 3:
		var item = current_run.definition.generate_shop_item()
		if item: items.append(item)
	# Add 1-2 consumables if the pool is populated
	var consumable_count: int = randi_range(1, 2)
	for i in consumable_count:
		var consumable = current_run.definition.generate_shop_consumable()
		if consumable: items.append(consumable)
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
		GameEventBus.emit_item_gained(item.item_name, item.rarity, _get_portrait())
	# 30% chance for a bonus consumable
	var consumable: ConsumableItem = null
	if randf() < 0.3:
		consumable = current_run.definition.generate_loot_consumable()
		if consumable and _player:
			_player.add_consumable(consumable)
			current_run.track_consumable(consumable)
	if treasure_popup and treasure_popup.has_method("show_popup"):
		treasure_popup.show_popup({"node": node, "item": item, "consumable": consumable, "run": current_run})
	else:
		_complete_and_advance(node)

func _handle_exit(node: DungeonNodeData):
	"""A way out: leave with everything earned so far, or press on.
	Shown through the event popup. The texts are placeholders for review."""
	var ev := DungeonEvent.new()
	ev.event_name = "A Way Out"
	ev.description = "(Placeholder) A way back to the surface. You can leave with what you've found, or press on."
	var leave := DungeonEventChoice.new()
	leave.choice_text = "(Placeholder) Leave with your loot"
	leave.ends_run_banked = true
	var stay := DungeonEventChoice.new()
	stay.choice_text = "(Placeholder) Press on"
	var choices: Array[DungeonEventChoice] = [leave, stay]
	ev.choices = choices
	if event_popup and event_popup.has_method("show_popup"):
		event_popup.show_popup({"node": node, "event": ev, "run": current_run})
	else:
		_complete_and_advance(node)

func _bank_and_leave():
	"""End the run here, keeping everything earned (like a cleared chain link)."""
	if not current_run:
		return
	_cement_current_run()
	dungeon_left.emit(current_run)

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
			if choice and choice.ends_run_banked and succeeded:
				_bank_and_leave()
				return
		"shop":
			for item in result.get("purchased", []):
				if item is EquippableItem:
					current_run.track_item(item)
				elif item is ConsumableItem:
					current_run.track_consumable(item)
		"rest":
			var heal: int = result.get("heal_amount", 0)
			
			# --- Companion heal ratio (compute BEFORE healing player) ---
			var heal_ratio: float = 1.0  # full rest if player already at max HP
			if _player:
				var player_missing: int = _player.max_hp - _player.current_hp
				if player_missing > 0 and heal > 0:
					heal_ratio = clampf(float(heal) / float(player_missing), 0.0, 1.0)
				elif player_missing > 0 and heal == 0:
					heal_ratio = 0.0
				# Player at full HP → ratio stays 1.0 (companions still benefit)
			
			# --- Heal player ---
			if heal > 0 and _player:
				_player.heal(heal)
			
			# --- Heal companions proportionally ---
			if _player and heal_ratio > 0.0:
				for instance in _player.active_companions:
					if not instance or not instance.companion_data:
						continue
					var comp_max: int = instance.get_max_hp(_player.max_hp, _player.level)
					if instance.is_dead:
						# Revive at proportional HP
						instance.is_dead = false
						instance.current_hp = maxi(int(comp_max * heal_ratio), 1)
						print("  [Rest] Revived %s at %d/%d HP" % [
							instance.get_display_name(), instance.current_hp, comp_max])
					else:
						if instance.current_hp < 0:
							instance.initialize_hp(_player.max_hp, _player.level)
						var comp_missing: int = comp_max - instance.current_hp
						if comp_missing > 0:
							var comp_heal: int = maxi(int(comp_missing * heal_ratio), 1)
							instance.current_hp = mini(instance.current_hp + comp_heal, comp_max)
							print("  [Rest] Healed %s for %d → %d/%d HP" % [
								instance.get_display_name(), comp_heal, instance.current_hp, comp_max])
			
			var affix: DiceAffix = result.get("chosen_affix")
			if affix: _apply_temp_affix(affix)
		"shrine":
			if result.get("accepted", false):
				var node = current_run.get_node(node_id)
				if node and node.shrine:
					_apply_shrine(node.shrine)
		"treasure", "complete":
			pass  # rewards already applied before popup opened

		"run_affix":
			_awaiting_affix_choice = false
			var chosen: RunAffixEntry = result.get("chosen")
			var skipped: bool = result.get("skipped", false)

			if chosen:
				_apply_run_affix(chosen)
				current_run.track_run_affix(chosen)
				GameEventBus.emit_run_affix_chosen(chosen.display_name, _get_portrait())
				print("🎲 Run affix chosen: %s" % chosen.display_name)
			elif skipped:
				current_run.skip_affix_offer()
				var skip_gold: int = current_run.definition.affix_skip_gold_bonus
				if skip_gold > 0 and _player:
					_player.add_gold(skip_gold)
					current_run.track_gold(skip_gold)
					GameEventBus.emit_gold_gained(skip_gold, _get_portrait())
					print("🎲 Affix skipped (+%d gold)" % skip_gold)
				else:
					print("🎲 Affix skipped")

			# Resume deferred flow
			if _pending_advance_node:
				var advance_node = _pending_advance_node
				var boss_complete = _pending_boss_complete
				_pending_advance_node = null
				_pending_boss_complete = false
				_complete_and_advance(advance_node)
				if boss_complete:
					_on_dungeon_complete()
			elif result.get("trigger", "") == "entry":
				_enter_start_node()

	if node_id >= 0 and popup_type != "run_affix":
		_complete_and_advance(current_run.get_node(node_id))

func _apply_event_rewards(node_id: int, choice: DungeonEventChoice, succeeded: bool):
	if not _player or not choice: return
	if succeeded:
		if choice.heal_amount != 0: _player.heal(choice.heal_amount)
		if choice.heal_percent != 0.0:
			_player.heal(int(_player.max_health * choice.heal_percent))
		if choice.gold_reward != 0:
			_player.add_gold(choice.gold_reward)
			if choice.gold_reward > 0:
				current_run.track_gold(choice.gold_reward)
				GameEventBus.emit_gold_gained(choice.gold_reward, _get_portrait())
		if choice.experience_reward != 0:
			_player.add_experience(choice.experience_reward)
			current_run.track_exp(choice.experience_reward)
			GameEventBus.emit_exp_gained(choice.experience_reward, _get_portrait())
		if choice.grant_item:
			var item = LootManager.generate_drop(
				choice.grant_item,
				current_run.definition.dungeon_level,
				current_run.definition.dungeon_region
			).get("item") as EquippableItem
			if item:
				_player.add_to_inventory(item)
				current_run.track_item(item)
				GameEventBus.emit_item_gained(item.item_name, item.rarity, _get_portrait())
		if choice.grant_temp_affix:
			_apply_temp_affix(choice.grant_temp_affix)
	else:
		if choice.fail_heal_amount != 0: _player.heal(choice.fail_heal_amount)
		if choice.fail_gold_reward != 0: _player.add_gold(choice.fail_gold_reward)
	var node = current_run.get_node(node_id)
	if node and node.event:
		current_run.track_event(node.event.event_id)

func _apply_shrine(shrine: DungeonShrine):
	var level: int = current_run.definition.dungeon_level if current_run else 1
	var scaling_config: AffixScalingConfig = AffixTableRegistry.scaling_config
	var power_pos: float = scaling_config.get_power_position(level) if scaling_config else -1.0

	if shrine.blessing_affix and _player:
		var copy = shrine.blessing_affix.duplicate(true)
		copy.source_type = "shrine"
		if copy.has_scaling():
			copy.roll_value(power_pos, scaling_config)
		_player.affix_manager.add_affix(copy)
		current_run.track_shrine_affix(copy)
		GameEventBus.emit_shrine_applied(copy.affix_name, false, _get_portrait())
	if shrine.curse_affix and _player:
		var copy = shrine.curse_affix.duplicate(true)
		copy.source_type = "shrine"
		if copy.has_scaling():
			copy.roll_value(power_pos, scaling_config)
		_player.affix_manager.add_affix(copy)
		current_run.track_shrine_affix(copy)
		GameEventBus.emit_shrine_applied(copy.affix_name, true, _get_portrait())

# ============================================================================
# PROGRESSION HELPERS
# ============================================================================

func _complete_and_advance(node: DungeonNodeData):
	if not node: return
	current_run.complete_node(node.id)
	node_completed.emit(node)
	_update_floor_ui()
	
	# Tell the map to reveal next-floor nodes
	if dungeon_map:
		dungeon_map.complete_node(node.id)
	# A safe point: save the run so it survives closing the app
	GameState.request_autosave.call_deferred()

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

	# First-clear bonus (same logic regardless of chain)
	if not _is_first_cleared(def.dungeon_id):
		var item = def.generate_first_clear_item() if def.first_clear_item else null
		if item and _player:
			_player.add_to_inventory(item); current_run.track_item(item)
			GameEventBus.emit_item_gained(item.item_name, item.rarity, _get_portrait())
		if def.first_clear_gold > 0 and _player:
			_player.add_gold(def.first_clear_gold); current_run.track_gold(def.first_clear_gold)
			GameEventBus.emit_gold_gained(def.first_clear_gold, _get_portrait())
		if def.first_clear_exp > 0 and _player:
			_player.add_experience(def.first_clear_exp); current_run.track_exp(def.first_clear_exp)
			GameEventBus.emit_exp_gained(def.first_clear_exp, _get_portrait())
		_mark_first_cleared(def.dungeon_id)

	# ── Chain: mid-chain transition ──
	if _chain_runner and _chain_runner.has_next_dungeon():
		_cement_current_run()
		_chain_runner.record_completed_run(current_run)
		chain_dungeon_cemented.emit(current_run, _chain_runner)
		var next_def = _chain_runner.advance()
		if next_def:
			_start_next_chain_dungeon(next_def)
			return

	# ── Chain: final dungeon completed ──
	if _chain_runner:
		_cement_current_run()
		_chain_runner.record_completed_run(current_run)
		_chain_runner.is_chain_complete = true
		_apply_chain_clear_rewards()
		chain_completed.emit(_chain_runner)

	# ── Show completion popup and emit (single dungeon or chain-final) ──
	if complete_popup and complete_popup.has_method("show_popup"):
		var popup_data = {"type": "complete", "run": current_run}
		if _chain_runner:
			popup_data["chain_runner"] = _chain_runner
		complete_popup.show_popup(popup_data)
	dungeon_completed.emit(current_run)

func _on_player_died():
	"""The run is lost: gold earned in it, items and consumables found or
	bought in it go. Your own spending isn't refunded, and XP is kept
	(Balance Targets, "Losing")."""
	current_run.is_failed = true
	if _player:
		# Spending came out of run gold first; any spending beyond it was the
		# player's own money and stays spent.
		_player.gold = mini(current_run.gold_snapshot_on_entry, _player.gold)
		for item in current_run.items_earned:
			_player.remove_from_inventory(item)
		for consumable in current_run.consumables_earned:
			if consumable:
				ItemGrant.remove_by_name(consumable.item_name, 1)
	_cleanup_temp_effects()

	if _chain_runner:
		_chain_runner.is_chain_failed = true
		chain_failed.emit(current_run, _chain_runner)

	dungeon_failed.emit(current_run)

# ============================================================================
# TEMP EFFECTS
# ============================================================================

# ============================================================================
# ROGUELITE RUN AFFIX FLOW
# ============================================================================

func _show_run_affix_choice(trigger: String):
	"""Roll offers from the dungeon's affix pool and show the choice popup."""
	if not current_run or not current_run.definition.has_run_affix_pool():
		_resume_after_affix_skip(trigger)
		return

	var offers: Array[RunAffixEntry] = RunAffixRoller.new().roll_offers(
		current_run.definition.run_affix_pool,
		current_run,
		current_run.definition.affix_choices_per_offer
	)

	if offers.size() == 0:
		print("🎲 No affix offers available (pool exhausted)")
		_resume_after_affix_skip(trigger)
		return

	_awaiting_affix_choice = true

	if run_affix_popup and run_affix_popup.has_method("show_popup"):
		run_affix_popup.show_popup({
			"run": current_run,
			"offers": offers,
			"trigger": trigger,
			"skip_gold": current_run.definition.affix_skip_gold_bonus,
		})
	else:
		push_warning("DungeonScene: RunAffixChoicePopup not found!")
		_awaiting_affix_choice = false
		_resume_after_affix_skip(trigger)

func _resume_after_affix_skip(trigger: String):
	"""Resume the deferred flow when no popup is shown."""
	if _pending_advance_node:
		var advance_node = _pending_advance_node
		var boss_complete = _pending_boss_complete
		_pending_advance_node = null
		_pending_boss_complete = false
		_complete_and_advance(advance_node)
		if boss_complete:
			_on_dungeon_complete()
	elif trigger == "entry":
		_enter_start_node()

func _apply_run_affix(entry: RunAffixEntry):
	"""Apply a chosen run affix to the player. Uses existing temp systems."""
	if not entry or not _player:
		return

	match entry.affix_type:
		RunAffixEntry.AffixType.DICE:
			if entry.dice_affix:
				if entry.chain_animation:
					entry.dice_affix.effect_data["chain_animation"] = entry.chain_animation
				_apply_temp_affix(entry.dice_affix)
		RunAffixEntry.AffixType.STAT:
			if entry.stat_affix:
				var copy = entry.stat_affix.duplicate(true)
				_player.affix_manager.add_affix(copy)
				current_run.track_shrine_affix(copy)
		RunAffixEntry.AffixType.HYBRID:
			if entry.dice_affix:
				if entry.chain_animation:
					entry.dice_affix.effect_data["chain_animation"] = entry.chain_animation
				_apply_temp_affix(entry.dice_affix)
			if entry.stat_affix:
				var copy = entry.stat_affix.duplicate(true)
				_player.affix_manager.add_affix(copy)
				current_run.track_shrine_affix(copy)


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
		for a in die.applied_affixes:
			if a.source_type == "dungeon_temp": to_remove.append(a)
		for a in to_remove: die.remove_affix(a)
	if current_run:
		for affix in current_run.shrine_affixes_applied:
			_player.affix_manager.remove_affix(affix)

# ============================================================================
# CHAIN METHODS
# ============================================================================

func _cement_current_run():
	"""Lock in loot/gold/exp from the current dungeon so the next dungeon's
	death rollback won't touch them. Run affixes (dice temp + stat) are
	cleaned up — they are temporary power for one dungeon only."""
	if not _player or not current_run: return

	# 1. Run affixes are temporary — clean them up between chain links
	_cleanup_temp_effects()

	# 2. Items/consumables: clear tracking so death rollback won't remove them
	#    (the items themselves stay in the player's inventory)
	current_run.items_earned.clear()
	current_run.consumables_earned.clear()

	print("[Chain] Cemented run: %s" % current_run.definition.dungeon_name)

func _start_next_chain_dungeon(next_def: DungeonDefinition):
	"""Transition to the next dungeon in the chain without exiting."""
	# Clear old map (no temp cleanup — already cemented)
	if dungeon_map:
		dungeon_map.clear_map()

	# Generate fresh run with new gold snapshot
	current_run = _generator.generate(next_def)
	current_run.start(next_def, _player.gold)

	# Update UI
	if dungeon_name_label:
		dungeon_name_label.text = next_def.dungeon_name
	_update_floor_ui()

	if dungeon_map:
		dungeon_map.build_map(current_run)

	dungeon_started.emit(next_def)

	# Offer entry affix for new dungeon
	if next_def.has_run_affix_pool() and next_def.offer_on_entry:
		_pending_advance_node = null
		_pending_boss_complete = false
		_show_run_affix_choice("entry")
	else:
		_enter_start_node()

func _apply_chain_clear_rewards():
	"""Grant chain-level bonus rewards on full chain completion."""
	if not _chain_runner or not _chain_runner.chain or not _player: return
	var chain = _chain_runner.chain
	if chain.chain_clear_gold > 0:
		_player.add_gold(chain.chain_clear_gold)
		GameEventBus.emit_gold_gained(chain.chain_clear_gold, _get_portrait())
	if chain.chain_clear_exp > 0:
		_player.add_experience(chain.chain_clear_exp)
		GameEventBus.emit_exp_gained(chain.chain_clear_exp, _get_portrait())
	if chain.chain_clear_item and _player:
		var item_level = _chain_runner.get_current_definition().dungeon_level if _chain_runner.get_current_definition() else 1
		var region = _chain_runner.get_current_definition().dungeon_region if _chain_runner.get_current_definition() else 1
		var result = LootManager.generate_drop(chain.chain_clear_item, item_level, region)
		var item = result.get("item") as EquippableItem
		if item:
			_player.add_to_inventory(item)
			GameEventBus.emit_item_gained(item.item_name, item.rarity, _get_portrait())


func _apply_theme(definition: DungeonDefinition):
	pass

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


func _get_portrait() -> Control:
	if GameManager and GameManager.game_root:
		return GameManager.game_root.get_node_or_null(
			"PersistentUILayer/PortraitVBox/PortraitContainer/PortraitTexture")
	return null


func _is_first_cleared(dungeon_id: String) -> bool:
	return GameManager.completed_encounters.has("dungeon_" + dungeon_id) if GameManager else false

func _mark_first_cleared(dungeon_id: String):
	if GameManager:
		GameManager.completed_encounters.append("dungeon_" + dungeon_id)
