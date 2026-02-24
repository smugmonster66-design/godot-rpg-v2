# res://scripts/game/companion_trigger_processor.gd
# Evaluates companion triggers and executes their actions.
# Owned by CompanionManager. Stateless between calls.
extends RefCounted
class_name CompanionTriggerProcessor

# ============================================================================
# DEPENDENCIES (set by CompanionManager)
# ============================================================================
var _combat_manager = null
var _companion_manager: CompanionManager = null

# ============================================================================
# FIRING ORDER
# ============================================================================
## Canonical slot evaluation order: NPC0, NPC1, Summon0, Summon1
const FIRING_ORDER: Array[int] = [0, 1, 2, 3]

# ============================================================================
# SIGNALS
# ============================================================================
## Emitted when a companion fires its action (for UI animation hooks).
signal companion_fired(companion: CompanionCombatant, slot_index: int)

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

func process_trigger(trigger_type: CompanionData.CompanionTrigger,
		context: Dictionary = {}) -> Array[Dictionary]:
	"""Evaluate all companions for a specific trigger type.
	
	Args:
		trigger_type: The trigger event that occurred.
		context: Extra data for the trigger. Possible keys:
			- "damage_amount": int (for PLAYER_DAMAGED, ALLY_DAMAGED, etc.)
			- "damaged_target": Combatant (who got hit)
			- "killed_enemy": Combatant (for ENEMY_KILLED)
			- "killed_companion": CompanionCombatant (for COMPANION_KILLED)
			- "source_companion": CompanionCombatant (for OTHER_COMPANION_DAMAGED)
			- "trigger_source": Combatant (entity that caused the event)
	
	Returns:
		Array of result dictionaries from ActionEffect.execute() calls.
	"""
	var all_results: Array[Dictionary] = []

	for slot_idx in FIRING_ORDER:
		var companion = _companion_manager.get_slot(slot_idx)
		if not companion or not companion.is_alive():
			continue

		# Does this companion's trigger match?
		if companion.companion_data.trigger != trigger_type:
			continue

		# Can it fire? (cooldown, uses)
		if not companion.can_fire():
			continue

		# First-turn gate
		if not companion.companion_data.fires_on_first_turn and companion.turns_active == 0:
			continue

		# Threshold check for PLAYER_DAMAGED_THRESHOLD
		if trigger_type == CompanionData.CompanionTrigger.PLAYER_DAMAGED_THRESHOLD:
			var threshold = companion.companion_data.trigger_data.get("threshold_percent", 0.25)
			var player_hp_pct := _get_player_hp_percent()
			if player_hp_pct > threshold:
				continue

		# OTHER_COMPANION_DAMAGED — skip if the damaged companion is self
		if trigger_type == CompanionData.CompanionTrigger.OTHER_COMPANION_DAMAGED:
			var source = context.get("source_companion")
			if source == companion:
				continue

		# Condition gate (uses existing AffixCondition system)
		if companion.companion_data.condition:
			var cond_context = _build_condition_context(companion, context)
			var cond_result = companion.companion_data.condition.evaluate(cond_context)
			if cond_result.blocked:
				continue

		# --- FIRE! ---
		var targets = _resolve_targets(companion, context)
		if targets.is_empty():
			print("  [Companion] %s trigger matched but no valid targets -- skipped" % companion.combatant_name)
			continue

		var results = _execute_effects(companion, targets, context)
		all_results.append_array(results)

		# Record firing
		companion.on_fired()
		companion_fired.emit(companion, slot_idx)
		print("  [Companion] %s FIRED (slot %d, %d results)" % [companion.combatant_name, slot_idx, results.size()])

	return all_results

# ============================================================================
# TARGET RESOLUTION
# ============================================================================

func _resolve_targets(companion: CompanionCombatant, context: Dictionary) -> Array[Combatant]:
	"""Resolve the target(s) for a companion's action based on its target_rule."""
	var rule = companion.companion_data.target_rule
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
			# Find another alive companion (prefer the other NPC, then summons)
			for slot_idx in FIRING_ORDER:
				var other = _companion_manager.get_slot(slot_idx)
				if other and other != companion and other.is_alive():
					targets.append(other)
					break  # Target first found

		CompanionData.CompanionTarget.LOWEST_HP_ALLY:
			# Pool = player + all alive companions
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
			if source and source is Combatant and source.is_alive():
				targets.append(source)
			else:
				# Fallback: random enemy
				var enemies = _get_alive_enemies()
				if enemies.size() > 0:
					targets.append(enemies.pick_random())

		CompanionData.CompanionTarget.DAMAGED_ALLY:
			var damaged = context.get("damaged_target")
			if damaged and damaged is Combatant and damaged.is_alive():
				targets.append(damaged)
			else:
				# Fallback: lowest HP ally
				targets = _resolve_targets_fallback_lowest_hp(companion)

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
# EFFECT EXECUTION (ValueSource v2)
# ============================================================================

func _execute_effects(companion: CompanionCombatant, targets: Array[Combatant],
		context: Dictionary) -> Array[Dictionary]:
	"""Execute all ActionEffects from the companion's data.
	Reuses the existing ActionEffect.execute() pipeline.
	Provides full ValueSource v2 context for dynamic scaling."""
	var all_results: Array[Dictionary] = []

	for effect in companion.companion_data.action_effects:
		if not effect:
			continue

		var effect_context: Dictionary = {
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
		}

		# Companions don't use dice
		var dice_values: Array = []
		var results = effect.execute(companion, targets, dice_values, effect_context)
		all_results.append_array(results)

	return all_results

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
