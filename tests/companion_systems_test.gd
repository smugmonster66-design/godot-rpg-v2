# res://tests/companion_systems_test.gd
# Headless two-step test of the companion engine (engine/companions, Gaps 73-80
# and the approved Companion System).
#   godot --headless --path . res://tests/companion_systems_test.tscn -- start
#   godot --headless --path . res://tests/companion_systems_test.tscn -- continue
# start: recruits and dismisses through every story hook, fights with two
# test companions (reactions, tiers, taunt, statuses, pipeline, bond die,
# Dice-shaper, downed/revive/Wounded, temperaments, summons), then starts a
# second fight and saves at the player's turn with a companion hurt, burning
# and another downed. continue: the roster, party and the fight come back.
# WRITES user://save.tres. Back up your save.
extends Node

const MANNE := "res://resources/companions/companion_manne.tres"
const BRUTE := "res://resources/enemies/baseline/trash/brute.tres"
const EXPECT := "user://_companion_test_expect.json"
## A fight from a file (only those can be saved mid-fight)
const FIELD_FIGHT := "res://resources/encounters/baseline/trash/brute_skirmisher.tres"

var _failures: Array[String] = []
var _root: Node = null
var _mode := "start"
var _notices := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
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


func _cm():
	return _root.get_combat_manager()


func _wait_for_player_turn(max_frames: int = 900) -> bool:
	for i in max_frames:
		var cm = _cm()
		if cm and _root.is_in_combat and cm.combat_state == cm.CombatState.PLAYER_TURN and cm.turn_phase == cm.TurnPhase.PREP:
			return true
		await get_tree().process_frame
	return false


func _run() -> void:
	await _frames(10)
	var title: Node = _root.find_child("TitleScreen", true, false)
	if title:
		if _mode == "continue":
			title.continue_requested.emit()
		else:
			title.new_game_confirmed.emit()
	await _frames(40)
	NotificationManager.notification_queued.connect(func(_d): _notices += 1)
	if _mode == "continue":
		await _continue()
	else:
		await _start()
	_finish()

# ============================================================================
# TEST DATA (generic, not story content)
# ============================================================================

func _effect(type: int, base: int, dice: int = 0) -> ActionEffect:
	var e := ActionEffect.new()
	e.effect_type = type
	e.base_damage = base
	e.base_heal = base
	e.dice_count = dice
	e.shield_amount = base
	e.shield_uses_dice = false
	return e


func _guard() -> CompanionData:
	"""Protector: taunts; Signature hits at turn end with the bond die;
	Reaction shields the player when hurt; Bond ability heals the player."""
	var d := CompanionData.new()
	d.companion_name = "Test Guard"
	d.companion_id = &"test_guard"
	d.base_max_hp = 40
	d.trigger = CompanionData.CompanionTrigger.PLAYER_TURN_END
	d.target_rule = CompanionData.CompanionTarget.RANDOM_ENEMY
	var fx: Array[ActionEffect] = [_effect(ActionEffect.EffectType.DAMAGE, 5, 1)]
	d.action_effects = fx
	d.has_taunt = true
	d.temperament = CompanionData.Temperament.PROUD
	var r := CompanionAbility.new()
	r.trigger = CompanionData.CompanionTrigger.PLAYER_DAMAGED
	r.target_rule = CompanionData.CompanionTarget.PLAYER
	var rfx: Array[ActionEffect] = [_effect(ActionEffect.EffectType.SHIELD, 3)]
	r.action_effects = rfx
	d.reaction = r
	var b := CompanionAbility.new()
	b.trigger = CompanionData.CompanionTrigger.PLAYER_DAMAGED
	b.target_rule = CompanionData.CompanionTarget.PLAYER
	var bfx: Array[ActionEffect] = [_effect(ActionEffect.EffectType.HEAL, 2)]
	b.action_effects = bfx
	d.bond_ability = b
	d.trail_perk = CompanionData.TrailPerk.GOLD_FIND
	d.trail_perk_value = 0.5
	return d


func _mender() -> CompanionData:
	"""Mender + Dice-shaper: raises the lowest die when the hand is rolled
	(not the first time); revives a fallen companion (once per fight)."""
	var d := CompanionData.new()
	d.companion_name = "Test Mender"
	d.companion_id = &"test_mender"
	d.base_max_hp = 30
	d.trigger = CompanionData.CompanionTrigger.HAND_ROLLED
	d.target_rule = CompanionData.CompanionTarget.PLAYER
	d.fires_on_first_turn = false
	var de := CompanionDiceEffect.new()
	de.kind = CompanionDiceEffect.Kind.RAISE
	de.amount = 2
	de.pick = CompanionDiceEffect.Pick.LOWEST
	var dfx: Array[CompanionDiceEffect] = [de]
	d.dice_effects = dfx
	d.temperament = CompanionData.Temperament.LOYAL
	var r := CompanionAbility.new()
	r.trigger = CompanionData.CompanionTrigger.COMPANION_KILLED
	r.target_rule = CompanionData.CompanionTarget.DOWNED_COMPANION
	r.uses_per_combat = 1
	var rfx: Array[ActionEffect] = [_effect(ActionEffect.EffectType.HEAL, 10)]
	r.action_effects = rfx
	d.reaction = r
	return d


func _custom(key: String) -> bool:
	var sc := SingleCheck.new()
	sc.check_type = SingleCheck.CheckType.CUSTOM
	sc.key = StringName(key)
	var cond := GameCondition.new()
	cond.condition_type = GameCondition.ConditionType.SINGLE
	cond.single_check = sc
	return GameState.evaluate_condition(cond)


func _dialogue_action(tag: String) -> void:
	var line := DialogueLine.new()
	line.event_tag = StringName(tag)
	var enc := DialogueEncounter.new()
	enc.encounter_id = &"test_companion_action"
	enc.first_line = line
	DialogueManager.start_dialogue(enc)
	await _frames(3)
	if DialogueManager.is_active:
		DialogueManager.skip_dialogue()
	await _frames(2)


func _encounter() -> CombatEncounter:
	var brute: EnemyData = load(BRUTE)
	var enc := CombatEncounter.new()
	enc.encounter_id = "test_companions"
	enc.encounter_name = "Companion test"
	var enemies: Array[EnemyData] = [brute, brute]
	enc.enemies = enemies
	enc.player_starts_first = true
	return enc


func _slot_of(cm, id: StringName) -> CompanionCombatant:
	for i in range(4):
		var c = cm.companion_manager.get_slot(i)
		if c and c.companion_data and c.companion_data.companion_id == id:
			return c
	return null

# ============================================================================
# START
# ============================================================================

func _start() -> void:
	var p = GameManager.player
	# Dev mode seats test copies of Manne; start from an empty roster.
	p.companion_roster.clear()
	p.active_companions.clear()
	GameState.relationships.set_relationship(&"test_guard", 0)
	GameState.relationships.set_relationship(&"test_mender", 0)
	GameState.relationships.set_relationship(&"manne", 0)

	# --- 73: recruit and dismiss through every hook
	await _dialogue_action("game_action:10:" + MANNE)
	_check(CompanionRoster.is_in_party(&"manne"), "dialogue RECRUIT_COMPANION seats Manne")
	_check(_custom("companion_recruited:manne") and _custom("companion_in_party:manne"), "conditions see the recruit")
	var guard_data := _guard()
	var mender_data := _mender()
	CompanionRoster.recruit(guard_data, true, "test")
	var mender := CompanionRoster.recruit(mender_data, true, "test")
	_check(p.active_companions.size() == 2 and p.companion_roster.size() == 3, "party holds 2; the third waits at camp")
	_check(mender != null and not mender in p.active_companions, "a full party sends the recruit to camp")
	await _dialogue_action("game_action:11:manne")
	_check(not CompanionRoster.is_recruited(&"manne"), "dialogue DISMISS_COMPANION removes Manne")
	_check(CompanionRoster.set_active(mender, true), "the camp companion can be seated")
	var eff := GameEventEffect.new()
	eff.effect_type = GameEventEffect.EffectType.RECRUIT_COMPANION
	eff.item = load(MANNE)
	eff.int_value = 1
	eff.apply()
	var manne := CompanionRoster.find(&"manne")
	_check(manne != null and not manne in p.active_companions, "GameEvent RECRUIT_COMPANION: party full, Manne goes to camp")
	var dis := GameEventEffect.new()
	dis.effect_type = GameEventEffect.EffectType.DISMISS_COMPANION
	dis.key = &"manne"
	dis.apply()
	_check(not CompanionRoster.is_recruited(&"manne"), "GameEvent DISMISS_COMPANION")
	var rw := QuestRewards.new()
	var rc: Array[CompanionData] = [load(MANNE)]
	rw.recruit_companions = rc
	var up: Array[StringName] = [&"manne"]
	rw.upgrade_companion_bonds = up
	QuestManager._grant_rewards(rw)
	manne = CompanionRoster.find(&"manne")
	_check(manne != null and manne.bond_upgraded, "quest reward recruits Manne and upgrades the bond")

	# --- tiers and the bond die (78)
	var rules := CompanionBondRules.get_rules()
	_check(CompanionRoster.get_tier(&"test_guard") == 0 and CompanionRoster.bond_die_sides(guard_data) == 4, "Acquaintance rolls a d4")
	var n0 := _notices
	GameState.modify_relationship(&"test_guard", 85)
	_check(_notices > n0, "relationship change shows a notice")
	GameState.relationships.set_relationship(&"test_mender", 25)
	_check(CompanionRoster.get_tier(&"test_guard") == 3 and CompanionRoster.get_tier_name(&"test_guard") == "Devoted", "85 = Devoted")
	_check(CompanionRoster.bond_die_sides(guard_data) == 10 and CompanionRoster.bond_die_sides(mender_data) == 6, "bond die grows with tier (d10, d6)")
	_check(CompanionRoster.bond_die_sides(load(MANNE), manne) == rules.upgraded_die_sides, "upgraded bond die is d12")
	_check(_custom("companion_tier:test_guard:>=:3"), "companion_tier condition")
	var bonus: int = CompanionRoster.primary_stat_bonus(p)
	var roll: Dictionary = CompanionRoster.roll_bond(guard_data, CompanionRoster.find(&"test_guard"), p)
	_check(roll.value >= 1 + bonus and roll.value <= 10 + bonus, "bond roll = d10 + stat bonus (%d, bonus %d)" % [roll.value, bonus])
	_check(CompanionRoster.trail_bonus(CompanionData.TrailPerk.GOLD_FIND) == 0.5, "Trail perk counts for the active party")

	# --- the fight
	var enc := _encounter()
	GameManager.pending_encounter = enc
	_root.start_combat(enc)
	var ok: bool = await _wait_for_player_turn()
	_check(ok, "fight reached the player's turn")
	if not ok:
		return
	var cm = _cm()
	var pc: Combatant = cm.player_combatant
	var guard := _slot_of(cm, &"test_guard")
	var menderc := _slot_of(cm, &"test_mender")
	_check(guard != null and menderc != null, "both companions took the field")
	if guard == null or menderc == null:
		return
	var e0: Combatant = cm.enemy_combatants[0]
	var e1: Combatant = cm.enemy_combatants[1]

	# 76: status tracker
	_check(guard.status_tracker != null and cm._get_status_tracker(guard) == guard.status_tracker, "companions have a StatusTracker")
	var burn: StatusAffix = load("res://resources/statuses/burn.tres")
	guard.status_tracker.apply_status(burn, 4, "test")
	var ghp: int = guard.current_health
	await cm._tick_companion_statuses(true)
	await cm._tick_companion_statuses(false)
	_check(guard.current_health < ghp, "burn ticks on a companion (%d -> %d)" % [ghp, guard.current_health])
	guard.status_tracker.clear_all()

	# 79: taunt
	cm._apply_companion_taunts(e0)
	var t: Combatant = TargetSelector.select_target(e0, cm.enemy_threat_trackers[0], cm.companion_manager, pc)
	_check(t == guard, "has_taunt: the enemy targets the taunting companion (%s)" % (t.combatant_name if t else "null"))
	cm._get_status_tracker(e0).remove_status("taunt")

	# 75 + tiers: the Reaction (Trusted) and the Bond ability (Devoted, once)
	var ptr: StatusTracker = p.status_tracker
	var oh0: int = ptr.get_stacks("overhealth")
	pc.take_damage(4)
	_check(ptr.get_stacks("overhealth") >= oh0 + 3, "PLAYER_DAMAGED Reaction shields the player (SHIELD -> Overhealth)")
	_check(int(guard.ability_state[&"bond"]["uses"]) == 0, "the Bond ability fired and is spent for the fight")
	GameState.relationships.set_relationship(&"test_guard", 0)
	var oh1: int = ptr.get_stacks("overhealth")
	pc.take_damage(4)
	_check(ptr.get_stacks("overhealth") <= oh1, "below Trusted the Reaction stays locked")
	GameState.relationships.set_relationship(&"test_guard", 85)
	ptr.remove_status("overhealth")

	# 77: companion damage through the pipeline (armour, threat)
	e1.armor = 0
	var h0: int = e1.current_health
	cm._companion_deal_damage(guard, e1, {"damage_type": 0, "base_damage": 12, "multiplier": 1.0, "dice_used": 0})
	var plain: int = h0 - e1.current_health
	e1.current_health = h0
	e1.armor = 1000
	cm._companion_deal_damage(guard, e1, {"damage_type": 0, "base_damage": 12, "multiplier": 1.0, "dice_used": 0})
	var armoured: int = h0 - e1.current_health
	e1.armor = 0
	e1.current_health = h0
	_check(plain > 0 and armoured < plain, "armour reduces companion damage (%d vs %d)" % [armoured, plain])
	_check(cm.enemy_threat_trackers[1].get_threat(guard) > 0.0, "companion damage adds threat")
	var r: Array[Dictionary] = [{"effect_type": ActionEffect.EffectType.SHIELD, "target": menderc, "source": guard, "shield_amount": 5}]
	cm._process_companion_results(r)
	_check(menderc.status_tracker.get_stacks("overhealth") == 5, "SHIELD works on a companion")
	menderc.status_tracker.clear_all()

	# Signature: the bond die feeds a dice-using effect
	var hsum := 0
	for e in cm.enemy_combatants:
		hsum += e.current_health
	await cm._fire_companions_animated(CompanionData.CompanionTrigger.PLAYER_TURN_END)
	var hsum2 := 0
	for e in cm.enemy_combatants:
		hsum2 += e.current_health
	_check(hsum2 < hsum, "Signature (turn end) hits with base + bond die (%d)" % (hsum - hsum2))

	# Dice-shaper (HAND_ROLLED, fires_on_first_turn = false)
	while p.dice_pool.dice.size() < 3:
		p.dice_pool.add_die(DieResource.new(DieResource.DieType.D6, "test"))
	p.dice_pool.roll_hand()
	cm._hand_live = true
	var hand: Array[DieResource] = p.dice_pool.get_unconsumed_hand()
	for d in hand:
		d.set_value(d.get_max_value())
	hand[0].set_value(1)
	var low0: int = hand[0].get_total_value()
	cm._fire_companions_sync(CompanionData.CompanionTrigger.HAND_ROLLED)
	_check(hand[0].get_total_value() == low0, "fires_on_first_turn = false skips the first hand")
	cm._fire_companions_sync(CompanionData.CompanionTrigger.HAND_ROLLED)
	_check(hand[0].get_total_value() == mini(low0 + 2, CompanionDiceEffect.die_max_face(hand[0])), "Dice-shaper raises the lowest die (%d -> %d)" % [low0, hand[0].get_total_value()])
	var setmax := CompanionDiceEffect.new()
	setmax.kind = CompanionDiceEffect.Kind.SET_MAX
	hand[0].set_value(1)
	setmax.apply(p.dice_pool, 0, 0)
	_check(hand[0].current_value == hand[0].get_max_value(), "SET_MAX puts a die on its top face")
	var rr := CompanionDiceEffect.new()
	rr.kind = CompanionDiceEffect.Kind.REROLL_MINIMUM
	rr.count = 0
	hand[0].set_value(1)
	_check(rr.apply(p.dice_pool, 0, 0) >= 1, "REROLL_MINIMUM rerolls the 1s")
	var add := CompanionDiceEffect.new()
	add.kind = CompanionDiceEffect.Kind.ADD_DIE
	var before: int = p.dice_pool.hand.size()
	add.apply(p.dice_pool, 3, 6)
	_check(p.dice_pool.hand.size() == before + 1 and p.dice_pool.hand[-1].has_tag(CompanionDiceEffect.TEMP_DIE_TAG), "ADD_DIE adds a temporary d6")
	cm._hand_live = false

	# Downed, temperament (Proud), Mender revive -> Wounded
	var rel0: int = GameState.get_relationship(&"test_guard")
	guard.take_damage(99999)
	var ginst := CompanionRoster.find(&"test_guard")
	_check(guard.is_alive(), "the Mender's Reaction revived the downed companion")
	_check(ginst.is_wounded and guard.max_health < ginst.get_full_max_hp(p.max_hp, p.level), "revived mid-fight = Wounded (max %d of %d)" % [guard.max_health, ginst.get_full_max_hp(p.max_hp, p.level)])
	_check(GameState.get_relationship(&"test_guard") == mini(100, rel0 - 3 + 5), "Proud: -3 when downed, +5 revived mid-fight (%d -> %d)" % [rel0, GameState.get_relationship(&"test_guard")])
	# Second fall: the Mender's revive is spent; a consumable brings them back
	guard.take_damage(99999)
	_check(not guard.is_alive() and ginst.is_dead, "downed again (the Mender's revive is once per fight)")
	var downed_camper := CompanionInstance.new()
	downed_camper.companion_data = _mender()
	downed_camper.is_dead = true
	p.companion_roster.append(downed_camper)
	_check(not CompanionRoster.can_activate(downed_camper) and not CompanionRoster.set_active(downed_camper, true), "a downed companion can't be seated from camp")
	p.companion_roster.erase(downed_camper)
	_check(cm.trigger_processor.evaluate_trigger(CompanionData.CompanionTrigger.PLAYER_TURN_END).filter(func(x): return x.companion == guard).is_empty(), "a downed companion doesn't act")
	var potion := ConsumableItem.new()
	potion.use_context = ConsumableItem.UseContext.ANY
	potion.revive_companions = true
	potion.revive_hp_percent = 0.5
	var used: Dictionary = potion.use(p, {"in_combat": true})
	_check(used.get("success", false) and guard.is_alive(), "revive consumable works mid-fight")

	# Summons: expiry clears the panel slot; Storm Sprite has its data
	var sprite_eff: ActionEffect = load("res://resources/actions/mage/storm/effects/storm_sprite_summon.tres")
	_check(sprite_eff.companion_data != null, "Storm Sprite summon has companion_data")
	var sprite: CompanionData = sprite_eff.companion_data.duplicate()
	sprite.duration_turns = 1
	var sc: CompanionCombatant = cm.companion_manager.summon(sprite)
	_check(sc != null, "summoned a sprite")
	if sc and cm.companion_panel:
		cm.companion_panel.set_companion(sc.slot_index, sc)
		var sidx: int = sc.slot_index
		for s in cm.companion_manager.tick_round():
			cm.companion_manager.remove_summon(s)
		_check(cm.companion_manager.get_slot(sidx) == null and cm.companion_panel.get_slot(sidx).is_empty, "an expired summon leaves the panel")

	# Down the Mender, then end the fight properly (sync)
	menderc.take_damage(99999)
	_check(not menderc.is_alive(), "Mender downed")
	var ghp_end: int = guard.current_health
	cm.end_combat(true)
	await _frames(30)
	if _root.post_combat_summary and _root.post_combat_summary.visible:
		_root._on_summary_closed()
	await _frames(10)
	var minst := CompanionRoster.find(&"test_mender")
	_check(minst.is_dead and ginst.current_hp == ghp_end, "fight end syncs HP and downed state")

	# --- second fight: save at the player's turn with companion state
	manne.current_hp = 1
	GameManager.pending_encounter = load(FIELD_FIGHT)
	_root.start_combat(GameManager.pending_encounter)
	ok = await _wait_for_player_turn()
	_check(ok, "second fight reached the player's turn")
	if not ok:
		return
	cm = _cm()
	guard = _slot_of(cm, &"test_guard")
	menderc = _slot_of(cm, &"test_mender")
	_check(menderc != null and not menderc.is_alive(), "a downed companion starts the next fight downed")
	guard.current_health = maxi(1, guard.current_health - 3)
	guard.status_tracker.apply_status(burn, 2, "test")
	guard.ability_state[&"bond"]["uses"] = 0
	cm._turn_save_point = true
	GameState.save_now_if_allowed()
	cm._turn_save_point = false
	var saved = load("user://save.tres")
	_check(saved != null and saved.has_companion_state and saved.companion_roster.size() == 3, "the save holds the roster (3)")
	_check(saved != null and not saved.combat_state.is_empty() and saved.combat_state.companions.size() == 2, "the save holds the fight with its companions")
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"guard_hp": guard.current_health, "guard_max": guard.max_health,
		"guard_rel": GameState.get_relationship(&"test_guard"),
		"mender_rel": GameState.get_relationship(&"test_mender"),
	}))
	f.close()
	GameState.session_active = false   # close the app mid-fight

# ============================================================================
# CONTINUE
# ============================================================================

func _continue() -> void:
	var f := FileAccess.open(EXPECT, FileAccess.READ)
	_check(f != null, "found the start step's expectations")
	if f == null:
		return
	var ex: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var p = GameManager.player
	_check(p.companion_roster.size() == 3 and p.active_companions.size() == 2, "roster (3) and party (2) came back")
	var ginst := CompanionRoster.find(&"test_guard")
	var minst := CompanionRoster.find(&"test_mender")
	var manne := CompanionRoster.find(&"manne")
	_check(ginst != null and minst != null and manne != null, "every companion is back")
	if ginst == null or minst == null or manne == null:
		return
	_check(p.active_companions[0] == ginst and p.active_companions[1] == minst, "party order kept")
	_check(ginst.is_wounded and minst.is_dead, "Wounded and downed kept")
	_check(manne.bond_upgraded and not manne in p.active_companions and manne.current_hp == 1, "camp companion kept (bond upgrade, HP)")
	_check(ginst.companion_data.reaction != null and ginst.companion_data.bond_ability != null, "abilities saved with the companion")
	_check(GameState.get_relationship(&"test_guard") == int(ex.guard_rel) and CompanionRoster.get_tier(&"test_guard") == 3, "relationship and tier kept")

	var ok: bool = await _wait_for_player_turn()
	_check(ok, "Continue put the fight back")
	if not ok:
		return
	var cm = _cm()
	var guard := _slot_of(cm, &"test_guard")
	var menderc := _slot_of(cm, &"test_mender")
	_check(guard != null and menderc != null, "companions back on the field")
	if guard == null or menderc == null:
		return
	_check(guard.max_health == int(ex.guard_max), "companion max HP (Wounded) restored (%d)" % guard.max_health)
	_check(abs(guard.current_health - int(ex.guard_hp)) <= 4, "companion HP restored (%d, saved %d)" % [guard.current_health, int(ex.guard_hp)])
	_check(guard.status_tracker.get_stacks("burn") > 0, "companion statuses restored")
	_check(int(guard.ability_state[&"bond"]["uses"]) == 0, "spent Bond ability stays spent")
	_check(not menderc.is_alive(), "downed companion still downed")
	_check(GameState.get_relationship(&"test_guard") == int(ex.guard_rel), "restoring a downed companion didn't re-run temperament")

	cm.end_combat(true)
	await _frames(30)
	if _root.post_combat_summary and _root.post_combat_summary.visible:
		_root._on_summary_closed()
	await _frames(10)

	# A proper rest: the whole roster recovers, Wounded ends
	CompanionRoster.rest(p, 1.0, true)
	_check(not minst.is_dead and not ginst.is_wounded, "a proper rest revives and ends Wounded")
	_check(manne.current_hp > 1, "camp companions heal on rest")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EXPECT))


func _finish() -> void:
	GameState.session_active = false
	if _failures.is_empty():
		print("companion_systems_test: ALL PASSED (%s)" % _mode)
		get_tree().quit(0)
	else:
		print("companion_systems_test: %d FAILED (%s)" % [_failures.size(), _mode])
		for fl in _failures:
			print("   - " + fl)
		get_tree().quit(1)
