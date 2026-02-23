# res://resources/data/dice_affix_processor.gd
# Processes and applies dice affixes
# Handles position checking, condition evaluation, neighbor targeting,
# dynamic value resolution, compound sub-effects, and effect application.
#
# v2.1 CHANGELOG:
#   - ON_USE trigger now scoped to triggering die via context["triggering_die"]
#   - Consumed dice (is_consumed == true) are skipped during activation collection
#   - The full stable hand array is preserved for neighbor resolution
#   - All other behavior unchanged from v2
#
# v2.2 CHANGELOG:
#   - Added PARENT_TARGET_VALUE/PERCENT and SNAPSHOT_TARGET_VALUE/PERCENT ValueSources
#   - Compound effects now snapshot ALL dice values before sub-effect iteration
#     via context["_compound_snapshot"] (Dict[int, int]: die_index -> pre-mod value)
#   - PARENT_TARGET_* resolves from parent affix's neighbor_target using snapshot
#   - SNAPSHOT_TARGET_* resolves from the sub-effect's own target die using snapshot
#   - _apply_sub_effect and _resolve_value_for_sub accept source_index + parent_affix
#   - New helper: _get_parent_target_die() resolves first die from parent's neighbor_target
extends RefCounted
class_name DiceAffixProcessor

# ============================================================================
# SIGNALS
# ============================================================================
signal affix_activated(die: DieResource, affix: DiceAffix, targets: Array[int])
signal effect_applied(die: DieResource, effect_type: DiceAffix.EffectType, value)

# ============================================================================
# MAIN PROCESSING
# ============================================================================

func process_trigger(dice: Array[DieResource], trigger: DiceAffix.Trigger, context: Dictionary = {}) -> Dictionary:
	"""Process all affixes with a specific trigger across all dice.
	
	Args:
		dice: The array of dice to process (hand or pool). For ON_USE, this
		      should be the FULL stable hand (not a single-die wrapper) so
		      that neighbor targeting works correctly.
		trigger: Which trigger to fire.
		context: Runtime state from PlayerDiceCollection. Keys may include:
			- used_count (int): How many dice consumed so far this turn.
			- used_indices (Array[int]): Pool slot indices of consumed dice.
			- original_hand_size (int): Hand size at start of turn.
			- turn_number (int): Current combat turn.
			- combat_modifiers (Array[CombatModifier]): Active persistent mods.
			- triggering_die (DieResource): [ON_USE only] The die being used.
			- triggering_index (int): [ON_USE only] Index of triggering die in hand.
	
	Returns a dictionary of changes made:
	{
		"value_changes": {die_index: {old: X, new: Y}},
		"tags_added": {die_index: [tags]},
		"tags_removed": {die_index: [tags]},
		"special_effects": [{type: X, die_index: Y, data: {...}}]
	}
	"""
	var result = {
		"value_changes": {},
		"tags_added": {},
		"tags_removed": {},
		"special_effects": [],
		"combat_events": [],   # v4: Mana system combat event queue
		"mana_events": [],     # v4: Mana system mana event queue
	}
	
	var total_dice = dice.size()
	var triggering_die = context.get("triggering_die", null)
	
	# First pass: collect all affixes that should activate
	var activations: Array[Dictionary] = []
	
	for i in range(total_dice):
		var die = dice[i]
		die.slot_index = i  # Update slot tracking
		
		# --- v2.1: Skip consumed dice (they already fired their ON_USE) ---
		# Exception: the triggering die itself isn't consumed YET (it's about to be)
		if die.is_consumed and die != triggering_die:
			continue
		
		# --- v2.1: For ON_USE, only the triggering die fires its affixes ---
		# Neighbor dice don't fire their own ON_USE affixes just because a
		# different die was used. They CAN be targets of the triggering die's
		# affixes though — that's handled by target resolution, not here.
		if trigger == DiceAffix.Trigger.ON_USE and triggering_die != null:
			if die != triggering_die:
				continue
		
		for affix in die.get_all_affixes():
			if affix.trigger != trigger:
				continue
			
			# Check position requirement
			if not affix.check_position(i, total_dice):
				continue
			
			# --- v2: Evaluate condition ---
			var condition_multiplier := 1.0
			if affix.has_condition():
				var cond_result = affix.evaluate_condition(die, dice, i, context)
				if cond_result.blocked:
					continue  # Condition not met — skip this affix
				condition_multiplier = cond_result.multiplier
			
			# Get target dice indices
			var targets = affix.get_target_indices(i, total_dice)
			
			activations.append({
				"source_index": i,
				"source_die": die,
				"affix": affix,
				"targets": targets,
				"condition_multiplier": condition_multiplier,
			})
	
	# Second pass: apply effects
	for activation in activations:
		var affix: DiceAffix = activation.affix
		
		if affix.is_compound():
			# --- v2: Process sub-effects ---
			_apply_compound_effect(
				dice,
				activation.source_die,
				affix,
				activation.source_index,
				activation.condition_multiplier,
				context,
				result
			)
		else:
			# Single effect (original path + v2 value resolution)
			_apply_affix_effect(
				dice,
				activation.source_die,
				affix,
				activation.targets,
				activation.condition_multiplier,
				context,
				result
			)
		
		affix_activated.emit(activation.source_die, activation.affix, activation.targets)
	
	return result

# ============================================================================
# COMPOUND EFFECT PROCESSING (v2, updated v2.2)
# ============================================================================

func _apply_compound_effect(dice: Array[DieResource], source_die: DieResource,
		affix: DiceAffix, source_index: int, parent_multiplier: float,
		context: Dictionary, result: Dictionary):
	"""Process all sub-effects of a compound affix."""
	var total_dice = dice.size()
	
	# --- v2.2: Snapshot ALL dice values before any sub-effects modify them ---
	# This enables symmetric steal/transfer effects and any sub-effect that
	# needs pre-modification values of any die (own target, parent target, etc.).
	# Keyed by die index for O(1) lookups.
	var compound_snapshot := {}
	for idx in range(total_dice):
		compound_snapshot[idx] = dice[idx].get_total_value()
	context["_compound_snapshot"] = compound_snapshot
	
	for sub in affix.sub_effects:
		# Determine targets for this sub-effect
		var sub_targets: Array[int]
		if sub.override_target:
			sub_targets = affix.get_target_indices_for(sub.target_override, source_index, total_dice)
		else:
			sub_targets = affix.get_target_indices(source_index, total_dice)
		
		# Check sub-effect's own condition override
		var sub_multiplier := parent_multiplier
		if sub.condition_override:
			var cond_result = sub.condition_override.evaluate(source_die, dice, source_index, context)
			if cond_result.blocked:
				continue  # This sub-effect's condition not met
			sub_multiplier *= cond_result.multiplier
		
		# Apply this sub-effect
		_apply_sub_effect(dice, source_die, affix, sub, sub_targets, source_index, sub_multiplier, context, result)
	
	# Clean up snapshot from context
	context.erase("_compound_snapshot")

func _apply_sub_effect(dice: Array[DieResource], source_die: DieResource,
		parent_affix: DiceAffix, sub: DiceAffixSubEffect, target_indices: Array[int],
		source_index: int, multiplier: float, context: Dictionary, result: Dictionary):
	"""Apply a single DiceAffixSubEffect to its targets."""
	for target_index in target_indices:
		if target_index < 0 or target_index >= dice.size():
			continue
		
		var target_die = dice[target_index]
		var resolved_value = _resolve_value_for_sub(sub, source_die, target_die, target_index, dice, source_index, parent_affix, context) * multiplier
		
		_dispatch_effect(dice, source_die, target_die, target_index,
			sub.effect_type, resolved_value, sub.effect_data, parent_affix, context, result)
		
		effect_applied.emit(target_die, sub.effect_type, resolved_value)

# ============================================================================
# SINGLE EFFECT APPLICATION (updated with value resolution + context)
# ============================================================================

func _apply_affix_effect(dice: Array[DieResource], source_die: DieResource, 
		affix: DiceAffix, target_indices: Array[int], condition_multiplier: float,
		context: Dictionary, result: Dictionary):
	"""Apply a single affix effect to target dice."""
	for target_index in target_indices:
		if target_index < 0 or target_index >= dice.size():
			continue
		
		var target_die = dice[target_index]
		
		# --- v2: Resolve dynamic value ---
		var resolved_value = _resolve_value(affix, source_die, target_die, dice, context)
		resolved_value *= condition_multiplier
		
		_dispatch_effect(dice, source_die, target_die, target_index,
			affix.effect_type, resolved_value, affix.effect_data, affix, context, result)
		
		effect_applied.emit(target_die, affix.effect_type, resolved_value)

# ============================================================================
# EFFECT DISPATCH — Routes to specific handler by EffectType
# ============================================================================

func _dispatch_effect(dice: Array[DieResource], source_die: DieResource,
		target_die: DieResource, target_index: int, etype: DiceAffix.EffectType,
		resolved_value: float, edata: Dictionary, affix_or_parent: DiceAffix,
		context: Dictionary, result: Dictionary):
	"""Central dispatcher that routes to the correct handler."""
	
	match etype:
		# --- Value modifications ---
		DiceAffix.EffectType.MODIFY_VALUE_FLAT:
			# ON_COMBAT_START value mods must persist as CombatModifiers,
			# otherwise roll_hand() overwrites them every turn.
			if affix_or_parent.trigger == DiceAffix.Trigger.ON_COMBAT_START:
				var mod = CombatModifier.new()
				mod.mod_type = CombatModifier.ModType.FLAT_BONUS
				mod.value = resolved_value
				mod.duration = CombatModifier.Duration.COMBAT
				mod.target_filter = CombatModifier.TargetFilter.SPECIFIC_SLOT
				mod.source_slot_index = target_index
				mod.source_name = affix_or_parent.affix_name
				result.special_effects.append({
					"type": "create_combat_modifier",
					"modifier": mod
				})
				print("    🛡️ %s: ON_COMBAT_START flat +%.0f → persistent modifier (slot %d)" % [
					affix_or_parent.affix_name, resolved_value, target_index])
			else:
				_apply_value_flat(target_die, target_index, resolved_value, affix_or_parent, result)
		
		
		DiceAffix.EffectType.MODIFY_VALUE_PERCENT:
			if affix_or_parent.trigger == DiceAffix.Trigger.ON_COMBAT_START:
				var mod = CombatModifier.new()
				mod.mod_type = CombatModifier.ModType.PERCENT_BONUS
				mod.value = resolved_value
				mod.duration = CombatModifier.Duration.COMBAT
				mod.target_filter = CombatModifier.TargetFilter.SPECIFIC_SLOT
				mod.source_slot_index = target_index
				mod.source_name = affix_or_parent.affix_name
				result.special_effects.append({
					"type": "create_combat_modifier",
					"modifier": mod
				})
				print("    🛡️ %s: ON_COMBAT_START percent x%.2f → persistent modifier (slot %d)" % [
					affix_or_parent.affix_name, resolved_value, target_index])
			else:
				_apply_value_percent(target_die, target_index, resolved_value, affix_or_parent, result)
		
		DiceAffix.EffectType.SET_MINIMUM_VALUE:
			_apply_set_minimum(target_die, target_index, resolved_value, result)
		
		DiceAffix.EffectType.SET_MAXIMUM_VALUE:
			_apply_set_maximum(target_die, target_index, resolved_value, result)
		
		# --- Tag modifications ---
		DiceAffix.EffectType.ADD_TAG:
			var tag = edata.get("tag", "")
			_apply_add_tag(target_die, target_index, tag, result)
		
		DiceAffix.EffectType.REMOVE_TAG:
			var tag = edata.get("tag", "")
			_apply_remove_tag(target_die, target_index, tag, result)
		
		DiceAffix.EffectType.COPY_TAGS:
			_apply_copy_tags(source_die, target_die, target_index, result)
		
		DiceAffix.EffectType.REMOVE_ALL_TAGS:
			_apply_remove_all_tags(target_die, target_index, result)
		
		# --- Reroll effects ---
		DiceAffix.EffectType.GRANT_REROLL:
			_apply_grant_reroll(target_die, target_index, affix_or_parent, result)
		
		DiceAffix.EffectType.AUTO_REROLL_LOW:
			var threshold = edata.get("threshold", int(resolved_value))
			_apply_auto_reroll(target_die, target_index, threshold, affix_or_parent, result)
		
		# --- Special effects ---
		DiceAffix.EffectType.DUPLICATE_ON_MAX:
			_apply_duplicate_on_max(target_die, target_index, result)
		
		DiceAffix.EffectType.LOCK_DIE:
			_apply_lock_die(target_die, target_index, result)
		
		DiceAffix.EffectType.CHANGE_DIE_TYPE:
			var upgrade_steps = int(edata.get("upgrade_steps", 0))
			if upgrade_steps != 0:
				var die_sizes := [4, 6, 8, 10, 12]
				var current_idx := die_sizes.find(target_die.die_type)
				if current_idx < 0:
					current_idx = 0
				var new_idx := clampi(current_idx + upgrade_steps, 0, die_sizes.size() - 1)
				_apply_change_type(target_die, target_index, die_sizes[new_idx], result)
			else:
				var new_type = int(edata.get("new_type", target_die.die_type))
				_apply_change_type(target_die, target_index, new_type, result)
		
		DiceAffix.EffectType.COPY_NEIGHBOR_VALUE:
			_apply_copy_value(dice, source_die, target_die, target_index, affix_or_parent, result)
		
		# --- Combat effects ---
		DiceAffix.EffectType.ADD_DAMAGE_TYPE:
			_apply_damage_type(target_die, target_index, edata, result)
			# v4.1: If scaled value exists, also emit flat bonus damage of that element
			if resolved_value > 0.0:
				var bonus_edata := {"element": edata.get("type", "NONE").to_upper()}
				_apply_emit_bonus_damage(source_die, target_index, resolved_value, bonus_edata, result)
		
		DiceAffix.EffectType.GRANT_STATUS_EFFECT:
			_apply_status_effect(target_die, target_index, edata, result)
		
		# --- NEW v2 effects ---
		DiceAffix.EffectType.RANDOMIZE_ELEMENT:
			var elements = edata.get("elements", ["FIRE", "ICE", "SHOCK", "POISON"])
			_apply_randomize_element(target_die, target_index, elements, result)
		
		DiceAffix.EffectType.LEECH_HEAL:
			var percent = edata.get("percent", resolved_value)
			_apply_leech_heal(target_die, target_index, percent, result)
		
		DiceAffix.EffectType.DESTROY_SELF:
			_apply_destroy_self(source_die, source_die.slot_index, result)
		
		DiceAffix.EffectType.SET_ELEMENT:
			var element_str = edata.get("element", "NONE")
			_apply_set_element(target_die, target_index, element_str, context, result)
		
		DiceAffix.EffectType.CREATE_COMBAT_MODIFIER:
			if affix_or_parent.combat_modifier:
				_apply_create_combat_modifier(source_die, affix_or_parent.combat_modifier, result)
		
		DiceAffix.EffectType.SET_ROLL_VALUE:
			_apply_set_roll_value(target_die, target_index, resolved_value, affix_or_parent, result)
		
		# --- Combat Event Emitters (v4) ---
		DiceAffix.EffectType.EMIT_SPLASH_DAMAGE:
			_apply_emit_splash(source_die, target_index, resolved_value, edata, result)
		
		DiceAffix.EffectType.EMIT_CHAIN_DAMAGE:
			_apply_emit_chain(source_die, target_index, resolved_value, edata, result)
		
		DiceAffix.EffectType.EMIT_AOE_DAMAGE:
			_apply_emit_aoe(source_die, target_index, resolved_value, edata, result)
		
		DiceAffix.EffectType.EMIT_BONUS_DAMAGE:
			_apply_emit_bonus_damage(source_die, target_index, resolved_value, edata, result)
		
		# --- Mana Event Emitters (v4) ---
		DiceAffix.EffectType.MANA_REFUND:
			_apply_mana_refund(source_die, target_index, resolved_value, result)
		
		DiceAffix.EffectType.MANA_GAIN:
			_apply_mana_gain(source_die, target_index, resolved_value, result)
		
		# --- Dice Manipulation (v4) ---
		DiceAffix.EffectType.ROLL_KEEP_HIGHEST:
			_apply_roll_keep_highest(target_die, target_index, resolved_value, result)
		
		DiceAffix.EffectType.GRANT_EXTRA_ROLL:
			_apply_grant_extra_roll(target_die, target_index, resolved_value, result)
		
		DiceAffix.EffectType.IGNORE_RESISTANCE:
			_apply_ignore_resistance(source_die, target_index, edata, result)

# ============================================================================
# VALUE RESOLUTION (v2)
# ============================================================================

func _resolve_value(affix: DiceAffix, source_die: DieResource,
		target_die: DieResource, dice: Array[DieResource], context: Dictionary) -> float:
	"""Resolve the runtime value for an affix based on its ValueSource."""
	match affix.value_source:
		DiceAffix.ValueSource.STATIC:
			return affix.effect_value
		DiceAffix.ValueSource.SELF_VALUE:
			return float(source_die.get_total_value())
		DiceAffix.ValueSource.SELF_VALUE_FRACTION:
			return float(source_die.get_total_value()) * affix.effect_value
		DiceAffix.ValueSource.NEIGHBOR_VALUE:
			return float(target_die.get_total_value())
		DiceAffix.ValueSource.NEIGHBOR_PERCENT:
			return float(target_die.get_total_value()) * affix.effect_value
		DiceAffix.ValueSource.CONTEXT_USED_COUNT:
			return float(context.get("used_count", 0)) * affix.effect_value
		DiceAffix.ValueSource.SELF_TAGS:
			return affix.effect_value  # Tags handled separately in dispatch
		# --- Mana Context (v4) ---
		DiceAffix.ValueSource.CONTEXT_ELEMENT_DICE_USED:
			var elem_str = affix.effect_data.get("element", "")
			var elem_enum = DieResource._string_to_element(elem_str)
			var elem_counts: Dictionary = context.get("element_use_counts", {})
			return float(elem_counts.get(elem_enum, 0)) * affix.effect_value
		DiceAffix.ValueSource.CONTEXT_DICE_PLACED:
			return float(context.get("used_count", 0)) * affix.effect_value
		# Guard: compound-only ValueSources on non-compound affix
		DiceAffix.ValueSource.PARENT_TARGET_VALUE:
			push_warning("DiceAffixProcessor: compound-only ValueSource on '%s'" % affix.affix_name)
			return affix.effect_value
		DiceAffix.ValueSource.PARENT_TARGET_PERCENT:
			push_warning("DiceAffixProcessor: compound-only ValueSource on '%s'" % affix.affix_name)
			return affix.effect_value
		DiceAffix.ValueSource.SNAPSHOT_TARGET_VALUE:
			push_warning("DiceAffixProcessor: compound-only ValueSource on '%s'" % affix.affix_name)
			return affix.effect_value
		DiceAffix.ValueSource.SNAPSHOT_TARGET_PERCENT:
			push_warning("DiceAffixProcessor: compound-only ValueSource on '%s'" % affix.affix_name)
	return affix.effect_value

func _resolve_value_for_sub(sub: DiceAffixSubEffect, source_die: DieResource,
		target_die: DieResource, target_index: int, dice: Array[DieResource],
		source_index: int, parent_affix: DiceAffix, context: Dictionary) -> float:
	"""Resolve the runtime value for a sub-effect based on its ValueSource.
	Applies min_effect_magnitude clamping when configured."""
	var raw: float
	match sub.value_source:
		DiceAffix.ValueSource.STATIC:
			raw = sub.effect_value
		DiceAffix.ValueSource.SELF_VALUE:
			raw = float(source_die.get_total_value())
		DiceAffix.ValueSource.SELF_VALUE_FRACTION:
			raw = float(source_die.get_total_value()) * sub.effect_value
		DiceAffix.ValueSource.NEIGHBOR_VALUE:
			raw = float(target_die.get_total_value())
		DiceAffix.ValueSource.NEIGHBOR_PERCENT:
			raw = float(target_die.get_total_value()) * sub.effect_value
		DiceAffix.ValueSource.CONTEXT_USED_COUNT:
			raw = float(context.get("used_count", 0)) * sub.effect_value
		DiceAffix.ValueSource.SELF_TAGS:
			raw = sub.effect_value
		DiceAffix.ValueSource.PARENT_TARGET_VALUE:
			var parent_target = _get_parent_target_die(parent_affix, source_index, dice)
			if parent_target:
				var snap = context.get("_compound_snapshot", {})
				var pt_idx = dice.find(parent_target)
				raw = float(snap.get(pt_idx, parent_target.get_total_value()))
			else:
				raw = float(target_die.get_total_value())
		DiceAffix.ValueSource.PARENT_TARGET_PERCENT:
			var parent_target = _get_parent_target_die(parent_affix, source_index, dice)
			if parent_target:
				var snap = context.get("_compound_snapshot", {})
				var pt_idx = dice.find(parent_target)
				raw = float(snap.get(pt_idx, parent_target.get_total_value())) * sub.effect_value
			else:
				raw = float(target_die.get_total_value()) * sub.effect_value
		DiceAffix.ValueSource.SNAPSHOT_TARGET_VALUE:
			var snap = context.get("_compound_snapshot", {})
			raw = float(snap.get(target_index, target_die.get_total_value()))
		DiceAffix.ValueSource.SNAPSHOT_TARGET_PERCENT:
			var snap = context.get("_compound_snapshot", {})
			raw = float(snap.get(target_index, target_die.get_total_value())) * sub.effect_value
		_:
			raw = sub.effect_value
	
	# Apply minimum magnitude clamping (preserves sign)
	if sub.min_effect_magnitude > 0.0 and raw != 0.0:
		if absf(raw) < sub.min_effect_magnitude:
			raw = sub.min_effect_magnitude * signf(raw)
	
	return raw


func _get_parent_target_die(parent_affix: DiceAffix, source_index: int,
		dice: Array[DieResource]) -> DieResource:
	"""Resolve the first die from the parent affix's neighbor_target.
	Used by PARENT_TARGET_VALUE/PERCENT so a sub-effect targeting SELF
	can derive its value from the parent's target (e.g. LEFT neighbor)."""
	var parent_targets = parent_affix.get_target_indices(source_index, dice.size())
	if parent_targets.size() > 0 and parent_targets[0] >= 0 and parent_targets[0] < dice.size():
		return dice[parent_targets[0]]
	return null


func _apply_set_roll_value(die: DieResource, index: int, value: float, affix: DiceAffix, result: Dictionary):
	"""Force a die to a specific value. Supports use_die_max in effect_data."""
	var final_value: int
	if affix.effect_data.get("use_die_max", false):
		final_value = die.die_type  # DieType enum value IS the max face
	else:
		final_value = int(value)
	die.forced_roll_value = final_value
	result.special_effects.append({
		"type": "set_roll_value",
		"die_index": index,
		"forced_value": final_value,
		"affix": affix.affix_name
	})
	print("    🎲 %s: forced roll value = %d (from %s)" % [
		die.display_name, final_value, affix.affix_name
	])


# ============================================================================
# VALUE EFFECT IMPLEMENTATIONS
# ============================================================================

func _apply_value_flat(die: DieResource, index: int, value: float, affix: DiceAffix, result: Dictionary):
	"""Apply flat value modification"""
	var old_value = die.modified_value
	die.apply_flat_modifier(value)
	
	if old_value != die.modified_value:
		_record_value_change(result, index, old_value, die.modified_value)
		print("    📊 %s: %d -> %d (flat %+.0f from %s)" % [
			die.display_name, old_value, die.modified_value, 
			value, affix.affix_name
		])

func _apply_value_percent(die: DieResource, index: int, value: float, affix: DiceAffix, result: Dictionary):
	"""Apply percentage value modification.
	Guarantees at least +1/-1 change when value != 1.0 to prevent
	truncation zeroing out small-die bonuses (e.g. D4 roll 1 × 1.65 = 1)."""
	var old_value = die.modified_value
	die.apply_percent_modifier(value)
	# Floor: if the multiplier should change the value but truncation ate it
	if die.modified_value == old_value and value != 1.0 and old_value > 0:
		if value > 1.0:
			die.modified_value = old_value + 1
		elif value < 1.0:
			die.modified_value = maxi(old_value - 1, 0)
	
	if old_value != die.modified_value:
		_record_value_change(result, index, old_value, die.modified_value)
		print("    📊 %s: %d -> %d (x%.2f from %s)" % [
			die.display_name, old_value, die.modified_value,
			value, affix.affix_name
		])

func _apply_set_minimum(die: DieResource, index: int, value: float, result: Dictionary):
	"""Set minimum value"""
	var old_value = die.modified_value
	die.set_minimum_value(int(value))
	
	if old_value != die.modified_value:
		_record_value_change(result, index, old_value, die.modified_value)

func _apply_set_maximum(die: DieResource, index: int, value: float, result: Dictionary):
	"""Set maximum value"""
	var old_value = die.modified_value
	die.set_maximum_value(int(value))
	
	if old_value != die.modified_value:
		_record_value_change(result, index, old_value, die.modified_value)

# ============================================================================
# TAG EFFECT IMPLEMENTATIONS
# ============================================================================

func _apply_add_tag(die: DieResource, index: int, tag: String, result: Dictionary):
	"""Add tag to die"""
	if tag and not die.has_tag(tag):
		die.add_tag(tag)
		_record_tag_added(result, index, tag)
		print("    🏷️ %s gained tag: %s" % [die.display_name, tag])

func _apply_remove_tag(die: DieResource, index: int, tag: String, result: Dictionary):
	"""Remove tag from die"""
	if tag and die.has_tag(tag):
		die.remove_tag(tag)
		_record_tag_removed(result, index, tag)

func _apply_copy_tags(source: DieResource, target: DieResource, 
		index: int, result: Dictionary):
	"""Copy tags from source die to target"""
	for tag in source.get_tags():
		if not target.has_tag(tag):
			target.add_tag(tag)
			_record_tag_added(result, index, tag)

func _apply_remove_all_tags(die: DieResource, index: int, result: Dictionary):
	"""Remove ALL tags from die (v2 — used by Purify)"""
	var removed_tags = die.get_tags().duplicate()
	for tag in removed_tags:
		die.remove_tag(tag)
		_record_tag_removed(result, index, tag)
	if removed_tags.size() > 0:
		print("    🏷️ %s: removed all %d tags" % [die.display_name, removed_tags.size()])

# ============================================================================
# REROLL EFFECT IMPLEMENTATIONS
# ============================================================================

func _apply_grant_reroll(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Grant reroll ability to die"""
	die.can_reroll = true
	result.special_effects.append({
		"type": "grant_reroll",
		"die_index": index,
		"affix": affix.affix_name
	})

func _apply_auto_reroll(die: DieResource, index: int, threshold: int, affix: DiceAffix, result: Dictionary):
	"""Auto-reroll if below threshold"""
	if die.current_value <= threshold:
		var old_value = die.current_value
		die.roll()
		print("    🎲 %s auto-rerolled (was %d, threshold %d): now %d" % [
			die.display_name, old_value, threshold, die.current_value
		])
		_record_value_change(result, index, old_value, die.current_value)
		result.special_effects.append({
			"type": "auto_reroll",
			"die_index": index,
			"old_value": old_value,
			"new_value": die.current_value
		})

# ============================================================================
# SPECIAL EFFECT IMPLEMENTATIONS
# ============================================================================

func _apply_duplicate_on_max(die: DieResource, index: int, result: Dictionary):
	"""Duplicate die if max value rolled. Skips duplicate dice to prevent infinite loops."""
	if die.is_duplicate:
		return
	if die.is_max_roll():
		result.special_effects.append({
			"type": "duplicate",
			"die_index": index,
			"source_die": die
		})
		print("    ✨ %s rolled max! Duplicate triggered" % die.display_name)



func _apply_lock_die(die: DieResource, index: int, result: Dictionary):
	"""Lock die from being consumed"""
	die.is_locked = true
	result.special_effects.append({
		"type": "lock",
		"die_index": index
	})

func _apply_change_type(die: DieResource, index: int, new_type: int, result: Dictionary):
	"""Change die type (absolute). Caller resolves relative upgrades."""
	var old_type = die.die_type
	if new_type == old_type:
		return  # No change needed (already at cap or same type)
	die.die_type = new_type
	result.special_effects.append({
		"type": "change_type",
		"die_index": index,
		"old_type": old_type,
		"new_type": new_type
	})
	print("    🎲 %s: D%d → D%d" % [die.display_name, old_type, new_type])

func _apply_copy_value(dice: Array[DieResource], source: DieResource, target: DieResource,
		index: int, affix: DiceAffix, result: Dictionary):
	"""Copy percentage of neighbor's value"""
	var source_index = source.slot_index
	var neighbor: DieResource = null
	
	if affix.neighbor_target == DiceAffix.NeighborTarget.LEFT and source_index > 0:
		neighbor = dice[source_index - 1]
	elif affix.neighbor_target == DiceAffix.NeighborTarget.RIGHT and source_index < dice.size() - 1:
		neighbor = dice[source_index + 1]
	
	if neighbor:
		var percent = affix.get_percent()
		var bonus = int(neighbor.get_total_value() * percent)
		var old_value = target.modified_value
		target.apply_flat_modifier(bonus)
		
		if bonus > 0:
			_record_value_change(result, index, old_value, target.modified_value)
			print("    📊 %s gained +%d (%.0f%% of %s's %d)" % [
				target.display_name, bonus, percent * 100,
				neighbor.display_name, neighbor.get_total_value()
			])

# ============================================================================
# COMBAT EFFECT IMPLEMENTATIONS
# ============================================================================

func _apply_damage_type(die: DieResource, index: int, edata: Dictionary, result: Dictionary):
	"""Add damage type to die for combat"""
	var damage_type = edata.get("type", "physical")
	var percent = edata.get("percent", 0.0)
	
	result.special_effects.append({
		"type": "damage_type",
		"die_index": index,
		"damage_type": damage_type,
		"percent": percent
	})
	
	die.add_tag(damage_type)

func _apply_status_effect(die: DieResource, index: int, edata: Dictionary, result: Dictionary):
	"""Store status effect to apply on use"""
	var status = edata.get("status", {})
	
	result.special_effects.append({
		"type": "status_effect",
		"die_index": index,
		"status": status
	})

# ============================================================================
# NEW v2 EFFECT IMPLEMENTATIONS
# ============================================================================

func _apply_randomize_element(die: DieResource, index: int, elements: Array, result: Dictionary):
	"""Set die element to a random choice from the given list."""
	if elements.size() == 0:
		return
	
	var chosen: String = elements[randi() % elements.size()]
	var mapped = DieResource._string_to_element(chosen)
	var old_element = die.element
	die.element = mapped
	
	result.special_effects.append({
		"type": "randomize_element",
		"die_index": index,
		"old_element": old_element,
		"new_element": mapped,
		"element_name": chosen
	})
	print("    🎨 %s element randomized to %s" % [die.display_name, chosen])

func _apply_leech_heal(die: DieResource, index: int, percent: float, result: Dictionary):
	"""Store leech heal data for combat resolution.
	The CombatManager/Calculator reads this from special_effects after damage."""
	result.special_effects.append({
		"type": "leech_heal",
		"die_index": index,
		"percent": percent
	})
	print("    💚 %s will leech %.0f%% of damage as healing" % [die.display_name, percent * 100])

func _apply_destroy_self(die: DieResource, index: int, result: Dictionary):
	"""Mark this die for permanent removal from the pool after use.
	PlayerDiceCollection handles the actual removal from special_effects."""
	result.special_effects.append({
		"type": "destroy_from_pool",
		"die_index": index,
		"pool_slot_index": die.slot_index,
		"die_name": die.display_name
	})
	print("    💀 %s marked for permanent destruction" % die.display_name)

func _apply_set_element(die: DieResource, index: int, element_str: String, context, result: Dictionary):
	"""Set die element to a specific element."""
	var old_element = die.element

	# ── LEAST_USED: resolve from combat context ──
	if element_str == "LEAST_USED":
		var use_counts: Dictionary = context.get("element_use_counts", {})
		var candidates = [
			DieResource.Element.SLASHING, DieResource.Element.BLUNT,
			DieResource.Element.PIERCING, DieResource.Element.FIRE,
			DieResource.Element.ICE, DieResource.Element.SHOCK,
			DieResource.Element.POISON, DieResource.Element.SHADOW,
			DieResource.Element.FAITH,
		]
		var min_count: int = 999999
		var least: int = candidates[0]
		for elem in candidates:
			var count: int = use_counts.get(elem, 0)
			if count < min_count:
				min_count = count
				least = elem
		die.element = least
	else:
		var mapped = DieResource._string_to_element(element_str)
		die.element = mapped

	result.special_effects.append({
		"type": "set_element",
		"die_index": index,
		"old_element": old_element,
		"new_element": die.element
	})

func _apply_create_combat_modifier(source_die: DieResource, modifier: CombatModifier, result: Dictionary):
	"""Push a persistent CombatModifier into special_effects.
	PlayerDiceCollection picks this up and adds it to combat_modifiers."""
	var mod_copy = modifier.duplicate(true)
	mod_copy.source_slot_index = source_die.slot_index
	if not mod_copy.source_name:
		mod_copy.source_name = source_die.display_name
	
	result.special_effects.append({
		"type": "create_combat_modifier",
		"modifier": mod_copy
	})
	print("    🛡️ Combat modifier created from %s: %s" % [source_die.display_name, mod_copy])

# ============================================================================
# COMBAT EVENT EMITTERS (v4 — Mana System)
# ============================================================================

func _apply_emit_splash(source_die: DieResource, index: int,
		resolved_value: float, edata: Dictionary, result: Dictionary):
	"""Emit a splash damage event for CombatManager to resolve post-attack.
	Splash hits enemies adjacent to the primary target.
	Supports two modes:
	  - percent (default): resolved_value is ignored, percent of primary damage used
	  - flat: resolved_value IS the splash damage dealt to each adjacent enemy
	"""
	var mode: String = edata.get("mode", "percent")
	var event := {
		"type": "splash",
		"source_die": source_die.display_name,
		"die_index": index,
		"element": edata.get("element", ""),
		"mode": mode,
	}
	if mode == "flat":
		event["flat_damage"] = resolved_value
		event["percent"] = 0.0
	else:
		event["damage"] = resolved_value
		event["percent"] = edata.get("percent", 0.5)
	result.combat_events.append(event)
	if mode == "flat":
		print("    💥 %s queued flat splash: %.0f %s" % [
			source_die.display_name, resolved_value, edata.get("element", "?")])
	else:
		print("    💥 %s queued splash: %.0f%% %s" % [
			source_die.display_name, edata.get("percent", 0.5) * 100, edata.get("element", "?")])



func _apply_emit_chain(source_die: DieResource, index: int,
		resolved_value: float, edata: Dictionary, result: Dictionary):
	"""Emit a chain damage event. Chains to N targets with decay."""
	var event = {
		"type": "chain",
		"source_die": source_die.display_name,
		"die_index": index,
		"damage": resolved_value,
		"element": edata.get("element", ""),
		"chains": int(edata.get("chains", 2)),
		"decay": edata.get("decay", 0.7),
	}
	result.combat_events.append(event)
	print("    ⚡ %s queued chain: %.0f %s × %d (%.0f%% decay)" % [
		source_die.display_name, resolved_value, edata.get("element", "?"),
		event.chains, event.decay * 100])

func _apply_emit_aoe(source_die: DieResource, index: int,
		resolved_value: float, edata: Dictionary, result: Dictionary):
	"""Emit an AoE damage event. Hits all enemies."""
	var event = {
		"type": "aoe",
		"source_die": source_die.display_name,
		"die_index": index,
		"damage": resolved_value,
		"element": edata.get("element", ""),
	}
	result.combat_events.append(event)
	print("    🌊 %s queued AoE: %.0f %s" % [
		source_die.display_name, resolved_value, edata.get("element", "?")])

func _apply_emit_bonus_damage(source_die: DieResource, index: int,
		resolved_value: float, edata: Dictionary, result: Dictionary):
	"""Emit a bonus damage event. Added to primary attack damage."""
	var event = {
		"type": "bonus_damage",
		"source_die": source_die.display_name,
		"die_index": index,
		"damage": resolved_value,
		"element": edata.get("element", ""),
	}
	result.combat_events.append(event)
	print("    🔥 %s queued bonus damage: %.0f %s" % [
		source_die.display_name, resolved_value, edata.get("element", "?")])

# ============================================================================
# MANA EVENT EMITTERS (v4)
# ============================================================================

func _apply_mana_refund(source_die: DieResource, index: int,
		resolved_value: float, result: Dictionary):
	"""Emit a mana refund event. Refunds a percentage of the last pull cost."""
	var event = {
		"type": "mana_refund",
		"source_die": source_die.display_name,
		"die_index": index,
		"percent": resolved_value,
	}
	result.mana_events.append(event)
	print("    🔮 %s queued mana refund: %.0f%%" % [
		source_die.display_name, resolved_value * 100])

func _apply_mana_gain(source_die: DieResource, index: int,
		resolved_value: float, result: Dictionary):
	"""Emit a mana gain event. Adds flat mana to the pool."""
	var event = {
		"type": "mana_gain",
		"source_die": source_die.display_name,
		"die_index": index,
		"amount": int(resolved_value),
	}
	result.mana_events.append(event)
	print("    🔮 %s queued mana gain: %d" % [
		source_die.display_name, int(resolved_value)])

# ============================================================================
# DICE MANIPULATION (v4)
# ============================================================================

func _apply_roll_keep_highest(die: DieResource, index: int,
		resolved_value: float, result: Dictionary):
	"""Roll the die N extra times and keep the highest result.
	Modifies the die's value in place."""
	var extra_rolls = int(resolved_value)
	if extra_rolls <= 0:
		return
	
	var best = die.get_total_value()
	for _i in range(extra_rolls):
		die.roll()
		best = maxi(best, die.get_total_value())
	
	var old_val = die.get_total_value()
	die.modified_value = best
	
	if old_val != best:
		_record_value_change(result, index, old_val, best)
	
	result.special_effects.append({
		"type": "roll_keep_highest",
		"die_index": index,
		"rolls": extra_rolls + 1,
		"kept": best,
	})
	print("    🎲 %s rolled %d times, kept %d" % [
		die.display_name, extra_rolls + 1, best])

func _apply_grant_extra_roll(die: DieResource, index: int,
		resolved_value: float, result: Dictionary):
	"""Grant the die a reroll that keeps the better result.
	Similar to ROLL_KEEP_HIGHEST but designed for UI display as 'extra roll'."""
	var extra = int(resolved_value)
	if extra <= 0:
		return
	
	var original = die.get_total_value()
	var best = original
	for _i in range(extra):
		die.roll()
		best = maxi(best, die.get_total_value())
	
	die.modified_value = best
	
	if original != best:
		_record_value_change(result, index, original, best)
	
	result.special_effects.append({
		"type": "grant_extra_roll",
		"die_index": index,
		"original": original,
		"final": best,
	})
	print("    🎲 %s got extra roll: %d → %d" % [
		die.display_name, original, best])

func _apply_ignore_resistance(source_die: DieResource, index: int,
		edata: Dictionary, result: Dictionary):
	"""Mark this attack as ignoring target resistance for an element.
	CombatManager reads this from combat_events during damage calc."""
	var event = {
		"type": "ignore_resistance",
		"source_die": source_die.display_name,
		"die_index": index,
		"element": edata.get("element", ""),
	}
	result.combat_events.append(event)
	print("    🛡️ %s queued resistance bypass: %s" % [
		source_die.display_name, edata.get("element", "all")])

# ============================================================================
# RESULT TRACKING HELPERS
# ============================================================================
func _record_value_change(result: Dictionary, index: int, old_val: int, new_val: int):
	"""Record a value change in results"""
	result.value_changes[index] = {"old": old_val, "new": new_val}

func _record_tag_added(result: Dictionary, index: int, tag: String):
	"""Record a tag addition in results"""
	if not result.tags_added.has(index):
		result.tags_added[index] = []
	result.tags_added[index].append(tag)

func _record_tag_removed(result: Dictionary, index: int, tag: String):
	"""Record a tag removal in results"""
	if not result.tags_removed.has(index):
		result.tags_removed[index] = []
	result.tags_removed[index].append(tag)

# ============================================================================
# UTILITY
# ============================================================================

func _make_affix_result() -> Dictionary:
	return {
		"value_changes": {},
		"tags_added": {},
		"tags_removed": {},
		"special_effects": [],
		"combat_events": [],
		"mana_events": [],
	}


func get_affix_description_at_position(die: DieResource, slot_index: int, total_dice: int) -> String:
	"""Get description of what affixes will do at a specific position"""
	var lines: Array[String] = []
	
	for affix in die.get_all_affixes():
		var will_activate = affix.check_position(slot_index, total_dice)
		var status = "✓" if will_activate else "✗"
		lines.append("%s %s" % [status, affix.get_formatted_description()])
	
	return "\n".join(lines)
