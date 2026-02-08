# equippable_item.gd - Equipment with affix tables for rolling
extends Resource
class_name EquippableItem

# ============================================================================
# ENUMS
# ============================================================================
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

enum EquipSlot {
	HEAD,
	TORSO,
	GLOVES,
	BOOTS,
	MAIN_HAND,
	OFF_HAND,
	HEAVY,  # Two-handed weapons
	ACCESSORY
}

# ============================================================================
# BASIC ITEM DATA
# ============================================================================
@export var item_name: String = "New Item"
@export_multiline var description: String = "An equippable item."
@export var icon: Texture2D = null
@export var rarity: Rarity = Rarity.COMMON
@export var equip_slot: EquipSlot = EquipSlot.MAIN_HAND
@export var set_definition: SetDefinition = null

## Optional element for this item. Flows to action fields as their element.
@export var has_elemental_identity: bool = false
@export var elemental_identity: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING

# ============================================================================
# AFFIX SYSTEM - TABLES
# ============================================================================
@export_group("Affix Tables")

# Assign affix tables to each slot
# Items will roll from these tables based on rarity
@export var first_affix_table: AffixTable = null
@export var second_affix_table: AffixTable = null
@export var third_affix_table: AffixTable = null

# ============================================================================
# AFFIX SYSTEM - MANUAL OVERRIDE
# ============================================================================
@export_group("Manual Affixes (Override)")

# Manual affix assignment (optional - overrides table rolling)
# Leave these empty to use table rolling instead
@export var manual_first_affix: Affix = null
@export var manual_second_affix: Affix = null
@export var manual_third_affix: Affix = null

# LEGENDARY ONLY: Fourth unique affix
@export_subgroup("Legendary Unique Affix")
@export var unique_affix: Affix = null

# Runtime affixes (populated either manually or by rolling)
var item_affixes: Array[Affix] = []

# ============================================================================
# DICE
# ============================================================================
# In equippable_item.gd
@export_group("Dice")
## Dice this item grants. Drag DieResource files here (like enemy dice).
@export var grants_dice: Array[DieResource] = []  # Changed from Array[DieResource.DieType]
@export var dice_tags: Array[String] = []

# ============================================================================
# COMBAT ACTION
# ============================================================================
@export_group("Combat Action")
@export var grants_action: bool = false
@export var action: Action = null


# ============================================================================
# ELEMENTAL IDENTITY
# ============================================================================

func get_elemental_identity() -> int:
	"""Find the elemental identity — item-level first, then affixes.
	Returns the DamageType int, or -1 if none is set."""
	# Item-level override
	if has_elemental_identity:
		return elemental_identity
	# Scan affixes
	for affix in item_affixes:
		if affix and affix.has_elemental_identity:
			return affix.elemental_identity
	return -1


# ============================================================================
# UTILITY
# ============================================================================

func is_heavy_weapon() -> bool:
	"""Check if this is a two-handed weapon"""
	return equip_slot == EquipSlot.HEAVY

func get_rarity_color() -> Color:
	"""Get color for rarity tier"""
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.BLUE
		Rarity.EPIC: return Color.PURPLE
		Rarity.LEGENDARY: return Color.ORANGE
		_: return Color.WHITE

func get_rarity_name() -> String:
	"""Get rarity name as string"""
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
		_: return "Unknown"

func get_slot_name() -> String:
	"""Get equipment slot name"""
	match equip_slot:
		EquipSlot.HEAD: return "Head"
		EquipSlot.TORSO: return "Torso"
		EquipSlot.GLOVES: return "Gloves"
		EquipSlot.BOOTS: return "Boots"
		EquipSlot.MAIN_HAND: return "Main Hand"
		EquipSlot.OFF_HAND: return "Off Hand"
		EquipSlot.HEAVY: return "Main Hand"
		EquipSlot.ACCESSORY: return "Accessory"
		_: return "Unknown"

# ============================================================================
# AFFIX MANAGEMENT
# ============================================================================

func initialize_affixes(affix_pool = null):
	"""Initialize affixes - use manual if set, otherwise roll from tables
	
	Args:
		affix_pool: Legacy parameter, no longer used (kept for compatibility)
	"""
	item_affixes.clear()
	
	# Check if manual affixes are set
	if manual_first_affix or manual_second_affix or manual_third_affix:
		_use_manual_affixes()
	else:
		_roll_from_tables()
	
	# LEGENDARY: Always add unique affix if present
	if rarity == Rarity.LEGENDARY and unique_affix:
		_add_unique_affix()

func _use_manual_affixes():
	"""Use manually assigned affixes from Inspector"""
	if manual_first_affix:
		var copy = manual_first_affix.duplicate_with_source(item_name, "item")
		item_affixes.append(copy)
		print("  ✓ Using manual affix 1: %s" % manual_first_affix.affix_name)
	
	if manual_second_affix:
		var copy = manual_second_affix.duplicate_with_source(item_name, "item")
		item_affixes.append(copy)
		print("  ✓ Using manual affix 2: %s" % manual_second_affix.affix_name)
	
	if manual_third_affix:
		var copy = manual_third_affix.duplicate_with_source(item_name, "item")
		item_affixes.append(copy)
		print("  ✓ Using manual affix 3: %s" % manual_third_affix.affix_name)

func _roll_from_tables():
	"""Roll random affixes from assigned affix tables
	
	Rarity determines which tables to roll from:
	- COMMON: No affixes
	- UNCOMMON: Roll 1 from first_affix_table
	- RARE: Roll 1 from first_affix_table, 1 from second_affix_table
	- EPIC: Roll from all three tables
	- LEGENDARY: Roll from all three tables + unique affix
	"""
	var num_affixes = get_affix_count_for_rarity()
	
	if num_affixes >= 1:
		_roll_from_table(first_affix_table, "First")
	
	if num_affixes >= 2:
		_roll_from_table(second_affix_table, "Second")
	
	if num_affixes >= 3:
		_roll_from_table(third_affix_table, "Third")
	
	print("✨ Rolled %d affixes for %s" % [item_affixes.size(), item_name])

func _roll_from_table(table: AffixTable, tier_name: String):
	"""Roll one affix from a specific affix table"""
	if not table:
		print("  ⚠️ No %s affix table assigned for %s" % [tier_name, item_name])
		return
	
	if not table.is_valid():
		print("  ⚠️ %s affix table is empty for %s" % [tier_name, item_name])
		return
	
	var affix = table.get_random_affix()
	if affix:
		var affix_copy = affix.duplicate_with_source(item_name, "item")
		item_affixes.append(affix_copy)
		print("  🎲 Rolled %s affix: %s (from table: %s)" % [tier_name, affix.affix_name, table.table_name])
	else:
		print("  ❌ Failed to roll from %s table" % tier_name)

func _add_unique_affix():
	"""Add the unique legendary affix (4th affix)"""
	if not unique_affix:
		print("  ⚠️ LEGENDARY item missing unique affix!")
		return
	
	var copy = unique_affix.duplicate_with_source(item_name, "item")
	item_affixes.append(copy)
	print("  ⭐ Added UNIQUE affix: %s" % unique_affix.affix_name)

func get_affix_count_for_rarity() -> int:
	"""Get number of affixes to roll based on rarity (excludes unique affix)"""
	match rarity:
		Rarity.COMMON: return 0
		Rarity.UNCOMMON: return 1
		Rarity.RARE: return 2
		Rarity.EPIC: return 3
		Rarity.LEGENDARY: return 3  # + unique affix = 4 total
		_: return 0

func get_all_affixes() -> Array[Affix]:
	"""Get all affixes this item grants"""
	return item_affixes.duplicate()

# ============================================================================
# BACKWARD COMPATIBILITY
# ============================================================================

func roll_affixes(affix_pool = null):
	"""Legacy function - calls initialize_affixes for compatibility"""
	initialize_affixes(affix_pool)

# ============================================================================
# CONVERSION FOR UI/INVENTORY
# ============================================================================

func to_dict() -> Dictionary:
	"""Convert to Dictionary for UI compatibility"""
	var dict = {
		"name": item_name,
		"display_name": item_name,
		"slot": get_slot_name(),
		"description": description,
		"dice_resources": [],
		"dice_tags": dice_tags.duplicate(),
		"is_heavy": is_heavy_weapon(),
		"icon": icon,
		"rarity": get_rarity_name()
	}
	
	# Add dice resources (actual DieResource copies)
	for die in grants_dice:
		if die:
			dict["dice_resources"].append(die.duplicate_die())
	
	# Add affixes as dictionaries for UI display
	var affixes_data = []
	for affix in item_affixes:
		affixes_data.append({
			"name": affix.affix_name,
			"display_name": affix.affix_name,
			"description": affix.description,
			"category": affix.category,
			"category_name": affix.get_category_name()
		})
	
	if affixes_data.size() > 0:
		dict["affixes"] = affixes_data
	
	if grants_action and action:
		var action_dict = action.to_dict()
		action_dict["action_resource"] = action
		dict["actions"] = [action_dict]
	
	# Equipment set
	if set_definition:
		dict["set_definition"] = set_definition
		dict["set_name"] = set_definition.set_name
		dict["set_id"] = set_definition.set_id
		dict["set_color"] = set_definition.set_color
	
	# Elemental identity from affixes
	var elem_id = get_elemental_identity()
	if elem_id >= 0:
		dict["elemental_identity"] = elem_id
	
	return dict
