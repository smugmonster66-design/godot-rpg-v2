# res://tests/damage_core_test.gd
# Headless test of engine/damage-core: player area attacks hit every enemy
# (Audit E12), damage effects honour value sources and conditions (E13),
# dice-affix statuses can target all enemies (E8), chain hops keep at least
# 1 damage (E9). The dice formula itself is covered in stats_test.
# WRITES user://save.tres (run through tools/run_tests.sh, which restores it).
#
#   godot --headless --path . res://tests/damage_core_test.tscn
extends Node

const BRUTE := "res://resources/enemies/baseline/trash/brute.tres"

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


func _fixed_die(value: int, element: int = DieResource.Element.SLASHING) -> DieResource:
	var d := DieResource.new()
	d.die_type = DieResource.DieType.D12
	d.element = element
	d.set_value(value)
	return d


func _attack(effect: ActionEffect, die_value: int) -> Dictionary:
	var a := Action.new()
	a.action_id = "test_attack"
	a.action_name = "Test Attack"
	a.action_type = 0
	a.effects = [effect]
	var d: Dictionary = a.to_dict()
	d["action_resource"] = a
	d["action_type"] = 0
	d["placed_dice"] = [_fixed_die(die_value)]
	return d


func _run() -> void:
	await _frames(10)
	var title: Node = _root.find_child("TitleScreen", true, false)
	if title:
		title.new_game_confirmed.emit()
	await _frames(30)
	var enc := CombatEncounter.new()
	enc.encounter_id = "test_damage_core"
	var brute: EnemyData = load(BRUTE)
	var enemies: Array[EnemyData] = [brute, brute, brute]
	enc.enemies = enemies
	enc.player_starts_first = true
	enc.stat_multiplier = 20.0   # nobody dies during the test
	GameManager.pending_encounter = enc
	_root.start_combat(enc)
	await _frames(90)
	_cm = _root.combat_scene.find_child("CombatManager", true, false)
	if _cm == null:
		_cm = _root.combat_scene
	var foes: Array = _cm.enemy_combatants
	_check(foes.size() == 3, "fight started with 3 enemies")
	if foes.size() < 3:
		_finish()
		return
	var pc: Combatant = _cm.player_combatant

	# --- E12: an area attack damages every enemy
	var aoe := ActionEffect.new()
	aoe.effect_type = ActionEffect.EffectType.DAMAGE
	aoe.target = ActionEffect.TargetType.ALL_ENEMIES
	aoe.dice_count = 1
	aoe.base_damage = 5
	var before: Array = foes.map(func(e): return e.current_health)
	_cm._apply_action_effect(_attack(aoe, 8), pc, [foes[0]])
	await _frames(5)
	var all_hit := true
	for i in foes.size():
		if foes[i].current_health >= before[i]:
			all_hit = false
	_check(all_hit, "an area attack damages all three enemies")

	# Single-target still hits one
	var single := ActionEffect.new()
	single.effect_type = ActionEffect.EffectType.DAMAGE
	single.dice_count = 1
	single.base_damage = 5
	before = foes.map(func(e): return e.current_health)
	_cm._apply_action_effect(_attack(single, 8), pc, [foes[1]])
	await _frames(5)
	_check(foes[1].current_health < before[1] and foes[0].current_health == before[0] and foes[2].current_health == before[2],
		"a single-target attack damages only its target")

	# --- E13: value source (per stack of a status on the target)
	var burn: StatusAffix = load("res://resources/statuses/burn.tres")
	var per_stack := ActionEffect.new()
	per_stack.effect_type = ActionEffect.EffectType.DAMAGE
	per_stack.dice_count = 0
	per_stack.base_damage = 10
	per_stack.value_source = ActionEffect.ValueSource.TARGET_STATUS_STACKS
	per_stack.value_source_status_id = "burn"
	var t2: StatusTracker = _cm._get_status_tracker(foes[2])
	if t2.has_status("burn"):
		t2.remove_status("burn")
	var dmg0: int = _cm._calculate_damage(_attack(per_stack, 1), pc, foes[2]).total_damage
	t2.apply_status(burn, 3, "test")
	var dmg3: int = _cm._calculate_damage(_attack(per_stack, 1), pc, foes[2]).total_damage
	_check(dmg3 > dmg0, "damage per Burn stack grows with stacks (%d -> %d)" % [dmg0, dmg3])

	# Condition blocks the effect
	var cond := ActionEffectCondition.new()
	cond.condition_type = ActionEffectCondition.ConditionType.TARGET_HP_BELOW
	if true:
		cond.threshold = 0.01
		var gated := ActionEffect.new()
		gated.effect_type = ActionEffect.EffectType.DAMAGE
		gated.dice_count = 0
		gated.base_damage = 50
		gated.condition = cond
		var gd: int = _cm._calculate_damage(_attack(gated, 1), pc, foes[2]).total_damage
		_check(gd == 0, "a failed condition drops the damage effect (%d)" % gd)

	# --- E8: a dice-affix status can target all enemies
	for e in foes:
		var tr: StatusTracker = _cm._get_status_tracker(e)
		if tr.has_status("chill"):
			tr.remove_status("chill")
	_cm._resolve_apply_status({"status_id": "chill", "stacks": 2, "target": "all_enemies"}, foes[0])
	var all_chilled := true
	for e in foes:
		if _cm._get_status_tracker(e).get_stacks("chill") < 2:
			all_chilled = false
	_check(all_chilled, "an all-enemies dice status reaches every enemy")

	# --- E9: chain hops keep at least 1 damage
	_cm._pending_chain_hops.clear()
	_cm._resolve_chain({"damage": 1, "chains": 2, "decay": 0.5, "element": "5"}, foes[0])
	var hops: Array = _cm._pending_chain_hops
	_check(hops.size() == 1 and hops[0].damages.size() == 2 and hops[0].damages.min() >= 1,
		"a 1-damage chain still hops twice for at least 1")
	_cm._pending_chain_hops.clear()

	# --- Holy (FAITH) is a real damage type: magical, weakness-aware
	var holy := DamagePacket.new()
	holy.add_damage(ActionEffect.DamageType.FAITH, 10.0)
	var plain_holy: int = holy.calculate_final_damage({"armor": 1000, "barrier": 0, "element_modifiers": {}}, 1.0)
	var weak_holy: int = holy.calculate_final_damage({"armor": 0, "barrier": 0, "element_modifiers": {"FAITH": 2.0}}, 1.0)
	_check(plain_holy == 10, "holy damage ignores armour (%d)" % plain_holy)
	_check(weak_holy == 20, "a holy weakness doubles it (%d)" % weak_holy)
	var holy_die := _fixed_die(5, DieResource.Element.FAITH)
	_check(holy_die.get_effective_damage_type(ActionEffect.DamageType.SLASHING) == ActionEffect.DamageType.FAITH,
		"a holy die deals holy damage")
	_finish()


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("damage_core_test: ALL PASSED")
		get_tree().quit(0)
	else:
		print("damage_core_test: %d FAILED" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)
