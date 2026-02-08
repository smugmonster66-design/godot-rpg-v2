# res://scripts/combat/affix_evaluator.gd
# Centralized evaluator for item-level affixes.
# Replaces scattered affix iteration in Player, AffixPoolManager, and
# CombatCalculator with a single pipeline that handles:
#   - Condition gating and scaling
#   - Dynamic value resolution via ValueSource
#   - Compound sub-effect processing
#   - Tag-based filtering
#   - Debug logging
#
# USAGE:
#   var evaluator = AffixEvaluator.new()
#   var ctx = evaluator.build_context(player)
#
#   # Stat calculation (replaces Player.get_stat manual loops)
#   var strength = evaluator.resolve_stat(affix_mgr, "strength", base_str, ctx)
#
#   # Damage bonuses (replaces CombatCalculator._apply_damage_bonuses loops)
#   var bonus = evaluator.resolve_category_sum(affix_mgr, Affix.Category.SLASHING_DAMAGE_BONUS, ctx)
#
#   # Get all granted actions with condition checks
#   var actions = evaluator.resolve_granted_actions(affix_mgr, ctx)
#
#   # Query by tag
#   var weapon_affixes = evaluator.get_affixes_by_tag(affix_mgr, "weapon")
extends RefCounted
class_name AffixEvaluator

# ============================================================================
# SIGNALS
# ============================================================================
signal affix_evaluated(affix: Affix, resolved_value: float, was_blocked: bool)
signal compound_effect_applied(affix: Affix, sub_effect: AffixSubEffect, value: float)

# ============================================================================
# DEBUG
# ============================================================================
var debug_logging: bool = false

# ============================================================================
# CONTEXT BUILDING
# ============================================================================

func build_context(player, in_combat: bool = false, turn_number: int = 0, round_number: int = 0) -> Dictionary:
	"""Build a standard context dictionary from player state.
	
	This is the canonical way to create the context dictionary that
	all evaluation methods expect. Call once per evaluation pass and
	reuse for all resolve_* calls in that pass.
	"""
	var ctx: Dictionary = {
		"player": player,
		"in_combat": in_combat,
		"turn_number": turn_number,
		"round_number": round_number,
	}
	
	if player:
		if "affix_manager" in player and player.affix_manager:
			ctx["affix_manager"] = player.affix_manager
		if "dice_pool" in player and player.dice_pool:
			ctx["dice_pool"] = player.dice_pool
		if player.has_method("get") and player.get("active_class"):
			ctx["active_class"] = player.active_class
		if "status_tracker" in player and player.status_tracker:
			ctx["status_tracker"] = player.status_tracker
	
	return ctx

func build_combat_context(player, source_combatant, turn_number: int, round_number: int, target = null) -> Dictionary:
	"""Build context specifically for in-combat evaluation.
	
	Args:
		target: Optional damage target (Combatant). Enables TARGET_HAS_STATUS conditions.
	"""
	var ctx = build_context(player, true, turn_number, round_number)
	ctx["source"] = source_combatant
	if target:
		ctx["target"] = target
		# Target's StatusTracker for TARGET_HAS_STATUS conditions
		if "status_tracker" in target:
			ctx["target_status_tracker"] = target.status_tracker
		elif target.has_method("get_node_or_null"):
			var t_tracker = target.get_node_or_null("StatusTracker")
			if t_tracker:
				ctx["target_status_tracker"] = t_tracker
	return ctx

# ============================================================================
# STAT RESOLUTION — Replaces Player.get_stat() affix loops
# ============================================================================

func resolve_stat(affix_manager: AffixPoolManager, stat_name: String, base_value: float, context: Dictionary) -> float:
	"""Calculate a stat with flat bonuses then multipliers, respecting conditions.
	
	Replaces:
		AffixPoolManager.calculate_stat()
		Player.get_stat() affix iteration
	
	Args:
		affix_manager: Player's affix pool manager.
		stat_name: "strength", "agility", "intellect", "luck"
		base_value: Pre-affix base value (class + equipment + level).
		context: Runtime context from build_context().
	
	Returns:
		Final stat value after all bonuses and multipliers.
	"""
	var value = base_value
	
	var bonus_cat = _stat_to_bonus_category(stat_name)
	var mult_cat = _stat_to_multiplier_category(stat_name)
	
	# Flat bonuses
	if bonus_cat >= 0:
		value += resolve_category_sum(affix_manager, bonus_cat, context)
	
	# Multipliers
	if mult_cat >= 0:
		value *= resolve_category_product(affix_manager, mult_cat, context)
	
	return value

# ============================================================================
# CATEGORY-LEVEL RESOLUTION
# ============================================================================

func resolve_category_sum(affix_manager: AffixPoolManager, category: Affix.Category, context: Dictionary) -> float:
	"""Sum all affix values in a category, with condition/value source resolution.
	
	Use for additive categories: STRENGTH_BONUS, DAMAGE_BONUS, ARMOR_BONUS, etc.
	"""
	var total: float = 0.0
	
	for affix in affix_manager.get_pool(category):
		var value = _evaluate_single_affix(affix, context)
		total += value
	
	return total

func resolve_category_product(affix_manager: AffixPoolManager, category: Affix.Category, context: Dictionary) -> float:
	"""Multiply all affix values in a category, with condition/value source resolution.
	
	Use for multiplicative categories: STRENGTH_MULTIPLIER, DAMAGE_MULTIPLIER, etc.
	Returns 1.0 if the pool is empty (identity for multiplication).
	"""
	var product: float = 1.0
	
	for affix in affix_manager.get_pool(category):
		var value = _evaluate_single_affix(affix, context)
		if value != 0.0:
			product *= value
	
	return product

func resolve_category_max(affix_manager: AffixPoolManager, category: Affix.Category, context: Dictionary) -> float:
	"""Get the maximum value across all affixes in a category.
	Useful for effects where only the strongest applies."""
	var best: float = 0.0
	
	for affix in affix_manager.get_pool(category):
		var value = _evaluate_single_affix(affix, context)
		if value > best:
			best = value
	
	return best

# ============================================================================
# DAMAGE RESOLUTION — Replaces CombatCalculator affix loops
# ============================================================================

func apply_damage_bonuses(affix_manager: AffixPoolManager, packet, primary_damage_type, context: Dictionary):
	"""Apply all typed and global damage bonuses to a DamagePacket.
	
	Replaces CombatCalculator._apply_damage_bonuses().
	Handles condition checking and dynamic value resolution.
	"""
	# Global damage bonus → primary type
	var global_bonus = resolve_category_sum(affix_manager, Affix.Category.DAMAGE_BONUS, context)
	if global_bonus > 0 and packet.has_method("add_damage"):
		packet.add_damage(primary_damage_type, global_bonus)
	
	# Type-specific bonuses
	var type_categories = {
		0: Affix.Category.SLASHING_DAMAGE_BONUS,   # SLASHING
		1: Affix.Category.PIERCING_DAMAGE_BONUS,    # PIERCING
		2: Affix.Category.BLUNT_DAMAGE_BONUS,       # BLUNT
		3: Affix.Category.FIRE_DAMAGE_BONUS,        # FIRE
		4: Affix.Category.ICE_DAMAGE_BONUS,         # ICE
		5: Affix.Category.SHOCK_DAMAGE_BONUS,       # SHOCK
		6: Affix.Category.POISON_DAMAGE_BONUS,      # POISON
		7: Affix.Category.SHADOW_DAMAGE_BONUS,      # SHADOW
	}
	
	for damage_type in type_categories:
		var cat = type_categories[damage_type]
		var bonus = resolve_category_sum(affix_manager, cat, context)
		if bonus > 0 and packet.has_method("add_damage"):
			packet.add_damage(damage_type, bonus)

func resolve_damage_multiplier(affix_manager: AffixPoolManager, context: Dictionary) -> float:
	"""Calculate total damage multiplier from affixes.
	Replaces CombatCalculator._calculate_damage_multiplier()."""
	return resolve_category_product(affix_manager, Affix.Category.DAMAGE_MULTIPLIER, context)

func resolve_defense_multiplier(affix_manager: AffixPoolManager, context: Dictionary) -> float:
	"""Calculate total defense multiplier from affixes."""
	return resolve_category_product(affix_manager, Affix.Category.DEFENSE_MULTIPLIER, context)

# ============================================================================
# DEFENSE / RESIST RESOLUTION
# ============================================================================

func resolve_armor(affix_manager: AffixPoolManager, base_armor: float, context: Dictionary) -> float:
	"""Calculate armor with affix bonuses."""
	return base_armor + resolve_category_sum(affix_manager, Affix.Category.ARMOR_BONUS, context)

func resolve_barrier(affix_manager: AffixPoolManager, base_barrier: float, context: Dictionary) -> float:
	"""Calculate barrier with affix bonuses."""
	return base_barrier + resolve_category_sum(affix_manager, Affix.Category.BARRIER_BONUS, context)

func resolve_resistance(affix_manager: AffixPoolManager, element: String, base_resist: float, context: Dictionary) -> float:
	"""Calculate elemental resistance with affix bonuses."""
	var cat = _element_to_resist_category(element)
	if cat >= 0:
		return base_resist + resolve_category_sum(affix_manager, cat, context)
	return base_resist

func resolve_health_bonus(affix_manager: AffixPoolManager, context: Dictionary) -> float:
	"""Get total health bonus from affixes."""
	return resolve_category_sum(affix_manager, Affix.Category.HEALTH_BONUS, context)

func resolve_mana_bonus(affix_manager: AffixPoolManager, context: Dictionary) -> float:
	"""Get total mana bonus from affixes."""
	return resolve_category_sum(affix_manager, Affix.Category.MANA_BONUS, context)

# ============================================================================
# STATUS-AWARE RESOLUTION — Affix + StatusTracker stat modifiers
# ============================================================================
# These layer StatusTracker stat modifiers ON TOP of affix resolution,
# matching how Player.get_armor() and get_total_stat() now work.
# Use these instead of the base resolve_* when StatusTracker is active.

func resolve_stat_with_status(affix_manager: AffixPoolManager, stat_name: String, base_value: float, context: Dictionary) -> float:
	"""resolve_stat() + StatusTracker stat modifiers.
	
	Layering order (matches Player.get_total_stat):
		1. Base value (class + equipment + level)
		2. Affix flat bonuses (with conditions)
		3. Affix multipliers (with conditions)
		4. Status stat modifiers (Corrode armor, Enfeeble damage_mult)
	"""
	var after_affixes = resolve_stat(affix_manager, stat_name, base_value, context)
	var tracker = context.get("status_tracker", null)
	if tracker and tracker.has_method("get_total_stat_modifier"):
		after_affixes += tracker.get_total_stat_modifier(stat_name)
	return after_affixes

func resolve_armor_with_status(affix_manager: AffixPoolManager, base_armor: float, context: Dictionary) -> float:
	"""resolve_armor() + StatusTracker armor modifiers (Corrode)."""
	var after_affixes = resolve_armor(affix_manager, base_armor, context)
	var tracker = context.get("status_tracker", null)
	if tracker and tracker.has_method("get_total_stat_modifier"):
		after_affixes += tracker.get_total_stat_modifier("armor")
	return maxf(0.0, after_affixes)

func resolve_barrier_with_status(affix_manager: AffixPoolManager, base_barrier: float, context: Dictionary) -> float:
	"""resolve_barrier() + StatusTracker barrier modifiers."""
	var after_affixes = resolve_barrier(affix_manager, base_barrier, context)
	var tracker = context.get("status_tracker", null)
	if tracker and tracker.has_method("get_total_stat_modifier"):
		after_affixes += tracker.get_total_stat_modifier("barrier")
	return maxf(0.0, after_affixes)

func resolve_damage_multiplier_with_status(affix_manager: AffixPoolManager, context: Dictionary) -> float:
	"""resolve_damage_multiplier() + Enfeeble's damage_multiplier reduction."""
	var affix_mult = resolve_damage_multiplier(affix_manager, context)
	var tracker = context.get("status_tracker", null)
	if tracker and tracker.has_method("get_total_stat_modifier"):
		# Enfeeble: stat_modifier_per_stack: {"damage_multiplier": -0.1}
		affix_mult += tracker.get_total_stat_modifier("damage_multiplier")
	return maxf(0.0, affix_mult)

# ============================================================================
# GRANTED RESOURCES — Actions & Dice with condition checks
# ============================================================================

func resolve_granted_actions(affix_manager: AffixPoolManager, context: Dictionary) -> Array:
	"""Get all actions granted by affixes, filtered by conditions.
	
	Replaces AffixPoolManager.get_granted_actions() with condition awareness.
	"""
	var actions: Array = []
	
	for affix in affix_manager.get_pool(Affix.Category.NEW_ACTION):
		if not affix.granted_action:
			continue
		
		# Check condition
		if affix.has_condition() and context.size() > 0:
			if not affix.check_condition(context):
				continue
		
		actions.append(affix.granted_action)
	
	return actions

func resolve_granted_dice(affix_manager: AffixPoolManager, context: Dictionary) -> Array[DieResource]:
	"""Get all dice granted by affixes, filtered by conditions."""
	var dice: Array[DieResource] = []
	
	for affix in affix_manager.get_pool(Affix.Category.DICE):
		# Check condition
		if affix.has_condition() and context.size() > 0:
			if not affix.check_condition(context):
				continue
		
		for die in affix.granted_dice:
			if die:
				dice.append(die)
	
	return dice

# ============================================================================
# TAG-BASED QUERIES
# ============================================================================

func get_affixes_by_tag(affix_manager: AffixPoolManager, tag: String) -> Array[Affix]:
	"""Get all active affixes with a specific tag, across all pools."""
	var result: Array[Affix] = []
	for category in affix_manager.pools:
		for affix in affix_manager.pools[category]:
			if affix is Affix and affix.has_tag(tag):
				result.append(affix)
	return result

func get_affixes_by_any_tag(affix_manager: AffixPoolManager, check_tags: Array[String]) -> Array[Affix]:
	"""Get all active affixes that have ANY of the given tags."""
	var result: Array[Affix] = []
	for category in affix_manager.pools:
		for affix in affix_manager.pools[category]:
			if affix is Affix and affix.has_any_tag(check_tags):
				result.append(affix)
	return result

func count_affixes_with_tag(affix_manager: AffixPoolManager, tag: String) -> int:
	"""Count active affixes with a specific tag."""
	return get_affixes_by_tag(affix_manager, tag).size()

func sum_values_by_tag(affix_manager: AffixPoolManager, tag: String, context: Dictionary) -> float:
	"""Sum resolved values of all affixes with a specific tag.
	Useful for: 'weapon affixes are 20% stronger' type effects."""
	var total: float = 0.0
	for affix in get_affixes_by_tag(affix_manager, tag):
		total += _evaluate_single_affix(affix, context)
	return total

# ============================================================================
# COMPOUND AFFIX RESOLUTION
# ============================================================================

func resolve_compound_affix(affix: Affix, context: Dictionary) -> Array[Dictionary]:
	"""Resolve a compound affix into its individual sub-effect results.
	
	Returns an array of dictionaries, each with:
		{
			"category": Affix.Category,
			"value": float,
			"sub_effect": AffixSubEffect,
			"granted_action": Action or null,
			"granted_dice": Array[DieResource],
		}
	"""
	var results: Array[Dictionary] = []
	
	if not affix.is_compound():
		return results
	
	# Check parent condition first
	var parent_multiplier: float = 1.0
	if affix.has_condition() and context.size() > 0:
		var cond_result = affix.condition.evaluate(context)
		if cond_result.blocked:
			return results  # Parent blocked — no sub-effects fire
		parent_multiplier = cond_result.multiplier
	
	for sub in affix.sub_effects:
		if not sub is AffixSubEffect:
			continue
		
		# Check sub-effect condition override
		if sub.override_condition:
			if not sub.check_condition(context):
				continue
		
		# Resolve value
		var value = sub.resolve_value(context)
		
		# Apply parent multiplier
		value *= parent_multiplier
		
		# Apply sub-effect's own scaling multiplier
		if sub.override_condition and sub.condition:
			value *= sub.get_condition_multiplier(context)
		
		var result_entry = {
			"category": sub.category,
			"value": value,
			"sub_effect": sub,
			"granted_action": sub.granted_action,
			"granted_dice": sub.granted_dice,
		}
		results.append(result_entry)
		
		compound_effect_applied.emit(affix, sub, value)
	
	return results

# ============================================================================
# BATCH EVALUATION — Process entire pools with compound support
# ============================================================================

func resolve_all_effects(affix_manager: AffixPoolManager, context: Dictionary) -> Dictionary:
	"""Resolve ALL active affixes into a flat dictionary of category → total value.
	
	Handles both simple and compound affixes. Useful for full stat recalculation
	or snapshot generation.
	
	Returns:
		{
			Affix.Category.STRENGTH_BONUS: 15.0,
			Affix.Category.DAMAGE_MULTIPLIER: 1.25,
			...
			"_granted_actions": Array[Action],
			"_granted_dice": Array[DieResource],
			"_blocked_affixes": Array[Affix],
		}
	"""
	var totals: Dictionary = {}
	var granted_actions: Array = []
	var granted_dice: Array[DieResource] = []
	var blocked: Array[Affix] = []
	
	# Initialize all categories to identity values
	for cat in Affix.Category.values():
		totals[cat] = 0.0
	
	for category in affix_manager.pools:
		for affix in affix_manager.pools[category]:
			if not affix is Affix:
				continue
			
			if affix.is_compound():
				# Compound: iterate sub-effects
				var sub_results = resolve_compound_affix(affix, context)
				if sub_results.is_empty() and affix.has_condition():
					blocked.append(affix)
					continue
				
				for entry in sub_results:
					var sub_cat = entry.category
					totals[sub_cat] = totals.get(sub_cat, 0.0) + entry.value
					
					if entry.granted_action:
						granted_actions.append(entry.granted_action)
					for die in entry.granted_dice:
						if die:
							granted_dice.append(die)
			else:
				# Simple affix
				var value = _evaluate_single_affix(affix, context)
				
				if value == 0.0 and affix.has_condition():
					# Might be blocked by condition
					if not affix.check_condition(context):
						blocked.append(affix)
						continue
				
				totals[category] = totals.get(category, 0.0) + value
				
				# Collect granted resources
				if affix.granted_action and category == Affix.Category.NEW_ACTION:
					if affix.check_condition(context):
						granted_actions.append(affix.granted_action)
				
				if category == Affix.Category.DICE:
					if affix.check_condition(context):
						for die in affix.granted_dice:
							if die:
								granted_dice.append(die)
	
	totals["_granted_actions"] = granted_actions
	totals["_granted_dice"] = granted_dice
	totals["_blocked_affixes"] = blocked
	
	return totals

# ============================================================================
# SINGLE AFFIX EVALUATION (internal)
# ============================================================================

func _evaluate_single_affix(affix: Affix, context: Dictionary) -> float:
	"""Evaluate a single non-compound affix, returning its resolved value.
	Handles condition checking, value source resolution, and logging."""
	
	var value: float = affix.resolve_value(context)
	var was_blocked = (value == 0.0 and affix.has_condition() and context.size() > 0
		and not affix.check_condition(context))
	
	if debug_logging:
		if was_blocked:
			print("  ❌ Affix '%s' blocked by condition" % affix.affix_name)
		elif value != 0.0:
			print("  ✅ Affix '%s' → %.2f" % [affix.affix_name, value])
	
	affix_evaluated.emit(affix, value, was_blocked)
	return value

# ============================================================================
# CATEGORY MAPPING HELPERS
# ============================================================================

func _stat_to_bonus_category(stat_name: String) -> int:
	match stat_name:
		"strength": return Affix.Category.STRENGTH_BONUS
		"agility": return Affix.Category.AGILITY_BONUS
		"intellect": return Affix.Category.INTELLECT_BONUS
		"luck": return Affix.Category.LUCK_BONUS
		_: return -1

func _stat_to_multiplier_category(stat_name: String) -> int:
	match stat_name:
		"strength": return Affix.Category.STRENGTH_MULTIPLIER
		"agility": return Affix.Category.AGILITY_MULTIPLIER
		"intellect": return Affix.Category.INTELLECT_MULTIPLIER
		"luck": return Affix.Category.LUCK_MULTIPLIER
		_: return -1

func _element_to_resist_category(element: String) -> int:
	match element:
		"fire": return Affix.Category.FIRE_RESIST_BONUS
		"ice": return Affix.Category.ICE_RESIST_BONUS
		"shock": return Affix.Category.SHOCK_RESIST_BONUS
		"poison": return Affix.Category.POISON_RESIST_BONUS
		"shadow": return Affix.Category.SHADOW_RESIST_BONUS
		_: return -1
