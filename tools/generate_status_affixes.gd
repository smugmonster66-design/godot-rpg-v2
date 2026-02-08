@tool
extends EditorScript

func _run():
	print("=== Generating StatusAffix Resources ===")
	
	var sa_script = load("res://resources/data/status_affix.gd")
	var affix_script = load("res://resources/data/affix.gd")
	
	if not sa_script or not affix_script:
		push_error("Failed to load scripts!")
		return
	
	# Create throwaway instances to read enum values
	var _sa = sa_script.new()
	var _af = affix_script.new()
	
	print("  StatusAffix script: %s" % sa_script)
	print("  Test instance: %s" % _sa)
	
	# Ensure output directory exists
	var dir = DirAccess.open("res://resources")
	if dir:
		if not dir.dir_exists("statuses"):
			dir.make_dir("statuses")
	
	var defs = _get_all_definitions(_sa, _af)
	print("  Definitions found: %d" % defs.size())
	
	var count = 0
	for def in defs:
		var s = sa_script.new()
		_apply_definition(s, def, _sa, _af)
		var path = "res://resources/statuses/%s.tres" % def["status_id"]
		var err = ResourceSaver.save(s, path)
		if err == OK:
			print("  ✓ Created: %s" % path)
			count += 1
		else:
			push_error("  ✗ Failed to save: %s (error %d)" % [path, err])
	
	print("=== Done: %d StatusAffix resources generated ===" % count)

func _apply_definition(s, def: Dictionary, _sa, _af):
	s.status_id = def["status_id"]
	s.affix_name = def["affix_name"]
	s.description = def["description"]
	s.category = def.get("category", 36)  # MISC
	s.show_in_summary = false
	s.duration_type = def.get("duration_type", 0)
	s.default_duration = def.get("default_duration", 3)
	s.max_stacks = def.get("max_stacks", 99)
	s.refresh_on_reapply = def.get("refresh_on_reapply", true)
	s.decay_style = def.get("decay_style", 0)
	s.decay_amount = def.get("decay_amount", 1)
	s.falls_off_between_turns = def.get("falls_off_between_turns", false)
	s.tick_timing = def.get("tick_timing", 0)
	s.expire_timing = def.get("expire_timing", 1)
	s.is_debuff = def.get("is_debuff", true)
	s.can_be_cleansed = def.get("can_be_cleansed", true)
	s.cleanse_tags = def.get("cleanse_tags", [])
	s.damage_per_stack = def.get("damage_per_stack", 0)
	s.tick_damage_type = def.get("tick_damage_type", 0)
	s.heal_per_stack = def.get("heal_per_stack", 0)
	s.stat_modifier_per_stack = def.get("stat_modifier_per_stack", {})

func _get_all_definitions(_sa, _af) -> Array:
	# Local enum shortcuts — resolved at runtime, not parse time
	var STACK_BASED = 0
	var TURN_BASED = 1
	var DECAY_NONE = 0
	var DECAY_FLAT = 1
	var DECAY_HALVING = 2
	var TICK_START = 0
	var TICK_END = 1
	var DMG_NONE = 0
	var DMG_PHYSICAL = 1
	var DMG_MAGICAL = 2
	var CAT_PER_TURN = 33   # Count from Affix.Category enum
	var CAT_DEFENSE = 11
	var CAT_MISC = 36

	return [
		{
			"status_id": "poison",
			"affix_name": "Poison",
			"description": "Deals physical damage at the start of each turn. Stacks halve after each tick.",
			"category": CAT_PER_TURN,
			"duration_type": STACK_BASED,
			"max_stacks": 99,
			"decay_style": DECAY_HALVING,
			"tick_timing": TICK_START,
			"damage_per_stack": 1,
			"tick_damage_type": DMG_PHYSICAL,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "dot", "poison", "physical_dot"],
		},
		{
			"status_id": "burn",
			"affix_name": "Burn",
			"description": "Deals magical damage at the end of each turn for a set duration.",
			"category": CAT_PER_TURN,
			"duration_type": TURN_BASED,
			"default_duration": 3,
			"max_stacks": 99,
			"decay_style": DECAY_NONE,
			"tick_timing": TICK_END,
			"expire_timing": TICK_END,
			"damage_per_stack": 1,
			"tick_damage_type": DMG_MAGICAL,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "dot", "burn", "fire", "magical_dot"],
		},
		{
			"status_id": "bleed",
			"affix_name": "Bleed",
			"description": "Deals physical damage at the start of each turn. Loses 1 stack per tick.",
			"category": CAT_PER_TURN,
			"duration_type": STACK_BASED,
			"max_stacks": 99,
			"decay_style": DECAY_FLAT,
			"decay_amount": 1,
			"tick_timing": TICK_START,
			"damage_per_stack": 1,
			"tick_damage_type": DMG_PHYSICAL,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "dot", "bleed", "physical_dot"],
		},
		{
			"status_id": "shadow",
			"affix_name": "Shadow",
			"description": "Deals magical damage at the start of each turn. Stacks halve after each tick.",
			"category": CAT_PER_TURN,
			"duration_type": STACK_BASED,
			"max_stacks": 99,
			"decay_style": DECAY_HALVING,
			"tick_timing": TICK_START,
			"damage_per_stack": 1,
			"tick_damage_type": DMG_MAGICAL,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "dot", "shadow", "magical_dot"],
		},
		{
			"status_id": "chill",
			"affix_name": "Chill",
			"description": "Every 2 stacks reduces die values by 1. Does not decay naturally.",
			"category": CAT_MISC,
			"duration_type": STACK_BASED,
			"max_stacks": 99,
			"decay_style": DECAY_NONE,
			"tick_timing": TICK_START,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "chill", "ice", "slow_effect"],
		},
		{
			"status_id": "slowed",
			"affix_name": "Slowed",
			"description": "Reduces die values by stack amount for a set duration.",
			"category": CAT_MISC,
			"duration_type": TURN_BASED,
			"default_duration": 3,
			"max_stacks": 99,
			"decay_style": DECAY_NONE,
			"tick_timing": TICK_START,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "slow_effect"],
		},
		{
			"status_id": "stunned",
			"affix_name": "Stunned",
			"description": "Stuns a number of random dice equal to stacks for a set duration.",
			"category": CAT_MISC,
			"duration_type": TURN_BASED,
			"default_duration": 2,
			"max_stacks": 10,
			"decay_style": DECAY_NONE,
			"tick_timing": TICK_START,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "cc", "stun"],
		},
		{
			"status_id": "corrode",
			"affix_name": "Corrode",
			"description": "Reduces armor for a set duration.",
			"category": CAT_MISC,
			"duration_type": TURN_BASED,
			"default_duration": 3,
			"max_stacks": 99,
			"stat_modifier_per_stack": {"armor": -2},
			"is_debuff": true,
			"cleanse_tags": ["debuff", "corrode", "defense_reduction"],
		},
		{
			"status_id": "enfeeble",
			"affix_name": "Enfeeble",
			"description": "Reduces outgoing damage for a set duration.",
			"category": CAT_MISC,
			"duration_type": TURN_BASED,
			"default_duration": 3,
			"max_stacks": 99,
			"stat_modifier_per_stack": {"damage_multiplier": -0.1},
			"is_debuff": true,
			"cleanse_tags": ["debuff", "enfeeble", "damage_reduction"],
		},
		{
			"status_id": "expose",
			"affix_name": "Expose",
			"description": "Increases crit chance against this target by 2% per stack.",
			"category": CAT_MISC,
			"duration_type": STACK_BASED,
			"max_stacks": 50,
			"decay_style": DECAY_NONE,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "expose"],
		},
		{
			"status_id": "overhealth",
			"affix_name": "Overhealth",
			"description": "Absorbs incoming damage. Decrements each turn.",
			"category": CAT_MISC,
			"duration_type": TURN_BASED,
			"default_duration": 3,
			"max_stacks": 999,
			"decay_style": DECAY_NONE,
			"tick_timing": TICK_START,
			"expire_timing": TICK_END,
			"is_debuff": false,
			"can_be_cleansed": true,
			"cleanse_tags": ["buff", "overhealth", "defensive"],
		},
		{
			"status_id": "block",
			"affix_name": "Block",
			"description": "Reduces incoming damage by stack amount. Falls off at the start of your next turn.",
			"category": CAT_DEFENSE,
			"duration_type": STACK_BASED,
			"max_stacks": 999,
			"decay_style": DECAY_NONE,
			"falls_off_between_turns": true,
			"is_debuff": false,
			"can_be_cleansed": true,
			"cleanse_tags": ["buff", "block", "defensive"],
		},
		{
			"status_id": "dodge",
			"affix_name": "Dodge",
			"description": "10% chance to evade per stack. Falls off at the start of your next turn.",
			"category": CAT_MISC,
			"duration_type": STACK_BASED,
			"max_stacks": 10,
			"decay_style": DECAY_NONE,
			"falls_off_between_turns": true,
			"is_debuff": false,
			"can_be_cleansed": true,
			"cleanse_tags": ["buff", "dodge", "defensive"],
		},
		{
			"status_id": "ignition",
			"affix_name": "Ignition",
			"description": "A combustible resource consumed by fire abilities for bonus effects.",
			"category": CAT_MISC,
			"duration_type": STACK_BASED,
			"max_stacks": 99,
			"decay_style": DECAY_NONE,
			"is_debuff": false,
			"can_be_cleansed": false,
			"cleanse_tags": ["buff", "ignition", "resource"],
		},
	]
