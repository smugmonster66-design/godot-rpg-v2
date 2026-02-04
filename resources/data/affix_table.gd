# affix_table.gd - Configurable table of affixes for rolling
extends Resource
class_name AffixTable

# ============================================================================
# TABLE CONFIGURATION
# ============================================================================
@export var table_name: String = "New Affix Table"
@export_multiline var description: String = "Describe what this table is for (e.g., 'First-tier helm affixes')"

# The affixes that can roll from this table
@export var available_affixes: Array[Affix] = []

# ============================================================================
# WEIGHTS (Optional - for advanced control)
# ============================================================================
# If true, uses weighted random selection based on affix weights
@export var use_weighted_selection: bool = false

# Per-affix weights (only used if use_weighted_selection = true)
# Index matches available_affixes array
@export var affix_weights: Array[int] = []

# ============================================================================
# UTILITY
# ============================================================================

func get_random_affix() -> Affix:
	"""Get a random affix from this table"""
	if available_affixes.size() == 0:
		print("⚠️ AffixTable '%s' is empty!" % table_name)
		return null
	
	if use_weighted_selection and affix_weights.size() == available_affixes.size():
		return _get_weighted_random_affix()
	else:
		return available_affixes.pick_random()

func _get_weighted_random_affix() -> Affix:
	"""Get random affix using weighted selection"""
	var total_weight = 0
	for weight in affix_weights:
		total_weight += weight
	
	if total_weight == 0:
		print("⚠️ AffixTable '%s' has zero total weight, using random" % table_name)
		return available_affixes.pick_random()
	
	var roll = randi_range(0, total_weight - 1)
	var cumulative = 0
	
	for i in range(available_affixes.size()):
		cumulative += affix_weights[i]
		if roll < cumulative:
			return available_affixes[i]
	
	return available_affixes[-1]

func get_table_size() -> int:
	"""Get number of affixes in this table"""
	return available_affixes.size()

func has_affix(affix: Affix) -> bool:
	"""Check if affix is in this table"""
	return affix in available_affixes

func get_all_affixes() -> Array[Affix]:
	"""Get all affixes in this table"""
	return available_affixes.duplicate()

func is_valid() -> bool:
	"""Check if table has at least one affix"""
	return available_affixes.size() > 0
