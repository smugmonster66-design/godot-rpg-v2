@tool
extends EditorScript

func _run():
	print("=== Dungeon Resource Tests ===")
	_test_enums()
	_test_event_choice()
	_test_event()
	_test_shrine()
	_test_definition()
	print("=== All dungeon resource tests passed ===")

func _test_enums():
	assert(DungeonEnums.NodeType.BOSS == 3)
	assert(DungeonEnums.get_node_color(DungeonEnums.NodeType.COMBAT) != Color.BLACK)
	assert(DungeonEnums.get_node_type_name(DungeonEnums.NodeType.SHOP) == "Shop")
	print("  ✓ DungeonEnums")

func _test_event_choice():
	var c = DungeonEventChoice.new()
	c.choice_text = "Open the chest"
	c.success_chance = 0.7
	assert(c.is_risky())
	assert(c.get_display_text().contains("70%"))
	var safe = DungeonEventChoice.new()
	safe.success_chance = 1.0
	assert(not safe.is_risky())
	assert(safe.roll_success())
	print("  ✓ DungeonEventChoice")

func _test_event():
	var e = DungeonEvent.new()
	e.min_floor = 2; e.max_floor = 8
	assert(e.is_valid_for_floor(5))
	assert(not e.is_valid_for_floor(1))
	print("  ✓ DungeonEvent")

func _test_shrine():
	var s = DungeonShrine.new()
	assert(not s.has_curse())
	s.curse_affix = Affix.new()
	assert(s.has_curse())
	print("  ✓ DungeonShrine")

func _test_definition():
	var d = DungeonDefinition.new()
	d.dungeon_name = "Test"; d.dungeon_id = "test"; d.floor_count = 10
	assert(d.validate().size() > 0)
	assert(d.get_mid_floor() == 5)
	print("  ✓ DungeonDefinition")
