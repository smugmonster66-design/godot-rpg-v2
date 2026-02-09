# equippable_item.gd - Equipment with inherent stats, rolled affixes, and typed accessors
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
@export_multiline var flavor_text: String = ""
@export var icon: Texture2D = null
@export var rarity: Rarity = Rarity.COMMON
@export var equip_slot: EquipSlot = EquipSlot.MAIN_HAND
@export var set_definition: SetDefinition = null

## Optional element for this item. Flows to action fields as their element.
@export var has_elemental_identity: bool = false
@export var elemental_identity: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING

# ============================================================================
# ITEM IDENTITY
# ============================================================================
@export_group("Item Identity")

## Region this item originates from (1-6). Determines power budget and thematic pool.
@export_range(1, 6) var region: int = 1

## Item level within the region. Scales inherent stat values.
## Loot generation sets this based on area difficulty.
@export_range(1, 100) var item_level: int = 1

## Base gold value before rarity multiplier. Sell price = base_value * rarity_multiplier.
@export var base_value: int = 10

## Tags for filtering, set bonuses, Cate dialogue, and UI categorization.
## Examples: "heavy_armor", "cloth", "fire_themed", "region_3", "craftable"
@export var item_tags: PackedStringArray = []

# ============================================================================
# EQUIP REQUIREMENTS
# ============================================================================
@export_group("Equip Requirements")

## Minimum player level to equip. 0 = no requirement.
@export var required_level: int = 0

## Minimum stat values to equip. Only checked for stats > 0.
@export var required_strength: int = 0
@export var required_agility: int = 0
@export var required_intellect: int = 0

# ============================================================================
# VISUALS
# ============================================================================
@export_group("Visuals")

## Sprite overlay for paper doll / equipment display.
## For Spine: the skin or attachment name this item activates.
@export var equipped_sprite: Texture2D = null

## Spine skin name (if using Spine for layered character rendering).
## Leave empty if not using Spine.
@export var spine_skin_name: String = ""

## Optional tint or color variation applied to the equipped visual.
@export var visual_tint: Color = Color.WHITE

# ============================================================================
# INHERENT AFFIXES — The item's identity stats (always present, never random)
# ============================================================================
@export_group("Inherent Affixes")

## Fixed affixes that define this base item's identity.
## These are always active regardless of rarity and are NOT rolled randomly.
## Example: An Iron Helm always has +5 Armor. A Silk Hood always has +2 INT.
## Drag Affix .tres files here in the Inspector.
@export var inherent_affixes: Array[Affix] = []

# ============================================================================
# AFFIX SYSTEM — Rolled affix tables (one per slot, index = slot number)
# ============================================================================
@export_group("Affix Tables")

## Affix tables for each rollable slot. Index 0 = Tier 1 (Uncommon+),
## Index 1 = Tier 2 (Rare+), Index 2 = Tier 3 (Epic+), etc.
## Heavy weapons can have up to 6 entries. Standard gear uses 3.
@export var affix_tables: Array[AffixTable] = []

# ============================================================================
# AFFIX SYSTEM — Manual overrides (optional, bypasses table rolling)
# ============================================================================
@export_group("Manual Affixes (Override)")

## Manual affix assignment per slot. If any are set, ALL table rolling is skipped.
## Use for quest rewards, unique items, or testing.
@export var manual_affixes: Array[Affix] = []

## LEGENDARY ONLY: Unique fourth affix that only drops on this specific item.
@export_subgroup("Legendary Unique Affix")
@export var unique_affix: Affix = null

# ============================================================================
# RUNTIME STATE — Populated by initialize_affixes(), not saved to .tres
# ============================================================================

## All active rolled/manual affixes (NOT including inherent — those are always on).
var rolled_affixes: Array[Affix] = []

## Combined view: inherent + rolled + unique. Rebuilt by initialize_affixes().
var item_affixes: Array[Affix] = []

# ============================================================================
# DICE
# ============================================================================
@export_group("Dice")

## Dice this item grants. Drag DieResource files here.
@export var grants_dice: Array[DieResource] = []
@export var dice_tags: Array[String] = []

# ============================================================================
# COMBAT ACTION
# ============================================================================
@export_group("Combat Action")
@export var grants_action: bool = false
@export var action: Action = null

# ============================================================================
# BACKWARD COMPATIBILITY — Old 3-slot exports (read-only migration helpers)
# ============================================================================
@export_group("DEPRECATED — Use affix_tables array instead")
@export var first_affix_table: AffixTable = null
@export var second_affix_table: AffixTable = null
@export var third_affix_table: AffixTable = null
@export var manual_first_affix: Affix = null
@export var manual_second_affix: Affix = null
@export var manual_third_affix: Affix = null


# ============================================================================
# AFFIX MANAGEMENT
# ============================================================================

func initialize_affixes(affix_pool = null):
	"""Initialize all affixes: inherent + rolled/manual + unique.
	
	Call this when an item is generated (loot drop, shop purchase, quest reward).
	
	Args:
		affix_pool: Legacy parameter, no longer used (kept for compatibility).
	"""
	rolled_affixes.clear()
	item_affixes.clear()
	
	# Step 1: Always apply inherent affixes (the base item's identity)
	_apply_inherent_affixes()
	
	# Step 2: Roll or manually assign random affixes
	if _has_manual_affixes():
		_use_manual_affixes()
	else:
		_roll_from_tables()
	
	# Step 3: Add legendary unique affix if applicable
	if rarity == Rarity.LEGENDARY and unique_affix:
		_add_unique_affix()
	
	# Step 4: Build the combined list
	_rebuild_combined_affixes()

func _apply_inherent_affixes():
	"""Copy inherent affixes with source tracking.
	Inherent affixes keep their preset effect_number (no rolling)."""
	for affix in inherent_affixes:
		if affix:
			var copy = affix.duplicate_with_source(item_name, "item_inherent")
			item_affixes.append(copy)
			print("  📌 Inherent affix: %s (%.1f)" % [affix.affix_name, affix.effect_number])

func _has_manual_affixes() -> bool:
	"""Check if manual affixes are configured (new array OR legacy fields)."""
	if manual_affixes.size() > 0:
		return true
	# Legacy check
	return manual_first_affix != null or manual_second_affix != null or manual_third_affix != null

func _use_manual_affixes():
	"""Use manually assigned affixes (new array takes priority over legacy fields)."""
	var sources: Array[Affix] = []
	
	if manual_affixes.size() > 0:
		sources = manual_affixes
	else:
		# Legacy: gather from individual fields
		for affix in [manual_first_affix, manual_second_affix, manual_third_affix]:
			if affix:
				sources.append(affix)
	
	for affix in sources:
		if affix:
			var copy = affix.duplicate_with_source(item_name, "item")
			copy.roll_value()  # Roll within min/max range
			rolled_affixes.append(copy)
			print("  ✓ Manual affix: %s (rolled %.1f)" % [affix.affix_name, copy.effect_number])

func _roll_from_tables():
	"""Roll random affixes from the affix_tables array.
	
	Rarity determines how many tables to roll from:
	- COMMON: 0 rolled affixes
	- UNCOMMON: Table index 0
	- RARE: Tables 0-1
	- EPIC/LEGENDARY: Tables 0-2 (standard) or 0-5 (heavy weapons)
	"""
	var tables = _get_resolved_tables()
	var num_affixes = get_affix_count_for_rarity()
	
	for i in range(min(num_affixes, tables.size())):
		_roll_from_table(tables[i], i + 1)
	
	print("✨ Rolled %d affixes for %s (%s)" % [rolled_affixes.size(), item_name, get_rarity_name()])

func _get_resolved_tables() -> Array[AffixTable]:
	"""Get the affix tables to use, preferring the new array over legacy fields."""
	if affix_tables.size() > 0:
		return affix_tables
	
	# Legacy fallback: build array from individual fields
	var legacy: Array[AffixTable] = []
	for table in [first_affix_table, second_affix_table, third_affix_table]:
		if table:
			legacy.append(table)
	return legacy

func _roll_from_table(table: AffixTable, slot_number: int):
	"""Roll one affix from a specific affix table and roll its value."""
	if not table or not table.is_valid():
		print("  ⚠️ Affix table slot %d is null or empty for %s" % [slot_number, item_name])
		return
	
	var affix = table.get_random_affix()
	if affix:
		var copy = affix.duplicate_with_source(item_name, "item")
		copy.roll_value()  # Roll value between effect_min and effect_max
		rolled_affixes.append(copy)
		print("  🎲 Slot %d: %s = %.1f (from %s)" % [
			slot_number, affix.affix_name, copy.effect_number, table.table_name])
	else:
		print("  ❌ Failed to roll from table slot %d" % slot_number)

func _add_unique_affix():
	"""Add the unique legendary affix."""
	if not unique_affix:
		print("  ⚠️ LEGENDARY item missing unique affix!")
		return
	
	var copy = unique_affix.duplicate_with_source(item_name, "item_unique")
	copy.roll_value()
	rolled_affixes.append(copy)
	print("  ⭐ Unique affix: %s (%.1f)" % [unique_affix.affix_name, copy.effect_number])

func _rebuild_combined_affixes():
	"""Rebuild the combined item_affixes list from inherent + rolled."""
	item_affixes.clear()
	
	# Inherent first (these are the item's base identity)
	for affix in inherent_affixes:
		if affix:
			var copy = affix.duplicate_with_source(item_name, "item_inherent")
			item_affixes.append(copy)
	
	# Then rolled/manual affixes
	item_affixes.append_array(rolled_affixes)

func get_affix_count_for_rarity() -> int:
	"""Get number of affixes to roll based on rarity (excludes inherent and unique)."""
	var base_count: int
	match rarity:
		Rarity.COMMON: base_count = 0
		Rarity.UNCOMMON: base_count = 1
		Rarity.RARE: base_count = 2
		Rarity.EPIC: base_count = 3
		Rarity.LEGENDARY: base_count = 3  # + unique = 4 total
		_: base_count = 0
	
	# Heavy weapons get double affix slots
	if is_heavy_weapon():
		base_count *= 2
	
	return base_count

func get_all_affixes() -> Array[Affix]:
	"""Get all affixes (inherent + rolled + unique)."""
	return item_affixes.duplicate()

func get_inherent_affixes() -> Array[Affix]:
	"""Get only the inherent (non-random) affixes."""
	return inherent_affixes.duplicate()

func get_rolled_affixes() -> Array[Affix]:
	"""Get only the rolled/manual affixes (excluding inherent)."""
	return rolled_affixes.duplicate()

# ============================================================================
# EQUIP REQUIREMENTS
# ============================================================================

func can_equip(player) -> bool:
	"""Check if the player meets all equip requirements.
	
	Args:
		player: The Player resource. Needs get_base_stat() and level properties.
	
	Returns:
		true if all requirements are met.
	"""
	if not player:
		return false
	
	# Level check
	if required_level > 0:
		var player_level = player.get("level") if player.get("level") != null else 0
		if player_level < required_level:
			return false
	
	# Stat checks
	if required_strength > 0 and player.get_base_stat("strength") < required_strength:
		return false
	if required_agility > 0 and player.get_base_stat("agility") < required_agility:
		return false
	if required_intellect > 0 and player.get_base_stat("intellect") < required_intellect:
		return false
	
	return true

func get_unmet_requirements(player) -> Array[String]:
	"""Get list of human-readable unmet requirements for tooltip display.
	
	Returns:
		Array of strings like ["Requires Level 10", "Requires 15 Strength"]
	"""
	var unmet: Array[String] = []
	if not player:
		return unmet
	
	if required_level > 0:
		var player_level = player.get("level") if player.get("level") != null else 0
		if player_level < required_level:
			unmet.append("Requires Level %d" % required_level)
	
	if required_strength > 0 and player.get_base_stat("strength") < required_strength:
		unmet.append("Requires %d Strength" % required_strength)
	if required_agility > 0 and player.get_base_stat("agility") < required_agility:
		unmet.append("Requires %d Agility" % required_agility)
	if required_intellect > 0 and player.get_base_stat("intellect") < required_intellect:
		unmet.append("Requires %d Intellect" % required_intellect)
	
	return unmet

# ============================================================================
# ECONOMY
# ============================================================================

const RARITY_VALUE_MULTIPLIER := {
	Rarity.COMMON: 1.0,
	Rarity.UNCOMMON: 1.5,
	Rarity.RARE: 2.5,
	Rarity.EPIC: 5.0,
	Rarity.LEGENDARY: 10.0,
}

func get_sell_value() -> int:
	"""Calculate sell price: base_value × rarity multiplier × region scaling."""
	var multiplier = RARITY_VALUE_MULTIPLIER.get(rarity, 1.0)
	var region_scale = 1.0 + (region - 1) * 0.5  # Region 1 = 1.0x, Region 6 = 3.5x
	return int(base_value * multiplier * region_scale)

func get_buy_value() -> int:
	"""Shop buy price (typically 2-4x sell value)."""
	return get_sell_value() * 3

# ============================================================================
# ELEMENTAL IDENTITY
# ============================================================================

func get_elemental_identity() -> int:
	"""Find the elemental identity — item-level first, then affixes.
	Returns the DamageType int, or -1 if none is set."""
	# Item-level override
	if has_elemental_identity:
		return elemental_identity
	# Scan affixes (including inherent)
	for affix in item_affixes:
		if affix and affix.has_elemental_identity:
			return affix.elemental_identity
	return -1

# ============================================================================
# TAGS
# ============================================================================

func has_tag(tag: String) -> bool:
	"""Check if this item has a specific tag."""
	return tag in item_tags

func has_any_tag(tags: Array[String]) -> bool:
	"""Check if this item has any of the given tags."""
	for tag in tags:
		if tag in item_tags:
			return true
	return false

func has_all_tags(tags: Array[String]) -> bool:
	"""Check if this item has all of the given tags."""
	for tag in tags:
		if tag not in item_tags:
			return false
	return true

# ============================================================================
# UTILITY
# ============================================================================

func is_heavy_weapon() -> bool:
	"""Check if this is a two-handed weapon."""
	return equip_slot == EquipSlot.HEAVY

func get_rarity_color() -> Color:
	"""Get color for rarity tier."""
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.BLUE
		Rarity.EPIC: return Color.PURPLE
		Rarity.LEGENDARY: return Color.ORANGE
		_: return Color.WHITE

func get_rarity_name() -> String:
	"""Get rarity name as string."""
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
		_: return "Unknown"

func get_slot_name() -> String:
	"""Get equipment slot name."""
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

func get_display_name() -> String:
	"""Get the item name for UI display."""
	return item_name

func get_tooltip_lines() -> Array[String]:
	"""Build ordered tooltip lines for UI rendering.
	
	Returns an array of strings suitable for a tooltip panel:
	[name, slot + rarity, requirements, inherent stats, rolled affixes, unique, flavor]
	"""
	var lines: Array[String] = []
	
	# Header
	lines.append(item_name)
	lines.append("%s %s" % [get_rarity_name(), get_slot_name()])
	
	# Region / Level
	if item_level > 0:
		lines.append("Item Level %d (Region %d)" % [item_level, region])
	
	# Requirements
	var reqs: Array[String] = []
	if required_level > 0:
		reqs.append("Level %d" % required_level)
	if required_strength > 0:
		reqs.append("%d STR" % required_strength)
	if required_agility > 0:
		reqs.append("%d AGI" % required_agility)
	if required_intellect > 0:
		reqs.append("%d INT" % required_intellect)
	if reqs.size() > 0:
		lines.append("Requires: %s" % ", ".join(reqs))
	
	# Separator
	lines.append("---")
	
	# Inherent affixes
	for affix in inherent_affixes:
		if affix:
			lines.append(affix.get_display_text())
	
	# Rolled affixes
	if rolled_affixes.size() > 0:
		lines.append("---")
		for affix in rolled_affixes:
			lines.append(affix.get_display_text())
	
	# Set bonus hint
	if set_definition:
		lines.append("---")
		lines.append("Set: %s" % set_definition.set_name)
	
	# Flavor text
	if flavor_text != "":
		lines.append("---")
		lines.append(flavor_text)
	
	# Sell value
	lines.append("Sell: %d gold" % get_sell_value())
	
	return lines

# ============================================================================
# BACKWARD COMPATIBILITY
# ============================================================================

func roll_affixes(affix_pool = null):
	"""DEPRECATED — Use initialize_affixes() instead."""
	push_warning("roll_affixes() is deprecated. Use initialize_affixes().")
	initialize_affixes(affix_pool)

# ============================================================================
# DICTIONARY CONVERSION — DEPRECATED, use typed accessors above instead
# ============================================================================

func to_dict() -> Dictionary:
	"""Convert to Dictionary for UI/inventory compatibility.
	
	DEPRECATED: Downstream code should migrate to using EquippableItem directly.
	This bridge remains functional but new code should access typed properties.
	The dict now includes an 'equippable_item' back-reference for migration.
	"""
	var dict = {
		# Back-reference for gradual migration away from dict-based inventory
		"equippable_item": self,
		
		# Core identity
		"name": item_name,
		"display_name": item_name,
		"description": description,
		"flavor_text": flavor_text,
		"slot": get_slot_name(),
		"icon": icon,
		"rarity": get_rarity_name(),
		"rarity_color": get_rarity_color(),
		"is_heavy": is_heavy_weapon(),
		
		# New fields
		"region": region,
		"item_level": item_level,
		"sell_value": get_sell_value(),
		"item_tags": Array(item_tags),
		"required_level": required_level,
		
		# Dice
		"dice_resources": [],
		"dice_tags": dice_tags.duplicate(),
	}
	
	# Dice copies
	for die in grants_dice:
		if die:
			dict["dice_resources"].append(die.duplicate_die())
	
	# Affix data for UI display (combined inherent + rolled)
	var affixes_data = []
	for affix in item_affixes:
		affixes_data.append({
			"name": affix.affix_name,
			"display_name": affix.affix_name,
			"description": affix.description,
			"category": affix.category,
			"category_name": affix.get_category_name(),
			"effect_number": affix.effect_number,
			"source_type": affix.source_type if affix.has_method("get") else "item",
		})
	if affixes_data.size() > 0:
		dict["affixes"] = affixes_data
	
	# Typed affix arrays for systems that need the actual Affix objects
	dict["item_affixes"] = item_affixes.duplicate()
	dict["inherent_affixes"] = inherent_affixes.duplicate()
	dict["rolled_affixes"] = rolled_affixes.duplicate()
	
	# Action
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
	
	# Elemental identity
	var elem_id = get_elemental_identity()
	if elem_id >= 0:
		dict["elemental_identity"] = elem_id
	
	# Visual data
	if equipped_sprite:
		dict["equipped_sprite"] = equipped_sprite
	if spine_skin_name != "":
		dict["spine_skin_name"] = spine_skin_name
	dict["visual_tint"] = visual_tint
	
	return dict
