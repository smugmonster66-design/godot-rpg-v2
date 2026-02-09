# loot_manager.gd - Manages loot generation from loot tables
#
# v2 CHANGELOG (Item Level Scaling):
#   - roll_loot() now accepts source_level and source_region
#   - _process_item_drop() stamps item_level and region before affix rolling
#   - Added generate_drop() for one-shot item creation outside loot tables
#   - Added roll_loot_from_enemy() convenience wrapper
#   - Added get_item_level_for_region() helper
#   - All existing callers continue working (new params have defaults)
#
extends Node

# All loaded loot tables indexed by name
var loot_tables: Dictionary = {}

# ============================================================================
# ITEM LEVEL SCALING CONFIG
# ============================================================================

## How many levels above/below source the item can roll.
## source_level=20, spread=3 → item_level ranges 17–23.
@export var item_level_spread: int = 3

## Cached reference to the scaling config (auto-loaded from registry).
var _scaling_config: AffixScalingConfig = null

func _get_scaling_config() -> AffixScalingConfig:
	if _scaling_config:
		return _scaling_config
	if has_node("/root/AffixTableRegistry"):
		var registry = get_node("/root/AffixTableRegistry")
		if registry and registry.scaling_config:
			_scaling_config = registry.scaling_config
	return _scaling_config

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("💰 Loot Manager initializing...")
	_load_all_loot_tables()
	print("💰 Loot Manager ready - loaded %d loot tables" % loot_tables.size())

func _load_all_loot_tables():
	"""Automatically load all .tres loot tables from directory"""
	_load_tables_from_directory("res://resources/loot_tables/enemies/", "Enemies")
	_load_tables_from_directory("res://resources/loot_tables/containers/", "Containers")
	_load_tables_from_directory("res://resources/loot_tables/zones/", "Zones")
	_load_tables_from_directory("res://resources/loot_tables/special/", "Special")

func _load_tables_from_directory(dir_path: String, category_name: String):
	"""Load all loot table .tres files from a directory"""
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		# Silently skip missing directories
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var loaded_count = 0
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = dir_path + file_name
			var table = load(full_path)
			
			if table and table is LootTable:
				loot_tables[table.table_name] = table
				loaded_count += 1
				print("    ✓ %s: %s" % [category_name, table.table_name])
			else:
				print("    ✗ Failed to load: %s" % file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if loaded_count > 0:
		print("  📦 %s: %d tables" % [category_name, loaded_count])

# ============================================================================
# PUBLIC API - ROLL LOOT
# ============================================================================

func roll_loot(table_name: String, modifiers: Dictionary = {},
			   source_level: int = -1, source_region: int = -1) -> Array[Dictionary]:
	"""Roll loot from a loot table
	
	Args:
		table_name: Name of the loot table to roll
		modifiers: Optional modifiers (luck, magic_find, etc.)
		source_level: Level of the drop source (flows to item_level). -1 = don't stamp.
		source_region: Region of the drop source (1–6). -1 = don't stamp.
	
	Returns:
		Array of loot results: [{item: {}, quantity: 1, source: ""}]
	"""
	var table = loot_tables.get(table_name, null)
	
	if not table:
		print("⚠️ Loot table '%s' not found!" % table_name)
		return []
	
	var results: Array[Dictionary] = []
	
	# Roll guaranteed drops
	results.append_array(_roll_guaranteed_pool(table, source_level, source_region))
	
	# Roll weighted drops
	results.append_array(_roll_weighted_pool(table, source_level, source_region))
	
	# Roll bonus drops (with luck modifier)
	results.append_array(_roll_bonus_pool(table, modifiers, source_level, source_region))
	
	print("💰 Rolled '%s': %d items (source Lv.%d, R%d)" % [
		table_name, results.size(), source_level, source_region])
	return results

func roll_loot_multiple(table_name: String, count: int, modifiers: Dictionary = {},
						source_level: int = -1, source_region: int = -1) -> Array[Dictionary]:
	"""Roll the same loot table multiple times
	
	Returns combined results from all rolls
	"""
	var all_results: Array[Dictionary] = []
	
	for i in range(count):
		all_results.append_array(roll_loot(table_name, modifiers,
										   source_level, source_region))
	
	return all_results

# ============================================================================
# CONVENIENCE API (v2)
# ============================================================================

func roll_loot_from_enemy(table_name: String, enemy_level: int,
						  enemy_region: int, luck_bonus: float = 0.0) -> Array[Dictionary]:
	"""Convenience wrapper for enemy drops.
	
	Args:
		table_name: The enemy's loot table name.
		enemy_level: The enemy's level (becomes source_level).
		enemy_region: The region the enemy is in.
		luck_bonus: Player's luck stat bonus for drop chance.
	
	Returns:
		Array of loot results.
	"""
	var modifiers := {}
	if luck_bonus > 0.0:
		modifiers["luck"] = luck_bonus
	
	return roll_loot(table_name, modifiers, enemy_level, enemy_region)


func generate_drop(item_template: EquippableItem, source_level: int,
				   source_region: int = 1,
				   rarity_override: int = -1) -> Dictionary:
	"""Generate a single item drop outside the loot table system.
	
	Useful for quest rewards, shop generation, debug testing, etc.
	
	Args:
		item_template: The base EquippableItem to instantiate.
		source_level: Level for scaling (typically enemy or zone level).
		source_region: Region for metadata (1–6).
		rarity_override: Force a rarity (-1 = use template's rarity).
	
	Returns:
		Item dictionary ready for inventory, or empty dict on failure.
	"""
	if not item_template:
		push_warning("LootManager.generate_drop(): null item_template")
		return {}
	
	var item: EquippableItem = item_template.duplicate(true)
	
	if rarity_override >= 0:
		item.rarity = rarity_override
	
	# Stamp level with jitter
	item.item_level = clampi(
		source_level + randi_range(-item_level_spread, item_level_spread),
		1, 100
	)
	item.region = source_region
	
	# Roll affixes
	item.initialize_affixes()
	
	var item_dict := item.to_dict()
	item_dict["item_affixes"] = item.get_all_affixes()
	
	print("  🎁 Generated: %s Lv.%d (%s, R%d)" % [
		item.item_name, item.item_level, item.get_rarity_name(), item.region])
	
	return {
		"type": "item",
		"item": item_dict,
		"quantity": 1,
		"source": "generated"
	}


func get_item_level_for_region(region_num: int, difficulty_bias: float = 0.5) -> int:
	"""Get an appropriate item level for a region.
	
	Args:
		region_num: Region number (1–6).
		difficulty_bias: 0.0 = easiest, 1.0 = hardest, 0.5 = average.
	
	Returns:
		Item level within the region's bounds.
	"""
	var config := _get_scaling_config()
	if config:
		return config.get_item_level_for_region(region_num, difficulty_bias)
	
	# Fallback: rough approximation
	var base_levels := {1: 10, 2: 25, 3: 41, 4: 58, 5: 75, 6: 90}
	return base_levels.get(region_num, 50)

# ============================================================================
# POOL ROLLING LOGIC
# ============================================================================

func _roll_guaranteed_pool(table: LootTable,
						   source_level: int = -1, source_region: int = -1) -> Array[Dictionary]:
	"""Roll all guaranteed drops"""
	var results: Array[Dictionary] = []
	
	for drop in table.get_valid_drops(table.guaranteed_drops):
		var drop_result = _process_single_drop(drop, table.table_name,
											   source_level, source_region)
		if drop_result:
			results.append(drop_result)
	
	return results

func _roll_weighted_pool(table: LootTable,
						 source_level: int = -1, source_region: int = -1) -> Array[Dictionary]:
	"""Roll weighted drops using weighted random selection"""
	var results: Array[Dictionary] = []
	var num_rolls = table.get_num_weighted_rolls()
	
	if table.weighted_drops.size() == 0:
		return results
	
	for i in range(num_rolls):
		var drop = _select_weighted_drop(table.weighted_drops)
		if drop:
			var drop_result = _process_single_drop(drop, table.table_name,
												   source_level, source_region)
			if drop_result:
				results.append(drop_result)
	
	return results

func _roll_bonus_pool(table: LootTable, modifiers: Dictionary,
					  source_level: int = -1, source_region: int = -1) -> Array[Dictionary]:
	"""Roll bonus drops with % chance (affected by luck)"""
	var results: Array[Dictionary] = []
	
	if table.bonus_drops.size() == 0:
		return results
	
	# Apply luck modifier to bonus chance
	var bonus_chance = table.bonus_drop_chance
	if modifiers.has("luck"):
		var luck = modifiers["luck"]
		bonus_chance += luck * 0.01  # +1% per luck point
	
	if modifiers.has("magic_find"):
		bonus_chance += modifiers["magic_find"] * 0.01
	
	# Clamp to 0-100%
	bonus_chance = clamp(bonus_chance, 0.0, 1.0)
	
	# Roll for bonus drop
	if randf() < bonus_chance:
		var drop = _select_weighted_drop(table.bonus_drops)
		if drop:
			var drop_result = _process_single_drop(drop, table.table_name,
												   source_level, source_region)
			if drop_result:
				results.append(drop_result)
				print("  🌟 Bonus drop triggered! (%d%% chance)" % int(bonus_chance * 100))
	
	return results

# ============================================================================
# DROP PROCESSING
# ============================================================================

func _select_weighted_drop(drops: Array[LootDrop]) -> LootDrop:
	"""Select one drop from a weighted pool"""
	var valid_drops = []
	var total_weight = 0
	
	# Build valid drops list
	for drop in drops:
		if drop and drop.is_valid():
			valid_drops.append(drop)
			total_weight += drop.drop_weight
	
	if valid_drops.size() == 0 or total_weight == 0:
		return null
	
	# Weighted random selection
	var roll = randi_range(0, total_weight - 1)
	var cumulative = 0
	
	for drop in valid_drops:
		cumulative += drop.drop_weight
		if roll < cumulative:
			return drop
	
	return valid_drops[-1]  # Fallback

func _process_single_drop(drop: LootDrop, source: String,
						  source_level: int = -1, source_region: int = -1) -> Dictionary:
	"""Process a single drop and return result"""
	match drop.drop_type:
		LootDrop.DropType.ITEM:
			return _process_item_drop(drop, source, source_level, source_region)
		
		LootDrop.DropType.CURRENCY:
			return _process_currency_drop(drop, source)
		
		LootDrop.DropType.TABLE:
			return _process_nested_table(drop, source, source_level, source_region)
		
		LootDrop.DropType.NOTHING:
			print("  💨 Dropped: Nothing")
			return {}  # Empty result
	
	return {}

func _process_item_drop(drop: LootDrop, source: String,
						source_level: int = -1, source_region: int = -1) -> Dictionary:
	"""Process an item drop — create item with level-scaled affixes.
	
	Args:
		drop: The LootDrop resource describing what to drop.
		source: Display name of the drop source (enemy name, chest, etc).
		source_level: Level of the source (enemy level, zone level).
					  -1 = don't stamp (use item template's default).
		source_region: Region the source is in (1–6).
					  -1 = don't stamp.
	"""
	if not drop.item_template:
		return {}
	
	# Create a copy of the item
	var item = drop.item_template.duplicate(true)
	
	# Override rarity if specified
	if drop.force_rarity >= 0:
		item.rarity = drop.force_rarity
	
	# Stamp item_level from source (with jitter)
	if source_level > 0:
		item.item_level = clampi(
			source_level + randi_range(-item_level_spread, item_level_spread),
			1, 100
		)
	
	# Stamp region
	if source_region > 0:
		item.region = source_region
	
	# Initialize affixes (now uses item_level for scaling)
	item.initialize_affixes()
	
	# Convert to dictionary
	var item_dict = item.to_dict()
	item_dict["item_affixes"] = item.get_all_affixes()
	
	# Get quantity
	var quantity = drop.get_quantity()
	
	print("  🎁 Dropped: %s Lv.%d x%d (%s, R%d)" % [
		item.item_name, item.item_level, quantity,
		item.get_rarity_name(), item.region])
	
	return {
		"type": "item",
		"item": item_dict,
		"quantity": quantity,
		"source": source
	}

func _process_currency_drop(drop: LootDrop, source: String) -> Dictionary:
	"""Process a currency drop"""
	var amount = drop.get_currency_amount()
	
	if amount <= 0:
		return {}
	
	print("  💰 Dropped: %d Gold" % amount)
	
	return {
		"type": "currency",
		"amount": amount,
		"source": source
	}

func _process_nested_table(drop: LootDrop, source: String,
						   source_level: int = -1, source_region: int = -1) -> Dictionary:
	"""Process a nested loot table drop"""
	if not drop.nested_table:
		return {}
	
	print("  📦 Rolling nested table: %s" % drop.nested_table.table_name)
	
	# Roll the nested table and return first result
	var nested_results = roll_loot(drop.nested_table.table_name, {},
								   source_level, source_region)
	
	if nested_results.size() > 0:
		return nested_results[0]  # Return first drop from nested table
	
	return {}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func get_loot_table(table_name: String) -> LootTable:
	"""Get a loot table by name"""
	return loot_tables.get(table_name, null)

func has_loot_table(table_name: String) -> bool:
	"""Check if a loot table exists"""
	return loot_tables.has(table_name)

func get_all_table_names() -> Array[String]:
	"""Get list of all loaded loot table names"""
	var names: Array[String] = []
	for name in loot_tables.keys():
		names.append(name)
	return names

func preview_rolls(table_name: String, num_simulations: int = 100) -> Dictionary:
	"""Simulate rolling a loot table many times for debugging
	
	Returns:
		{
			"item_name": drop_count,
			"Gold": total_gold,
			...
		}
	"""
	var stats = {}
	
	for i in range(num_simulations):
		var results = roll_loot(table_name)
		
		for result in results:
			if result.get("type") == "currency":
				var amount = result.get("amount", 0)
				stats["Gold"] = stats.get("Gold", 0) + amount
			elif result.get("type") == "item":
				var item_name = result.get("item", {}).get("name", "Unknown")
				stats[item_name] = stats.get(item_name, 0) + 1
	
	print("=== Preview: %s (%d rolls) ===" % [table_name, num_simulations])
	for key in stats:
		print("  %s: %d" % [key, stats[key]])
	
	return stats
