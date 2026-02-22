# res://scripts/autoload/dice_affix_table_registry.gd
# Autoload singleton that provides runtime access to the 9 base DiceAffixTables
# (3 families × 3 tiers) and convenience rolling methods.
#
# Mirrors AffixTableRegistry but for the DiceAffix system.
#
# Add as Autoload in Project → Project Settings → Globals:
#   Name: DiceAffixTableRegistry
#   Path: res://scripts/autoload/dice_affix_table_registry.gd
#
# Table families:
#   - value:      Flat/percent value mods, set min/max, roll-keep-highest
#   - combat:     Elemental damage, status effects, leech, element conversion
#   - positional: Neighbor interactions, conditional bonuses, rerolls, utility
#
# USAGE:
#   var tables = DiceAffixTableRegistry.get_tables_for_tier(2)
#   var affix = DiceAffixTableRegistry.roll_affix(2, 15, DieResource.Element.FIRE)
#
extends Node

# ============================================================================
# PATHS
# ============================================================================

const TABLE_DIR := "res://resources/dice_affix_tables/"

# ============================================================================
# STATE
# ============================================================================

## The 9 base tables, keyed by "family_tier" (e.g. "value_1", "combat_3").
var table_registry: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_tables()
	if OS.is_debug_build():
		_print_summary()


func _load_tables() -> void:
	"""Load all 9 base DiceAffixTables from disk."""
	var families := ["value", "combat", "positional"]
	var tiers := [1, 2, 3]

	for family in families:
		for tier in tiers:
			var key := "%s_%d" % [family, tier]
			var path := "%s%s_tier_%d.tres" % [TABLE_DIR, family, tier]

			if ResourceLoader.exists(path):
				var table: DiceAffixTable = load(path)
				if table:
					table_registry[key] = table
				else:
					push_warning("DiceAffixTableRegistry: Failed to load %s" % path)
			else:
				# Tables may not exist yet — that's fine during development
				if OS.is_debug_build():
					print("  ⏭️ DiceAffixTableRegistry: No table at %s" % path)

	print("🎲 DiceAffixTableRegistry: Loaded %d/9 dice affix tables" % table_registry.size())


func _print_summary() -> void:
	if table_registry.is_empty():
		return
	print("─── Dice Affix Table Registry ───")
	for key in table_registry:
		var table: DiceAffixTable = table_registry[key]
		print("  %s: %d affixes" % [key, table.get_table_size()])
	print("─────────────────────────────────")


# ============================================================================
# PUBLIC API — Table Access
# ============================================================================

func get_table(family: StringName, tier: int) -> DiceAffixTable:
	"""Get a specific table by family and tier.

	Args:
		family: "value", "combat", or "positional"
		tier: 1, 2, or 3
	"""
	var key := "%s_%d" % [family, tier]
	return table_registry.get(key, null)


func get_tables_for_tier(tier: int) -> Array[DiceAffixTable]:
	"""Get all tables for a given tier (all 3 families).

	Args:
		tier: 1, 2, or 3

	Returns:
		Array of available DiceAffixTables for that tier.
	"""
	var result: Array[DiceAffixTable] = []
	for family in ["value", "combat", "positional"]:
		var key := "%s_%d" % [family, tier]
		if table_registry.has(key):
			var table: DiceAffixTable = table_registry[key]
			if table.is_valid():
				result.append(table)
	return result


func get_tables_for_tier_and_element(tier: int, element: DieResource.Element) -> Array[DiceAffixTable]:
	"""Get tables for a tier, filtered by element compatibility.

	Tables with empty element_filter match any element.
	Tables with a filter only match if the element is listed.
	"""
	var result: Array[DiceAffixTable] = []
	for family in ["value", "combat", "positional"]:
		var key := "%s_%d" % [family, tier]
		if table_registry.has(key):
			var table: DiceAffixTable = table_registry[key]
			if table.is_valid() and table.applies_to_element(element):
				result.append(table)
	return result


# ============================================================================
# PUBLIC API — Rolling
# ============================================================================

func roll_affix(tier: int, item_level: int,
		element: DieResource.Element = DieResource.Element.NONE,
		scaling_config: AffixScalingConfig = null) -> DiceAffix:
	"""Roll a single random DiceAffix from the given tier.

	Handles table selection, random pick, duplication, and value scaling.

	Args:
		tier: Which tier to roll from (1, 2, or 3).
		item_level: Item level for value scaling.
		element: Die element for table filtering.
		scaling_config: Optional scaling config for fuzz. If null, tries
						to get it from AffixTableRegistry.

	Returns:
		A fully rolled DiceAffix copy, or null if no tables/affixes available.
	"""
	var tables := get_tables_for_tier_and_element(tier, element)
	if tables.is_empty():
		return null

	var table: DiceAffixTable = tables.pick_random()
	if not table or not table.is_valid():
		return null

	var base_affix: DiceAffix = table.get_random_affix_for_element(element)
	if not base_affix:
		return null

	# Duplicate so we don't modify the template
	var rolled: DiceAffix = base_affix.duplicate(true)

	# Scale effect_value if this affix has min/max range
	if rolled.has_scaling():
		var power_pos := _get_power_position(item_level, scaling_config)
		rolled.roll_scaled_value(power_pos, scaling_config)

	# Stamp source metadata
	rolled.source = "generated"
	rolled.source_type = "dice_roll"

	return rolled


func roll_multiple(count: int, tiers: Array[int], item_level: int,
		element: DieResource.Element = DieResource.Element.NONE,
		scaling_config: AffixScalingConfig = null,
		avoid_duplicates: bool = true) -> Array[DiceAffix]:
	"""Roll multiple DiceAffixes, one per tier entry.

	Args:
		count: How many to roll (should match tiers.size()).
		tiers: Array of tier values to roll from, e.g. [1, 2] for Rare.
		item_level: Item level for scaling.
		element: Die element for filtering.
		scaling_config: Optional.
		avoid_duplicates: If true, rerolls on duplicate affix_name (up to 3 attempts).

	Returns:
		Array of rolled DiceAffixes (may be shorter than count if tables are sparse).
	"""
	var results: Array[DiceAffix] = []
	var used_names: Array[String] = []

	for i in range(mini(count, tiers.size())):
		var tier: int = tiers[i]
		var max_attempts := 3 if avoid_duplicates else 1

		for _attempt in range(max_attempts):
			var rolled := roll_affix(tier, item_level, element, scaling_config)
			if not rolled:
				break
			if avoid_duplicates and rolled.affix_name in used_names:
				continue
			results.append(rolled)
			used_names.append(rolled.affix_name)
			break

	return results


# ============================================================================
# INTERNAL
# ============================================================================

func _get_power_position(item_level: int, scaling_config: AffixScalingConfig = null) -> float:
	"""Resolve power position from item level."""
	if scaling_config:
		return scaling_config.get_power_position(item_level)

	# Try to get from AffixTableRegistry
	var registry_node = get_node_or_null("/root/AffixTableRegistry")
	if registry_node and registry_node.scaling_config:
		return registry_node.scaling_config.get_power_position(item_level)

	# Fallback: linear 1-100
	return clampf(float(item_level - 1) / 99.0, 0.0, 1.0)


func get_registry_dict() -> Dictionary:
	"""Get the raw registry dictionary for external use."""
	return table_registry
