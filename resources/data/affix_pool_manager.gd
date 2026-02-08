# res://resources/data/affix_pool_manager.gd
# Manages categorized affix pools.
#
# v2 CHANGELOG:
#   - Added tag-based queries (get_affixes_by_tag, get_affixes_by_any_tag, etc.)
#   - Added bulk operations (remove_affixes_by_tag, remove_affixes_by_source_type)
#   - Added conditional queries (get_active_affixes_with_conditions)
#   - Added v2-aware stat calculations (calculate_stat_v2, calculate_damage_v2)
#   - Added get_all_active_affixes, get_affix_count utilities
#   - Enhanced debug printing with condition/tag/value source display
#   - All original methods preserved — no breaking changes
extends RefCounted
class_name AffixPoolManager

# ============================================================================
# AFFIX POOLS BY CATEGORY
# ============================================================================
var pools: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	_initialize_pools()

func _initialize_pools():
	"""Create empty pools for all categories"""
	for category in Affix.Category.values():
		pools[category] = []

# ============================================================================
# ADD/REMOVE AFFIXES
# ============================================================================

func add_affix(affix: Affix):
	"""Add an affix to its category pool"""
	if not affix:
		return
	
	if not pools.has(affix.category):
		pools[affix.category] = []
	
	pools[affix.category].append(affix)

func remove_affix(affix: Affix):
	"""Remove a specific affix from its pool"""
	if not affix:
		return
	
	if pools.has(affix.category):
		pools[affix.category].erase(affix)

func remove_affixes_by_source(p_source: String):
	"""Remove all affixes from a specific source"""
	for category in pools:
		var to_remove = []
		for affix in pools[category]:
			if affix.matches_source(p_source):
				to_remove.append(affix)
		for affix in to_remove:
			pools[category].erase(affix)

# ============================================================================
# QUERY POOLS
# ============================================================================

func get_pool(category: Affix.Category) -> Array:
	"""Get all affixes in a category"""
	if pools.has(category):
		return pools[category]
	return []

func get_affixes_by_source(p_source: String) -> Array[Affix]:
	"""Get all affixes from a specific source"""
	var result: Array[Affix] = []
	
	for category in pools:
		for affix in pools[category]:
			if affix.matches_source(p_source):
				result.append(affix)
	
	return result

# ============================================================================
# TAG-BASED QUERIES (v2)
# ============================================================================

func get_affixes_by_tag(tag: String) -> Array[Affix]:
	"""Get all affixes across all pools that have a specific tag."""
	var result: Array[Affix] = []
	for category in pools:
		for affix in pools[category]:
			if affix is Affix and affix.has_tag(tag):
				result.append(affix)
	return result

func get_affixes_by_any_tag(check_tags: Array[String]) -> Array[Affix]:
	"""Get all affixes that have ANY of the given tags."""
	var result: Array[Affix] = []
	for category in pools:
		for affix in pools[category]:
			if affix is Affix and affix.has_any_tag(check_tags):
				result.append(affix)
	return result

func get_affixes_by_all_tags(check_tags: Array[String]) -> Array[Affix]:
	"""Get all affixes that have ALL of the given tags."""
	var result: Array[Affix] = []
	for category in pools:
		for affix in pools[category]:
			if affix is Affix and affix.has_all_tags(check_tags):
				result.append(affix)
	return result

func count_affixes_with_tag(tag: String) -> int:
	"""Count all affixes with a specific tag."""
	var count = 0
	for category in pools:
		for affix in pools[category]:
			if affix is Affix and affix.has_tag(tag):
				count += 1
	return count

func has_affix_with_tag(tag: String) -> bool:
	"""Check if any active affix has a specific tag."""
	for category in pools:
		for affix in pools[category]:
			if affix is Affix and affix.has_tag(tag):
				return true
	return false

# ============================================================================
# BULK OPERATIONS (v2)
# ============================================================================

func remove_affixes_by_tag(tag: String) -> int:
	"""Remove all affixes with a specific tag. Returns count removed."""
	var removed = 0
	for category in pools:
		var to_remove: Array = []
		for affix in pools[category]:
			if affix is Affix and affix.has_tag(tag):
				to_remove.append(affix)
		for affix in to_remove:
			pools[category].erase(affix)
			removed += 1
	return removed

func remove_affixes_by_source_type(p_source_type: String) -> int:
	"""Remove all affixes with a specific source_type. Returns count removed."""
	var removed = 0
	for category in pools:
		var to_remove: Array = []
		for affix in pools[category]:
			if affix is Affix and affix.source_type == p_source_type:
				to_remove.append(affix)
		for affix in to_remove:
			pools[category].erase(affix)
			removed += 1
	return removed

func get_all_active_affixes() -> Array[Affix]:
	"""Get every affix across all pools (flat list)."""
	var result: Array[Affix] = []
	for category in pools:
		for affix in pools[category]:
			if affix is Affix:
				result.append(affix)
	return result

func get_affix_count() -> int:
	"""Get total count of all active affixes."""
	var count = 0
	for category in pools:
		count += pools[category].size()
	return count

# ============================================================================
# CONDITIONAL QUERIES (v2)
# ============================================================================

func get_active_affixes_with_conditions(context: Dictionary) -> Dictionary:
	"""Get all affixes split by whether their conditions are met.
	
	Returns:
		{
			"active": Array[Affix],   # Conditions met (or no condition)
			"blocked": Array[Affix],  # Conditions NOT met
		}
	"""
	var active: Array[Affix] = []
	var blocked: Array[Affix] = []
	
	for category in pools:
		for affix in pools[category]:
			if not affix is Affix:
				continue
			if affix.has_condition() and context.size() > 0:
				if affix.check_condition(context):
					active.append(affix)
				else:
					blocked.append(affix)
			else:
				active.append(affix)
	
	return {"active": active, "blocked": blocked}

# ============================================================================
# CALCULATE STATS (original v1 — no condition/value source support)
# ============================================================================

func calculate_stat(base_value: float, stat_name: String) -> float:
	"""Calculate a stat with bonuses then multipliers"""
	var value = base_value
	
	var bonus_category: Affix.Category
	var mult_category: Affix.Category
	
	match stat_name:
		"strength":
			bonus_category = Affix.Category.STRENGTH_BONUS
			mult_category = Affix.Category.STRENGTH_MULTIPLIER
		"agility":
			bonus_category = Affix.Category.AGILITY_BONUS
			mult_category = Affix.Category.AGILITY_MULTIPLIER
		"intellect":
			bonus_category = Affix.Category.INTELLECT_BONUS
			mult_category = Affix.Category.INTELLECT_MULTIPLIER
		"luck":
			bonus_category = Affix.Category.LUCK_BONUS
			mult_category = Affix.Category.LUCK_MULTIPLIER
		_:
			return value
	
	# Apply bonuses first
	for affix in get_pool(bonus_category):
		value += affix.apply_effect()
	
	# Apply multipliers second
	for affix in get_pool(mult_category):
		value *= affix.apply_effect()
	
	return value

func calculate_damage(base_damage: float) -> float:
	"""Calculate damage with bonuses then multipliers"""
	var damage = base_damage
	
	for affix in get_pool(Affix.Category.DAMAGE_BONUS):
		damage += affix.apply_effect()
	
	for affix in get_pool(Affix.Category.DAMAGE_MULTIPLIER):
		damage *= affix.apply_effect()
	
	return damage

func calculate_defense(base_defense: float) -> float:
	"""Calculate defense with bonuses then multipliers"""
	var defense = base_defense
	
	for affix in get_pool(Affix.Category.DEFENSE_BONUS):
		defense += affix.apply_effect()
	
	for affix in get_pool(Affix.Category.DEFENSE_MULTIPLIER):
		defense *= affix.apply_effect()
	
	return defense

# ============================================================================
# CALCULATE STATS v2 — With condition + value source support
# ============================================================================

func calculate_stat_v2(base_value: float, stat_name: String, context: Dictionary) -> float:
	"""Calculate a stat with full v2 evaluation (conditions + value sources).
	Falls back to original behavior if context is empty."""
	if context.is_empty():
		return calculate_stat(base_value, stat_name)
	
	var value = base_value
	var bonus_category: int = -1
	var mult_category: int = -1
	
	match stat_name:
		"strength":
			bonus_category = Affix.Category.STRENGTH_BONUS
			mult_category = Affix.Category.STRENGTH_MULTIPLIER
		"agility":
			bonus_category = Affix.Category.AGILITY_BONUS
			mult_category = Affix.Category.AGILITY_MULTIPLIER
		"intellect":
			bonus_category = Affix.Category.INTELLECT_BONUS
			mult_category = Affix.Category.INTELLECT_MULTIPLIER
		"luck":
			bonus_category = Affix.Category.LUCK_BONUS
			mult_category = Affix.Category.LUCK_MULTIPLIER
		_:
			return value
	
	# Flat bonuses with condition/value source resolution
	if bonus_category >= 0:
		for affix in get_pool(bonus_category):
			value += affix.resolve_value(context)
	
	# Multipliers with condition/value source resolution
	if mult_category >= 0:
		for affix in get_pool(mult_category):
			var mult = affix.resolve_value(context)
			if mult != 0.0:
				value *= mult
	
	return value

func calculate_damage_v2(base_damage: float, context: Dictionary) -> float:
	"""Calculate damage with full v2 evaluation."""
	if context.is_empty():
		return calculate_damage(base_damage)
	
	var damage = base_damage
	for affix in get_pool(Affix.Category.DAMAGE_BONUS):
		damage += affix.resolve_value(context)
	for affix in get_pool(Affix.Category.DAMAGE_MULTIPLIER):
		var mult = affix.resolve_value(context)
		if mult != 0.0:
			damage *= mult
	return damage

func calculate_defense_v2(base_defense: float, context: Dictionary) -> float:
	"""Calculate defense with full v2 evaluation."""
	if context.is_empty():
		return calculate_defense(base_defense)
	
	var defense = base_defense
	for affix in get_pool(Affix.Category.DEFENSE_BONUS):
		defense += affix.resolve_value(context)
	for affix in get_pool(Affix.Category.DEFENSE_MULTIPLIER):
		var mult = affix.resolve_value(context)
		if mult != 0.0:
			defense *= mult
	return defense

# ============================================================================
# GET SPECIAL AFFIXES
# ============================================================================

func get_granted_actions() -> Array:
	"""Get all actions granted by affixes"""
	var actions: Array = []
	
	for affix in get_pool(Affix.Category.NEW_ACTION):
		if affix.granted_action:
			actions.append(affix.granted_action)
	
	return actions

func get_granted_dice() -> Array[DieResource]:
	"""Get all dice granted by affixes"""
	var dice: Array[DieResource] = []
	
	for affix in get_pool(Affix.Category.DICE):
		for die in affix.granted_dice:
			if die:
				dice.append(die)
	
	return dice

# ============================================================================
# DEBUG
# ============================================================================

func print_pools():
	"""Debug: print all non-empty pools"""
	print("=== Affix Pools ===")
	for category in pools:
		if pools[category].size() > 0:
			var cat_name = Affix.Category.keys()[category]
			print("  %s: %d affixes" % [cat_name, pools[category].size()])
			for affix in pools[category]:
				print("    - %s" % affix.get_display_text())

func print_pools_v2(context: Dictionary = {}):
	"""Enhanced debug: print all non-empty pools with condition/tag/value info."""
	print("=== Affix Pools (v2) ===")
	for category in pools:
		if pools[category].size() > 0:
			var cat_name = Affix.Category.keys()[category]
			print("  %s: %d affixes" % [cat_name, pools[category].size()])
			for affix in pools[category]:
				var status = ""
				if affix is Affix:
					if affix.has_condition() and context.size() > 0:
						if affix.check_condition(context):
							status = " ✅"
						else:
							status = " ❌ (blocked)"
					if affix.tags.size() > 0:
						status += " [%s]" % ", ".join(affix.tags)
					if affix.value_source != Affix.ValueSource.STATIC:
						var resolved = affix.resolve_value(context)
						status += " (resolved: %.2f)" % resolved
				print("    - %s%s" % [affix.get_display_text(), status])
