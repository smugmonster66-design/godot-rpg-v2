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

var combat_state: CombatState = CombatState.INITIALIZING

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

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
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

func check_pending_encounter():
	"""Check if GameManager has a pending encounter"""
	if GameManager and GameManager.pending_encounter:
		current_encounter = GameManager.pending_encounter
		GameManager.pending_encounter = null
		print("⚔️ Found pending encounter: %s" % current_encounter.encounter_name)
		
		if GameManager.player:
			initialize_combat(GameManager.player)


func _execute_action(action_data: Dictionary, source: Node2D, targets: Array[Combatant]):
	var animation_set = action_data.get("animation_set") as CombatAnimationSet
	
	# Get positions
	var source_pos = source.global_position
	var target_positions: Array[Vector2] = []
	var target_nodes: Array[Node2D] = []
	
	for target in targets:
		target_positions.append(target.global_position)
		target_nodes.append(target)
	
	# Connect to apply effect at right time
	var apply_effect_callable = func():
		_apply_action_effect(action_data, source, targets)
	
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
	
	# Spawn enemies from encounter if we have one
	if current_encounter and encounter_spawner:
		encounter_spawner.spawn_encounter(current_encounter)
	
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
	
	print("⚔️ Combat initialization complete")
	print("  Turn order: %s" % [turn_order.map(func(c): return c.combatant_name)])
	
	# Start first round
	_start_round()

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
	"""Start player's turn"""
	combat_state = CombatState.PLAYER_TURN
	
	print("🎲 _start_player_turn debug:")
	print("  player: %s" % player)
	print("  GameManager.player: %s" % GameManager.player)
	print("  Same player? %s" % (player == GameManager.player))
	
	if player and player.dice_pool:
		print("  player.dice_pool: %s" % player.dice_pool)
		print("  GameManager.player.dice_pool: %s" % GameManager.player.dice_pool)
		print("  Same dice_pool? %s" % (player.dice_pool == GameManager.player.dice_pool))
		print("  POOL size: %d" % player.dice_pool.dice.size())
		print("  GameManager POOL size: %d" % GameManager.player.dice_pool.dice.size())
		
		for die in player.dice_pool.dice:
			print("    - %s from %s" % [die.display_name, die.source])
		
		# Roll the hand — this triggers hand_rolled signal which starts
		# the DicePoolDisplay entrance animation
		player.dice_pool.roll_hand()
	else:
		print("  ⚠️ No player (%s) or dice_pool (%s)!" % [player != null, player.dice_pool if player else null])
	
	# Wait for the roll entrance animation to play before enabling UI
	# (dice count * 0.08s stagger + 0.2s for the last die to finish)
	var dice_count = player.dice_pool.hand.size() if player and player.dice_pool else 0
	var animation_duration = dice_count * 0.08 + 0.25
	await get_tree().create_timer(animation_duration).timeout
	
	if combat_ui:
		if combat_ui.has_method("on_turn_start"):
			combat_ui.on_turn_start()
		if combat_ui.has_method("set_player_turn"):
			combat_ui.set_player_turn(true)


func _on_player_end_turn():
	"""Player ended their turn"""
	if combat_state != CombatState.PLAYER_TURN:
		return
	
	print("🎮 Player ended turn")
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
	if action_resource and action_resource.get("animation_set"):
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
	
	# Create callback for applying effect at the right moment
	var apply_effect_callback = func():
		if not effect_applied:
			effect_applied = true
			_apply_action_effect(action_data, player_combatant, targets)
	
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
		_apply_action_effect(action_data, player_combatant, targets)
	
	combat_state = CombatState.PLAYER_TURN

func _get_enemy_portrait_position(enemy_index: int) -> Vector2:
	"""Get the center position of an enemy's portrait in the UI"""
	if not combat_ui or not combat_ui.enemy_panel:
		return Vector2.ZERO
	
	var enemy_panel = combat_ui.enemy_panel
	if enemy_index < 0 or enemy_index >= enemy_panel.enemy_slots.size():
		return Vector2.ZERO
	
	var slot: EnemySlot = enemy_panel.enemy_slots[enemy_index]
	if not slot or not slot.portrait_rect:
		return Vector2.ZERO
	
	# Return center of portrait
	var portrait = slot.portrait_rect
	return portrait.global_position + portrait.size / 2


# ============================================================================
# ENEMY TURN
# ============================================================================

func _start_enemy_turn(enemy: Combatant):
	"""Start an enemy's turn"""
	combat_state = CombatState.ENEMY_TURN
	
	if combat_ui and combat_ui.has_method("set_player_turn"):
		combat_ui.set_player_turn(false)
	
	enemy.start_turn()
	
	if combat_ui and combat_ui.has_method("show_enemy_hand"):
		combat_ui.show_enemy_hand(enemy)
	
	# Small delay to let UI update
	await get_tree().create_timer(0.3).timeout
	
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
			# Add block/armor buff if you have that system
		
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
			# Handle special abilities - could check action_data for specifics



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
	
	# Get defender stats
	var defender_stats = _get_defender_stats(defender)
	
	# Use CombatCalculator with DieResource array (not int array)
	if attacker_affixes:
		var result = CombatCalculator.calculate_attack_damage(
			attacker_affixes,
			effects,
			placed_dice,  # Pass DieResource array directly — no longer extracting ints
			defender_stats
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
	"""Get defense stats from defender"""
	if defender is Player:
		return defender.get_defense_stats()
	elif defender is Combatant:
		return {
			"armor": defender.armor,
			"fire_resist": defender.get("fire_resist") if defender.get("fire_resist") else 0,
			"ice_resist": defender.get("ice_resist") if defender.get("ice_resist") else 0,
			"shock_resist": defender.get("shock_resist") if defender.get("shock_resist") else 0,
			"poison_resist": defender.get("poison_resist") if defender.get("poison_resist") else 0,
			"shadow_resist": defender.get("shadow_resist") if defender.get("shadow_resist") else 0,
		}
	return {"armor": 0}

# ============================================================================
# HEALTH MANAGEMENT
# ============================================================================

func _on_player_health_changed(current: int, maximum: int):
	if player:
		player.current_hp = current
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
# COMBAT END
# ============================================================================

func end_combat(player_won: bool):
	print("\n=== COMBAT ENDED ===")
	combat_state = CombatState.ENDED
	_combat_initialized = false  # Reset for next combat
	
	if player_won:
		print("🎉 Victory!")
	else:
		print("💀 Defeat!")
	
	combat_ended.emit(player_won)

func _on_combat_ended(player_won: bool):
	"""Handle combat end cleanup"""
	if player_won:
		# Calculate rewards
		var total_exp = 0
		var total_gold = 0
		
		for enemy in enemy_combatants:
			var rewards = enemy.get_rewards()
			total_exp += rewards.experience
			total_gold += rewards.gold
		
		print("  Rewards: %d XP, %d Gold" % [total_exp, total_gold])
		
		# Apply rewards to player
		if player:
			player.gold += total_gold
			if player.active_class:
				player.active_class.add_experience(total_exp)
