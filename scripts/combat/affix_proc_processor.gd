# res://scripts/combat/affix_proc_processor.gd
# Lightweight processor for item-level proc effects (PROC, ON_HIT, PER_TURN).
# Called by CombatManager at specific hook points during combat.
#
# Unlike DiceAffixProcessor (which operates on dice), this operates on
# Affix resources from the player's AffixPoolManager — meaning skills,
# equipment, and set bonuses can all contribute proc effects.
#
# USAGE:
#   var proc_processor = AffixProcProcessor.new()
#   var results = proc_processor.process_procs(
#       player.affix_manager,
#       Affix.ProcTrigger.ON_DEAL_DAMAGE,
#       {"damage_dealt": 42, "damage_type": ActionEffect.DamageType.SLASHING}
#   )
#   # Then apply results (heal player, add temp buffs, etc.)
extends RefCounted
class_name AffixProcProcessor

# ============================================================================
# SIGNALS
# ============================================================================
signal proc_activated(affix: Affix, trigger: Affix.ProcTrigger, result: Dictionary)
signal proc_effect_applied(affix: Affix, effect: Dictionary)

# ============================================================================
# MAIN PROCESSING
# ============================================================================

func process_procs(
	affix_manager: AffixPoolManager,
	trigger: Affix.ProcTrigger,
	context: Dictionary = {}
) -> Dictionary:
	"""Process all proc-capable affixes for a given trigger.
	
	Checks PROC, ON_HIT, and PER_TURN pools. Each affix is evaluated for:
	  1. Trigger match
	  2. Proc chance roll
	  3. Optional condition check (via effect_data)
	  4. Effect application
	
	Args:
		affix_manager: Player's AffixPoolManager containing all active affixes.
		trigger: Which hook point is firing.
		context: Runtime state from combat. Keys may include:
			- damage_dealt (int): Total damage just dealt.
			- damage_type (ActionEffect.DamageType): Primary damage type.
			- damage_taken (int): Damage just received by player.
			- action_name (String): Name of action used.
			- action_resource (Action): The Action resource used.
			- placed_dice (Array[DieResource]): Dice used in the action.
			- target (Combatant): Target of the action.
			- source (Combatant): Source of the action.
			- turn_number (int): Current combat turn.
			- round_number (int): Current combat round.
	
	Returns:
		{
			"activated": Array[Dictionary],  # Each proc that fired
			"healing": float,                # Total healing to apply
			"bonus_damage": float,           # Extra damage to apply
			"temp_affixes": Array[Affix],    # Temporary affixes to register
			"temp_dice_affixes": Array[DiceAffix],  # Temp dice affixes
			"granted_actions": Array[Action], # Actions to temporarily grant
			"status_effects": Array[Dictionary], # Status effects to apply
			"special_effects": Array[Dictionary], # For UI/animation hooks
		}
	"""
	var result = _make_empty_result()
	
	# Gather proc-capable affixes from all relevant pools
	var candidates: Array[Affix] = []
	candidates.append_array(_get_typed_array(affix_manager.get_pool(Affix.Category.PROC)))
	candidates.append_array(_get_typed_array(affix_manager.get_pool(Affix.Category.ON_HIT)))
	candidates.append_array(_get_typed_array(affix_manager.get_pool(Affix.Category.PER_TURN)))
	
	for affix in candidates:
		# 1. Check trigger match
		if affix.proc_trigger != trigger:
			continue
		
		# 2. Check optional conditions
		if not _check_proc_condition(affix, context):
			continue
		
		# 3. Roll proc chance
		if not _roll_proc_chance(affix):
			continue
		
		# 4. Apply effect
		var effect_result = _apply_proc_effect(affix, context)
		_merge_effect_result(result, effect_result)
		
		result.activated.append({
			"affix": affix,
			"trigger": trigger,
			"effect": effect_result,
		})
		
		proc_activated.emit(affix, trigger, effect_result)
	
	return result

# ============================================================================
# TARGETED PROCESSING — Single category shorthand
# ============================================================================

func process_on_hit(affix_manager: AffixPoolManager, context: Dictionary = {}) -> Dictionary:
	"""Shorthand for ON_DEAL_DAMAGE procs."""
	return process_procs(affix_manager, Affix.ProcTrigger.ON_DEAL_DAMAGE, context)

func process_on_take_damage(affix_manager: AffixPoolManager, context: Dictionary = {}) -> Dictionary:
	"""Shorthand for ON_TAKE_DAMAGE procs."""
	return process_procs(affix_manager, Affix.ProcTrigger.ON_TAKE_DAMAGE, context)

func process_turn_start(affix_manager: AffixPoolManager, context: Dictionary = {}) -> Dictionary:
	"""Shorthand for ON_TURN_START procs."""
	return process_procs(affix_manager, Affix.ProcTrigger.ON_TURN_START, context)

func process_turn_end(affix_manager: AffixPoolManager, context: Dictionary = {}) -> Dictionary:
	"""Shorthand for ON_TURN_END procs."""
	return process_procs(affix_manager, Affix.ProcTrigger.ON_TURN_END, context)

func process_combat_start(affix_manager: AffixPoolManager, context: Dictionary = {}) -> Dictionary:
	"""Shorthand for ON_COMBAT_START procs."""
	return process_procs(affix_manager, Affix.ProcTrigger.ON_COMBAT_START, context)

# ============================================================================
# CONDITION CHECKING
# ============================================================================

func _check_proc_condition(affix: Affix, context: Dictionary) -> bool:
	"""Check if an affix's optional condition is met.
	
	Conditions are stored in affix.effect_data under the "condition" key.
	If no condition is present, the proc always passes this check.
	"""
	var condition = affix.effect_data.get("condition", "")
	if condition == "":
		return true
	
	match condition:
		"damage_above":
			# Only fires if damage dealt exceeds threshold
			var threshold = affix.effect_data.get("threshold", 0)
			return context.get("damage_dealt", 0) > threshold
		
		"damage_below":
			var threshold = affix.effect_data.get("threshold", 0)
			return context.get("damage_dealt", 0) < threshold
		
		"health_below_percent":
			# Fires when player health is below X% of max
			var source = context.get("source", null)
			var threshold = affix.effect_data.get("threshold", 0.5)
			if source and source.has_method("get_health_percent"):
				return source.get_health_percent() < threshold
			return false
		
		"health_above_percent":
			var source = context.get("source", null)
			var threshold = affix.effect_data.get("threshold", 0.5)
			if source and source.has_method("get_health_percent"):
				return source.get_health_percent() > threshold
			return false
		
		"damage_type_is":
			# Only fires for a specific damage type
			var required_type = affix.effect_data.get("required_damage_type", "")
			var actual_type = context.get("damage_type", null)
			if actual_type != null and required_type != "":
				return str(actual_type) == required_type
			return false
		
		"has_heavy_weapon":
			# Check if player has a two-handed weapon equipped
			var player = context.get("player", null)
			if player and player.equipment.has("Main Hand"):
				var item = player.equipment.get("Main Hand")
				return item != null and item.get("is_heavy", false)
			return false
		
		"has_dual_wield":
			# Check if both weapon slots are filled
			var player = context.get("player", null)
			if player:
				var main = player.equipment.get("Main Hand")
				var off = player.equipment.get("Off Hand")
				return main != null and off != null
			return false
		
		"equipment_slots_filled":
			# Fires if at least N equipment slots are filled
			var required = affix.effect_data.get("required_slots", 1)
			var player = context.get("player", null)
			if player:
				var filled = 0
				for slot in player.equipment:
					if player.equipment[slot] != null:
						filled += 1
				return filled >= required
			return false
		
		"turn_number_above":
			var threshold = affix.effect_data.get("threshold", 0)
			return context.get("turn_number", 0) > threshold
		
		_:
			print("⚠️ AffixProcProcessor: Unknown condition '%s'" % condition)
			return true

# ============================================================================
# CHANCE ROLLING
# ============================================================================

func _roll_proc_chance(affix: Affix) -> bool:
	"""Roll against the affix's proc_chance. Returns true if proc fires."""
	if affix.proc_chance >= 1.0:
		return true
	if affix.proc_chance <= 0.0:
		return false
	return randf() < affix.proc_chance

# ============================================================================
# EFFECT APPLICATION
# ============================================================================

func _apply_proc_effect(affix: Affix, context: Dictionary) -> Dictionary:
	"""Apply a single affix's proc effect and return the result.
	
	The proc_effect field on the Affix determines what happens.
	Falls back to category-based behavior for backwards compatibility.
	"""
	var effect: Dictionary = {
		"type": "none",
		"affix_name": affix.affix_name,
		"source": affix.source,
	}
	
	var proc_effect = affix.effect_data.get("proc_effect", "")
	
	# If no explicit proc_effect, infer from category
	if proc_effect == "":
		proc_effect = _infer_effect_from_category(affix)
	
	match proc_effect:
		# ── Healing ──
		"heal_flat":
			# Heal a flat amount
			effect.type = "healing"
			effect["amount"] = affix.effect_number
		
		"heal_percent_damage":
			# Heal a percentage of damage dealt (leech)
			var damage_dealt = context.get("damage_dealt", 0)
			effect.type = "healing"
			effect["amount"] = damage_dealt * affix.effect_number
		
		"heal_percent_max_hp":
			# Heal a percentage of max HP
			var source = context.get("source", null)
			var max_hp = 100
			if source and source.has_method("get") and source.get("max_health"):
				max_hp = source.max_health
			effect.type = "healing"
			effect["amount"] = max_hp * affix.effect_number
		
		# ── Bonus Damage ──
		"bonus_damage_flat":
			# Add flat bonus damage
			effect.type = "bonus_damage"
			effect["amount"] = affix.effect_number
		
		"bonus_damage_percent":
			# Add percentage of damage dealt as bonus damage
			var damage_dealt = context.get("damage_dealt", 0)
			effect.type = "bonus_damage"
			effect["amount"] = damage_dealt * affix.effect_number
		
		# ── Temporary Stat Buffs ──
		"temp_affix":
			# Register a temporary affix for N turns
			# The affix to apply is stored in effect_data["temp_affix"]
			# Duration in turns stored in effect_data["duration"]
			var temp = affix.effect_data.get("temp_affix", null)
			if temp is Affix:
				effect.type = "temp_affix"
				effect["affix"] = temp
				effect["duration"] = affix.effect_data.get("duration", 1)
		
		# ── Status Effects ──
		"apply_status":
			# Apply a status effect to the target
			# Status data stored in effect_data["status"]
			effect.type = "status_effect"
			effect["status"] = affix.effect_data.get("status", {})
			effect["target"] = affix.effect_data.get("status_target", "enemy")  # "enemy" or "self"
		
		# ── Dice Manipulation ──
		"grant_temp_dice_affix":
			# Apply a temporary DiceAffix to all dice for N turns
			var dice_affix = affix.effect_data.get("dice_affix", null)
			if dice_affix is DiceAffix:
				effect.type = "temp_dice_affix"
				effect["dice_affix"] = dice_affix
				effect["duration"] = affix.effect_data.get("duration", 1)
		
		# ── Armor / Barrier ──
		"gain_armor":
			effect.type = "gain_armor"
			effect["amount"] = affix.effect_number
		
		"gain_barrier":
			effect.type = "gain_barrier"
			effect["amount"] = affix.effect_number
		
		# ── Action Grant ──
		"grant_action":
			# Temporarily grant a combat action
			if affix.granted_action:
				effect.type = "granted_action"
				effect["action"] = affix.granted_action
				effect["duration"] = affix.effect_data.get("duration", 1)
		
		# ── Retrigger (for Overforge-style effects) ──
		"retrigger_dice_affixes":
			# Signals that dice affixes should be re-processed
			# The combat manager handles the actual re-processing
			effect.type = "retrigger_dice_affixes"
			effect["trigger_to_replay"] = affix.effect_data.get("trigger_to_replay", "ON_USE")
		
		# ── Stacking Buff (for Whetstone-style effects) ──
		"stacking_buff":
			# Accumulates stacks each time it fires. The actual bonus
			# is effect_number * current_stacks. Stack count is tracked
			# in the affix's effect_data at runtime.
			var stacks = affix.effect_data.get("_current_stacks", 0) + 1
			var max_stacks = affix.effect_data.get("max_stacks", 99)
			stacks = mini(stacks, max_stacks)
			affix.effect_data["_current_stacks"] = stacks
			
			effect.type = "stacking_buff"
			effect["stacks"] = stacks
			effect["value_per_stack"] = affix.effect_number
			effect["total_value"] = affix.effect_number * stacks
			effect["buff_category"] = affix.effect_data.get("buff_category", "DAMAGE_BONUS")
		
		# ── Generic / Custom ──
		"custom":
			# Pass-through for effects that need custom handling
			# The combat manager checks effect_data["custom_id"] to decide what to do
			effect.type = "custom"
			effect["custom_id"] = affix.effect_data.get("custom_id", "")
			effect["custom_data"] = affix.effect_data.get("custom_data", {})
		
		_:
			print("⚠️ AffixProcProcessor: Unknown proc_effect '%s' on '%s'" % [proc_effect, affix.affix_name])
			effect.type = "unknown"
	
	proc_effect_applied.emit(affix, effect)
	return effect

# ============================================================================
# CATEGORY INFERENCE — Backwards compat for affixes without explicit proc_effect
# ============================================================================

func _infer_effect_from_category(affix: Affix) -> String:
	"""If no proc_effect is set, try to infer from the affix category."""
	match affix.category:
		Affix.Category.ON_HIT:
			# Default ON_HIT behavior: bonus damage
			return "bonus_damage_flat"
		Affix.Category.PER_TURN:
			# Default PER_TURN behavior: stacking buff
			return "stacking_buff"
		Affix.Category.PROC:
			# PROC with no proc_effect — just use effect_number as bonus damage
			return "bonus_damage_flat"
		_:
			return ""

# ============================================================================
# RESULT HELPERS
# ============================================================================

func _make_empty_result() -> Dictionary:
	return {
		"activated": [],
		"healing": 0.0,
		"bonus_damage": 0.0,
		"temp_affixes": [],
		"temp_dice_affixes": [],
		"granted_actions": [],
		"status_effects": [],
		"special_effects": [],
	}

func _merge_effect_result(result: Dictionary, effect: Dictionary):
	"""Merge a single effect into the aggregate result."""
	match effect.get("type", ""):
		"healing":
			result.healing += effect.get("amount", 0.0)
			result.special_effects.append({
				"type": "proc_heal",
				"amount": effect.get("amount", 0.0),
				"source": effect.get("affix_name", ""),
			})
		
		"bonus_damage":
			result.bonus_damage += effect.get("amount", 0.0)
			result.special_effects.append({
				"type": "proc_bonus_damage",
				"amount": effect.get("amount", 0.0),
				"source": effect.get("affix_name", ""),
			})
		
		"temp_affix":
			var affix = effect.get("affix", null)
			if affix:
				result.temp_affixes.append(affix)
		
		"status_effect":
			result.status_effects.append(effect.get("status", {}))
		
		"temp_dice_affix":
			var dice_affix = effect.get("dice_affix", null)
			if dice_affix:
				result.temp_dice_affixes.append(dice_affix)
		
		"granted_action":
			var action = effect.get("action", null)
			if action:
				result.granted_actions.append(action)
		
		"retrigger_dice_affixes":
			result.special_effects.append({
				"type": "retrigger_dice_affixes",
				"trigger_to_replay": effect.get("trigger_to_replay", "ON_USE"),
				"source": effect.get("affix_name", ""),
			})
		
		"stacking_buff":
			result.special_effects.append({
				"type": "stacking_buff",
				"stacks": effect.get("stacks", 0),
				"total_value": effect.get("total_value", 0.0),
				"buff_category": effect.get("buff_category", "DAMAGE_BONUS"),
				"source": effect.get("affix_name", ""),
			})
		
		"gain_armor":
			result.special_effects.append({
				"type": "proc_gain_armor",
				"amount": effect.get("amount", 0.0),
				"source": effect.get("affix_name", ""),
			})
		
		"gain_barrier":
			result.special_effects.append({
				"type": "proc_gain_barrier",
				"amount": effect.get("amount", 0.0),
				"source": effect.get("affix_name", ""),
			})

# ============================================================================
# COMBAT LIFECYCLE — Call these to reset state between combats
# ============================================================================

func on_combat_start(affix_manager: AffixPoolManager):
	"""Reset stacking buffs and other per-combat state."""
	_reset_stacking_buffs(affix_manager)

func on_combat_end(affix_manager: AffixPoolManager):
	"""Clean up any runtime state on affixes."""
	_reset_stacking_buffs(affix_manager)

func _reset_stacking_buffs(affix_manager: AffixPoolManager):
	"""Clear _current_stacks from all proc affixes."""
	for category in [Affix.Category.PROC, Affix.Category.ON_HIT, Affix.Category.PER_TURN]:
		for affix in affix_manager.get_pool(category):
			if affix.effect_data.has("_current_stacks"):
				affix.effect_data["_current_stacks"] = 0

# ============================================================================
# UTILITY
# ============================================================================

func _get_typed_array(pool: Array) -> Array[Affix]:
	"""Convert untyped pool array to typed Array[Affix]."""
	var typed: Array[Affix] = []
	for item in pool:
		if item is Affix:
			typed.append(item)
	return typed
