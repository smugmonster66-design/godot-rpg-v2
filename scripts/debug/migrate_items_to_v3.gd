@tool
extends EditorScript

## Run this in the Godot editor (Script > Run) to migrate all existing
## EquippableItem .tres files from the old 3-field format to the new
## array-based format.
##
## What it does:
##   1. Finds all .tres files under res://resources/items/
##   2. For each EquippableItem:
##      - Migrates first/second/third_affix_table → affix_tables array
##      - Migrates manual_first/second/third_affix → manual_affixes array
##      - Sets region = 1, item_level = 1, base_value based on rarity
##      - Clears the old deprecated fields
##   3. Saves each file back
##
## Safe to run multiple times (skips already-migrated items).

const ITEM_DIRS := [
	"res://resources/items/",
	"res://resources/items/head/",
	"res://resources/items/torso/",
	"res://resources/items/gloves/",
	"res://resources/items/boots/",
	"res://resources/items/main hand/",
	"res://resources/items/off hand/",
	"res://resources/items/heavy/",
	"res://resources/items/accessory/",
	"res://resources/items/equipment_sets/",
]

const RARITY_BASE_VALUES := {
	0: 5,    # Common
	1: 10,   # Uncommon
	2: 20,   # Rare
	3: 40,   # Epic
	4: 80,   # Legendary
}

func _run():
	var migrated := 0
	var skipped := 0
	var errors := 0
	
	print("═══════════════════════════════════════")
	print("  EquippableItem v3 Migration Script")
	print("═══════════════════════════════════════")
	
	# Recursively find all .tres files
	var all_paths: Array[String] = []
	for dir_path in ITEM_DIRS:
		_find_tres_files(dir_path, all_paths)
	
	# Also scan subdirectories of equipment_sets
	_find_tres_files("res://resources/items/equipment_sets/", all_paths)
	
	print("Found %d .tres files to check" % all_paths.size())
	print("")
	
	for path in all_paths:
		var resource = load(path)
		if not resource or not resource is EquippableItem:
			continue
		
		var item: EquippableItem = resource
		
		# Check if already migrated (has affix_tables populated)
		if item.affix_tables.size() > 0 or item.manual_affixes.size() > 0:
			if item.region > 0 and item.base_value > 0:
				print("  ⏭ SKIP (already migrated): %s" % path)
				skipped += 1
				continue
		
		print("  🔄 Migrating: %s (%s)" % [item.item_name, path])
		
		# ── Migrate affix tables ──
		# Check if old fields exist and have values
		var old_tables: Array[AffixTable] = []
		if "first_affix_table" in item and item.first_affix_table:
			old_tables.append(item.first_affix_table)
			print("    → Moved first_affix_table to affix_tables[0]")
		if "second_affix_table" in item and item.second_affix_table:
			old_tables.append(item.second_affix_table)
			print("    → Moved second_affix_table to affix_tables[1]")
		if "third_affix_table" in item and item.third_affix_table:
			old_tables.append(item.third_affix_table)
			print("    → Moved third_affix_table to affix_tables[2]")
		
		if old_tables.size() > 0 and item.affix_tables.size() == 0:
			item.affix_tables = old_tables
		
		# ── Migrate manual affixes ──
		var old_manuals: Array[Affix] = []
		if "manual_first_affix" in item and item.manual_first_affix:
			old_manuals.append(item.manual_first_affix)
			print("    → Moved manual_first_affix to manual_affixes[0]")
		if "manual_second_affix" in item and item.manual_second_affix:
			old_manuals.append(item.manual_second_affix)
			print("    → Moved manual_second_affix to manual_affixes[1]")
		if "manual_third_affix" in item and item.manual_third_affix:
			old_manuals.append(item.manual_third_affix)
			print("    → Moved manual_third_affix to manual_affixes[2]")
		
		if old_manuals.size() > 0 and item.manual_affixes.size() == 0:
			item.manual_affixes = old_manuals
		
		# ── Set new identity fields ──
		if item.region == 0:
			item.region = 1
		if item.item_level == 0:
			item.item_level = 1
		if item.base_value == 0:
			item.base_value = RARITY_BASE_VALUES.get(item.rarity, 10)
		
		print("    → region=%d, item_level=%d, base_value=%d" % [item.region, item.item_level, item.base_value])
		
		# ── Save ──
		var err = ResourceSaver.save(item, path)
		if err == OK:
			migrated += 1
			print("    ✅ Saved")
		else:
			errors += 1
			print("    ❌ SAVE FAILED: error %d" % err)
	
	print("")
	print("═══════════════════════════════════════")
	print("  Migration complete!")
	print("  Migrated: %d" % migrated)
	print("  Skipped:  %d" % skipped)
	print("  Errors:   %d" % errors)
	print("═══════════════════════════════════════")
	print("")
	print("NEXT STEPS:")
	print("  1. Open each item in Inspector to verify migration")
	print("  2. Add inherent_affixes to give items base identity")
	print("  3. Clear deprecated fields once verified (old fields")
	print("     will be ignored by the new code but clutter Inspector)")

func _find_tres_files(dir_path: String, results: Array[String]):
	"""Recursively find all .tres files in a directory."""
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path.path_join(file_name)
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_find_tres_files(full_path, results)
		elif file_name.ends_with(".tres"):
			if full_path not in results:
				results.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
