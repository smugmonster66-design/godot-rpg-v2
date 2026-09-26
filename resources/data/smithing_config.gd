# res://resources/data/smithing_config.gd
# Central configuration for the Smithing system (Salvage + Upgrade).
# All costs and yields are inspector-editable.
extends Resource
class_name SmithingConfig

# ============================================================================
# COMPONENT DEFINITIONS
# ============================================================================

## All crafting component types, ordered by rarity tier (0=Common → 4=Legendary).
## Used by the smithing UI to look up icons and display names.
@export var components: Array[CraftingComponentDefinition] = []

# ============================================================================
# SALVAGE YIELDS
# ============================================================================

## Salvage yields indexed by EquippableItem.Rarity (0=Common → 4=Legendary).
## Each entry maps component_id (StringName) → amount (int).
## Example: Rare item yields {"common": 5, "uncommon": 3, "rare": 1}
@export var salvage_common: Dictionary = {&"common": 3}
@export var salvage_uncommon: Dictionary = {&"common": 5, &"uncommon": 2}
@export var salvage_rare: Dictionary = {&"common": 8, &"uncommon": 4, &"rare": 1}
@export var salvage_epic: Dictionary = {&"common": 10, &"uncommon": 6, &"rare": 3, &"epic": 1}
@export var salvage_legendary: Dictionary = {&"common": 12, &"uncommon": 8, &"rare": 4, &"epic": 2, &"legendary": 1}

# ============================================================================
# UPGRADE BASE COST
# ============================================================================

## Base upgrade cost indexed by rarity. Same Dictionary structure as salvage.
@export var upgrade_cost_common: Dictionary = {&"common": 5}
@export var upgrade_cost_uncommon: Dictionary = {&"common": 8, &"uncommon": 3}
@export var upgrade_cost_rare: Dictionary = {&"common": 12, &"uncommon": 6, &"rare": 2}
@export var upgrade_cost_epic: Dictionary = {&"common": 15, &"uncommon": 8, &"rare": 4, &"epic": 1}
@export var upgrade_cost_legendary: Dictionary = {&"common": 20, &"uncommon": 12, &"rare": 6, &"epic": 3, &"legendary": 1}

# ============================================================================
# LOCK COST PER AFFIX
# ============================================================================

## Additional cost per locked affix, indexed by rarity.
@export var lock_cost_common: Dictionary = {&"common": 2}
@export var lock_cost_uncommon: Dictionary = {&"common": 3, &"uncommon": 1}
@export var lock_cost_rare: Dictionary = {&"common": 5, &"uncommon": 2, &"rare": 1}
@export var lock_cost_epic: Dictionary = {&"common": 6, &"uncommon": 3, &"rare": 2, &"epic": 1}
@export var lock_cost_legendary: Dictionary = {&"common": 8, &"uncommon": 5, &"rare": 3, &"epic": 2}

# ============================================================================
# HELPERS
# ============================================================================

func get_salvage_yield(rarity: int) -> Dictionary:
	match rarity:
		0: return salvage_common
		1: return salvage_uncommon
		2: return salvage_rare
		3: return salvage_epic
		4: return salvage_legendary
		_: return salvage_common

func get_upgrade_base_cost(rarity: int) -> Dictionary:
	match rarity:
		0: return upgrade_cost_common
		1: return upgrade_cost_uncommon
		2: return upgrade_cost_rare
		3: return upgrade_cost_epic
		4: return upgrade_cost_legendary
		_: return upgrade_cost_common

func get_lock_cost_per_affix(rarity: int) -> Dictionary:
	match rarity:
		0: return lock_cost_common
		1: return lock_cost_uncommon
		2: return lock_cost_rare
		3: return lock_cost_epic
		4: return lock_cost_legendary
		_: return lock_cost_common

func get_total_upgrade_cost(rarity: int, locked_count: int) -> Dictionary:
	"""Calculate total upgrade cost: base + (lock_cost × locked_count)."""
	var base = get_upgrade_base_cost(rarity).duplicate()
	if locked_count > 0:
		var lock_cost = get_lock_cost_per_affix(rarity)
		for comp_id in lock_cost:
			var current = base.get(comp_id, 0)
			base[comp_id] = current + lock_cost[comp_id] * locked_count
	return base

func get_component_by_id(component_id: StringName) -> CraftingComponentDefinition:
	for comp in components:
		if comp and comp.component_id == component_id:
			return comp
	return null
