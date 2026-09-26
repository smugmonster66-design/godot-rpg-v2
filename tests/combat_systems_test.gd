# res://tests/combat_systems_test.gd
# Headless test of the combat fixes (engine/combat-fixes): starts a real fight
# on a NEW game and drives enemy actions directly through CombatManager.
# WRITES user://save.tres (autosave). Back up your save first.
#
#   godot --headless --path . res://tests/combat_systems_test.tscn
extends Node

const BRUTE := "res://resources/enemies/baseline/trash/brute.tres"
const RALLY := "res://resources/actions/enemy_base/rally.tres"
const MASS_MEND := "res://resources/actions/enemy_base/mass_mend.tres"
const CHAIN_SPARK := "res://resources/actions/enemy_base/chain_spark.tres"

var _failures: Array[String] = []
var _cm: Node = null
var _root: Node = null


func _ready() -> void:
	_root = load("res://scenes/game/game_root.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_root)
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + what)
	if not cond:
		_failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _encounter(mult: float) -> CombatEncounter:
	var brute: EnemyData = load(BRUTE)
	var enc := CombatEncounter.new()
	enc.encounter_id = "test_combat_fixes"
	enc.encounter_name = "Combat fixes test"
	var enemies: Array[EnemyData] = [brute, brute, brute]
	enc.enemies = enemies
	enc.player_starts_first = true
	enc.stat_multiplier = mult
	return enc


func _action(path: String, source: Combatant) -> Dictionary:
	var a: Action = load(path)
	var d: Dictionary = a.to_dict()
	d["action_resource"] = a
	d["source"] = source.combatant_name
	# Outside its turn an enemy holds no dice; give it one fresh, rolled die.
	var dice: Array = source.enemy_data.create_dice_copies() if source.enemy_data else []
	for die in dice:
		for i in 50:  # reroll until the die shows a useful value
			die.roll()
			if die.get_total_value() >= 4:
				break
	d["placed_dice"] = dice.slice(0, 1)
	return d


func _tracker(c) -> StatusTracker:
	return _cm._get_status_tracker(c)


func _run() -> void:
	await _frames(10)
	var title: Node = _root.find_child("TitleScreen", true, false)
	if title:
		title.new_game_confirmed.emit()
	await _frames(30)

	# --- start a real fight (stat_multiplier 2.0)
	var enc := _encounter(2.0)
	GameManager.pending_encounter = enc
	_root.start_combat(enc)
	await _frames(90)
	_cm = _root.combat_scene.find_child("CombatManager", true, false)
	if _cm == null:
		_cm = _root.combat_scene
	_check(_cm.enemy_combatants.size() == 3, "fight started with 3 enemies (%d)" % _cm.enemy_combatants.size())
	if _cm.enemy_combatants.size() < 3:
		_finish()
		return
	var e0: Combatant = _cm.enemy_combatants[0]
	var e1: Combatant = _cm.enemy_combatants[1]
	var pc: Combatant = _cm.player_combatant

	# --- 52: stat_multiplier doubles HP (before affix bonus / power scaling)
	var base_hp: int = e0.enemy_data.max_health
	var floor_hp: int = int(base_hp * 2.0 * e0._power_scaling_factor) - 1
	_check(e0.encounter_stat_multiplier == 2.0 and e0.max_health >= floor_hp,
		"stat_multiplier applied (base %d, now %d)" % [base_hp, e0.max_health])

	# --- 49: the AI sees the player's real status tracker
	_check(EnemyAI._tracker_of(pc) == GameManager.player.status_tracker, "AI reads the player's live StatusTracker")
	_check(EnemyAI._tracker_of(e0) == e0.get_node_or_null("StatusTracker"), "AI reads an enemy's own StatusTracker")

	# --- 53: action kind from action_category when legacy action_type is 0
	_check(EnemyAI._ai_action_type({"action_category": Action.ActionCategory.HEAL}) == 2, "HEAL category scored as a heal")
	_check(EnemyAI._ai_action_type({"action_type": 1, "action_category": Action.ActionCategory.HEAL}) == 1, "legacy action_type still wins when set")

	# --- 50: role targeting runs and returns a living target
	var t: Combatant = TargetSelector.select_target(e0, _cm.enemy_threat_trackers[0], _cm.companion_manager, pc)
	_check(t != null and t.is_alive(), "role-based targeting returns a target (%s)" % (t.combatant_name if t else "null"))

	# --- 25: enemy ALL_ALLIES buff lands on the enemy team, not the player
	var p_buffs_before: int = _tracker(pc).get_active_buffs().size()
	var e1_buffs_before: int = _tracker(e1).get_active_buffs().size()
	_cm._apply_action_effect(_action(RALLY, e0), e0, [pc])
	await _frames(2)
	_check(_tracker(pc).get_active_buffs().size() == p_buffs_before, "enemy Rally did not buff the player")
	_check(_tracker(e1).get_active_buffs().size() > e1_buffs_before, "enemy Rally buffed another enemy")

	# --- 26: enemy group heal heals the enemy team
	e1.current_health = 1
	e0.current_health = maxi(1, e0.max_health - 5)
	_cm._apply_action_effect(_action(MASS_MEND, e0), e0, [pc])
	await _frames(2)
	_check(e1.current_health > 1, "enemy Mass Mend healed an ally (e1 HP %d)" % e1.current_health)

	# --- 26: enemy chain damages the player
	var hp_before: int = pc.current_health
	_cm._apply_action_effect(_action(CHAIN_SPARK, e0), e0, [pc])
	await _frames(20)
	_check(pc.current_health < hp_before, "enemy Chain Spark damages the player (%d -> %d)" % [hp_before, pc.current_health])

	# --- 56: enemies can't Execute
	var exec_action := Action.new()
	exec_action.action_id = "test_enemy_execute"
	exec_action.action_type = 3
	var ex := ActionEffect.new()
	ex.effect_type = ActionEffect.EffectType.EXECUTE
	ex.execute_instant_kill = true
	ex.execute_threshold = 1.0
	var effs: Array[ActionEffect] = [ex]
	exec_action.effects = effs
	var ed: Dictionary = exec_action.to_dict()
	ed["action_resource"] = exec_action
	pc.current_health = 2
	var hp_exec: int = pc.current_health
	_cm._apply_action_effect(ed, e0, [pc])
	await _frames(2)
	_check(pc.current_health == hp_exec, "enemy EXECUTE refused (player HP %d -> %d)" % [hp_exec, pc.current_health])

	# --- 17: every enemy has its own copy of each action (charges per enemy)
	var a0: Action = e0.actions[0].get("action_resource")
	var a1: Action = e1.actions[0].get("action_resource")
	_check(a0 != a1 and a0.action_id == a1.action_id, "each enemy has its own copy of the same action")
	a0.charge_type = Action.ChargeType.LIMITED_PER_COMBAT
	a1.charge_type = Action.ChargeType.LIMITED_PER_COMBAT
	a0.max_charges = 1
	a1.max_charges = 1
	a0.reset_charges_for_combat()
	a1.reset_charges_for_combat()
	a0.consume_charge()
	_check(not a0.has_charges() and a1.has_charges(), "one enemy using a limited action doesn't use up another's")

	# --- ally is hurt: context, hint, escalation, heal targeting, heal urgency
	e1.current_health = maxi(1, int(e1.max_health * 0.2))
	e0.current_health = e0.max_health
	var lowest: float = _cm._lowest_ally_hp_percent(e0)
	_check(lowest < 0.3, "lowest ally HP%% seen from e0 (%.2f)" % lowest)
	var hint := ActionAIHint.new()
	hint.condition = ActionAIHint.HintCondition.ALLY_HP_BELOW
	hint.threshold = 0.5
	_check(hint.evaluate({"ally_lowest_hp_percent": lowest}) and not hint.evaluate({"ally_lowest_hp_percent": 0.9}), "ALLY_HP_BELOW hint fires only when an ally is hurt")
	var rule := AIEscalationRule.new()
	rule.trigger = AIEscalationRule.EscalationTrigger.ALLY_HP_BELOW
	rule.threshold = 0.5
	_check(rule.evaluate({"ally_lowest_hp_percent": lowest}), "ALLY_HP_BELOW escalation fires")

	var mend := Action.new()
	mend.action_id = "test_mend_most_hurt"
	mend.action_type = 2
	mend.action_category = Action.ActionCategory.HEAL
	var he := ActionEffect.new()
	he.effect_type = ActionEffect.EffectType.HEAL
	he.target = ActionEffect.TargetType.LOWEST_HP_ALLY
	he.heal_uses_dice = true
	he.heal_multiplier = 1.0
	var heffs: Array[ActionEffect] = [he]
	mend.effects = heffs
	var md: Dictionary = mend.to_dict()
	md["action_resource"] = mend
	var die_list: Array = e0.enemy_data.create_dice_copies()
	for die in die_list:
		for i in 50:
			die.roll()
			if die.get_total_value() >= 4:
				break
	md["placed_dice"] = die_list.slice(0, 1)
	e0.current_health = e0.max_health - 1
	var e1_before: int = e1.current_health
	_cm._apply_action_effect(md, e0, [pc])
	await _frames(2)
	_check(e1.current_health > e1_before and e0.current_health == e0.max_health - 1, "LOWEST_HP_ALLY heal went to the hurt ally (e1 %d -> %d)" % [e1_before, e1.current_health])

	var heal_dict: Dictionary = md.duplicate()
	var dice_arr: Array[DieResource] = []
	for die in die_list.slice(0, 1):
		dice_arr.append(die)
	var calm: float = EnemyAI._score_action(heal_dict, dice_arr, EnemyAI.BALANCED, {"enemy": e0, "ally_lowest_hp_percent": 1.0})
	var urgent: float = EnemyAI._score_action(heal_dict, dice_arr, EnemyAI.BALANCED, {"enemy": e0, "ally_lowest_hp_percent": 0.1})
	_check(urgent > calm, "an ally's heal scores higher when an ally is hurt (%.1f > %.1f)" % [urgent, calm])

	# --- 54: encounter_won condition
	GameManager.mark_encounter_completed(enc)
	var sc := SingleCheck.new()
	sc.check_type = SingleCheck.CheckType.CUSTOM
	sc.key = &"encounter_won:test_combat_fixes"
	var cond := GameCondition.new()
	cond.condition_type = GameCondition.ConditionType.SINGLE
	cond.single_check = sc
	_check(GameState.evaluate_condition(cond), "encounter_won:<id> passes after the fight is recorded")

	# --- end the fight cleanly
	_root.end_combat(true)
	await _frames(10)
	_check(GameManager.pending_encounter == null, "pending encounter cleared after the fight")

	# --- 58: a dialogue START_COMBAT that can't start doesn't hang the conversation
	var bad := DialogueLine.new()
	bad.event_tag = &"game_action:0:res://does/not/exist.tres"
	var after := DialogueLine.new()
	after.text = "After."
	bad.next_line = after
	var denc := DialogueEncounter.new()
	denc.encounter_id = &"test_bad_combat"
	denc.first_line = bad
	DialogueManager.start_dialogue(denc)
	await _frames(5)
	_check(not _root.is_in_combat, "bad START_COMBAT didn't start a fight")
	_check(DialogueManager.is_active and not DialogueManager.has_pending_resume(), "conversation carried on after the bad START_COMBAT")
	DialogueManager.skip_dialogue()
	await _frames(3)

	_finish()


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("combat_systems_test: ALL PASSED")
		get_tree().quit(0)
	else:
		print("combat_systems_test: %d FAILED" % _failures.size())
		for f in _failures:
			print("   - " + f)
		get_tree().quit(1)
