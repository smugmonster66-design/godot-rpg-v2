# equippable_item.gd - Equipment with inherent stats, rolled affixes, and typed accessors
# v3 — Dictionary bridge fully removed. All downstream reads EquippableItem directly.
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
@export_range(1, 100) var item_level: int = 1

## Base gold value before rarity multiplier.
@export var base_value: int = 10

## Tags for filtering, set bonuses, Cate dialogue, and UI categorization.
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
@export var equipped_sprite: Texture2D = null

## Spine skin name (if using Spine for layered character rendering).
@export var spine_skin_name: String = ""

## Optional tint/color variation applied to the equipped visual.
@export var visual_tint: Color = Color.WHITE

# ============================================================================
# INHERENT AFFIXES — The item's identity stats (always present, never random)
# ============================================================================
@export_group("Inherent Affixes")

## Fixed affixes that define this base item's identity.
## Always active regardless of rarity. NOT rolled randomly.
@export var inherent_affixes: Array[Affix] = []

# ============================================================================
# AFFIX SYSTEM — Rolled affix tables
# ============================================================================
@export_group("Affix Tables")

## Affix tables for each rollable slot. Index 0 = Tier 1, etc.
## Heavy weapons can have up to 6 entries. Standard gear uses 3.
@export var affix_tables: Array[AffixTable] = []

# ============================================================================
# AFFIX SYSTEM — Manual overrides
# ============================================================================
@export_group("Manual Affixes (Override)")

## Manual affix assignment per slot. If any are set, ALL table rolling is skipped.
@export var manual_affixes: Array[Affix] = []

## LEGENDARY ONLY: Unique fourth affix.
@export_subgroup("Legendary Unique Affix")
@export var unique_affix: Affix = null

# ============================================================================
# RUNTIME STATE — Not saved to .tres
# ============================================================================

## Rolled/manual affixes (NOT including inherent).
var rolled_affixes: Array[Affix] = []

## Combined view: inherent + rolled + unique. Rebuilt by initialize_affixes().
var item_affixes: Array[Affix] = []

## Runtime dice — starts as copies of grants_dice, but may be modified
## by dice affixes during combat prep. Snapshot/restore cycle lives here.
var runtime_dice: Array[DieResource] = []

## Whether runtime_dice have been modified from the template.
var _dice_modified: bool = false

# ============================================================================
# DICE
# ============================================================================
@export_group("Dice")

## Dice templates this item grants. Runtime copies live in runtime_dice.
@export var grants_dice: Array[DieResource] = []
@export var dice_tags: Array[String] = []

# ============================================================================
# COMBAT ACTION
# ============================================================================
@export_group("Combat Action")
@export var grants_action: bool = false
@export var action: Action = null

# ============================================================================
# AFFIX MANAGEMENT
# ============================================================================

func initialize_affixes(_affix_pool = null):
	"""Initialize all affixes: inherent + rolled/manual + unique.
	Also creates fresh runtime dice from templates.
	"""
	rolled_affixes.clear()
	item_affixes.clear()
	
	# Step 1: Always apply inherent affixes
	_apply_inherent_affixes()
	
	# Step 2: Roll or manually assign random affixes
	if manual_affixes.size() > 0:
		_use_manual_affixes()
	else:
		_roll_from_tables()
	
	# Step 3: Add legendary unique affix
	if rarity == Rarity.LEGENDARY and unique_affix:
		_add_unique_affix()
	
	# Step 4: Build combined list
	_rebuild_combined_affixes()
	
	# Step 5: Create fresh runtime dice from templates
	reset_dice_to_base()

func _apply_inherent_affixes():
	"""Copy inherent affixes with source tracking. No rolling."""
	for affix in inherent_affixes:
		if affix:
			var copy = affix.duplicate_with_source(item_name, "item_inherent")
			item_affixes.append(copy)
			print("  📌 Inherent: %s" % affix.affix_name)

func _use_manual_affixes():
	"""Use manually assigned affixes and roll their values."""
	for affix in manual_affixes:
		if affix:
			var copy = affix.duplicate_with_source(item_name, "item")
			copy.roll_value()
			rolled_affixes.append(copy)
			print("  ✓ Manual: %s (%.1f)" % [affix.affix_name, copy.effect_number])

func _roll_from_tables():
	"""Roll random affixes from affix_tables array."""
	var num_affixes = get_affix_count_for_rarity()
	
	for i in range(mini(num_affixes, affix_tables.size())):
		_roll_from_table(affix_tables[i], i + 1)
	
	print("✨ Rolled %d affixes for %s (%s)" % [rolled_affixes.size(), item_name, get_rarity_name()])

func _roll_from_table(table: AffixTable, slot_number: int):
	"""Roll one affix from a specific table and roll its value."""
	if not table or not table.is_valid():
		print("  ⚠️ Table slot %d null/empty for %s" % [slot_number, item_name])
		return
	
	var affix = table.get_random_affix()
	if affix:
		var copy = affix.duplicate_with_source(item_name, "item")
		copy.roll_value()
		rolled_affixes.append(copy)
		print("  🎲 Slot %d: %s = %.1f" % [slot_number, affix.affix_name, copy.effect_number])
	else:
		print("  ❌ Failed to roll from table slot %d" % slot_number)

func _add_unique_affix():
	"""Add the unique legendary affix."""
	if not unique_affix:
		return
	var copy = unique_affix.duplicate_with_source(item_name, "item_unique")
	copy.roll_value()
	rolled_affixes.append(copy)
	print("  ⭐ Unique: %s (%.1f)" % [unique_affix.affix_name, copy.effect_number])

func _rebuild_combined_affixes():
	"""Rebuild item_affixes = inherent (copied) + rolled."""
	item_affixes.clear()
	for affix in inherent_affixes:
		if affix:
			var copy = affix.duplicate_with_source(item_name, "item_inherent")
			item_affixes.append(copy)
	item_affixes.append_array(rolled_affixes)

func get_affix_count_for_rarity() -> int:
	"""Number of rolled affixes by rarity. Heavy weapons get double."""
	var base_count: int
	match rarity:
		Rarity.COMMON: base_count = 0
		Rarity.UNCOMMON: base_count = 1
		Rarity.RARE: base_count = 2
		Rarity.EPIC: base_count = 3
		Rarity.LEGENDARY: base_count = 3
		_: base_count = 0
	if is_heavy_weapon():
		base_count *= 2
	return base_count

func get_all_affixes() -> Array[Affix]:
	"""All affixes (inherent + rolled + unique)."""
	return item_affixes.duplicate()

func get_inherent_affixes() -> Array[Affix]:
	"""Only the inherent (non-random) affixes."""
	return inherent_affixes.duplicate()

func get_rolled_affixes() -> Array[Affix]:
	"""Only the rolled/manual affixes."""
	return rolled_affixes.duplicate()

# ============================================================================
# DICE MANAGEMENT
# ============================================================================

func reset_dice_to_base():
	"""Create fresh runtime dice from templates."""
	runtime_dice.clear()
	for die in grants_dice:
		if die:
			runtime_dice.append(die.duplicate_die())
	_dice_modified = false

func get_runtime_dice() -> Array[DieResource]:
	"""Get the current runtime dice (may have modifications)."""
	return runtime_dice

func snapshot_dice(modified: Array[DieResource]):
	"""Save modified dice back from the pool. Called on unequip."""
	runtime_dice.clear()
	for die in modified:
		runtime_dice.append(die.duplicate_die())
	_dice_modified = true

func are_dice_modified() -> bool:
	return _dice_modified

# ============================================================================
# EQUIP REQUIREMENTS
# ============================================================================

func can_equip(player) -> bool:
	"""Check if the player meets all equip requirements."""
	if not player:
		return false
	if required_level > 0:
		var player_level = player.get("level") if player.get("level") != null else 0
		if player_level < required_level:
			return false
	if required_strength > 0 and player.get_base_stat("strength") < required_strength:
		return false
	if required_agility > 0 and player.get_base_stat("agility") < required_agility:
		return false
	if required_intellect > 0 and player.get_base_stat("intellect") < required_intellect:
		return false
	return true

func get_unmet_requirements(player) -> Array[String]:
	"""Human-readable list of unmet requirements."""
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
	var multiplier = RARITY_VALUE_MULTIPLIER.get(rarity, 1.0)
	var region_scale = 1.0 + (region - 1) * 0.5
	return int(base_value * multiplier * region_scale)

func get_buy_value() -> int:
	return get_sell_value() * 3

# ============================================================================
# ELEMENTAL IDENTITY
# ============================================================================

func get_elemental_identity() -> int:
	"""Returns DamageType int, or -1 if none."""
	if has_elemental_identity:
		return elemental_identity
	for affix in item_affixes:
		if affix and affix.has_elemental_identity:
			return affix.elemental_identity
	return -1

# ============================================================================
# TAGS
# ============================================================================

func has_tag(tag: String) -> bool:
	return tag in item_tags

func has_any_tag(tags: Array[String]) -> bool:
	for tag in tags:
		if tag in item_tags:
			return true
	return false

func has_all_tags(tags: Array[String]) -> bool:
	for tag in tags:
		if tag not in item_tags:
			return false
	return true

# ============================================================================
# UTILITY
# ============================================================================

func is_heavy_weapon() -> bool:
	return equip_slot == EquipSlot.HEAVY

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.BLUE
		Rarity.EPIC: return Color.PURPLE
		Rarity.LEGENDARY: return Color.ORANGE
		_: return Color.WHITE

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
		_: return "Unknown"

func get_slot_name() -> String:
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
	return item_name

func get_tooltip_lines() -> Array[String]:
	"""Pre-built tooltip content in display order."""
	var lines: Array[String] = []
	lines.append(item_name)
	lines.append("%s %s" % [get_rarity_name(), get_slot_name()])
	if item_level > 0:
		lines.append("Item Level %d (Region %d)" % [item_level, region])
	
	var reqs: Array[String] = []
	if required_level > 0: reqs.append("Level %d" % required_level)
	if required_strength > 0: reqs.append("%d STR" % required_strength)
	if required_agility > 0: reqs.append("%d AGI" % required_agility)
	if required_intellect > 0: reqs.append("%d INT" % required_intellect)
	if reqs.size() > 0:
		lines.append("Requires: %s" % ", ".join(reqs))
	
	lines.append("---")
	for affix in inherent_affixes:
		if affix:
			lines.append(affix.get_display_text())
	
	if rolled_affixes.size() > 0:
		lines.append("---")
		for affix in rolled_affixes:
			lines.append(affix.get_display_text())
	
	if set_definition:
		lines.append("---")
		lines.append("Set: %s" % set_definition.set_name)
	
	if flavor_text != "":
		lines.append("---")
		lines.append(flavor_text)
	
	lines.append("Sell: %d gold" % get_sell_value())
	return lines

# ============================================================================
# BACKWARD COMPATIBILITY — Legacy callers
# ============================================================================

func roll_affixes(_affix_pool = null):
	"""DEPRECATED — Use initialize_affixes()."""
	push_warning("roll_affixes() is deprecated. Use initialize_affixes().")
	initialize_affixes()
