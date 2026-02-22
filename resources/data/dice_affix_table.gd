# res://resources/data/dice_affix_table.gd
# Configurable table of DiceAffixes for random rolling onto dice.
# Mirrors AffixTable but holds Array[DiceAffix] instead of Array[Affix].
#
# Used by DieGenerator to roll random dice affixes onto granted dice,
# the same way AffixTable is used by EquippableItem to roll item affixes.
extends Resource
class_name DiceAffixTable

# ============================================================================
# TABLE CONFIGURATION
# ============================================================================
@export var table_name: String = "New Dice Affix Table"
@export_multiline var description: String = ""

## The dice affixes that can roll from this table.
@export var available_affixes: Array[DiceAffix] = []

# ============================================================================
# WEIGHTS (Optional — for advanced control)
# ============================================================================

## If true, uses weighted random selection based on affix_weights.
@export var use_weighted_selection: bool = false

## Per-affix weights (only used if use_weighted_selection = true).
## Index matches available_affixes array.
@export var affix_weights: Array[int] = []

# ============================================================================
# ELEMENT FILTER (Optional — for element-specific rolling)
# ============================================================================

## If non-empty, this table only applies to dice of these elements.
## Empty = applies to all elements (default).
@export var element_filter: Array[DieResource.Element] = []

# ============================================================================
# PUBLIC API
# ============================================================================

func get_random_affix() -> DiceAffix:
	"""Get a random dice affix from this table."""
	if available_affixes.is_empty():
		return null

	if use_weighted_selection and affix_weights.size() == available_affixes.size():
		return _get_weighted_random()
	else:
		return available_affixes.pick_random()


func get_random_affix_for_element(element: DieResource.Element) -> DiceAffix:
	"""Get a random affix, filtering by element compatibility.

	If this table has no element_filter, any element is fine.
	If it has a filter, the die's element must be in it.
	"""
	if not element_filter.is_empty() and element not in element_filter:
		return null
	return get_random_affix()


func get_table_size() -> int:
	return available_affixes.size()


func has_affix(affix: DiceAffix) -> bool:
	return affix in available_affixes


func is_valid() -> bool:
	return available_affixes.size() > 0


func applies_to_element(element: DieResource.Element) -> bool:
	"""Check if this table can roll for a given element."""
	if element_filter.is_empty():
		return true
	return element in element_filter


# ============================================================================
# INTERNAL
# ============================================================================

func _get_weighted_random() -> DiceAffix:
	var total_weight := 0
	for w in affix_weights:
		total_weight += w

	if total_weight == 0:
		return available_affixes.pick_random()

	var roll := randi_range(0, total_weight - 1)
	var cumulative := 0

	for i in range(available_affixes.size()):
		cumulative += affix_weights[i]
		if roll < cumulative:
			return available_affixes[i]

	return available_affixes[-1]
