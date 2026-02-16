@tool
extends EditorScript
# ============================================================================
# generate_region1_loot_tables.gd
# Region 1 (Sanctum) — Loot Table Generator
#
# Scans all 68 base item templates from region_1/ directories, then creates:
#   - 1 shared item pool (all items, slot-weighted)
#   - 3 archetype bonus pools (STR/AGI/INT filtered)
#   - 1 world legendary pool (empty — add legendaries via Inspector)
#   - 5 enemy tier configs (Trash → World Boss)
#   - 1 RegionLootConfig wiring everything together
#
# Run: Editor → File → Run (or Ctrl+Shift+X with this script open)
# ============================================================================

const ITEM_DIR := "res://resources/items/region_1"
const LOOT_DIR := "res://resources/loot_tables"
const TIER_DIR := "res://resources/loot_tables/tier_configs"
const REGION_DIR := "res://resources/loot_tables/regions"

# Affix Category for archetype detection
const C := Affix.Category

# Slot weight map — controls how often each slot type appears in drops.
# Higher = more common. Armor is most common, accessories rarest.
var SLOT_WEIGHTS := {
	"head": 10,
	"torso": 10,
	"gloves": 10,
	"boots": 10,
	"main_hand": 6,
	"off_hand": 6,
	"heavy": 4,
	"accessory": 3,
}

func _run():
	print("=" .repeat(60))
	print("  REGION 1 LOOT TABLE GENERATOR")
	print("=" .repeat(60))

	_ensure_dirs()

	# Step 1: Load all item templates
	var items: Array[Dictionary] = _load_all_items()
	if items.is_empty():
		push_error("No items found in %s — run the item generator first!" % ITEM_DIR)
		return

	# Step 2: Create loot tables
	var shared_table: LootTable = _create_shared_pool(items)
	var str_table: LootTable = _create_archetype_pool(items, "str", "STR")
	var agi_table: LootTable = _create_archetype_pool(items, "agi", "AGI")
	var int_table: LootTable = _create_archetype_pool(items, "int", "INT")
	var legendary_table: LootTable = _create_world_legendary_pool()

	# Step 3: Create tier configs
	var tiers: Dictionary = _create_tier_configs()

	# Step 4: Wire RegionLootConfig
	_create_region_config(tiers, shared_table, str_table, agi_table, int_table, legendary_table)

	print("")
	print("=" .repeat(60))
	print("  DONE — Loot system ready for Region 1")
	print("=" .repeat(60))

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

func _ensure_dirs():
	var da := DirAccess.open("res://")
	for dir: String in [
		LOOT_DIR,
		LOOT_DIR + "/zones",
		TIER_DIR,
		REGION_DIR,
	]:
		if not da.dir_exists(dir):
			da.make_dir_recursive(dir)
			print("  📁 Created %s" % dir)

# ============================================================================
# ITEM LOADING — Scans all region_1 subdirectories
# ============================================================================

func _load_all_items() -> Array[Dictionary]:
	"""Load all .tres item templates and tag with slot folder + archetype.
	
	Returns Array of {item: EquippableItem, slot: String, archetype: String, path: String}
	"""
	var results: Array[Dictionary] = []

	for slot_folder: String in SLOT_WEIGHTS.keys():
		var dir_path: String = ITEM_DIR + "/" + slot_folder
		var dir := DirAccess.open(dir_path)
		if not dir:
			print("  ⚠️ No directory: %s" % dir_path)
			continue

		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path: String = dir_path + "/" + file_name
				var item = load(full_path)
				if item and item is EquippableItem:
					var archetype: String = _detect_archetype(item)
					results.append({
						"item": item,
						"slot": slot_folder,
						"archetype": archetype,
						"path": full_path,
					})
			file_name = dir.get_next()
		dir.list_dir_end()

	print("\n  📦 Loaded %d item templates" % results.size())
	for slot_folder: String in SLOT_WEIGHTS.keys():
		var count: int = 0
		for entry: Dictionary in results:
			if entry.slot == slot_folder:
				count += 1
		if count > 0:
			print("    %s: %d items (weight %d each)" % [slot_folder, count, SLOT_WEIGHTS[slot_folder]])

	return results


func _detect_archetype(item: EquippableItem) -> String:
	"""Detect STR/AGI/INT archetype from the item's first base stat affix."""
	if item.base_stat_affixes.size() == 0:
		# Fallback: check manual affixes
		if item.manual_first_affix:
			return _category_to_archetype(item.manual_first_affix.category)
		return "none"

	var first_affix: Affix = item.base_stat_affixes[0]
	if not first_affix:
		return "none"

	return _category_to_archetype(first_affix.category)


func _category_to_archetype(category: int) -> String:
	match category:
		C.STRENGTH_BONUS: return "str"
		C.AGILITY_BONUS: return "agi"
		C.INTELLECT_BONUS: return "int"
	return "none"

# ============================================================================
# SHARED POOL — All 68 items, slot-weighted
# ============================================================================

func _create_shared_pool(items: Array[Dictionary]) -> LootTable:
	print("\n── SHARED POOL ──")

	var table := LootTable.new()
	table.table_name = "region_1_shared"
	table.description = "Region 1 (Sanctum) — All base items, weighted by slot rarity."
	table.num_weighted_rolls_min = 1
	table.num_weighted_rolls_max = 1

	var drops: Array[LootDrop] = []
	for entry: Dictionary in items:
		var drop := _make_item_drop(entry.item, SLOT_WEIGHTS[entry.slot])
		drops.append(drop)

	table.weighted_drops.assign(drops)

	var path: String = LOOT_DIR + "/zones/region_1_shared.tres"
	var err := ResourceSaver.save(table, path)
	if err == OK:
		print("  ✅ %s → %s (%d items)" % [table.table_name, path, drops.size()])
	else:
		push_error("  ❌ Failed to save shared pool: %s" % error_string(err))

	return table

# ============================================================================
# ARCHETYPE POOLS — STR/AGI/INT filtered subsets
# ============================================================================

func _create_archetype_pool(items: Array[Dictionary], archetype_key: String, label: String) -> LootTable:
	var table := LootTable.new()
	table.table_name = "region_1_%s_bonus" % archetype_key
	table.description = "Region 1 — %s archetype bonus pool. Enemies matching this stat roll a bonus item from here." % label
	table.num_weighted_rolls_min = 1
	table.num_weighted_rolls_max = 1

	var drops: Array[LootDrop] = []
	for entry: Dictionary in items:
		if entry.archetype == archetype_key:
			var drop := _make_item_drop(entry.item, SLOT_WEIGHTS[entry.slot])
			drops.append(drop)

	table.weighted_drops.assign(drops)

	var path: String = LOOT_DIR + "/zones/region_1_%s_bonus.tres" % archetype_key
	var err := ResourceSaver.save(table, path)
	if err == OK:
		print("  ✅ %s → %s (%d items)" % [table.table_name, path, drops.size()])
	else:
		push_error("  ❌ Failed to save %s pool: %s" % [label, error_string(err)])

	return table

# ============================================================================
# WORLD LEGENDARY POOL — Empty, hand-curated via Inspector
# ============================================================================

func _create_world_legendary_pool() -> LootTable:
	print("\n── WORLD LEGENDARY POOL ──")

	var table := LootTable.new()
	table.table_name = "world_legendaries"
	table.description = "Hand-curated world legendaries. Any enemy can trigger a drop from here. Add legendary item templates via the Inspector."
	table.num_weighted_rolls_min = 1
	table.num_weighted_rolls_max = 1

	var path: String = LOOT_DIR + "/special/world_legendaries.tres"
	var err := ResourceSaver.save(table, path)
	if err == OK:
		print("  ✅ %s → %s (empty — add legendaries in Inspector)" % [table.table_name, path])
	else:
		push_error("  ❌ Failed to save world legendary pool: %s" % error_string(err))

	return table

# ============================================================================
# TIER CONFIGS — 5 enemy tiers with tuned defaults
# ============================================================================

func _create_tier_configs() -> Dictionary:
	print("\n── TIER CONFIGS ──")

	var configs := {}

	# ── TRASH ──
	# Mostly junk, occasional Uncommon. 60% chance of nothing.
	configs["trash"] = _make_tier_config(
		"Trash", EnemyTierLootConfig.EnemyTier.TRASH,
		50, 35, 12, 3,       # rarity: Common 50, Uncommon 35, Rare 12, Epic 3
		0, 1, 60,             # drops: 0-1, nothing_weight 60
		0.0,                  # archetype bonus: none
		0.0,                  # world legendary: none
		3, 10,                # currency: 3-10 gold
	)

	# ── ELITE ──
	# Guaranteed drop. Better rarity spread. Slight archetype bonus.
	configs["elite"] = _make_tier_config(
		"Elite", EnemyTierLootConfig.EnemyTier.ELITE,
		20, 45, 25, 10,
		1, 1, 0,              # 1 guaranteed drop
		0.20,                 # 20% archetype bonus
		0.005,                # 0.5% world legendary
		8, 25,
	)

	# ── MINI-BOSS ──
	# 1 guaranteed + 30% 2nd. Good rarity. Decent archetype + legendary chance.
	configs["mini_boss"] = _make_tier_config(
		"Mini-Boss", EnemyTierLootConfig.EnemyTier.MINI_BOSS,
		5, 30, 40, 25,
		1, 2, 0,              # 1-2 drops (effectively ~1.3 average)
		0.35,                 # 35% archetype bonus
		0.02,                 # 2% world legendary
		15, 40,
	)

	# ── BOSS ──
	# 1-2 guaranteed. Heavily skewed toward Rare/Epic. Strong bonus chances.
	configs["boss"] = _make_tier_config(
		"Boss", EnemyTierLootConfig.EnemyTier.BOSS,
		0, 15, 40, 45,
		1, 2, 0,
		0.50,                 # 50% archetype bonus
		0.05,                 # 5% world legendary
		25, 60,
	)

	# ── WORLD BOSS ──
	# 2 guaranteed + 40% 3rd. Epic-heavy. Always archetype bonus if applicable.
	configs["world_boss"] = _make_tier_config(
		"World Boss", EnemyTierLootConfig.EnemyTier.WORLD_BOSS,
		0, 0, 30, 70,
		2, 3, 0,              # 2-3 drops
		1.0,                  # 100% archetype bonus
		0.15,                 # 15% world legendary
		50, 120,
	)

	return configs


func _make_tier_config(
	p_name: String, p_tier: EnemyTierLootConfig.EnemyTier,
	p_common: int, p_uncommon: int, p_rare: int, p_epic: int,
	p_drop_min: int, p_drop_max: int, p_nothing: int,
	p_archetype: float,
	p_legendary: float,
	p_gold_min: int, p_gold_max: int,
) -> EnemyTierLootConfig:

	var config := EnemyTierLootConfig.new()
	config.tier_name = p_name
	config.tier = p_tier
	config.common_weight = p_common
	config.uncommon_weight = p_uncommon
	config.rare_weight = p_rare
	config.epic_weight = p_epic
	config.drop_count_min = p_drop_min
	config.drop_count_max = p_drop_max
	config.nothing_weight = p_nothing
	config.archetype_bonus_chance = p_archetype
	config.world_legendary_chance = p_legendary
	config.currency_min = p_gold_min
	config.currency_max = p_gold_max

	var file_name: String = p_name.to_lower().replace("-", "_").replace(" ", "_")
	var path: String = TIER_DIR + "/%s_tier.tres" % file_name
	var err := ResourceSaver.save(config, path)
	if err == OK:
		print("  ✅ %s → %s (C:%d U:%d R:%d E:%d | drops %d-%d)" % [
			p_name, path, p_common, p_uncommon, p_rare, p_epic, p_drop_min, p_drop_max])
	else:
		push_error("  ❌ Failed to save tier config %s: %s" % [p_name, error_string(err)])

	return config

# ============================================================================
# REGION CONFIG — Wires everything together
# ============================================================================

func _create_region_config(
	tiers: Dictionary,
	shared: LootTable,
	str_pool: LootTable,
	agi_pool: LootTable,
	int_pool: LootTable,
	legendary_pool: LootTable,
):
	print("\n── REGION CONFIG ──")

	var config := RegionLootConfig.new()
	config.region_name = "Sanctum"
	config.region_number = 1
	config.trash_config = tiers["trash"]
	config.elite_config = tiers["elite"]
	config.mini_boss_config = tiers["mini_boss"]
	config.boss_config = tiers["boss"]
	config.world_boss_config = tiers["world_boss"]
	config.shared_item_pool = shared
	config.str_bonus_pool = str_pool
	config.agi_bonus_pool = agi_pool
	config.int_bonus_pool = int_pool
	config.world_legendary_pool = legendary_pool

	var path: String = REGION_DIR + "/region_1_loot_config.tres"
	var err := ResourceSaver.save(config, path)
	if err == OK:
		print("  ✅ Region 1 Loot Config → %s" % path)
	else:
		push_error("  ❌ Failed to save region config: %s" % error_string(err))

# ============================================================================
# HELPERS
# ============================================================================

func _make_item_drop(item: EquippableItem, weight: int) -> LootDrop:
	"""Create a LootDrop entry for an item template."""
	var drop := LootDrop.new()
	drop.drop_type = LootDrop.DropType.ITEM
	drop.item_template = item
	drop.drop_weight = weight
	drop.force_rarity = -1  # Rarity decided by tier config at roll time
	drop.quantity_min = 1
	drop.quantity_max = 1
	return drop
