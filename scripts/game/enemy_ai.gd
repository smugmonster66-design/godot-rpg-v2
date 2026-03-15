# res://scripts/game/enemy_ai.gd
# Enemy AI decision-making with element awareness, configurable personality,
# per-action hints, multi-enemy coordination, and intent preview.
extends RefCounted
class_name EnemyAI

# AI Strategy constants (match EnemyData.AIStrategy enum order)
const AGGRESSIVE = 0
const DEFENSIVE = 1
const BALANCED = 2
const RANDOM = 3

# Default scoring weights (used when EnemyAIConfig is null — equivalent to 0.5)
const _DEFAULT_ELEMENT_PREF := 0.5
const _DEFAULT_HEAL_URGENCY := 0.5
const _DEFAULT_HEAL_THRESH := 0.5
const _DEFAULT_CRIT_THRESH := 0.3
const _DEFAULT_STATUS_AWARE := 0.5
const _DEFAULT_COORD_PREF := 0.5

# Score cap for FORCE_ACTION hints
const _FORCE_SCORE := 9999.0

# ============================================================================
# DECISION RESULT
# ============================================================================

class Decision:
	var action: Dictionary = {}
	var dice: Array[DieResource] = []
	var score: float = 0.0

# ============================================================================
# MAIN DECISION FUNCTION
# ============================================================================

## Decide what action to take with available dice.
##
## context (optional) keys:
##   "enemy"          : Combatant — the acting enemy
##   "target"         : Combatant — the primary target (player/companion)
##   "allied_enemies" : Array[Combatant] — alive allies (empty if not team_aware)
##   "ai_config"      : EnemyAIConfig — personality overrides (or null)
##   "turn_number"    : int
static func decide(actions: Array, available_dice: Array[DieResource],
		strategy: int, context: Dictionary = {}) -> Decision:

	if available_dice.size() == 0 or actions.size() == 0:
		return null

	var config: EnemyAIConfig = context.get("ai_config")
	var candidates: Array[Decision] = []

	for action in actions:
		var required: int = action.get("die_slots", 1)

		# Can we afford this action?
		if available_dice.size() < required:
			continue

		var action_resource: Action = action.get("action_resource")

		# Select dice — element-aware when possible
		var selected_dice := _select_dice(available_dice, required, strategy,
				action_resource, config)

		if selected_dice.size() < required:
			continue

		# Score the action
		var decision := Decision.new()
		decision.action = action
		decision.dice = selected_dice
		decision.score = _score_action(action, selected_dice, strategy, context, config)

		candidates.append(decision)

	if candidates.size() == 0:
		return null

	# Pick best (or random)
	if strategy == RANDOM:
		return candidates[randi() % candidates.size()]

	# Sort by score descending
	candidates.sort_custom(func(a, b): return a.score > b.score)
	return candidates[0]

# ============================================================================
# DICE SELECTION — element-aware partitioning
# ============================================================================

static func _select_dice(available: Array[DieResource], count: int,
		strategy: int, action_resource: Action = null,
		config: EnemyAIConfig = null) -> Array[DieResource]:

	var sorted := available.duplicate()

	# Determine element preference strength
	var elem_pref: float = config.element_preference if config else _DEFAULT_ELEMENT_PREF

	# Extract the action's primary damage type for element matching
	var primary_dt: int = _get_primary_damage_type(action_resource)
	var has_accepted: bool = action_resource != null and action_resource.accepted_elements.size() > 0

	# Partition into matching / non-matching when element awareness > 0
	var matching: Array[DieResource] = []
	var non_matching: Array[DieResource] = []

	if strategy != RANDOM and elem_pref > 0.0 and (primary_dt >= 0 or has_accepted):
		for die: DieResource in sorted:
			var is_match := false
			if primary_dt >= 0 and die.is_element_match(primary_dt as ActionEffect.DamageType):
				is_match = true
			elif has_accepted:
				var eff_elem: int = die.get_effective_element()
				if eff_elem in action_resource.accepted_elements:
					is_match = true
			if is_match:
				matching.append(die)
			else:
				non_matching.append(die)
	else:
		# No element awareness — treat all dice equally
		non_matching = sorted

	# Sort each partition by strategy
	_sort_by_strategy(matching, strategy)
	_sort_by_strategy(non_matching, strategy)

	# Prefer matching dice, then fill remainder with non-matching
	var result: Array[DieResource] = []
	for die in matching:
		if result.size() >= count:
			break
		result.append(die)
	for die in non_matching:
		if result.size() >= count:
			break
		result.append(die)
	return result


static func _sort_by_strategy(dice: Array[DieResource], strategy: int) -> void:
	match strategy:
		AGGRESSIVE:
			dice.sort_custom(func(a, b): return a.get_total_value() > b.get_total_value())
		DEFENSIVE:
			dice.sort_custom(func(a, b): return a.get_total_value() < b.get_total_value())
		BALANCED:
			var avg := 0.0
			for die in dice:
				avg += die.get_total_value()
			avg /= dice.size() if dice.size() > 0 else 1
			dice.sort_custom(func(a, b):
				return abs(a.get_total_value() - avg) < abs(b.get_total_value() - avg)
			)
		RANDOM:
			dice.shuffle()

# ============================================================================
# ACTION SCORING
# ============================================================================

static func _score_action(action: Dictionary, dice: Array[DieResource],
		strategy: int, context: Dictionary, config: EnemyAIConfig = null) -> float:

	# --- Base value (legacy formula, kept for compat) ---
	var base: float = action.get("base_damage", 0)
	var mult: float = action.get("damage_multiplier", 1.0)
	var action_type: int = action.get("action_type", 0)

	var dice_total := 0
	for die in dice:
		dice_total += die.get_total_value()

	var value: float = base + dice_total * mult

	# --- Strategy multiplier ---
	var strategy_mult := 1.0
	match strategy:
		AGGRESSIVE:
			strategy_mult = 1.5 if action_type == 0 else 0.5
		DEFENSIVE:
			if action_type == 1:
				strategy_mult = 1.5
			elif action_type == 2:
				strategy_mult = 1.3
			else:
				strategy_mult = 0.7
		BALANCED:
			strategy_mult = 1.0
		RANDOM:
			return randf() * 100.0

	value *= strategy_mult

	# --- Element match bonus ---
	var action_resource: Action = action.get("action_resource")
	var primary_dt: int = _get_primary_damage_type(action_resource)
	var elem_pref: float = config.element_preference if config else _DEFAULT_ELEMENT_PREF

	if primary_dt >= 0 and elem_pref > 0.0:
		var match_count := 0
		for die in dice:
			if die.is_element_match(primary_dt as ActionEffect.DamageType):
				match_count += 1
		# Each matching die adds up to 30% bonus at max element_preference
		value += value * (0.15 * elem_pref * 2.0) * match_count

	# --- Situational bonuses (requires combat context) ---
	var enemy_combatant = context.get("enemy")
	var target_combatant = context.get("target")

	if enemy_combatant:
		var self_hp_pct: float = float(enemy_combatant.current_health) / float(maxi(enemy_combatant.max_health, 1))
		var heal_urgency: float = config.heal_urgency if config else _DEFAULT_HEAL_URGENCY
		var heal_thresh: float = config.heal_threshold if config else _DEFAULT_HEAL_THRESH
		var crit_thresh: float = config.critical_threshold if config else _DEFAULT_CRIT_THRESH

		# Heal urgency bonus
		if action_type == 2 and heal_urgency > 0.0:  # HEAL
			if self_hp_pct < crit_thresh:
				value += 50.0 * heal_urgency * 2.0
			elif self_hp_pct < heal_thresh:
				value += 25.0 * heal_urgency * 2.0

		# Defend urgency bonus
		if action_type == 1 and heal_urgency > 0.0:  # DEFEND
			if self_hp_pct < heal_thresh:
				value += 15.0 * heal_urgency * 2.0

	# --- Status waste penalty ---
	if target_combatant and action_resource:
		var status_aware: float = config.status_awareness if config else _DEFAULT_STATUS_AWARE
		if status_aware > 0.0:
			var target_tracker = target_combatant.get_node_or_null("StatusTracker")
			if target_tracker:
				var penalty := _calculate_status_penalty(action_resource, target_tracker)
				value += penalty * status_aware * 2.0

	# --- Multi-enemy coordination bonus ---
	var allied_enemies: Array = context.get("allied_enemies", [])
	if allied_enemies.size() > 0 and target_combatant and action_resource:
		var coord_pref: float = config.coordination_preference if config else _DEFAULT_COORD_PREF
		if coord_pref > 0.0:
			var synergy := _calculate_synergy_bonus(action_resource, target_combatant)
			value += synergy * coord_pref * 2.0

	# --- Per-action AI hints ---
	if action_resource and action_resource.get("ai_hints"):
		var hints: Array = action_resource.ai_hints
		if hints.size() > 0:
			value = _apply_ai_hints(value, hints, context, enemy_combatant, target_combatant)

	return value

# ============================================================================
# HELPERS
# ============================================================================

## Extract the DamageType from the first DAMAGE effect of an action.
## Returns -1 if no damage effect exists.
static func _get_primary_damage_type(action_resource: Action) -> int:
	if not action_resource:
		return -1

	# Check effect_slots first (modern), then legacy effects
	if action_resource.effect_slots.size() > 0:
		for slot in action_resource.effect_slots:
			if slot and slot.effect and slot.effect.effect_type == ActionEffect.EffectType.DAMAGE:
				return slot.effect.damage_type
	else:
		for effect in action_resource.effects:
			if effect and effect.effect_type == ActionEffect.EffectType.DAMAGE:
				return effect.damage_type
	return -1


## Calculate score penalty for re-applying statuses the target already has.
## Returns a negative value.
static func _calculate_status_penalty(action_resource: Action,
		target_tracker) -> float:
	var penalty := 0.0

	var effects_to_check: Array = []
	if action_resource.effect_slots.size() > 0:
		for slot in action_resource.effect_slots:
			if slot and slot.effect:
				effects_to_check.append(slot.effect)
	else:
		for effect in action_resource.effects:
			if effect:
				effects_to_check.append(effect)

	for effect in effects_to_check:
		if effect.effect_type == ActionEffect.EffectType.ADD_STATUS:
			var status_id: String = effect.get("status_id", "")
			if status_id != "" and target_tracker.has_status(status_id):
				penalty -= 40.0

	return penalty


## Calculate synergy bonus based on statuses already on the target.
## If the target has a status and this action deals damage of a matching
## element or has COMBO_MARK / EXECUTE effects, grant a synergy bonus.
static func _calculate_synergy_bonus(action_resource: Action,
		target_combatant) -> float:
	var target_tracker = target_combatant.get_node_or_null("StatusTracker")
	if not target_tracker:
		return 0.0

	var bonus := 0.0

	var effects_to_check: Array = []
	if action_resource.effect_slots.size() > 0:
		for slot in action_resource.effect_slots:
			if slot and slot.effect:
				effects_to_check.append(slot.effect)
	else:
		for effect in action_resource.effects:
			if effect:
				effects_to_check.append(effect)

	for effect in effects_to_check:
		# Combo / Execute effects synergise with any existing debuff
		if effect.effect_type == ActionEffect.EffectType.COMBO_MARK:
			if target_tracker.get_active_debuffs().size() > 0:
				bonus += 20.0
		elif effect.effect_type == ActionEffect.EffectType.EXECUTE:
			if target_tracker.get_active_debuffs().size() > 0:
				bonus += 25.0

	# Element synergy: if target has burn and action deals fire, bonus
	var _element_status_map := {
		"burn": ActionEffect.DamageType.FIRE,
		"freeze": ActionEffect.DamageType.ICE,
		"shock": ActionEffect.DamageType.SHOCK,
		"poison": ActionEffect.DamageType.POISON,
	}
	var primary_dt: int = _get_primary_damage_type(action_resource)
	if primary_dt >= 0:
		for status_id: String in _element_status_map:
			if target_tracker.has_status(status_id):
				if _element_status_map[status_id] == primary_dt:
					bonus += 15.0

	return bonus


## Apply ActionAIHint array to modify the action score.
static func _apply_ai_hints(base_score: float, hints: Array,
		context: Dictionary, enemy_combatant, target_combatant) -> float:
	var score := base_score

	# Build hint evaluation context
	var hint_ctx := {}
	if enemy_combatant:
		hint_ctx["self_hp_percent"] = float(enemy_combatant.current_health) / float(maxi(enemy_combatant.max_health, 1))
		hint_ctx["self_tracker"] = enemy_combatant.get_node_or_null("StatusTracker")
	if target_combatant:
		hint_ctx["target_hp_percent"] = float(target_combatant.current_health) / float(maxi(target_combatant.max_health, 1))
		hint_ctx["target_tracker"] = target_combatant.get_node_or_null("StatusTracker")

	var allied: Array = context.get("allied_enemies", [])
	hint_ctx["ally_count"] = allied.size()
	hint_ctx["turn_number"] = context.get("turn_number", 1)

	for hint in hints:
		if not hint is ActionAIHint:
			continue
		if not hint.evaluate(hint_ctx):
			continue

		match hint.effect:
			ActionAIHint.HintEffect.SCORE_BONUS:
				score += hint.bonus_value
			ActionAIHint.HintEffect.SCORE_MULTIPLIER:
				score *= hint.multiplier_value
			ActionAIHint.HintEffect.FORCE_ACTION:
				score = _FORCE_SCORE

	return score

# ============================================================================
# INTENT PREVIEW (framed out — no UI yet)
# ============================================================================

## Lightweight preview of the most likely next-turn action category.
## Runs at end of the enemy's turn to set an intent indicator.
## Returns a dict: { "category": int, "action_name": String }
##   category: 0=ATTACK, 1=DEFEND, 2=HEAL, 3=SPECIAL
static func preview_intent(actions: Array, strategy: int,
		context: Dictionary = {}) -> Dictionary:

	if actions.size() == 0:
		return {"category": 0, "action_name": ""}

	# Score actions without dice (just by type + strategy + hints)
	var best_type: int = 0
	var best_name: String = ""
	var best_score: float = -999.0

	for action in actions:
		var action_type: int = action.get("action_type", 0)
		var name: String = action.get("name", "")

		var type_score := 0.0
		match strategy:
			AGGRESSIVE:
				type_score = 100.0 if action_type == 0 else 30.0
			DEFENSIVE:
				if action_type == 1:
					type_score = 100.0
				elif action_type == 2:
					type_score = 80.0
				else:
					type_score = 30.0
			BALANCED:
				type_score = 60.0
			RANDOM:
				type_score = randf() * 100.0

		# Apply AI hints if available
		var action_resource: Action = action.get("action_resource")
		if action_resource and action_resource.get("ai_hints"):
			var enemy_combatant = context.get("enemy")
			var target_combatant = context.get("target")
			type_score = _apply_ai_hints(type_score, action_resource.ai_hints,
					context, enemy_combatant, target_combatant)

		if type_score > best_score:
			best_score = type_score
			best_type = action_type
			best_name = name

	return {"category": best_type, "action_name": best_name}
