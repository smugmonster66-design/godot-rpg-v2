# res://resources/data/slot_definition.gd
# Defines the default affix table families and base stats for an equipment slot.
#
# Each EquippableItem references a SlotDefinition. When creating a new item
# in the editor, selecting a slot auto-populates the affix family configuration
# from the SlotDefinition's defaults. The designer can then override per-item.
#
# The 9 base AffixTables (offense/defense/utility × tier 1/2/3) are loaded
# from a singleton. SlotDefinition just controls WHICH of those 9 tables
# each tier is allowed to roll from via the family flags.
#
# EXAMPLE (Head slot):
#   tier_1_offense = false, tier_1_defense = true, tier_1_utility = true
#   tier_2_offense = false, tier_2_defense = true, tier_2_utility = true
#   tier_3_offense = false, tier_3_defense = true, tier_3_utility = true
#   → Head items never roll offensive affixes by default
#
extends Resource
class_name SlotDefinition

# ============================================================================
# SLOT IDENTITY
# ============================================================================

@export var slot_name: String = "New Slot"
@export var slot_type: EquippableItem.EquipSlot = EquippableItem.EquipSlot.MAIN_HAND

# ============================================================================
# TIER 1 AFFIX FAMILIES (Uncommon+)
# ============================================================================
@export_group("Tier 1 Families (Uncommon+)")

## Allow tier 1 offensive affixes (stat bonuses, flat damage, typed damage)
@export var tier_1_offense: bool = false

## Allow tier 1 defensive affixes (armor, resists, health, heal after combat)
@export var tier_1_defense: bool = true

## Allow tier 1 utility affixes (mana, neutral dice grants, elemental D4s)
@export var tier_1_utility: bool = true

# ============================================================================
# TIER 2 AFFIX FAMILIES (Rare+)
# ============================================================================
@export_group("Tier 2 Families (Rare+)")

## Allow tier 2 offensive affixes (multipliers, elemental damage, procs)
@export var tier_2_offense: bool = false

## Allow tier 2 defensive affixes (barrier, regen, combat start buffs, procs)
@export var tier_2_defense: bool = true

## Allow tier 2 utility affixes (mana regen, D8/D10 grants, elemental D6s)
@export var tier_2_utility: bool = true

# ============================================================================
# TIER 3 AFFIX FAMILIES (Epic+)
# ============================================================================
@export_group("Tier 3 Families (Epic+)")

## Allow tier 3 offensive affixes (global mult, lifesteal, stacking procs)
@export var tier_3_offense: bool = false

## Allow tier 3 defensive affixes (defense mult, thorns, % heal procs)
@export var tier_3_defense: bool = true

## Allow tier 3 utility affixes (D12 grants, elemental D8/D10/D12, actions)
@export var tier_3_utility: bool = true

# ============================================================================
# BASE STATS
# ============================================================================
@export_group("Base Stats")

## Base armor this slot provides (before affixes). Primarily for armor slots.
@export var base_armor: int = 0

## Base barrier this slot provides.
@export var base_barrier: int = 0

## Base health bonus from this slot.
@export var base_health: int = 0

## Base mana bonus from this slot.
@export var base_mana: int = 0

# ============================================================================
# HEAVY WEAPON CONFIGURATION
# ============================================================================
@export_group("Heavy Weapon")

## If true, this slot gets double affix rolls (6 total instead of 3).
## Only relevant for HEAVY slot.
@export var double_affix_rolls: bool = false

# ============================================================================
# PUBLIC API
# ============================================================================

func get_tier_families(tier: int) -> Array[StringName]:
	"""Get the list of allowed affix families for a given tier.
	
	Args:
		tier: Affix tier (1, 2, or 3).
	
	Returns:
		Array of family names: "offense", "defense", "utility"
	"""
	var families: Array[StringName] = []
	
	match tier:
		1:
			if tier_1_offense: families.append(&"offense")
			if tier_1_defense: families.append(&"defense")
			if tier_1_utility: families.append(&"utility")
		2:
			if tier_2_offense: families.append(&"offense")
			if tier_2_defense: families.append(&"defense")
			if tier_2_utility: families.append(&"utility")
		3:
			if tier_3_offense: families.append(&"offense")
			if tier_3_defense: families.append(&"defense")
			if tier_3_utility: families.append(&"utility")
		_:
			push_warning("SlotDefinition: Invalid tier %d" % tier)
	
	return families


func get_tables_for_tier(tier: int, table_registry: Dictionary) -> Array[AffixTable]:
	"""Get the actual AffixTable resources this slot can roll from for a tier.
	
	Args:
		tier: Affix tier (1, 2, or 3).
		table_registry: Dictionary mapping "family_tier" keys to AffixTable.
			Example: {"offense_1": offense_t1_table, "defense_2": defense_t2_table, ...}
	
	Returns:
		Array of AffixTable resources the item can roll from.
	"""
	var tables: Array[AffixTable] = []
	var families = get_tier_families(tier)
	
	for family in families:
		var key: String = "%s_%d" % [family, tier]
		if table_registry.has(key):
			tables.append(table_registry[key])
		else:
			push_warning("SlotDefinition: No table found for key '%s'" % key)
	
	return tables


func get_total_roll_count(rarity: EquippableItem.Rarity) -> int:
	"""Get the total number of affix rolls based on rarity and slot config.
	
	Args:
		rarity: Item rarity.
	
	Returns:
		Number of affixes to roll (before unique legendary affix).
	"""
	var base_count: int = 0
	match rarity:
		EquippableItem.Rarity.COMMON:
			base_count = 0
		EquippableItem.Rarity.UNCOMMON:
			base_count = 1
		EquippableItem.Rarity.RARE:
			base_count = 2
		EquippableItem.Rarity.EPIC, EquippableItem.Rarity.LEGENDARY:
			base_count = 3
	
	if double_affix_rolls:
		base_count *= 2
	
	return base_count


func get_base_stats_dict() -> Dictionary:
	"""Get base stats as a dictionary for easy application.
	
	Returns:
		Dictionary of stat_name → value (only non-zero stats included).
	"""
	var stats: Dictionary = {}
	if base_armor > 0: stats["armor"] = base_armor
	if base_barrier > 0: stats["barrier"] = base_barrier
	if base_health > 0: stats["health"] = base_health
	if base_mana > 0: stats["mana"] = base_mana
	return stats


func _to_string() -> String:
	var t1 = "/".join(get_tier_families(1))
	var t2 = "/".join(get_tier_families(2))
	var t3 = "/".join(get_tier_families(3))
	return "SlotDef<%s | T1:[%s] T2:[%s] T3:[%s]>" % [slot_name, t1, t2, t3]
