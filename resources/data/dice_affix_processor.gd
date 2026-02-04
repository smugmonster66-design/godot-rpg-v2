# dice_affix_processor.gd - Processes and applies dice affixes
# Handles position checking, neighbor targeting, and effect application
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

func process_trigger(dice: Array[DieResource], trigger: DiceAffix.Trigger) -> Dictionary:
	"""Process all affixes with a specific trigger across all dice
	
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
		"special_effects": []
	}
	
	var total_dice = dice.size()
	
	# First pass: collect all affixes that should activate
	var activations: Array[Dictionary] = []
	
	for i in range(total_dice):
		var die = dice[i]
		die.slot_index = i  # Update slot tracking
		
		for affix in die.get_all_affixes():
			if affix.trigger != trigger:
				continue
			
			# Check position requirement
			if not affix.check_position(i, total_dice):
				continue
			
			# Get target dice indices
			var targets = affix.get_target_indices(i, total_dice)
			
			activations.append({
				"source_index": i,
				"source_die": die,
				"affix": affix,
				"targets": targets
			})
	
	# Second pass: apply effects
	for activation in activations:
		_apply_affix_effect(
			dice,
			activation.source_die,
			activation.affix,
			activation.targets,
			result
		)
		
		affix_activated.emit(activation.source_die, activation.affix, activation.targets)
	
	return result

# ============================================================================
# EFFECT APPLICATION
# ============================================================================

func _apply_affix_effect(dice: Array[DieResource], source_die: DieResource, 
		affix: DiceAffix, target_indices: Array[int], result: Dictionary):
	"""Apply a single affix effect to target dice"""
	
	for target_index in target_indices:
		if target_index < 0 or target_index >= dice.size():
			continue
		
		var target_die = dice[target_index]
		
		match affix.effect_type:
			# Value modifications
			DiceAffix.EffectType.MODIFY_VALUE_FLAT:
				_apply_value_flat(target_die, target_index, affix, result)
			
			DiceAffix.EffectType.MODIFY_VALUE_PERCENT:
				_apply_value_percent(target_die, target_index, affix, result)
			
			DiceAffix.EffectType.SET_MINIMUM_VALUE:
				_apply_set_minimum(target_die, target_index, affix, result)
			
			DiceAffix.EffectType.SET_MAXIMUM_VALUE:
				_apply_set_maximum(target_die, target_index, affix, result)
			
			# Tag modifications
			DiceAffix.EffectType.ADD_TAG:
				_apply_add_tag(target_die, target_index, affix, result)
			
			DiceAffix.EffectType.REMOVE_TAG:
				_apply_remove_tag(target_die, target_index, affix, result)
			
			DiceAffix.EffectType.COPY_TAGS:
				_apply_copy_tags(dice, source_die, target_die, target_index, affix, result)
			
			# Reroll effects
			DiceAffix.EffectType.GRANT_REROLL:
				_apply_grant_reroll(target_die, target_index, affix, result)
			
			DiceAffix.EffectType.AUTO_REROLL_LOW:
				_apply_auto_reroll(target_die, target_index, affix, result)
			
			# Special effects
			DiceAffix.EffectType.DUPLICATE_ON_MAX:
				_apply_duplicate_on_max(dice, target_die, target_index, affix, result)
			
			DiceAffix.EffectType.LOCK_DIE:
				_apply_lock_die(target_die, target_index, affix, result)
			
			DiceAffix.EffectType.CHANGE_DIE_TYPE:
				_apply_change_type(target_die, target_index, affix, result)
			
			DiceAffix.EffectType.COPY_NEIGHBOR_VALUE:
				_apply_copy_value(dice, source_die, target_die, target_index, affix, result)
			
			# Combat effects - these are handled differently (stored for combat use)
			DiceAffix.EffectType.ADD_DAMAGE_TYPE:
				_apply_damage_type(target_die, target_index, affix, result)
			
			DiceAffix.EffectType.GRANT_STATUS_EFFECT:
				_apply_status_effect(target_die, target_index, affix, result)
		
		effect_applied.emit(target_die, affix.effect_type, affix.effect_value)

# ============================================================================
# VALUE EFFECT IMPLEMENTATIONS
# ============================================================================

func _apply_value_flat(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Apply flat value modification"""
	var old_value = die.modified_value
	die.apply_flat_modifier(affix.get_value_modifier())
	
	if old_value != die.modified_value:
		_record_value_change(result, index, old_value, die.modified_value)
		print("    📊 %s: %d -> %d (flat +%.0f from %s)" % [
			die.display_name, old_value, die.modified_value, 
			affix.get_value_modifier(), affix.affix_name
		])

func _apply_value_percent(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Apply percentage value modification"""
	var old_value = die.modified_value
	die.apply_percent_modifier(affix.get_value_modifier())
	
	if old_value != die.modified_value:
		_record_value_change(result, index, old_value, die.modified_value)
		print("    📊 %s: %d -> %d (x%.2f from %s)" % [
			die.display_name, old_value, die.modified_value,
			affix.get_value_modifier(), affix.affix_name
		])

func _apply_set_minimum(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Set minimum value"""
	var old_value = die.modified_value
	die.set_minimum_value(int(affix.get_value_modifier()))
	
	if old_value != die.modified_value:
		_record_value_change(result, index, old_value, die.modified_value)

func _apply_set_maximum(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Set maximum value"""
	var old_value = die.modified_value
	die.set_maximum_value(int(affix.get_value_modifier()))
	
	if old_value != die.modified_value:
		_record_value_change(result, index, old_value, die.modified_value)

# ============================================================================
# TAG EFFECT IMPLEMENTATIONS
# ============================================================================

func _apply_add_tag(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Add tag to die"""
	var tag = affix.get_effect_tag()
	if tag and not die.has_tag(tag):
		die.add_tag(tag)
		_record_tag_added(result, index, tag)
		print("    🏷️ %s gained tag: %s" % [die.display_name, tag])

func _apply_remove_tag(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Remove tag from die"""
	var tag = affix.get_effect_tag()
	if tag and die.has_tag(tag):
		die.remove_tag(tag)
		_record_tag_removed(result, index, tag)

func _apply_copy_tags(dice: Array[DieResource], source: DieResource, target: DieResource, 
		index: int, affix: DiceAffix, result: Dictionary):
	"""Copy tags from source die to target"""
	for tag in source.get_tags():
		if not target.has_tag(tag):
			target.add_tag(tag)
			_record_tag_added(result, index, tag)

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

func _apply_auto_reroll(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Auto-reroll if below threshold"""
	var threshold = affix.get_threshold()
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

func _apply_duplicate_on_max(dice: Array[DieResource], die: DieResource, 
		index: int, affix: DiceAffix, result: Dictionary):
	"""Duplicate die if max value rolled"""
	if die.is_max_roll():
		result.special_effects.append({
			"type": "duplicate",
			"die_index": index,
			"source_die": die
		})
		print("    ✨ %s rolled max! Duplicate triggered" % die.display_name)

func _apply_lock_die(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Lock die from being consumed"""
	die.is_locked = true
	result.special_effects.append({
		"type": "lock",
		"die_index": index
	})

func _apply_change_type(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Change die type"""
	var new_type = affix.get_new_die_type()
	var old_type = die.die_type
	die.die_type = new_type
	result.special_effects.append({
		"type": "change_type",
		"die_index": index,
		"old_type": old_type,
		"new_type": new_type
	})

func _apply_copy_value(dice: Array[DieResource], source: DieResource, target: DieResource,
		index: int, affix: DiceAffix, result: Dictionary):
	"""Copy percentage of neighbor's value"""
	# Find the source die based on affix target direction
	var source_index = source.slot_index
	var neighbor: DieResource = null
	
	# Determine which neighbor based on affix configuration
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

func _apply_damage_type(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Add damage type to die for combat"""
	var damage_type = affix.get_damage_type()
	var percent = affix.get_percent()
	
	result.special_effects.append({
		"type": "damage_type",
		"die_index": index,
		"damage_type": damage_type,
		"percent": percent
	})
	
	# Also add as tag for easy checking
	die.add_tag(damage_type)

func _apply_status_effect(die: DieResource, index: int, affix: DiceAffix, result: Dictionary):
	"""Store status effect to apply on use"""
	var status = affix.get_status_effect()
	
	result.special_effects.append({
		"type": "status_effect",
		"die_index": index,
		"status": status
	})

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

func get_affix_description_at_position(die: DieResource, slot_index: int, total_dice: int) -> String:
	"""Get description of what affixes will do at a specific position"""
	var lines: Array[String] = []
	
	for affix in die.get_all_affixes():
		var will_activate = affix.check_position(slot_index, total_dice)
		var status = "✓" if will_activate else "✗"
		lines.append("%s %s" % [status, affix.get_formatted_description()])
	
	return "\n".join(lines)
