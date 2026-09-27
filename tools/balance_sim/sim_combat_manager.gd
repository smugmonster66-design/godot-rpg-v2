# res://tools/balance_sim/sim_combat_manager.gd
# The real CombatManager, driven synchronously for the balance simulator.
#
# Every game rule runs through the real CombatManager code: damage
# (_apply_action_effect -> _calculate_damage -> CombatCalculator /
# DamagePacket), defensive statuses, procs, dice affix events, status ticks,
# thresholds, enemy AI and targeting, charges, consumable buffs.
#
# What this subclass replaces is only the orchestration the UI and the
# animation layer normally drive with awaits (rolling, confirming, enemy turn
# pacing). The turn order below mirrors CombatManager: _start_round ->
# _start_current_turn -> _start_player_turn / _on_roll_pressed /
# _on_action_confirmed / _on_player_end_turn, and _start_enemy_turn ->
# _process_enemy_turn -> _execute_enemy_action_immediate -> _finish_enemy_turn.
# The player's choices come from SimPolicy (the stand-in for the person).
extends "res://scripts/game/combat_manager.gd"

const SimPolicy = preload("res://tools/balance_sim/sim_policy.gd")

## Fight log for the metrics (filled while a fight runs).
var log: Dictionary = {}
## Round cap: a fight still going after this many rounds counts as a loss.
var max_rounds: int = 60
## The player's action list for this fight (ActionManager output).
var player_actions: Array = []
var action_manager: ActionManager = null
var policy = null
## Outlevelling runs: spawn the enemies as if this player were fighting them.
var spawn_as: Player = null
## Enemy damage growth options (sim only, for the open design decision):
##   opt_a: enemy damage x (1 + opt_a x power_position(enemy level)), after
##          defences, through the depth multiplier the game already has.
##   opt_b: enemy flat damage affixes x opt_b (wider affix ranges).
var opt_a: float = 0.0
var opt_b: float = 1.0
var _hp_seen: int = 0
var _ended: bool = false
var _won: bool = false


func _ready() -> void:
	# No UI, no event bus, no animation layer: just the nodes the rules need.
	find_combat_nodes()
	setup_encounter_spawner()
	proc_processor = AffixProcProcessor.new()
	battlefield_tracker = BattlefieldTracker.new()
	battlefield_tracker.name = "BattlefieldTracker"
	add_child(battlefield_tracker)
	battlefield_tracker.channel_released.connect(_on_channel_released)
	battlefield_tracker.counter_triggered.connect(_on_counter_triggered)
	action_manager = ActionManager.new()
	action_manager.name = "SimActionManager"
	add_child(action_manager)
	player_combatant.health_changed.connect(_on_player_health_changed)
	player_combatant.health_changed.connect(_sim_track_hp)
	policy = SimPolicy.new()


# ---------------------------------------------------------------------------
# UI / animation hooks, made synchronous
# ---------------------------------------------------------------------------

func _victory_sequence() -> void:
	# Real: waits for animations, then end_combat(true).
	if combat_state == CombatState.ENDED:
		return
	end_combat(true)


func end_combat(player_won: bool):
	if combat_state == CombatState.ENDED:
		return
	_ended = true
	_won = player_won
	super.end_combat(player_won)


func _execute_chain_hop_group(group: Dictionary) -> void:
	# Real: animates each hop, then applies it. Same damage and status steps,
	# without the travel and impact animations.
	var targets: Array = group.get("targets", [])
	var damages: Array = group.get("damages", [])
	var element = group.get("element", "")
	for i in range(mini(targets.size(), damages.size())):
		var ct: Combatant = targets[i]
		if not is_instance_valid(ct) or not ct.is_alive():
			continue
		_apply_elemental_damage(ct, damages[i], element)
		if enemy_combatants.find(ct) >= 0:
			_check_enemy_death(ct)
		var chain_status_res = group.get("chain_status_res")
		var chain_stacks: int = int(group.get("chain_stacks", 0))
		if chain_status_res and chain_stacks > 0 and ct.is_alive():
			var tracker := _get_status_tracker(ct)
			if tracker:
				tracker.apply_status(chain_status_res, chain_stacks, "chain")


func _drain_chain_hops() -> void:
	while not _pending_chain_hops.is_empty():
		var groups: Array[Dictionary] = _pending_chain_hops.duplicate()
		_pending_chain_hops.clear()
		for g in groups:
			_execute_chain_hop_group(g)


func _sim_track_hp(current: int, _maximum: int) -> void:
	var delta := current - _hp_seen
	if delta < 0:
		log["damage_taken"] += -delta
	elif delta > 0:
		log["healed"] += delta
	_hp_seen = current


func _sync_player_health():
	super._sync_player_health()
	_sim_track_hp(player_combatant.current_health, player_combatant.max_health)


func _finalize_hand(pool: PlayerDiceCollection) -> void:
	"""What the dice UI does after a roll animation: apply the deferred ON_ROLL
	value changes (AffixVisualAnimator / the enemy branch of _start_enemy_turn)
	and shatter dice that ended at 0 or less."""
	for die_index in pool.pending_value_animations.keys():
		var change = pool.pending_value_animations[die_index]
		if die_index < pool.hand.size():
			pool.hand[die_index].modified_value = change.to
	pool.pending_value_animations.clear()
	pool.pending_element_refreshes.clear()
	for die_index in pool.pending_shatters.keys():
		pool.shatter_hand_die(die_index)
	pool.pending_shatters.clear()


# ---------------------------------------------------------------------------
# One fight
# ---------------------------------------------------------------------------

func run_fight(p_player: Player, encounter: CombatEncounter, start_hp: int = -1) -> Dictionary:
	"""Run one fight to the end and return its log."""
	_reset_between_fights()
	player = p_player
	current_encounter = encounter
	combat_state = CombatState.INITIALIZING
	_ended = false
	_won = false
	log = {
		"rounds": 0, "player_actions": 0, "enemy_actions": 0, "enemy_hits": [],
		"damage_taken": 0, "healed": 0, "player_damage": 0, "dot_damage": 0,
		"raw_hit": 0.0, "raw_no_dice": 0.0, "raw_no_pips": 0.0, "crit_extra": 0,
		"kills": 0, "enemies": 0, "potions_used": 0, "potion_heal": 0,
		"timeout": false, "enemy_hp_total": 0, "deaths": 0,
		"weapon_actions": 0, "class_actions": 0, "unplaced_dice": 0,
	}

	# Player state for this fight
	player.status_tracker.clear_all()
	if start_hp > 0:
		player.current_hp = mini(start_hp, player.max_hp)
	else:
		player.current_hp = player.max_hp
	_sync_player_to_combatant()
	_hp_seen = player_combatant.current_health
	# The game never calls dice_pool.start_combat() (or the ON_COMBAT_START
	# dice affixes); the sim doesn't either, to match.

	# Enemies (real spawn: EnemyData affixes at the player's level, power
	# matching, encounter multiplier, dungeon depth from GameManager)
	var real_gm_player = GameManager.player
	if spawn_as:
		GameManager.player = spawn_as
	encounter_spawner.spawn_encounter(encounter)
	GameManager.player = real_gm_player
	if opt_a != 0.0 or opt_b != 1.0:
		_apply_enemy_damage_options()
	log["enemies"] = enemy_combatants.size()
	for e in enemy_combatants:
		log["enemy_hp_total"] += e.max_health
	_build_turn_order()

	# Player actions (ActionManager: class action + item actions + affix actions)
	action_manager.initialize(player)
	player_actions = action_manager.get_actions()
	for a in player_actions:
		var res = a.get("action_resource")
		if res and res.has_method("reset_charges_for_combat"):
			res.reset_charges_for_combat()
	combat_charge_tracker.clear()

	# The rest of _finalize_combat_init
	if player.has_mana_pool() and player.mana_pool.refill_on_combat_start:
		player.mana_pool.refill()
	_apply_consumable_buffs()
	proc_processor.on_combat_start(player.affix_manager)
	_apply_proc_results(proc_processor.process_combat_start(player.affix_manager, _build_proc_context()))
	player.status_tracker.set_source_affix_manager(player.affix_manager)
	for enemy in enemy_combatants:
		var tracker = _get_status_tracker(enemy)
		if tracker:
			tracker.set_source_affix_manager(player.affix_manager)
			if not tracker.status_threshold_triggered.is_connected(_on_enemy_threshold_triggered):
				tracker.status_threshold_triggered.connect(_on_enemy_threshold_triggered.bind(enemy))
	enemy_threat_trackers.clear()
	for enemy in enemy_combatants:
		var tt = ThreatTracker.new()
		var allies: Array[Combatant] = [player_combatant]
		tt.initialize(allies)
		enemy_threat_trackers.append(tt)
	_connect_status_threshold_signals()
	policy.begin_fight(self)

	# Rounds
	current_round = 0
	while not _ended:
		current_round += 1
		log["rounds"] = current_round
		if current_round > max_rounds:
			log["timeout"] = true
			end_combat(false)
			break
		if current_encounter.turn_limit > 0 and current_round > current_encounter.turn_limit:
			end_combat(false)
			break
		current_turn_index = 0
		while current_turn_index < turn_order.size() and not _ended:
			var c: Combatant = turn_order[current_turn_index]
			if c.is_alive():
				_sim_take_turn(c)
			if _ended:
				break
			battlefield_tracker.process_turn_end()
			current_turn_index += 1
		if _ended:
			break
		for tt in enemy_threat_trackers:
			tt.apply_decay()
		_check_combat_end()

	var out := log.duplicate()
	out["won"] = _won
	out["end_hp"] = player_combatant.current_health
	out["max_hp"] = player.max_hp
	for e in enemy_combatants:
		if not e.is_alive():
			out["kills"] += 1
	return out


func _apply_enemy_damage_options() -> void:
	var cfg = AffixTableRegistry.scaling_config
	var flat_cats := [Affix.Category.DAMAGE_BONUS, Affix.Category.SLASHING_DAMAGE_BONUS, Affix.Category.BLUNT_DAMAGE_BONUS,
		Affix.Category.PIERCING_DAMAGE_BONUS, Affix.Category.FIRE_DAMAGE_BONUS, Affix.Category.ICE_DAMAGE_BONUS,
		Affix.Category.SHOCK_DAMAGE_BONUS, Affix.Category.POISON_DAMAGE_BONUS, Affix.Category.SHADOW_DAMAGE_BONUS]
	for e in enemy_combatants:
		var pos: float = cfg.get_power_position(e.get_effective_level()) if cfg else 0.0
		if opt_a != 0.0:
			e.encounter_damage_multiplier *= 1.0 + opt_a * pos
		if opt_b != 1.0 and e.affix_manager:
			for cat in flat_cats:
				for a in e.affix_manager.get_pool(cat):
					a.effect_number *= opt_b


func _reset_between_fights() -> void:
	for e in enemy_combatants:
		if is_instance_valid(e):
			remove_child(e)
			e.queue_free()
	enemy_combatants.clear()
	if encounter_spawner:
		encounter_spawner.spawned_enemies.clear()
	turn_order.clear()
	enemy_threat_trackers.clear()
	_pending_chain_hops.clear()
	_defer_combat_end = false
	_deferred_combat_end_result = -1
	_victory_pending = false
	_combat_initialized = false
	_enemies_hit_this_turn.clear()
	current_round = 0
	current_turn_index = 0
	if battlefield_tracker:
		battlefield_tracker.clear_all()


# ---------------------------------------------------------------------------
# Turns
# ---------------------------------------------------------------------------

func _sim_take_turn(c: Combatant) -> void:
	var is_player := c == player_combatant
	var tracker: StatusTracker = _get_status_tracker(c)
	# Frozen: tick start and end, skip the turn (as _start_current_turn)
	if tracker and tracker.has_status("freeze"):
		_ticks(c, tracker.process_turn_start())
		if not _ended and c.is_alive():
			_ticks(c, tracker.process_turn_end())
		return
	if is_player:
		_sim_player_turn()
	else:
		_sim_enemy_turn(c)


func _ticks(c: Combatant, results: Array[Dictionary]) -> void:
	var before := _enemy_hp_sum()
	_apply_status_tick_results(player if c == player_combatant else null, c, results)
	if c != player_combatant:
		log["dot_damage"] += maxi(0, before - _enemy_hp_sum())
		if not c.is_alive():
			_check_enemy_death(c)
	_check_combat_end()


func _enemy_hp_sum() -> int:
	var s := 0
	for e in enemy_combatants:
		s += e.current_health
	return s


func _sim_player_turn() -> void:
	combat_state = CombatState.PLAYER_TURN
	_enemies_hit_last_turn = _enemies_hit_this_turn.size()
	_enemies_hit_this_turn.clear()
	_ticks(player_combatant, player.status_tracker.process_turn_start())
	if _ended:
		return
	_apply_proc_results(proc_processor.process_turn_start(player.affix_manager, _build_proc_context()))
	if battlefield_tracker.has_any_effects():
		var alive: Array = enemy_combatants.filter(func(e): return e.is_alive())
		for r in battlefield_tracker.process_turn_start(alive, [player_combatant]):
			_process_single_battlefield_result(r)
		if _check_combat_end():
			return
	# PREP: consumables (the policy decides)
	policy.prep_phase(self)
	if _ended:
		return
	# ACTION: roll the hand
	for a in player_actions:
		var res = a.get("action_resource")
		if res and res.has_method("reset_charges_for_turn"):
			res.reset_charges_for_turn()
	player.dice_pool.roll_hand()
	_finalize_hand(player.dice_pool)
	_hand_live = true
	# Place dice until the policy has nothing useful left
	var guard := 0
	while not _ended and guard < 20:
		guard += 1
		var choice: Dictionary = policy.choose_action(self)
		if choice.is_empty():
			break
		_sim_player_action(choice)
	log["unplaced_dice"] += player.dice_pool.get_unconsumed_count()
	_hand_live = false
	if _ended:
		return
	# End of turn
	_ticks(player_combatant, player.status_tracker.process_turn_end())
	if _ended:
		return
	_apply_proc_results(proc_processor.process_turn_end(player.affix_manager, _build_proc_context()))
	player.dice_pool.end_turn()
	_check_combat_end()


func _sim_player_action(choice: Dictionary) -> void:
	var a: Dictionary = choice["action"]
	var dice: Array = choice["dice"]
	var target: Combatant = choice["target"]
	var res: Action = a.get("action_resource")
	for d in dice:
		player.dice_pool.consume_from_hand(d)
	if res:
		res.consume_charge()
		track_charge_used(res)
	var action_data := {
		"name": a.get("name", ""),
		"action_type": a.get("action_type", 0),
		"base_damage": a.get("base_damage", 0),
		"damage_multiplier": a.get("damage_multiplier", 1.0),
		"placed_dice": dice.duplicate(),
		"source": a.get("source", ""),
		"action_resource": res,
		"target": target,
		"target_index": enemy_combatants.find(target),
		"is_class_action": a.get("is_class_action", false),
	}
	# ON_USE dice affixes (as _on_action_confirmed)
	var on_use_ctx: Dictionary = {}
	if target and target.is_alive():
		var t_tracker = _get_status_tracker(target)
		if t_tracker:
			var ts: Dictionary = {}
			for inst in t_tracker.get_all_active():
				var sa = inst.get("status_affix")
				if sa and sa.status_id != "":
					ts[sa.status_id] = {"stacks": inst.get("current_stacks", 0)}
			on_use_ctx["target_statuses"] = ts
	player.dice_pool.process_on_use_affixes(action_data["placed_dice"], on_use_ctx)
	# Measurement only: raw (pre-defence) hit with and without the dice
	if int(action_data["action_type"]) == 0 and res and target:
		_measure_dice_share(action_data, target)
	var before := _enemy_hp_sum()
	var targets: Array = [target] if target else []
	log["player_actions"] += 1
	if a.get("is_class_action", false):
		log["class_actions"] += 1
	else:
		log["weapon_actions"] += 1
	_apply_action_effect(action_data, player_combatant, targets)
	_drain_chain_hops()
	var r: Dictionary = action_data.get("_last_damage_result", {})
	if r.get("is_crit", false):
		log["crit_extra"] += maxi(0, int(r.get("total_damage", 0)) - int(r.get("pre_crit_damage", 0)))
	log["player_damage"] += maxi(0, before - _enemy_hp_sum())
	_check_combat_end()


func estimate_damage(action_data: Dictionary, target: Combatant) -> Dictionary:
	"""The real damage calculation for a planned hit (no HP changes)."""
	return _calculate_damage(action_data, player_combatant, target)


func _measure_dice_share(action_data: Dictionary, target: Combatant) -> void:
	"""Raw (pre-defence) damage of this hit through the real calculation:
	with the dice as rolled, with every die at 0, and with the dice at their
	face value only (stat and gear pips removed)."""
	var placed: Array = action_data.get("placed_dice", [])
	var full := _raw_hit(action_data, placed, target)
	if full <= 0.0:
		return
	var zeroed: Array = []
	var faces: Array = []
	for d in placed:
		if d is DieResource:
			var z: DieResource = d.duplicate_die()
			z.modified_value = 0
			zeroed.append(z)
			var f: DieResource = d.duplicate_die()
			var pips: int = int(d.get_meta("stat_bonus_applied", 0))
			f.modified_value = maxi(0, d.modified_value - pips)
			faces.append(f)
	log["raw_hit"] += full
	log["raw_no_dice"] += _raw_hit(action_data, zeroed, target)
	log["raw_no_pips"] += _raw_hit(action_data, faces, target)


func _raw_hit(action_data: Dictionary, dice: Array, target: Combatant) -> float:
	var d := action_data.duplicate()
	d["placed_dice"] = dice
	var r: Dictionary = _calculate_damage(d, player_combatant, target)
	var total := 0.0
	var eb: Dictionary = r.get("element_breakdown", {})
	for k in eb:
		total += float(eb[k])
	return total


func _sim_enemy_turn(enemy: Combatant) -> void:
	combat_state = CombatState.ENEMY_TURN
	var tracker: StatusTracker = _get_status_tracker(enemy)
	if tracker:
		_ticks(enemy, tracker.process_turn_start())
		if _ended or not enemy.is_alive():
			return
	for action_dict in enemy.actions:
		var ar = action_dict.get("action_resource") as Action
		if ar:
			ar.reset_charges_for_turn()
	enemy.start_turn()
	_finalize_hand(enemy.dice_collection)
	if enemy.dice_collection:
		_resolve_combat_events(enemy.dice_collection.drain_combat_events(), player_combatant, 0, enemy)
	var guard := 0
	while not _ended and enemy.is_alive() and enemy.has_usable_dice() and guard < 12:
		guard += 1
		if not _sim_enemy_decide_and_act(enemy):
			break
	if _ended:
		return
	# _finish_enemy_turn
	if tracker:
		if tracker.has_status("taunt"):
			tracker.remove_status("taunt")
		_ticks(enemy, tracker.process_turn_end())
		if _ended:
			return
	enemy.end_turn()


func _sim_enemy_decide_and_act(enemy: Combatant) -> bool:
	var idx := enemy_combatants.find(enemy)
	if idx < 0 or idx >= enemy_threat_trackers.size():
		return false
	var target = TargetSelector.select_target(enemy, enemy_threat_trackers[idx], companion_manager, player_combatant)
	if not target or not target.is_alive():
		return false
	var effective_strategy: int = enemy.ai_strategy
	if enemy.enemy_data and enemy.enemy_data.escalation_rules.size() > 0:
		var esc_context := {
			"self_hp_percent": float(enemy.current_health) / float(maxi(enemy.max_health, 1)),
			"alive_ally_count": _count_alive_enemies_except(enemy),
			"ally_lowest_hp_percent": _lowest_ally_hp_percent(enemy),
			"total_ally_count": enemy_combatants.size() - 1,
			"turn_number": current_round,
		}
		for rule: AIEscalationRule in enemy.enemy_data.escalation_rules:
			if rule and rule.evaluate(esc_context):
				effective_strategy = rule.new_strategy
				break
	var ai_context := {
		"enemy": enemy, "target": target, "turn_number": current_round,
		"ally_lowest_hp_percent": _lowest_ally_hp_percent(enemy),
	}
	var et: StatusTracker = _get_status_tracker(enemy)
	if et and et.has_status("restrained"):
		var escape_res = load("res://resources/actions/escape_action.tres") as Action
		if escape_res:
			ai_context["escape_action"] = escape_res
	if enemy.enemy_data and enemy.enemy_data.ai_config:
		ai_context["ai_config"] = enemy.enemy_data.ai_config
	if enemy.enemy_data and enemy.enemy_data.team_aware:
		ai_context["allied_enemies"] = _get_alive_enemies_except(enemy)
	var decision = EnemyAI.decide(enemy.actions, enemy.get_available_dice(), effective_strategy, ai_context)
	if not decision:
		return false
	var action_resource = decision.action.get("action_resource") as Action
	if action_resource:
		var side = TargetingMode.get_target_side(action_resource.get_targeting_mode())
		if side == TargetingMode.TargetSide.ENEMY or side == TargetingMode.TargetSide.BOTH:
			decision.action["selected_target"] = target
		else:
			decision.action["selected_target"] = enemy
	else:
		decision.action["selected_target"] = target
	# _execute_enemy_action_immediate, minus the timer
	var action_data = decision.action.duplicate()
	action_data["placed_dice"] = decision.dice
	var tgt: Combatant = action_data.get("selected_target", player_combatant)
	if not tgt or not tgt.is_alive():
		tgt = player_combatant
	for die in decision.dice:
		enemy.consume_action_die(die)
	if action_resource and action_resource.action_category == Action.ActionCategory.ESCAPE:
		# Escape attempts (Restrained) are resolved by an animated UI path;
		# the sim just spends the dice.
		action_resource.consume_charge()
		return true
	_process_enemy_on_use(enemy, decision.dice, tgt)
	var hp_before: int = player_combatant.current_health
	log["enemy_actions"] += 1
	_apply_action_effect(action_data, enemy, [tgt])
	_drain_chain_hops()
	var lost: int = hp_before - player_combatant.current_health
	if lost > 0:
		log["enemy_hits"].append(lost)
	if action_resource:
		action_resource.consume_charge()
	_check_player_death()
	_check_combat_end()
	return true
