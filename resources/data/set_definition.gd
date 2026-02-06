# res://resources/data/set_definition.gd
# Defines an equipment set: its identity, bonus thresholds, and optional member list.
# Items reference this resource via their set_definition field.
# The SetTracker on the Player handles activation/deactivation of bonuses.
extends Resource
class_name SetDefinition

# ============================================================================
# IDENTITY
# ============================================================================

## Display name shown in tooltips and UI (e.g., "Frostborn Regalia")
@export var set_name: String = "New Set"

## Unique identifier for matching. Use snake_case (e.g., "frostborn_regalia").
## Items with the same set_id belong to this set.
@export var set_id: StringName = &""

## Optional icon displayed alongside the set name in UI
@export var set_icon: Texture2D = null

## Color used for the set name in tooltips and item borders
@export var set_color: Color = Color(0.2, 0.8, 0.6)  # Teal-green default

# ============================================================================
# BONUS THRESHOLDS
# ============================================================================
@export_group("Bonuses")

## Ordered list of bonus thresholds. Each activates at its required_pieces count.
## Example: [{required: 2, affixes: [...]}, {required: 4, affixes: [...]}]
## Thresholds should be ordered by required_pieces ascending.
@export var thresholds: Array[SetBonusThreshold] = []

# ============================================================================
# MEMBER ITEMS (Optional - for UI display)
# ============================================================================
@export_group("Set Members (UI Only)")

## Optional list of items in this set. Used ONLY for tooltip display
## (e.g., showing "✓ Frostborn Helm / ✗ Frostborn Plate").
## The system works fine without this — items reference the set, not vice versa.
## Populate this for richer tooltips; leave empty if you prefer minimal authoring.
@export var member_items: Array[EquippableItem] = []

# ============================================================================
# QUERY METHODS
# ============================================================================

func get_active_thresholds(equipped_count: int) -> Array[SetBonusThreshold]:
	"""Get all thresholds that should be active at the given piece count.
	
	Args:
		equipped_count: Number of set pieces currently equipped.
	
	Returns:
		Array of thresholds where required_pieces <= equipped_count.
	"""
	var active: Array[SetBonusThreshold] = []
	for threshold in thresholds:
		if equipped_count >= threshold.required_pieces:
			active.append(threshold)
	return active

func get_next_threshold(equipped_count: int) -> SetBonusThreshold:
	"""Get the next threshold the player hasn't reached yet.
	
	Args:
		equipped_count: Number of set pieces currently equipped.
	
	Returns:
		The next unreached threshold, or null if all are active.
	"""
	for threshold in thresholds:
		if equipped_count < threshold.required_pieces:
			return threshold
	return null

func get_max_pieces() -> int:
	"""Get the highest threshold's required piece count.
	Useful for UI display (e.g., '2/4 Frostborn Regalia').
	"""
	var max_val: int = 0
	for threshold in thresholds:
		max_val = max(max_val, threshold.required_pieces)
	
	# If member_items is populated, use that as the true max
	if member_items.size() > max_val:
		max_val = member_items.size()
	
	return max_val

func get_total_pieces() -> int:
	"""Get total number of items in the set.
	Uses member_items if populated, otherwise uses highest threshold.
	"""
	if member_items.size() > 0:
		return member_items.size()
	return get_max_pieces()

func get_affix_source_name() -> String:
	"""Get the source string used when registering affixes with AffixPoolManager.
	Format: 'set:Set Name' — allows clean removal via remove_affixes_by_source().
	"""
	return "set:%s" % set_name

# ============================================================================
# DEBUG
# ============================================================================

func _to_string() -> String:
	return "SetDefinition<%s, %d thresholds>" % [set_name, thresholds.size()]
