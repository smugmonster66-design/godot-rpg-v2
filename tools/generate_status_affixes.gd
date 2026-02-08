# res://tools/generate_status_affixes.gd
# Run via Editor > Script > Run (Ctrl+Shift+X) to generate all status .tres files.
# Creates files in res://resources/statuses/
@tool
extends EditorScript

func _run():
	print("=== Generating StatusAffix Resources ===")
	
	# Ensure output directory exists
	var dir = DirAccess.open("res://resources")
	if dir:
		if not dir.dir_exists("statuses"):
			dir.make_dir("statuses")
	else:
		push_error("Cannot open res://resources/")
		return
	
	var count = 0
	for def in _get_all_definitions():
		var affix = _create_status_affix(def)
		var path = "res://resources/statuses/%s.tres" % def["status_id"]
		var err = ResourceSaver.save(affix, path)
		if err == OK:
			print("  ✓ Created: %s" % path)
			count += 1
		else:
			push_error("  ✗ Failed to save: %s (error %d)" % [path, err])
	
	print("=== Done: %d StatusAffix resources generated ===" % count)

func _create_status_affix(def: Dictionary) -> StatusAffix:
	var s = StatusAffix.new()
	
	# Identity (StatusAffix)
	s.status_id = def["status_id"]
	
	# Inherited Affix fields
	s.affix_name = def["affix_name"]
	s.description = def["description"]
	s.category = def.get("category", Affix.Category.MISC)
	s.show_in_summary = false  # Statuses show via their own UI, not item tooltips
	
	# Duration & Stacking
	s.duration_type = def.get("duration_type", StatusAffix.DurationType.STACK_BASED)
	s.default_duration = def.get("default_duration", 3)
	s.max_stacks = def.get("max_stacks", 99)
	s.refresh_on_reapply = def.get("refresh_on_reapply", true)
	
	# Decay
	s.decay_style = def.get("decay_style", StatusAffix.DecayStyle.NONE)
	s.decay_amount = def.get("decay_amount", 1)
	s.falls_off_between_turns = def.get("falls_off_between_turns", false)
	
	# Timing
	s.tick_timing = def.get("tick_timing", StatusAffix.TickTiming.START_OF_TURN)
	s.expire_timing = def.get("expire_timing", StatusAffix.TickTiming.END_OF_TURN)
	
	# Classification
	s.is_debuff = def.get("is_debuff", true)
	s.can_be_cleansed = def.get("can_be_cleansed", true)
	s.cleanse_tags = def.get("cleanse_tags", [])
	
	# Tick Effects
	s.damage_per_stack = def.get("damage_per_stack", 0)
	s.tick_damage_type = def.get("tick_damage_type", StatusAffix.StatusDamageType.NONE)
	s.heal_per_stack = def.get("heal_per_stack", 0)
	s.stat_modifier_per_stack = def.get("stat_modifier_per_stack", {})
	
	return s

func _get_all_definitions() -> Array[Dictionary]:
	return [
		# ==================================================================
		# DAMAGE-OVER-TIME (DoTs)
		# ==================================================================
		{
			"status_id": "poison",
			"affix_name": "Poison",
			"description": "Deals physical damage at the start of each turn. Stacks halve after each tick.",
			"category": Affix.Category.PER_TURN,
			"duration_type": StatusAffix.DurationType.STACK_BASED,
			"max_stacks": 99,
			"decay_style": StatusAffix.DecayStyle.HALVING,
			"tick_timing": StatusAffix.TickTiming.START_OF_TURN,
			"damage_per_stack": 1,
			"tick_damage_type": StatusAffix.StatusDamageType.PHYSICAL,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "dot", "poison", "physical_dot"],
		},
		{
			"status_id": "burn",
			"affix_name": "Burn",
			"description": "Deals magical damage at the end of each turn for a set duration.",
			"category": Affix.Category.PER_TURN,
			"duration_type": StatusAffix.DurationType.TURN_BASED,
			"default_duration": 3,
			"max_stacks": 99,
			"decay_style": StatusAffix.DecayStyle.NONE,
			"tick_timing": StatusAffix.TickTiming.END_OF_TURN,
			"expire_timing": StatusAffix.TickTiming.END_OF_TURN,
			"damage_per_stack": 1,
			"tick_damage_type": StatusAffix.StatusDamageType.MAGICAL,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "dot", "burn", "fire", "magical_dot"],
		},
		{
			"status_id": "bleed",
			"affix_name": "Bleed",
			"description": "Deals physical damage at the start of each turn. Loses 1 stack per tick.",
			"category": Affix.Category.PER_TURN,
			"duration_type": StatusAffix.DurationType.STACK_BASED,
			"max_stacks": 99,
			"decay_style": StatusAffix.DecayStyle.FLAT,
			"decay_amount": 1,
			"tick_timing": StatusAffix.TickTiming.START_OF_TURN,
			"damage_per_stack": 1,
			"tick_damage_type": StatusAffix.StatusDamageType.PHYSICAL,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "dot", "bleed", "physical_dot"],
		},
		{
			"status_id": "shadow",
			"affix_name": "Shadow",
			"description": "Deals magical damage at the start of each turn. Stacks halve after each tick.",
			"category": Affix.Category.PER_TURN,
			"duration_type": StatusAffix.DurationType.STACK_BASED,
			"max_stacks": 99,
			"decay_style": StatusAffix.DecayStyle.HALVING,
			"tick_timing": StatusAffix.TickTiming.START_OF_TURN,
			"damage_per_stack": 1,
			"tick_damage_type": StatusAffix.StatusDamageType.MAGICAL,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "dot", "shadow", "magical_dot"],
		},
		
		# ==================================================================
		# DEBUFFS — CONTROL / IMPAIRMENT
		# ==================================================================
		{
			"status_id": "chill",
			"affix_name": "Chill",
			"description": "Every 2 stacks reduces die values by 1. Does not decay naturally.",
			"category": Affix.Category.MISC,
			"duration_type": StatusAffix.DurationType.STACK_BASED,
			"max_stacks": 99,
			"decay_style": StatusAffix.DecayStyle.NONE,
			"tick_timing": StatusAffix.TickTiming.START_OF_TURN,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "chill", "ice", "slow_effect"],
		},
		{
			"status_id": "slowed",
			"affix_name": "Slowed",
			"description": "Reduces die values by stack amount for a set duration.",
			"category": Affix.Category.MISC,
			"duration_type": StatusAffix.DurationType.TURN_BASED,
			"default_duration": 3,
			"max_stacks": 99,
			"decay_style": StatusAffix.DecayStyle.NONE,
			"tick_timing": StatusAffix.TickTiming.START_OF_TURN,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "slow_effect"],
		},
		{
			"status_id": "stunned",
			"affix_name": "Stunned",
			"description": "Stuns a number of random dice equal to stacks for a set duration.",
			"category": Affix.Category.MISC,
			"duration_type": StatusAffix.DurationType.TURN_BASED,
			"default_duration": 2,
			"max_stacks": 10,
			"decay_style": StatusAffix.DecayStyle.NONE,
			"tick_timing": StatusAffix.TickTiming.START_OF_TURN,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "cc", "stun"],
		},
		{
			"status_id": "corrode",
			"affix_name": "Corrode",
			"description": "Reduces armor for a set duration.",
			"category": Affix.Category.MISC,
			"duration_type": StatusAffix.DurationType.TURN_BASED,
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
			"category": Affix.Category.MISC,
			"duration_type": StatusAffix.DurationType.TURN_BASED,
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
			"category": Affix.Category.MISC,
			"duration_type": StatusAffix.DurationType.STACK_BASED,
			"max_stacks": 50,
			"decay_style": StatusAffix.DecayStyle.NONE,
			"is_debuff": true,
			"cleanse_tags": ["debuff", "expose"],
		},
		
		# ==================================================================
		# BUFFS — DEFENSIVE
		# ==================================================================
		{
			"status_id": "overhealth",
			"affix_name": "Overhealth",
			"description": "Absorbs incoming damage. Decrements each turn.",
			"category": Affix.Category.MISC,
			"duration_type": StatusAffix.DurationType.TURN_BASED,
			"default_duration": 3,
			"max_stacks": 999,
			"decay_style": StatusAffix.DecayStyle.NONE,
			"tick_timing": StatusAffix.TickTiming.START_OF_TURN,
			"expire_timing": StatusAffix.TickTiming.END_OF_TURN,
			"is_debuff": false,
			"can_be_cleansed": true,
			"cleanse_tags": ["buff", "overhealth", "defensive"],
		},
		{
			"status_id": "block",
			"affix_name": "Block",
			"description": "Reduces incoming damage by stack amount. Falls off at the start of your next turn.",
			"category": Affix.Category.DEFENSE_BONUS,
			"duration_type": StatusAffix.DurationType.STACK_BASED,
			"max_stacks": 999,
			"decay_style": StatusAffix.DecayStyle.NONE,
			"falls_off_between_turns": true,
			"is_debuff": false,
			"can_be_cleansed": true,
			"cleanse_tags": ["buff", "block", "defensive"],
		},
		{
			"status_id": "dodge",
			"affix_name": "Dodge",
			"description": "10% chance to evade per stack. Falls off at the start of your next turn.",
			"category": Affix.Category.MISC,
			"duration_type": StatusAffix.DurationType.STACK_BASED,
			"max_stacks": 10,
			"decay_style": StatusAffix.DecayStyle.NONE,
			"falls_off_between_turns": true,
			"is_debuff": false,
			"can_be_cleansed": true,
			"cleanse_tags": ["buff", "dodge", "defensive"],
		},
		
		# ==================================================================
		# BUFFS — RESOURCE
		# ==================================================================
		{
			"status_id": "ignition",
			"affix_name": "Ignition",
			"description": "A combustible resource consumed by fire abilities for bonus effects.",
			"category": Affix.Category.MISC,
			"duration_type": StatusAffix.DurationType.STACK_BASED,
			"max_stacks": 99,
			"decay_style": StatusAffix.DecayStyle.NONE,
			"is_debuff": false,
			"can_be_cleansed": false,
			"cleanse_tags": ["buff", "ignition", "resource"],
		},
	]
