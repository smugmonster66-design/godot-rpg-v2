@tool
extends EditorScript

## Run this once in Godot (Script > Run) to create the frozen.tres StatusAffix.
## Frozen is applied when Chill reaches its stack threshold (10 stacks).
## It acts as a short stun — the target loses their next turn.

func _run():
	# Load the StatusAffix script
	var script = load("res://resources/data/status_affix.gd")
	if not script:
		print("❌ Could not load status_affix.gd")
		return
	
	var frozen = StatusAffix.new()
	
	# Identity
	frozen.status_id = "frozen"
	frozen.affix_name = "Frozen"
	frozen.description = "Frozen solid. Lose your next turn. Takes 2× damage from physical attacks while frozen."
	frozen.show_in_summary = false
	
	# Duration — short turn-based
	frozen.duration_type = StatusAffix.DurationType.TURN_BASED
	frozen.default_duration = 1
	frozen.max_stacks = 1
	frozen.refresh_on_reapply = true
	
	# No decay — expires purely by turn count
	frozen.decay_style = StatusAffix.DecayStyle.NONE
	frozen.falls_off_between_turns = false
	
	# Timing
	frozen.tick_timing = StatusAffix.TickTiming.START_OF_TURN
	frozen.expire_timing = StatusAffix.TickTiming.END_OF_TURN
	
	# No tick damage — Frozen is a control effect
	frozen.damage_per_stack = 0
	frozen.tick_damage_type = StatusAffix.StatusDamageType.NONE
	frozen.heal_per_stack = 0
	
	# No threshold on Frozen itself
	frozen.stack_threshold = 0
	
	# Classification
	frozen.is_debuff = true
	frozen.can_be_cleansed = true
	frozen.cleanse_tags = ["debuff", "cc", "frozen", "ice", "stun"]
	
	# Category — use the same MISC category as stun
	frozen.category = Affix.Category.MISC
	
	# Save
	DirAccess.make_dir_recursive_absolute("res://resources/statuses")
	var err = ResourceSaver.save(frozen, "res://resources/statuses/frozen.tres")
	if err == OK:
		print("✅ Frozen status saved to res://resources/statuses/frozen.tres")
	else:
		print("❌ Failed to save frozen.tres: error %d" % err)
