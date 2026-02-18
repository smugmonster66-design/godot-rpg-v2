# res://scripts/game/combat_manager.gd
# Combat manager - handles combat flow with encounter spawning
extends Node2D

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var encounter_spawner: EncounterSpawner = $EncounterSpawner
@onready var animation_player: CombatAnimationPlayer = $CombatAnimationPlayer


var player_combatant: Combatant = null
var enemy_combatants: Array[Combatant] = []
var combat_ui = null
var battlefield_tracker: BattlefieldTracker = null
var proc_processor: AffixProcProcessor = null
var event_bus: CombatEventBus = null
# ============================================================================
# STATE
# ============================================================================
var player: Player = null
var current_encounter: CombatEncounter = null
var _combat_initialized: bool = false  # Add this line

enum CombatState {
	INITIALIZING,
	PLAYER_TURN,
	ENEMY_TURN,
	ANIMATING,
	ENDED
}

enum TurnPhase {
	NONE,       ## Not the player's turn
	PREP,       ## Player can open menu / swap gear
	ACTION,     ## Hand rolled, menu locked, placing dice
}

var combat_state: CombatState = CombatState.INITIALIZING
var turn_phase: TurnPhase = TurnPhase.NONE

# Per-combat charge tracker — prevents charge reset exploits from re-equipping
# Key: action resource_path (String), Value: charges consumed (int)
var combat_charge_tracker: Dictionary = {}



## v5: Track how many unique enemies the player hit this turn (for Crucible's Gift)
var _enemies_hit_this_turn: Array = []
var _enemies_hit_last_turn: int = 0


# Turn order
var turn_order: Array[Combatant] = []
var current_turn_index: int = 0
var current_round: int = 0

# ============================================================================
# SIGNALS
# ============================================================================
signal combat_ended(player_won: bool)
signal turn_started(combatant: Combatant, is_player: bool)
signal round_started(round_number: int)
signal turn_phase_changed(phase: TurnPhase)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	
	add_to_group("combat_manager")
	
	print("⚔️ CombatManager _ready")
	
	# Find nodes
	find_combat_nodes()
	
	# Setup encounter spawner
	setup_encounter_spawner()
	
	# Setup UI connections
	setup_ui_connections()
	
	# Check for pending encounter from GameManager
	await get_tree().process_frame
	check_pending_encounter()

func find_combat_nodes():
	"""Find combat nodes in the scene tree"""
	print("🔍 Finding combat nodes...")
	
	# Find player combatant
	player_combatant = find_child("PlayerCombatant", true, false) as Combatant
	if player_combatant:
		player_combatant.is_player_controlled = true
		print("  ✅ Player combatant found")
	else:
		push_error("  ❌ Player combatant NOT FOUND")
	
	# Find encounter spawner
	if not encounter_spawner:
		encounter_spawner = find_child("EncounterSpawner", true, false) as EncounterSpawner
	if not encounter_spawner:
		# Create one if not found
		encounter_spawner = EncounterSpawner.new()
		encounter_spawner.name = "EncounterSpawner"
		add_child(encounter_spawner)
		print("  ✅ Created EncounterSpawner")
	else:
		print("  ✅ EncounterSpawner found")
	
	# Find UI
	combat_ui = find_child("CombatUILayer", true, false)
	if not combat_ui:
		combat_ui = find_child("CombatUI", true, false)
	print("  CombatUI: %s" % ("✓" if combat_ui else "✗"))

func setup_encounter_spawner():
	"""Setup encounter spawner signals"""
	if encounter_spawner:
		if not encounter_spawner.enemies_spawned.is_connected(_on_enemies_spawned):
			encounter_spawner.enemies_spawned.connect(_on_enemies_spawned)
		if not encounter_spawner.spawn_failed.is_connected(_on_spawn_failed):
			encounter_spawner.spawn_failed.connect(_on_spawn_failed)

func setup_ui_connections():
	"""Setup combat UI signal connections"""
	if combat_ui:
		if combat_ui.has_signal("action_confirmed") and not combat_ui.action_confirmed.is_connected(_on_action_confirmed):
			combat_ui.action_confirmed.connect(_on_action_confirmed)
		if combat_ui.has_signal("turn_ended") and not combat_ui.turn_ended.is_connected(_on_player_end_turn):
			combat_ui.turn_ended.connect(_on_player_end_turn)
	
	
	# v4 — Status Thresholds: Connect threshold signals
	_connect_status_threshold_signals()

func check_pending_encounter():
	"""Check if GameManager has a pending encounter"""
	if GameManager and GameManager.pending_encounter:
		current_encounter = GameManager.pending_encounter
		GameManager.pending_encounter = null
		print("⚔️ Found pending encounter: %s" % current_encounter.encounter_name)
		
		if GameManager.player:
			initialize_combat(GameManager.player)



func _execute_conditional_riders(action_resource: Action,
		source: Combatant, targets: Array) -> void:
	if not action_resource.has_meta("conditional_riders"):
		return
	
	var riders: Array = action_resource.get_meta("conditional_riders")
	
	for rider in riders:
		var condition = rider.get("condition")
		var effect: ActionEffect = rider.get("effect")
		
		if not effect:
			continue
		
		# Check rider condition against current combat state
		var should_fire := true
		var combat_context := _build_combat_context(source, targets)
		if condition and condition.has_method("evaluate"):
			should_fire = condition.evaluate(combat_context)
		
		if should_fire:
			var rider_results := effect.execute(
				source, targets, [], combat_context)
			_process_action_effect_results(rider_results, source)



func _execute_action(action_data: Dictionary, source: Node2D, targets: Array[Combatant]):
	var animation_set = action_data.get("animation_set") as CombatAnimationSet
	
	# Get positions
	var source_pos = source.global_position
	var target_positions: Array[Vector2] = []
	var target_nodes: Array[Node2D] = []
	
	for target in targets:
		target_positions.append(target.global_position)
		target_nodes.append(target)
	
	# Use weakrefs to avoid lambda capture errors if nodes are freed mid-animation
	var source_ref = weakref(source)
	var target_refs: Array = []
	for t in targets:
		target_refs.append(weakref(t))
	
	var apply_effect_callable = func():
		var s = source_ref.get_ref()
		if not s or not is_instance_valid(s):
			return
		var live_targets: Array[Combatant] = []
		for ref in target_refs:
			var t = ref.get_ref()
			if t and is_instance_valid(t):
				live_targets.append(t)
		_apply_action_effect(action_data, s, live_targets)
	
	animation_player.apply_effect_now.connect(apply_effect_callable, CONNECT_ONE_SHOT)
	
	# Play animation sequence
	await animation_player.play_action_animation(
		animation_set,
		source_pos,
		target_positions,
		target_nodes
	)



# ============================================================================
# ENCOUNTER SPAWNING
# ============================================================================

func _on_enemies_spawned(enemies: Array[Combatant]):
	"""Handle enemies spawned by EncounterSpawner"""
	enemy_combatants = enemies
	
	# Connect signals for each enemy
	for i in range(enemy_combatants.size()):
		_connect_enemy_signals(enemy_combatants[i], i)
	
	print("⚔️ %d enemies ready for combat" % enemy_combatants.size())

func _on_spawn_failed(reason: String):
	"""Handle spawn failure"""
	push_error("⚔️ Encounter spawn failed: %s" % reason)

func _connect_enemy_signals(enemy: Combatant, index: int):
	"""Connect signals for an enemy combatant"""
	if not enemy.health_changed.is_connected(_on_enemy_health_changed):
		enemy.health_changed.connect(_on_enemy_health_changed.bind(index))
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	if not enemy.turn_completed.is_connected(_on_combatant_turn_completed):
		enemy.turn_completed.connect(_on_combatant_turn_completed.bind(enemy))

# ============================================================================
# COMBAT INITIALIZATION
# ============================================================================

func initialize_combat(p_player: Player):
	"""Initialize combat with player data"""
	print("⚔️ Initializing combat...")
	player = p_player
	combat_state = CombatState.INITIALIZING
	
	event_bus = CombatEventBus.new()
	event_bus.name = "CombatEventBus"
	event_bus.debug_logging = OS.is_debug_build()  # optional
	add_child(event_bus)
	print("  ✅ CombatEventBus initialized")
	
	
	# Spawn enemies from encounter if we have one
	if current_encounter and encounter_spawner:
		encounter_spawner.spawn_encounter(current_encounter)
	
	if not battlefield_tracker:
		battlefield_tracker = BattlefieldTracker.new()
		battlefield_tracker.name = "BattlefieldTracker"
		add_child(battlefield_tracker)
	
	
	# Continue initialization after spawning
	await get_tree().process_frame
	_finalize_combat_init(p_player)

func _finalize_combat_init(p_player: Player):
	"""Finalize combat initialization after enemies are ready"""
	if _combat_initialized:
		print("⚠️ Combat already initialized, skipping")
		return
	_combat_initialized = true
	
	player = p_player
	
	
	
	# --- Reactive Animation Event Bus ---
	event_bus = CombatEventBus.new()
	event_bus.name = "CombatEventBus"
	event_bus.debug_logging = OS.is_debug_build()
	add_child(event_bus)
	event_bus.emit_combat_started()
	print("  ✅ CombatEventBus initialized")
	
	
	# Sync player to combatant
	_sync_player_to_combatant()
	
	# Connect player combatant signals
	if player_combatant:
		if not player_combatant.health_changed.is_connected(_on_player_health_changed):
			player_combatant.health_changed.connect(_on_player_health_changed)
		if not player_combatant.died.is_connected(_on_player_died):
			player_combatant.died.connect(_on_player_died)
	
	# Build turn order
	_build_turn_order()
	
	# Initialize UI
	if combat_ui:
		combat_ui.initialize_ui(player, enemy_combatants)
	
	# Connect cleanup
	if not combat_ended.is_connected(_on_combat_ended):
		combat_ended.connect(_on_combat_ended)
	
	# Connect battlefield tracker signals
	if battlefield_tracker:
		if not battlefield_tracker.channel_released.is_connected(_on_channel_released):
			battlefield_tracker.channel_released.connect(_on_channel_released)
		if not battlefield_tracker.counter_triggered.is_connected(_on_counter_triggered):
			battlefield_tracker.counter_triggered.connect(_on_counter_triggered)
	
	# Reset per-combat charge tracker
	combat_charge_tracker.clear()
	
	# --- MANA: Refill mana pool at combat start ---
	if player and player.has_mana_pool():
		if player.mana_pool.refill_on_combat_start:
			player.mana_pool.refill()
			print("  🔮 Mana pool refilled: %d / %d" % [
				player.mana_pool.current_mana, player.mana_pool.max_mana])
	# --- END MANA ---
	
	
	
	# Initialize proc processor and fire combat-start procs
	if not proc_processor:
		proc_processor = AffixProcProcessor.new()
	if player and player.affix_manager:
		proc_processor.on_combat_start(player.affix_manager)
		var combat_start_results = proc_processor.process_combat_start(
			player.affix_manager, _build_proc_context())
		_apply_proc_results(combat_start_results)
	
	print("⚔️ Combat initialization complete")
	print("  Turn order: %s" % [turn_order.map(func(c): return c.combatant_name)])
	
	
	# v5: Connect threshold triggers for Flashpoint / Pyroclastic Flow
	if player.status_tracker:
		player.status_tracker.set_source_affix_manager(player.affix_manager)
	# For ENEMY status trackers — connect to their threshold signals:
	for i in range(enemy_combatants.size()):
		var enemy = enemy_combatants[i]
		var tracker = _get_status_tracker(enemy)
		if tracker:
			tracker.set_source_affix_manager(player.affix_manager)
			if not tracker.status_threshold_triggered.is_connected(_on_enemy_threshold_triggered):
				tracker.status_threshold_triggered.connect(
					_on_enemy_threshold_triggered.bind(enemy))
	
	
	# --- Reactive Animation: Bridge status signals to event bus ---
	if event_bus:
		_connect_status_event_bridges()

	# Brief delay for scene transition (fade-from-black is ~0.7s)
	if GameManager.game_root and GameManager.game_root.is_in_dungeon:
		await get_tree().create_timer(0.5).timeout

	print("🔍 BEFORE drop-in check: combat_ui=%s, enemy_panel=%s" % [
		combat_ui != null,
		combat_ui.enemy_panel != null if combat_ui else "N/A"])

	if combat_ui and combat_ui.enemy_panel and combat_ui.enemy_panel.has_method("play_drop_in_animation"):
		print("🔍 CALLING play_drop_in_animation()")
		await combat_ui.enemy_panel.play_drop_in_animation()
		print("🔍 RETURNED from play_drop_in_animation()")
	else:
		print("🔍 SKIPPED drop-in — condition failed")

	print("🔍 CALLING _start_round()")
	_start_round()


func _connect_status_event_bridges():
	"""Bridge StatusTracker signals to CombatEventBus for reactive animations.
	Keeps StatusTracker decoupled — it doesn't know about the event bus."""
	if player and player.status_tracker:
		player.status_tracker.status_applied.connect(
			func(sid, inst):
				if event_bus:
					var visual = _get_combatant_visual(player_combatant)
					var affix: StatusAffix = inst.get("status_affix")
					if visual and affix:
						event_bus.emit_status_applied(visual, affix.status_name, inst.get("stacks", 1), affix.cleanse_tags)
		)
		player.status_tracker.status_removed.connect(
			func(sid):
				if event_bus:
					var visual = _get_combatant_visual(player_combatant)
					if visual:
						event_bus.emit_status_removed(visual, sid)
		)
	
	for enemy in enemy_combatants:
		if enemy.has_node("StatusTracker"):
			var tracker: StatusTracker = enemy.get_node("StatusTracker")
			tracker.status_applied.connect(
				func(sid, inst):
					if event_bus:
						var visual = _get_combatant_visual(enemy)
						var affix: StatusAffix = inst.get("status_affix")
						if visual and affix:
							event_bus.emit_status_applied(visual, affix.affix_name, inst.get("stacks", 1), affix.cleanse_tags)
			)
			tracker.status_removed.connect(
				func(sid):
					if event_bus:
						var visual = _get_combatant_visual(enemy)
						if visual:
							event_bus.emit_status_removed(visual, sid)
			)


func _sync_player_to_combatant():
	"""Sync player stats to combatant"""
	if player and player_combatant:
		player_combatant.current_health = player.current_hp
		player_combatant.max_health = player.max_hp
		player_combatant.combatant_name = "Player"
		player_combatant.update_display()
		print("  ✅ Synced player to combatant")

func _build_turn_order():
	"""Build the turn order array"""
	turn_order.clear()
	
	# Check encounter settings for turn order
	var player_first = true
	if current_encounter:
		player_first = current_encounter.player_starts_first
	
	if player_first:
		turn_order.append(player_combatant)
		for enemy in enemy_combatants:
			if enemy.is_alive():
				turn_order.append(enemy)
	else:
		for enemy in enemy_combatants:
			if enemy.is_alive():
				turn_order.append(enemy)
		turn_order.append(player_combatant)

# ============================================================================
# TURN ORDER MANAGEMENT
# ============================================================================

func _start_round():
	"""Start a new round"""
	current_round += 1
	current_turn_index = 0
	
	print("\n⚔️ === ROUND %d ===" % current_round)
	
	# Check turn limit
	if current_encounter and current_encounter.turn_limit > 0:
		if current_round > current_encounter.turn_limit:
			print("⏰ Turn limit reached!")
			end_combat(false)
			return
	
	round_started.emit(current_round)
	_start_current_turn()

func _start_current_turn():
	"""Start the current combatant's turn"""
	# Skip dead combatants
	while current_turn_index < turn_order.size():
		var combatant = turn_order[current_turn_index]
		if combatant.is_alive():
			break
		current_turn_index += 1
	
	# Check if round is over
	if current_turn_index >= turn_order.size():
		_end_round()
		return
	
	var combatant = turn_order[current_turn_index]
	var is_player = (combatant == player_combatant)
	
	print("\n🎲 %s's turn" % combatant.combatant_name)
	turn_started.emit(combatant, is_player)
	
	if is_player:
		_start_player_turn()
	else:
		_start_enemy_turn(combatant)

func _end_current_turn():
	"""Move to next turn"""
	# --- BATTLEFIELD: Clean up expired counters at turn end ---
	if battlefield_tracker:
		battlefield_tracker.process_turn_end()
	# --- END BATTLEFIELD ---
	
	current_turn_index += 1
	_start_current_turn()

func _end_round():
	"""End round and check for combat end or start new round"""
	print("\n⚔️ === ROUND %d ENDED ===" % current_round)
	
	if _check_combat_end():
		return
	
	_start_round()

func _check_combat_end() -> bool:
	"""Check if combat should end"""
	if not player_combatant.is_alive():
		end_combat(false)
		return true
	
	var all_dead = true
	for enemy in enemy_combatants:
		if enemy.is_alive():
			all_dead = false
			break
	
	if all_dead:
		end_combat(true)
		return true
	
	return false






# ============================================================================
# PLAYER TURN
# ============================================================================

func _start_player_turn():
	"""Start player's turn — enters PREP phase first"""
	combat_state = CombatState.PLAYER_TURN

	# v5: Update multi-target tracking for Crucible's Gift
	_enemies_hit_last_turn = _enemies_hit_this_turn.size()
	_enemies_hit_this_turn.clear()

	# --- STATUS: Start-of-turn processing ---
	if player:
		var tick_results = player.status_tracker.process_turn_start()
		await _apply_status_tick_results(player, player_combatant, tick_results)

		# Check if player died from DoT damage
		if not player_combatant.is_alive():
			_check_player_death()
			return
	
	# --- END STATUS ---



	if event_bus:
			event_bus.emit_round_started(current_round)



	# --- PROC: Turn-start procs ---
	if player and player.affix_manager and proc_processor:
		var turn_start_results = proc_processor.process_turn_start(
			player.affix_manager, _build_proc_context())
		_apply_proc_results(turn_start_results)
	# --- END PROC ---



	
	# --- BATTLEFIELD: Process channels at player turn start ---
	if battlefield_tracker and battlefield_tracker.has_any_effects():
		var alive_enemies: Array = []
		for e in enemy_combatants:
			if e.is_alive():
				alive_enemies.append(e)
		var bf_results = battlefield_tracker.process_turn_start(
			alive_enemies, [player_combatant])
		for r in bf_results:
			_process_single_battlefield_result(r)
		
		# Check if any enemies died from channel releases
		if _check_combat_end():
			return
	# --- END BATTLEFIELD ---

	# Enter prep phase — menu is accessible, hand is NOT rolled yet
	turn_phase = TurnPhase.PREP
	turn_phase_changed.emit(TurnPhase.PREP)

	if combat_ui:
		combat_ui.enter_prep_phase()

func _on_roll_pressed():
	"""Player pressed Roll — transition from PREP to ACTION phase"""
	if combat_state != CombatState.PLAYER_TURN or turn_phase != TurnPhase.PREP:
		return

	print("🎲 Player pressed Roll — entering ACTION phase")

	# Lock the menu
	turn_phase = TurnPhase.ACTION
	turn_phase_changed.emit(TurnPhase.ACTION)

	# Force-close menu if open
	if GameManager.game_root and GameManager.game_root.player_menu:
		var menu = GameManager.game_root.player_menu
		if menu.visible and menu.has_method("close_menu"):
			menu.close_menu()

	# Now do everything the old _start_player_turn did after status processing
	if player and player.dice_pool:
		# Clear stale action field dice BEFORE rolling new hand
		if combat_ui:
			for field in combat_ui.action_fields:
				if is_instance_valid(field) and field.placed_dice.size() > 0:
					field.clear_dice()

		# Tell DicePoolDisplay to skip its built-in entrance animation
		if combat_ui and combat_ui.dice_pool_display:
			combat_ui.dice_pool_display.hide_for_roll_animation = true

		# Roll the hand
		player.dice_pool.roll_hand()
		
		

		# Wait one frame for refresh to create visuals
		await get_tree().process_frame
		if combat_ui and combat_ui.roll_animator:
			combat_ui.roll_animator.play_roll_sequence()
	else:
		print("  ⚠️ No player or dice_pool!")

	# Wait for the roll animation to finish before enabling UI
	if combat_ui and combat_ui.roll_animator:
		await combat_ui.roll_animator.roll_animation_complete
	else:
		var dice_count = player.dice_pool.hand.size() if player and player.dice_pool else 0
		var animation_duration = dice_count * 0.08 + 0.25
		await get_tree().create_timer(animation_duration).timeout

	if combat_ui:
		combat_ui.enter_action_phase()
		
	# Enable mana die dragging during action phase
	if combat_ui and combat_ui.has_method("set_mana_drag_enabled"):
		combat_ui.set_mana_drag_enabled(true)





func _on_player_end_turn():
	"""Player ended their turn"""
	if combat_state != CombatState.PLAYER_TURN:
		return
	
	
	turn_phase = TurnPhase.NONE
	turn_phase_changed.emit(TurnPhase.NONE)
	
	
	if combat_ui and combat_ui.has_method("set_mana_drag_enabled"):
		combat_ui.set_mana_drag_enabled(false)
	
	print("🎮 Player ended turn")
	
	# --- STATUS: End-of-turn processing ---
	if player and player.status_tracker:
		var tick_results = player.status_tracker.process_turn_start()
		await _apply_status_tick_results(player, player_combatant, tick_results)
		
		if not player_combatant.is_alive():
			_check_player_death()
			return
	# --- END STATUS ---
	
	# --- PROC: Turn-end procs ---
	if player and player.affix_manager and proc_processor:
		var turn_end_results = proc_processor.process_turn_end(
			player.affix_manager, _build_proc_context())
		_apply_proc_results(turn_end_results)
	# --- END PROC ---
	
	# Tick temp action field durations
	if combat_ui and combat_ui.has_method("tick_temp_action_fields"):
		combat_ui.tick_temp_action_fields()
	
	_end_current_turn()



func _on_action_confirmed(action_data: Dictionary):
	"""Player confirmed an action - plays animation then applies effect"""
	if combat_state != CombatState.PLAYER_TURN:
		return
	
	var action_name = action_data.get("name", "Unknown")
	var action_type = action_data.get("action_type", 0)
	
	# Get target for damage calculation
	var target = action_data.get("target", null) as Combatant
	var target_index = action_data.get("target_index", 0)
	
	# Fallback to first living enemy if no target specified
	if not target or not target.is_alive():
		target = _get_first_living_enemy()
		target_index = enemy_combatants.find(target)
	
	# Build targets array for _apply_action_effect
	var targets: Array = [target] if target else []
	
	print("⚔️ Player uses %s (type=%d)" % [action_name, action_type])
	
	# Get animation set from action_resource
	var animation_set: CombatAnimationSet = null
	var action_resource = action_data.get("action_resource") as Action
	if action_resource:
		# Check for element-specific animation override from placed dice
		var placed = action_data.get("placed_dice", []) as Array
		if placed.size() > 0 and action_resource.has_method("get_animation_for_element"):
			var first_die = placed[0] as DieResource
			if first_die:
				var die_elem = first_die.get_effective_element()
				var dt = DieResource.ELEMENT_TO_DAMAGE_TYPE.get(die_elem, -1)
				if dt >= 0:
					animation_set = action_resource.get_animation_for_element(dt)
		# Fallback to default animation_set
		if not animation_set and action_resource.get("animation_set"):
			animation_set = action_resource.animation_set
	
	# Get the action field that was used (for source position)
	var action_field: ActionField = null
	if combat_ui:
		action_field = combat_ui.find_action_field_by_name(action_name)
	
	# Check if we have animation player and animation set
	var anim_player = _get_combat_animation_player()
	
	if animation_set and anim_player:
		await _play_action_with_animation(action_data, targets, target_index, animation_set, anim_player, action_field)
	else:
		_apply_action_effect(action_data, player_combatant, targets)



func _get_combat_animation_player():
	"""Find the CombatAnimationPlayer node"""
	if has_node("CombatAnimationPlayer"):
		return get_node("CombatAnimationPlayer")
	return find_child("CombatAnimationPlayer", true, false)


func _play_action_with_animation(action_data: Dictionary, targets: Array, target_index: int,
		animation_set: CombatAnimationSet, anim_player, action_field: ActionField) -> void:
	"""Play action animation and apply effect at the right timing"""
	
	combat_state = CombatState.ANIMATING
	
	# === GET SOURCE POSITION (Action field die slot center) ===
	var source_pos: Vector2 = Vector2.ZERO
	if action_field and action_field.die_slot_panels.size() > 0:
		# Get center of first die slot
		var first_slot = action_field.die_slot_panels[0]
		source_pos = first_slot.global_position + first_slot.size / 2
	elif player_combatant:
		# Fallback to player combatant position
		source_pos = player_combatant.global_position
	
	
	# === DEBUG: Verify source position ===
	print("🔍 SOURCE POS DEBUG ========================")
	print("  action_field: %s" % (action_field.name if action_field else "NULL"))
	if action_field:
		print("  action_field.global_position: %s" % action_field.global_position)
		print("  action_field.size: %s" % action_field.size)
		if action_field.die_slot_panels.size() > 0:
			var slot = action_field.die_slot_panels[0]
			print("  first_slot.global_position: %s" % slot.global_position)
			print("  first_slot.size: %s" % slot.size)
			print("  computed source_pos: %s" % source_pos)
		else:
			print("  ⚠️  No die_slot_panels!")
	else:
		print("  ⚠️  No action_field found!")
	print("  Final source_pos: %s" % source_pos)
	print("============================================")
	
	
	
	# === GET TARGET POSITIONS (Enemy portrait centers in UI) ===
	var target_positions: Array[Vector2] = []
	var target_nodes: Array[Node2D] = []
	
	# Check if this is an AoE attack (targets all enemies)
	var is_aoe = false
	var action_resource = action_data.get("action_resource") as Action
	if action_resource and action_resource.effects.size() > 0:
		for effect in action_resource.effects:
			if effect and effect.target == ActionEffect.TargetType.ALL_ENEMIES:
				is_aoe = true
				break
	
	if is_aoe:
		# Target ALL enemy portraits
		for i in range(enemy_combatants.size()):
			var enemy = enemy_combatants[i]
			if enemy and enemy.is_alive():
				var portrait_pos = _get_enemy_portrait_position(i)
				if portrait_pos != Vector2.ZERO:
					target_positions.append(portrait_pos)
					target_nodes.append(enemy)
	else:
		# Single target - get portrait position for selected enemy
		var portrait_pos = _get_enemy_portrait_position(target_index)
		if portrait_pos != Vector2.ZERO:
			target_positions.append(portrait_pos)
		elif targets.size() > 0 and targets[0] is Combatant:
			# Fallback to combatant position
			target_positions.append(targets[0].global_position)
		
		for t in targets:
			if t is Node2D:
				target_nodes.append(t)
	
	print("🎬 Animation: source=%s, targets=%d positions" % [source_pos, target_positions.size()])
	
	# Track if effect has been applied
	var effect_applied = false
	
	# Create callback — use weakrefs to avoid lambda capture errors
	# if nodes are freed before the animation callback fires
	var player_ref = weakref(player_combatant)
	var target_refs: Array = []
	for t in targets:
		target_refs.append(weakref(t))
	
	var apply_effect_callback = func():
		if effect_applied:
			return
		effect_applied = true
		var p = player_ref.get_ref()
		if not p or not is_instance_valid(p):
			return
		var live_targets: Array = []
		for ref in target_refs:
			var t = ref.get_ref()
			if t and is_instance_valid(t):
				live_targets.append(t)
		_apply_action_effect(action_data, p, live_targets)
	
	# Connect to apply_effect_now signal if it exists
	if anim_player.has_signal("apply_effect_now"):
		if not anim_player.apply_effect_now.is_connected(apply_effect_callback):
			anim_player.apply_effect_now.connect(apply_effect_callback, CONNECT_ONE_SHOT)
	
	# Play the animation sequence
	if anim_player.has_method("play_action_animation"):
		await anim_player.play_action_animation(animation_set, source_pos, target_positions, target_nodes)
	else:
		push_warning("CombatAnimationPlayer missing play_action_animation method")
		await get_tree().create_timer(0.5).timeout
	
	
	# If effect wasn't applied by signal, apply now
	if not effect_applied:
		effect_applied = true
		var p = player_ref.get_ref()
		if p and is_instance_valid(p):
			var live_targets: Array = []
			for ref in target_refs:
				var t = ref.get_ref()
				if t and is_instance_valid(t):
					live_targets.append(t)
			_apply_action_effect(action_data, p, live_targets)
	
	combat_state = CombatState.PLAYER_TURN

func _get_enemy_portrait_position(enemy_index: int) -> Vector2:
	"""Get the center position of an enemy's portrait in the UI.
	Uses enemy_panel.get_enemy_visual() which translates array index → slot."""
	if not combat_ui or not combat_ui.enemy_panel:
		return Vector2.ZERO

	var slot = combat_ui.enemy_panel.get_enemy_visual(enemy_index)
	if not slot or not slot is EnemySlot or not slot.portrait_rect:
		return Vector2.ZERO

	var portrait = slot.portrait_rect
	return portrait.global_position + portrait.size / 2



# ============================================================================
# ENEMY TURN
# ============================================================================

func _start_enemy_turn(enemy: Combatant):
	"""Start an enemy's turn"""
	combat_state = CombatState.ENEMY_TURN

	# --- STATUS: Enemy start-of-turn processing ---
	if enemy.has_node("StatusTracker"):
		var tracker: StatusTracker = enemy.get_node("StatusTracker")
		var tick_results = tracker.process_turn_start()
		await _apply_status_tick_results(null, enemy, tick_results)

		if not enemy.is_alive():
			_check_enemy_death(enemy)
			return
	# --- END STATUS ---

	if combat_ui and combat_ui.has_method("set_player_turn"):
		combat_ui.set_player_turn(false)

	# Tell enemy panel to create dice hidden (same pattern as player)
	if combat_ui and combat_ui.enemy_panel:
		combat_ui.enemy_panel.hide_for_roll_animation = true

	enemy.start_turn()

	if combat_ui and combat_ui.has_method("show_enemy_hand"):
		combat_ui.show_enemy_hand(enemy)
		
		
	# Extra frames for EnemyDiceHand layout propagation (was hidden, now visible)
	await get_tree().process_frame
	await get_tree().process_frame

	# Small delay to let UI update
	await get_tree().create_timer(0.3).timeout

	# Play roll animation - projectiles come from the enemy's portrait
	if combat_ui and combat_ui.roll_animator and combat_ui.enemy_panel:
		var ep = combat_ui.enemy_panel
		var slot_idx = ep.get_slot_for_combatant(enemy)
		var source_pos = Vector2.ZERO

		if slot_idx >= 0 and slot_idx < ep.enemy_slots.size():
			var slot: EnemySlot = ep.enemy_slots[slot_idx]
			if slot.portrait_rect:
				source_pos = slot.portrait_rect.global_position + slot.portrait_rect.size / 2.0

		await get_tree().process_frame

		await combat_ui.roll_animator.play_roll_sequence_for(
			ep,
			ep.hand_dice_visuals,
			source_pos
		)

	_process_enemy_turn(enemy)


func _process_enemy_turn(enemy: Combatant):
	"""Process enemy AI decisions"""
	if not enemy.is_alive():
		_finish_enemy_turn(enemy)
		return
	
	if not enemy.has_usable_dice():
		print("  %s has no usable dice" % enemy.combatant_name)
		_finish_enemy_turn(enemy)
		return
	
	var decision = EnemyAI.decide(
		enemy.actions,
		enemy.get_available_dice(),
		enemy.ai_strategy
	)
	
	if not decision:
		print("  %s couldn't decide" % enemy.combatant_name)
		_finish_enemy_turn(enemy)
		return
	
	print("  🤖 %s decides: %s with %d dice" % [
		enemy.combatant_name,
		decision.action.get("name", "?"),
		decision.dice.size()
	])
	
	_animate_enemy_action(enemy, decision)

func _animate_enemy_action(enemy: Combatant, decision: EnemyAI.Decision):
	"""Animate enemy placing dice and executing action"""
	combat_state = CombatState.ANIMATING
	
	var action_name = decision.action.get("name", "Attack")
	
	enemy.prepare_action(decision.action, decision.dice)
	
	# Highlight the action field being used
	if combat_ui and combat_ui.has_method("highlight_enemy_action"):
		combat_ui.highlight_enemy_action(action_name)
	
	# Animate each die being used
	for i in range(decision.dice.size()):
		var die = decision.dice[i]
		
		print("  🎲 Looking for visual for: %s" % die.display_name)
		
		# Find the visual that matches THIS die
		var die_visual: Control = null
		if combat_ui and combat_ui.enemy_panel:
			print("    hand_dice_visuals count: %d" % combat_ui.enemy_panel.hand_dice_visuals.size())
			for vis in combat_ui.enemy_panel.hand_dice_visuals:
				if is_instance_valid(vis) and vis.visible and vis.has_method("get_die"):
					var vis_die = vis.get_die()
					# Match by reference OR by display_name as fallback
					if vis_die == die or (vis_die and vis_die.display_name == die.display_name):
						die_visual = vis
						print("    ✅ Found matching visual")
						break
		
		# Fallback: if no match, find first visible die visual
		if not die_visual and combat_ui and combat_ui.enemy_panel:
			for vis in combat_ui.enemy_panel.hand_dice_visuals:
				if is_instance_valid(vis) and vis.visible:
					die_visual = vis
					print("    ⚠️ Using fallback (first visible)")
					break
		
		print("    Found visual: %s" % (die_visual != null))
		
		# Animate die to action field
		if combat_ui and combat_ui.has_method("animate_die_to_action_field"):
			await combat_ui.animate_die_to_action_field(die_visual, action_name, die)
		else:
			await get_tree().create_timer(enemy.dice_drag_duration).timeout
		
		enemy.consume_action_die(die)
	
	# Brief pause before action executes
	await get_tree().create_timer(0.3).timeout
	
	# Execute the action
	var action_data = decision.action.duplicate()
	action_data["placed_dice"] = decision.dice
	
	var action_type = decision.action.get("action_type", 0)
	
	match action_type:
		0:  # ATTACK
			var damage = _calculate_damage(action_data, enemy, player)
			print("  💥 %s attacks player for %d!" % [enemy.combatant_name, damage])
			if player_combatant:
				player_combatant.take_damage(damage)
				_update_player_health()
				
				# --- PROC: On-take-damage procs ---
				if player and player.affix_manager and proc_processor:
					var take_dmg_results = proc_processor.process_on_take_damage(
						player.affix_manager, _build_proc_context({
							"damage_taken": damage,
						}))
					_apply_proc_results(take_dmg_results)
				# --- END PROC ---
				
				# --- BATTLEFIELD: Check counter-attacks when player takes damage ---
				if battlefield_tracker and battlefield_tracker.has_pending_counters():
					var alive_enemies: Array = []
					for e in enemy_combatants:
						if e.is_alive():
							alive_enemies.append(e)
					var counter_results = battlefield_tracker.on_damage_taken(
						player_combatant, enemy, damage,
						alive_enemies, [player_combatant])
					for r in counter_results:
						_process_single_battlefield_result(r)
				# --- END BATTLEFIELD ---
		1:  # DEFEND
			print("  🛡️ %s defends" % enemy.combatant_name)
			# Apply armor/barrier buff
		2:  # HEAL
			var heal_amount = _calculate_damage(action_data, enemy, null)
			print("  💚 %s heals for %d" % [enemy.combatant_name, heal_amount])
			enemy.heal(heal_amount)
			if combat_ui and combat_ui.enemy_panel:
				var enemy_index = combat_ui.enemy_panel.get_enemy_index(enemy)
				_update_enemy_health(enemy_index)
		3:  # SPECIAL
			print("  ✨ %s uses special ability" % enemy.combatant_name)
	
	# Animate action confirm (clear dice from field)
	if combat_ui and combat_ui.has_method("animate_enemy_action_confirm"):
		await combat_ui.animate_enemy_action_confirm(action_name)
	
	# Small delay before finishing turn
	await get_tree().create_timer(0.2).timeout
	
	_finish_enemy_turn(enemy)


func _finish_enemy_turn(enemy: Combatant):
	"""Finish enemy's turn"""
	print("  %s's turn complete" % enemy.combatant_name)
	
	if combat_ui and combat_ui.has_method("hide_enemy_hand"):
		combat_ui.hide_enemy_hand()
	
	# --- STATUS: Enemy end-of-turn processing ---
	if enemy.has_node("StatusTracker"):
		var tracker: StatusTracker = enemy.get_node("StatusTracker")
		var tick_results = tracker.process_turn_end()
		await _apply_status_tick_results(null, enemy, tick_results)
		
		if not enemy.is_alive():
			_check_enemy_death(enemy)
			return
	# --- END STATUS ---
	
	enemy.end_turn()
	_end_current_turn()



func _on_combatant_turn_completed(_combatant: Combatant):
	pass

# ============================================================================
# DAMAGE CALCULATION
# ============================================================================


func _apply_action_effect(action_data: Dictionary, source: Combatant, targets: Array):
	"""Apply the actual game effect (damage, heal, etc.) from an action"""
	var action_type = action_data.get("action_type", 0)
	
	match action_type:
		0:  # ATTACK
			for target in targets:
				var damage = _calculate_damage(action_data, source, target)
				print("  💥 %s deals %d damage to %s" % [source.combatant_name, damage, target.combatant_name])
				target.take_damage(damage)
				
				# v5: Track unique enemies hit for Crucible's Gift
				if source == player_combatant and target not in _enemies_hit_this_turn:
					_enemies_hit_this_turn.append(target)
				
				# --- PROC: On-hit procs (player attacks only) ---
				if source == player_combatant and player and player.affix_manager and proc_processor:
					var hit_results = proc_processor.process_on_hit(
						player.affix_manager, _build_proc_context({
							"damage_dealt": damage,
							"target": target,
							"action_resource": action_data.get("action_resource"),
							"placed_dice": action_data.get("placed_dice", []),
						}))
					_apply_proc_results(hit_results)
				# --- END PROC ---
				
				# Update appropriate health display
				if target == player_combatant:
					_update_player_health()
					_check_player_death()
				else:
					var enemy_index = enemy_combatants.find(target)
					if enemy_index >= 0:
						_update_enemy_health(enemy_index)
						_check_enemy_death(target)
		
		1:  # DEFEND
			print("  🛡️ %s defends" % source.combatant_name)
		
		2:  # HEAL
			var heal_amount = _calculate_heal(action_data, source)
			print("  💚 %s heals for %d" % [source.combatant_name, heal_amount])
			source.heal(heal_amount)
			
			if source == player_combatant:
				_update_player_health()
			else:
				var enemy_index = enemy_combatants.find(source)
				if enemy_index >= 0:
					_update_enemy_health(enemy_index)
		
		3:  # SPECIAL
			print("  ✨ %s uses special ability" % source.combatant_name)
	
	# --- STATUS: Process all ActionEffect types beyond legacy action_type ---
	var action_resource = action_data.get("action_resource") as Action
	if action_resource and action_resource.effects.size() > 0:
		var has_processable_effects = false
		for effect in action_resource.effects:
			if effect and effect.effect_type in [
				ActionEffect.EffectType.ADD_STATUS,
				ActionEffect.EffectType.REMOVE_STATUS,
				ActionEffect.EffectType.CLEANSE,
				ActionEffect.EffectType.SHIELD,
				ActionEffect.EffectType.ARMOR_BUFF,
				ActionEffect.EffectType.DAMAGE_REDUCTION,
				ActionEffect.EffectType.REFLECT,
				ActionEffect.EffectType.LIFESTEAL,
				ActionEffect.EffectType.EXECUTE,
				ActionEffect.EffectType.COMBO_MARK,
				ActionEffect.EffectType.ECHO,
				ActionEffect.EffectType.SPLASH,
				ActionEffect.EffectType.CHAIN,
				ActionEffect.EffectType.RANDOM_STRIKES,
				ActionEffect.EffectType.MANA_MANIPULATE,
				ActionEffect.EffectType.MODIFY_COOLDOWN,
				ActionEffect.EffectType.REFUND_CHARGES,
				ActionEffect.EffectType.GRANT_TEMP_ACTION,
				ActionEffect.EffectType.CHANNEL,
				ActionEffect.EffectType.COUNTER_SETUP,
			]:
				has_processable_effects = true
				break
		
		if has_processable_effects:
			var all_enemies_alive: Array = []
			for e in enemy_combatants:
				if e.is_alive():
					all_enemies_alive.append(e)
			var all_allies: Array = [player_combatant] if player_combatant else []
			
			var placed_dice: Array = action_data.get("placed_dice", [])
			var dice_values: Array = []
			for die in placed_dice:
				if die is DieResource:
					dice_values.append(die.get_total_value())
			
			var primary_target = targets[0] if targets.size() > 0 else null
			var results = action_resource.execute_simple(
				source, primary_target, all_enemies_alive, all_allies, dice_values
			)
			
			_process_action_effect_results(results, source)
	# --- END STATUS ---
	
	# --- v4 MANA SYSTEM: Resolve queued combat and mana events ---
	if player and player.dice_pool:
		var primary = targets[0] if targets.size() > 0 else null
		_resolve_combat_events(player.dice_pool.drain_combat_events(), primary)
		_resolve_mana_events(player.dice_pool.drain_mana_events())
	# --- END MANA SYSTEM ---
	
	# --- FINALIZE DICE CONSUMPTION (v5) ---
	# Commit element/tag usage now that the action has irrevocably fired.
	# This must happen AFTER _apply_action_effect so ON_USE affixes see
	# the pre-action counts, and BEFORE the next action's affixes resolve.
	if player and player.dice_pool:
		var placed_dice: Array = action_data.get("placed_dice", [])
		player.dice_pool.finalize_dice_consumption(placed_dice)
	# --- END FINALIZE ---
	
	# --- v6: CLASS ACTION CONDITIONAL RIDERS ---
	if action_data.get("is_class_action", false):
		var class_action_resource = action_data.get("action_resource") as Action
		if class_action_resource:
			_execute_conditional_riders(class_action_resource, source, targets)
	# --- END CLASS ACTION ---



# ============================================================================
# COMBAT / MANA EVENT RESOLUTION (v4 — Mana System)
# ============================================================================

func _resolve_combat_events(events: Array[Dictionary], primary_target) -> void:
	"""Resolve queued combat events from dice affix processing.
	Called after _apply_action_effect() with the primary attack target."""
	if events.is_empty():
		return
	
	print("  ⚡ Resolving %d combat events..." % events.size())
	
	for event in events:
		match event.get("type", ""):
			"splash":
				_resolve_splash(event, primary_target)
			"chain":
				_resolve_chain(event, primary_target)
			"aoe":
				_resolve_aoe(event)
			"bonus_damage":
				_resolve_bonus_damage(event, primary_target)
			"ignore_resistance":
				# Resistance bypass is consumed during damage calc (future).
				# For now, log it — full integration requires CombatCalculator changes.
				print("    🛡️ Resistance bypass: %s (noted for calc)" % event.get("element", ""))
			_:
				print("    ⚠️ Unknown combat event type: %s" % event.get("type", "?"))

func _resolve_splash(event: Dictionary, primary_target) -> void:
	"""Splash damage to enemies adjacent to the primary target in formation."""
	var damage = int(event.get("damage", 0))
	var percent = event.get("percent", 0.5)
	var splash_damage = int(damage * percent)
	
	if splash_damage <= 0:
		return
	
	var primary_index = enemy_combatants.find(primary_target) if primary_target else -1
	var splash_targets: Array[Combatant] = []
	
	# Adjacent enemies in the formation
	if primary_index > 0 and enemy_combatants[primary_index - 1].is_alive():
		splash_targets.append(enemy_combatants[primary_index - 1])
	if primary_index >= 0 and primary_index < enemy_combatants.size() - 1:
		if enemy_combatants[primary_index + 1].is_alive():
			splash_targets.append(enemy_combatants[primary_index + 1])
	
	for target in splash_targets:
		target.take_damage(splash_damage)
		var idx = enemy_combatants.find(target)
		print("    💥 Splash: %d %s damage to %s" % [
			splash_damage, event.get("element", ""), target.combatant_name])
		if idx >= 0:
			_update_enemy_health(idx)
			_check_enemy_death(target)

func _resolve_chain(event: Dictionary, primary_target) -> void:
	"""Chain damage to N additional targets with decay multiplier."""
	var base_damage = int(event.get("damage", 0))
	var chains = event.get("chains", 2)
	var decay = event.get("decay", 0.7)
	
	if base_damage <= 0:
		return
	
	# Build target list: all living enemies except primary
	var eligible: Array[Combatant] = []
	for enemy in enemy_combatants:
		if enemy.is_alive() and enemy != primary_target:
			eligible.append(enemy)
	
	var current_damage = float(base_damage)
	var chain_count = 0
	
	for target in eligible:
		if chain_count >= chains:
			break
		
		current_damage *= decay
		var chain_dmg = int(current_damage)
		if chain_dmg <= 0:
			break
		
		target.take_damage(chain_dmg)
		chain_count += 1
		var idx = enemy_combatants.find(target)
		print("    ⚡ Chain %d: %d %s damage to %s" % [
			chain_count, chain_dmg, event.get("element", ""), target.combatant_name])
		if idx >= 0:
			_update_enemy_health(idx)
			_check_enemy_death(target)

func _resolve_aoe(event: Dictionary) -> void:
	"""AoE damage to all living enemies."""
	var damage = int(event.get("damage", 0))
	if damage <= 0:
		return
	
	for enemy in enemy_combatants:
		if enemy.is_alive():
			enemy.take_damage(damage)
			var idx = enemy_combatants.find(enemy)
			print("    🌊 AoE: %d %s damage to %s" % [
				damage, event.get("element", ""), enemy.combatant_name])
			if idx >= 0:
				_update_enemy_health(idx)
				_check_enemy_death(enemy)

func _resolve_bonus_damage(event: Dictionary, primary_target) -> void:
	"""Bonus flat damage added to the primary target."""
	var damage = int(event.get("damage", 0))
	if damage <= 0 or not primary_target or not primary_target.is_alive():
		return
	
	primary_target.take_damage(damage)
	var idx = enemy_combatants.find(primary_target)
	print("    🔥 Bonus damage: %d %s to %s" % [
		damage, event.get("element", ""), primary_target.combatant_name])
	if idx >= 0:
		_update_enemy_health(idx)
		_check_enemy_death(primary_target)

func _resolve_mana_events(events: Array[Dictionary]) -> void:
	"""Resolve queued mana events from dice affix processing."""
	if events.is_empty():
		return
	if not player or not player.has_mana_pool():
		return
	
	print("  🔮 Resolving %d mana events..." % events.size())
	
	for event in events:
		match event.get("type", ""):
			"mana_refund":
				var percent = event.get("percent", 0.0)
				var refund = int(player.mana_pool.last_pull_cost * percent)
				if refund > 0:
					player.mana_pool.current_mana = mini(
						player.mana_pool.current_mana + refund,
						player.mana_pool.max_mana)
					print("    🔮 Mana refund: +%d (%.0f%% of %d cost)" % [
						refund, percent * 100, player.mana_pool.last_pull_cost])
				
			"mana_gain":
				var amount = int(event.get("amount", 0))
				if amount > 0:
					player.mana_pool.current_mana = mini(
						player.mana_pool.current_mana + amount,
						player.mana_pool.max_mana)
					print("    🔮 Mana gain: +%d" % amount)
			_:
				print("    ⚠️ Unknown mana event type: %s" % event.get("type", "?"))







# ============================================================================
# v4 — STATUS THRESHOLD RESOLUTION
# ============================================================================

func _connect_status_threshold_signals():
	"""Connect status_threshold_triggered from all combatant StatusTrackers."""
	# Player
	if player and "status_tracker" in player and player.status_tracker:
		var tracker = player.status_tracker
		if tracker.has_signal("status_threshold_triggered"):
			if not tracker.status_threshold_triggered.is_connected(_on_status_threshold_player):
				tracker.status_threshold_triggered.connect(_on_status_threshold_player)
	
	# Enemies
	for i in range(enemy_combatants.size()):
		var enemy_c = enemy_combatants[i]
		var tracker = null
		if "status_tracker" in enemy_c:
			tracker = enemy_c.status_tracker
		elif enemy_c.has_method("get_node_or_null"):
			tracker = enemy_c.get_node_or_null("StatusTracker")
		if tracker and tracker.has_signal("status_threshold_triggered"):
			if not tracker.status_threshold_triggered.is_connected(_on_status_threshold_enemy):
				tracker.status_threshold_triggered.connect(
					_on_status_threshold_enemy.bind(i))

func _on_status_threshold_player(status_id: String, event_data: Dictionary):
	"""Handle threshold on the PLAYER (e.g., self-damage from Poison burst)."""
	print("💥 Player threshold: %s → %s" % [status_id, event_data])
	
	if event_data.get("effect") == "burst_damage":
		var damage: int = event_data.get("damage", 0)
		if damage > 0 and player_combatant:
			var is_magical: bool = event_data.get("damage_is_magical", false)
			player_combatant.take_damage(damage)
			print("  💥 Player takes %d %s burst from %s" % [
				damage, "magical" if is_magical else "physical",
				event_data.get("status_name", status_id)])
			
			if not player_combatant.is_alive():
				_check_player_death()

func _on_status_threshold_enemy(status_id: String, event_data: Dictionary,
		enemy_index: int = 0):
	"""Handle threshold on an ENEMY (e.g., Burn explosion deals burst damage)."""
	print("💥 Enemy[%d] threshold: %s → %s" % [enemy_index, status_id, event_data])
	
	if event_data.get("effect") == "burst_damage":
		var damage: int = event_data.get("damage", 0)
		if damage > 0 and enemy_index < enemy_combatants.size():
			var target = enemy_combatants[enemy_index]
			if target and target.is_alive():
				target.take_damage(damage)
				var is_magical: bool = event_data.get("damage_is_magical", false)
				print("  💥 Enemy[%d] takes %d %s burst from %s" % [
					enemy_index, damage,
					"magical" if is_magical else "physical",
					event_data.get("status_name", status_id)])
				
				if not target.is_alive():
					_check_enemy_death(target)


func _get_status_duration_bonus(status_id: String) -> int:
	if not player or not "affix_manager" in player:
		return 0
	var apm = player.affix_manager
	if not apm:
		return 0
	
	var bonus: int = 0
	for affix in apm.get_pool(Affix.Category.MISC):
		if not "status_duration" in affix.tags:
			continue
		var target_sid: String = affix.effect_data.get("status_id", "")
		if target_sid == status_id or target_sid == "":
			bonus += int(affix.effect_data.get("duration_bonus", 0))
	return bonus

func _get_status_damage_mult(status_id: String) -> float:
	if not player or not "affix_manager" in player:
		return 1.0
	var apm = player.affix_manager
	if not apm or not apm.has_method("get_pool"):
		return 1.0
	
	var mult: float = 1.0
	for affix in apm.get_pool(Affix.Category.STATUS_DAMAGE_MULTIPLIER):
		var target_sid: String = affix.effect_data.get("status_id", "")
		if target_sid == status_id or target_sid == "":
			mult *= affix.get_value()
	return mult


func _apply_status_tick_results(player_ref, combatant: Combatant, 
		tick_results: Array[Dictionary]) -> void:
	"""Apply damage/heal from status tick results and update UI.
	
	Args:
		player_ref: The Player resource (null for enemies).
		combatant: The Combatant node to apply damage/heal to.
		tick_results: Array from StatusTracker.process_turn_start/end().
	"""
	for result in tick_results:
		var status_name: String = result.get("status_name", "")
		var damage: int = result.get("damage", 0)
		var is_magical: bool = result.get("damage_is_magical", false)
		var heal: int = result.get("heal", 0)
		
		if damage > 0:
			print("  🔥 %s takes %d %s damage from %s" % [
				combatant.combatant_name,
				damage,
				"magical" if is_magical else "physical",
				status_name
			])
			
			if player_ref:
				player_ref.take_damage(damage, is_magical)
				_sync_player_health()
			else:
				combatant.take_damage(damage)
		
		if heal > 0:
			print("  💚 %s heals %d from %s" % [
				combatant.combatant_name, heal, status_name
			])
			
			if player_ref:
				player_ref.heal(heal)
				_sync_player_health()
			else:
				combatant.heal(heal)
	
	
		# Fire reactive animation events
		if event_bus:
			var visual = _get_combatant_visual(combatant)
			if visual:
				if damage > 0:
					event_bus.emit_status_ticked(visual, status_name, damage, result.get("element", ""))
				if heal > 0:
					event_bus.emit_heal_applied(visual, heal)
		
		
		
	# Update health displays after all ticks
	if combatant == player_combatant:
		_update_player_health()
	else:
		var enemy_index = enemy_combatants.find(combatant)
		if enemy_index >= 0:
			_update_enemy_health(enemy_index)
	
	# Brief pause so player can see tick damage
	if tick_results.size() > 0:
		await get_tree().create_timer(0.3).timeout


func _sync_player_health():
	"""Sync player HP to the player combatant node."""
	if player and player_combatant:
		player_combatant.current_health = player.current_hp
		player_combatant.max_health = player.max_hp
		player_combatant.update_display()


# ============================================================================
# ACTION EFFECT RESULT PROCESSING (v3.1 — 21 EffectTypes)
# ============================================================================

func _process_action_effect_results(results: Array[Dictionary], source: Combatant) -> void:
	"""Process ActionEffect execution results for all 21 effect types.
	Called after Action.execute_simple() returns results.
	
	Args:
		results: Array of result dicts from ActionEffect.execute().
		source: The Combatant that used the action (needed for self-targeting effects).
	"""
	var source_name: String = source.combatant_name if source else "Unknown"
	
	for result in results:
		var effect_type = result.get("effect_type", -1)
		var target = result.get("target", null)
		
		match effect_type:
			# ── Core ──
			ActionEffect.EffectType.ADD_STATUS:
				var tracker: StatusTracker = _get_status_tracker(target)
				if not tracker:
					continue
				var status_affix: StatusAffix = result.get("status_affix")
				var stacks: int = result.get("stacks_to_add", 1)
				if status_affix:
					tracker.apply_status(status_affix, stacks, source_name)
			
			ActionEffect.EffectType.REMOVE_STATUS:
				var tracker: StatusTracker = _get_status_tracker(target)
				if not tracker:
					continue
				var status_affix: StatusAffix = result.get("status_affix")
				var stacks: int = result.get("stacks_to_remove", 0)
				var remove_all: bool = result.get("remove_all", false)
				if status_affix:
					if remove_all:
						tracker.remove_status(status_affix.status_id)
					else:
						tracker.remove_stacks(status_affix.status_id, stacks)
			
			ActionEffect.EffectType.CLEANSE:
				var tracker: StatusTracker = _get_status_tracker(target)
				if not tracker:
					continue
				var tags: Array[String] = []
				var raw_tags = result.get("cleanse_tags", [])
				for tag in raw_tags:
					tags.append(tag)
				var max_removals: int = result.get("cleanse_max_removals", 0)
				if tags.size() > 0:
					tracker.cleanse(tags, max_removals)
					
			# ── Defensive ──
			ActionEffect.EffectType.SHIELD:
				var amount: int = result.get("shield_amount", 0)
				var duration: int = result.get("shield_duration", -1)
				if amount > 0 and source and source.has_method("add_shield"):
					source.add_shield(amount, duration)
				print("  🛡️ Shield: +%d" % amount)

			ActionEffect.EffectType.ARMOR_BUFF:
				var amount: int = result.get("armor_amount", 0)
				var duration: int = result.get("armor_duration", 2)
				if amount > 0 and source and source.has_method("add_armor_buff"):
					source.add_armor_buff(amount, duration)
				print("  🛡️ Armor: +%d for %dt" % [amount, duration])

			ActionEffect.EffectType.DAMAGE_REDUCTION:
				var amount = result.get("reduction_amount", 0)
				var is_pct: bool = result.get("reduction_is_percent", false)
				var duration: int = result.get("reduction_duration", 1)
				if source and source.has_method("add_damage_reduction"):
					source.add_damage_reduction(amount, is_pct, duration,
						result.get("reduction_single_use", false))
				print("  🛡️ DR: %s for %dt" % [
					"%d%%" % int(amount * 100) if is_pct else str(int(amount)), duration])

			ActionEffect.EffectType.REFLECT:
				var pct: float = result.get("reflect_percent", 0.3)
				var duration: int = result.get("reflect_duration", 2)
				if source and source.has_method("add_reflect"):
					source.add_reflect(pct, duration, result.get("reflect_element"))
				print("  🪞 Reflect: %d%% for %dt" % [int(pct * 100), duration])

			# ── Combat Modifiers ──
			ActionEffect.EffectType.LIFESTEAL:
				var dmg: int = result.get("damage", 0)
				var pct: float = result.get("lifesteal_percent", 0.3)
				if result.get("lifesteal_deals_damage", true) and dmg > 0:
					var target_node = result.get("target")
					if target_node and target_node.has_method("take_damage"):
						target_node.take_damage(dmg)
						_update_and_check_target(target_node)
				var heal_amt = int(dmg * pct)
				if heal_amt > 0 and source:
					source.heal(heal_amt)
					if source == player_combatant:
						_update_player_health()
				print("  🧛 Lifesteal: %d dmg, %d healed" % [dmg, heal_amt])

			ActionEffect.EffectType.EXECUTE:
				var dmg: int = result.get("damage", 0)
				var target_node = result.get("target")
				if result.get("execute_instant_kill", false) and target_node:
					if target_node.has_method("take_damage"):
						target_node.take_damage(target_node.current_health)
					print("  💀 Execute: instant kill!")
				elif dmg > 0 and target_node and target_node.has_method("take_damage"):
					target_node.take_damage(dmg)
					print("  💀 Execute: %d damage%s" % [dmg,
						" (bonus!)" if result.get("execute_triggered") else ""])
				if target_node:
					_update_and_check_target(target_node)

			ActionEffect.EffectType.COMBO_MARK:
				var target_node = result.get("target")
				var ms: StatusAffix = result.get("mark_status")
				if target_node and ms:
					var mark_tracker: StatusTracker = null
					if target_node.has_node("StatusTracker"):
						mark_tracker = target_node.get_node("StatusTracker")
					elif target_node == player_combatant and player and player.status_tracker:
						mark_tracker = player.status_tracker
					if mark_tracker:
						var existing = mark_tracker.get_stacks(ms.affix_id)
						if existing > 0:
							var bonus = result.get("mark_consume_bonus", 5)
							var combo_dmg = existing * bonus
							mark_tracker.remove_stacks(ms.affix_id, existing)
							if target_node.has_method("take_damage"):
								target_node.take_damage(combo_dmg)
							print("  🔥 Combo: %d marks × %d = %d" % [existing, bonus, combo_dmg])
							_update_and_check_target(target_node)
						else:
							mark_tracker.apply_status(ms, result.get("mark_stacks", 1), "combo_mark")
							print("  🎯 Marked: %d stacks" % result.get("mark_stacks", 1))
				if result.get("mark_deals_damage", false):
					var dmg = result.get("damage", 0)
					if dmg > 0 and target_node and target_node.has_method("take_damage"):
						target_node.take_damage(dmg)
						_update_and_check_target(target_node)

			ActionEffect.EffectType.ECHO:
				if result.get("echo_triggered", false):
					var echo_damages: Array = result.get("echo_damages", [])
					var target_node = result.get("target")
					for i in range(echo_damages.size()):
						if target_node and target_node.is_alive() and target_node.has_method("take_damage"):
							target_node.take_damage(echo_damages[i])
							print("  🔁 Echo %d: %d" % [i + 1, echo_damages[i]])
					if target_node:
						_update_and_check_target(target_node)

			# ── Multi-Target ──
			ActionEffect.EffectType.SPLASH:
				var primary_dmg: int = result.get("primary_damage", result.get("damage", 0))
				var splash_dmg: int = result.get("splash_damage", 0)
				var target_node = result.get("target")
				if primary_dmg > 0 and target_node and target_node.has_method("take_damage"):
					target_node.take_damage(primary_dmg)
					_update_and_check_target(target_node)
				if splash_dmg > 0:
					for st in _get_splash_targets(target_node, result.get("splash_all", false)):
						if st.has_method("take_damage"):
							st.take_damage(splash_dmg)
							print("  💥 Splash: %d → %s" % [splash_dmg, st.combatant_name])
							_update_and_check_target(st)

			ActionEffect.EffectType.CHAIN:
				var primary_dmg: int = result.get("primary_damage", result.get("damage", 0))
				var chain_damages: Array = result.get("chain_damages", [])
				var target_node = result.get("target")
				if primary_dmg > 0 and target_node and target_node.has_method("take_damage"):
					target_node.take_damage(primary_dmg)
					_update_and_check_target(target_node)
				var chain_tgts = _get_chain_targets(
					target_node, result.get("chain_can_repeat", false))
				for i in range(mini(chain_damages.size(), chain_tgts.size())):
					var ct = chain_tgts[i]
					if ct.is_alive() and ct.has_method("take_damage"):
						ct.take_damage(chain_damages[i])
						print("  ⚡ Chain %d: %d → %s" % [i + 1, chain_damages[i], ct.combatant_name])
						_update_and_check_target(ct)

			ActionEffect.EffectType.RANDOM_STRIKES:
				var strike_damages: Array = result.get("strike_damages", [])
				for i in range(strike_damages.size()):
					var alive: Array = []
					for e in enemy_combatants:
						if e.is_alive():
							alive.append(e)
					if alive.is_empty():
						break
					var hit = alive[randi() % alive.size()]
					if hit.has_method("take_damage"):
						hit.take_damage(strike_damages[i])
						print("  🎲 Strike %d: %d → %s" % [i + 1, strike_damages[i], hit.combatant_name])
						_update_and_check_target(hit)

			# ── Economy ──
			ActionEffect.EffectType.MANA_MANIPULATE:
				var mana_amt: int = result.get("mana_amount", 0)
				if mana_amt != 0 and player and player.has_mana_pool():
					if mana_amt > 0:
						player.mana_pool.add_mana(mana_amt)
						print("  🔮 Mana: +%d" % mana_amt)
					else:
						var drain = absi(mana_amt)
						var old = player.mana_pool.current_mana
						player.mana_pool.current_mana = maxi(0, old - drain)
						player.mana_pool.mana_changed.emit(
							player.mana_pool.current_mana, player.mana_pool.max_mana)
						print("  🔮 Mana: -%d" % drain)

			ActionEffect.EffectType.MODIFY_COOLDOWN:
				var reduction: int = result.get("cooldown_reduction", 1)
				var target_id: String = result.get("cooldown_target_action_id", "")
				var count := 0
				if combat_ui:
					for field in combat_ui.action_fields:
						if not is_instance_valid(field) or not field.action_resource:
							continue
						var action: Action = field.action_resource
						if target_id != "" and action.action_id != target_id:
							continue
						if "current_cooldown" in action and action.current_cooldown > 0:
							action.current_cooldown = maxi(0, action.current_cooldown - reduction)
							count += 1
				print("  ⏱️ CD -%d on %d action(s)" % [reduction, count])

			ActionEffect.EffectType.REFUND_CHARGES:
				var refund: int = result.get("charges_to_refund", 1)
				var target_id: String = result.get("refund_target_action_id", "")
				var total := 0
				if combat_ui:
					for field in combat_ui.action_fields:
						if not is_instance_valid(field) or not field.action_resource:
							continue
						var action: Action = field.action_resource
						if action.charge_type == Action.ChargeType.UNLIMITED:
							continue
						if target_id != "" and action.action_id != target_id:
							continue
						var old = action.current_charges
						action.current_charges = mini(old + refund, action.max_charges)
						var gained = action.current_charges - old
						if gained > 0:
							total += gained
							if field.has_method("refresh_charge_state"):
								field.refresh_charge_state()
				print("  🔋 Refunded %d charge(s)" % total)

			ActionEffect.EffectType.GRANT_TEMP_ACTION:
				var granted: Action = result.get("granted_action")
				var duration: int = result.get("grant_duration", 1)
				if granted and combat_ui and combat_ui.has_method("add_temp_action_field"):
					combat_ui.add_temp_action_field(granted, duration)
					print("  🎁 Granted '%s' for %dt" % [granted.action_name, duration])
				elif granted:
					print("  🎁 Grant '%s' queued (UI pending)" % granted.action_name)

			# ── Battlefield ──
			ActionEffect.EffectType.CHANNEL:
				if battlefield_tracker:
					var release_eff: ActionEffect = result.get("channel_release_effect")
					if release_eff:
						var channel = ChannelEffect.create(
							result.get("effect_name", "Channel"), release_eff,
							result.get("channel_max_turns", 3),
							result.get("channel_growth_per_turn", 0.5), source)
						battlefield_tracker.add_channel(channel)

			ActionEffect.EffectType.COUNTER_SETUP:
				if battlefield_tracker:
					var counter_eff: ActionEffect = result.get("counter_effect")
					if counter_eff:
						var counter = CounterEffect.create(
							result.get("effect_name", "Counter"), counter_eff,
							result.get("counter_charges", 1),
							result.get("counter_damage_threshold", 0), source)
						battlefield_tracker.add_counter(counter)


# ============================================================================
# BATTLEFIELD RESULT PROCESSING
# ============================================================================

func _process_single_battlefield_result(result: Dictionary) -> void:
	"""Process a single result dict from BattlefieldTracker (channel release or
	counter-attack). These results are standard ActionEffect output dicts, so we
	handle DAMAGE, HEAL, and ADD_STATUS — the most common payloads for channels
	and counters. Extend this match as needed."""
	var etype = result.get("effect_type", -1)
	match etype:
		ActionEffect.EffectType.DAMAGE:
			var target_node = result.get("target")
			var dmg: int = result.get("damage", 0)
			if target_node and target_node.has_method("take_damage") and dmg > 0:
				target_node.take_damage(dmg)
				print("  📡 BF damage: %d → %s" % [dmg,
					target_node.combatant_name if target_node else "?"])
				_update_and_check_target(target_node)
		
		ActionEffect.EffectType.HEAL:
			var target_node = result.get("target")
			var heal: int = result.get("heal", 0)
			if target_node and heal > 0:
				if target_node == player_combatant and player:
					player.heal(heal)
					_update_player_health()
				elif target_node.has_method("heal"):
					target_node.heal(heal)
					var idx = enemy_combatants.find(target_node)
					if idx >= 0:
						_update_enemy_health(idx)
				print("  📡 BF heal: %d → %s" % [heal,
					target_node.combatant_name if target_node else "?"])
		
		ActionEffect.EffectType.ADD_STATUS:
			var target_node = result.get("target")
			var sa: StatusAffix = result.get("status_affix")
			if target_node and sa:
				var bf_tracker: StatusTracker = _get_status_tracker(target_node)
				if bf_tracker:
					bf_tracker.apply_status(sa, result.get("stacks_to_add", 1),
						result.get("_battlefield_source", "battlefield"))
					print("  📡 BF status: %s → %s" % [sa.affix_name,
						target_node.combatant_name if target_node else "?"])

func _on_channel_released(channel: ChannelEffect, results: Array[Dictionary],
		was_broken: bool) -> void:
	"""Signal handler for battlefield_tracker.channel_released."""
	print("  📡 Channel '%s' %s (x%.1f)" % [
		channel.channel_name,
		"broken" if was_broken else "released",
		channel.get_current_multiplier()])

func _on_counter_triggered(counter: CounterEffect, results: Array[Dictionary]) -> void:
	"""Signal handler for battlefield_tracker.counter_triggered."""
	print("  ⚔️ Counter '%s' fired!" % counter.counter_name)


func _get_status_tracker(target) -> StatusTracker:
	"""Get the StatusTracker for a target (player or enemy combatant)."""
	if target == player_combatant and player and player.status_tracker:
		return player.status_tracker
	elif target is Combatant and target.has_node("StatusTracker"):
		return target.get_node("StatusTracker")
	return null

func _calculate_damage(action_data: Dictionary, attacker, defender) -> int:
	"""Calculate damage using split elemental damage system"""
	var placed_dice: Array = action_data.get("placed_dice", [])
	
	# Get action effects (from Action resource if available)
	var effects: Array[ActionEffect] = []
	if action_data.has("action_resource") and action_data.action_resource is Action:
		effects = action_data.action_resource.effects
	elif action_data.has("effects") and action_data.effects is Array:
		for effect in action_data.effects:
			if effect is ActionEffect:
				effects.append(effect)
	
	# Legacy fallback - create a basic damage effect if no effects found
	if effects.is_empty():
		var legacy_effect = ActionEffect.new()
		legacy_effect.effect_type = ActionEffect.EffectType.DAMAGE
		legacy_effect.base_damage = action_data.get("base_damage", 0)
		legacy_effect.damage_multiplier = action_data.get("damage_multiplier", 1.0)
		legacy_effect.damage_type = action_data.get("element", ActionEffect.DamageType.SLASHING)
		legacy_effect.dice_count = placed_dice.size()
		effects = [legacy_effect]
	
	
	# Get attacker's affix manager (players have one, enemies might not)
	var attacker_affixes: AffixPoolManager = null
	if attacker is Player:
		attacker_affixes = attacker.affix_manager
	elif attacker is Combatant and attacker.has_method("get_affix_manager"):
		attacker_affixes = attacker.get_affix_manager()
	
	# v6: Apply ACTION_BASE_DAMAGE_BONUS — adds to base_damage before multipliers
	var _action_res = action_data.get("action_resource")
	if _action_res is Action and attacker_affixes:
		var base_bonus = attacker_affixes.get_action_base_damage_bonus(_action_res.action_id)
		if base_bonus > 0:
			var modified_effects: Array[ActionEffect] = []
			for effect in effects:
				if effect and effect.effect_type == ActionEffect.EffectType.DAMAGE:
					var copy = effect.duplicate()
					copy.base_damage += int(base_bonus)
					modified_effects.append(copy)
					print("  📊 Action base damage +%d → %d (from skill ranks)" % [
						int(base_bonus), copy.base_damage
					])
				else:
					modified_effects.append(effect)
			effects = modified_effects
	
	# Get defender stats
	var defender_stats = _get_defender_stats(defender)
	
	# Use CombatCalculator with DieResource array (not int array)
	if attacker_affixes:
		# v6: Extract action_id for action-scoped affix lookups
		var action_id: String = ""
		var action_res = action_data.get("action_resource")
		if action_res is Action:
			action_id = action_res.action_id
		
		# Extract accepted_elements for multi-element synergy (e.g. Chromatic Bolt)
		var accepted_elems: Array[int] = []
		if action_res is Action:
			accepted_elems = action_res.accepted_elements
		
		var result = CombatCalculator.calculate_attack_damage(
			attacker_affixes,
			effects,
			placed_dice,  # Pass DieResource array directly — no longer extracting ints
			defender_stats,
			action_id,
			accepted_elems
		)
		
		# Log the element breakdown for debugging
		if result.element_breakdown.size() > 1:
			print("  🎯 Split damage: %s" % str(result.element_breakdown))
		
		return result.total_damage
	
	# Simple fallback calculation (no affixes — still uses split damage)
	var packet = DamagePacket.new()
	var action_element = action_data.get("element", ActionEffect.DamageType.SLASHING)
	
	for die in placed_dice:
		if die is DieResource:
			var die_value = float(die.get_total_value())
			var die_type = die.get_effective_damage_type(action_element)
			if die.is_element_match(action_element):
				die_value *= CombatCalculator.ELEMENT_MATCH_BONUS
			packet.add_damage(die_type, die_value)
		elif die is int:
			packet.add_damage(action_element, float(die))
	
	var base = action_data.get("base_damage", 0)
	if base > 0:
		packet.add_damage(action_element, float(base))
	
	var mult = action_data.get("damage_multiplier", 1.0)
	if mult != 1.0:
		packet.apply_multiplier(mult)
	
	var total = packet.calculate_final_damage(defender_stats)
	return total



func _calculate_heal(action_data: Dictionary, healer) -> int:
	"""Calculate healing amount"""
	var placed_dice: Array = action_data.get("placed_dice", [])
	
	# Get dice values
	var dice_total = 0
	for die in placed_dice:
		if die is DieResource:
			dice_total += die.get_total_value()
	
	# Get heal values from action
	var base_heal = action_data.get("base_damage", 0)
	var multiplier = action_data.get("damage_multiplier", 1.0)
	
	# Check for ActionEffect-based healing
	var effects: Array[ActionEffect] = []
	if action_data.has("action_resource") and action_data.action_resource is Action:
		effects = action_data.action_resource.effects
	elif action_data.has("effects"):
		effects = action_data.effects
	
	# If we have heal effects, use those
	for effect in effects:
		if effect and effect.effect_type == ActionEffect.EffectType.HEAL:
			var effect_dice_total = 0
			if effect.heal_uses_dice:
				effect_dice_total = dice_total
			return int((effect_dice_total + effect.base_heal) * effect.heal_multiplier)
	
	# Legacy fallback
	return int((dice_total + base_heal) * multiplier)

func _get_defender_stats(defender) -> Dictionary:
	"""Get defense stats from defender.
	Returns armor, barrier, element_modifiers, and defense_mult."""
	if defender is Player:
		return defender.get_defense_stats()
	elif defender is Combatant:
		var elem_mods: Dictionary = {}
		if defender.enemy_data and defender.enemy_data.element_modifiers.size() > 0:
			elem_mods = defender.enemy_data.element_modifiers
		return {
			"armor": defender.armor,
			"barrier": defender.barrier,
			"element_modifiers": elem_mods,
			"defense_mult": 1.0,
		}
	return {"armor": 0, "barrier": 0, "element_modifiers": {}, "defense_mult": 1.0}

# ============================================================================
# HEALTH MANAGEMENT
# ============================================================================

func _on_player_health_changed(current: int, maximum: int):
	if player:
		player.current_hp = current
		player.hp_changed.emit(current, maximum)
	_update_player_health()

func _on_enemy_health_changed(_current: int, _maximum: int, enemy_index: int):
	_update_enemy_health(enemy_index)

func _update_player_health():
	"""Update player health display"""
	if combat_ui and player_combatant:
		combat_ui.update_player_health(player_combatant.current_health, player_combatant.max_health)

func _update_enemy_health(enemy_index: int):
	"""Update enemy health display"""
	if combat_ui and enemy_index >= 0 and enemy_index < enemy_combatants.size():
		var enemy = enemy_combatants[enemy_index]
		combat_ui.update_enemy_health(enemy_index, enemy.current_health, enemy.max_health)

func _check_player_death() -> bool:
	"""Check if player died"""
	if not player_combatant.is_alive():
		end_combat(false)
		return true
	return false

func _check_enemy_death(enemy: Combatant):
	"""Check if enemy died and handle it"""
	if not enemy.is_alive():
		var index = enemy_combatants.find(enemy)
		if combat_ui:
			combat_ui.on_enemy_died(index)
			
	if event_bus:
			var visual = _get_combatant_visual(enemy)
			if visual:
				event_bus.emit_enemy_died(visual, enemy.combatant_name)

func _on_enemy_died(enemy: Combatant):
	"""Handle enemy death"""
	print("☠️ %s defeated!" % enemy.combatant_name)
	
	var index = enemy_combatants.find(enemy)
	if combat_ui:
		combat_ui.on_enemy_died(index)
	
	_check_combat_end()
	




func _on_player_died():
	"""Handle player death"""
	print("☠️ Player defeated!")
	end_combat(false)

func _get_first_living_enemy() -> Combatant:
	"""Get first living enemy"""
	for enemy in enemy_combatants:
		if enemy.is_alive():
			return enemy
	return null



# ============================================================================
# PER-COMBAT CHARGE TRACKING
# ============================================================================

func track_charge_used(action: Action):
	"""Record that a per-combat charge was consumed. Called when action is confirmed."""
	if not action or action.charge_type != Action.ChargeType.LIMITED_PER_COMBAT:
		return
	var key = _get_action_charge_key(action)
	combat_charge_tracker[key] = combat_charge_tracker.get(key, 0) + 1
	print("🔋 Tracked charge: %s → %d used" % [action.action_name, combat_charge_tracker[key]])

func get_charges_used(action: Action) -> int:
	"""Get how many per-combat charges have been consumed for this action."""
	if not action or action.charge_type != Action.ChargeType.LIMITED_PER_COMBAT:
		return 0
	return combat_charge_tracker.get(_get_action_charge_key(action), 0)

func _get_action_charge_key(action: Action) -> String:
	"""Generate a stable key for charge tracking.
	Uses resource_path if saved, otherwise action_id, otherwise action_name."""
	if action.resource_path and not action.resource_path.is_empty():
		return action.resource_path
	if action.action_id and not action.action_id.is_empty():
		return action.action_id
	return action.action_name

func is_in_prep_phase() -> bool:
	"""Public helper for UI gating."""
	return combat_state == CombatState.PLAYER_TURN and turn_phase == TurnPhase.PREP



# ============================================================================
# COMBAT END
# ============================================================================

func end_combat(player_won: bool):
	print("\n=== COMBAT ENDED ===")
	
	# v4: Disable mana die dragging
	var bottom_ui = _get_bottom_ui()
	if bottom_ui and bottom_ui.has_method("set_mana_drag_enabled"):
		bottom_ui.set_mana_drag_enabled(false)
	
	combat_state = CombatState.ENDED
	turn_phase = TurnPhase.NONE
	_combat_initialized = false
	combat_charge_tracker.clear()
	
	if player_won:
		print("🎉 Victory!")
	else:
		print("💀 Defeat!")
	
	# Clear player status effects (on combatant node, not Player resource)
	if player_combatant and player_combatant.has_node("StatusTracker"):
		player_combatant.get_node("StatusTracker").clear_all()
	
	# Clear enemy status effects
	for enemy in enemy_combatants:
		if enemy.has_node("StatusTracker"):
			enemy.get_node("StatusTracker").clear_all()
	
	# --- BATTLEFIELD: Clear all persistent effects ---
	if battlefield_tracker:
		battlefield_tracker.clear_all()
	# --- END BATTLEFIELD ---
	
	# --- PROC: Reset per-combat proc state ---
	if proc_processor and player and player.affix_manager:
		proc_processor.on_combat_end(player.affix_manager)
	# --- END PROC ---
	
	combat_ended.emit(player_won)


func _on_combat_ended(player_won: bool):
	"""Cleanup, then hand off to GameRoot for scene transition + rewards."""
	
	# --- Reactive Animation Cleanup ---
	if combat_ui and "reactive_animator" in combat_ui and combat_ui.reactive_animator:
		combat_ui.reactive_animator.cleanup()
	if event_bus:
		event_bus.emit_combat_ended(player_won)
		event_bus.clear_history()
	
	# Bridge to GameRoot → GameManager.on_combat_ended() → post-combat summary
	if GameManager and GameManager.game_root:
		GameManager.game_root.end_combat(player_won)
		



func reset_combat():
	"""Clean up all combat state for next encounter.
	Called by GameRoot.end_combat() before hiding the combat layer."""
	print("🔄 CombatManager: reset_combat")
	
	# Clear enemy panel
	if combat_ui and combat_ui.enemy_panel:
		for slot in combat_ui.enemy_panel.enemy_slots:
			slot.set_empty()
		combat_ui.enemy_panel.hide_all_turn_indicators()
		combat_ui.enemy_panel.hide_dice_hand()
		combat_ui.enemy_panel.modulate.a = 0.0  # Ready for next drop-in
	
	# Clear action fields
	if combat_ui and combat_ui.action_fields_grid:
		for child in combat_ui.action_fields_grid.get_children():
			child.queue_free()
		combat_ui.action_fields.clear()
	
	# Clear dice pool display
	if combat_ui and combat_ui.dice_pool_display:
		combat_ui.dice_pool_display.hide()
	
	# Hide enemy hand
	if combat_ui and combat_ui.has_method("hide_enemy_hand"):
		combat_ui.hide_enemy_hand()
	
	# Clean up mana die selector
	if combat_ui and combat_ui.mana_die_selector:
		combat_ui.mana_die_selector.cleanup()
	
	
	# Reset state
	enemy_combatants.clear()
	combat_state = CombatState.INITIALIZING
	turn_phase = TurnPhase.NONE
	current_round = 0
	current_turn_index = 0
	turn_order.clear()



# ============================================================================
# HELPERS — Multi-Target & Health
# ============================================================================

func _get_splash_targets(primary_target, splash_all: bool) -> Array:
	if splash_all:
		var targets: Array = []
		for e in enemy_combatants:
			if e.is_alive() and e != primary_target:
				targets.append(e)
		return targets
	var idx = enemy_combatants.find(primary_target)
	var targets: Array = []
	if idx > 0 and enemy_combatants[idx - 1].is_alive():
		targets.append(enemy_combatants[idx - 1])
	if idx >= 0 and idx < enemy_combatants.size() - 1:
		if enemy_combatants[idx + 1].is_alive():
			targets.append(enemy_combatants[idx + 1])
	return targets

func _get_chain_targets(primary_target, can_repeat: bool) -> Array:
	var targets: Array = []
	for e in enemy_combatants:
		if e.is_alive() and e != primary_target:
			targets.append(e)
	if can_repeat and targets.size() > 0:
		var base = targets.duplicate()
		while targets.size() < 10:
			targets.append_array(base)
	return targets

func _update_and_check_target(target) -> void:
	if target == player_combatant:
		_update_player_health()
		_check_player_death()
	else:
		var idx = enemy_combatants.find(target)
		if idx >= 0:
			_update_enemy_health(idx)
			_check_enemy_death(target)

func _build_proc_context(extra: Dictionary = {}) -> Dictionary:
	"""Build a standard context dict for AffixProcProcessor calls.
	Centralizes all runtime state that proc effects may need."""
	var ctx: Dictionary = {
		"source": player_combatant,
		"turn_number": current_round,  # or a per-player turn counter
		"round_number": current_round,
	}
	
	# Wire element_use_counts from the dice pool
	if player and player.dice_pool:
		ctx["element_use_counts"] = player.dice_pool.get_element_use_counts()
		ctx["dice_pool"] = player.dice_pool.dice  # for Infinite Curriculum
	
	# Merge caller-specific keys (damage_dealt, target, etc.)
	ctx.merge(extra, true)
	return ctx


func _build_combat_context(source: Combatant, targets: Array) -> Dictionary:
	"""Build a context dict for conditional rider evaluation.
	Extends _build_proc_context with target-specific state."""
	var ctx := _build_proc_context()
	ctx["source"] = source
	ctx["targets"] = targets
	
	if targets.size() > 0 and targets[0] is Combatant:
		var primary = targets[0]
		ctx["target"] = primary
		ctx["target_hp_percent"] = float(primary.current_health) / maxf(float(primary.max_health), 1.0)
		
		# Target status info for conditions like "if target is Burning"
		var target_tracker := _get_status_tracker(primary)
		if target_tracker:
			ctx["target_tracker"] = target_tracker
			ctx["target_statuses"] = target_tracker.active_statuses
	
	return ctx




func _apply_proc_results(results: Dictionary) -> void:
	"""Apply aggregated proc results to game state.
	Handles all result types from AffixProcProcessor.process_procs()."""
	if results.activated.is_empty():
		return
	
	print("  ⚙️ %d procs activated" % results.activated.size())
	
	# --- Healing ---
	if results.healing > 0 and player_combatant:
		player_combatant.heal(int(results.healing))
		if player:
			player.current_hp = player_combatant.current_health
		_update_player_health()
		print("  💚 Proc heal: %d" % int(results.healing))
	
	# --- Bonus Damage ---
	# NOTE: Bonus damage from procs is logged for now. To integrate fully,
	# pass results.bonus_damage into CombatCalculator during the damage step.
	if results.bonus_damage > 0:
		print("  ⚡ Proc bonus damage: %d (logged — wire into damage calc)" % int(results.bonus_damage))
	
	# --- Temp Affixes ---
	if player and player.affix_manager:
		for temp_affix in results.temp_affixes:
			player.affix_manager.register_affix(temp_affix)
			print("  📎 Temp affix registered: %s" % temp_affix.affix_name)
	
	# --- Temp Dice Affixes ---
	if player and player.dice_pool:
		for dice_affix in results.temp_dice_affixes:
			# Apply to all dice in hand
			for die in player.dice_pool.hand:
				die.add_temp_affix(dice_affix)
			print("  🎲 Temp dice affix applied: %s" % dice_affix.affix_name)
	
	# --- Granted Actions ---
	for action in results.granted_actions:
		if combat_ui and combat_ui.has_method("add_temp_action_field"):
			combat_ui.add_temp_action_field(action, 1)
			print("  🎁 Granted action: %s" % action.action_name)
	
	# --- Status Effects ---
	for status_data in results.status_effects:
		# Status effects from procs target enemies by default
		var status_target = status_data.get("target", "enemy")
		if status_target == "self" and player and player.status_tracker:
			var sa = status_data.get("status_affix")
			if sa:
				player.status_tracker.apply_status(sa, 1, "proc")
		# Enemy targeting requires knowing which enemy — log for now
		else:
			print("  🎯 Status effect queued for %s (wire target selection)" % status_target)
	
	# --- Special Effects (armor, barrier, stacking buffs, retriggering, custom) ---
	for se in results.special_effects:
		var se_type = se.get("type", "")
		match se_type:
			"proc_gain_armor":
				var amount = int(se.get("amount", 0))
				if amount > 0 and player_combatant and player_combatant.has_method("add_armor_buff"):
					player_combatant.add_armor_buff(amount, 1)
					print("  🛡️ Proc armor: +%d" % amount)
			
			"proc_gain_barrier":
				var amount = int(se.get("amount", 0))
				if amount > 0 and player_combatant and player_combatant.has_method("add_shield"):
					player_combatant.add_shield(amount, 1)
					print("  🛡️ Proc barrier: +%d" % amount)
			
			"stacking_buff":
				print("  📈 Stacking buff: %s x%d = %.1f (%s)" % [
					se.get("source", "?"),
					se.get("stacks", 0),
					se.get("total_value", 0.0),
					se.get("buff_category", "?")])
			
			"retrigger_dice_affixes":
				# Re-process dice affixes with the specified trigger
				var trigger_str = se.get("trigger_to_replay", "ON_USE")
				print("  🔁 Retrigger dice affixes: %s (from %s)" % [
					trigger_str, se.get("source", "?")])
				# Full implementation: map trigger_str to DiceAffix.Trigger enum
				# and call player.dice_pool.process_trigger(trigger_enum)
			
			"proc_combat_modifier":
				print("  ⚔️ Combat modifier: %s +%.1f (%s)" % [
					se.get("modifier_type", "?"),
					se.get("amount", 0.0),
					se.get("source", "?")])
			
			"proc_custom":
				var custom_id = se.get("custom_id", "")
				print("  🔧 Custom proc: %s from %s" % [
					custom_id, se.get("source", "?")])
				# Route custom effects here as they're implemented
			
			"proc_heal":
				pass  # Already handled above via results.healing
			
			"proc_bonus_damage":
				pass  # Already handled above via results.bonus_damage





# ============================================================================
# v5 — FLAME TREE: Threshold Triggered Procs (Flashpoint, Pyroclastic Flow)
# ============================================================================

func _on_enemy_threshold_triggered(status_id: String, data: Dictionary, source_enemy) -> void:
	"""Handle status threshold events on enemies for player skill procs.
	
	- Flashpoint: When Burn explodes, splash 50% burst to other enemies.
	- Pyroclastic Flow: When Burn explodes, apply 3 Burn stacks to other enemies.
	"""
	if status_id != "burn":
		return
	if not player or not player.affix_manager:
		return
	
	var other_enemies: Array = []
	for enemy in enemy_combatants:
		if enemy != source_enemy and enemy.current_health > 0:
			other_enemies.append(enemy)
	
	if other_enemies.is_empty():
		return
	
	# Flashpoint: Splash 50% of burst damage to other enemies
	var has_flashpoint: bool = player.affix_manager.get_affixes_by_tag("flashpoint").size() > 0
	if has_flashpoint and data.get("effect", "") == "burst_damage":
		var burst: int = data.get("damage", 0)
		var splash: int = roundi(burst * 0.5)
		var is_magical: bool = data.get("damage_is_magical", true)
		if splash > 0:
			for enemy in other_enemies:
				print("  ★ Flashpoint splash: %d fire damage to %s" % [splash, enemy.combatant_name])
				enemy.take_damage(splash)
				_update_enemy_health(enemy_combatants.find(enemy))
	
	# Pyroclastic Flow: Apply 3 Burn stacks to other enemies
	var has_pyro_flow: bool = player.affix_manager.get_affixes_by_tag("pyroclastic_flow").size() > 0
	if has_pyro_flow and data.get("effect", "") == "burst_damage":
		var burn_res = load("res://resources/statuses/burn.tres") as StatusAffix
		if burn_res:
			for enemy in other_enemies:
				var tracker = _get_status_tracker(enemy)
				if tracker:
					print("  ★ Pyroclastic Flow: +3 Burn to %s" % enemy.combatant_name)
					tracker.apply_status(burn_res, 3, "Pyroclastic Flow")


func _get_combatant_visual(combatant: Combatant) -> Node:
	"""Get the visual node for a combatant (for reactive animation events)."""
	if combatant == player_combatant:
		if combat_ui and combat_ui.player_health_display:
			return combat_ui.player_health_display
		return null
	var idx = enemy_combatants.find(combatant)
	if idx >= 0 and combat_ui and combat_ui.enemy_panel:
		return combat_ui.enemy_panel.get_enemy_visual(idx)
	return null


func _get_bottom_ui() -> Control:
	return get_tree().get_first_node_in_group("bottom_ui")
