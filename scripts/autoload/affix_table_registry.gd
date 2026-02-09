# res://autoloads/affix_table_registry.gd
# Autoload singleton that provides runtime access to the 9 base AffixTables
# and the global AffixScalingConfig.
#
# Add this as an Autoload in Project → Project Settings → Globals:
#   Name: AffixTableRegistry
#   Path: res://autoloads/affix_table_registry.gd
#
# USAGE:
#   var tables = AffixTableRegistry.get_tables_for_slot_tier(slot_def, 2)
#   var config = AffixTableRegistry.scaling_config
#   var power = config.get_power_position(item_level)
#
extends Node

# ============================================================================
# TABLE PATHS — Edit these if you reorganize files
# ============================================================================

const TABLE_DIR := "res://resources/affix_tables/base/"
const SCALING_CONFIG_PATH := "res://resources/scaling/affix_scaling_config.tres"

# ============================================================================
# LOADED RESOURCES
# ============================================================================

## The 9 base tables, keyed by "family_tier" (e.g. "offense_1", "defense_3")
var table_registry: Dictionary = {}

## Global scaling configuration
var scaling_config: AffixScalingConfig = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_tables()
	_load_scaling_config()
	
	if OS.is_debug_build():
		_print_registry_summary()


func _load_tables() -> void:
	"""Load all 9 base AffixTables from disk."""
	var families := ["offense", "defense", "utility"]
	var tiers := [1, 2, 3]
	
	for family in families:
		for tier in tiers:
			var key := "%s_%d" % [family, tier]
			var path := "%s%s_tier_%d.tres" % [TABLE_DIR, family, tier]
			
			if ResourceLoader.exists(path):
				var table: AffixTable = load(path)
				if table:
					table_registry[key] = table
				else:
					push_warning("AffixTableRegistry: Failed to load table at %s" % path)
			else:
				push_warning("AffixTableRegistry: Table not found at %s" % path)
	
	print("📋 AffixTableRegistry: Loaded %d/9 base tables" % table_registry.size())


func _load_scaling_config() -> void:
	"""Load the global scaling configuration."""
	if ResourceLoader.exists(SCALING_CONFIG_PATH):
		scaling_config = load(SCALING_CONFIG_PATH)
		if scaling_config:
			print("📈 AffixTableRegistry: Scaling config loaded (max_level=%d, fuzz=%.0f%%)" % [
				scaling_config.max_item_level,
				scaling_config.default_fuzz_percent * 100
			])
		else:
			push_warning("AffixTableRegistry: Failed to load scaling config")
	else:
		push_warning("AffixTableRegistry: No scaling config at %s — using defaults" % SCALING_CONFIG_PATH)


func _print_registry_summary() -> void:
	"""Debug: Print table contents summary."""
	print("─── Affix Table Registry ───")
	for key in table_registry:
		var table: AffixTable = table_registry[key]
		print("  %s: %d affixes" % [key, table.available_affixes.size()])
	print("────────────────────────────")

# ============================================================================
# PUBLIC API
# ============================================================================

func get_table(family: StringName, tier: int) -> AffixTable:
	"""Get a specific base table by family and tier.
	
	Args:
		family: "offense", "defense", or "utility"
		tier: 1, 2, or 3
	
	Returns:
		The AffixTable, or null if not found.
	"""
	var key := "%s_%d" % [family, tier]
	return table_registry.get(key, null)


func get_tables_for_slot_tier(slot_def: SlotDefinition, tier: int) -> Array[AffixTable]:
	"""Get all tables a slot is allowed to roll from for a given tier.
	
	This is the primary API for the item rolling system. It checks the
	SlotDefinition's family flags and returns matching tables.
	
	Args:
		slot_def: The item's slot definition.
		tier: Which affix tier (1=Uncommon, 2=Rare, 3=Epic).
	
	Returns:
		Array of AffixTable resources the item can roll from.
	"""
	return slot_def.get_tables_for_tier(tier, table_registry)


func roll_affix_for_slot(slot_def: SlotDefinition, tier: int,
						 item_level: int) -> Affix:
	"""Roll a single affix appropriate for a slot, tier, and item level.
	
	Convenience method that handles table selection, random affix pick,
	duplication, and value rolling in one call.
	
	Args:
		slot_def: The item's slot definition.
		tier: Which affix tier to roll from.
		item_level: The item's level for value scaling.
	
	Returns:
		A fully rolled Affix copy, or null if no tables/affixes available.
	"""
	var tables = get_tables_for_slot_tier(slot_def, tier)
	if tables.is_empty():
		return null
	
	# Pick a random table from the available families, then a random affix
	var table: AffixTable = tables.pick_random()
	if not table or not table.is_valid():
		return null
	
	var base_affix: Affix = table.get_random_affix()
	if not base_affix:
		return null
	
	# Duplicate and roll value
	var rolled: Affix = base_affix.duplicate_with_source("", "item")
	
	if scaling_config and rolled.has_scaling():
		var power_pos: float = scaling_config.get_power_position(item_level)
		rolled.roll_value(power_pos, scaling_config)
	
	return rolled


func get_registry_dict() -> Dictionary:
	"""Get the raw table registry dictionary.
	
	Useful for passing to SlotDefinition.get_tables_for_tier().
	Keys are "family_tier" strings like "offense_1", "defense_3".
	"""
	return table_registry
