# res://scripts/game/companion_trigger_processor.gd
# Evaluates companion triggers and executes their abilities.
# Owned by CombatManager. Stateless between calls (per-ability state lives on
# each CompanionCombatant).
#
# Each companion can have up to three abilities (CompanionData.get_abilities):
# the Signature (always), the Reaction (from Trusted) and the Bond ability
# (from Devoted, once per fight). Every firing rolls the companion's bond die
# (d4..d12 by tier, plus the player's primary-stat bonus) and hands it to the
# effects as their die value.
extends RefCounted
class_name CompanionTriggerProcessor

# ============================================================================
# DEPENDENCIES (set by CombatManager)
# ============================================================================
var _combat_manager = null
var _companion_manager: CompanionManager = null

# ============================================================================
# FIRING ORDER
# ============================================================================
## Canonical slot evaluation order: NPC0, NPC1, Summon0, Summon1
const FIRING_ORDER: Array[int] = [0, 1, 2, 3]

## Triggers about one companion: only that companion's abilities answer.
const SELF_TRIGGERS := [
	CompanionData.CompanionTrigger.COMPANION_DAMAGED,
	CompanionData.CompanionTrigger.ON_DEATH,
	CompanionData.CompanionTrigger.ON_SUMMON,
]
## Triggers about one companion that the others answer.
const OTHERS_TRIGGERS := [
	CompanionData.CompanionTrigger.OTHER_COMPANION_DAMAGED,
	CompanionData.CompanionTrigger.COMPANION_KILLED,
]

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when a companion fires an ability (for UI animation hooks).
signal companion_fired(companion: CompanionCombatant, slot_index: int)

# ============================================================================
# EVALUATE (returns fire entries WITHOUT executing effects)
# ============================================================================

func evaluate_trigger(trigger_type: CompanionData.CompanionTrigger,
		context: Dictionary = {}) -> Array[Dictionary]:
	"""Evaluate every companion's abilities for a trigger.
	Returns one fire entry per ability that should fire. Does NOT execute.

	Each entry: {
		"companion": CompanionCombatant, "slot_index": int,
		"targets": Array[Combatant], "context": Dictionary,
		"ability": CompanionAbility, "ability_slot": StringName,
	}"""
	var fire_entries: Array[Dictionary] = []
	var subject = context.get("source_companion")

	for slot_idx in FIRING_ORDER:
		var companion: CompanionCombatant = _companion_manager.get_slot(slot_idx)
		if not companion or not is_instance_valid(companion) or companion.companion_data == null:
			continue
		# Self / others filtering
		if trigger_type in SELF_TRIGGERS and subject != companion:
			continue
		if trigger_type in OTHERS_TRIGGERS and subject == companion:
			continue
		# Only ON_DEATH lets a companion at 0 HP act (its last word)
		var dying_ok: bool = trigger_type == CompanionData.CompanionTrigger.ON_DEATH
		if not companion.is_alive() and not dying_ok:
			continue
		# Frozen companions don't act
		if not dying_ok and companion.status_tracker and companion.status_tracker.has_status("freeze"):
			continue

		for ab_entry in companion.companion_data.get_abilities():
			var ability: CompanionAbility = ab_entry["ability"]
			var ab_slot: StringName = ab_entry["slot"]
			if ability == null or ability.trigger != trigger_type:
				continue
			if not companion.is_ability_unlocked(ab_slot, ability):
				continue
			if dying_ok and not companion.is_alive():
				var st: Dictionary = companion.ability_state.get(ab_slot, {})
				if int(st.get("uses", -1)) == 0:
					continue
			elif not companion.can_fire_ability(ab_slot):
				continue

			# Trigger thresholds
			if trigger_type == CompanionData.CompanionTrigger.PLAYER_DAMAGED_THRESHOLD:
				var threshold = ability.trigger_data.get("threshold_percent", 0.25)
				if _get_player_hp_percent() > threshold:
					continue
			if trigger_type == CompanionData.CompanionTrigger.PLAYER_HIT_HARD:
				var min_pct: float = ability.trigger_data.get("min_percent", 0.2)
				var pc = _get_player_combatant()
				var max_hp: int = pc.max_health if pc else 1
				if float(context.get("damage_amount", 0)) < min_pct * float(max_hp):
					continue

			# fires_on_first_turn = false: skip the first occurrence
			if companion.consume_first_skip(ab_slot, ability):
				continue

			# Condition gate
			if ability.condition:
				var cond_context = _build_condition_context(companion, context)
				if ability.condition.evaluate(cond_context).blocked:
					continue

			var targets = _resolve_targets(companion, ability.target_rule, context)
			if targets.is_empty():
				print("  [Companion] %s %s matched but no valid targets -- skipped" % [
					companion.combatant_name, ab_slot])
				continue

			fire_entries.append({
				"companion": companion,
				"slot_index": slot_idx,
				"targets": targets,
				"context": context,
				"ability": ability,
				"ability_slot": ab_slot,
			})

	return fire_entries

# ============================================================================
# EXECUTE EFFECTS (called by CombatManager per fire entry)
# ============================================================================

func execute_fire(fire_entry: Dictionary) -> Array[Dictionary]:
	"""Execute one ability and mark it fired. Returns the ActionEffect result
	dictionaries (CombatManager applies them through the shared pipeline)."""
	var companion: CompanionCombatant = fire_entry["companion"]
	var slot_idx: int = fire_entry["slot_index"]
	var ability: CompanionAbility = fire_entry.get("ability")
	var ab_slot: StringName = fire_entry.get("ability_slot", &"signature")
	if ability == null:
		ability = companion.companion_data.get_signature()
	var targets: Array[Combatant] = []
	targets.assign(fire_entry["targets"])
	var context: Dictionary = fire_entry["context"]

	var results = _execute_effects(companion, ability, targets, context)

	companion.on_ability_fired(ab_slot, ability)
	companion_fired.emit(companion, slot_idx)
	print("  [Companion] %s %s FIRED (slot %d, %d results)" % [
		companion.combatant_name, ab_slot, slot_idx, results.size()])
	return results

# ============================================================================
# LEGACY ENTRY POINT (backwards compatibility)
# ============================================================================

func process_trigger(trigger_type: CompanionData.CompanionTrigger,
		context: Dictionary = {}) -> Array[Dictionary]:
	"""Evaluate AND immediately execute all matching abilities."""
	var all_results: Array[Dictionary] = []
	for entry in evaluate_trigger(trigger_type, context):
		all_results.append_array(execute_fire(entry))
	return all_results

# ============================================================================
# TARGET RESOLUTION
# ============================================================================

func _resolve_targets(companion: CompanionCombatant, rule: int, context: Dictionary) -> Array[Combatant]:
	"""Resolve the target(s) for an ability's target rule."""
	var targets: Array[Combatant] = []

	match rule:
		CompanionData.CompanionTarget.RANDOM_ENEMY:
			var enemies = _get_alive_enemies()
			if enemies.size() > 0:
				targets.append(enemies.pick_random())

		CompanionData.CompanionTarget.ALL_ENEMIES:
			targets.append_array(_get_alive_enemies())

		CompanionData.CompanionTarget.LOWEST_HP_ENEMY:
			var enemies = _get_alive_enemies()
			if enemies.size() > 0:
				var lowest = enemies[0]
				for e in enemies:
					if e.current_health < lowest.current_health:
						lowest = e
				targets.append(lowest)

		CompanionData.CompanionTarget.PLAYER:
			var pc = _get_player_combatant()
			if pc:
				targets.append(pc)

		CompanionData.CompanionTarget.SELF:
			targets.append(companion)

		CompanionData.CompanionTarget.OTHER_COMPANION:
			for slot_idx in FIRING_ORDER:
				var other = _companion_manager.get_slot(slot_idx)
				if other and other != companion and other.is_alive():
					targets.append(other)
					break

		CompanionData.CompanionTarget.LOWEST_HP_ALLY:
			var candidates: Array[Combatant] = []
			var pc = _get_player_combatant()
			if pc:
				candidates.append(pc)
			for c in _companion_manager.get_alive_companions():
				candidates.append(c)
			if candidates.size() > 0:
				var lowest = candidates[0]
				for c in candidates:
					if c.current_health < lowest.current_health:
						lowest = c
				targets.append(lowest)

		CompanionData.CompanionTarget.ALL_ALLIES:
			var pc = _get_player_combatant()
			if pc:
				targets.append(pc)
			for c in _companion_manager.get_alive_companions():
				targets.append(c)

		CompanionData.CompanionTarget.TRIGGERING_SOURCE:
			var source = context.get("trigger_source")
			if source and source is Combatant and is_instance_valid(source) and source.is_alive() \
					and source in _get_alive_enemies():
				targets.append(source)
			else:
				var enemies = _get_alive_enemies()
				if enemies.size() > 0:
					targets.append(enemies.pick_random())

		CompanionData.CompanionTarget.DAMAGED_ALLY:
			var damaged = context.get("damaged_target")
			if damaged and damaged is Combatant and is_instance_valid(damaged) and damaged.is_alive():
				targets.append(damaged)
			else:
				targets = _resolve_targets_fallback_lowest_hp(companion)

		CompanionData.CompanionTarget.DOWNED_COMPANION:
			for c in _companion_manager.get_downed_npcs():
				if c != companion:
					targets.append(c)
					break

	return targets

func _resolve_targets_fallback_lowest_hp(companion: CompanionCombatant) -> Array[Combatant]:
	"""Fallback: lowest HP ally."""
	var candidates: Array[Combatant] = []
	var pc = _get_player_combatant()
	if pc:
		candidates.append(pc)
	for c in _companion_manager.get_alive_companions():
		if c != companion:
			candidates.append(c)
	if candidates.size() > 0:
		var lowest = candidates[0]
		for c in candidates:
			if c.current_health < lowest.current_health:
				lowest = c
		return [lowest]
	return []

# ============================================================================
# EFFECT EXECUTION (bond die + ValueSource v2)
# ============================================================================

func roll_bond_for(companion: CompanionCombatant) -> Dictionary:
	"""The bond die roll for one firing (Gap 78)."""
	var player = _combat_manager.player if _combat_manager else null
	return CompanionRoster.roll_bond(companion.companion_data, companion.companion_instance, player)


func _execute_effects(companion: CompanionCombatant, ability: CompanionAbility,
		targets: Array[Combatant], context: Dictionary) -> Array[Dictionary]:
	"""Run the ability's ActionEffects (with the bond roll as their die) and
	its Dice-shaper effects."""
	var all_results: Array[Dictionary] = []
	var bond: Dictionary = roll_bond_for(companion)
	var effect_context = _build_effect_context(companion, context, bond)
	var dice_values: Array = []
	if int(bond.get("value", 0)) > 0:
		dice_values.append(int(bond["value"]))
		print("  [Companion] %s bond roll: d%d=%d +%d = %d" % [companion.combatant_name,
			bond["sides"], bond["roll"], bond["bonus"], bond["value"]])

	for effect in ability.action_effects:
		if not effect:
			continue
		var results = effect.execute(companion, targets, dice_values, effect_context)
		for r in results:
			r["bond_value"] = int(bond.get("value", 0))
		all_results.append_array(results)

	all_results.append_array(_apply_dice_effects(companion, ability, bond))
	return all_results


func _apply_dice_effects(companion: CompanionCombatant, ability: CompanionAbility,
		bond: Dictionary) -> Array[Dictionary]:
	"""Dice-shaper: work on the player's rolled hand (only while it's live)."""
	var out: Array[Dictionary] = []
	if ability.dice_effects.is_empty() or _combat_manager == null:
		return out
	if not _combat_manager.has_method("is_player_hand_live") or not _combat_manager.is_player_hand_live():
		print("  [Companion] %s dice effects skipped (no live hand)" % companion.combatant_name)
		return out
	var pool: PlayerDiceCollection = _combat_manager.player.dice_pool
	var sides: int = int(bond.get("sides", 0))
	var value: int = int(bond.get("value", 0))
	for de in ability.dice_effects:
		if de == null:
			continue
		var changed: int = de.apply(pool, value, sides, companion.combatant_name)
		out.append({"effect_type": -1, "dice_shaper": de.kind, "dice_changed": changed,
			"source": companion, "target": _get_player_combatant()})
		print("  [Companion] %s dice effect %s changed %d die/dice" % [
			companion.combatant_name, CompanionDiceEffect.Kind.keys()[de.kind], changed])
	return out


func _build_effect_context(companion: CompanionCombatant, context: Dictionary,
		bond: Dictionary = {}) -> Dictionary:
	"""The ValueSource v2 context dict for effect execution.
	Shared between companion abilities and synergy bonus actions."""
	return {
		# Source identity
		"source": companion,
		# Source HP (percent + raw)
		"source_hp_percent": float(companion.current_health) / maxf(float(companion.max_health), 1.0),
		"source_current_hp": companion.current_health,
		"source_max_hp": companion.max_health,
		# Combat state
		"in_combat": true,
		"turn_number": _combat_manager.current_round if _combat_manager else 1,
		# Combatant counts
		"alive_enemies": _get_alive_enemies().size(),
		"alive_companions": _companion_manager.get_alive_companions().size(),
		# Trigger context (for TRIGGER_DAMAGE_AMOUNT)
		"trigger_damage": context.get("damage_amount", 0),
		# Bond die (Gap 78)
		"bond_value": int(bond.get("value", 0)),
		"bond_die_sides": int(bond.get("sides", 0)),
	}

# ============================================================================
# SYNERGY BONUS ACTIONS
# ============================================================================

func evaluate_synergy_triggers(trigger_type: CompanionData.CompanionTrigger,
		context: Dictionary = {}) -> Array[Dictionary]:
	"""Evaluate active synergy bonus actions for a trigger type.
	Returns fire entries for synergies whose bonus_trigger matches and
	whose bonus_action_effects are non-empty.
	Targets are resolved per-effect at execution time, not here."""
	var fire_entries: Array[Dictionary] = []

	var active_synergies = CompanionSynergyManager.get_active_synergies()
	for synergy in active_synergies:
		if synergy.bonus_action_effects.is_empty():
			continue
		if synergy.bonus_trigger != trigger_type:
			continue

		# Check cooldown
		if CompanionSynergyManager.get_bonus_cooldown(synergy.synergy_id) > 0:
			continue

		# Pick a source companion (first alive member of the synergy)
		var source_companion = _find_synergy_source(synergy)
		if not source_companion:
			continue

		# Condition gate
		if synergy.bonus_condition:
			var cond_context = _build_condition_context(source_companion, context)
			if synergy.bonus_condition.evaluate(cond_context).blocked:
				continue

		fire_entries.append({
			"synergy": synergy,
			"companion": source_companion,
			"slot_index": source_companion.slot_index,
			"context": context,
			"is_synergy_bonus": true,
		})

	return fire_entries


func execute_synergy_fire(fire_entry: Dictionary) -> Array[Dictionary]:
	"""Execute effects for a synergy bonus action.
	Each effect resolves its own targets via ActionEffect.resolve_targets()."""
	var synergy: CompanionSynergyDefinition = fire_entry["synergy"]
	var companion: CompanionCombatant = fire_entry["companion"]
	var context: Dictionary = fire_entry["context"]

	var all_results: Array[Dictionary] = []
	var effect_context = _build_effect_context(companion, context)
	var combat_ctx = _build_combat_context(companion, context)

	for effect in synergy.bonus_action_effects:
		if not effect:
			continue
		var targets = ActionEffect.resolve_targets(effect.target, companion, combat_ctx)
		if targets.is_empty():
			continue
		var dice_values: Array = []
		var results = effect.execute(companion, targets, dice_values, effect_context)
		all_results.append_array(results)

	# Set cooldown
	if synergy.bonus_cooldown_turns > 0:
		CompanionSynergyManager.set_bonus_cooldown(
			synergy.synergy_id, synergy.bonus_cooldown_turns)

	companion_fired.emit(companion, fire_entry["slot_index"])
	print("  [Synergy] %s bonus FIRED (%d results)" % [
		synergy.synergy_name, all_results.size()])

	return all_results


func _find_synergy_source(synergy: CompanionSynergyDefinition) -> CompanionCombatant:
	"""Pick the first alive companion that's part of this synergy (for effect context)."""
	for slot_idx in FIRING_ORDER:
		var companion = _companion_manager.get_slot(slot_idx)
		if not companion or not companion.is_alive():
			continue
		if CompanionSynergyManager._companion_is_in_synergy(synergy, companion.companion_data):
			return companion
	return null


func _build_combat_context(source: CompanionCombatant, trigger_context: Dictionary) -> Dictionary:
	"""Build the combat context dict for ActionEffect.resolve_targets()."""
	return {
		"alive_enemies": _get_alive_enemies(),
		"alive_companions": _companion_manager.get_alive_companions(),
		"player_combatant": _get_player_combatant(),
		"trigger_source": trigger_context.get("trigger_source"),
		"damaged_target": trigger_context.get("damaged_target"),
	}

# ============================================================================
# CONTEXT BUILDING
# ============================================================================

func _build_condition_context(companion: CompanionCombatant, trigger_context: Dictionary) -> Dictionary:
	"""Build a context dict compatible with AffixCondition.evaluate()."""
	var player = _combat_manager.player if _combat_manager else null

	return {
		"player": player,
		"source": companion,
		"in_combat": true,
		"turn_number": _combat_manager.current_round if _combat_manager else 0,
		"damage_amount": trigger_context.get("damage_amount", 0),
		"source_hp_percent": float(companion.current_health) / maxf(float(companion.max_health), 1.0),
		"player_hp_percent": _get_player_hp_percent(),
	}

# ============================================================================
# HELPERS (delegate to combat_manager)
# ============================================================================

func _get_alive_enemies() -> Array[Combatant]:
	if _combat_manager:
		var result: Array[Combatant] = []
		for e in _combat_manager.enemy_combatants:
			if e.is_alive():
				result.append(e)
		return result
	return []

func _get_player_combatant() -> Combatant:
	if _combat_manager:
		return _combat_manager.player_combatant
	return null

func _get_player_hp_percent() -> float:
	var pc = _get_player_combatant()
	if pc and pc.max_health > 0:
		return float(pc.current_health) / float(pc.max_health)
	return 1.0
