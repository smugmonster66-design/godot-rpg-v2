@tool
extends EditorScript

## Run this via File → Run EditorScript.
## It creates an affix with effect_data, saves it, then verifies persistence
## by reading the raw .tres file AND reloading the resource.

func _run():
	var path = "res://resources/affixes/test/_dict_test.tres"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	
	# ── Step 1: Create and save ──
	var affix = Affix.new()
	affix.affix_name = "Dict Test"
	affix.description = "Testing dictionary persistence"
	affix.category = Affix.Category.SKILL_RANK_BONUS
	affix.effect_number = 1.0
	affix.effect_data = {"skill_id": "flame_kindling"}
	
	print("\n=== DICT PERSISTENCE TEST ===")
	print("1. Before save:")
	print("   effect_data = %s" % [affix.effect_data])
	print("   effect_data type = %s" % typeof(affix.effect_data))
	print("   effect_data size = %d" % affix.effect_data.size())
	
	var err = ResourceSaver.save(affix, path)
	print("2. Save result: %s" % ("OK" if err == OK else "FAILED: %d" % err))
	
	# ── Step 2: Read raw file ──
	var raw = FileAccess.get_file_as_string(path)
	print("3. Raw .tres contents:")
	print("─────────────────────")
	print(raw)
	print("─────────────────────")
	
	var has_skill_id = "skill_id" in raw
	print("4. 'skill_id' found in raw file: %s" % has_skill_id)
	
	# ── Step 3: Reload from disk (bypass cache) ──
	# ResourceLoader.load with cache mode IGNORE to force fresh load
	var reloaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if reloaded:
		print("5. Reloaded resource:")
		print("   effect_data = %s" % [reloaded.effect_data])
		print("   effect_data size = %d" % reloaded.effect_data.size())
		if reloaded.effect_data.has("skill_id"):
			print("   ✅ skill_id = '%s'" % reloaded.effect_data["skill_id"])
		else:
			print("   ❌ skill_id NOT FOUND in reloaded effect_data")
	else:
		print("5. ❌ Failed to reload resource")
	
	# ── Step 4: Test with take_over_path (alternative save method) ──
	var affix2 = Affix.new()
	affix2.affix_name = "Dict Test 2"
	affix2.description = "Testing with take_over_path"
	affix2.category = Affix.Category.SKILL_RANK_BONUS
	affix2.effect_number = 2.0
	affix2.effect_data = {"skill_id": "flame_inferno", "extra": "test"}
	
	var path2 = "res://resources/affixes/test/_dict_test_2.tres"
	affix2.take_over_path(path2)
	var err2 = ResourceSaver.save(affix2, path2)
	print("\n6. Method 2 (take_over_path) save: %s" % ("OK" if err2 == OK else "FAILED"))
	
	var raw2 = FileAccess.get_file_as_string(path2)
	print("7. Raw file 2 has 'skill_id': %s" % ("skill_id" in raw2))
	print("   Raw file 2 has 'flame_inferno': %s" % ("flame_inferno" in raw2))
	
	print("\n=== TEST COMPLETE ===")
	print("If step 4 says YES but Inspector shows empty → it's a cache/display issue.")
	print("If step 4 says NO → it's a serialization issue with your Godot build.")
