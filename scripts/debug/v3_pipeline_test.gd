# res://scripts/debug/v3_pipeline_test.gd
# V3 Pipeline Integration Test
#
# Validates the EquippableItem-direct pipeline after Chunks 1–3.
# Attach to any Node and call run_all(), or connect to a button.
#
extends Node

var _pass_count := 0
var _fail_count := 0


func _ready():
	_wait_for_player()

func _wait_for_player():
	while not GameManager.player:
		await get_tree().create_timer(0.1).timeout
	# Extra frame for UI initialization to finish
	await get_tree().process_frame
	run_all()

func run_all():
	_pass_count = 0
	_fail_count = 0
	
	print("\n" + "═".repeat(60))
	print("  V3 PIPELINE INTEGRATION TEST")
	print("═".repeat(60))
	
	_test_loot_manager_returns_equippable()
	_test_item_stamping_and_affixes()
	_test_generate_drop()
	_test_player_inventory_accepts_equippable()
	_test_player_equip_registers_affixes()
	_test_to_dict_deprecation_warning()
	_test_preview_rolls_with_equippable()
	
	print("\n" + "─".repeat(60))
	print("  RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	if _fail_count == 0:
		print("  ✅ ALL TESTS PASSED")
	else:
		print("  ❌ SOME TESTS FAILED")
	print("═".repeat(60) + "\n")


# ════════════════════════════════════════════════════════════════
# TEST 1: LootManager._process_item_drop returns EquippableItem
# ════════════════════════════════════════════════════════════════

func _test_loot_manager_returns_equippable():
	print("\n📋 Test 1: LootManager returns EquippableItem")
	
	var template := _make_test_item("Test Sword", EquippableItem.EquipSlot.MAIN_HAND, EquippableItem.Rarity.RARE)
	
	# Use generate_drop since it's the public API
	var result: Dictionary = LootManager.generate_drop(template, 25, 3)
	
	_assert("result is not empty", result.size() > 0)
	_assert("result type is 'item'", result.get("type") == "item")
	_assert("result['item'] is EquippableItem", result.get("item") is EquippableItem)
	_assert("result['item'] is NOT Dictionary", not (result.get("item") is Dictionary))
	
	if result.get("item") is EquippableItem:
		var item: EquippableItem = result.get("item")
		_assert("item.item_name matches template", item.item_name == "Test Sword")
		print("  ✓ Item class: %s" % item.get_class())


# ════════════════════════════════════════════════════════════════
# TEST 2: Item stamping (item_level, region) and affix rolling
# ════════════════════════════════════════════════════════════════

func _test_item_stamping_and_affixes():
	print("\n📋 Test 2: Item stamping and affix rolling")
	
	var template := _make_test_item("Stamping Test Helm", EquippableItem.EquipSlot.HEAD, EquippableItem.Rarity.EPIC)
	
	var result: Dictionary = LootManager.generate_drop(template, 50, 4)
	var item: EquippableItem = result.get("item")
	
	_assert("item exists", item != null)
	
	if item:
		# item_level should be near 50 (±spread, typically ±3)
		_assert("item_level stamped (>0)", item.item_level > 0)
		_assert("item_level near source (40-60)", item.item_level >= 40 and item.item_level <= 60)
		_assert("region stamped to 4", item.region == 4)
		
		# EPIC should have affixes from tiers 1+2+3
		var total_affixes = item.inherent_affixes.size() + item.rolled_affixes.size()
		print("  Inherent: %d, Rolled: %d, Total: %d" % [
			item.inherent_affixes.size(), item.rolled_affixes.size(), total_affixes])
		
		# item_affixes should equal inherent + rolled combined
		_assert("item_affixes = inherent + rolled",
			item.item_affixes.size() == item.inherent_affixes.size() + item.rolled_affixes.size())
		
		# Check affixes are actual Affix Resources
		for affix in item.item_affixes:
			if affix:
				_assert("affix '%s' is Affix Resource" % affix.affix_name, affix is Affix)
				break  # Just check first one


# ════════════════════════════════════════════════════════════════
# TEST 3: generate_drop() convenience method
# ════════════════════════════════════════════════════════════════

func _test_generate_drop():
	print("\n📋 Test 3: generate_drop() convenience method")
	
	var template := _make_test_item("Gen Test Boots", EquippableItem.EquipSlot.BOOTS, EquippableItem.Rarity.UNCOMMON)
	
	# Test rarity override
	var result := LootManager.generate_drop(template, 10, 1, EquippableItem.Rarity.LEGENDARY)
	var item: EquippableItem = result.get("item")
	
	_assert("item exists", item != null)
	if item:
		_assert("rarity overridden to LEGENDARY", item.rarity == EquippableItem.Rarity.LEGENDARY)
		_assert("source is 'generated'", result.get("source") == "generated")
		_assert("quantity is 1", result.get("quantity") == 1)


# ════════════════════════════════════════════════════════════════
# TEST 4: Player inventory accepts EquippableItem from loot
# ════════════════════════════════════════════════════════════════

func _test_player_inventory_accepts_equippable():
	print("\n📋 Test 4: Player inventory accepts EquippableItem")
	
	var player: Player = GameManager.player if GameManager else null
	if not player:
		print("  ⚠️ SKIPPED — No GameManager.player available")
		return
	
	var template := _make_test_item("Inventory Test Gloves", EquippableItem.EquipSlot.GLOVES, EquippableItem.Rarity.RARE)
	var result := LootManager.generate_drop(template, 20, 2)
	var item: EquippableItem = result.get("item")
	
	_assert("generated item is EquippableItem", item is EquippableItem)
	
	if item:
		var size_before := player.inventory.size()
		player.add_to_inventory(item)
		
		_assert("inventory size increased by 1", player.inventory.size() == size_before + 1)
		_assert("item is in inventory", item in player.inventory)
		_assert("inventory item is EquippableItem", player.inventory[-1] is EquippableItem)
		
		# Clean up — remove test item
		player.remove_from_inventory(item)
		_assert("cleanup: item removed", item not in player.inventory)


# ════════════════════════════════════════════════════════════════
# TEST 5: Equip item → affixes registered with affix_manager
# ════════════════════════════════════════════════════════════════


func _test_player_equip_registers_affixes():
	print("\n📋 Test 5: Equip registers affixes with affix_manager")
	
	var player: Player = GameManager.player if GameManager else null
	if not player:
		print("  ⚠️ SKIPPED — No GameManager.player available")
		return
	
	var template := _make_test_item("Affix Test Torso", EquippableItem.EquipSlot.TORSO, EquippableItem.Rarity.EPIC)
	var result := LootManager.generate_drop(template, 40, 3)
	var item: EquippableItem = result.get("item")
	
	if not item or item.item_affixes.size() == 0:
		print("  ⚠️ SKIPPED — Item has no affixes to test (try higher rarity or check tables)")
		return
	
	# Add to inventory first (required for equip)
	player.add_to_inventory(item)
	
	# Track affixes before equip
	var affix_names_on_item: Array[String] = []
	for affix in item.item_affixes:
		if affix:
			affix_names_on_item.append(affix.affix_name)
	
	print("  Item has %d affixes: %s" % [affix_names_on_item.size(), affix_names_on_item])
	
	# Unequip existing torso if any
	if player.equipment.get("Torso"):
		player.unequip_item("Torso")
	
	var equipped := player.equip_item(item)
	_assert("equip succeeded", equipped)
	_assert("item is equipped", player.is_item_equipped(item))
	
	# Check affixes registered via public API
	if player.affix_manager and affix_names_on_item.size() > 0:
		var first_affix_name = affix_names_on_item[0]
		var source_affixes = player.affix_manager.get_affixes_by_source(item.item_name)
		var found = false
		for affix in source_affixes:
			if affix.affix_name == first_affix_name:
				found = true
				break
		_assert("first affix '%s' found in affix_manager" % first_affix_name, found)
		_assert("all item affixes registered (%d)" % affix_names_on_item.size(),
			source_affixes.size() == affix_names_on_item.size())
	
	# Clean up
	player.unequip_item("Torso")
	player.remove_from_inventory(item)
	_assert("cleanup: unequipped", not player.is_item_equipped(item))


# ════════════════════════════════════════════════════════════════
# TEST 6: to_dict() fires deprecation warning
# ════════════════════════════════════════════════════════════════

func _test_to_dict_deprecation_warning():
	print("\n📋 Test 6: to_dict() deprecation warning")
	
	var template := _make_test_item("Deprecation Test", EquippableItem.EquipSlot.ACCESSORY, EquippableItem.Rarity.COMMON)
	
	# This should print a push_warning in the console
	print("  (Expect a deprecation warning below ↓)")
	var dict = template.to_dict()
	
	_assert("to_dict() still returns Dictionary", dict is Dictionary)
	_assert("dict has 'name' key", dict.has("name"))
	_assert("dict['name'] matches", dict.get("name") == "Deprecation Test")
	print("  (If you see 'EquippableItem.to_dict() is deprecated' above, Chunk 3 is working)")


# ════════════════════════════════════════════════════════════════
# TEST 7: preview_rolls() works with EquippableItem items
# ════════════════════════════════════════════════════════════════

func _test_preview_rolls_with_equippable():
	print("\n📋 Test 7: preview_rolls() with EquippableItem")
	
	# This test only works if a loot table exists
	var table_names := LootManager.get_all_table_names()
	if table_names.size() == 0:
		print("  ⚠️ SKIPPED — No loot tables loaded")
		return
	
	var test_table = table_names[0]
	print("  Using table: %s" % test_table)
	
	# preview_rolls should not crash — it accesses result.item.item_name
	var stats := LootManager.preview_rolls(test_table, 5)
	_assert("preview_rolls returned Dictionary", stats is Dictionary)
	print("  preview_rolls returned %d distinct entries" % stats.size())


# ════════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════════

func _make_test_item(name: String, slot: EquippableItem.EquipSlot, rarity: EquippableItem.Rarity) -> EquippableItem:
	"""Create a minimal EquippableItem for testing."""
	var item := EquippableItem.new()
	item.item_name = name
	item.equip_slot = slot
	item.rarity = rarity
	item.description = "Test item for v3 pipeline verification"
	item.base_value = 10
	# slot_definition will auto-resolve from equip_slot in initialize_affixes()
	return item


func _assert(description: String, condition: bool):
	if condition:
		_pass_count += 1
		print("  ✅ %s" % description)
	else:
		_fail_count += 1
		print("  ❌ FAIL: %s" % description)
