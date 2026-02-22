# res://scripts/autoload/die_generator.gd
# Generates randomly-rolled DieResource instances with DiceAffixes.
#
# Mirrors EquippableItem's affix rolling pipeline:
#   - Rarity determines dice affix count
#   - Tier gates which DiceAffixTables are available
#   - Item level scales effect_value within min/max ranges
#   - Base die template provides type, element, textures, element_affix
#
# Add as Autoload in Project → Project Settings → Globals:
#   Name: DieGenerator
#   Path: res://scripts/autoload/die_generator.gd
#
# USAGE:
#   var die = DieGenerator.generate(DieResource.DieType.D6,
#       DieResource.Element.FIRE, EquippableItem.Rarity.RARE, 15)
#
#   # Or from an existing template:
#   var die = DieGenerator.generate_from_template(template_die,
#       EquippableItem.Rarity.EPIC, 20)
#
extends Node

# ============================================================================
# CONSTANTS
# ============================================================================

const BASE_DICE_DIR := "res://resources/dice/base/"

## Maps DieType enum → filename prefix
const SIZE_NAMES := {
	DieResource.DieType.D4:  "d4",
	DieResource.DieType.D6:  "d6",
	DieResource.DieType.D8:  "d8",
	DieResource.DieType.D10: "d10",
	DieResource.DieType.D12: "d12",
	DieResource.DieType.D20: "d20",
}

## Maps Element enum → filename suffix
const ELEMENT_NAMES := {
	DieResource.Element.NONE:     "none",
	DieResource.Element.SLASHING: "slashing",
	DieResource.Element.BLUNT:    "blunt",
	DieResource.Element.PIERCING: "piercing",
	DieResource.Element.FIRE:     "fire",
	DieResource.Element.ICE:      "ice",
	DieResource.Element.SHOCK:    "shock",
	DieResource.Element.POISON:   "poison",
	DieResource.Element.SHADOW:   "shadow",
	DieResource.Element.FAITH:    "faith",
}

## Rarity → number of DiceAffixes to roll (excluding inherent/element affixes)
const RARITY_DICE_AFFIX_COUNT := {
	EquippableItem.Rarity.COMMON:    0,
	EquippableItem.Rarity.UNCOMMON:  1,
	EquippableItem.Rarity.RARE:      2,
	EquippableItem.Rarity.EPIC:      2,
	EquippableItem.Rarity.LEGENDARY: 2,  # + unique handled separately
}

## Rarity → which tiers to roll from (mirrors item system logic)
## Rarity → tier escalation (Option A):
## Epic/Legendary drop T1 filler, unlock T3 power.
const RARITY_TIERS := {
	EquippableItem.Rarity.COMMON:    [],
	EquippableItem.Rarity.UNCOMMON:  [1],
	EquippableItem.Rarity.RARE:      [1, 2],
	EquippableItem.Rarity.EPIC:      [2, 3],
	EquippableItem.Rarity.LEGENDARY: [2, 3],
}

## Rarity display names for debug logging
const RARITY_NAMES := {
	EquippableItem.Rarity.COMMON:    "Common",
	EquippableItem.Rarity.UNCOMMON:  "Uncommon",
	EquippableItem.Rarity.RARE:      "Rare",
	EquippableItem.Rarity.EPIC:      "Epic",
	EquippableItem.Rarity.LEGENDARY: "Legendary",
}

# ============================================================================
# CACHE
# ============================================================================

## Cached base die templates: "d6_fire" → DieResource
var _template_cache: Dictionary = {}


# ============================================================================
# PUBLIC API — Primary Generation
# ============================================================================

func generate(die_type: DieResource.DieType, element: DieResource.Element,
		rarity: EquippableItem.Rarity, item_level: int,
		source_name: String = "", region: int = 1) -> DieResource:
	"""Generate a randomly-rolled DieResource.

	This is the main entry point. Creates a die from the base template,
	adds rolled DiceAffixes based on rarity, and scales values by item_level.

	Args:
		die_type: D4, D6, D8, D10, D12, or D20.
		element: Element for the die (NONE for neutral).
		rarity: Determines how many DiceAffixes roll.
		item_level: Scales DiceAffix values (1-100).
		source_name: Display name of the source item (for metadata).
		region: Region number (for future regional table filtering).

	Returns:
		A new DieResource with rolled DiceAffixes, or null on failure.
	"""
	# Step 1: Get base template
	var template := _get_base_template(die_type, element)
	if not template:
		push_error("DieGenerator: No base template for %s_%s" % [
			SIZE_NAMES.get(die_type, "??"), ELEMENT_NAMES.get(element, "??")])
		return null

	return _generate_from_template_internal(template, rarity, item_level, source_name, region)


func generate_from_template(template: DieResource, rarity: EquippableItem.Rarity,
		item_level: int, source_name: String = "", region: int = 1) -> DieResource:
	"""Generate a rolled die from an existing template DieResource.

	Use this when you already have a specific template (e.g., from an
	item's grants_dice array) and want to roll affixes onto it.

	Args:
		template: The base DieResource to copy from.
		rarity: Determines affix count.
		item_level: Scales affix values.
		source_name: Source item name for metadata.
		region: Region number.

	Returns:
		A new DieResource with rolled DiceAffixes.
	"""
	if not template:
		push_error("DieGenerator: Null template provided")
		return null

	return _generate_from_template_internal(template, rarity, item_level, source_name, region)


# ============================================================================
# PUBLIC API — Batch Generation
# ============================================================================

func generate_batch(templates: Array[DieResource], rarity: EquippableItem.Rarity,
		item_level: int, source_name: String = "", region: int = 1) -> Array[DieResource]:
	"""Generate rolled dice for an array of templates.

	Used when an item grants multiple dice (e.g., heavy weapons grant 2).

	Args:
		templates: Array of base DieResources.
		rarity: Applied to all generated dice.
		item_level: Scales all generated dice.
		source_name: Source item name.
		region: Region number.

	Returns:
		Array of generated DieResources (same order as templates).
	"""
	var results: Array[DieResource] = []
	for template in templates:
		if template:
			var die := generate_from_template(template, rarity, item_level, source_name, region)
			if die:
				results.append(die)
	return results


# ============================================================================
# PUBLIC API — Rarity Info
# ============================================================================

func get_affix_count(rarity: EquippableItem.Rarity) -> int:
	"""Get the number of DiceAffixes a die of this rarity receives."""
	return RARITY_DICE_AFFIX_COUNT.get(rarity, 0)


func get_tiers_for_rarity(rarity: EquippableItem.Rarity) -> Array:
	"""Get which tiers to roll from for a given rarity."""
	return RARITY_TIERS.get(rarity, [])


# ============================================================================
# INTERNAL — Core Generation
# ============================================================================

func _generate_from_template_internal(template: DieResource,
		rarity: EquippableItem.Rarity, item_level: int,
		source_name: String, region: int) -> DieResource:
	"""Internal generation logic shared by both public methods."""

	# Step 1: Duplicate the template (deep copy preserves inherent affixes)
	var die: DieResource = template.duplicate_die()

	# Step 2: Stamp metadata
	die.source = source_name if not source_name.is_empty() else "generated"
	if not die.tags.has("rarity:%s" % RARITY_NAMES.get(rarity, "common").to_lower()):
		die.tags.append("rarity:%s" % RARITY_NAMES.get(rarity, "common").to_lower())
	if not die.tags.has("generated"):
		die.tags.append("generated")

	# Step 3: Determine affix count and tiers
	var affix_count: int = get_affix_count(rarity)
	var tiers: Array = get_tiers_for_rarity(rarity)

	if affix_count == 0 or tiers.is_empty():
		# Common die — no rolled affixes, just the base template
		if OS.is_debug_build():
			print("🎲 Generated %s %s (Common — no affixes)" % [
				die.display_name, RARITY_NAMES.get(rarity, "?")])
		return die

	# Step 4: Get the DiceAffixTableRegistry
	var registry := _get_registry()
	if not registry:
		push_warning("DieGenerator: DiceAffixTableRegistry not available — returning base die")
		return die

	# Step 5: Get scaling config
	var scaling_config := _get_scaling_config()

	# Step 6: Roll DiceAffixes
	var rolled_affixes := registry.roll_multiple(
		affix_count, tiers, item_level, die.element, scaling_config)

	# Step 7: Apply rolled affixes to the die's applied_affixes array
	for affix in rolled_affixes:
		affix.source = source_name
		affix.source_type = "item_grant"
		affix.rolled_on_rarity = rarity
		die.applied_affixes.append(affix)

	# Step 8: Update display name to reflect rarity
	if rarity > EquippableItem.Rarity.COMMON:
		die.display_name = "%s %s" % [RARITY_NAMES.get(rarity, ""), die.display_name]

	if OS.is_debug_build():
		print("🎲 Generated %s (Lv.%d, %d affixes):" % [
			die.display_name, item_level, rolled_affixes.size()])
		for affix in rolled_affixes:
			var val_str := affix.get_rolled_value_string() if affix.has_scaling() else str(affix.effect_value)
			print("   🔹 %s: %s [%s]" % [affix.affix_name, val_str,
				affix.get_value_range_string() if affix.has_scaling() else "static"])

	return die


# ============================================================================
# INTERNAL — Template Access
# ============================================================================

func _get_base_template(die_type: DieResource.DieType,
		element: DieResource.Element) -> DieResource:
	"""Load (and cache) a base die template from res://resources/dice/base/."""
	var size_name: String = SIZE_NAMES.get(die_type, "")
	var elem_name: String = ELEMENT_NAMES.get(element, "")

	if size_name.is_empty() or elem_name.is_empty():
		return null

	var cache_key := "%s_%s" % [size_name, elem_name]

	if _template_cache.has(cache_key):
		return _template_cache[cache_key]

	var path := "%s%s_%s.tres" % [BASE_DICE_DIR, size_name, elem_name]
	if ResourceLoader.exists(path):
		var template: DieResource = load(path)
		if template:
			_template_cache[cache_key] = template
			return template

	push_warning("DieGenerator: Base die not found at %s" % path)
	return null


# ============================================================================
# INTERNAL — Registry/Config Access
# ============================================================================

func _get_registry() -> Node:
	"""Get the DiceAffixTableRegistry autoload."""
	return get_node_or_null("/root/DiceAffixTableRegistry")


func _get_scaling_config() -> AffixScalingConfig:
	"""Get the global AffixScalingConfig from AffixTableRegistry."""
	var affix_registry := get_node_or_null("/root/AffixTableRegistry")
	if affix_registry and affix_registry.scaling_config:
		return affix_registry.scaling_config
	return null
