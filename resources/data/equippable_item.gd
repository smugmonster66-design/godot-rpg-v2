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

## Affixes rolled or assigned to this item instance (populated at init time)
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
	  1. Manual affixes (if any manual_*_affix is set)
	  2. SlotDefinition + AffixTableRegistry (new system)
	  3. Legacy table slots (fallback for unmigrated items)
	
	Args:
		affix_pool: Legacy parameter, ignored. Kept for API compatibility.
	"""
	item_affixes.clear()
	
	# Priority 1: Manual affixes
	if manual_first_affix or manual_second_affix or manual_third_affix:
		_use_manual_affixes()
	# Priority 2: New SlotDefinition system
	elif _has_slot_definition_system():
		_roll_from_slot_definition()
	# Priority 3: Legacy table slots
	elif first_affix_table or second_affix_table or third_affix_table:
		_roll_from_tables()
	
	# LEGENDARY: Always add unique affix if present
	if rarity == Rarity.LEGENDARY and unique_affix:
		_add_unique_affix()


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
		
		item_affixes.append(rolled)
		
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
			item_name, item_level, region, get_rarity_name(), item_affixes.size()])


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
	"""Use manually assigned affixes from Inspector."""
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
		item_affixes.append(copy)
		print("  ✓ Using manual affix 1: %s" % manual_first_affix.affix_name)
	
	if manual_second_affix:
		var copy = manual_second_affix.duplicate_with_source(item_name, "item")
		if copy.has_scaling():
			copy.roll_value(power_pos, scaling_config)
		item_affixes.append(copy)
		print("  ✓ Using manual affix 2: %s" % manual_second_affix.affix_name)
	
	if manual_third_affix:
		var copy = manual_third_affix.duplicate_with_source(item_name, "item")
		if copy.has_scaling():
			copy.roll_value(power_pos, scaling_config)
		item_affixes.append(copy)
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
	
	print("✨ Rolled %d affixes for %s (legacy tables)" % [item_affixes.size(), item_name])

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
		item_affixes.append(affix_copy)
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
	
	item_affixes.append(copy)
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
