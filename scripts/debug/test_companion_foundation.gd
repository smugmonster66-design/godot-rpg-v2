# res://scripts/debug/test_companion_foundation.gd
# Quick validation that companion foundation resources work.
@tool
extends EditorScript

func _run():
	print("\n[Test] === COMPANION FOUNDATION TEST ===\n")
	_test_companion_data()
	_test_companion_instance()
	_test_companion_combatant()
	_test_companion_manager_queries()
	print("\n[Test] === ALL TESTS COMPLETE ===\n")

func _test_companion_data():
	print("--- CompanionData ---")
	var data = CompanionData.new()
	data.companion_name = "Test Guard"
	data.companion_id = &"test_guard"
	data.companion_type = CompanionData.CompanionType.NPC
	data.base_max_hp = 50
	data.hp_scaling = CompanionData.HPScaling.FLAT
	data.trigger = CompanionData.CompanionTrigger.PLAYER_DAMAGED
	data.target_rule = CompanionData.CompanionTarget.SELF
	data.has_taunt = true
	data.taunt_duration = 2

	assert(data.calculate_max_hp(100, 5) == 50, "FLAT scaling should return base_max_hp")

	data.hp_scaling = CompanionData.HPScaling.PLAYER_PERCENT
	data.hp_scaling_value = 0.5
	assert(data.calculate_max_hp(100, 5) == 50, "50% of 100 = 50")
	assert(data.calculate_max_hp(200, 5) == 100, "50% of 200 = 100")

	data.hp_scaling = CompanionData.HPScaling.PLAYER_LEVEL
	data.hp_scaling_value = 10.0
	data.base_max_hp = 20
	assert(data.calculate_max_hp(100, 5) == 70, "20 + 5*10 = 70")

	print("  [OK] CompanionData HP scaling OK")

func _test_companion_instance():
	print("--- CompanionInstance ---")
	var data = CompanionData.new()
	data.companion_name = "Test Sage"
	data.base_max_hp = 60
	data.hp_scaling = CompanionData.HPScaling.FLAT

	var instance = CompanionInstance.new()
	instance.companion_data = data
	assert(instance.current_hp == -1, "Should be uninitialized")

	instance.initialize_hp(100, 5)
	assert(instance.current_hp == 60, "Should be 60 after init")

	instance.current_hp = 30
	instance.is_dead = false
	# Simulate restore
	instance.restore()
	assert(instance.is_dead == false, "Should be alive after restore")
	assert(instance.current_hp == -1, "HP reset to -1 for recalc")

	print("  [OK] CompanionInstance lifecycle OK")

func _test_companion_combatant():
	print("--- CompanionCombatant ---")
	var data = CompanionData.new()
	data.companion_name = "Test Elemental"
	data.companion_type = CompanionData.CompanionType.SUMMON
	data.base_max_hp = 40
	data.hp_scaling = CompanionData.HPScaling.FLAT
	data.has_taunt = false
	data.cooldown_turns = 2
	data.uses_per_combat = 3
	data.duration_turns = 5

	var combatant = CompanionCombatant.new()
	combatant.initialize_from_data(data, 2, 100, 5)

	assert(combatant.is_companion == true, "Should be companion")
	assert(combatant.is_summon == true, "Should be summon")
	assert(combatant.max_health == 40, "Max HP should be 40")
	assert(combatant.current_health == 40, "Current HP should be 40")
	assert(combatant.uses_remaining == 3, "Should have 3 uses")
	assert(combatant.can_fire() == true, "Should be able to fire")

	combatant.on_fired()
	assert(combatant.uses_remaining == 2, "Should have 2 uses after firing")
	assert(combatant.cooldown_remaining == 2, "Should have 2 turn cooldown")
	assert(combatant.can_fire() == false, "Should be on cooldown")

	combatant.tick_cooldown()
	assert(combatant.cooldown_remaining == 1, "Should be 1 after tick")
	combatant.tick_cooldown()
	assert(combatant.can_fire() == true, "Should be off cooldown")

	# Duration
	for j in range(4):
		assert(combatant.tick_duration() == false, "Should not expire at turn %d" % (j + 1))
	assert(combatant.tick_duration() == true, "Should expire at turn 5")

	print("  [OK] CompanionCombatant state tracking OK")

	combatant.free()

func _test_companion_manager_queries():
	print("--- CompanionManager queries ---")
	var mgr = CompanionManager.new()

	# Verify empty state
	assert(mgr.get_alive_companions().size() == 0, "Should start empty")
	assert(mgr.has_empty_summon_slot() == true, "Summon slots should be free")
	assert(mgr.get_alive_taunting().size() == 0, "No taunters")

	print("  [OK] CompanionManager empty-state queries OK")
	mgr.free()
