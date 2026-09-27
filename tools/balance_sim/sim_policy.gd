# res://tools/balance_sim/sim_policy.gd
# The simulated player: a simple, sensible heuristic for placing dice.
#
# Each step of the ACTION phase:
#   1. List every usable action (has charges; for Chromatic Bolt and other
#      element-limited actions only dice of an accepted element count).
#   2. For each action, fill its die slots with the highest-value legal dice
#      (an action needs all its slots filled, as ActionField requires).
#   3. Score it with the real damage calculation (CombatManager.
#      _calculate_damage, pre-defence) divided by the dice it spends: damage
#      per die. Attacks only; Parry and other non-attacks are used with dice
#      no attack can take.
#   4. Pick the best damage per die. Ties go to the action that spends more
#      dice (a 2-slot staff hit uses the hand better than two 1-slot hits
#      only when it's at least as good per die).
#   5. Target: an enemy this hit is likely to kill (estimated hit >= its HP),
#      the one with the most max HP among those; otherwise the enemy with the
#      least HP left (focus fire).
# No skills; the Mage cannot pull mana dice without skill unlocks.
extends RefCounted

var cm = null


func begin_fight(p_cm) -> void:
	cm = p_cm


func prep_phase(_cm) -> void:
	# Consumables can't be used in a fight (every restorative is
	# OUT_OF_COMBAT, preps are PRE_COMBAT); nothing to do here.
	pass


func _legal_dice(action: Dictionary) -> Array:
	var res: Action = action.get("action_resource")
	var accepted: Array = res.accepted_elements if res else []
	var out: Array = []
	for d in cm.player.dice_pool.get_unconsumed_hand():
		if d.is_locked or d.is_shattered:
			continue
		if accepted.size() > 0 and not (int(d.get_effective_element()) in accepted):
			continue
		out.append(d)
	out.sort_custom(func(a, b): return a.get_total_value() > b.get_total_value())
	return out


func _alive_enemies() -> Array:
	return cm.enemy_combatants.filter(func(e): return e.is_alive())


func choose_action(_cm) -> Dictionary:
	var enemies := _alive_enemies()
	if enemies.is_empty():
		return {}
	var best: Dictionary = {}
	var best_score := -1.0
	var fallback: Dictionary = {}
	for a in cm.player_actions:
		var res: Action = a.get("action_resource")
		if res and not res.has_charges():
			continue
		var slots: int = maxi(1, int(a.get("die_slots", 1)))
		var legal := _legal_dice(a)
		if legal.size() < slots:
			continue
		var dice: Array = legal.slice(0, slots)
		var is_attack: bool = int(a.get("action_type", 0)) == 0 and (res == null or res.action_category == Action.ActionCategory.ATTACK)
		if not is_attack:
			if fallback.is_empty():
				fallback = {"action": a, "dice": dice, "target": enemies[0]}
			continue
		var est := _estimate(a, dice, enemies[0])
		var score := est / float(slots) + 0.001 * slots
		if score > best_score:
			best_score = score
			best = {"action": a, "dice": dice, "est": est}
	if best.is_empty():
		return fallback
	best["target"] = _pick_target(enemies, float(best.get("est", 0.0)))
	return best


func _estimate(a: Dictionary, dice: Array, target: Combatant) -> float:
	var data := {
		"placed_dice": dice,
		"action_resource": a.get("action_resource"),
		"base_damage": a.get("base_damage", 0),
		"damage_multiplier": a.get("damage_multiplier", 1.0),
		"action_type": a.get("action_type", 0),
	}
	var r: Dictionary = cm.estimate_damage(data, target)
	var total := 0.0
	var eb: Dictionary = r.get("element_breakdown", {})
	for k in eb:
		total += float(eb[k])
	return total


func _pick_target(enemies: Array, est: float) -> Combatant:
	var killable: Array = []
	for e in enemies:
		var arm: float = maxf(float(e.armor), float(e.barrier))
		if est - arm * 0.5 >= e.current_health:
			killable.append(e)
	if not killable.is_empty():
		killable.sort_custom(func(x, y): return x.max_health > y.max_health)
		return killable[0]
	var low: Combatant = enemies[0]
	for e in enemies:
		if e.current_health < low.current_health:
			low = e
	return low
