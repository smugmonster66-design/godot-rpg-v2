@tool
# equippable_item.gd - Equipment with SlotDefinition-driven affix rolling and level scaling
#
# @tool is required so the equip_slot setter can auto-resolve SlotDefinitions
# in the Inspector. All runtime logic is guarded — @tool only affects the setter.
#
# v2 CHANGELOG (Item Level Scaling):
#   - Added SlotDefinition reference for family-based affix table access
#   - Added item_level / region fields wired to affix value generation
#   - initialize_affixes() now uses AffixTableRegistry + scaling when available
#   - Manual affix overrides preserved (backwards compatible)
#   - Legacy table slots preserved as fallback (backwards compatible)
#   - Unique legendary affix system preserved
#   - to_dict() now includes item_level, region, value_display, value_range
#
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
@export var equip_slot: EquipSlot = EquipSlot.MAIN_HAND:
	set(value):
		equip_slot = value
		if Engine.is_editor_hint():
			_auto_resolve_slot_definition()
@export var set_definition: SetDefinition = null

## Optional element for this item. Flows to action fields as their element.
@export var has_elemental_identity: bool = false
@export var elemental_identity: ActionEffect.DamageType = ActionEffect.DamageType.SLASHING

# ============================================================================
# SLOT DEFINITION — Controls which affix families this item can roll
# ============================================================================
@export_group("Slot Configuration")

## The slot definition that controls affix family access and base stats.
## Drag a SlotDefinition .tres here, or leave null to auto-resolve from equip_slot.
@export var slot_definition: SlotDefinition = null

# ============================================================================
# ITEM LEVEL & REGION — Drives affix value scaling
# ============================================================================
@export_group("Item Level")

## This item's power level. Determines where affix values land within
## their effect_min → effect_max ranges. Set by the loot system at drop time.
## Range: 1 (weakest, region 1 start) to 100 (strongest, region 6 endgame).
@export_range(1, 100) var item_level: int = 1

## Which region this item dropped in. Informational + used for loot filtering.
@export_range(1, 6) var region: int = 1

# ============================================================================
# AFFIX SYSTEM - TABLES (legacy — kept for backwards compatibility)
# ============================================================================
@export_group("Affix Tables (Legacy)")

## @deprecated Use slot_definition instead. These are preserved for migration.
@export var first_affix_table: AffixTable = null
@export var second_affix_table: AffixTable = null
@export var third_affix_table: AffixTable = null

# ============================================================================
# AFFIX SYSTEM - MANUAL OVERRIDE
# ============================================================================
@export_group("Manual Affixes (Override)")

## Manual affix assignment (optional — overrides table rolling).
## Leave these empty to use the SlotDefinition-based table rolling.
@export var manual_first_affix: Affix = null
@export var manual_second_affix: Affix = null
@export var manual_third_affix: Affix = null

## LEGENDARY ONLY: Fourth unique affix (always added regardless of roll system)
@export_subgroup("Legendary Unique Affix")
@export var unique_affix: Affix = null

## Affixes rolled or assigned to this item instance (populated at init time).
## This is the COMBINED array used by combat, player stats, etc.
var item_affixes: Array[Affix] = []

## Inherent affixes — baked into the item template (from manual affix slots).
## These define the item's identity (e.g. "Venom Dagger always has poison").
## Displayed green-tinted in the inventory detail panel.
var inherent_affixes: Array[Affix] = []

## Rolled affixes — generated at item creation from affix tables.
## These are the random bonuses that add variety between drops.
## Displayed gold-tinted in the inventory detail panel.
var rolled_affixes: Array[Affix] = []

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
# EQUIP REQUIREMENTS
# ============================================================================
@export_group("Requirements")

## Minimum player level to equip this item. 0 = no requirement.
@export_range(0, 100) var required_level: int = 0

## Minimum Strength to equip. 0 = no requirement.
@export_range(0, 999) var required_strength: int = 0

## Minimum Agility to equip. 0 = no requirement.
@export_range(0, 999) var required_agility: int = 0

## Minimum Intellect to equip. 0 = no requirement.
@export_range(0, 999) var required_intellect: int = 0

# ============================================================================
# ECONOMY
# ============================================================================
@export_group("Economy")

## Base gold value before rarity/level multipliers.
@export_range(0, 9999) var base_value: int = 10

# ============================================================================
# ELEMENTAL IDENTITY
# ============================================================================

func get_elemental_identity() -> int:
	"""Find the elemental identity — item-level first, then affixes.
	Returns the DamageType int, or -1 if none is set."""
	if has_elemental_identity:
		return elemental_identity
	for affix in item_affixes:
		if affix and affix.has_elemental_identity:
			return affix.elemental_identity
	return -1

# ============================================================================
# AFFIX MANAGEMENT
# ============================================================================

func initialize_affixes(affix_pool = null):
	"""Initialize affixes using the best available system.
	
	Priority order:
	  1. Manual affixes (if any manual_*_affix is set) → inherent_affixes
	  2. SlotDefinition + AffixTableRegistry (new system) → rolled_affixes
	  3. Legacy table slots (fallback for unmigrated items) → rolled_affixes
	
	Args:
		affix_pool: Legacy parameter, ignored. Kept for API compatibility.
	"""
	item_affixes.clear()
	inherent_affixes.clear()
	rolled_affixes.clear()
	
	# Priority 1: Manual affixes → inherent
	if manual_first_affix or manual_second_affix or manual_third_affix:
		_use_manual_affixes()
	
	# Priority 2: New SlotDefinition system → rolled
	if _has_slot_definition_system():
		_roll_from_slot_definition()
	# Priority 3: Legacy table slots → rolled
	elif first_affix_table or second_affix_table or third_affix_table:
		_roll_from_tables()
	
	# LEGENDARY: Always add unique affix if present
	if rarity == Rarity.LEGENDARY and unique_affix:
		_add_unique_affix()
	
	# Combine into item_affixes for backwards compatibility
	_rebuild_combined_affixes()


func _has_slot_definition_system() -> bool:
	"""Check if the new SlotDefinition system is available."""
	if slot_definition:
		return true
	return _get_slot_definition() != null


func _get_slot_definition() -> SlotDefinition:
	"""Get the SlotDefinition for this item, auto-resolving if needed."""
	if slot_definition:
		return slot_definition
	
	# Auto-resolve: try loading from the standard path
	var slot_file := _slot_to_filename(equip_slot)
	var path := "res://resources/slot_definitions/%s.tres" % slot_file
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is SlotDefinition:
			return loaded
	
	return null


func _slot_to_filename(slot: EquipSlot) -> String:
	"""Map EquipSlot enum to SlotDefinition filename."""
	match slot:
		EquipSlot.HEAD: return "head_slot"
		EquipSlot.TORSO: return "torso_slot"
		EquipSlot.GLOVES: return "gloves_slot"
		EquipSlot.BOOTS: return "boots_slot"
		EquipSlot.MAIN_HAND: return "main_hand_slot"
		EquipSlot.OFF_HAND: return "off_hand_slot"
		EquipSlot.HEAVY: return "heavy_slot"
		EquipSlot.ACCESSORY: return "accessory_slot"
		_: return "main_hand_slot"


func _auto_resolve_slot_definition() -> void:
	"""Auto-populate slot_definition when equip_slot changes in the Inspector.
	Only runs in the editor. Skips if a SlotDefinition is already manually assigned."""
	var slot_file := _slot_to_filename(equip_slot)
	var path := "res://resources/slot_definitions/%s.tres" % slot_file
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is SlotDefinition:
			slot_definition = loaded
			notify_property_list_changed()

# ============================================================================
# NEW ROLLING SYSTEM (SlotDefinition + AffixTableRegistry)
# ============================================================================

func _roll_from_slot_definition() -> void:
	"""Roll affixes using SlotDefinition + AffixTableRegistry.
	
	Rarity determines how many tiers are rolled:
	  COMMON:    0 affixes
	  UNCOMMON:  1 roll from tier 1
	  RARE:      1 from tier 1 + 1 from tier 2
	  EPIC:      1 from tier 1 + 1 from tier 2 + 1 from tier 3
	  LEGENDARY: same as EPIC (+ unique affix added separately)
	
	Heavy weapons with double_affix_rolls get 2× the rolls.
	"""
	var sd: SlotDefinition = _get_slot_definition()
	if not sd:
		push_warning("EquippableItem '%s': No SlotDefinition found — skipping roll" % item_name)
		return
	
	var registry = _get_registry()
	if not registry:
		push_warning("EquippableItem '%s': AffixTableRegistry not available — skipping roll" % item_name)
		return
	
	var scaling_config: AffixScalingConfig = registry.scaling_config
	var power_pos: float = 0.0
	if scaling_config:
		power_pos = scaling_config.get_power_position(item_level)
	else:
		power_pos = clampf(float(item_level - 1) / 99.0, 0.0, 1.0)
	
	# Determine roll count per tier based on rarity
	var tiers_to_roll: Array[int] = _get_tiers_for_rarity()
	
	# Double for heavy weapons
	if sd.double_affix_rolls:
		var doubled: Array[int] = []
		for t in tiers_to_roll:
			doubled.append(t)
			doubled.append(t)
		tiers_to_roll = doubled
	
	# Roll each tier
	for tier in tiers_to_roll:
		var tables: Array[AffixTable] = sd.get_tables_for_tier(tier, registry.table_registry)
		if tables.is_empty():
			if OS.is_debug_build():
				print("  ⚠️ No tables for %s tier %d (families: %s)" % [
					sd.slot_name, tier, sd.get_tier_families(tier)])
			continue
		
		var table: AffixTable = tables.pick_random()
		if not table or not table.is_valid():
			continue
		
		var base_affix: Affix = table.get_random_affix()
		if not base_affix:
			continue
		
		var rolled: Affix = base_affix.duplicate_with_source(item_name, "item")
		
		if rolled.has_scaling():
			rolled.roll_value(power_pos, scaling_config)
		
		rolled_affixes.append(rolled)
		
		if OS.is_debug_build():
			var val_str := rolled.get_rolled_value_string() if rolled.has_scaling() else str(rolled.effect_number)
			print("  🎲 T%d %s: %s %s (from %s)" % [
				tier,
				rolled.affix_name,
				val_str,
				"[%s]" % rolled.get_value_range_string() if rolled.has_scaling() else "",
				table.table_name
			])
	
	if OS.is_debug_build():
		print("✨ %s (Lv.%d, R%d, %s) rolled %d affixes via SlotDefinition" % [
			item_name, item_level, region, get_rarity_name(), rolled_affixes.size()])


func _get_tiers_for_rarity() -> Array[int]:
	"""Map rarity to which tiers get rolled."""
	match rarity:
		Rarity.COMMON:
			return []
		Rarity.UNCOMMON:
			return [1]
		Rarity.RARE:
			return [1, 2]
		Rarity.EPIC, Rarity.LEGENDARY:
			return [1, 2, 3]
		_:
			return []


func _get_registry():
	"""Get the AffixTableRegistry autoload. Returns null if not available."""
	if Engine.has_singleton("AffixTableRegistry"):
		return Engine.get_singleton("AffixTableRegistry")
	
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var root = tree.root
		if root and root.has_node("AffixTableRegistry"):
			return root.get_node("AffixTableRegistry")
	
	return null

# ============================================================================
# MANUAL AFFIXES
# ============================================================================

func _use_manual_affixes():
	"""Use manually assigned affixes from Inspector → inherent_affixes."""
	var scaling_config: AffixScalingConfig = null
	var power_pos: float = clampf(float(item_level - 1) / 99.0, 0.0, 1.0)
	
	var registry = _get_registry()
	if registry and registry.scaling_config:
		scaling_config = registry.scaling_config
		power_pos = scaling_config.get_power_position(item_level)
	
	if manual_first_affix:
		var copy = manual_first_affix.duplicate_with_source(item_name, "item")
		if copy.has_scaling():
			copy.roll_value(power_pos, scaling_config)
		inherent_affixes.append(copy)
		print("  ✓ Using manual affix 1: %s" % manual_first_affix.affix_name)
	
	if manual_second_affix:
		var copy = manual_second_affix.duplicate_with_source(item_name, "item")
		if copy.has_scaling():
			copy.roll_value(power_pos, scaling_config)
		inherent_affixes.append(copy)
		print("  ✓ Using manual affix 2: %s" % manual_second_affix.affix_name)
	
	if manual_third_affix:
		var copy = manual_third_affix.duplicate_with_source(item_name, "item")
		if copy.has_scaling():
			copy.roll_value(power_pos, scaling_config)
		inherent_affixes.append(copy)
		print("  ✓ Using manual affix 3: %s" % manual_third_affix.affix_name)

# ============================================================================
# LEGACY TABLE ROLLING (fallback for unmigrated items)
# ============================================================================

func _roll_from_tables():
	"""Roll random affixes from assigned affix tables (legacy system).
	
	Rarity determines which tables to roll from:
	- COMMON: No affixes
	- UNCOMMON: Roll 1 from first_affix_table
	- RARE: Roll 1 from first + second
	- EPIC: Roll from all three tables
	- LEGENDARY: Roll from all three + unique affix
	"""
	var num_affixes = get_affix_count_for_rarity()
	
	if num_affixes >= 1:
		_roll_from_table(first_affix_table, "First")
	
	if num_affixes >= 2:
		_roll_from_table(second_affix_table, "Second")
	
	if num_affixes >= 3:
		_roll_from_table(third_affix_table, "Third")
	
	print("✨ Rolled %d affixes for %s (legacy tables)" % [rolled_affixes.size(), item_name])

func _roll_from_table(table: AffixTable, tier_name: String):
	"""Roll one affix from a specific affix table (legacy)"""
	if not table:
		print("  ⚠️ No %s affix table assigned for %s" % [tier_name, item_name])
		return
	
	if not table.is_valid():
		print("  ⚠️ %s affix table is empty for %s" % [tier_name, item_name])
		return
	
	var affix = table.get_random_affix()
	if affix:
		var affix_copy = affix.duplicate_with_source(item_name, "item")
		rolled_affixes.append(affix_copy)
		print("  🎲 Rolled %s affix: %s (from table: %s)" % [tier_name, affix.affix_name, table.table_name])
	else:
		print("  ❌ Failed to roll from %s table" % tier_name)

# ============================================================================
# UNIQUE LEGENDARY AFFIX
# ============================================================================

func _add_unique_affix():
	"""Add the unique legendary affix (4th affix)"""
	if not unique_affix:
		print("  ⚠️ LEGENDARY item missing unique affix!")
		return
	
	var copy = unique_affix.duplicate_with_source(item_name, "item")
	
	# Scale unique affix too if it has ranges
	if copy.has_scaling():
		var power_pos := clampf(float(item_level - 1) / 99.0, 0.0, 1.0)
		var registry = _get_registry()
		if registry and registry.scaling_config:
			power_pos = registry.scaling_config.get_power_position(item_level)
			copy.roll_value(power_pos, registry.scaling_config)
		else:
			copy.roll_value(power_pos)
	
	rolled_affixes.append(copy)
	print("  ⭐ Added UNIQUE affix: %s" % unique_affix.affix_name)

# ============================================================================
# RARITY HELPERS
# ============================================================================

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

func _rebuild_combined_affixes() -> void:
	"""Merge inherent + rolled into item_affixes for backwards compatibility."""
	item_affixes.clear()
	for a in inherent_affixes:
		item_affixes.append(a)
	for a in rolled_affixes:
		item_affixes.append(a)

# ============================================================================
# EQUIP REQUIREMENT CHECKS
# ============================================================================

func has_requirements() -> bool:
	"""Returns true if this item has any equip requirements."""
	return required_level > 0 or required_strength > 0 \
		or required_agility > 0 or required_intellect > 0

func can_equip(player) -> bool:
	"""Check if a player meets all equip requirements.
	Accepts any object with level / get_total_stat() (Player resource)."""
	if not player:
		return true
	if required_level > 0 and player.level < required_level:
		return false
	if required_strength > 0 and player.get_total_stat("strength") < required_strength:
		return false
	if required_agility > 0 and player.get_total_stat("agility") < required_agility:
		return false
	if required_intellect > 0 and player.get_total_stat("intellect") < required_intellect:
		return false
	return true

func get_unmet_requirements(player) -> Array[String]:
	"""Return human-readable strings for each unmet requirement."""
	var unmet: Array[String] = []
	if not player:
		return unmet
	if required_level > 0 and player.level < required_level:
		unmet.append("Requires Level %d (you: %d)" % [required_level, player.level])
	if required_strength > 0 and player.get_total_stat("strength") < required_strength:
		unmet.append("Requires %d Strength (you: %d)" % [required_strength, player.get_total_stat("strength")])
	if required_agility > 0 and player.get_total_stat("agility") < required_agility:
		unmet.append("Requires %d Agility (you: %d)" % [required_agility, player.get_total_stat("agility")])
	if required_intellect > 0 and player.get_total_stat("intellect") < required_intellect:
		unmet.append("Requires %d Intellect (you: %d)" % [required_intellect, player.get_total_stat("intellect")])
	return unmet

# ============================================================================
# ECONOMY
# ============================================================================

func get_sell_value() -> int:
	"""Calculate sell value based on base_value, rarity, and item level."""
	var rarity_mult := 1.0
	match rarity:
		Rarity.COMMON: rarity_mult = 1.0
		Rarity.UNCOMMON: rarity_mult = 1.5
		Rarity.RARE: rarity_mult = 2.5
		Rarity.EPIC: rarity_mult = 4.0
		Rarity.LEGENDARY: rarity_mult = 7.0
	
	# Level scaling: linear 1× at Lv.1 → 3× at Lv.100
	var level_mult := 1.0 + (float(item_level - 1) / 99.0) * 2.0
	
	return maxi(1, roundi(base_value * rarity_mult * level_mult))

# ============================================================================
# BACKWARD COMPATIBILITY
# ============================================================================

func roll_affixes(affix_pool = null):
	"""Legacy function - calls initialize_affixes for compatibility"""
	initialize_affixes(affix_pool)

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
# CONVERSION FOR UI/INVENTORY
# ============================================================================

func to_dict() -> Dictionary:
	"""DEPRECATED (v3): No longer needed. Equipment pipeline uses
	EquippableItem Resources directly. This method will be removed
	in a future version. If you see the warning below, update the
	caller to use EquippableItem properties directly."""
	push_warning("EquippableItem.to_dict() is deprecated — caller should use EquippableItem directly: %s" % item_name)
	var dict = {
		"name": item_name,
		"display_name": item_name,
		"slot": get_slot_name(),
		"description": description,
		"dice_resources": [],
		"dice_tags": dice_tags.duplicate(),
		"is_heavy": is_heavy_weapon(),
		"icon": icon,
		"rarity": get_rarity_name(),
		"item_level": item_level,
		"region": region,
		"equippable_item": self,
	}
	
	# Add dice resources (actual DieResource copies)
	for die in grants_dice:
		if die:
			dict["dice_resources"].append(die.duplicate_die())
	
	# Add affixes as dictionaries for UI display
	var affixes_data = []
	for affix in item_affixes:
		var affix_dict := {
			"name": affix.affix_name,
			"display_name": affix.affix_name,
			"description": affix.description,
			"category": affix.category,
			"category_name": affix.get_category_name(),
			"effect_number": affix.effect_number,
		}
		if affix.has_scaling():
			affix_dict["value_display"] = affix.get_rolled_value_string()
			affix_dict["value_range"] = affix.get_value_range_string()
		affixes_data.append(affix_dict)
	
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

# Add these to equippable_item.gd

# ============================================================================
# DICE PERSISTENCE
# ============================================================================

## Runtime dice — starts as grants_dice copies, gets overwritten with
## modified versions when unequipped to preserve player-applied affixes.
var _runtime_dice: Array[DieResource] = []
var _dice_modified: bool = false

func get_runtime_dice() -> Array[DieResource]:
	"""Return modified dice if they exist, otherwise base templates."""
	if _dice_modified and _runtime_dice.size() > 0:
		return _runtime_dice
	return grants_dice

func are_dice_modified() -> bool:
	return _dice_modified

func store_modified_dice(dice: Array[DieResource]):
	"""Snapshot modified dice back onto this item (called on unequip)."""
	_runtime_dice.clear()
	for die in dice:
		if die:
			_runtime_dice.append(die.duplicate_die())
	_dice_modified = true

func reset_dice_to_base():
	"""Clear modifications, revert to grants_dice templates."""
	_runtime_dice.clear()
	_dice_modified = false
