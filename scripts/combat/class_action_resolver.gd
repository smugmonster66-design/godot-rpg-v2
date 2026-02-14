# res://scripts/combat/class_action_resolver.gd
# Resolves the effective class action by applying skill-based modifications.
#
# v6 — Class Action System
#
# Usage:
#   var resolver = ClassActionResolver.new()
#   var effective = resolver.resolve(base_action, affix_manager, context)
#
# The resolver CLONES the base action before applying any modifications.
# The original .tres resource is never mutated.
extends RefCounted
class_name ClassActionResolver

# ============================================================================
# SIGNALS (for debugging / combat log)
# ============================================================================
signal action_resolved(base_name: String, effective_name: String, mod_count: int)
signal stat_modified(property: String, operation: String, value: float)
signal effect_added(effect_name: String)
signal effect_replaced(index: int, old_name: String, new_name: String)
signal action_upgraded(old_name: String, new_name: String)
signal conditional_added(condition_type: String, effect_name: String)

# ============================================================================
# CONFIGURATION
# ============================================================================
var debug_logging: bool = false

# ============================================================================
# MAIN RESOLVE
# ============================================================================

func resolve(base_action: Action, affix_manager: AffixPoolManager,
		context: Dictionary = {}) -> Action:
	"""Build the effective class action from base + all active modifiers.
	
	Processing order:
	  1. Check for CLASS_ACTION_UPGRADE (last one wins — full replacement)
	  2. Apply all CLASS_ACTION_STAT_MOD (additive first, then multiplicative)
	  3. Apply all CLASS_ACTION_EFFECT_ADD (append to effects array)
	  4. Apply all CLASS_ACTION_EFFECT_REPLACE (swap by index)
	  5. Collect all CLASS_ACTION_CONDITIONAL (store as metadata)
	
	Args:
		base_action: The Action .tres from PlayerClass.class_action.
		affix_manager: Player's AffixPoolManager with active affixes.
		context: Runtime context for condition checking on affixes.
	
	Returns:
		A runtime-modified Action clone. Never the original resource.
	"""
	if not base_action:
		push_warning("ClassActionResolver: null base_action")
		return null
	
	var mods: Dictionary = affix_manager.get_class_action_modifiers()
	
	# ── Step 1: Check for upgrades ──
	var working_action: Action = _check_upgrades(base_action, mods, context)
	
	# ── Step 2: Clone the action we're working with ──
	working_action = _deep_clone_action(working_action)
	
	# ── Step 3: Apply stat mods ──
	_apply_stat_mods(working_action, mods, context)
	
	# ── Step 4: Apply effect additions ──
	_apply_effect_adds(working_action, mods, context)
	
	# ── Step 5: Apply effect replacements ──
	_apply_effect_replacements(working_action, mods, context)
	
	# ── Step 6: Collect conditionals ──
	_collect_conditionals(working_action, mods, context)
	
	var mod_count := _count_applied_mods(mods)
	if debug_logging and mod_count > 0:
		print("  🎯 ClassAction resolved: '%s' with %d mods applied" % [
			working_action.action_name, mod_count])
	
	action_resolved.emit(base_action.action_name,
		working_action.action_name, mod_count)
	
	return working_action


# ============================================================================
# STEP 1: UPGRADE CHECK
# ============================================================================

func _check_upgrades(base: Action, mods: Dictionary,
		context: Dictionary) -> Action:
	"""Check for CLASS_ACTION_UPGRADE affixes. Last valid one wins.
	
	Returns the action to use as the base (may be the original or
	a replacement from an upgrade affix).
	"""
	var upgrades: Array = mods.get(Affix.Category.CLASS_ACTION_UPGRADE, [])
	if upgrades.is_empty():
		return base
	
	# Iterate in order; last one that passes conditions wins
	var best_upgrade: Action = null
	for affix in upgrades:
		if not affix is Affix:
			continue
		
		# Condition check
		if affix.has_condition() and context.size() > 0:
			if not affix.check_condition(context):
				continue
		
		if affix.granted_action:
			best_upgrade = affix.granted_action
	
	if best_upgrade:
		if debug_logging:
			print("  ⬆️ Class action upgraded: '%s' → '%s'" % [
				base.action_name, best_upgrade.action_name])
		action_upgraded.emit(base.action_name, best_upgrade.action_name)
		return best_upgrade
	
	return base


# ============================================================================
# STEP 2: DEEP CLONE
# ============================================================================

func _deep_clone_action(action: Action) -> Action:
	"""Create a runtime copy of an Action so we never mutate .tres files.
	
	Duplicates the Action and its effects array. Does NOT duplicate
	individual ActionEffect resources (they're read-only references).
	New effects added by mods are separate resources anyway.
	"""
	var clone: Action = action.duplicate(false)
	
	# Deep-copy the effects array so appends/replacements don't
	# modify the original resource's array
	var cloned_effects: Array[ActionEffect] = []
	cloned_effects.assign(action.effects.duplicate())
	clone.effects = cloned_effects
	
	return clone


# ============================================================================
# STEP 3: STAT MODS
# ============================================================================

## Properties that can be modified via CLASS_ACTION_STAT_MOD.
## Maps property name → {type, min, max} for validation and clamping.
const MODIFIABLE_PROPERTIES := {
	"die_slots":          {"type": "int",   "min": 1, "max": 6},
	"min_dice_required":  {"type": "int",   "min": 0, "max": 6},
	"mana_cost":          {"type": "int",   "min": 0, "max": 999},
	"cooldown_turns":     {"type": "int",   "min": 0, "max": 10},
	"max_charges":        {"type": "int",   "min": 1, "max": 99},
	"base_damage":        {"type": "int",   "min": 0, "max": 9999},
	"damage_multiplier":  {"type": "float", "min": 0.0, "max": 99.0},
}

func _apply_stat_mods(action: Action, mods: Dictionary,
		context: Dictionary) -> void:
	"""Apply CLASS_ACTION_STAT_MOD affixes to the action clone.
	
	Processing order: all "add" operations first, then all "multiply".
	This prevents order-dependent stacking issues.
	"""
	var stat_mods: Array = mods.get(Affix.Category.CLASS_ACTION_STAT_MOD, [])
	if stat_mods.is_empty():
		return
	
	# Separate into add and multiply passes
	var adds: Array[Affix] = []
	var multiplies: Array[Affix] = []
	
	for affix in stat_mods:
		if not affix is Affix:
			continue
		if affix.has_condition() and context.size() > 0:
			if not affix.check_condition(context):
				continue
		
		var op: String = affix.effect_data.get("operation", "add")
		if op == "multiply":
			multiplies.append(affix)
		else:
			adds.append(affix)
	
	# Pass 1: Additive
	for affix in adds:
		_apply_single_stat_mod(action, affix, "add")
	
	# Pass 2: Multiplicative
	for affix in multiplies:
		_apply_single_stat_mod(action, affix, "multiply")


func _apply_single_stat_mod(action: Action, affix: Affix,
		operation: String) -> void:
	"""Apply a single stat modification to the action."""
	var prop: String = affix.effect_data.get("property", "")
	if prop.is_empty() or not MODIFIABLE_PROPERTIES.has(prop):
		push_warning("ClassActionResolver: unknown property '%s'" % prop)
		return
	
	var config: Dictionary = MODIFIABLE_PROPERTIES[prop]
	var current_value = action.get(prop)
	var mod_value: float = affix.effect_number
	var new_value: float
	
	match operation:
		"add":
			new_value = current_value + mod_value
		"multiply":
			new_value = current_value * mod_value
		_:
			push_warning("ClassActionResolver: unknown operation '%s'" % operation)
			return
	
	# Clamp to valid range
	new_value = clampf(new_value, config["min"], config["max"])
	
	# Apply as int or float based on property type
	if config["type"] == "int":
		action.set(prop, int(new_value))
	else:
		action.set(prop, new_value)
	
	if debug_logging:
		print("  📊 Class action stat: %s %s %.2f → %.2f" % [
			prop, operation, current_value, new_value])
	
	stat_modified.emit(prop, operation, mod_value)


# ============================================================================
# STEP 4: EFFECT ADDITIONS
# ============================================================================

func _apply_effect_adds(action: Action, mods: Dictionary,
		context: Dictionary) -> void:
	"""Append new ActionEffects to the class action's effect chain."""
	var effect_adds: Array = mods.get(
		Affix.Category.CLASS_ACTION_EFFECT_ADD, [])
	
	for affix in effect_adds:
		if not affix is Affix:
			continue
		if affix.has_condition() and context.size() > 0:
			if not affix.check_condition(context):
				continue
		
		var new_effect: ActionEffect = affix.effect_data.get("action_effect")
		if new_effect:
			action.effects.append(new_effect)
			if debug_logging:
				print("  ➕ Class action effect added: '%s'" % new_effect.effect_name)
			effect_added.emit(new_effect.effect_name)


# ============================================================================
# STEP 5: EFFECT REPLACEMENTS
# ============================================================================

func _apply_effect_replacements(action: Action, mods: Dictionary,
		context: Dictionary) -> void:
	"""Replace ActionEffects at specific indices in the effect chain."""
	var replacements: Array = mods.get(
		Affix.Category.CLASS_ACTION_EFFECT_REPLACE, [])
	
	for affix in replacements:
		if not affix is Affix:
			continue
		if affix.has_condition() and context.size() > 0:
			if not affix.check_condition(context):
				continue
		
		var index: int = affix.effect_data.get("effect_index", -1)
		var new_effect: ActionEffect = affix.effect_data.get("action_effect")
		
		if index < 0 or index >= action.effects.size():
			push_warning("ClassActionResolver: effect_index %d out of range (0-%d)" % [
				index, action.effects.size() - 1])
			continue
		
		if new_effect:
			var old_name: String = action.effects[index].effect_name if action.effects[index] else "null"
			action.effects[index] = new_effect
			if debug_logging:
				print("  🔄 Class action effect[%d] replaced: '%s' → '%s'" % [
					index, old_name, new_effect.effect_name])
			effect_replaced.emit(index, old_name, new_effect.effect_name)


# ============================================================================
# STEP 6: CONDITIONALS
# ============================================================================

func _collect_conditionals(action: Action, mods: Dictionary,
		context: Dictionary) -> void:
	"""Collect conditional rider effects and store as action metadata.
	
	Conditionals are stored in a runtime-only array on the action clone.
	Combat execution checks these during action resolution.
	
	Two-layer condition model:
	  - The affix's own condition gates whether the rider is COLLECTED
	    (i.e., is this skill active / does context permit it).
	  - The rider's inner condition gates whether it FIRES in combat
	    (i.e., does the target have Burn? Is HP below threshold?).
	"""
	var conditionals: Array = mods.get(
		Affix.Category.CLASS_ACTION_CONDITIONAL, [])
	
	if conditionals.is_empty():
		return
	
	var riders: Array[Dictionary] = []
	
	for affix in conditionals:
		if not affix is Affix:
			continue
		# Outer condition: does this affix apply at all?
		if affix.has_condition() and context.size() > 0:
			if not affix.check_condition(context):
				continue
		
		var rider_condition = affix.effect_data.get("condition")
		var rider_effect: ActionEffect = affix.effect_data.get("action_effect")
		
		if rider_effect:
			riders.append({
				"condition": rider_condition,
				"effect": rider_effect,
				"source": affix.affix_name,
			})
			if debug_logging:
				var cond_name = rider_condition.get_description() if rider_condition else "always"
				print("  🔮 Conditional rider: '%s' when %s" % [
					rider_effect.effect_name, cond_name])
			conditional_added.emit(
				rider_condition.get_description() if rider_condition else "always",
				rider_effect.effect_name)
	
	if riders.size() > 0:
		# Store as runtime metadata — not persisted, not exported
		action.set_meta("conditional_riders", riders)



# ============================================================================
# HELPERS
# ============================================================================

func _count_applied_mods(mods: Dictionary) -> int:
	"""Count total modifier affixes across all CLASS_ACTION_* categories."""
	var count := 0
	for cat in mods:
		count += mods[cat].size()
	return count
