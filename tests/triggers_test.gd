# res://tests/triggers_test.gd
# Headless test of engine/triggers: the combat event hub (status applied,
# freeze, enemy acted, enemy died with the killing element) and gear procs
# on the new triggers, including max_per_turn (Audit E1, E2).
# WRITES user://save.tres (run through tools/run_tests.sh, which restores it).
#
#   godot --headless --path . res://tests/triggers_test.tscn
extends Node

const BRUTE := "res://resources/enemies/baseline/trash/brute.tres"
const POKE := "res://resources/actions/enemy_base/poke.tres"

var _failures: Array[String] = []
var _cm: Node = null
var _root: Node = null
var _events: Array = []


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


func _kinds() -> Array:
	return _events.map(func(e): return e[0])


func _status_action(status_id: String, stacks: int) -> Dictionary:
	var eff := ActionEffect.new()
	eff.effect_type = ActionEffect.EffectType.ADD_STATUS
	eff.status_affix = load("res://resources/statuses/%s.tres" % status_id)
	eff.stack_count = stacks
	var a := Action.new()
	a.action_id = "test_status_%s" % status_id
	a.action_type = 3
	a.effects = [eff]
	var d: Dictionary = a.to_dict()
	d["action_resource"] = a
	d["action_type"] = 3
	d["placed_dice"] = []
	return d


func _fire_hit(value: int) -> Dictionary:
	var eff := ActionEffect.new()
	eff.effect_type = ActionEffect.EffectType.DAMAGE
	eff.damage_type = ActionEffect.DamageType.FIRE
	eff.dice_count = 0
	eff.base_damage = value
	var a := Action.new()
	a.action_id = "test_fire_hit"
	a.action_type = 0
	a.effects = [eff]
	var d: Dictionary = a.to_dict()
	d["action_resource"] = a
	d["action_type"] = 0
	d["placed_dice"] = []
	return d


func _run() -> void:
	await _frames(10)
	var title: Node = _root.find_child("TitleScreen", true, false)
	if title:
		title.new_game_confirmed.emit()
	await _frames(30)
	var enc := CombatEncounter.new()
	enc.encounter_id = "test_triggers"
	var brute: EnemyData = load(BRUTE)
	var enemies: Array[EnemyData] = [brute, brute]
	enc.enemies = enemies
	enc.player_starts_first = true
	GameManager.pending_encounter = enc
	_root.start_combat(enc)
	await _frames(90)
	_cm = _root.combat_scene.find_child("CombatManager", true, false)
	if _cm == null:
		_cm = _root.combat_scene
	var foes: Array = _cm.enemy_combatants
	_check(foes.size() == 2, "fight started with 2 enemies")
	if foes.size() < 2:
		_finish()
		return
	var pc: Combatant = _cm.player_combatant
	_cm.combat_event.connect(func(kind, data): _events.append([kind, data]))

	# --- a proc on ON_STATUS_APPLIED, capped once per turn
	var p = GameManager.player
	var proc := Affix.new()
	proc.affix_name = "Test Status Heal"
	proc.category = Affix.Category.PROC
	proc.proc_trigger = Affix.ProcTrigger.ON_STATUS_APPLIED
	proc.effect_number = 5
	proc.effect_data = {"effect": "heal_flat", "max_per_turn": 1}
	p.affix_manager.add_affix(proc)
	p.current_hp = maxi(1, p.max_hp - 40)
	pc.current_health = p.current_hp
	var hp0: int = pc.current_health

	# --- status applied by the player
	_events.clear()
	_cm._apply_action_effect(_status_action("bleed", 2), pc, [foes[0]])
	await _frames(3)
	var applied := _events.filter(func(e): return e[0] == &"status_applied")
	_check(applied.size() >= 1 and applied[0][1].get("by_player", false) and applied[0][1].get("status_id") == "bleed",
		"status_applied fires, marked as the player's")
	_check(_kinds().has(&"action_used"), "action_used fires")
	var hp1: int = pc.current_health
	_check(hp1 > hp0, "an ON_STATUS_APPLIED gear proc fires (HP %d -> %d)" % [hp0, hp1])
	_cm._apply_action_effect(_status_action("bleed", 1), pc, [foes[0]])
	await _frames(3)
	_check(pc.current_health == hp1, "max_per_turn caps the proc at once per turn")
	_cm.proc_processor.reset_turn_counters()

	# --- freeze
	_events.clear()
	_cm._apply_action_effect(_status_action("freeze", 1), pc, [foes[1]])
	await _frames(3)
	_check(_kinds().has(&"freeze"), "applying Freeze fires a freeze event")

	# --- enemy acted
	_events.clear()
	var poke: Action = load(POKE)
	var pd: Dictionary = poke.to_dict()
	pd["action_resource"] = poke
	var die := DieResource.new()
	die.set_value(3)
	pd["placed_dice"] = [die]
	_cm._apply_action_effect(pd, foes[0], [pc])
	await _frames(3)
	_check(_kinds().has(&"enemy_acted"), "an enemy action fires enemy_acted")

	# --- enemy died, killed by fire
	_events.clear()
	foes[1].current_health = 1
	_cm._apply_action_effect(_fire_hit(50), pc, [foes[1]])
	await _frames(5)
	var died := _events.filter(func(e): return e[0] == &"enemy_died")
	_check(died.size() == 1, "a death fires enemy_died")
	_check(died.size() == 1 and died[0][1].get("by_fire_or_holy", false),
		"the death knows it was a fire kill (element %s)" % (str(died[0][1].get("element")) if died.size() else "-"))
	_finish()


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("triggers_test: ALL PASSED")
		get_tree().quit(0)
	else:
		print("triggers_test: %d FAILED" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)
