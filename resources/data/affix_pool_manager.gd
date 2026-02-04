# res://resources/data/affix_pool_manager.gd
# Manages categorized affix pools
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
# CALCULATE STATS
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
# GET SPECIAL AFFIXES
# ============================================================================

func get_granted_actions() -> Array:
	"""Get all actions granted by affixes"""
	var actions: Array = []
	
	for affix in get_pool(Affix.Category.NEW_ACTION):
		if affix.granted_action:
			actions.append(affix.granted_action)
	
	return actions

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
